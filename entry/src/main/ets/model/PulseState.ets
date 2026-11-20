export enum PulseState {
  Normal = 'normal',
  Elevated = 'elevated',
  Critical = 'critical'
}

export interface PulseVariant {
  state: PulseState;
  bpm: number;
  label: Resource;
  color: Resource;
  markerAngle: number;
  movementLabel: Resource;
  movementColor: Resource;
  spo2: number;
  spo2Label: Resource;
  spo2Color: Resource;
  temperature: number;
  temperatureLabel: Resource;
  temperatureColor: Resource;
  next: PulseState;
}
