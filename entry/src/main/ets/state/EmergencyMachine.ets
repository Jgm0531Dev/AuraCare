import { AlertState } from '../model/Alert';
import { AlertReason } from '../model/AlertReason';
import { PulseState } from '../model/PulseState';

/** Reloj y temporizadores inyectados: la máquina no usa APIs del sistema. */
export interface Clock {
  now(): number;
  setTimeout(callback: () => void, delay: number): number;
  clearTimeout(id: number): void;
}

export type WatchMode = 'live' | 'offline' | 'first-use';
export type Sensitivity = 'Baja' | 'Media' | 'Alta';

export interface SensitivityThresholds {
  Baja: number;
  Media: number;
  Alta: number;
}

export const SENSITIVITY_THRESHOLDS: SensitivityThresholds = {
  Baja: 130,
  Media: 110,
  Alta: 100
};

export const AUTO_ALERT_DELAY_MS: number = 3000;
export const SOS_HOLD_MS: number = 2000;
export const ARE_YOU_OK_SECONDS: number = 30;
export const SOS_COUNTDOWN_SECONDS: number = 5;

export interface AutoAlertContext {
  autoAlerts: boolean;
  exerciseMode: boolean;
  mode: WatchMode;
  bpm: number;
  sensitivity: Sensitivity;
  variant: PulseState;
  movementImmobile: boolean;
}

export enum EmergencyEvent {
  AutoAlert,
  SosHold,
  SimularAlerta,
  Safe,
  Emergency,
  CancelSos,
  ConfirmNotify,
  ViewAlertSent
}

export enum EmergencyEffect {
  None,
  AutoAlert,
  AreYouOkEnter,
  SosEnter,
  AlertSent,
  AlertSentPreview,
  ToastCancelled,
  ToastNotified
}

/** Patrones de vibración solicitados por la máquina; el servicio los ejecuta. */
export enum VibrationPattern {
  None,
  Short,
  Triple
}

export interface EmergencyDispatch {
  reason?: AlertReason;
  noticeMinutes?: number;
  onWay?: boolean;
}

export interface EmergencySnapshot {
  state: AlertState;
  reason: AlertReason;
  startedAt: number;
  remainingSeconds: number;
  autoAlertFired: boolean;
  nextNoticeSeconds: number;
  onWayPaused: boolean;
  effect: EmergencyEffect;
  effectToken: number;
  vibration: VibrationPattern;
}

export type EmergencyListener = (snapshot: EmergencySnapshot) => void;

export class EmergencyMachine {
  private state: AlertState = AlertState.None;
  private reason: AlertReason = AlertReason.PulsoCritico;
  private startedAt: number = 0;
  private remainingSeconds: number = 0;
  private effect: EmergencyEffect = EmergencyEffect.None;
  private effectToken: number = 0;
  private vibration: VibrationPattern = VibrationPattern.None;
  private autoAlertFired: boolean = false;
  private lastGuardKey: string = '';
  private noticeMinutes: number = 5;
  private noticeSeconds: number = 300;
  private nextNoticeSeconds: number = 300;
  private onWay: boolean = false;
  private autoAlertTimer: number | undefined = undefined;
  private sosHoldTimer: number | undefined = undefined;
  private countdownTimer: number | undefined = undefined;
  private noticeTimer: number | undefined = undefined;
  private listeners: EmergencyListener[] = [];
  private readonly clock: Clock;

  constructor(clock: Clock) {
    this.clock = clock;
  }

  subscribe(listener: EmergencyListener): () => void {
    this.listeners.push(listener);
    return (): void => {
      const index: number = this.listeners.indexOf(listener);
      if (index >= 0) {
        this.listeners.splice(index, 1);
      }
    };
  }

  getSnapshot(): EmergencySnapshot {
    return {
      state: this.state,
      reason: this.reason,
      startedAt: this.startedAt,
      remainingSeconds: this.remainingSeconds,
      autoAlertFired: this.autoAlertFired,
      nextNoticeSeconds: this.nextNoticeSeconds,
      onWayPaused: this.onWay,
      effect: this.effect,
      effectToken: this.effectToken,
      vibration: this.vibration
    };
  }

