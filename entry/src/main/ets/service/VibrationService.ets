import { vibrator } from '@kit.SensorServiceKit';
import { Context } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { VibrationPattern } from '../state/EmergencyMachine';

const DOMAIN = 0xA20C;
const TAG = 'AuraCareVibration';
const SHORT_MS: number = 200;
const PULSE_MS: number = 120;
const GAP_MS: number = 60;

/**
 * Diagnóstico de vibración (también en release, solo en la ruta de alerta y "Probar vibración"):
 * lista de vibradores (getVibratorInfoSync, API 19+; getVibratorIdList no existe en el SDK 24),
 * resultado de startVibration y errores. Filtrar en hilog por el tag AuraCareVibration.
 */
export function logVibrators(origin: string): void {
  try {
    const infos: vibrator.VibratorInfo[] = vibrator.getVibratorInfoSync();
    const ids: string = infos.map((info: vibrator.VibratorInfo): string =>
      `${info.deviceId}/${info.vibratorId}`).join(',');
    hilog.info(DOMAIN, TAG, '[%{public}s] vibradores=%{public}d ids=[%{public}s]', origin, infos.length, ids);
  } catch (err) {
    hilog.error(DOMAIN, TAG, '[%{public}s] getVibratorInfoSync falló: %{public}s', origin, JSON.stringify(err));
  }
}

/** startVibration con registro del resultado. */
export function startLoggedVibration(origin: string, durationMs: number, usage: vibrator.Usage): void {
  try {
    const effect: vibrator.VibrateTime = { type: 'time', duration: durationMs };
    const attribute: vibrator.VibrateAttribute = { usage: usage };
    vibrator.startVibration(effect, attribute).then((): void => {
      hilog.info(DOMAIN, TAG, '[%{public}s] startVibration OK %{public}d ms usage=%{public}s', origin, durationMs, usage);
    }).catch((err: Object): void => {
      hilog.error(DOMAIN, TAG, '[%{public}s] startVibration rechazada: %{public}s', origin, JSON.stringify(err));
    });
  } catch (err) {
    hilog.error(DOMAIN, TAG, '[%{public}s] startVibration lanzó: %{public}s', origin, JSON.stringify(err));
  }
}

/** Ejecuta la vibración de alertas. No conoce la UI ni la máquina de estados. */
class VibrationService {
  private context: Context | undefined = undefined;
  private pulseTimer: number | undefined = undefined;

  init(context: Context): void {
    this.context = context;
    // VIBRATE es system_grant: se concede al instalar, no hace falta pedirlo en tiempo de ejecución.
  }

  vibrate(pattern: VibrationPattern, origin: string = 'alerta'): void {
    if (pattern === VibrationPattern.None) {
      return;
    }
    logVibrators(origin);
    if (pattern === VibrationPattern.Short) {
      startLoggedVibration(origin, SHORT_MS, 'notification');
      return;
    }
    startLoggedVibration(origin, PULSE_MS, 'notification');
    this.clearPulseTimer();
    this.pulseTimer = setTimeout((): void => {
      this.pulseTimer = undefined;
      startLoggedVibration(origin, PULSE_MS, 'notification');
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

}

export const vibrationService: VibrationService = new VibrationService();
