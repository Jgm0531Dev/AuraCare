import { PulseState, PulseVariant } from '../model/PulseState';
import { EmergencyContact } from '../model/EmergencyContact';
import { SensorCapabilities, SensorStatus } from '../model/SensorAvailability';

export const DEFAULT_CONTACTS: EmergencyContact[] = [
  { id: 'c1', name: 'María López', role: 'Madre', initials: 'ML', color: $r('app.color.contact_ml'), step: 0 },
  { id: 'c2', name: 'Carlos Gómez', role: 'Hermano', initials: 'CG', color: $r('app.color.contact_cg'), step: 0 },
  { id: 'c3', name: 'Dra. Elena Ruiz', role: 'Médica', initials: 'ER', color: $r('app.color.contact_er'), step: 0 },
  { id: 'c4', name: 'Pedro Morales', role: 'Cónyuge', initials: 'PM', color: $r('app.color.contact_pm'), step: 0 }
];

export const DEMO_NEW_CONTACT: EmergencyContact = {
  id: 'c5', name: 'Lucía Fernández', role: 'Amiga', initials: 'LF',
  color: $r('app.color.contact_lf'), step: 0
};

export const PULSE_VARIANTS: PulseVariant[] = [
  {
    state: PulseState.Normal,
    bpm: 78,
    label: $r('app.string.pulse_normal'),
    color: $r('app.color.green'),
    markerAngle: 245,
    movementLabel: $r('app.string.walking'),
    movementColor: $r('app.color.green'),
    spo2: 98,
    spo2Label: $r('app.string.sensor_normal'),
    spo2Color: $r('app.color.green'),
    temperature: 36.5,
    temperatureLabel: $r('app.string.sensor_stable'),
    temperatureColor: $r('app.color.green'),
    next: PulseState.Elevated
  },
  {
    state: PulseState.Elevated,
    bpm: 104,
    label: $r('app.string.pulse_elevated'),
    color: $r('app.color.orange'),
    markerAngle: 295,
    movementLabel: $r('app.string.resting'),
    movementColor: $r('app.color.orange'),
    spo2: 93,
    spo2Label: $r('app.string.sensor_low'),
    spo2Color: $r('app.color.orange'),
    temperature: 37.4,
    temperatureLabel: $r('app.string.sensor_high'),
    temperatureColor: $r('app.color.orange'),
    next: PulseState.Critical
  },
  {
    state: PulseState.Critical,
    bpm: 132,
    label: $r('app.string.pulse_critical'),
    color: $r('app.color.red'),
    markerAngle: 346,
    movementLabel: $r('app.string.immobile'),
    movementColor: $r('app.color.red'),
    spo2: 88,
    spo2Label: $r('app.string.sensor_very_low'),
    spo2Color: $r('app.color.red'),
    temperature: 38.6,
    temperatureLabel: $r('app.string.sensor_fever'),
    temperatureColor: $r('app.color.red'),
    next: PulseState.Normal
  }
];

export const DEFAULT_CAPABILITIES: SensorCapabilities = {
  heartRate: SensorStatus.Available,
  spo2: SensorStatus.Available,
  temperature: SensorStatus.Available,
  movement: SensorStatus.Available,
  location: SensorStatus.Available,
  fallDetection: SensorStatus.Available
};
