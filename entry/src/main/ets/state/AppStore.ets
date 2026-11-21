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
}

@ObservedV2
export class AppEmergency {
  @Trace state: AlertState = AlertState.None;
  @Trace reason: AlertReason = AlertReason.PulsoCritico;
}

@ObservedV2
export class AppStore {
  @Trace bpm: number = 78;
  @Trace pulseState: PulseState = PulseState.Normal;
  @Trace spo2: number = 98;
  @Trace spo2Simulated: boolean = true;
  @Trace temperature: number = 36.5;
  @Trace movementLabel: Resource = $r('app.string.walking');
  @Trace markerAngle: number = 245;
  @Trace stateColor: Resource = $r('app.color.green');
  /** Estado inicial vacío; los de ejemplo solo con el interruptor del panel demo. */
  @Trace contacts: EmergencyContact[] = [];
  @Trace capabilities: SensorCapabilities = DEFAULT_CAPABILITIES;
  @Trace settings: AppSettings = new AppSettings();
  @Trace emergency: AppEmergency = new AppEmergency();
  @Trace mode: WatchMode = 'live';
  @Trace autoAlerts: boolean = true;
  @Trace movementImmobile: boolean = false;
  @Trace emergencySeconds: number = 0;
  @Trace nextNoticeSeconds: number = 0;
  @Trace onWay: boolean = false;
  @Trace toastMessage: Resource = $r('app.string.alert_cancelled');
  @Trace toastVisible: boolean = false;
  @Trace callingName: Resource | string = $r('app.string.emergency_911');
  @Trace callingVisible: boolean = false;
  @Trace dialogOpen: boolean = false;
  @Trace dialogKind: DialogKind = DialogKind.None;
  /** Espejo de NavPathStack.size() para los logs bajo DEBUG_LAYOUT. */
  @Trace navStackDepth: number = 0;
  @Trace contactResponseStep: number = 0;
  @Trace contactToRemoveId: string = '';
  @Trace contactToRemoveName: string = '';
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
        step: step
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

  showCalling(name: Resource | string): void {
    this.callingName = name;
    this.callingVisible = true;
  }

  hideCalling(): void {
    this.callingVisible = false;
  }
}

export const appStore: AppStore = new AppStore();

/** Estado de demo añadido por las pantallas P2 (sin persistencia). */
@ObservedV2
export class ExtraDemoState {
  @Trace medicalSample: boolean = false;
}

export const extraDemoState: ExtraDemoState = new ExtraDemoState();
