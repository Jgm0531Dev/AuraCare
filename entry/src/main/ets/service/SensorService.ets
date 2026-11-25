import { Context } from '@kit.AbilityKit';
import { SensorProvider } from './SensorProvider';
import { MockSensorProvider } from './MockSensorProvider';
import { RealSensorProvider } from './RealSensorProvider';
import { SpO2Provider } from './SpO2Provider';
import { MockSpO2Provider } from './MockSpO2Provider';
import { rangeRepository } from './RangeRepository';
import { AppStore, ToggleableCapability } from '../state/AppStore';
import { PulseState, PulseVariant } from '../model/PulseState';
import { PULSE_VARIANTS } from '../mock/DemoData';
import { SensorCapabilities, SensorStatus } from '../model/SensorAvailability';
import { SensorReading } from '../model/SensorReading';
import { AlertReason } from '../model/AlertReason';
import { AlertState } from '../model/Alert';
import { AnomalyConfig, AnomalyEngine, AnomalyResult, DEFAULT_ANOMALY_CONFIG, classifyPulse } from '../state/AnomalyEngine';
import { PersonalRange, RangeTracker } from '../state/RangeModel';
import { SENSITIVITY_THRESHOLDS } from '../state/EmergencyMachine';
import { Logger } from '../util/Logger';

const TAG: string = 'SensorService';
const POLL_MS: number = 1000;
const RANGE_SAVE_MS: number = 60000;

export type AnomalyListener = (reason: AlertReason) => void;

/**
 * Lecturas para la UI y el motor de anomalías.
 * Proveedor activo: RealSensorProvider (HEART_RATE + ACCELEROMETER) salvo con "Modo demostración",
 * que usa el Mock y lo marca en pantalla. Sin permiso o sin sensor NO hay relleno: "sin lectura".
 */
class SensorService {
  private readonly real: RealSensorProvider = new RealSensorProvider();
  private readonly mock: MockSensorProvider = new MockSensorProvider();
  private readonly spo2Provider: SpO2Provider = new MockSpO2Provider();
  private readonly engine: AnomalyEngine = new AnomalyEngine();
  private range: RangeTracker = new RangeTracker();
  private store: AppStore | undefined = undefined;
  private pollTimer: number | undefined = undefined;
  private lastRangeSave: number = 0;
  private rangeDirty: boolean = false;
  private anomalyListener: AnomalyListener = (_reason: AlertReason): void => {};

  /** Datos de prueba (Modo demostración) en lugar de los sensores del reloj. */
  isSimulated(): boolean {
    return this.store !== undefined && this.store.settings.demoMode;
  }

  private active(): SensorProvider {
    return this.isSimulated() ? this.mock : this.real;
  }

  /** Abre el almacenamiento del rango personal. Llamar antes de start(). */
  init(context: Context): void {
    rangeRepository.init(context);
    this.range = new RangeTracker(rangeRepository.load());
  }

  setAnomalyListener(listener: AnomalyListener): void {
    this.anomalyListener = listener;
  }

  start(store: AppStore): void {
    this.store = store;
    this.selectVariant(PulseState.Normal, store);
    this.tick();
    this.startPolling();
  }

  /** Solicita READ_HEALTH_DATA (user_grant). Sin permiso: pulso "sin lectura", nunca simulado. */
  requestPermissions(context: Context): Promise<boolean> {
    return this.real.requestPermission(context);
  }

  /** Botón "Dar permiso" del Monitor: diálogo, y si ya no se muestra, el ajuste del sistema. */
  requestPermissionsInteractive(context: Context): Promise<boolean> {
    return this.real.requestPermission(context, true);
  }

  /** Tras "Estoy bien" o al cerrar una alerta: evita re-disparos inmediatos. */
  snooze(): void {
    this.engine.snooze(Date.now());
    if (this.store !== undefined) {
      this.store.anomalyPending = false;
    }
  }

  setDemoMode(on: boolean): void {
    const store: AppStore | undefined = this.store;
    if (store === undefined) {
      return;
    }
    store.settings.demoMode = on;
    this.engine.reset();
    if (on) {
      // Los sensores reales no se usan mientras la demo está activa.
      this.real.release();
      this.selectVariant(PulseState.Normal, store);
    }
    this.tick();
    Logger.info(TAG, `modo demostración=${on}`);
  }

  /** Demo: fija la variante de los datos de prueba (Normal / Elevado / Crítico). */
  selectVariant(state: PulseState, store: AppStore): void {
    this.mock.setVariant(state);
    const variant: PulseVariant | undefined =
      PULSE_VARIANTS.find((item: PulseVariant): boolean => item.state === state);
    if (variant !== undefined && this.isSimulated()) {
      store.selectVariant(variant);
      this.spo2Provider.setPercent(variant.spo2);
      store.applySpO2(this.spo2Provider.read());
    }
    if (this.pollTimer !== undefined) {
      this.tick();
    }
  }

  setCapabilities(capabilities: SensorCapabilities, store: AppStore): void {
    this.mock.setCapabilities(capabilities);
    store.capabilities = this.active().capabilities();
  }

  /** Panel de desarrollo: solo afecta al proveedor de demostración. */
  toggleCapability(capability: ToggleableCapability, available: boolean, store: AppStore): void {
    store.setCapability(capability, available);
    this.mock.setCapabilities(store.capabilities);
    if (capability === 'spo2') {
      this.spo2Provider.setAvailable(available);
      store.applySpO2(this.spo2Provider.read());
    }
  }

