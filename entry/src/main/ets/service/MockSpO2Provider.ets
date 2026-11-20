import { SpO2Provider } from './SpO2Provider';
import { SpO2Reading, SpO2Source } from '../model/SpO2Reading';

export class MockSpO2Provider implements SpO2Provider {
  private percent: number = 98;

  setPercent(value: number): void {
    this.percent = value;
  }

  isAvailable(): boolean {
    return true;
  }

  read(): SpO2Reading {
    return {
      percent: this.percent,
      source: SpO2Source.Simulated,
      simulated: true,
      timestamp: Date.now()
    };
  }

  release(): void {
    // El mock no posee recursos del sistema.
  }
}
