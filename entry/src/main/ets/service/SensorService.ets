import { SensorProvider } from './SensorProvider';
import { MockSensorProvider } from './MockSensorProvider';
import { SpO2Provider } from './SpO2Provider';
import { MockSpO2Provider } from './MockSpO2Provider';
import { AppStore, ToggleableCapability } from '../state/AppStore';
import { PulseState, PulseVariant } from '../model/PulseState';
import { PULSE_VARIANTS } from '../mock/DemoData';
import { SensorCapabilities, SensorStatus } from '../model/SensorAvailability';

class SensorService {
  private provider: SensorProvider = new MockSensorProvider();
  private spo2Provider: SpO2Provider = new MockSpO2Provider();

  start(store: AppStore): void {
    this.selectVariant(PulseState.Normal, store);
    store.capabilities = this.provider.capabilities();
    store.applySpO2(this.spo2Provider.read());
  }

  selectVariant(state: PulseState, store: AppStore): void {
    // Estado, color, marcador e inmovilidad del Monitor: applyReading no los toca.
    const variant: PulseVariant | undefined =
      PULSE_VARIANTS.find((item: PulseVariant): boolean => item.state === state);
    if (variant !== undefined) {
      store.selectVariant(variant);
    }
    this.provider.setVariant(state);
    const reading = this.provider.read();
    store.applyReading(reading);
    this.spo2Provider.setPercent(reading.spo2);
    store.applySpO2(this.spo2Provider.read());
  }

  setCapabilities(capabilities: SensorCapabilities, store: AppStore): void {
    this.provider.setCapabilities(capabilities);
    store.capabilities = capabilities;
  }

  toggleCapability(capability: ToggleableCapability, available: boolean, store: AppStore): void {
    store.setCapability(capability, available);
    this.provider.setCapabilities(store.capabilities);
    if (capability === 'spo2') {
      this.spo2Provider.setAvailable(available);
      store.applySpO2(this.spo2Provider.read());
    }
    store.settings.fallDetection = store.capabilities.fallDetection === SensorStatus.Available;
  }

  release(): void {
    this.provider.release();
    this.spo2Provider.release();
  }
}

export const sensorService: SensorService = new SensorService();
