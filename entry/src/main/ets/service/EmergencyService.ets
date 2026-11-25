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
import { settingsRepository } from './SettingsRepository';
import { sensorService } from './SensorService';
import { alarmService } from './AlarmService';
import { notificationService } from './NotificationService';
import { LocationResult, LocationStatus, locationService } from './LocationService';
import { alertStateRepository, StoredAlert } from './AlertStateRepository';

const TAG: string = 'EmergencyService';
const TOAST_MS: number = 2000;
const CALLING_MS: number = 2500;
const EMERGENCY_NUMBER: string = '911';

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
  private context: Context | undefined = undefined;
  /** Momento en que la app pasó a segundo plano (los temporizadores JS se congelan). */
  private backgroundAt: number = 0;

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
    sensorService.setAnomalyListener((reason: AlertReason): void => {
      this.onAnomaly(reason);
    });
  }

  /**
   * v1.0.1: la auto-alerta la decide el motor de anomalías (SensorService -> onAnomaly) con lecturas
   * reales o de demostración. Este método queda como punto de traza para el panel de desarrollo.
   */
  updateAutoAlert(store: AppStore): void {
    if (DEBUG_LAYOUT) {
      const context: AutoAlertContext = {
        autoAlerts: store.autoAlerts,
        exerciseMode: store.settings.exerciseMode,
        mode: store.mode,
        bpm: store.bpm,
        sensitivity: this.toSensitivity(store.settings.sensitivity),
        variant: store.pulseState,
        movementImmobile: store.movementImmobile
      };
      Logger.info(TAG, `[trace] updateAutoAlert bpm=${context.bpm} variant=${context.variant}`);
    }
  }

  /** Anomalía sostenida detectada por el motor: abre "¿Estás bien?". */
  onAnomaly(reason: AlertReason): void {
    const store: AppStore | undefined = this.store;
    if (store === undefined || store.emergency.state !== AlertState.None) {
      return;
    }
    this.machine.dispatch(EmergencyEvent.AutoAlert, { reason: reason });
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
        this.dial(EMERGENCY_NUMBER);
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
    settingsRepository.init(context);
    settingsRepository.loadInto(store.settings);
    this.machine.setNoticeMinutes(store.settings.noticeMinutes);
    this.context = context;
    alarmService.init(context);
    locationService.init(context);
    alertStateRepository.init(context);
    this.restorePersistedAlert();
  }

  /** Reinicio de la app con una alerta en curso: la recupera descontando el tiempo transcurrido. */
  private restorePersistedAlert(): void {
    const saved: StoredAlert | undefined = alertStateRepository.load();
    if (saved === undefined) {
      return;
    }
    const elapsed: number = Math.max(0, (Date.now() - saved.savedAt) / 1000);
    Logger.warn(TAG, `alerta recuperada: ${saved.state} hace ${Math.round(elapsed)} s`);
    if (this.store !== undefined) {
      this.store.alertBpm = saved.alertBpm;
    }
    this.machine.restore(saved.state, saved.reason, saved.remainingSeconds - elapsed);
  }

  /** EntryAbility.onBackground: guarda la alerta y libera sensores. */
  onBackground(): void {
    this.backgroundAt = Date.now();
    this.persistAlert();
    sensorService.pause();
  }

  /** EntryAbility.onForeground: descuenta el tiempo en segundo plano y reanuda sensores. */
  onForeground(): void {
    sensorService.resume();
    const store: AppStore | undefined = this.store;
    if (store === undefined || this.backgroundAt === 0) {
      return;
    }
    const elapsed: number = Math.max(0, (Date.now() - this.backgroundAt) / 1000);
    this.backgroundAt = 0;
    const state: AlertState = store.emergency.state;
    if (state === AlertState.AreYouOk || state === AlertState.SosCountdown) {
      this.machine.restore(state, store.emergency.reason, store.emergencySeconds - elapsed);
    }
  }

  private persistAlert(): void {
    const store: AppStore | undefined = this.store;
    if (store === undefined) {
      return;
    }
    if (store.emergency.state === AlertState.None) {
      alertStateRepository.clear();
      return;
    }
    alertStateRepository.save({
      state: store.emergency.state,
      reason: store.emergency.reason,
      remainingSeconds: store.emergencySeconds,
      alertBpm: store.alertBpm,
      savedAt: Date.now()
    });
  }

  /** Alerta activa: apaga el sonido y la vibración hasta el próximo recordatorio. */
  silenceAlarm(): void {
    alarmService.stop();
    if (this.store !== undefined) {
      this.store.alarmSilenced = true;
    }
  }

  /** "Ya viene ayuda": lo marca el usuario. Pausa recordatorios y apaga la alarma. */
  markHelpComing(on: boolean): void {
    this.setOnWay(on);
    if (on) {
      this.silenceAlarm();
    }
  }

  private str(resource: Resource): string {
    try {
      return this.context?.resourceManager.getStringSync(resource.id) ?? '';
    } catch (err) {
      Logger.error(TAG, 'getStringSync falló', err as Object);
      return '';
    }
  }

  private startAlertOutputs(state: AlertState): void {
    const store: AppStore | undefined = this.store;
    if (store === undefined) {
      return;
    }
    store.alarmSilenced = false;
    alarmService.start();
    const text: Resource = state === AlertState.AlertSent ? $r('app.string.notif_alert_text') :
      (state === AlertState.SosCountdown ? $r('app.string.notif_sos_text') : $r('app.string.notif_are_you_ok_text'));
    void notificationService.publishAlert(this.str($r('app.string.notif_alert_title')), this.str(text));
  }

  private stopAlertOutputs(): void {
    alarmService.stop();
    notificationService.cancelAlert();
    alertStateRepository.clear();
    const store: AppStore | undefined = this.store;
    if (store !== undefined) {
      store.alarmSilenced = false;
      store.locationStatus = LocationStatus.Off;
      store.address = '';
    }
  }

  /** Ubicación opcional: solo si el usuario la activó en Ajustes. No se envía a nadie. */
  private fetchLocation(): void {
    const store: AppStore | undefined = this.store;
    if (store === undefined) {
      return;
    }
    if (!store.settings.locationEnabled) {
      store.locationStatus = LocationStatus.Off;
      return;
    }
    store.locationStatus = LocationStatus.Locating;
    locationService.locate().then((result: LocationResult): void => {
      if (store.emergency.state === AlertState.None) {
        return;
      }
      store.locationStatus = result.status;
      store.latitude = result.latitude;
      store.longitude = result.longitude;
      store.address = result.address;
    }).catch((err: Object): void => {
      store.locationStatus = LocationStatus.Failed;
      Logger.error(TAG, 'locate falló', err);
    });
  }

  /** Ajustes: activar pide el permiso en ese momento; si se niega, el interruptor vuelve a apagado. */
  async setLocationEnabled(on: boolean): Promise<boolean> {
    const store: AppStore | undefined = this.store;
    if (store === undefined) {
      return false;
    }
    if (!on) {
      store.settings.locationEnabled = false;
      this.saveSettings();
      return false;
    }
    const granted: boolean = locationService.hasPermission() || await locationService.requestPermission();
    store.settings.locationEnabled = granted;
    this.saveSettings();
    return granted;
  }

  /** Persiste Ajustes y reaplica lo que afecta a la máquina. */
  saveSettings(): void {
    const store: AppStore | undefined = this.store;
    if (store === undefined) {
      return;
    }
    settingsRepository.save(store.settings);
    this.machine.setNoticeMinutes(store.settings.noticeMinutes);
    this.updateAutoAlert(store);
  }

  /** Abre el flujo propio de alta (ruta 'addContact' en Index). */
  requestAddContact(): void {
    if (this.store !== undefined) {
      this.store.editingContactId = '';
    }
    this.emitUi('addContact');
  }

  /** Abre la misma ruta en modo edición del contacto real `id`. */
  requestEditContact(id: string): void {
    const store: AppStore | undefined = this.store;
    if (store === undefined) {
      return;
    }
    store.editingContactId = id;
    this.emitUi('addContact');
  }

  /** Edición real: cambia nombre y teléfono, conserva id y orden. */
  updateUserContact(id: string, name: string, phone: string): boolean {
    const store: AppStore | undefined = this.store;
    if (store === undefined) {
      return false;
    }
    const base: EmergencyContact[] = contactRepository.load();
    const index: number = base.findIndex((contact: EmergencyContact): boolean => contact.id === id);
    if (index < 0) {
      Logger.warn(TAG, 'updateUserContact: contacto no encontrado');
      return false;
    }
    const current: EmergencyContact = base[index];
    base[index] = {
      id: current.id,
      name: name,
      role: phone,
      initials: initialsOf(name),
      color: current.color,
      step: 0,
      phone: phone
    };
    store.contacts = base;
    contactRepository.save(base);
    store.editingContactId = '';
    return true;
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
      // Contactos de ejemplo (solo desarrollo): sin número real.
      this.showCalling(contact.name);
      return;
    }
    this.dial(phone);
  }

  /**
   * Abre el marcador del sistema con el número (call.makeCall, API pública, sin permiso).
   * El usuario confirma la llamada. Sin capacidad de voz o si falla: se muestra el número.
   */
  dial(phone: string): void {
    let voice: boolean = false;
    try {
      voice = call.hasVoiceCapability();
    } catch (err) {
      Logger.error(TAG, 'hasVoiceCapability falló', err as Object);
    }
    if (!voice) {
      Logger.warn(TAG, 'el reloj no tiene capacidad de voz; se muestra el número');
      this.showCallFailed(phone);
      return;
    }
    call.makeCall(phone).then((): void => {
      Logger.info(TAG, 'makeCall: marcador abierto');
    }).catch((err: Object): void => {
      Logger.error(TAG, 'makeCall falló', err);
      this.showCallFailed(phone);
    });
  }

  private showCallFailed(phone: string): void {
    const store: AppStore | undefined = this.store;
    if (store === undefined) {
      return;
    }
    store.callFailedNumber = phone;
    store.callFailedVisible = true;
    this.emitUi('callFailed');
  }

  hideCallFailed(): void {
    if (this.store !== undefined) {
      this.store.callFailedVisible = false;
      this.emitUi('callFailedHidden');
    }
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
    alarmService.stop();
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
    if (previous !== AlertState.None && snapshot.state === AlertState.None) {
      // Cerrada la alerta ("Estoy bien", cancelar SOS, confirmar aviso): pausa del motor.
      sensorService.snooze();
    }
    store.emergency.state = snapshot.state;
    store.emergency.reason = snapshot.reason;
    if (previous !== snapshot.state) {
      if (snapshot.state === AlertState.None) {
        this.stopAlertOutputs();
      } else {
        this.startAlertOutputs(snapshot.state);
      }
    }
    store.emergencySeconds = snapshot.remainingSeconds;
    store.emergencyTotalSeconds = snapshot.totalSeconds;
    this.logCountdown(snapshot, previous);
    store.nextNoticeSeconds = snapshot.nextNoticeSeconds;
    store.onWay = snapshot.onWayPaused;
    if (previous !== snapshot.state && snapshot.state !== AlertState.None) {
      this.persistAlert();
    }
    this.emitUi('snapshot');
    if (snapshot.effectToken === this.lastEffectToken) {
      return;
    }
    this.lastEffectToken = snapshot.effectToken;
    if (snapshot.effect === EmergencyEffect.AlertSent ||
        snapshot.effect === EmergencyEffect.AlertSentPreview) {
      store.resetContactResponse();
      this.setOnWay(false);
      // v1.0.1: no se afirma ningún envío. Se busca la ubicación (si está activada) para mostrarla.
      this.fetchLocation();
    } else if (snapshot.effect === EmergencyEffect.ToastCancelled ||
        snapshot.effect === EmergencyEffect.ToastNotified) {
      this.showToast($r('app.string.alert_cancelled'));
    } else if (snapshot.effect === EmergencyEffect.NoticeDue) {
      // Recordatorio: vuelve la alarma y se repite la notificación local.
      this.startAlertOutputs(AlertState.AlertSent);
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
