import { SpO2Reading } from '../model/SpO2Reading';

export interface SpO2Provider {
  isAvailable(): boolean;
  read(): SpO2Reading;
  release(): void;
}
