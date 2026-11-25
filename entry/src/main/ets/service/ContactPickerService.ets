import { contact } from '@kit.ContactsKit';
import { Logger } from '../util/Logger';

const TAG: string = 'ContactPickerService';
const CONTACTS_SYSCAP: string = 'SystemCapability.Applications.Contacts';

export interface PickedContact {
  name: string;
  /** Solo dígitos (se descartan espacios, guiones, paréntesis y '+'). */
  phone: string;
}

/**
 * Picker de contactos del sistema (contact.selectContacts, sin permiso READ_CONTACTS).
 * En el SDK 6.1.1(24) el perfil wearable no declara SystemCapability.Applications.Contacts:
 * en el reloj se espera false y el botón se oculta. Solo se llama tras canIUse y dentro de try/catch.
 */
class ContactPickerService {
  isAvailable(): boolean {
    try {
      return canIUse(CONTACTS_SYSCAP);
    } catch (err) {
      Logger.error(TAG, 'canIUse falló', err as Object);
      return false;
    }
  }

  /** undefined si el usuario cancela, el Picker falla o el contacto no tiene teléfono. */
  async pick(): Promise<PickedContact | undefined> {
    if (!this.isAvailable()) {
      return undefined;
    }
    try {
      const result: contact.Contact[] = await contact.selectContacts({ isMultiSelect: false });
      if (result.length === 0) {
        return undefined;
      }
      const chosen: contact.Contact = result[0];
      const numbers: contact.PhoneNumber[] = chosen.phoneNumbers ?? [];
      if (numbers.length === 0) {
        Logger.warn(TAG, 'contacto sin teléfono');
        return undefined;
      }
      const phone: string = numbers[0].phoneNumber.replace(/[^0-9]/g, '');
      const name: string = (chosen.name?.fullName ?? '').trim();
      return { name: name, phone: phone };
    } catch (err) {
      Logger.error(TAG, 'selectContacts falló', err as Object);
      return undefined;
    }
  }
}

export const contactPickerService: ContactPickerService = new ContactPickerService();
