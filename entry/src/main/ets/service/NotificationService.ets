import { notificationManager } from '@kit.NotificationKit';
import { wantAgent, WantAgent } from '@kit.AbilityKit';
import { common } from '@kit.AbilityKit';
import { Logger } from '../util/Logger';

const TAG: string = 'NotificationService';
const ALERT_NOTIFICATION_ID: number = 1001;
const BUNDLE_NAME: string = 'com.jgmht.auracare';
const ABILITY_NAME: string = 'EntryAbility';

/**
 * Notificación local de la alerta (no sale del reloj). Canal propio: slot SOCIAL_COMMUNICATION
 * (el tipo de slot de mayor prioridad que puede crear una app de terceros).
 * Si el usuario no permite notificaciones, la alarma (vibración + sonido) sigue funcionando.
 */
class NotificationService {
  private enabled: boolean = false;
  private slotReady: boolean = false;

  isEnabled(): boolean {
    return this.enabled;
  }

  /** Pide permiso de notificaciones una vez (diálogo del sistema) y crea el canal. */
  async init(context: common.UIAbilityContext): Promise<void> {
    try {
      this.enabled = await notificationManager.isNotificationEnabled();
      if (!this.enabled) {
        await notificationManager.requestEnableNotification(context);
        this.enabled = await notificationManager.isNotificationEnabled();
      }
    } catch (err) {
      this.enabled = false;
      Logger.error(TAG, 'requestEnableNotification falló o fue rechazado', err as Object);
    }
    if (!this.enabled) {
      Logger.warn(TAG, 'notificaciones desactivadas: solo alarma local');
      return;
    }
    try {
      await notificationManager.addSlot(notificationManager.SlotType.SOCIAL_COMMUNICATION);
      this.slotReady = true;
    } catch (err) {
      Logger.error(TAG, 'addSlot falló', err as Object);
    }
  }

  /** Publica (o reemplaza) la notificación de alerta. Tocarla abre la app. */
  async publishAlert(title: string, text: string): Promise<void> {
    if (!this.enabled) {
      return;
    }
    try {
      const agent: WantAgent = await wantAgent.getWantAgent({
        wants: [{ bundleName: BUNDLE_NAME, abilityName: ABILITY_NAME }],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      });
      const request: notificationManager.NotificationRequest = {
        id: ALERT_NOTIFICATION_ID,
        notificationSlotType: this.slotReady ? notificationManager.SlotType.SOCIAL_COMMUNICATION :
          notificationManager.SlotType.SERVICE_INFORMATION,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: { title: title, text: text }
        },
        wantAgent: agent
      };
      await notificationManager.publish(request);
    } catch (err) {
      Logger.error(TAG, 'publish falló', err as Object);
    }
  }

  cancelAlert(): void {
    notificationManager.cancel(ALERT_NOTIFICATION_ID).catch((err: Object): void => {
      Logger.error(TAG, 'cancel falló', err);
    });
  }
}

export const notificationService: NotificationService = new NotificationService();
