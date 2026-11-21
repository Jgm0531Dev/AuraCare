import { SpO2Provider } from './SpO2Provider';
import { SpO2Reading, SpO2Source } from '../model/SpO2Reading';

export class MockSpO2Provider implements SpO2Provider {
  private percent: number = 98;
  private available: boolean = true;

  setPercent(value: number): void {
    this.percent = value;
  }

  setAvailable(available: boolean): void {
    this.available = available;
  }

  isAvailable(): boolean {
    return this.available;
  }

  read(): SpO2Reading {
    return {
      percent: this.percent,
      source: this.available ? SpO2Source.Simulated : SpO2Source.Unavailable,
      simulated: this.available,
      timestamp: Date.now()
    };
  }

  release(): void {
    // El mock no posee recursos del sistema.
  }
}
