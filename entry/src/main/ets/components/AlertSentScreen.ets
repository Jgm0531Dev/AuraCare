import { AlertReason } from '../model/AlertReason';
import { EmergencyContact } from '../model/EmergencyContact';
import { DialogKind, appStore } from '../state/AppStore';
import { emergencyService } from '../service/EmergencyService';
import { DesignTokens } from '../util/DesignTokens';
import { dimens } from '../util/Dimens';
import { ScreenScaffold } from './ScreenScaffold';
import { PhoneIcon } from './PhoneIcon';
import { LocationStatus } from '../service/LocationService';

/**
 * Alerta activa (v1.0.1). Lo que ocurre de verdad: alarma y notificación en el reloj, botones que
 * abren el marcador y ubicación opcional mostrada solo aquí. No se envía ningún mensaje automático.
 */
@ComponentV2
export struct AlertSentScreen {
  private hasContacts(): boolean {
    return appStore.contacts.length > 0;
  }

  private isOffline(): boolean {
    return appStore.mode === 'offline';
  }

  private title(): Resource {
    if (!this.hasContacts()) {
      return $r('app.string.no_contacts');
    }
    if (this.isOffline()) {
      return $r('app.string.alert_pending');
    }
    return $r('app.string.alert_sent');
  }

  private headerReason(): Resource {
    if (!this.hasContacts()) {
      return $r('app.string.no_alert_sent');
    }
    if (this.isOffline()) {
      return $r('app.string.offline_short');
    }
    const reason: AlertReason = appStore.emergency.reason;
    if (reason === AlertReason.Caida) {
      return $r('app.string.reason_fall');
    }
    if (reason === AlertReason.SosManual) {
      return $r('app.string.reason_sos');
    }
    // Congelado en el disparo: no cambia con lecturas posteriores.
    return $r('app.string.reason_pulse', appStore.alertBpm > 0 ? appStore.alertBpm : appStore.bpm);
  }

  private headerColor(): Resource {
    return $r('app.color.red');
  }

  private headerIcon(): Resource {
    return $r('app.string.icon_warning');
  }

  private locationText(): Resource | string {
    const status: string = appStore.locationStatus;
    if (status === LocationStatus.Found) {
      return `${appStore.latitude.toFixed(5)}, ${appStore.longitude.toFixed(5)}`;
    }
    if (status === LocationStatus.Locating) {
      return $r('app.string.location_locating');
    }
    if (status === LocationStatus.NoPermission) {
      return $r('app.string.location_no_permission');
    }
    if (status === LocationStatus.SystemDisabled) {
      return $r('app.string.location_system_off');
    }
    if (status === LocationStatus.Timeout) {
      return $r('app.string.location_timeout');
    }
    if (status === LocationStatus.ServiceUnavailable) {
      return $r('app.string.location_service_unavailable');
    }
    if (status === LocationStatus.Failed) {
      return $r('app.string.location_failed');
    }
    return $r('app.string.location_off');
  }

  private locationColor(): Resource {
    return appStore.locationStatus === LocationStatus.Found ? $r('app.color.green') : $r('app.color.muted');
  }

  private formatTime(seconds: number): string {
    const minutes: number = Math.floor(seconds / 60);
    const rest: number = seconds % 60;
    const minuteText: string = minutes < 10 ? `0${minutes}` : `${minutes}`;
    const secondText: string = rest < 10 ? `0${rest}` : `${rest}`;
    return `${minuteText}:${secondText}`;
  }

