import { describe, it, expect } from '@ohos/hypium';
import {
  RangeBucket,
  GENERAL_RANGE_MAX,
  GENERAL_RANGE_MIN,
  HOUR_MS,
  PersonalRange,
  RANGE_MIN_SAMPLES,
  RANGE_WINDOW_HOURS,
  RangeTracker
} from '../main/ets/state/RangeModel';

const T0: number = 1700000000000;

export default function rangeModelTest() {
  describe('RangeModel', () => {
    it('con pocas lecturas sigue calibrando y usa el rango general', 0, () => {
      const tracker: RangeTracker = new RangeTracker();
      for (let i = 0; i < RANGE_MIN_SAMPLES - 1; i++) {
        tracker.add(70, T0 + i * 1000);
      }
      const range: PersonalRange = tracker.compute(T0 + RANGE_MIN_SAMPLES * 1000);
      expect(range.ready).assertFalse();
      expect(range.min).assertEqual(GENERAL_RANGE_MIN);
      expect(range.max).assertEqual(GENERAL_RANGE_MAX);
    });

    it('con lecturas suficientes calcula media ± 2σ (ancho mínimo ±10)', 0, () => {
      const tracker: RangeTracker = new RangeTracker();
      // 66 / 74 alternados: media 70, σ = 4 -> 62-78.
      for (let i = 0; i < 1200; i++) {
        tracker.add(i % 2 === 0 ? 66 : 74, T0 + i * 1000);
      }
      const range: PersonalRange = tracker.compute(T0 + 1200 * 1000);
      expect(range.ready).assertTrue();
      expect(range.min).assertEqual(60);
      expect(range.max).assertEqual(80);
      const wide: RangeTracker = new RangeTracker();
      for (let i = 0; i < 1200; i++) {
        wide.add(i % 2 === 0 ? 55 : 85, T0 + i * 1000);
      }
      const wideRange: PersonalRange = wide.compute(T0 + 1200 * 1000);
      expect(wideRange.min).assertEqual(45);
      expect(wideRange.max).assertEqual(100);
    });

    it('exactamente 10 min (600 lecturas) deja de "aprender"', 0, () => {
      const tracker: RangeTracker = new RangeTracker();
      for (let i = 0; i < RANGE_MIN_SAMPLES; i++) {
        tracker.add(70, T0 + i * 1000);
      }
      const range: PersonalRange = tracker.compute(T0 + RANGE_MIN_SAMPLES * 1000);
      expect(RANGE_MIN_SAMPLES).assertEqual(600);
      expect(range.ready).assertTrue();
      expect(range.samples).assertEqual(600);
    });

    it('histórico vacío: aprendiendo, 0 lecturas, rango general', 0, () => {
      const range: PersonalRange = new RangeTracker([]).compute(T0);
      expect(range.ready).assertFalse();
      expect(range.samples).assertEqual(0);
      expect(range.min).assertEqual(GENERAL_RANGE_MIN);
      expect(range.max).assertEqual(GENERAL_RANGE_MAX);
    });

    it('histórico corrupto: se descartan los agregados inválidos sin fallar', 0, () => {
      const hour: number = Math.floor(T0 / HOUR_MS);
      const raw: string = `[{"hour":${hour}},{"hour":${hour},"count":5,"sum":"x","sumSq":null},` +
        `{"hour":${hour},"count":0,"sum":0,"sumSq":0},{"hour":${hour},"count":10,"sum":700,"sumSq":49000}]`;
      const buckets: RangeBucket[] = JSON.parse(raw) as RangeBucket[];
      const range: PersonalRange = new RangeTracker(buckets).compute(T0);
      expect(range.samples).assertEqual(10);
      expect(range.ready).assertFalse();
    });

    it('histórico corrupto que no es un array: vacío, sin excepción', 0, () => {
      const notArray: RangeBucket[] = JSON.parse('{"buckets":3}') as RangeBucket[];
      const range: PersonalRange = new RangeTracker(notArray).compute(T0);
      expect(range.samples).assertEqual(0);
      expect(range.ready).assertFalse();
    });

    it('valores atípicos (artefactos) no cambian el rango', 0, () => {
      const tracker: RangeTracker = new RangeTracker();
      for (let i = 0; i < 1200; i++) {
        tracker.add(i % 2 === 0 ? 66 : 74, T0 + i * 1000);
      }
      tracker.add(0, T0 + 1201000);
      tracker.add(5, T0 + 1202000);
      tracker.add(250, T0 + 1203000);
      const range: PersonalRange = tracker.compute(T0 + 1204000);
      expect(range.samples).assertEqual(1200);
      expect(range.min).assertEqual(60);
      expect(range.max).assertEqual(80);
    });

    it('lecturas de hace más de 7 días se descartan y las recientes se conservan', 0, () => {
      const tracker: RangeTracker = new RangeTracker();
      for (let i = 0; i < 500; i++) {
        tracker.add(70, T0 + i * 1000);
      }
      const recent: number = T0 + RANGE_WINDOW_HOURS * HOUR_MS;
      for (let i = 0; i < 300; i++) {
        tracker.add(70, recent + i * 1000);
      }
      expect(tracker.compute(recent + 300000).samples).assertEqual(300);
    });

    it('descarta lecturas fuera de rango fisiológico', 0, () => {
      const tracker: RangeTracker = new RangeTracker();
      tracker.add(0, T0);
      tracker.add(10, T0);
      tracker.add(300, T0);
      expect(tracker.compute(T0).samples).assertEqual(0);
    });

    it('olvida lo anterior a 7 días', 0, () => {
      const tracker: RangeTracker = new RangeTracker();
      for (let i = 0; i < 1000; i++) {
        tracker.add(70, T0 + i * 1000);
      }
      const later: number = T0 + (RANGE_WINDOW_HOURS + 2) * HOUR_MS;
      const range: PersonalRange = tracker.compute(later);
      expect(range.samples).assertEqual(0);
      expect(range.ready).assertFalse();
    });

    it('se reconstruye desde los agregados persistidos', 0, () => {
      const tracker: RangeTracker = new RangeTracker();
      for (let i = 0; i < 900; i++) {
        tracker.add(72, T0 + i * 1000);
      }
      const restored: RangeTracker = new RangeTracker(tracker.getBuckets());
      expect(restored.compute(T0 + 900 * 1000).samples).assertEqual(900);
    });
  });
}
