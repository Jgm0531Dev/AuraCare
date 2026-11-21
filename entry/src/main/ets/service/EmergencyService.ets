import {
  AutoAlertContext,
  Clock,
  EmergencyEffect,
  EmergencyEvent,
  EmergencyMachine,
  EmergencySnapshot,
  Sensitivity
} from '../state/EmergencyMachine';
import { AppStore, DialogKind } from '../state/AppStore';
import { AlertReason } from '../model/AlertReason';
import { vibrationService } from './VibrationService';
import { Logger } from '../util/Logger';
import { DEBUG_LAYOUT } from '../util/Dimens';

const TAG: string = 'EmergencyService';
const TOAST_MS: number = 2000;
const CALLING_MS: number = 2500;

class SystemClock implements Clock {
  now(): number {
    return Date.now();
  }

  setTimeout(callback: () => void, delay: number): number {
    return setTimeout(callback, delay);
  }

  clearTimeout(id: number): void {
    clearTimeout(id);
  }
}

class EmergencyService {
  private readonly clock: Clock = new SystemClock();
  private readonly machine: EmergencyMachine = new EmergencyMachine(this.clock);
  private store: AppStore | undefined = undefined;
  private toastTimer: number | undefined = undefined;
  private callingTimer: number | undefined = undefined;
  private lastEffectToken: number = 0;

  start(store: AppStore): void {
    this.store = store;
    this.machine.subscribe((snapshot: EmergencySnapshot): void => {
      this.applySnapshot(snapshot);
    });
    this.machine.setNoticeMinutes(store.settings.noticeMinutes);
    this.updateAutoAlert(store);
  }

  updateAutoAlert(store: AppStore): void {
    const context: AutoAlertContext = {
      autoAlerts: store.autoAlerts,
      exerciseMode: store.settings.exerciseMode,
      mode: store.mode,
      bpm: store.bpm,
      sensitivity: this.toSensitivity(store.settings.sensitivity),
      variant: store.pulseState,
      movementImmobile: store.movementImmobile
    };
    this.machine.updateAutoAlert(context);
  }

  setNoticeMinutes(minutes: number): void {
    this.machine.setNoticeMinutes(minutes);
  }

  setOnWay(onWay: boolean): void {
    this.machine.setOnWay(onWay);
  }

  simulateAlert(reason: AlertReason): void {
    this.machine.dispatch(EmergencyEvent.SimularAlerta, { reason: reason });
  }

  startSosHold(): void {
    this.machine.startSosHold();
  }

  cancelSosHold(): void {
    this.machine.cancelSosHold();
  }

  safe(): void {
    this.machine.dispatch(EmergencyEvent.Safe);
  }

  helpNow(): void {
    this.machine.dispatch(EmergencyEvent.Emergency);
  }

  cancelSos(): void {
    this.machine.dispatch(EmergencyEvent.CancelSos);
  }

  confirmNotify(): void {
    this.machine.dispatch(EmergencyEvent.ConfirmNotify);
  }

  viewAlertSent(): void {
    this.machine.dispatch(EmergencyEvent.ViewAlertSent);
  }

  openDialog(kind: DialogKind, contactId: string = '', contactName: string = ''): void {
    const store: AppStore | undefined = this.store;
    if (store === undefined) {
      return;
    }
    try {
      store.dialogKind = kind;
      store.contactToRemoveId = contactId;
      store.contactToRemoveName = contactName;
      store.dialogOpen = true;
      this.logOverlay('openDialog');
    } catch (err) {
      this.closeDialog();
      Logger.error(TAG, 'openDialog falló', err as Object);
    }
  }

  closeDialog(): void {
    const store: AppStore | undefined = this.store;
    if (store === undefined) {
      return;
    }
    try {
      store.dialogOpen = false;
      store.dialogKind = DialogKind.None;
      store.contactToRemoveId = '';
      store.contactToRemoveName = '';
    } finally {
      // El overlay se apaga incluso si falla alguna limpieza intermedia.
      store.dialogOpen = false;
      store.dialogKind = DialogKind.None;
      this.logOverlay('closeDialog');
    }
  }

  confirmDialog(): void {
    const store: AppStore | undefined = this.store;
    if (store === undefined) {
      return;
    }
    const kind: DialogKind = store.dialogKind;
    try {
      if (kind === DialogKind.CancelAlert) {
        this.confirmNotify();
        return;
      }
      if (kind === DialogKind.Call911) {
        this.showCalling($r('app.string.emergency_911'));
        return;
      }
      if (kind === DialogKind.RemoveContact) {
        store.removeContact(store.contactToRemoveId);
        this.syncOnWay();
        return;
      }
      if (kind === DialogKind.AddContact) {
        this.addDemoContact();
      }
    } catch (err) {
      Logger.error(TAG, 'confirmDialog falló', err as Object);
    } finally {
      this.closeDialog();
    }
  }

