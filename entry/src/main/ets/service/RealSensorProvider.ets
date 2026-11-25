import { abilityAccessCtrl, Context, Permissions } from '@kit.AbilityKit';
import { sensor } from '@kit.SensorServiceKit';
import { SensorReading } from '../model/SensorReading';
import { SensorCapabilities, SensorStatus } from '../model/SensorAvailability';
import { PulseState } from '../model/PulseState';
import { SensorProvider } from './SensorProvider';
import { Logger } from '../util/Logger';
import { RELEASE_MODE } from '../util/AppConfig';
import { GRAVITY_MS2, MotionClassifier, MotionKind } from '../state/MotionClassifier';

const TAG: string = 'RealSensorProvider';
const HEALTH_PERMISSION: Permissions = 'ohos.permission.READ_HEALTH_DATA';
const HEART_RATE_INTERVAL_NS: number = 1000000000;
const MOVEMENT_INTERVAL_NS: number = 200000000;
const NO_DATA_TIMEOUT_MS: number = 10000;
/** Una lectura de pulso más vieja que esto ya no se muestra ni se evalúa. */
const HEART_RATE_FRESH_MS: number = 5000;
const MOTION_FRESH_MS: number = 3000;

export class RealSensorProvider implements SensorProvider {
  // SpO2 y temperatura: sin SensorId público en el SDK 6.1.1(24) -> No disponible (ver docs/auditoria-fase0.md).
  private capabilitiesState: SensorCapabilities = {
    heartRate: SensorStatus.Available,
    spo2: SensorStatus.Unavailable,
    temperature: SensorStatus.Unavailable,
    movement: SensorStatus.Available,
    location: SensorStatus.Available,
    fallDetection: SensorStatus.Available
  };
  /** 0 = sin lectura. Nunca se rellena con valores de ejemplo. */
  private bpm: number = 0;
  private spo2: number = 0;
  private temperature: number = 0;
  /** Clasificación pura (testeable con muestras sintéticas en src/test). */
  private readonly motion: MotionClassifier = new MotionClassifier();
  private lastMagnitudeLogAt: number = 0;
  private availabilityChecked: boolean = false;
  private heartRateAvailable: boolean = false;
  private movementAvailable: boolean = false;
  private heartRateSubscribed: boolean = false;
  private movementSubscribed: boolean = false;
  private permissionDenied: boolean = false;
  private lastHeartRateAt: number = 0;
  private lastMovementAt: number = 0;
  private watchdogTimer: number | undefined = undefined;

  private readonly heartRateCallback: (data: sensor.HeartRateResponse) => void =
    (data: sensor.HeartRateResponse): void => {
      try {
        if (data.heartRate > 0) {
          this.bpm = data.heartRate;
          this.lastHeartRateAt = Date.now();
          this.capabilitiesState.heartRate = SensorStatus.Measuring;
        }
      } catch (err) {
        Logger.error(TAG, 'callback de pulso falló', err as Object);
      }
    };

  private readonly movementCallback: (data: sensor.AccelerometerResponse) => void =
    (data: sensor.AccelerometerResponse): void => {
      try {
        const now: number = Date.now();
        const magnitude: number = this.motion.add(data.x, data.y, data.z, now);
        this.lastMovementAt = now;
        this.capabilitiesState.movement = SensorStatus.Measuring;
        // Solo debug (RELEASE_MODE=false): magnitud 1 vez por segundo para comprobar en reloj real.
        if (!RELEASE_MODE && now - this.lastMagnitudeLogAt >= 1000) {
          this.lastMagnitudeLogAt = now;
          Logger.info(TAG, `acelerómetro |a|=${magnitude.toFixed(2)} m/s2 (${(magnitude / GRAVITY_MS2).toFixed(2)} g) pico=${this.motion.peekPeakG().toFixed(2)} g estado=${this.motion.getKind()}`);
        }
      } catch (err) {
        Logger.error(TAG, 'callback de movimiento falló', err as Object);
      }
    };

