import { describe, it, expect } from '@ohos/hypium';
import {
  AUTO_ALERT_DELAY_MS,
  ARE_YOU_OK_SECONDS,
  AutoAlertContext,
  Clock,
  EmergencyEffect,
  EmergencyEvent,
  EmergencyMachine,
  EmergencySnapshot,
  SENSITIVITY_THRESHOLDS,
  SOS_COUNTDOWN_SECONDS,
  SOS_HOLD_MS,
  VibrationPattern
} from '../main/ets/state/EmergencyMachine';
import { AlertState } from '../main/ets/model/Alert';
import { AlertReason } from '../main/ets/model/AlertReason';
import { PulseState } from '../main/ets/model/PulseState';

class FakeTimer {
  at: number = 0;
  callback: () => void = () => {};

  constructor(at: number, callback: () => void) {
    this.at = at;
    this.callback = callback;
  }
}

class FakeClock implements Clock {
  current: number = 1000;
  private nextId: number = 1;
  private timers: Map<number, FakeTimer> = new Map();

  now(): number {
    return this.current;
  }

  setTimeout(callback: () => void, delay: number): number {
    const id: number = this.nextId++;
    this.timers.set(id, new FakeTimer(this.current + delay, callback));
    return id;
  }

  clearTimeout(id: number): void {
    this.timers.delete(id);
  }

  advance(delay: number): void {
    const target: number = this.current + delay;
    while (true) {
      let nextId: number = -1;
      let nextAt: number = Number.MAX_SAFE_INTEGER;
      this.timers.forEach((timer: FakeTimer, id: number): void => {
        if (timer.at <= target && timer.at < nextAt) {
          nextId = id;
          nextAt = timer.at;
        }
      });
      if (nextId < 0) {
        break;
      }
      const timer: FakeTimer | undefined = this.timers.get(nextId);
      this.timers.delete(nextId);
      this.current = nextAt;
      if (timer !== undefined) {
        timer.callback();
      }
    }
    this.current = target;
  }

  count(): number {
    return this.timers.size;
  }
}

function autoContext(bpm: number, variant: PulseState, immobile: boolean): AutoAlertContext {
  const context: AutoAlertContext = {
    autoAlerts: true,
    exerciseMode: false,
    mode: 'live',
    bpm: bpm,
    sensitivity: 'Alta',
    variant: variant,
    movementImmobile: immobile
  };
  return context;
}

