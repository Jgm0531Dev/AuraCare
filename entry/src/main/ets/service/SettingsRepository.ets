import { preferences } from '@kit.ArkData';
import { Context } from '@kit.AbilityKit';
import { AppSettings } from '../state/AppStore';
import { Logger } from '../util/Logger';

const TAG: string = 'SettingsRepository';
const STORE_NAME: string = 'auracare_settings';
const KEY_SETTINGS: string = 'settings';

/** Forma persistida de Ajustes (solo tipos planos). */
interface StoredSettings {
  sensitivity?: string;
  noticeMinutes?: number;
  exerciseMode?: boolean;
  fallDetection?: boolean;
  demoMode?: boolean;
  locationEnabled?: boolean;
}

const VALID_SENSITIVITY: string[] = ['Baja', 'Media', 'Alta'];
const VALID_NOTICE: number[] = [1, 3, 5, 10];

/** Ajustes persistentes con @kit.ArkData preferences (sobreviven al reinicio). */
class SettingsRepository {
  private store: preferences.Preferences | undefined = undefined;

  init(context: Context): void {
    try {
      this.store = preferences.getPreferencesSync(context, { name: STORE_NAME });
    } catch (err) {
      Logger.error(TAG, 'getPreferencesSync falló', err as Object);
    }
  }

  /** Aplica lo guardado sobre `target`; valores inválidos o ausentes conservan el valor por defecto. */
  loadInto(target: AppSettings): void {
    if (this.store === undefined) {
      return;
    }
    try {
      const raw: string = this.store.getSync(KEY_SETTINGS, '{}') as string;
      const stored: StoredSettings = JSON.parse(raw) as StoredSettings;
      if (stored.sensitivity !== undefined && VALID_SENSITIVITY.indexOf(stored.sensitivity) >= 0) {
        target.sensitivity = stored.sensitivity;
      }
      if (stored.noticeMinutes !== undefined && VALID_NOTICE.indexOf(stored.noticeMinutes) >= 0) {
        target.noticeMinutes = stored.noticeMinutes;
      }
      if (stored.exerciseMode !== undefined) {
        target.exerciseMode = stored.exerciseMode;
      }
      if (stored.fallDetection !== undefined) {
        target.fallDetection = stored.fallDetection;
      }
      if (stored.demoMode !== undefined) {
        target.demoMode = stored.demoMode;
      }
      if (stored.locationEnabled !== undefined) {
        target.locationEnabled = stored.locationEnabled;
      }
      Logger.info(TAG, `ajustes cargados: ${raw}`);
    } catch (err) {
      Logger.error(TAG, 'loadInto falló', err as Object);
    }
  }

  save(source: AppSettings): void {
    if (this.store === undefined) {
      return;
    }
    const stored: StoredSettings = {
      sensitivity: source.sensitivity,
      noticeMinutes: source.noticeMinutes,
      exerciseMode: source.exerciseMode,
      fallDetection: source.fallDetection,
      demoMode: source.demoMode,
      locationEnabled: source.locationEnabled
    };
    try {
      this.store.putSync(KEY_SETTINGS, JSON.stringify(stored));
      this.store.flush().catch((err: Object): void => {
        Logger.error(TAG, 'flush falló', err);
      });
    } catch (err) {
      Logger.error(TAG, 'save falló', err as Object);
    }
  }
}

export const settingsRepository: SettingsRepository = new SettingsRepository();
