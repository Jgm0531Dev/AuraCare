import { SensorReading } from '../model/SensorReading';
import { SensorCapabilities } from '../model/SensorAvailability';

export interface SensorProvider {
  read(): SensorReading;
  capabilities(): SensorCapabilities;
  release(): void;
}