export default function emergencyMachineTest() {
  describe('EmergencyMachine', () => {
    it('dispara auto-alerta tras 3 s en crítico inmóvil', 0, () => {
      const clock: FakeClock = new FakeClock();
      const machine: EmergencyMachine = new EmergencyMachine(clock);
      const snapshots: EmergencySnapshot[] = [];
      machine.subscribe((snapshot: EmergencySnapshot): void => {
        snapshots.push(snapshot);
      });
      machine.updateAutoAlert(autoContext(132, PulseState.Critical, true));
      clock.advance(AUTO_ALERT_DELAY_MS - 1);
      expect(machine.getSnapshot().state).assertEqual(AlertState.None);
      clock.advance(1);
      expect(machine.getSnapshot().state).assertEqual(AlertState.AreYouOk);
      expect(snapshots[snapshots.length - 1].effect).assertEqual(EmergencyEffect.AutoAlert);
      expect(machine.getSnapshot().reason).assertEqual(AlertReason.PulsoCritico);
      machine.dispose();
    });

    it('no dispara auto-alerta en ejercicio, modo local o sin inmovilidad', 0, () => {
      const clock: FakeClock = new FakeClock();
      const machine: EmergencyMachine = new EmergencyMachine(clock);
      const noExercise: AutoAlertContext = autoContext(132, PulseState.Critical, true);
      noExercise.exerciseMode = true;
      machine.updateAutoAlert(noExercise);
      const offline: AutoAlertContext = autoContext(132, PulseState.Critical, true);
      offline.mode = 'offline';
      machine.updateAutoAlert(offline);
      machine.updateAutoAlert(autoContext(132, PulseState.Critical, false));
      machine.updateAutoAlert(autoContext(SENSITIVITY_THRESHOLDS.Alta - 1, PulseState.Elevated, true));
      clock.advance(AUTO_ALERT_DELAY_MS);
      expect(machine.getSnapshot().state).assertEqual(AlertState.None);
      machine.dispose();
    });

    it('cancela la auto-alerta si cambia el contexto antes de 3 s', 0, () => {
      const clock: FakeClock = new FakeClock();
      const machine: EmergencyMachine = new EmergencyMachine(clock);
      machine.updateAutoAlert(autoContext(132, PulseState.Critical, true));
      clock.advance(1000);
      machine.updateAutoAlert(autoContext(132, PulseState.Critical, false));
      clock.advance(AUTO_ALERT_DELAY_MS);
      expect(machine.getSnapshot().state).assertEqual(AlertState.None);
      machine.dispose();
    });

    it('SOS requiere 2 s y soltar antes cancela', 0, () => {
      const clock: FakeClock = new FakeClock();
      const machine: EmergencyMachine = new EmergencyMachine(clock);
      machine.startSosHold();
      clock.advance(SOS_HOLD_MS - 1);
      machine.cancelSosHold();
      clock.advance(1);
      expect(machine.getSnapshot().state).assertEqual(AlertState.None);
      machine.startSosHold();
      clock.advance(SOS_HOLD_MS);
      expect(machine.getSnapshot().state).assertEqual(AlertState.SosCountdown);
      expect(machine.getSnapshot().reason).assertEqual(AlertReason.SosManual);
      machine.dispose();
    });

    it('¿Estás bien? envía alerta a los 30 s y muestra aviso', 0, () => {
      const clock: FakeClock = new FakeClock();
      const machine: EmergencyMachine = new EmergencyMachine(clock);
      machine.dispatch(EmergencyEvent.SimularAlerta, { reason: AlertReason.Caida });
      expect(machine.getSnapshot().state).assertEqual(AlertState.AreYouOk);
      expect(machine.getSnapshot().remainingSeconds).assertEqual(ARE_YOU_OK_SECONDS);
      clock.advance(1000);
      expect(machine.getSnapshot().remainingSeconds).assertEqual(ARE_YOU_OK_SECONDS - 1);
      clock.advance((ARE_YOU_OK_SECONDS - 1) * 1000);
      expect(machine.getSnapshot().state).assertEqual(AlertState.AlertSent);
      expect(machine.getSnapshot().effect).assertEqual(EmergencyEffect.AlertSent);
      machine.dispose();
    });

    it('Estoy bien cancela y pedir ayuda confirma', 0, () => {
      const clock: FakeClock = new FakeClock();
      const machine: EmergencyMachine = new EmergencyMachine(clock);
      machine.dispatch(EmergencyEvent.SimularAlerta);
      machine.dispatch(EmergencyEvent.Safe);
      expect(machine.getSnapshot().state).assertEqual(AlertState.None);
      expect(machine.getSnapshot().effect).assertEqual(EmergencyEffect.ToastCancelled);
      machine.dispatch(EmergencyEvent.SimularAlerta);
      machine.dispatch(EmergencyEvent.Emergency);
      clock.advance(1000);
      machine.dispatch(EmergencyEvent.ConfirmNotify);
      expect(machine.getSnapshot().state).assertEqual(AlertState.None);
      expect(machine.getSnapshot().effect).assertEqual(EmergencyEffect.ToastNotified);
      machine.dispose();
    });

    it('SOS cuenta 5 s y Cancelar vuelve a none', 0, () => {
      const clock: FakeClock = new FakeClock();
      const machine: EmergencyMachine = new EmergencyMachine(clock);
      machine.dispatch(EmergencyEvent.SimularAlerta, { reason: AlertReason.SosManual });
      expect(machine.getSnapshot().state).assertEqual(AlertState.SosCountdown);
      expect(machine.getSnapshot().remainingSeconds).assertEqual(SOS_COUNTDOWN_SECONDS);
      machine.dispatch(EmergencyEvent.CancelSos);
      clock.advance(SOS_COUNTDOWN_SECONDS * 1000);
      expect(machine.getSnapshot().state).assertEqual(AlertState.None);
      machine.dispatch(EmergencyEvent.SimularAlerta, { reason: AlertReason.SosManual });
      clock.advance(SOS_COUNTDOWN_SECONDS * 1000);
      expect(machine.getSnapshot().state).assertEqual(AlertState.AlertSent);
      machine.dispose();
    });

    it('reenvía avisos y pausa si alguien va en camino', 0, () => {
      const clock: FakeClock = new FakeClock();
      const machine: EmergencyMachine = new EmergencyMachine(clock);
      machine.dispatch(EmergencyEvent.SimularAlerta);
      machine.dispatch(EmergencyEvent.Emergency);
      machine.setNoticeMinutes(1);
      clock.advance(1000);
      expect(machine.getSnapshot().nextNoticeSeconds).assertEqual(59);
      machine.setOnWay(true);
      clock.advance(2000);
      expect(machine.getSnapshot().nextNoticeSeconds).assertEqual(59);
      expect(clock.count()).assertEqual(0);
      machine.setOnWay(false);
      clock.advance(1000);
      expect(machine.getSnapshot().nextNoticeSeconds).assertEqual(58);
      machine.dispose();
    });

    it('emite vibración corta al entrar en ¿Estás bien? y triple en SOS', 0, () => {
      const clock: FakeClock = new FakeClock();
      const machine: EmergencyMachine = new EmergencyMachine(clock);
      const snapshots: EmergencySnapshot[] = [];
      machine.subscribe((snapshot: EmergencySnapshot): void => {
        snapshots.push(snapshot);
      });
      machine.dispatch(EmergencyEvent.SimularAlerta, { reason: AlertReason.Caida });
      expect(snapshots[snapshots.length - 1].vibration).assertEqual(VibrationPattern.Short);
      machine.dispatch(EmergencyEvent.Safe);
      machine.dispatch(EmergencyEvent.SimularAlerta, { reason: AlertReason.SosManual });
      expect(snapshots[snapshots.length - 1].vibration).assertEqual(VibrationPattern.Triple);
      machine.dispose();
    });

    it('Ver Alerta enviada abre la pantalla sin aviso de envío', 0, () => {
      const clock: FakeClock = new FakeClock();
      const machine: EmergencyMachine = new EmergencyMachine(clock);
      machine.dispatch(EmergencyEvent.ViewAlertSent);
      const snapshot: EmergencySnapshot = machine.getSnapshot();
      expect(snapshot.state).assertEqual(AlertState.AlertSent);
      expect(snapshot.effect).assertEqual(EmergencyEffect.AlertSentPreview);
      expect(snapshot.nextNoticeSeconds).assertEqual(300);
      expect(snapshot.vibration).assertEqual(VibrationPattern.None);
      machine.dispose();
    });
  });
}