  /** Segundo plano: deja de leer y libera los sensores (sensor.off). */
  pause(): void {
    this.stopPolling();
    this.real.release();
    this.saveRange(true);
  }

  resume(): void {
    if (this.store === undefined) {
      return;
    }
    this.tick();
    this.startPolling();
  }

  release(): void {
    this.stopPolling();
    this.real.release();
    this.mock.release();
    this.spo2Provider.release();
    this.saveRange(true);
  }

  private startPolling(): void {
    if (this.pollTimer !== undefined) {
      return;
    }
    this.pollTimer = setInterval((): void => {
      try {
        this.tick();
      } catch (err) {
        Logger.error(TAG, 'tick falló', err as Object);
      }
    }, POLL_MS);
  }

  private stopPolling(): void {
    if (this.pollTimer !== undefined) {
      clearInterval(this.pollTimer);
      this.pollTimer = undefined;
    }
  }

  private anomalyConfig(store: AppStore): AnomalyConfig {
    const sensitivity: string = store.settings.sensitivity;
    const high: number = sensitivity === 'Baja' ? SENSITIVITY_THRESHOLDS.Baja :
      (sensitivity === 'Alta' ? SENSITIVITY_THRESHOLDS.Alta : SENSITIVITY_THRESHOLDS.Media);
    return {
      highBpm: high,
      lowBpm: DEFAULT_ANOMALY_CONFIG.lowBpm,
      sustainMs: DEFAULT_ANOMALY_CONFIG.sustainMs,
      fallImpactG: DEFAULT_ANOMALY_CONFIG.fallImpactG,
      fallStillMs: DEFAULT_ANOMALY_CONFIG.fallStillMs,
      fallWindowMs: DEFAULT_ANOMALY_CONFIG.fallWindowMs,
      cooldownMs: DEFAULT_ANOMALY_CONFIG.cooldownMs
    };
  }

  private tick(): void {
    const store: AppStore | undefined = this.store;
    if (store === undefined) {
      return;
    }
    const simulated: boolean = this.isSimulated();
    const reading: SensorReading = this.active().read();
    const now: number = reading.timestamp;
    const heartRateValid: boolean = reading.heartRateValid === true;
    const motionValid: boolean = reading.motionValid === true;

    store.bpm = heartRateValid ? reading.bpm : 0;
    store.heartRateValid = heartRateValid;
    store.motionValid = motionValid;
    store.movementLabel = reading.movementLabel;
    store.movementImmobile = reading.immobile === true;
    if (simulated) {
      store.spo2 = reading.spo2;
      store.temperature = reading.temperature;
    }
    this.applyCapabilities(store);

    // Rango personal: solo lecturas reales, fuera de modo ejercicio y sin alerta en curso.
    if (!simulated && heartRateValid && !store.settings.exerciseMode && store.emergency.state === AlertState.None) {
      this.range.add(reading.bpm, now);
      this.rangeDirty = true;
    }
    const personal: PersonalRange = this.range.compute(now);
    store.rangeReady = personal.ready;
    store.rangeMin = personal.min;
    store.rangeMax = personal.max;
    store.rangeSamples = personal.samples;
    this.saveRange(false);

    const config: AnomalyConfig = this.anomalyConfig(store);
    this.engine.setConfig(config);
    const state: PulseState = classifyPulse(store.bpm, personal.min, personal.max, config);
    const variant: PulseVariant | undefined = PULSE_VARIANTS.find((item: PulseVariant): boolean => item.state === state);
    store.pulseState = state;
    if (variant !== undefined) {
      store.stateColor = heartRateValid ? variant.color : $r('app.color.muted');
      store.markerAngle = variant.markerAngle;
    }

    const result: AnomalyResult = this.engine.update({
      now: now,
      bpm: store.bpm,
      heartRateValid: heartRateValid,
      motionValid: motionValid,
      immobile: store.movementImmobile,
      peakG: reading.peakG ?? 0,
      exerciseMode: store.settings.exerciseMode,
      fallDetection: store.settings.fallDetection
    });
    store.anomalyPending = result.pending && store.emergency.state === AlertState.None;
    if (result.trigger !== undefined && store.emergency.state === AlertState.None && store.autoAlerts) {
      Logger.warn(TAG, `anomalía detectada: ${result.trigger}`);
      this.anomalyListener(result.trigger);
    }
  }

  private applyCapabilities(store: AppStore): void {
    const next: SensorCapabilities = this.active().capabilities();
    const current: SensorCapabilities = store.capabilities;
    // La ubicación la gestiona LocationService: se conserva su estado.
    if (current.heartRate !== next.heartRate || current.spo2 !== next.spo2 ||
        current.temperature !== next.temperature || current.movement !== next.movement ||
        current.fallDetection !== next.fallDetection) {
      store.capabilities = {
        heartRate: next.heartRate,
        spo2: next.spo2,
        temperature: next.temperature,
        movement: next.movement,
        location: current.location,
        fallDetection: next.fallDetection
      };
    }
  }

  private saveRange(force: boolean): void {
    const now: number = Date.now();
    if (!this.rangeDirty || (!force && now - this.lastRangeSave < RANGE_SAVE_MS)) {
      return;
    }
    rangeRepository.save(this.range.getBuckets());
    this.lastRangeSave = now;
    this.rangeDirty = false;
  }

  /** Estado del sensor de pulso para la UI (permiso pendiente vs. no disponible). */
  heartRateStatus(): SensorStatus {
    return this.active().capabilities().heartRate;
  }
}

export const sensorService: SensorService = new SensorService();
