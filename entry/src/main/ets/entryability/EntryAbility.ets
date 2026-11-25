import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { emergencyService } from '../service/EmergencyService';
import { notificationService } from '../service/NotificationService';

const DOMAIN: number = 0xA10A;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'EntryAbility', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'EntryAbility', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'EntryAbility', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'EntryAbility', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'EntryAbility', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'EntryAbility', 'Succeeded in loading the content.');
      // Vigilancia solo en primer plano (no hay BackgroundMode legítimo para esto):
      // la pantalla se mantiene encendida mientras la app está abierta.
      try {
        windowStage.getMainWindowSync().setWindowKeepScreenOn(true).catch((e: Object): void => {
          hilog.error(DOMAIN, 'EntryAbility', 'setWindowKeepScreenOn falló: %{public}s', JSON.stringify(e));
        });
      } catch (e) {
        hilog.error(DOMAIN, 'EntryAbility', 'getMainWindowSync falló: %{public}s', JSON.stringify(e));
      }
      // Permiso de notificaciones y canal propio (diálogo del sistema una sola vez).
      notificationService.init(this.context).catch((e: Object): void => {
        hilog.error(DOMAIN, 'EntryAbility', 'notificationService.init falló: %{public}s', JSON.stringify(e));
      });
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'EntryAbility', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'EntryAbility', '%{public}s', 'Ability onForeground');
    emergencyService.onForeground();
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'EntryAbility', '%{public}s', 'Ability onBackground');
    emergencyService.onBackground();
  }
}