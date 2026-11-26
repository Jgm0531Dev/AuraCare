import { PulseState, PulseVariant } from '../model/PulseState';
import { EmergencyContact } from '../model/EmergencyContact';
import { AlertState } from '../model/Alert';
import { AlertReason } from '../model/AlertReason';
import { SensorReading } from '../model/SensorReading';
import { SpO2Reading, SpO2Source } from '../model/SpO2Reading';
import { SensorCapabilities, SensorStatus } from '../model/SensorAvailability';
import { DEFAULT_CAPABILITIES, DEFAULT_CONTACTS, DEMO_NEW_CONTACT } from '../mock/DemoData';
import { WatchMode } from './EmergencyMachine';

export type ToggleableCapability = 'spo2' | 'temperature' | 'fallDetection';

export enum DialogKind {
  None,
  CancelAlert,
  Call911,
  RemoveContact,
  AddContact
}

@ObservedV2
export class AppSettings {
  @Trace sensitivity: string = 'Media';
  @Trace noticeMinutes: number = 5;
  @Trace exerciseMode: boolean = false;
  @Trace batterySaver: boolean = false;
  @Trace fallDetection: boolean = true;
  /** Modo demostración: datos de prueba generados en el reloj (apagado por defecto). */
  @Trace demoMode: boolean = false;
  /** Ubicación opcional: solo se muestra en el reloj al confirmarse una alerta. */
  @Trace locationEnabled: boolean = false;
}

@ObservedV2
export class AppEmergency {
  @Trace state: AlertState = AlertState.None;
  @Trace reason: AlertReason = AlertReason.PulsoCritico;
}

@ObservedV2
export class AppStore {
  /** Valores neutros hasta la primera lectura (nunca valores de ejemplo fuera del Modo demostración). */
  @Trace bpm: number = 0;
  @Trace pulseState: PulseState = PulseState.Normal;
  @Trace spo2: number = 0;
  @Trace spo2Simulated: boolean = true;
  @Trace temperature: number = 0;
  @Trace movementLabel: Resource = $r('app.string.value_dash');
  @Trace markerAngle: number = 245;
  @Trace stateColor: Resource = $r('app.color.muted');
  /** Estado inicial vacío; los de ejemplo solo con el interruptor del panel demo. */
  @Trace contacts: EmergencyContact[] = [];
  @Trace capabilities: SensorCapabilities = DEFAULT_CAPABILITIES;
  @Trace settings: AppSettings = new AppSettings();
  @Trace emergency: AppEmergency = new AppEmergency();
  @Trace mode: WatchMode = 'live';
  @Trace autoAlerts: boolean = true;
  @Trace movementImmobile: boolean = false;
  /** false = sin lectura de pulso (sin permiso, sin sensor o reloj sin colocar): el Monitor muestra "--". */
  @Trace heartRateValid: boolean = false;
  /** WEAR_DETECTION: reloj quitado de la muñeca (pulso y caídas se ignoran). */
  @Trace notWorn: boolean = false;
  @Trace motionValid: boolean = false;
  /** Rango normal personal calculado con lecturas reales acumuladas (RangeModel). */
  @Trace rangeReady: boolean = false;
  @Trace rangeMin: number = 60;
  @Trace rangeMax: number = 100;
  @Trace rangeSamples: number = 0;
  /** Una condición anómala se está acumulando (motor de anomalías). */
  @Trace anomalyPending: boolean = false;
  /** La alarma de Alerta activa fue silenciada por el usuario (vuelve con el recordatorio). */
  @Trace alarmSilenced: boolean = false;
  /** Ubicación de la alerta (LocationStatus como texto), solo para mostrar en el reloj. */
  @Trace locationStatus: string = 'off';
  @Trace latitude: number = 0;
  @Trace longitude: number = 0;
  @Trace address: string = '';
  /** El reloj no puede llamar (sin capacidad de voz o makeCall falló): se muestra el número. */
  @Trace callFailedVisible: boolean = false;
  @Trace callFailedNumber: string = '';
  /** Aviso informativo que se cierra al tocarlo (p. ej., instrucciones del permiso de pulso). */
  @Trace infoVisible: boolean = false;
  @Trace infoMessage: Resource = $r('app.string.health_permission_steps');
  @Trace emergencySeconds: number = 0;
  /** Total de la cuenta en curso, desde la máquina (respeta x5/x10 vía Clock). */
  @Trace emergencyTotalSeconds: number = 0;
  /** BPM congelado al disparar la alerta: el motivo no cambia con lecturas posteriores. */
  @Trace alertBpm: number = 0;
  @Trace nextNoticeSeconds: number = 0;
  @Trace onWay: boolean = false;
  @Trace toastMessage: Resource = $r('app.string.alert_cancelled');
  @Trace toastVisible: boolean = false;
  @Trace dialogOpen: boolean = false;
  @Trace dialogKind: DialogKind = DialogKind.None;
  /** Espejo de NavPathStack.size() para los logs bajo DEBUG_LAYOUT. */
  @Trace navStackDepth: number = 0;
  @Trace contactResponseStep: number = 0;
  @Trace contactToRemoveId: string = '';
  @Trace contactToRemoveName: string = '';
  /** Contacto en edición (ruta 'addContact'); vacío = alta nueva. */
  @Trace editingContactId: string = '';
  @Trace demoPanelVisible: boolean = true;

