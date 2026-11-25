import { vibrator } from '@kit.SensorServiceKit';
import { abilityAccessCtrl, Context, Permissions } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { VibrationPattern } from '../state/EmergencyMachine';

const DOMAIN = 0xA20C;
const TAG = 'AuraCareVibration';
const PERMISSION: Permissions = 'ohos.permission.VIBRATE';
const SHORT_MS: number = 200;
const PULSE_MS: number = 120;
const GAP_MS: number = 60;

/** Ejecuta la vibración de alertas. No conoce la UI ni la máquina de estados. */
class VibrationService {
  private context: Context | undefined = undefined;
  private pulseTimer: number | undefined = undefined;

  init(context: Context): void {
    this.context = context;
    // VIBRATE es system_grant: se concede al instalar, no hace falta pedirlo en tiempo de ejecución.
  }

  async requestPermission(): Promise<void> {
    if (this.context === undefined) {
      return;
    }
    try {
      const manager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const result = await manager.requestPermissionsFromUser(this.context, [PERMISSION]);
      hilog.info(DOMAIN, TAG, 'Permiso de vibración concedido: %{public}d', result.authResults[0]);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'No se pudo solicitar el permiso de vibración: %{public}s', JSON.stringify(err));
    }
  }

  vibrate(pattern: VibrationPattern): void {
    if (pattern === VibrationPattern.None) {
      return;
    }
    if (pattern === VibrationPattern.Short) {
      this.pulse(SHORT_MS);
      return;
    }
    this.pulse(PULSE_MS);
    this.clearPulseTimer();
    this.pulseTimer = setTimeout((): void => {
      this.pulseTimer = undefined;
      this.pulse(PULSE_MS);
    }, PULSE_MS + GAP_MS);
  }

  dispose(): void {
    this.clearPulseTimer();
    this.context = undefined;
  }

  private clearPulseTimer(): void {
    if (this.pulseTimer !== undefined) {
      clearTimeout(this.pulseTimer);
      this.pulseTimer = undefined;
    }
  }

  private pulse(duration: number): void {
    try {
      const effect: vibrator.VibrateTime = { type: 'time', duration: duration };
      const attribute: vibrator.VibrateAttribute = { usage: 'notification' };
      vibrator.startVibration(effect, attribute);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'No se pudo vibrar: %{public}s', JSON.stringify(err));
    }
  }
}

export const vibrationService: VibrationService = new VibrationService();
