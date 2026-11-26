import { describe, it, expect } from '@ohos/hypium';
import {
  AnomalyEngine,
  AnomalyInput,
  AnomalyResult,
  DEFAULT_ANOMALY_CONFIG,
  classifyPulse,
  isPlausibleBpm,
  MAX_VALID_BPM
} from '../main/ets/state/AnomalyEngine';
import { GRAVITY_MS2, MotionClassifier, MotionKind } from '../main/ets/state/MotionClassifier';
import { AlertReason } from '../main/ets/model/AlertReason';
import { PulseState } from '../main/ets/model/PulseState';

const SAMPLE_MS: number = 200;   // acelerómetro a 5 Hz (como RealSensorProvider)
const TICK_MS: number = 1000;    // SensorService evalúa cada segundo
const MOTION_FRESH_MS: number = 3000;

type Pattern = 'walk' | 'still' | 'impact';

/**
 * Simulación del camino real: muestras x/y/z sintéticas -> MotionClassifier -> AnomalyEngine,
 * con el tiempo controlado por el test (sin temporizadores).
 */
class Sim {
  now: number = 1000000;
  readonly motion: MotionClassifier = new MotionClassifier();
  readonly engine: AnomalyEngine = new AnomalyEngine();
  bpm: number = 75;
  heartRateValid: boolean = true;
  exerciseMode: boolean = false;
  fallDetection: boolean = true;
  triggers: AlertReason[] = [];
  firstTriggerAt: number = -1;
  private step: number = 0;
  private sinceTick: number = 0;

  private sample(pattern: Pattern): void {
    let z: number = GRAVITY_MS2;
    if (pattern === 'walk') {
      // Oscilación de ±3 m/s² (paso normal, ~1,3 g de pico).
      z = GRAVITY_MS2 + (this.step % 2 === 0 ? 3 : -3);
    } else if (pattern === 'still') {
      z = GRAVITY_MS2 + (this.step % 2 === 0 ? 0.02 : -0.02);
    } else {
      z = GRAVITY_MS2 * 3;   // golpe de 3 g
    }
    this.step += 1;
    this.motion.add(0, 0, z, this.now);
  }

  private tick(): void {
    const valid: boolean = this.motion.isValid(this.now, MOTION_FRESH_MS);
    const result: AnomalyResult = this.engine.update({
      now: this.now,
      bpm: this.bpm,
      heartRateValid: this.heartRateValid,
      motionValid: valid,
      immobile: valid && this.motion.isImmobile(),
      peakG: valid ? this.motion.takePeakG() : 0,
      exerciseMode: this.exerciseMode,
      fallDetection: this.fallDetection
    });
    if (result.trigger !== undefined) {
      this.triggers.push(result.trigger);
      if (this.firstTriggerAt < 0) {
        this.firstTriggerAt = this.now;
      }
    }
  }

  /** Avanza `ms` con el patrón dado (una muestra cada 200 ms, una evaluación cada segundo). */
  run(pattern: Pattern, ms: number): void {
    const end: number = this.now + ms;
    while (this.now < end) {
      this.now += SAMPLE_MS;
      this.sample(pattern);
      this.sinceTick += SAMPLE_MS;
      if (this.sinceTick >= TICK_MS) {
        this.sinceTick = 0;
        this.tick();
      }
    }
  }

  impact(): void {
    this.now += SAMPLE_MS;
    this.sample('impact');
    this.sinceTick += SAMPLE_MS;
  }
}

/** Entrada directa (sin simulación de muestras) para los casos borde con timestamps exactos. */
function input(now: number, bpm: number, immobile: boolean): AnomalyInput {
  return {
    now: now,
    bpm: bpm,
    heartRateValid: true,
    motionValid: true,
    immobile: immobile,
    peakG: 1,
    exerciseMode: false,
    fallDetection: true
  };
}

