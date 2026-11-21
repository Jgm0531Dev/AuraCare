import {
  AutoAlertContext,
  EmergencyEffect,
  EmergencyEvent,
  EmergencyMachine,
  EmergencySnapshot,
  ScaledClock,
  Sensitivity
} from '../state/EmergencyMachine';
import { AppStore, DialogKind } from '../state/AppStore';
import { AlertReason } from '../model/AlertReason';
import { AlertState } from '../model/Alert';
import { vibrationService } from './VibrationService';
import { Logger } from '../util/Logger';
import { DEBUG_LAYOUT } from '../util/Dimens';
import { RELEASE_MODE } from '../util/AppConfig';
import { call } from '@kit.TelephonyKit';
import { Context } from '@kit.AbilityKit';
import { EmergencyContact } from '../model/EmergencyContact';
import { DEFAULT_CONTACTS } from '../mock/DemoData';
import { MAX_CONTACTS, USER_CONTACT_PREFIX, contactRepository, initialsOf, isUserContact } from './ContactRepository';

const TAG: string = 'EmergencyService';
const TOAST_MS: number = 2000;
const CALLING_MS: number = 2500;

/** Aviso explícito a la raíz (Index), que no re-renderiza con lecturas directas del store. */
export type UiListener = (event: string) => void;

class EmergencyService {
  private readonly clock: ScaledClock = new ScaledClock();
  private readonly machine: EmergencyMachine = new EmergencyMachine(this.clock);
  private store: AppStore | undefined = undefined;
  private toastTimer: number | undefined = undefined;
  private callingTimer: number | undefined = undefined;
  private lastEffectToken: number = 0;
  private uiListeners: UiListener[] = [];

  onUiChange(listener: UiListener): () => void {
    this.uiListeners.push(listener);
    return (): void => {
      const index: number = this.uiListeners.indexOf(listener);
      if (index >= 0) {
        this.uiListeners.splice(index, 1);
      }
    };
  }

  private emitUi(event: string): void {
    const store: AppStore | undefined = this.store;
    if (DEBUG_LAYOUT && store !== undefined) {
      Logger.info(TAG,
        `[trace] store escrito (${event}): alert=${store.emergency.state} reason=${store.emergency.reason} dialog=${store.dialogOpen} calling=${store.callingVisible} listeners=${this.uiListeners.length}`);
    }
    this.uiListeners.forEach((listener: UiListener): void => {
      try {
        listener(event);
      } catch (err) {
        Logger.error(TAG, `uiListener falló (${event})`, err as Object);
      }
    });
  }

  /** Demo: transición directa a `¿Estás bien?`, aunque la cadena de sensores falle. */
  fireAlertNow(reason: AlertReason): void {
    this.machine.forceAreYouOk(reason);
  }

  start(store: AppStore): void {
    this.store = store;
    this.machine.setTracer((message: string): void => {
      if (DEBUG_LAYOUT) {
        Logger.info('EmergencyMachine', `[trace] ${message}`);
      }
    });
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

  /** x1 / x5 / x10 sobre el Clock inyectado en la máquina de emergencia. */
  setTimeScale(scale: number): void {
    // Release: velocidad fija en x1.
    this.clock.setSpeed(RELEASE_MODE ? 1 : scale);
    if (DEBUG_LAYOUT) {
      Logger.info(TAG, `[trace] Clock velocidad=x${scale} alert=${this.store?.emergency.state}`);
    }
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
      this.emitUi('openDialog');
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
      this.emitUi('closeDialog');
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
        contactRepository.save(store.contacts);
        this.syncOnWay();
        return;
      }
      // AddContact: "Entendido" solo cierra el aviso; el contacto de prueba se añade desde el panel demo.
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
    // Interruptor "Contactos de ejemplo": encendido = ejemplos (no se guardan);
    // apagado = vuelven los contactos reales guardados.
    store.contacts = empty ? contactRepository.load() : DEFAULT_CONTACTS.slice();
    store.resetContactResponse();
    this.syncOnWay();
  }

