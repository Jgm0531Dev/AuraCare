import { abilityAccessCtrl, Context, Permissions } from '@kit.AbilityKit';
import { sensor } from '@kit.SensorServiceKit';
import { SensorReading } from '../model/SensorReading';
import { SensorCapabilities, SensorStatus } from '../model/SensorAvailability';
import { PulseState, PulseVariant } from '../model/PulseState';
import { PULSE_VARIANTS } from '../mock/DemoData';
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

class MotionSample {
  timestamp: number = 0;
  deviation: number = 0;
}

export class RealSensorProvider implements SensorProvider {
  private variant: PulseVariant = PULSE_VARIANTS[0];
  private capabilitiesState: SensorCapabilities = {
    heartRate: SensorStatus.Available,
    spo2: SensorStatus.Available,
    temperature: SensorStatus.Available,
    movement: SensorStatus.Available,
    location: SensorStatus.Available,
    fallDetection: SensorStatus.Available
  };
  private bpm: number = this.variant.bpm;
  private spo2: number = this.variant.spo2;
  private temperature: number = this.variant.temperature;
  private movementLabel: Resource = this.variant.movementLabel;
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
        if (average < IMMOBILE_AVG && max < IMMOBILE_MAX) {
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
        this.ensureStarted();
      } else {
        this.capabilitiesState.heartRate = SensorStatus.PermissionRequired;
        Logger.warn(TAG, 'Permiso READ_HEALTH_DATA denegado; pulso simulado');
      }
      return granted;
    } catch (err) {
      this.permissionDenied = true;
      this.capabilitiesState.heartRate = SensorStatus.PermissionRequired;
      Logger.error(TAG, 'No se pudo solicitar READ_HEALTH_DATA; pulso simulado', err as Object);
      return false;
    }
  }

  read(): SensorReading {
    this.ensureStarted();
    return {
      bpm: this.bpm,
      spo2: this.spo2,
      temperature: this.temperature,
      movementLabel: this.movementLabel,
      timestamp: Date.now()
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

  setVariant(state: PulseState): void {
    const found: PulseVariant | undefined = PULSE_VARIANTS.find((item: PulseVariant): boolean => item.state === state);
    if (found === undefined) {
      return;
    }
    this.variant = found;
    this.bpm = found.bpm;
    this.spo2 = found.spo2;
    this.temperature = found.temperature;
    this.movementLabel = found.movementLabel;
  }

  setCapabilities(capabilities: SensorCapabilities): void {
    this.capabilitiesState = {
      heartRate: capabilities.heartRate,
      spo2: capabilities.spo2,
      temperature: capabilities.temperature,
      movement: capabilities.movement,
      location: capabilities.location,
      fallDetection: capabilities.fallDetection
    };
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
        Logger.warn(TAG, 'SensorId.HEART_RATE no existe; pulso simulado');
      }
      if (!this.movementAvailable) {
        this.capabilitiesState.movement = SensorStatus.Unavailable;
        Logger.warn(TAG, 'SensorId.ACCELEROMETER no existe; movimiento simulado');
      }
      this.subscribeAvailableSensors();
    } catch (err) {
      this.capabilitiesState.heartRate = SensorStatus.Unavailable;
      this.capabilitiesState.movement = SensorStatus.Unavailable;
      Logger.error(TAG, 'getSensorList falló; lecturas simuladas', err as Object);
    }
  }

  private subscribeAvailableSensors(): void {
    if (this.heartRateAvailable && !this.permissionDenied &&
        this.capabilitiesState.heartRate !== SensorStatus.Unavailable) {
      this.subscribeHeartRate();
    }
    if (this.movementAvailable && this.capabilitiesState.movement !== SensorStatus.Unavailable) {
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
        Logger.warn(TAG, 'Activar permiso READ_HEALTH_DATA; pulso simulado');
      } else {
        this.capabilitiesState.heartRate = SensorStatus.Unavailable;
        Logger.error(TAG, 'No se pudo suscribir al pulso; lectura simulada', err as Object);
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
        Logger.warn(TAG, 'Activar permiso de acelerómetro; movimiento simulado');
      } else {
        this.capabilitiesState.movement = SensorStatus.Unavailable;
        Logger.error(TAG, 'No se pudo suscribir al acelerómetro; movimiento simulado', err as Object);
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
      this.capabilitiesState.heartRate = SensorStatus.Unavailable;
      this.bpm = this.variant.bpm;
      Logger.warn(TAG, 'Sin datos de pulso en 10 s; lectura simulada');
    }
    if (this.movementSubscribed && this.capabilitiesState.movement !== SensorStatus.PermissionRequired &&
        now - this.lastMovementAt >= NO_DATA_TIMEOUT_MS) {
      this.capabilitiesState.movement = SensorStatus.Unavailable;
      this.movementLabel = this.variant.movementLabel;
      Logger.warn(TAG, 'Sin datos de movimiento en 10 s; lectura simulada');
    }
  }

  private clearWatchdog(): void {
    if (this.watchdogTimer !== undefined) {
      clearTimeout(this.watchdogTimer);
      this.watchdogTimer = undefined;
    }
  }
}
