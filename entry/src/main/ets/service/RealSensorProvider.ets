import { abilityAccessCtrl, Context, Permissions } from '@kit.AbilityKit';
import { sensor } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { SensorReading } from '../model/SensorReading';
import { SensorCapabilities, SensorStatus } from '../model/SensorAvailability';
import { PulseState } from '../model/PulseState';
import { SensorProvider } from './SensorProvider';
import { Logger } from '../util/Logger';
import { RELEASE_MODE } from '../util/AppConfig';
import { GRAVITY_MS2, MotionClassifier, MotionKind } from '../state/MotionClassifier';
import { isPlausibleBpm } from '../state/AnomalyEngine';

const TAG: string = 'RealSensorProvider';
const HEALTH_PERMISSION: Permissions = 'ohos.permission.READ_HEALTH_DATA';
const HEART_RATE_INTERVAL_NS: number = 1000000000;
const MOVEMENT_INTERVAL_NS: number = 200000000;
const NO_DATA_TIMEOUT_MS: number = 10000;
/** Una lectura de pulso más vieja que esto ya no se muestra ni se evalúa. */
const HEART_RATE_FRESH_MS: number = 5000;
const MOTION_FRESH_MS: number = 3000;
const WEAR_INTERVAL_NS: number = 1000000000;
/** Guía Sensor Service Kit, error 14500101: reintentar con espera creciente y parar tras 3 fallos. */
const SERVICE_EXCEPTION: number = 14500101;
const MAX_RETRIES: number = 3;
const RETRY_BASE_MS: number = 1000;

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
  private wearAvailable: boolean = false;
  private wearSubscribed: boolean = false;
  /** Último valor de WEAR_DETECTION: 1 puesto, 0 no puesto; -1 sin dato (se asume puesto). */
  private wearValue: number = -1;
  private listRetries: number = 0;
  private heartRateRetries: number = 0;
  private movementRetries: number = 0;
  private retryTimers: number[] = [];
  private permissionDenied: boolean = false;
  private lastHeartRateAt: number = 0;
  private lastMovementAt: number = 0;
  private watchdogTimer: number | undefined = undefined;
  /** Sube en cada release(): una consulta getSensorList pendiente de antes no puede suscribir después. */
  private generation: number = 0;

  private readonly heartRateCallback: (data: sensor.HeartRateResponse) => void =
    (data: sensor.HeartRateResponse): void => {
      try {
        // Valores imposibles (0, negativos, > 250 lpm) se descartan: la UI muestra "--".
        if (isPlausibleBpm(data.heartRate)) {
          this.bpm = data.heartRate;
          this.lastHeartRateAt = Date.now();
          this.capabilitiesState.heartRate = SensorStatus.Measuring;
        }
      } catch (err) {
        Logger.error(TAG, 'callback de pulso falló', err as Object);
      }
    };

  private readonly wearCallback: (data: sensor.WearDetectionResponse) => void =
    (data: sensor.WearDetectionResponse): void => {
      try {
        const next: number = data.value === 0 ? 0 : 1;
        if (next !== this.wearValue) {
          Logger.info(TAG, next === 0 ? 'reloj no colocado' : 'reloj colocado');
        }
        this.wearValue = next;
      } catch (err) {
        Logger.error(TAG, 'callback de colocación falló', err as Object);
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
    // Reloj quitado (WEAR_DETECTION = 0): sin pulso ni detección de caídas (dejarlo en la mesa no es una caída).
    const notWorn: boolean = this.wearSubscribed && this.wearValue === 0;
    const heartRateValid: boolean = !notWorn && this.heartRateSubscribed && this.lastHeartRateAt > 0 &&
      now - this.lastHeartRateAt <= HEART_RATE_FRESH_MS;
    const motionValid: boolean = !notWorn && this.movementSubscribed && this.motion.isValid(now, MOTION_FRESH_MS);
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
      peakG: motionValid ? peak : 0,
      notWorn: notWorn
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
    try {
      if (this.wearSubscribed) {
        sensor.off(sensor.SensorId.WEAR_DETECTION, this.wearCallback);
      }
    } catch (err) {
      Logger.error(TAG, 'sensor.off de colocación falló', err as Object);
    }
    this.heartRateSubscribed = false;
    this.movementSubscribed = false;
    this.wearSubscribed = false;
    this.wearValue = -1;
    this.availabilityChecked = false;
    this.generation++;
    this.clearRetries();
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
    const generation: number = this.generation;
    try {
      const list = await sensor.getSensorList();
      if (generation !== this.generation) {
        // Se liberó (segundo plano, demo o cierre) mientras se consultaba: no suscribir (on/off en pares).
        return;
      }
      this.heartRateAvailable = list.some((item: sensor.Sensor): boolean =>
        item.sensorId === sensor.SensorId.HEART_RATE);
      this.movementAvailable = list.some((item: sensor.Sensor): boolean =>
        item.sensorId === sensor.SensorId.ACCELEROMETER);
      this.wearAvailable = list.some((item: sensor.Sensor): boolean =>
        item.sensorId === sensor.SensorId.WEAR_DETECTION);
      this.listRetries = 0;
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
      if (this.isServiceException(err) && this.scheduleRetry(this.listRetries++, (): void => {
        void this.checkAvailability();
      })) {
        Logger.warn(TAG, `getSensorList 14500101; reintento ${this.listRetries} de ${MAX_RETRIES}`);
        return;
      }
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
    // Colocación: solo si hay algún sensor que interpretar y el reloj lo ofrece (sin permiso en el SDK 24).
    this.subscribeWearIfNeeded();
    if (this.heartRateSubscribed || this.movementSubscribed) {
      this.startWatchdog();
    }
  }

  private subscribeWearIfNeeded(): void {
    if (this.wearAvailable && !this.wearSubscribed && (this.heartRateSubscribed || this.movementSubscribed)) {
      this.subscribeWear();
    }
  }

  private subscribeWear(): void {
    try {
      sensor.on(sensor.SensorId.WEAR_DETECTION, this.wearCallback, { interval: WEAR_INTERVAL_NS });
      this.wearSubscribed = true;
    } catch (err) {
      // Sin detección de colocación: se sigue como antes ("--" si deja de llegar el pulso).
      this.wearSubscribed = false;
      Logger.error(TAG, 'No se pudo suscribir a WEAR_DETECTION', err as Object);
    }
  }

  private subscribeHeartRate(): void {
    try {
      sensor.on(sensor.SensorId.HEART_RATE, this.heartRateCallback, { interval: HEART_RATE_INTERVAL_NS });
      this.heartRateSubscribed = true;
      this.heartRateRetries = 0;
      this.capabilitiesState.heartRate = SensorStatus.Measuring;
      this.startWatchdog();
    } catch (err) {
      this.heartRateSubscribed = false;
      if (this.isServiceException(err) && this.scheduleRetry(this.heartRateRetries++, (): void => {
        this.subscribeHeartRate();
        this.subscribeWearIfNeeded();
      })) {
        Logger.warn(TAG, `pulso 14500101; reintento ${this.heartRateRetries} de ${MAX_RETRIES}`);
      } else if (this.isPermissionError(err)) {
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
      this.movementRetries = 0;
      this.capabilitiesState.movement = SensorStatus.Measuring;
      this.startWatchdog();
    } catch (err) {
      this.movementSubscribed = false;
      if (this.isServiceException(err) && this.scheduleRetry(this.movementRetries++, (): void => {
        this.subscribeMovement();
        this.subscribeWearIfNeeded();
      })) {
        Logger.warn(TAG, `acelerómetro 14500101; reintento ${this.movementRetries} de ${MAX_RETRIES}`);
      } else if (this.isPermissionError(err)) {
        this.capabilitiesState.movement = SensorStatus.PermissionRequired;
        Logger.warn(TAG, 'Activar permiso de acelerómetro; sin lectura de movimiento');
      } else {
        this.capabilitiesState.movement = SensorStatus.Unavailable;
        Logger.error(TAG, 'No se pudo suscribir al acelerómetro; sin lectura de movimiento', err as Object);
      }
    }
  }

  private isPermissionError(err: Object): boolean {
    // Código documentado de sensor.on: 201 = Permission denied.
    return (err as BusinessError).code === 201;
  }

  private isServiceException(err: Object): boolean {
    return (err as BusinessError).code === SERVICE_EXCEPTION;
  }

  /**
   * Programa un reintento tras 1 s, 2 s y 4 s. Devuelve false a partir del tercer fallo (el llamador
   * marca el sensor "No disponible"). Un release() posterior anula los reintentos pendientes.
   */
  private scheduleRetry(attempt: number, action: () => void): boolean {
    if (attempt >= MAX_RETRIES) {
      return false;
    }
    const generation: number = this.generation;
    const timer: number = setTimeout((): void => {
      this.retryTimers = this.retryTimers.filter((item: number): boolean => item !== timer);
      if (generation !== this.generation) {
        return;
      }
      try {
        action();
      } catch (err) {
        Logger.error(TAG, 'reintento de sensor falló', err as Object);
      }
    }, RETRY_BASE_MS * Math.pow(2, attempt));
    this.retryTimers.push(timer);
    return true;
  }

  private clearRetries(): void {
    this.retryTimers.forEach((timer: number): void => {
      clearTimeout(timer);
    });
    this.retryTimers = [];
    this.listRetries = 0;
    this.heartRateRetries = 0;
    this.movementRetries = 0;
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
