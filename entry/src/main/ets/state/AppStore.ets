import { PulseState, PulseVariant } from '../model/PulseState';
import { EmergencyContact } from '../model/EmergencyContact';
import { AlertState } from '../model/Alert';
import { AlertReason } from '../model/AlertReason';
import { SensorReading } from '../model/SensorReading';
import { SpO2Reading } from '../model/SpO2Reading';
import { SensorCapabilities } from '../model/SensorAvailability';
import { DEFAULT_CAPABILITIES, DEFAULT_CONTACTS } from '../mock/DemoData';

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
  @Trace contacts: EmergencyContact[] = DEFAULT_CONTACTS.slice();
  @Trace capabilities: SensorCapabilities = DEFAULT_CAPABILITIES;
  @Trace settings: AppSettings = new AppSettings();
  @Trace emergency: AppEmergency = new AppEmergency();

  selectVariant(variant: PulseVariant): void {
    this.bpm = variant.bpm;
    this.pulseState = variant.state;
    this.spo2 = variant.spo2;
    this.temperature = variant.temperature;
    this.movementLabel = variant.movementLabel;
  }

  applyReading(reading: SensorReading): void {
    this.bpm = reading.bpm;
    this.spo2 = reading.spo2;
    this.temperature = reading.temperature;
    this.movementLabel = reading.movementLabel;
  }

  applySpO2(reading: SpO2Reading): void {
    this.spo2 = reading.percent;
    this.spo2Simulated = reading.simulated;
  }
}

export const appStore: AppStore = new AppStore();