  private logOverlay(event: string): void {
    if (!DEBUG_LAYOUT) {
      return;
    }
    const store: AppStore | undefined = this.store;
    if (store === undefined) {
      return;
    }
    Logger.info(TAG,
      `${event}: overlayOpen=${store.dialogOpen} dialogKind=${store.dialogKind} navStackDepth=${store.navStackDepth}`);
  }

  advanceContactResponse(): void {
    const store: AppStore | undefined = this.store;
    if (store === undefined) {
      return;
    }
    store.advanceContactResponse();
    this.syncOnWay();
  }

  setContactsEmpty(empty: boolean): void {
    const store: AppStore | undefined = this.store;
    if (store === undefined) {
      return;
    }
    store.setContactsEmpty(empty);
    this.syncOnWay();
  }

  addDemoContact(): void {
    const store: AppStore | undefined = this.store;
    if (store === undefined) {
      return;
    }
    store.addDemoContact();
    this.syncOnWay();
  }

  private syncOnWay(): void {
    const store: AppStore | undefined = this.store;
    if (store === undefined) {
      return;
    }
    const onWay: boolean = store.contacts.some((contact): boolean => contact.step >= 2);
    this.setOnWay(onWay);
  }

  showCalling(name: Resource | string): void {
    const store: AppStore | undefined = this.store;
    if (store === undefined) {
      return;
    }
    store.showCalling(name);
    if (this.callingTimer !== undefined) {
      this.clock.clearTimeout(this.callingTimer);
    }
    this.callingTimer = this.clock.setTimeout((): void => {
      this.callingTimer = undefined;
      store.hideCalling();
    }, CALLING_MS);
  }

  dispose(): void {
    vibrationService.dispose();
    this.machine.dispose();
    if (this.toastTimer !== undefined) {
      this.clock.clearTimeout(this.toastTimer);
      this.toastTimer = undefined;
    }
    if (this.callingTimer !== undefined) {
      this.clock.clearTimeout(this.callingTimer);
      this.callingTimer = undefined;
    }
    this.store = undefined;
    this.lastEffectToken = 0;
  }

  private applySnapshot(snapshot: EmergencySnapshot): void {
    const store: AppStore | undefined = this.store;
    if (store === undefined) {
      return;
    }
    vibrationService.vibrate(snapshot.vibration);
    store.emergency.state = snapshot.state;
    store.emergency.reason = snapshot.reason;
    store.emergencySeconds = snapshot.remainingSeconds;
    store.nextNoticeSeconds = snapshot.nextNoticeSeconds;
    store.onWay = snapshot.onWayPaused;
    if (snapshot.effectToken === this.lastEffectToken) {
      return;
    }
    this.lastEffectToken = snapshot.effectToken;
    if (snapshot.effect === EmergencyEffect.AlertSent ||
        snapshot.effect === EmergencyEffect.AlertSentPreview) {
      store.resetContactResponse();
      this.setOnWay(false);
      if (this.canNotify(store) && snapshot.effect === EmergencyEffect.AlertSent) {
        this.showToast($r('app.string.contacts_notified'));
      }
    } else if (snapshot.effect === EmergencyEffect.ToastCancelled) {
      this.showToast($r('app.string.alert_cancelled'));
    } else if (snapshot.effect === EmergencyEffect.ToastNotified && this.canNotify(store)) {
      this.showToast($r('app.string.contacts_notified'));
    }
  }

  private canNotify(store: AppStore): boolean {
    return store.mode === 'live' && store.contacts.length > 0;
  }

  private showToast(message: Resource): void {
    const store: AppStore | undefined = this.store;
    if (store === undefined) {
      return;
    }
    store.showToast(message);
    if (this.toastTimer !== undefined) {
      this.clock.clearTimeout(this.toastTimer);
    }
    this.toastTimer = this.clock.setTimeout((): void => {
      this.toastTimer = undefined;
      store.hideToast();
    }, TOAST_MS);
  }

  private toSensitivity(value: string): Sensitivity {
    if (value === 'Baja') {
      return 'Baja';
    }
    if (value === 'Alta') {
      return 'Alta';
    }
    return 'Media';
  }
}

export const emergencyService: EmergencyService = new EmergencyService();