  selectVariant(variant: PulseVariant): void {
    this.bpm = variant.bpm;
    this.pulseState = variant.state;
    this.spo2 = variant.spo2;
    this.temperature = variant.temperature;
    this.movementLabel = variant.movementLabel;
    this.movementImmobile = variant.state === PulseState.Critical;
    this.markerAngle = variant.markerAngle;
    this.stateColor = variant.color;
  }

  applyReading(reading: SensorReading): void {
    this.bpm = reading.bpm;
    this.spo2 = reading.spo2;
    this.temperature = reading.temperature;
    this.movementLabel = reading.movementLabel;
  }

  applySpO2(reading: SpO2Reading): void {
    if (reading.source === SpO2Source.Unavailable) {
      return;
    }
    this.spo2 = reading.percent;
    this.spo2Simulated = reading.simulated;
  }

  setCapability(capability: ToggleableCapability, available: boolean): void {
    const status: SensorStatus = available ? SensorStatus.Available : SensorStatus.Unavailable;
    const next: SensorCapabilities = {
      heartRate: this.capabilities.heartRate,
      spo2: this.capabilities.spo2,
      temperature: this.capabilities.temperature,
      movement: this.capabilities.movement,
      location: this.capabilities.location,
      fallDetection: this.capabilities.fallDetection
    };
    if (capability === 'spo2') {
      next.spo2 = status;
    } else if (capability === 'temperature') {
      next.temperature = status;
    } else {
      next.fallDetection = status;
    }
    this.capabilities = next;
  }

  setContactsEmpty(empty: boolean): void {
    this.contacts = empty ? [] : DEFAULT_CONTACTS.slice();
    this.resetContactResponse();
  }

  addDemoContact(): void {
    if (this.contacts.length >= 5) {
      return;
    }
    if (this.contacts.some((contact: EmergencyContact): boolean => contact.id === DEMO_NEW_CONTACT.id)) {
      return;
    }
    const next: EmergencyContact[] = this.contacts.slice();
    next.push(DEMO_NEW_CONTACT);
    this.contacts = next;
  }

  removeContact(id: string): void {
    this.contacts = this.contacts.filter((contact: EmergencyContact): boolean => contact.id !== id);
    this.resetContactResponse();
  }

  advanceContactResponse(): void {
    this.contactResponseStep = Math.min(2, this.contactResponseStep + 1);
    this.applyContactResponse();
  }

  resetContactResponse(): void {
    this.contactResponseStep = 0;
    this.applyContactResponse();
  }

  private applyContactResponse(): void {
    this.contacts = this.contacts.map((contact: EmergencyContact, index: number): EmergencyContact => {
      let step: number = 0;
      if (index === 0) {
        step = this.contactResponseStep;
      } else if (index === 1) {
        step = Math.min(1, this.contactResponseStep);
      }
      return {
        id: contact.id,
        name: contact.name,
        role: contact.role,
        initials: contact.initials,
        color: contact.color,
        step: step,
        phone: contact.phone
      };
    });
  }

  showToast(message: Resource): void {
    this.toastMessage = message;
    this.toastVisible = true;
  }

  hideToast(): void {
    this.toastVisible = false;
  }

}

export const appStore: AppStore = new AppStore();

/** Estado de demo añadido por las pantallas P2 (sin persistencia). */
@ObservedV2
export class ExtraDemoState {
  @Trace medicalSample: boolean = false;
}

export const extraDemoState: ExtraDemoState = new ExtraDemoState();
