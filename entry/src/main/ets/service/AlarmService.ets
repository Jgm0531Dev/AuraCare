import { media } from '@kit.MediaKit';
import { audio } from '@kit.AudioKit';
import { vibrator } from '@kit.SensorServiceKit';
import { Context } from '@kit.AbilityKit';
import { resourceManager } from '@kit.LocalizationKit';
import { Logger } from '../util/Logger';
import { logVibrators, startLoggedVibration } from './VibrationService';

const TAG: string = 'AlarmService';
const ALARM_FILE: string = 'alarm.wav';
const VIBRATE_ON_MS: number = 900;
const VIBRATE_PERIOD_MS: number = 1500;

/**
 * Alarma local del reloj: vibración en bucle + sonido en bucle (rawfile/alarm.wav, uso ALARM).
 * Si el audio falla (emulador, sin altavoz), sigue la vibración y se registra el error.
 */
class AlarmService {
  private context: Context | undefined = undefined;
  private player: media.AVPlayer | undefined = undefined;
  private vibrateTimer: number | undefined = undefined;
  private ringing: boolean = false;
  private soundOk: boolean = false;

  init(context: Context): void {
    this.context = context;
  }

  isRinging(): boolean {
    return this.ringing;
  }

  /** true si el sonido arrancó; false = solo vibración. */
  hasSound(): boolean {
    return this.soundOk;
  }

  start(): void {
    if (this.ringing) {
      return;
    }
    this.ringing = true;
    logVibrators('alarma');
    this.vibrateOnce();
    this.vibrateTimer = setInterval((): void => {
      this.vibrateOnce();
    }, VIBRATE_PERIOD_MS);
    void this.startSound();
  }

  stop(): void {
    this.ringing = false;
    if (this.vibrateTimer !== undefined) {
      clearInterval(this.vibrateTimer);
      this.vibrateTimer = undefined;
    }
    try {
      vibrator.stopVibration();
    } catch (err) {
      Logger.error(TAG, 'stopVibration falló', err as Object);
    }
    this.releasePlayer();
  }

  private vibrateOnce(): void {
    startLoggedVibration('alarma', VIBRATE_ON_MS, 'alarm');
  }

  private async startSound(): Promise<void> {
    const context: Context | undefined = this.context;
    if (context === undefined) {
      return;
    }
    try {
      const player: media.AVPlayer = await media.createAVPlayer();
      this.player = player;
      player.on('stateChange', (state: string): void => {
        try {
          if (state === 'initialized') {
            const info: audio.AudioRendererInfo = {
              usage: audio.StreamUsage.STREAM_USAGE_ALARM,
              rendererFlags: 0
            };
            player.audioRendererInfo = info;
            player.prepare().catch((err: Object): void => {
              Logger.error(TAG, 'prepare falló', err);
            });
          } else if (state === 'prepared') {
            player.loop = true;
            if (this.ringing) {
              player.play().then((): void => {
                this.soundOk = true;
              }).catch((err: Object): void => {
                Logger.error(TAG, 'play falló', err);
              });
            }
          }
        } catch (err) {
          Logger.error(TAG, 'stateChange falló', err as Object);
        }
      });
      player.on('error', (err: Object): void => {
        this.soundOk = false;
        Logger.error(TAG, 'AVPlayer error; solo vibración', err);
      });
      const fd: resourceManager.RawFileDescriptor = await context.resourceManager.getRawFd(ALARM_FILE);
      if (!this.ringing) {
        this.releasePlayer();
        return;
      }
      player.fdSrc = { fd: fd.fd, offset: fd.offset, length: fd.length };
    } catch (err) {
      this.soundOk = false;
      Logger.error(TAG, 'no se pudo iniciar el sonido; solo vibración', err as Object);
      this.releasePlayer();
    }
  }

  private releasePlayer(): void {
    const player: media.AVPlayer | undefined = this.player;
    this.player = undefined;
    this.soundOk = false;
    if (player === undefined) {
      return;
    }
    player.release().catch((err: Object): void => {
      Logger.error(TAG, 'release falló', err);
    });
    const context: Context | undefined = this.context;
    if (context !== undefined) {
      context.resourceManager.closeRawFd(ALARM_FILE).catch((err: Object): void => {
        Logger.error(TAG, 'closeRawFd falló', err);
      });
    }
  }
}

export const alarmService: AlarmService = new AlarmService();
