import { AlertReason } from '../model/AlertReason';
import { EmergencyContact } from '../model/EmergencyContact';
import { DialogKind, appStore } from '../state/AppStore';
import { emergencyService } from '../service/EmergencyService';
import { DesignTokens } from '../util/DesignTokens';
import { dimens } from '../util/Dimens';
import { ScreenScaffold } from './ScreenScaffold';

/** Pantalla de alerta enviada, pendiente o sin contactos. Nunca confirma un envío ficticio. */
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
    return $r('app.string.reason_pulse', appStore.bpm);
  }

  private headerColor(): Resource {
    return this.hasContacts() && !this.isOffline() ? $r('app.color.green') : $r('app.color.orange');
  }

  private headerIcon(): Resource {
    return this.hasContacts() && !this.isOffline() ? $r('app.string.icon_check') : $r('app.string.icon_warning');
  }

  private contactStatus(contact: EmergencyContact): Resource {
    if (this.isOffline()) {
      return $r('app.string.contact_pending');
    }
    if (contact.step >= 2) {
      return $r('app.string.contact_on_way');
    }
    if (contact.step === 1) {
      return $r('app.string.contact_received');
    }
    return $r('app.string.contact_sent');
  }

  private statusColor(contact: EmergencyContact): Resource {
    if (this.isOffline()) {
      return $r('app.color.orange');
    }
    if (contact.step >= 1) {
      return $r('app.color.green');
    }
    return $r('app.color.muted');
  }

  private onWayName(): string {
    for (const contact of appStore.contacts) {
      if (contact.step >= 2) {
        return contact.name;
      }
    }
    return '';
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

      Text(this.contactStatus(contact))
        .fontSize(dimens.u(DesignTokens.fsMin))
        .fontColor(this.statusColor(contact))
        .maxLines(1)
        .flexShrink(0)
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
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
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
          Text($r('app.string.location_shared'))
            .fontSize(dimens.u(DesignTokens.fsMin))
            .fontColor($r('app.color.green'))
            .maxLines(1)
        }
        .width('100%')
        .height(dimens.u(DesignTokens.alertRowHeightBase))
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('app.color.card'))
        .borderRadius(dimens.radiusCard())

        if (this.hasContacts()) {
          ForEach(appStore.contacts, (contact: EmergencyContact): void => {
            this.contactRow(contact)
          }, (contact: EmergencyContact): string => `${contact.id}-${contact.step}`)

          Text($r('app.string.next_notice_time', this.formatTime(appStore.nextNoticeSeconds)))
            .fontSize(dimens.u(DesignTokens.fsMin))
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
          if (this.onWayName().length > 0) {
            Text($r('app.string.on_way_name', this.onWayName()))
              .fontSize(dimens.u(DesignTokens.fsMin))
              .fontColor($r('app.color.green'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        } else {
          Text($r('app.string.no_emergency_contacts'))
            .fontSize(dimens.u(DesignTokens.fsMin))
            .fontColor($r('app.color.muted'))
            .textAlign(TextAlign.Center)
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
            emergencyService.openDialog(DialogKind.AddContact);
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
  }

  build() {
    ScreenScaffold({
      logTag: 'AlertSentScreen',
      scaffoldBackground: $r('app.color.surface_deep'),
      headerHeightBase: DesignTokens.alertHeaderBase,
      headerContent: (): void => {
        this.alertHeader();
      },
      bodyContent: (): void => {
        this.alertBody();
      }
    })
  }
}
