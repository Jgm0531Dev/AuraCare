import { SensorProvider } from './SensorProvider';
import { SensorReading } from '../model/SensorReading';
import { SensorCapabilities } from '../model/SensorAvailability';
import { PulseState, PulseVariant } from '../model/PulseState';
import { DEFAULT_CAPABILITIES, PULSE_VARIANTS } from '../mock/DemoData';

export class MockSensorProvider implements SensorProvider {
  private variant: PulseVariant = PULSE_VARIANTS[0];

  setVariant(state: PulseState): void {
    const found: PulseVariant | undefined = PULSE_VARIANTS.find((item: PulseVariant) => item.state === state);
    if (found !== undefined) {
      this.variant = found;
    }
  }

  read(): SensorReading {
    return {
      bpm: this.variant.bpm,
      spo2: this.variant.spo2,
      temperature: this.variant.temperature,
      movementLabel: this.variant.movementLabel,
      timestamp: Date.now()
    };
  }

  capabilities(): SensorCapabilities {
    return DEFAULT_CAPABILITIES;
  }

  release(): void {
    // El mock no posee recursos del sistema.
  }
}