  /** Reevalúa la auto-alerta; un cambio en las entradas reinicia `autoAlertFired`. */
  updateAutoAlert(context: AutoAlertContext): void {
    const guardKey: string = [
      context.autoAlerts,
      context.exerciseMode,
      context.mode,
      context.sensitivity,
      context.variant,
      context.movementImmobile
    ].join('|');
    if (guardKey !== this.lastGuardKey) {
      this.lastGuardKey = guardKey;
      this.autoAlertFired = false;
      this.clearAutoAlertTimer();
    }
    if (this.state !== AlertState.None || this.autoAlertFired || !this.canAutoAlert(context)) {
      return;
    }
    this.autoAlertTimer = this.clock.setTimeout((): void => {
      this.autoAlertTimer = undefined;
      if (this.state !== AlertState.None) {
        return;
      }
      this.autoAlertFired = true;
      this.dispatch(EmergencyEvent.AutoAlert, { reason: AlertReason.PulsoCritico });
    }, AUTO_ALERT_DELAY_MS);
  }

  startSosHold(): void {
    if (this.state !== AlertState.None) {
      return;
    }
    this.clearSosHoldTimer();
    this.sosHoldTimer = this.clock.setTimeout((): void => {
      this.sosHoldTimer = undefined;
      this.dispatch(EmergencyEvent.SosHold);
    }, SOS_HOLD_MS);
  }

  cancelSosHold(): void {
    this.clearSosHoldTimer();
  }

  setNoticeMinutes(minutes: number): void {
    this.noticeMinutes = minutes;
    if (this.state === AlertState.AlertSent) {
      this.noticeSeconds = minutes * 60;
      this.nextNoticeSeconds = this.noticeSeconds;
      this.clearNoticeTimer();
      if (!this.onWay) {
        this.scheduleNoticeTick();
      }
    }
    this.notify();
  }

  setOnWay(onWay: boolean): void {
    this.onWay = onWay;
    if (this.state === AlertState.AlertSent) {
      this.clearNoticeTimer();
      if (!onWay) {
        this.scheduleNoticeTick();
      }
    }
    this.notify();
  }

  dispatch(event: EmergencyEvent, payload: EmergencyDispatch = {}): void {
    switch (event) {
      case EmergencyEvent.AutoAlert:
        if (this.state === AlertState.None) {
          this.enterAreYouOk(payload.reason ?? AlertReason.PulsoCritico);
          this.setEffect(EmergencyEffect.AutoAlert);
          this.notify();
        }
        break;
      case EmergencyEvent.SosHold:
        if (this.state === AlertState.None) {
          this.enterSosCountdown();
        }
        break;
      case EmergencyEvent.SimularAlerta: {
        const reason: AlertReason = payload.reason ?? this.reason;
        if (reason === AlertReason.SosManual) {
          this.enterSosCountdown();
        } else {
          this.enterAreYouOk(reason);
        }
        break;
      }
      case EmergencyEvent.Safe:
        this.resetToNone(EmergencyEffect.ToastCancelled);
        break;
      case EmergencyEvent.Emergency:
        this.enterAlertSent();
        break;
      case EmergencyEvent.CancelSos:
        if (this.state === AlertState.SosCountdown) {
          this.resetToNone(EmergencyEffect.None);
        }
        break;
      case EmergencyEvent.ConfirmNotify:
        this.resetToNone(EmergencyEffect.ToastNotified);
        break;
      case EmergencyEvent.ViewAlertSent:
        if (this.state !== AlertState.AlertSent) {
          this.enterAlertSent(EmergencyEffect.AlertSentPreview);
        }
        break;
      default:
        break;
    }
  }

  dispose(): void {
    this.clearAutoAlertTimer();
    this.clearSosHoldTimer();
    this.clearCountdownTimer();
    this.clearNoticeTimer();
    this.listeners = [];
  }

  private canAutoAlert(context: AutoAlertContext): boolean {
    if (!context.autoAlerts || context.exerciseMode || context.mode !== 'live') {
      return false;
    }
    let threshold: number = SENSITIVITY_THRESHOLDS.Alta;
    if (context.sensitivity === 'Baja') {
      threshold = SENSITIVITY_THRESHOLDS.Baja;
    } else if (context.sensitivity === 'Media') {
      threshold = SENSITIVITY_THRESHOLDS.Media;
    }
    if (context.bpm < threshold) {
      return false;
    }
    if (context.variant === PulseState.Critical && !context.movementImmobile) {
      return false;
    }
    return true;
  }

