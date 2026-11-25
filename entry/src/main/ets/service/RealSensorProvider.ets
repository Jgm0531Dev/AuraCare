import { abilityAccessCtrl, Context, Permissions } from '@kit.AbilityKit';
import { sensor } from '@kit.SensorServiceKit';
import { SensorReading } from '../model/SensorReading';
import { SensorCapabilities, SensorStatus } from '../model/SensorAvailability';
import { PulseState } from '../model/PulseState';
import { SensorProvider } from './SensorProvider';
import { Logger } from '../util/Logger';

const TAG: string = 'RealSensorProvider';
const HEALTH_PERMISSION: Permissions = 'ohos.permission.READ_HEALTH_DATA';
const HEART_RATE_INTERVAL_NS: number = 1000000000;
const MOVEMENT_INTERVAL_NS: number = 200000000;
const NO_DATA_TIMEOUT_MS: number = 10000;
const MOVEMENT_WINDOW_MS: number = 5000;
const GRAVITY_MS2: number = 9.81;
const IMMOBILE_AVG: number = 0.12;
const IMMOBILE_MAX: number = 0.25;
const RESTING_AVG: number = 0.55;
const MIN_MOTION_SAMPLES: number = 4;
/** Una lectura de pulso más vieja que esto ya no se muestra ni se evalúa. */
const HEART_RATE_FRESH_MS: number = 5000;
const MOTION_FRESH_MS: number = 3000;

class MotionSample {
  timestamp: number = 0;
  deviation: number = 0;
}

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
  private movementLabel: Resource = $r('app.string.value_dash');
  private immobile: boolean = false;
  private peakG: number = 0;
  private availabilityChecked: boolean = false;
  private heartRateAvailable: boolean = false;
  private movementAvailable: boolean = false;
  private heartRateSubscribed: boolean = false;
  private movementSubscribed: boolean = false;
  private permissionDenied: boolean = false;
  private lastHeartRateAt: number = 0;
  private lastMovementAt: number = 0;
  private watchdogTimer: number | undefined = undefined;
  private motionSamples: MotionSample[] = [];

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
        const magnitude: number = Math.sqrt(data.x * data.x + data.y * data.y + data.z * data.z);
        const deviation: number = Math.abs(magnitude - GRAVITY_MS2);
        this.peakG = Math.max(this.peakG, magnitude / GRAVITY_MS2);
        const now: number = Date.now();
        this.motionSamples = this.motionSamples.filter((sample: MotionSample): boolean =>
          now - sample.timestamp <= MOVEMENT_WINDOW_MS);
        const sample: MotionSample = new MotionSample();
        sample.timestamp = now;
        sample.deviation = deviation;
        this.motionSamples.push(sample);
        this.lastMovementAt = now;
        this.capabilitiesState.movement = SensorStatus.Measuring;
        if (this.motionSamples.length < MIN_MOTION_SAMPLES) {
          return;
        }
        let sum: number = 0;
        let max: number = 0;
        this.motionSamples.forEach((item: MotionSample): void => {
          sum += item.deviation;
          max = Math.max(max, item.deviation);
        });
        const average: number = sum / this.motionSamples.length;
        this.immobile = average < IMMOBILE_AVG && max < IMMOBILE_MAX;
        if (this.immobile) {
          this.movementLabel = $r('app.string.immobile');
        } else if (average < RESTING_AVG) {
          this.movementLabel = $r('app.string.resting');
        } else {
          this.movementLabel = $r('app.string.walking');
        }
      } catch (err) {
        Logger.error(TAG, 'callback de movimiento falló', err as Object);
      }
    };

  async requestPermission(context: Context): Promise<boolean> {
    try {
      const manager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const result = await manager.requestPermissionsFromUser(context, [HEALTH_PERMISSION]);
      const granted: boolean = result.authResults[0] === 0;
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
    const motionValid: boolean = this.movementSubscribed && this.lastMovementAt > 0 &&
      now - this.lastMovementAt <= MOTION_FRESH_MS && this.motionSamples.length >= MIN_MOTION_SAMPLES;
    const peak: number = this.peakG;
    this.peakG = 0;
    return {
      bpm: heartRateValid ? this.bpm : 0,
      spo2: 0,
      temperature: 0,
      movementLabel: motionValid ? this.movementLabel : $r('app.string.value_dash'),
      timestamp: now,
      heartRateValid: heartRateValid,
      motionValid: motionValid,
      immobile: motionValid && this.immobile,
      peakG: motionValid ? peak : 0
    };
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
    this.motionSamples = [];
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
