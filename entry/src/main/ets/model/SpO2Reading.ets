export enum SpO2Source {
  Simulated = 'simulated',
  Real = 'real',
  Unavailable = 'unavailable'
}

export interface SpO2Reading {
  percent: number;
  source: SpO2Source;
  simulated: boolean;
  timestamp: number;
}
