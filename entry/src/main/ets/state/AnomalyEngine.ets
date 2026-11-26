import { AlertReason } from '../model/AlertReason';
import { PulseState } from '../model/PulseState';

/**
 * Motor de anomalías en TS puro (sin UI ni APIs del sistema): recibe lecturas con su
 * timestamp y decide si hay que abrir "¿Estás bien?". El tiempo llega en cada entrada,
 * así que los tests lo controlan sin temporizadores.
 */

/** Pulso alto sostenido en reposo, pulso muy bajo sostenido o caída (impacto + inmovilidad). */
export interface AnomalyConfig {
  /** Umbral de pulso alto (lo fija la sensibilidad de Ajustes). */
  highBpm: number;
  /** Por debajo de esto (y > 0) se considera pulso muy bajo. */
  lowBpm: number;
  /** Tiempo que la condición debe mantenerse sin interrupción. */
  sustainMs: number;
  /** Pico de aceleración que cuenta como impacto. */
  fallImpactG: number;
  /** Inmovilidad continua tras el impacto para confirmar caída. */
  fallStillMs: number;
  /** Ventana máxima entre impacto e inicio de la inmovilidad (debe superar MOVEMENT_WINDOW_MS). */
  fallWindowMs: number;
  /** Silencio tras una alerta o tras "Estoy bien". */
  cooldownMs: number;
}

export const DEFAULT_ANOMALY_CONFIG: AnomalyConfig = {
  highBpm: 110,
  lowBpm: 40,
  sustainMs: 10000,
  fallImpactG: 2.5,
  fallStillMs: 10000,
  // > ventana de inmovilidad (5 s, MotionClassifier): el golpe sale de la ventana a los ~5 s.
  fallWindowMs: 8000,
  cooldownMs: 120000
};

export interface AnomalyInput {
  now: number;
  bpm: number;
  heartRateValid: boolean;
  motionValid: boolean;
  immobile: boolean;
  peakG: number;
  exerciseMode: boolean;
  fallDetection: boolean;
}

export interface AnomalyResult {
  /** Motivo a disparar en esta lectura; undefined = nada. */
  trigger: AlertReason | undefined;
  /** Hay una condición acumulándose (para mostrar "Vigilando…"). */
  pending: boolean;
}

/** Normal dentro del rango personal; Elevado fuera de él; Crítico en el umbral alto o bajo. */
/** Rango fisiológico aceptado para una lectura de pulso (lpm). Fuera de él se descarta como "sin lectura". */
export const MIN_VALID_BPM: number = 1;
export const MAX_VALID_BPM: number = 250;

export function isPlausibleBpm(bpm: number): boolean {
  return Number.isFinite(bpm) && bpm >= MIN_VALID_BPM && bpm <= MAX_VALID_BPM;
}

export function classifyPulse(bpm: number, rangeMin: number, rangeMax: number, config: AnomalyConfig): PulseState {
  if (bpm <= 0) {
    return PulseState.Normal;
  }
  if (bpm >= config.highBpm || bpm < config.lowBpm) {
    return PulseState.Critical;
  }
  if (bpm < rangeMin || bpm > rangeMax) {
    return PulseState.Elevated;
  }
  return PulseState.Normal;
}

export class AnomalyEngine {
  private config: AnomalyConfig;
  private pulseSince: number = -1;
  private impactAt: number = -1;
  private stillSince: number = -1;
  private silentUntil: number = 0;

  constructor(config: AnomalyConfig = DEFAULT_ANOMALY_CONFIG) {
    this.config = config;
  }

  setConfig(config: AnomalyConfig): void {
    this.config = config;
  }

  getConfig(): AnomalyConfig {
    return this.config;
  }

  /** Tras "Estoy bien" o al cerrar una alerta: no vuelve a disparar hasta `now + cooldownMs`. */
  snooze(now: number): void {
    this.silentUntil = now + this.config.cooldownMs;
    this.pulseSince = -1;
    this.impactAt = -1;
    this.stillSince = -1;
  }

  reset(): void {
    this.pulseSince = -1;
    this.impactAt = -1;
    this.stillSince = -1;
    this.silentUntil = 0;
  }

  update(input: AnomalyInput): AnomalyResult {
    const pulseCondition: boolean = this.pulseCondition(input);
    if (pulseCondition) {
      if (this.pulseSince < 0) {
        this.pulseSince = input.now;
      }
    } else {
      this.pulseSince = -1;
    }
    this.trackFall(input);

    const silenced: boolean = input.now < this.silentUntil;
    if (!silenced && this.pulseSince >= 0 && input.now - this.pulseSince >= this.config.sustainMs) {
      this.snooze(input.now);
      return { trigger: AlertReason.PulsoCritico, pending: false };
    }
    if (!silenced && this.fallConfirmed(input.now)) {
      this.snooze(input.now);
      return { trigger: AlertReason.Caida, pending: false };
    }
    return { trigger: undefined, pending: !silenced && (this.pulseSince >= 0 || this.impactAt >= 0) };
  }

  private pulseCondition(input: AnomalyInput): boolean {
    if (!input.heartRateValid || input.bpm <= 0) {
      return false;
    }
    if (input.bpm < this.config.lowBpm) {
      return true;
    }
    if (input.exerciseMode || input.bpm < this.config.highBpm) {
      return false;
    }
    // Pulso alto: solo cuenta en reposo/inmóvil. Sin acelerómetro no se puede descartar ejercicio,
    // así que también cuenta (el usuario confirma con "Estoy bien").
    return !input.motionValid || input.immobile;
  }

  private trackFall(input: AnomalyInput): void {
    if (!input.fallDetection || !input.motionValid) {
      this.impactAt = -1;
      this.stillSince = -1;
      return;
    }
    if (input.peakG >= this.config.fallImpactG) {
      this.impactAt = input.now;
      this.stillSince = -1;
      return;
    }
    if (this.impactAt < 0) {
      return;
    }
    if (input.immobile) {
      if (this.stillSince < 0) {
        if (input.now - this.impactAt > this.config.fallWindowMs) {
          this.impactAt = -1;
          return;
        }
        this.stillSince = input.now;
      }
    } else {
      this.stillSince = -1;
      if (input.now - this.impactAt > this.config.fallWindowMs) {
        this.impactAt = -1;
      }
    }
  }

  private fallConfirmed(now: number): boolean {
    return this.impactAt >= 0 && this.stillSince >= 0 && now - this.stillSince >= this.config.fallStillMs;
  }
}