  /** Fila de alto fijo (72 base): avatar 48, nombre en una línea y estado a la derecha. */
  @Builder
  contactRow(contact: EmergencyContact) {
    Row({ space: dimens.u(DesignTokens.alertGapBase) }) {
      Text(contact.initials)
        .fontSize(dimens.u(DesignTokens.fsMin))
        .fontColor($r('app.color.text_primary'))
        .fontWeight(FontWeight.Bold)
        .width(dimens.u(DesignTokens.alertAvatarBase))
        .height(dimens.u(DesignTokens.alertAvatarBase))
        .borderRadius(dimens.u(DesignTokens.alertAvatarBase / 2))
        .backgroundColor(contact.color)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .flexShrink(0)

      Text(contact.name)
        .fontSize(dimens.u(DesignTokens.fsLabel))
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)

      // Abre el marcador del sistema con el número (el usuario confirma la llamada).
      Button() {
        PhoneIcon()
      }
      .width(dimens.touchMin())
      .height(dimens.touchMin())
      .borderRadius(dimens.touchMin() / 2)
      .backgroundColor($r('app.color.green'))
      .flexShrink(0)
      .accessibilityText($r('app.string.a11y_call_contact', contact.name))
      .onClick((): void => {
        emergencyService.callContact(contact);
      })
    }
    .width('100%')
    .height(dimens.u(DesignTokens.alertRowHeightBase))
    .padding({
      left: dimens.u(DesignTokens.alertRowPaddingBase),
      right: dimens.u(DesignTokens.alertRowPaddingBase)
    })
    .backgroundColor($r('app.color.card'))
    .borderRadius(dimens.radiusCard())
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  actionButton(label: Resource, color: Resource, onPress: () => void) {
    Button() {
      Text(label)
        .fontSize(dimens.u(DesignTokens.fsLabel))
        .fontColor($r('app.color.text_primary'))
        .fontWeight(FontWeight.Bold)
        .maxLines(1)
    }
    .width('100%')
    .height(dimens.primaryButtonHeight())
    .borderRadius(dimens.primaryButtonHeight() / 2)
    .backgroundColor(color)
    .onClick(onPress)
  }