export default function anomalyEngineTest() {
  describe('MotionClassifier', () => {
    it('clasifica quieto, reposo y caminar', 0, () => {
      const sim: Sim = new Sim();
      sim.run('still', 6000);
      expect(sim.motion.getKind()).assertEqual(MotionKind.Immobile);
      sim.run('walk', 6000);
      expect(sim.motion.getKind()).assertEqual(MotionKind.Walking);
    });

    it('sin muestras suficientes no es válido', 0, () => {
      const motion: MotionClassifier = new MotionClassifier();
      motion.add(0, 0, GRAVITY_MS2, 1000);
      expect(motion.isValid(1000, MOTION_FRESH_MS)).assertFalse();
      expect(motion.getKind()).assertEqual(MotionKind.Unknown);
    });

    it('registra el pico en g y lo reinicia al leerlo', 0, () => {
      const motion: MotionClassifier = new MotionClassifier();
      motion.add(0, 0, GRAVITY_MS2 * 3, 1000);
      expect(motion.takePeakG()).assertLarger(2.9);
      expect(motion.takePeakG()).assertEqual(0);
    });
  });

  describe('AnomalyEngine caídas (muestras sintéticas)', () => {
    it('golpe + inmovilidad -> Caida', 0, () => {
      const sim: Sim = new Sim();
      sim.run('walk', 3000);
      sim.impact();
      sim.run('still', 25000);
      expect(sim.triggers.length).assertEqual(1);
      expect(sim.triggers[0]).assertEqual(AlertReason.Caida);
    });

    it('golpe + 2 s de movimiento + inmovilidad -> Caida (margen real tras caer)', 0, () => {
      const sim: Sim = new Sim();
      sim.run('walk', 3000);
      sim.impact();
      sim.run('walk', 2000);
      sim.run('still', 25000);
      expect(sim.triggers.length).assertEqual(1);
      expect(sim.triggers[0]).assertEqual(AlertReason.Caida);
    });

    it('golpe sin inmovilidad (sigue caminando) -> nada', 0, () => {
      const sim: Sim = new Sim();
      sim.run('walk', 3000);
      sim.impact();
      sim.run('walk', 30000);
      expect(sim.triggers.length).assertEqual(0);
    });

    it('movimiento normal prolongado -> nada', 0, () => {
      const sim: Sim = new Sim();
      sim.run('walk', 60000);
      sim.run('still', 30000);
      expect(sim.triggers.length).assertEqual(0);
    });

    it('golpe + inmovilidad con detección de caídas apagada -> nada', 0, () => {
      const sim: Sim = new Sim();
      sim.fallDetection = false;
      sim.run('walk', 3000);
      sim.impact();
      sim.run('still', 25000);
      expect(sim.triggers.length).assertEqual(0);
    });

    it('inmovilidad tardía (más allá de la ventana) tras el golpe -> nada', 0, () => {
      const sim: Sim = new Sim();
      sim.run('walk', 3000);
      sim.impact();
      sim.run('walk', DEFAULT_ANOMALY_CONFIG.fallWindowMs + 3000);
      sim.run('still', 25000);
      expect(sim.triggers.length).assertEqual(0);
    });
  });

  describe('AnomalyEngine pulso', () => {
    it('pulso alto en reposo sostenido 10 s -> PulsoCritico', 0, () => {
      const sim: Sim = new Sim();
      sim.run('still', 6000);
      sim.bpm = 130;
      const start: number = sim.now;
      sim.run('still', 15000);
      expect(sim.triggers.length).assertEqual(1);
      expect(sim.triggers[0]).assertEqual(AlertReason.PulsoCritico);
      expect(sim.firstTriggerAt - start).assertLarger(DEFAULT_ANOMALY_CONFIG.sustainMs - 1);
    });

    it('pulso alto caminando -> nada', 0, () => {
      const sim: Sim = new Sim();
      sim.bpm = 130;
      sim.run('walk', 30000);
      expect(sim.triggers.length).assertEqual(0);
    });

    it('pulso alto en modo ejercicio -> nada; pulso < 40 sí dispara', 0, () => {
      const sim: Sim = new Sim();
      sim.exerciseMode = true;
      sim.bpm = 140;
      sim.run('still', 20000);
      expect(sim.triggers.length).assertEqual(0);
      sim.bpm = 35;
      sim.run('still', 15000);
      expect(sim.triggers.length).assertEqual(1);
      expect(sim.triggers[0]).assertEqual(AlertReason.PulsoCritico);
    });

    it('condición interrumpida antes de 10 s -> nada', 0, () => {
      const sim: Sim = new Sim();
      sim.run('still', 6000);
      sim.bpm = 125;
      sim.run('still', 8000);
      sim.bpm = 80;
      sim.run('still', 2000);
      sim.bpm = 125;
      sim.run('still', 8000);
      expect(sim.triggers.length).assertEqual(0);
    });

    it('sin lectura de pulso válida -> nada', 0, () => {
      const sim: Sim = new Sim();
      sim.heartRateValid = false;
      sim.bpm = 150;
      sim.run('still', 30000);
      expect(sim.triggers.length).assertEqual(0);
    });

    it('tras disparar, silencio durante cooldownMs', 0, () => {
      const sim: Sim = new Sim();
      sim.run('still', 6000);
      sim.bpm = 130;
      sim.run('still', DEFAULT_ANOMALY_CONFIG.sustainMs + 2000);
      expect(sim.triggers.length).assertEqual(1);
      sim.run('still', DEFAULT_ANOMALY_CONFIG.cooldownMs - 20000);
      expect(sim.triggers.length).assertEqual(1);
      sim.run('still', 40000);
      expect(sim.triggers.length).assertEqual(2);
    });
  });

  describe('AnomalyEngine casos borde (timestamps exactos)', () => {
    it('pulso alto en reposo: 9,9 s no dispara, exactamente 10 s sí', 0, () => {
      const engine: AnomalyEngine = new AnomalyEngine();
      const t0: number = 50000;
      expect(engine.update(input(t0, 130, true)).trigger === undefined).assertTrue();
      expect(engine.update(input(t0 + 9900, 130, true)).trigger === undefined).assertTrue();
      expect(engine.update(input(t0 + 10000, 130, true)).trigger).assertEqual(AlertReason.PulsoCritico);
    });

    it('pulso < 40: 9,9 s no dispara, exactamente 10 s sí (aunque se mueva)', 0, () => {
      const engine: AnomalyEngine = new AnomalyEngine();
      const t0: number = 50000;
      engine.update(input(t0, 38, false));
      expect(engine.update(input(t0 + 9900, 38, false)).trigger === undefined).assertTrue();
      expect(engine.update(input(t0 + 10000, 38, false)).trigger).assertEqual(AlertReason.PulsoCritico);
    });

    it('lectura "--" (bpm 0 o heartRateValid=false) nunca dispara', 0, () => {
      const engine: AnomalyEngine = new AnomalyEngine();
      for (let t = 0; t <= 60000; t += 1000) {
        const noSensor: AnomalyInput = input(t, 0, true);
        expect(engine.update(noSensor).trigger === undefined).assertTrue();
        const noPermission: AnomalyInput = input(t, 150, true);
        noPermission.heartRateValid = false;
        noPermission.motionValid = false;
        expect(engine.update(noPermission).trigger === undefined).assertTrue();
      }
    });

    it('pausa de 2 min tras "Estoy bien" (snooze): no dispara antes, sí después', 0, () => {
      const engine: AnomalyEngine = new AnomalyEngine();
      const okAt: number = 100000;
      engine.snooze(okAt);
      let fired: number = -1;
      for (let t = okAt; t <= okAt + 200000; t += 1000) {
        if (engine.update(input(t, 130, true)).trigger !== undefined && fired < 0) {
          fired = t;
        }
      }
      expect(fired >= okAt + DEFAULT_ANOMALY_CONFIG.cooldownMs).assertTrue();
      expect(fired <= okAt + DEFAULT_ANOMALY_CONFIG.cooldownMs + 1000).assertTrue();
    });

    it('modo ejercicio: pulso alto en reposo 60 s no dispara', 0, () => {
      const engine: AnomalyEngine = new AnomalyEngine();
      for (let t = 0; t <= 60000; t += 1000) {
        const exercise: AnomalyInput = input(t, 150, true);
        exercise.exerciseMode = true;
        expect(engine.update(exercise).trigger === undefined).assertTrue();
      }
    });
  });

  describe('classifyPulse', () => {
    it('normal, elevado y crítico según rango y umbral', 0, () => {
      const config = DEFAULT_ANOMALY_CONFIG;
      expect(classifyPulse(70, 55, 90, config)).assertEqual(PulseState.Normal);
      expect(classifyPulse(95, 55, 90, config)).assertEqual(PulseState.Elevated);
      expect(classifyPulse(50, 55, 90, config)).assertEqual(PulseState.Elevated);
      expect(classifyPulse(config.highBpm, 55, 90, config)).assertEqual(PulseState.Critical);
      expect(classifyPulse(35, 55, 90, config)).assertEqual(PulseState.Critical);
      expect(classifyPulse(0, 55, 90, config)).assertEqual(PulseState.Normal);
    });
  });

  describe('isPlausibleBpm', () => {
    it('descarta 0, negativos, NaN e imposibles (> 250)', 0, () => {
      expect(isPlausibleBpm(0)).assertFalse();
      expect(isPlausibleBpm(-5)).assertFalse();
      expect(isPlausibleBpm(NaN)).assertFalse();
      expect(isPlausibleBpm(Infinity)).assertFalse();
      expect(isPlausibleBpm(MAX_VALID_BPM + 1)).assertFalse();
      expect(isPlausibleBpm(300)).assertFalse();
    });
    it('acepta valores reales, incluidos los límites', 0, () => {
      expect(isPlausibleBpm(1)).assertTrue();
      expect(isPlausibleBpm(38)).assertTrue();
      expect(isPlausibleBpm(72)).assertTrue();
      expect(isPlausibleBpm(MAX_VALID_BPM)).assertTrue();
    });
  });
}
