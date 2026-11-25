import { preferences } from '@kit.ArkData';
import { Context } from '@kit.AbilityKit';
import { RangeBucket } from '../state/RangeModel';
import { Logger } from '../util/Logger';

const TAG: string = 'RangeRepository';
const STORE_NAME: string = 'auracare_range';
const KEY_BUCKETS: string = 'buckets';

/** Agregados horarios del rango personal (máx. 168 entradas, solo en el reloj). */
class RangeRepository {
  private store: preferences.Preferences | undefined = undefined;

  init(context: Context): void {
    try {
      this.store = preferences.getPreferencesSync(context, { name: STORE_NAME });
    } catch (err) {
      Logger.error(TAG, 'getPreferencesSync falló', err as Object);
    }
  }

  load(): RangeBucket[] {
    if (this.store === undefined) {
      return [];
    }
    try {
      const raw: string = this.store.getSync(KEY_BUCKETS, '[]') as string;
      return JSON.parse(raw) as RangeBucket[];
    } catch (err) {
      Logger.error(TAG, 'load falló', err as Object);
      return [];
    }
  }

  save(buckets: RangeBucket[]): void {
    if (this.store === undefined) {
      return;
    }
    try {
      this.store.putSync(KEY_BUCKETS, JSON.stringify(buckets));
      this.store.flush().catch((err: Object): void => {
        Logger.error(TAG, 'flush falló', err);
      });
    } catch (err) {
      Logger.error(TAG, 'save falló', err as Object);
    }
  }
}

export const rangeRepository: RangeRepository = new RangeRepository();
