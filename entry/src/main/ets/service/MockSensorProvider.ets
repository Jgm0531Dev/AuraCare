import { SensorProvider } from './SensorProvider';
import { SensorReading } from '../model/SensorReading';
import { SensorCapabilities } from '../model/SensorAvailability';
import { PulseState, PulseVariant } from '../model/PulseState';
import { DEFAULT_CAPABILITIES, PULSE_VARIANTS } from '../mock/DemoData';

export class MockSensorProvider implements SensorProvider {
  readonly isSimulated: boolean = true;
  private variant: PulseVariant = PULSE_VARIANTS[0];
  private capabilitiesState: SensorCapabilities = {
    heartRate: DEFAULT_CAPABILITIES.heartRate,
    spo2: DEFAULT_CAPABILITIES.spo2,
    temperature: DEFAULT_CAPABILITIES.temperature,
    movement: DEFAULT_CAPABILITIES.movement,
    location: DEFAULT_CAPABILITIES.location,
    fallDetection: DEFAULT_CAPABILITIES.fallDetection
  };

  setVariant(state: PulseState): void {
    const found: PulseVariant | undefined = PULSE_VARIANTS.find((item: PulseVariant) => item.state === state);
    if (found !== undefined) {
      this.variant = found;
    }
  }

  setCapabilities(capabilities: SensorCapabilities): void {
    this.capabilitiesState = capabilities;
  }

  read(): SensorReading {
    return {
      bpm: this.variant.bpm,
      spo2: this.variant.spo2,
      temperature: this.variant.temperature,
      movementLabel: this.variant.movementLabel,
      timestamp: Date.now(),
      // Datos de demostración: el motor de anomalías los trata igual que los reales.
      heartRateValid: true,
      motionValid: true,
      immobile: this.variant.state === PulseState.Critical,
      peakG: 1
    };
  }

  capabilities(): SensorCapabilities {
    return this.capabilitiesState;
  }

  release(): void {
    // El mock no posee recursos del sistema.
  }
}
