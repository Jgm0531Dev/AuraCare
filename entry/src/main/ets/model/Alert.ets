import { AlertReason } from './AlertReason';

export enum AlertState {
  None = 'none',
  AreYouOk = 'are-you-ok',
  SosCountdown = 'sos-countdown',
  AlertSent = 'alert-sent'
}

export interface Alert {
  state: AlertState;
  reason: AlertReason;
  startedAt: number;
}
