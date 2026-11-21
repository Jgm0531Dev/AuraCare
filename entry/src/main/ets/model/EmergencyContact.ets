export interface EmergencyContact {
  id: string;
  name: string;
  role: string;
  initials: string;
  color: Resource;
  step: number;
  /** Solo contactos reales (añadidos por el usuario); los de ejemplo no tienen. */
  phone?: string;
}
