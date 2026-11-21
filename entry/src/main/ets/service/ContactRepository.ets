import { preferences } from '@kit.ArkData';
import { Context } from '@kit.AbilityKit';
import { EmergencyContact } from '../model/EmergencyContact';
import { Logger } from '../util/Logger';

const TAG: string = 'ContactRepository';
const STORE_NAME: string = 'auracare_contacts';
const KEY_CONTACTS: string = 'contacts';
/** Prefijo de id de los contactos reales; los de ejemplo (c1..c5) nunca se guardan. */
export const USER_CONTACT_PREFIX: string = 'user-';
export const MAX_CONTACTS: number = 5;

/** Forma persistida (sin Resource): el color se recalcula por índice al cargar. */
interface StoredContact {
  id: string;
  name: string;
  phone: string;
  colorIndex: number;
}

const CONTACT_COLORS: Resource[] = [
  $r('app.color.contact_ml'), $r('app.color.contact_cg'), $r('app.color.contact_er'),
  $r('app.color.contact_pm'), $r('app.color.contact_lf')
];

export function isUserContact(contact: EmergencyContact): boolean {
  return contact.id.startsWith(USER_CONTACT_PREFIX);
}

export function initialsOf(name: string): string {
  const trimmed: string = name.trim();
  return trimmed.length === 0 ? '?' : trimmed.substring(0, 2).toUpperCase();
}

/** Persistencia local con @kit.ArkData preferences (API síncrona, SDK 6.1.1). */
class ContactRepository {
  private store: preferences.Preferences | undefined = undefined;

  init(context: Context): void {
    try {
      this.store = preferences.getPreferencesSync(context, { name: STORE_NAME });
    } catch (err) {
      Logger.error(TAG, 'getPreferencesSync falló', err as Object);
    }
  }

  load(): EmergencyContact[] {
    if (this.store === undefined) {
      return [];
    }
    try {
      const raw: string = this.store.getSync(KEY_CONTACTS, '[]') as string;
      const stored: StoredContact[] = JSON.parse(raw) as StoredContact[];
      const contacts: EmergencyContact[] = stored.slice(0, MAX_CONTACTS).map((item: StoredContact): EmergencyContact => {
        return {
          id: item.id,
          name: item.name,
          role: item.phone,
          initials: initialsOf(item.name),
          color: CONTACT_COLORS[Math.abs(item.colorIndex) % CONTACT_COLORS.length],
          step: 0,
          phone: item.phone
        };
      });
      Logger.info(TAG, `cargados ${contacts.length} contactos`);
      return contacts;
    } catch (err) {
      Logger.error(TAG, 'load falló', err as Object);
      return [];
    }
  }

  /** Guarda solo los contactos reales; los de ejemplo se filtran aquí. */
  save(contacts: EmergencyContact[]): void {
    if (this.store === undefined) {
      return;
    }
    const stored: StoredContact[] = contacts.filter(isUserContact).map(
      (contact: EmergencyContact, index: number): StoredContact => {
        return { id: contact.id, name: contact.name, phone: contact.phone ?? '', colorIndex: index };
      });
    try {
      this.store.putSync(KEY_CONTACTS, JSON.stringify(stored));
      this.store.flush().catch((err: Object): void => {
        Logger.error(TAG, 'flush falló', err);
      });
      Logger.info(TAG, `guardados ${stored.length} contactos`);
    } catch (err) {
      Logger.error(TAG, 'save falló', err as Object);
    }
  }

  colorFor(index: number): Resource {
    return CONTACT_COLORS[Math.abs(index) % CONTACT_COLORS.length];
  }
}

export const contactRepository: ContactRepository = new ContactRepository();