  /**
   * 1) requestPermissionsFromUser. 2) Si el sistema ya no muestra el diálogo (dialogShownResults=false,
   * tras una negativa) y `allowSettings`, requestPermissionOnSetting abre el ajuste del permiso.
   * Si todo falla devuelve false y la UI muestra las instrucciones manuales.
   */
  async requestPermission(context: Context, allowSettings: boolean = false): Promise<boolean> {
    try {
      const manager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const result = await manager.requestPermissionsFromUser(context, [HEALTH_PERMISSION]);
      let granted: boolean = result.authResults[0] === 0;
      const shownList: boolean[] = result.dialogShownResults ?? [];
      const dialogShown: boolean = shownList.length > 0 ? shownList[0] : true;
      if (!granted && allowSettings && !dialogShown) {
        try {
          const statuses: abilityAccessCtrl.GrantStatus[] =
            await manager.requestPermissionOnSetting(context, [HEALTH_PERMISSION]);
          granted = statuses.length > 0 && statuses[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
        } catch (settingErr) {
          Logger.error(TAG, 'requestPermissionOnSetting falló', settingErr as Object);
        }
      }
      this.permissionDenied = !granted;
      if (granted) {
        Logger.info(TAG, 'Permiso READ_HEALTH_DATA concedido');
        // Re-evalúa y suscribe aunque una comprobación anterior lo hubiera marcado sin permiso.
        if (!this.heartRateSubscribed) {
          this.capabilitiesState.heartRate = SensorStatus.Available;
          this.availabilityChecked = false;
        }
        this.ensureStarted();
      } else {
        this.capabilitiesState.heartRate = SensorStatus.PermissionRequired;
        Logger.warn(TAG, 'Permiso READ_HEALTH_DATA denegado; sin lectura de pulso');
      }
      return granted;
    } catch (err) {
      this.permissionDenied = true;
      this.capabilitiesState.heartRate = SensorStatus.PermissionRequired;
      Logger.error(TAG, 'No se pudo solicitar READ_HEALTH_DATA; sin lectura de pulso', err as Object);
      return false;
    }
  }

  read(): SensorReading {
    this.ensureStarted();
    const now: number = Date.now();
    const heartRateValid: boolean = this.heartRateSubscribed && this.lastHeartRateAt > 0 &&
      now - this.lastHeartRateAt <= HEART_RATE_FRESH_MS;
    const motionValid: boolean = this.movementSubscribed && this.motion.isValid(now, MOTION_FRESH_MS);
    const peak: number = this.motion.takePeakG();
    return {
      bpm: heartRateValid ? this.bpm : 0,
      spo2: 0,
      temperature: 0,
      movementLabel: motionValid ? this.motionLabel() : $r('app.string.value_dash'),
      timestamp: now,
      heartRateValid: heartRateValid,
      motionValid: motionValid,
      immobile: motionValid && this.motion.isImmobile(),
      peakG: motionValid ? peak : 0
    };
  }

  private motionLabel(): Resource {
    const kind: MotionKind = this.motion.getKind();
    if (kind === MotionKind.Immobile) {
      return $r('app.string.immobile');
    }
    if (kind === MotionKind.Resting) {
      return $r('app.string.resting');
    }
    if (kind === MotionKind.Walking) {
      return $r('app.string.walking');
    }
    return $r('app.string.value_dash');
  }

  capabilities(): SensorCapabilities {
    this.ensureStarted();
    return {
      heartRate: this.capabilitiesState.heartRate,
      spo2: this.capabilitiesState.spo2,
      temperature: this.capabilitiesState.temperature,
      movement: this.capabilitiesState.movement,
      location: this.capabilitiesState.location,
      fallDetection: this.capabilitiesState.fallDetection
    };
  }

  /** Lecturas reales: las variantes de demostración no aplican. */
  setVariant(_state: PulseState): void {
  }

  /** Las capacidades reales las decide el hardware, no la UI. */
  setCapabilities(_capabilities: SensorCapabilities): void {
  }

  release(): void {
    try {
      if (this.heartRateSubscribed) {
        sensor.off(sensor.SensorId.HEART_RATE, this.heartRateCallback);
      }
    } catch (err) {
      Logger.error(TAG, 'sensor.off de pulso falló', err as Object);
    }
    try {
      if (this.movementSubscribed) {
        sensor.off(sensor.SensorId.ACCELEROMETER, this.movementCallback);
      }
    } catch (err) {
      Logger.error(TAG, 'sensor.off de acelerómetro falló', err as Object);
    }
    this.heartRateSubscribed = false;
    this.movementSubscribed = false;
    this.availabilityChecked = false;
    this.lastHeartRateAt = 0;
    this.lastMovementAt = 0;
    this.motion.reset();
    this.clearWatchdog();
    Logger.info(TAG, 'sensores liberados');
  }

  private ensureStarted(): void {
    if (this.availabilityChecked) {
      return;
    }
    this.availabilityChecked = true;
    void this.checkAvailability();
  }

  private async checkAvailability(): Promise<void> {
    try {
      const list = await sensor.getSensorList();
      this.heartRateAvailable = list.some((item: sensor.Sensor): boolean =>
        item.sensorId === sensor.SensorId.HEART_RATE);
      this.movementAvailable = list.some((item: sensor.Sensor): boolean =>
        item.sensorId === sensor.SensorId.ACCELEROMETER);
      if (!this.heartRateAvailable) {
        this.capabilitiesState.heartRate = SensorStatus.Unavailable;
        Logger.warn(TAG, 'SensorId.HEART_RATE no existe; sin lectura de pulso');
      }
      if (!this.movementAvailable) {
        this.capabilitiesState.movement = SensorStatus.Unavailable;
        this.capabilitiesState.fallDetection = SensorStatus.Unavailable;
        Logger.warn(TAG, 'SensorId.ACCELEROMETER no existe; sin lectura de movimiento');
      }
      this.subscribeAvailableSensors();
    } catch (err) {
      this.capabilitiesState.heartRate = SensorStatus.Unavailable;
      this.capabilitiesState.movement = SensorStatus.Unavailable;
      Logger.error(TAG, 'getSensorList falló; sin lecturas', err as Object);
    }
  }

  private subscribeAvailableSensors(): void {
    if (this.heartRateAvailable && !this.permissionDenied && !this.heartRateSubscribed &&
        this.capabilitiesState.heartRate !== SensorStatus.Unavailable) {
      this.subscribeHeartRate();
    }
    if (this.movementAvailable && !this.movementSubscribed &&
        this.capabilitiesState.movement !== SensorStatus.Unavailable) {
      this.subscribeMovement();
    }
    if (this.heartRateSubscribed || this.movementSubscribed) {
      this.startWatchdog();
    }
  }

  private subscribeHeartRate(): void {
    try {
      sensor.on(sensor.SensorId.HEART_RATE, this.heartRateCallback, { interval: HEART_RATE_INTERVAL_NS });
      this.heartRateSubscribed = true;
      this.capabilitiesState.heartRate = SensorStatus.Measuring;
    } catch (err) {
      this.heartRateSubscribed = false;
      if (this.isPermissionError(err)) {
        this.permissionDenied = true;
        this.capabilitiesState.heartRate = SensorStatus.PermissionRequired;
        Logger.warn(TAG, 'Activar permiso READ_HEALTH_DATA; sin lectura de pulso');
      } else {
        this.capabilitiesState.heartRate = SensorStatus.Unavailable;
        Logger.error(TAG, 'No se pudo suscribir al pulso; sin lectura', err as Object);
      }
    }
  }

  private subscribeMovement(): void {
    try {
      sensor.on(sensor.SensorId.ACCELEROMETER, this.movementCallback, { interval: MOVEMENT_INTERVAL_NS });
      this.movementSubscribed = true;
      this.capabilitiesState.movement = SensorStatus.Measuring;
    } catch (err) {
      this.movementSubscribed = false;
      if (this.isPermissionError(err)) {
        this.capabilitiesState.movement = SensorStatus.PermissionRequired;
        Logger.warn(TAG, 'Activar permiso de acelerómetro; sin lectura de movimiento');
      } else {
        this.capabilitiesState.movement = SensorStatus.Unavailable;
        Logger.error(TAG, 'No se pudo suscribir al acelerómetro; sin lectura de movimiento', err as Object);
      }
    }
  }

  private isPermissionError(err: Object): boolean {
    const text: string = JSON.stringify(err);
    return text.includes('201') || text.toLowerCase().includes('permission');
  }

  private startWatchdog(): void {
    if (this.watchdogTimer !== undefined) {
      return;
    }
    this.watchdogTimer = setTimeout((): void => {
      try {
        this.handleNoData();
      } catch (err) {
        Logger.error(TAG, 'vigilancia de datos falló', err as Object);
      }
      this.watchdogTimer = undefined;
    }, NO_DATA_TIMEOUT_MS);
  }

  private handleNoData(): void {
    const now: number = Date.now();
    if (this.heartRateSubscribed && this.capabilitiesState.heartRate !== SensorStatus.PermissionRequired &&
        now - this.lastHeartRateAt >= NO_DATA_TIMEOUT_MS) {
      // Sin datos (p. ej., reloj sin colocar): se mantiene suscrito; read() devuelve "sin lectura".
      Logger.warn(TAG, 'Sin datos de pulso en 10 s; sin lectura');
    }
    if (this.movementSubscribed && this.capabilitiesState.movement !== SensorStatus.PermissionRequired &&
        now - this.lastMovementAt >= NO_DATA_TIMEOUT_MS) {
      Logger.warn(TAG, 'Sin datos de movimiento en 10 s; sin lectura');
    }
  }

  private clearWatchdog(): void {
    if (this.watchdogTimer !== undefined) {
      clearTimeout(this.watchdogTimer);
      this.watchdogTimer = undefined;
    }
  }
}
