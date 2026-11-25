import { preferences } from '@kit.ArkData';
import { Context } from '@kit.AbilityKit';
import { AlertState } from '../model/Alert';
import { AlertReason } from '../model/AlertReason';
import { Logger } from '../util/Logger';

const TAG: string = 'AlertStateRepository';
const STORE_NAME: string = 'auracare_alert';
const KEY_ALERT: string = 'alert';

/** Alerta en curso persistida para recuperarla tras segundo plano o reinicio. */
export interface StoredAlert {
  state: AlertState;
  reason: AlertReason;
  /** Segundos restantes de la cuenta en el momento de guardar (0 en Alerta activa). */
  remainingSeconds: number;
  alertBpm: number;
  savedAt: number;
}

class AlertStateRepository {
  private store: preferences.Preferences | undefined = undefined;

  init(context: Context): void {
    try {
      this.store = preferences.getPreferencesSync(context, { name: STORE_NAME });
    } catch (err) {
      Logger.error(TAG, 'getPreferencesSync falló', err as Object);
    }
  }

  load(): StoredAlert | undefined {
    if (this.store === undefined) {
      return undefined;
    }
    try {
      const raw: string = this.store.getSync(KEY_ALERT, '') as string;
      if (raw.length === 0) {
        return undefined;
      }
      const stored: StoredAlert = JSON.parse(raw) as StoredAlert;
      return stored.state === AlertState.None ? undefined : stored;
    } catch (err) {
      Logger.error(TAG, 'load falló', err as Object);
      return undefined;
    }
  }

  save(alert: StoredAlert): void {
    this.write(JSON.stringify(alert));
  }

  clear(): void {
    this.write('');
  }

  private write(value: string): void {
    if (this.store === undefined) {
      return;
    }
    try {
      this.store.putSync(KEY_ALERT, value);
      this.store.flush().catch((err: Object): void => {
        Logger.error(TAG, 'flush falló', err);
      });
    } catch (err) {
      Logger.error(TAG, 'write falló', err as Object);
    }
  }
}

export const alertStateRepository: AlertStateRepository = new AlertStateRepository();
