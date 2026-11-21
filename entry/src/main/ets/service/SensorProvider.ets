import { SensorReading } from '../model/SensorReading';
import { SensorCapabilities } from '../model/SensorAvailability';
import { PulseState } from '../model/PulseState';

export interface SensorProvider {
  /** true si las lecturas son simuladas (Mock). Opcional: ausente = lecturas reales. */
  readonly isSimulated?: boolean;
  read(): SensorReading;
  capabilities(): SensorCapabilities;
  setVariant(state: PulseState): void;
  setCapabilities(capabilities: SensorCapabilities): void;
  release(): void;
}