  /** Cabecera fija: check + título en una fila y el motivo en una línea. */
  @Builder
  alertHeader() {
    Column() {
      Row({ space: dimens.u(DesignTokens.alertGapBase) }) {
        Text(this.headerIcon())
          .fontSize(dimens.u(DesignTokens.fsBody))
          .fontColor(this.headerColor())
          .fontWeight(FontWeight.Bold)
          .maxLines(1)
        Text(this.title())
          .fontSize(dimens.u(DesignTokens.alertSentHeader))
          .fontColor($r('app.color.text_primary'))
          .fontWeight(FontWeight.Bold)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .justifyContent(FlexAlign.Center)

      Text(this.headerReason())
        .fontSize(dimens.u(DesignTokens.fsMin))
        .fontColor($r('app.color.text_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)
        .width('100%')

      // Instrucción fija (no hace scroll), máx. 2 líneas: la acción es del usuario.
      Text($r('app.string.alert_banner_honest'))
        .fontSize(dimens.u(DesignTokens.fsMin))
        .lineHeight(dimens.u(DesignTokens.alertBannerLineBase))
        .fontColor($r('app.color.orange'))
        .maxLines(DesignTokens.alertBannerMaxLines)
        .textOverflow({ overflow: TextOverflow.None })
        .textAlign(TextAlign.Center)
        .width('100%')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.surface_deep'))
  }

  /** Cuerpo con scroll en flujo normal: sin posiciones absolutas ni márgenes negativos. */
  @Builder
  alertBody() {
    Scroll() {
      Column({ space: dimens.u(DesignTokens.alertGapBase) }) {
        if (this.isOffline()) {
          Text($r('app.string.offline_banner'))
            .fontSize(dimens.u(DesignTokens.fsMin))
            .fontColor($r('app.color.orange'))
            .textAlign(TextAlign.Center)
          if (this.hasContacts()) {
            Text($r('app.string.retrying'))
              .fontSize(dimens.u(DesignTokens.fsMin))
              .fontColor($r('app.color.muted'))
          }
        }

        // Tarjeta compacta de BPM y ubicación (alto fijo, en flujo).
        Column() {
          Row({ space: dimens.u(DesignTokens.chipGapBase) }) {
            Text($r('app.string.frequency'))
              .fontSize(dimens.u(DesignTokens.fsLabel))
              .fontColor($r('app.color.text_secondary'))
              .maxLines(1)
            Text($r('app.string.frequency_value', appStore.bpm))
              .fontSize(dimens.u(DesignTokens.fsLabel))
              .fontColor($r('app.color.text_primary'))
              .fontWeight(FontWeight.Bold)
              .maxLines(1)
          }
          Text(this.locationText())
            .fontSize(dimens.u(DesignTokens.fsMin))
            .fontColor(this.locationColor())
            .maxLines(2)
            .textAlign(TextAlign.Center)
            .width('100%')
          if (appStore.locationStatus === LocationStatus.Found && appStore.address.length > 0) {
            Text(appStore.address)
              .fontSize(dimens.u(DesignTokens.fsMin))
              .fontColor($r('app.color.text_secondary'))
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .textAlign(TextAlign.Center)
          }
          if (appStore.locationStatus === LocationStatus.Found) {
            Text($r('app.string.location_not_sent'))
              .fontSize(dimens.u(DesignTokens.fsMin))
              .fontColor($r('app.color.muted'))
              .maxLines(3)
              .textAlign(TextAlign.Center)
              .width('100%')
          }
        }
        .width('100%')
        .constraintSize({ minHeight: dimens.u(DesignTokens.alertRowHeightBase) })
        .padding({ top: dimens.u(DesignTokens.chipGapBase), bottom: dimens.u(DesignTokens.chipGapBase) })
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('app.color.card'))
        .borderRadius(dimens.radiusCard())

        if (this.hasContacts()) {
          ForEach(appStore.contacts, (contact: EmergencyContact): void => {
            this.contactRow(contact)
          }, (contact: EmergencyContact): string =>
            `${contact.id}|${contact.name}|${contact.phone ?? ''}|${contact.step}`)

          Text(appStore.onWay ? $r('app.string.reminders_paused') :
            $r('app.string.next_notice_time', this.formatTime(appStore.nextNoticeSeconds)))
            .fontSize(dimens.u(DesignTokens.fsMin))
            .fontColor(appStore.onWay ? $r('app.color.green') : $r('app.color.text_secondary'))
            .maxLines(1)
        } else {
          Text($r('app.string.no_emergency_contacts'))
            .fontSize(dimens.u(DesignTokens.fsMin))
            .fontColor($r('app.color.muted'))
            .textAlign(TextAlign.Center)
        }

        if (!appStore.alarmSilenced) {
          this.actionButton($r('app.string.silence_alarm'), $r('app.color.orange'), (): void => {
            emergencyService.silenceAlarm();
          })
        }
        if (this.hasContacts()) {
          this.actionButton(appStore.onWay ? $r('app.string.help_coming_undo') : $r('app.string.help_coming'),
            $r('app.color.card'), (): void => {
              emergencyService.markHelpComing(!appStore.onWay);
            })
        }
        this.actionButton($r('app.string.call_911_action'), $r('app.color.red'), (): void => {
          emergencyService.openDialog(DialogKind.Call911);
        })
        if (this.hasContacts()) {
          this.actionButton($r('app.string.cancel_alert'), $r('app.color.card'), (): void => {
            emergencyService.openDialog(DialogKind.CancelAlert);
          })
        } else {
          this.actionButton($r('app.string.add_contact'), $r('app.color.green'), (): void => {
            emergencyService.requestAddContact();
          })
        }
      }
      .width(dimens.percent(DesignTokens.primaryButtonWidthPercent))
      .alignItems(HorizontalAlign.Center)
      // Holgura final: el último botón no queda bajo el borde redondo.
      .padding({ bottom: dimens.u(DesignTokens.alertRowHeightBase) })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
    .focusable(true)
    .defaultFocus(true)
    .focusOnTouch(true)
    .digitalCrownSensitivity(CrownSensitivity.LOW)
    // Recorte justo bajo la cabecera, fondo opaco y sin rebote que asome tarjetas.
    .clip(true)
    .edgeEffect(EdgeEffect.None)
    .backgroundColor($r('app.color.surface_deep'))
  }

  build() {
    ScreenScaffold({
      logTag: 'AlertSentScreen',
      scaffoldBackground: $r('app.color.surface_deep'),
      // 64 + aviso de hasta 3 x 30 = 154 base; el cuerpo con scroll conserva ~182.
      headerHeightBase: DesignTokens.alertHeaderBase + DesignTokens.alertBannerLineBase * DesignTokens.alertBannerMaxLines,
      headerContent: (): void => {
        this.alertHeader();
      },
      bodyContent: (): void => {
        this.alertBody();
      }
    })
  }
}
