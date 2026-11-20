export enum SensorStatus {
  Available = 'available',
  Unavailable = 'unavailable',
  PermissionRequired = 'permission',
  Measuring = 'measuring'
}

export interface SensorCapabilities {
  heartRate: SensorStatus;
  spo2: SensorStatus;
  temperature: SensorStatus;
  movement: SensorStatus;
  location: SensorStatus;
  fallDetection: SensorStatus;
}
