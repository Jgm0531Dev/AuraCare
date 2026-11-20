import { SensorProvider } from './SensorProvider';
import { MockSensorProvider } from './MockSensorProvider';
import { SpO2Provider } from './SpO2Provider';
import { MockSpO2Provider } from './MockSpO2Provider';
import { AppStore } from '../state/AppStore';
import { PulseState } from '../model/PulseState';

class SensorService {
  private provider: SensorProvider = new MockSensorProvider();
  private spo2Provider: SpO2Provider = new MockSpO2Provider();

  start(store: AppStore): void {
    store.applyReading(this.provider.read());
    store.capabilities = this.provider.capabilities();
    store.applySpO2(this.spo2Provider.read());
  }

  selectVariant(state: PulseState, store: AppStore): void {
    (this.provider as MockSensorProvider).setVariant(state);
    store.applyReading(this.provider.read());
  }

  release(): void {
    this.provider.release();
    this.spo2Provider.release();
  }
}

export const sensorService: SensorService = new SensorService();