  private enterAreYouOk(reason: AlertReason): void {
    this.clearSosHoldTimer();
    this.clearCountdownTimer();
    this.clearNoticeTimer();
    this.state = AlertState.AreYouOk;
    this.reason = reason;
    this.startedAt = this.clock.now();
    this.remainingSeconds = ARE_YOU_OK_SECONDS;
    this.setEffect(EmergencyEffect.AreYouOkEnter);
    this.vibration = VibrationPattern.Short;
    this.scheduleCountdownTick();
    this.notify();
  }

  private enterSosCountdown(): void {
    this.clearSosHoldTimer();
    this.clearCountdownTimer();
    this.clearNoticeTimer();
    this.state = AlertState.SosCountdown;
    this.reason = AlertReason.SosManual;
    this.startedAt = this.clock.now();
    this.remainingSeconds = SOS_COUNTDOWN_SECONDS;
    this.setEffect(EmergencyEffect.SosEnter);
    this.vibration = VibrationPattern.Triple;
    this.scheduleCountdownTick();
    this.notify();
  }

  private enterAlertSent(effect: EmergencyEffect = EmergencyEffect.AlertSent): void {
    this.clearCountdownTimer();
    this.clearSosHoldTimer();
    this.state = AlertState.AlertSent;
    this.startedAt = this.clock.now();
    this.remainingSeconds = 0;
    this.setEffect(effect);
    this.noticeSeconds = this.noticeMinutes * 60;
    this.nextNoticeSeconds = this.noticeSeconds;
    this.clearNoticeTimer();
    if (!this.onWay) {
      this.scheduleNoticeTick();
    }
    this.notify();
  }

  private resetToNone(effect: EmergencyEffect): void {
    this.clearSosHoldTimer();
    this.clearCountdownTimer();
    this.clearNoticeTimer();
    this.state = AlertState.None;
    this.remainingSeconds = 0;
    this.setEffect(effect);
    this.notify();
  }

  private scheduleCountdownTick(): void {
    this.countdownTimer = this.clock.setTimeout((): void => {
      this.countdownTimer = undefined;
      if (this.state !== AlertState.AreYouOk && this.state !== AlertState.SosCountdown) {
        return;
      }
      this.remainingSeconds = Math.max(0, this.remainingSeconds - 1);
      if (this.remainingSeconds === 0) {
        this.dispatch(EmergencyEvent.Emergency);
        return;
      }
      this.notify();
      this.scheduleCountdownTick();
    }, 1000);
  }

  private scheduleNoticeTick(): void {
    this.noticeTimer = this.clock.setTimeout((): void => {
      this.noticeTimer = undefined;
      if (this.state !== AlertState.AlertSent || this.onWay) {
        return;
      }
      this.nextNoticeSeconds = this.nextNoticeSeconds > 0 ? this.nextNoticeSeconds - 1 : this.noticeSeconds;
      this.notify();
      this.scheduleNoticeTick();
    }, 1000);
  }

  private clearAutoAlertTimer(): void {
    if (this.autoAlertTimer !== undefined) {
      this.clock.clearTimeout(this.autoAlertTimer);
      this.autoAlertTimer = undefined;
    }
  }

  private clearSosHoldTimer(): void {
    if (this.sosHoldTimer !== undefined) {
      this.clock.clearTimeout(this.sosHoldTimer);
      this.sosHoldTimer = undefined;
    }
  }

  private clearCountdownTimer(): void {
    if (this.countdownTimer !== undefined) {
      this.clock.clearTimeout(this.countdownTimer);
      this.countdownTimer = undefined;
    }
  }

  private clearNoticeTimer(): void {
    if (this.noticeTimer !== undefined) {
      this.clock.clearTimeout(this.noticeTimer);
      this.noticeTimer = undefined;
    }
  }

  private setEffect(effect: EmergencyEffect): void {
    this.effect = effect;
    this.effectToken += 1;
  }

  private notify(): void {
    const snapshot: EmergencySnapshot = this.getSnapshot();
    this.listeners.forEach((listener: EmergencyListener): void => {
      listener(snapshot);
    });
    this.vibration = VibrationPattern.None;
  }
}
