/**
 * Rango normal personal a partir de lecturas reales acumuladas (TS puro, sin UI).
 * Se guardan agregados por hora (n, suma, suma de cuadrados) de los últimos 7 días:
 * rango = media ± 2 desviaciones, con un ancho mínimo y límites fisiológicos.
 */

export interface RangeBucket {
  /** Hora absoluta: floor(ms / 3 600 000). */
  hour: number;
  count: number;
  sum: number;
  sumSq: number;
}

export interface PersonalRange {
  /** false = aún calibrando (se usa el rango general 60-100). */
  ready: boolean;
  min: number;
  max: number;
  mean: number;
  samples: number;
}

export const HOUR_MS: number = 3600000;
export const RANGE_WINDOW_HOURS: number = 168;
/** ~10 minutos de lecturas a 1 Hz antes de mostrar un rango personal. */
export const RANGE_MIN_SAMPLES: number = 600;
export const GENERAL_RANGE_MIN: number = 60;
export const GENERAL_RANGE_MAX: number = 100;
const RANGE_FLOOR: number = 45;
const RANGE_CEIL: number = 120;
const RANGE_MIN_HALF_WIDTH: number = 10;
const VALID_MIN_BPM: number = 30;
const VALID_MAX_BPM: number = 220;

export class RangeTracker {
  private buckets: RangeBucket[] = [];

  /** Tolera histórico corrupto (no-array, campos ausentes o no numéricos): lo inválido se descarta. */
  constructor(buckets: RangeBucket[] = []) {
    if (!Array.isArray(buckets)) {
      this.buckets = [];
      return;
    }
    this.buckets = buckets.filter((bucket: RangeBucket): boolean =>
      bucket !== null && typeof bucket === 'object' && Number.isFinite(bucket.hour) &&
      Number.isFinite(bucket.count) && bucket.count > 0 &&
      Number.isFinite(bucket.sum) && Number.isFinite(bucket.sumSq));
  }

  getBuckets(): RangeBucket[] {
    return this.buckets.slice();
  }

  clear(): void {
    this.buckets = [];
  }

  /** Añade una lectura válida; descarta valores fuera de rango fisiológico. */
  add(bpm: number, now: number): void {
    if (bpm < VALID_MIN_BPM || bpm > VALID_MAX_BPM) {
      return;
    }
    const hour: number = Math.floor(now / HOUR_MS);
    let bucket: RangeBucket | undefined = this.buckets.find((item: RangeBucket): boolean => item.hour === hour);
    if (bucket === undefined) {
      bucket = { hour: hour, count: 0, sum: 0, sumSq: 0 };
      this.buckets.push(bucket);
    }
    bucket.count += 1;
    bucket.sum += bpm;
    bucket.sumSq += bpm * bpm;
    this.prune(hour);
  }

  compute(now: number): PersonalRange {
    this.prune(Math.floor(now / HOUR_MS));
    let count: number = 0;
    let sum: number = 0;
    let sumSq: number = 0;
    this.buckets.forEach((bucket: RangeBucket): void => {
      count += bucket.count;
      sum += bucket.sum;
      sumSq += bucket.sumSq;
    });
    if (count < RANGE_MIN_SAMPLES) {
      return { ready: false, min: GENERAL_RANGE_MIN, max: GENERAL_RANGE_MAX, mean: count > 0 ? sum / count : 0, samples: count };
    }
    const mean: number = sum / count;
    const variance: number = Math.max(0, sumSq / count - mean * mean);
    const halfWidth: number = Math.max(RANGE_MIN_HALF_WIDTH, 2 * Math.sqrt(variance));
    const min: number = Math.max(RANGE_FLOOR, Math.round(mean - halfWidth));
    const max: number = Math.min(RANGE_CEIL, Math.round(mean + halfWidth));
    return { ready: true, min: min, max: max, mean: mean, samples: count };
  }

  private prune(currentHour: number): void {
    const oldest: number = currentHour - RANGE_WINDOW_HOURS + 1;
    this.buckets = this.buckets.filter((bucket: RangeBucket): boolean => bucket.hour >= oldest);
  }
}
