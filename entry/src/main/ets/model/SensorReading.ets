export interface SensorReading {
  bpm: number;
  spo2: number;
  temperature: number;
  movementLabel: Resource;
  timestamp: number;
  /** true solo si `bpm` viene de una medición (real o de demostración); false = sin lectura. */
  heartRateValid?: boolean;
  /** true si el acelerómetro (o la demo) aporta movimiento; false = sin dato de movimiento. */
  motionValid?: boolean;
  immobile?: boolean;
  /** Pico de aceleración (en g) desde la lectura anterior; 0 si no hay dato. */
  peakG?: number;
  /** true si el sensor WEAR_DETECTION dice que el reloj no está puesto (solo lecturas reales). */
  notWorn?: boolean;
}
