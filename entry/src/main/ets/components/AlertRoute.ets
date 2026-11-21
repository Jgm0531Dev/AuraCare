import { AlertState } from '../model/Alert';
import { appStore } from '../state/AppStore';
import { DEBUG_LAYOUT } from '../util/Dimens';
import { Logger } from '../util/Logger';
import { CountdownAlertScreen } from './CountdownAlertScreen';
import { AlertSentScreen } from './AlertSentScreen';

const TAG: string = 'AlertRoute';

/**
 * Ruta 'alert' de la NavPathStack. Las capas hermanas de Navigation en el Stack raíz
 * quedaban debajo de Navigation (previewer.log: onAppear sí, toques al Monitor), así que
 * las pantallas de emergencia se muestran como NavDestination, igual que el panel demo.
 */
@ComponentV2
export struct AlertRoute {
  build() {
    NavDestination() {
      Stack() {
        if (appStore.emergency.state === AlertState.AreYouOk ||
            appStore.emergency.state === AlertState.SosCountdown) {
          CountdownAlertScreen()
            .width('100%')
            .height('100%')
        } else if (appStore.emergency.state === AlertState.AlertSent) {
          AlertSentScreen()
            .width('100%')
            .height('100%')
        }
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.watch_background'))
    .onShown((): void => {
      if (DEBUG_LAYOUT) {
        Logger.info(TAG, `[trace] ruta alert visible: alert=${appStore.emergency.state}`);
      }
    })
    // La alerta solo se sale con sus propios botones (Estoy bien, Cancelar, etc.).
    .onBackPressed((): boolean => true)
  }
}