  /** Al iniciar la app: abre preferences y carga los contactos reales guardados. */
  loadContacts(context: Context): void {
    const store: AppStore | undefined = this.store;
    if (store === undefined) {
      return;
    }
    contactRepository.init(context);
    store.contacts = contactRepository.load();
  }

  /** Abre el flujo propio de alta (ruta 'addContact' en Index). */
  requestAddContact(): void {
    this.emitUi('addContact');
  }

  /** Alta real: relación como nombre + teléfono. Devuelve false si no se pudo. */
  addUserContact(name: string, phone: string): boolean {
    const store: AppStore | undefined = this.store;
    if (store === undefined) {
      return false;
    }
    // Si había ejemplos en pantalla, se parte de los reales guardados.
    const base: EmergencyContact[] = store.contacts.every(isUserContact) ? store.contacts.slice() : contactRepository.load();
    if (base.length >= MAX_CONTACTS) {
      Logger.warn(TAG, 'addUserContact: máximo de contactos alcanzado');
      return false;
    }
    base.push({
      id: `${USER_CONTACT_PREFIX}${Date.now()}`,
      name: name,
      role: phone,
      initials: initialsOf(name),
      color: contactRepository.colorFor(base.length),
      step: 0,
      phone: phone
    });
    store.contacts = base;
    contactRepository.save(base);
    this.syncOnWay();
    return true;
  }

  /** Llamar: marcador del sistema con el número (call.makeCall, sin permiso). Ejemplos: simulado. */
  callContact(contact: EmergencyContact): void {
    const phone: string | undefined = contact.phone;
    if (phone === undefined || phone.length === 0) {
      this.showCalling(contact.name);
      return;
    }
    call.makeCall(phone).then((): void => {
      Logger.info(TAG, 'makeCall: marcador abierto');
    }).catch((err: Object): void => {
      Logger.error(TAG, 'makeCall falló', err);
      this.showCalling(contact.name);
    });
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
    this.emitUi('showCalling');
    if (this.callingTimer !== undefined) {
      this.clock.clearTimeout(this.callingTimer);
    }
    this.callingTimer = this.clock.setTimeout((): void => {
      this.callingTimer = undefined;
      store.hideCalling();
      this.emitUi('hideCalling');
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
    const previous: AlertState = store.emergency.state;
    if (store.emergency.state === AlertState.None && snapshot.state !== AlertState.None) {
      // Motivo congelado en el disparo.
      store.alertBpm = store.bpm;
    }
    store.emergency.state = snapshot.state;
    store.emergency.reason = snapshot.reason;
    store.emergencySeconds = snapshot.remainingSeconds;
    store.emergencyTotalSeconds = snapshot.totalSeconds;
    this.logCountdown(snapshot, previous);
    store.nextNoticeSeconds = snapshot.nextNoticeSeconds;
    store.onWay = snapshot.onWayPaused;
    this.emitUi('snapshot');
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

  /** Progreso del anillo en 30, 20, 10 y 0 s (uno por segundo de cuenta, escalado por el Clock). */
  private logCountdown(snapshot: EmergencySnapshot, previous: AlertState): void {
    if (snapshot.state === AlertState.AlertSent &&
        (previous === AlertState.AreYouOk || previous === AlertState.SosCountdown)) {
      Logger.info(TAG, `anillo ${previous}: restante=0s progreso=0.00 -> alert-sent`);
      return;
    }
    const s: number = snapshot.remainingSeconds;
    if (snapshot.totalSeconds > 0 && (s === 30 || s === 20 || s === 10 || s === 0 || s === snapshot.totalSeconds)) {
      Logger.info(TAG,
        `anillo ${snapshot.state}: restante=${s}s total=${snapshot.totalSeconds}s progreso=${(s / snapshot.totalSeconds).toFixed(2)}`);
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
