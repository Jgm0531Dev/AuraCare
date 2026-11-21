import { SpO2Reading } from '../model/SpO2Reading';

export interface SpO2Provider {
  isAvailable(): boolean;
  setAvailable(available: boolean): void;
  setPercent(percent: number): void;
  read(): SpO2Reading;
  release(): void;
}
