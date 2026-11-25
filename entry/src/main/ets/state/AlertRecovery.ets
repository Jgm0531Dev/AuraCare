import { AlertState } from '../model/Alert';
import { AlertReason } from '../model/AlertReason';

/**
 * Recuperación de una alerta tras segundo plano o reinicio (TS puro, testeable).
 * Descuenta el tiempo transcurrido; si la cuenta venció mientras tanto, pasa a Alerta activa.
 */

/** Alerta en curso tal como se persiste. */
export interface StoredAlert {
  state: AlertState;
  reason: AlertReason;
  /** Segundos restantes de la cuenta al guardar (0 en Alerta activa). */
  remainingSeconds: number;
  alertBpm: number;
  savedAt: number;
}

export interface RecoveryPlan {
  state: AlertState;
  reason: AlertReason;
  /** Restante ya descontado; <= 0 solo si state es AlertSent. */
  remainingSeconds: number;
  alertBpm: number;
}

const VALID_STATES: string[] = [AlertState.AreYouOk, AlertState.SosCountdown, AlertState.AlertSent];
const VALID_REASONS: string[] = [AlertReason.PulsoCritico, AlertReason.Caida, AlertReason.SosManual];

/** undefined = no hay nada que recuperar (sin alerta, None o datos corruptos). */
export function planRecovery(saved: StoredAlert | undefined, now: number): RecoveryPlan | undefined {
  if (saved === undefined || VALID_STATES.indexOf(saved.state) < 0) {
    return undefined;
  }
  const reason: AlertReason = VALID_REASONS.indexOf(saved.reason) >= 0 ? saved.reason : AlertReason.SosManual;
  const savedAt: number = Number.isFinite(saved.savedAt) ? saved.savedAt : now;
  const remaining: number = Number.isFinite(saved.remainingSeconds) ? saved.remainingSeconds : 0;
  const alertBpm: number = Number.isFinite(saved.alertBpm) ? saved.alertBpm : 0;
  // Un reloj atrasado (savedAt en el futuro) no suma tiempo.
  const elapsed: number = Math.max(0, (now - savedAt) / 1000);
  if (saved.state === AlertState.AlertSent) {
    return { state: AlertState.AlertSent, reason: reason, remainingSeconds: 0, alertBpm: alertBpm };
  }
  const left: number = remaining - elapsed;
  if (left <= 0) {
    return { state: AlertState.AlertSent, reason: reason, remainingSeconds: 0, alertBpm: alertBpm };
  }
  return { state: saved.state, reason: reason, remainingSeconds: left, alertBpm: alertBpm };
}
