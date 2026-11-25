/**
 * Clasificación de movimiento a partir de muestras del acelerómetro (TS puro, testeable con
 * muestras sintéticas). Desviación = | |a| - g |; ventana deslizante de 5 s.
 */

export const GRAVITY_MS2: number = 9.81;
export const MOVEMENT_WINDOW_MS: number = 5000;
export const IMMOBILE_AVG: number = 0.12;
export const IMMOBILE_MAX: number = 0.25;
export const RESTING_AVG: number = 0.55;
export const MIN_MOTION_SAMPLES: number = 4;

export enum MotionKind {
  Unknown = 'unknown',
  Immobile = 'immobile',
  Resting = 'resting',
  Walking = 'walking'
}

class MotionSample {
  timestamp: number = 0;
  deviation: number = 0;
}

export class MotionClassifier {
  private samples: MotionSample[] = [];
  private kind: MotionKind = MotionKind.Unknown;
  private peakG: number = 0;
  private lastAt: number = 0;

  /** Añade una muestra (m/s²) y devuelve la magnitud en m/s². */
  add(x: number, y: number, z: number, now: number): number {
    const magnitude: number = Math.sqrt(x * x + y * y + z * z);
    this.peakG = Math.max(this.peakG, magnitude / GRAVITY_MS2);
    this.lastAt = now;
    this.samples = this.samples.filter((sample: MotionSample): boolean => now - sample.timestamp <= MOVEMENT_WINDOW_MS);
    const sample: MotionSample = new MotionSample();
    sample.timestamp = now;
    sample.deviation = Math.abs(magnitude - GRAVITY_MS2);
    this.samples.push(sample);
    if (this.samples.length < MIN_MOTION_SAMPLES) {
      this.kind = MotionKind.Unknown;
      return magnitude;
    }
    let sum: number = 0;
    let max: number = 0;
    this.samples.forEach((item: MotionSample): void => {
      sum += item.deviation;
      max = Math.max(max, item.deviation);
    });
    const average: number = sum / this.samples.length;
    if (average < IMMOBILE_AVG && max < IMMOBILE_MAX) {
      this.kind = MotionKind.Immobile;
    } else if (average < RESTING_AVG) {
      this.kind = MotionKind.Resting;
    } else {
      this.kind = MotionKind.Walking;
    }
    return magnitude;
  }

  getKind(): MotionKind {
    return this.kind;
  }

  isImmobile(): boolean {
    return this.kind === MotionKind.Immobile;
  }

  /** Hay suficientes muestras recientes para afirmar algo sobre el movimiento. */
  isValid(now: number, freshMs: number): boolean {
    return this.lastAt > 0 && now - this.lastAt <= freshMs && this.samples.length >= MIN_MOTION_SAMPLES;
  }

  /** Pico (en g) desde la última llamada; se reinicia al leerlo. */
  takePeakG(): number {
    const peak: number = this.peakG;
    this.peakG = 0;
    return peak;
  }

  peekPeakG(): number {
    return this.peakG;
  }

  lastSampleAt(): number {
    return this.lastAt;
  }

  reset(): void {
    this.samples = [];
    this.kind = MotionKind.Unknown;
    this.peakG = 0;
    this.lastAt = 0;
  }
}
