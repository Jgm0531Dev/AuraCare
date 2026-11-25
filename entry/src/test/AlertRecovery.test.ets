import { describe, it, expect } from '@ohos/hypium';
import { planRecovery, RecoveryPlan, StoredAlert } from '../main/ets/state/AlertRecovery';
import { AlertState } from '../main/ets/model/Alert';
import { AlertReason } from '../main/ets/model/AlertReason';

const NOW: number = 2000000;

function saved(state: AlertState, remaining: number, secondsAgo: number): StoredAlert {
  return {
    state: state,
    reason: AlertReason.Caida,
    remainingSeconds: remaining,
    alertBpm: 128,
    savedAt: NOW - secondsAgo * 1000
  };
}

export default function alertRecoveryTest() {
  describe('AlertRecovery (segundo plano / reinicio)', () => {
    it('alerta en curso: descuenta el tiempo transcurrido', 0, () => {
      const plan: RecoveryPlan | undefined = planRecovery(saved(AlertState.AreYouOk, 25, 10), NOW);
      expect(plan !== undefined).assertTrue();
      expect(plan!.state).assertEqual(AlertState.AreYouOk);
      expect(plan!.remainingSeconds).assertEqual(15);
      expect(plan!.reason).assertEqual(AlertReason.Caida);
      expect(plan!.alertBpm).assertEqual(128);
    });

    it('SOS en curso: descuenta y conserva el estado', 0, () => {
      const plan: RecoveryPlan | undefined = planRecovery(saved(AlertState.SosCountdown, 5, 2), NOW);
      expect(plan!.state).assertEqual(AlertState.SosCountdown);
      expect(plan!.remainingSeconds).assertEqual(3);
    });

    it('cuenta expirada mientras estaba en segundo plano: Alerta activa', 0, () => {
      const plan: RecoveryPlan | undefined = planRecovery(saved(AlertState.AreYouOk, 20, 45), NOW);
      expect(plan!.state).assertEqual(AlertState.AlertSent);
      expect(plan!.remainingSeconds).assertEqual(0);
    });

    it('expira justo en el límite (restante = transcurrido): Alerta activa', 0, () => {
      const plan: RecoveryPlan | undefined = planRecovery(saved(AlertState.SosCountdown, 5, 5), NOW);
      expect(plan!.state).assertEqual(AlertState.AlertSent);
    });

    it('Alerta activa guardada: sigue activa sin importar el tiempo', 0, () => {
      const plan: RecoveryPlan | undefined = planRecovery(saved(AlertState.AlertSent, 0, 3600), NOW);
      expect(plan!.state).assertEqual(AlertState.AlertSent);
    });

    it('sin alerta guardada (undefined o None): nada que recuperar', 0, () => {
      expect(planRecovery(undefined, NOW) === undefined).assertTrue();
      expect(planRecovery(saved(AlertState.None, 0, 1), NOW) === undefined).assertTrue();
    });

    it('datos corruptos: estado desconocido no se recupera; savedAt futuro no suma tiempo', 0, () => {
      const corrupt: StoredAlert = JSON.parse('{"state":"xyz","reason":"caida","remainingSeconds":10,"alertBpm":1,"savedAt":0}') as StoredAlert;
      expect(planRecovery(corrupt, NOW) === undefined).assertTrue();
      const future: RecoveryPlan | undefined = planRecovery(saved(AlertState.AreYouOk, 12, -30), NOW);
      expect(future!.remainingSeconds).assertEqual(12);
    });
  });
}
