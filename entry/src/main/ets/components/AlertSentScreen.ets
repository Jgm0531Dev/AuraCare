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

  @Builder
  contactCard(contact: EmergencyContact) {
    Row({ space: dimens.cqw(DesignTokens.demoGapCqw) }) {
      Text(contact.initials)
        .fontSize(dimens.u(DesignTokens.fsLabel))
        .fontColor($r('app.color.text_primary'))
        .fontWeight(FontWeight.Bold)
        .width(dimens.cqw(DesignTokens.alertContactAvatarCqw))
        .height(dimens.cqw(DesignTokens.alertContactAvatarCqw))
        .borderRadius(dimens.cqw(DesignTokens.alertContactAvatarCqw / 2))
        .backgroundColor(contact.color)
        .textAlign(TextAlign.Center)

      Column({ space: dimens.vp(DesignTokens.thinBorder) }) {
        Text(contact.name)
          .fontSize(dimens.u(DesignTokens.fsLabel))
          .fontColor($r('app.color.text_primary'))
        Text(contact.role)
          .fontSize(dimens.u(DesignTokens.fsMin))
          .fontColor($r('app.color.muted'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(this.contactStatus(contact))
        .fontSize(dimens.u(DesignTokens.fsMin))
        .fontColor(this.statusColor(contact))
    }
    .width('100%')
    .height(dimens.cqw(DesignTokens.alertContactRowMinHeightCqw))
    .padding({
      left: dimens.cqw(DesignTokens.infoCardPaddingCqw),
      right: dimens.cqw(DesignTokens.infoCardPaddingCqw)
    })
    .backgroundColor($r('app.color.card'))
    .borderRadius(dimens.radiusCard())
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  alertBody() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column({ space: dimens.cqw(DesignTokens.alertContentGapCqw) }) {
        Column({ space: dimens.cqw(DesignTokens.demoGapCqw) }) {
          Row({ space: dimens.cqw(DesignTokens.headerGapCqw) }) {
            Text(this.headerIcon())
              .fontSize(dimens.u(DesignTokens.fsSubtitle))
              .fontColor(this.headerColor())
              .fontWeight(FontWeight.Bold)
            Text(this.title())
              .fontSize(dimens.u(DesignTokens.alertSentHeader))
              .fontColor($r('app.color.text_primary'))
              .fontWeight(FontWeight.Bold)
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)

          Text(this.headerReason())
            .fontSize(dimens.u(DesignTokens.fsMin))
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Center)
            .width('100%')
        }
        .width('100%')

        Scroll() {
          Column({ space: dimens.cqw(DesignTokens.alertContentGapCqw) }) {
            if (this.isOffline()) {
              Text($r('app.string.offline_banner'))
                .fontSize(dimens.u(DesignTokens.fsMin))
                .fontColor($r('app.color.orange'))
              if (this.hasContacts()) {
                Text($r('app.string.retrying'))
                  .fontSize(dimens.u(DesignTokens.fsMin))
                  .fontColor($r('app.color.muted'))
              }
            }

            Column({ space: dimens.vp(DesignTokens.thinBorder) }) {
              Row({ space: dimens.cqw(DesignTokens.demoGapCqw) }) {
                Text($r('app.string.frequency'))
                  .fontSize(dimens.u(DesignTokens.fsLabel))
                  .fontColor($r('app.color.text_secondary'))
                Text($r('app.string.frequency_value', appStore.bpm))
                  .fontSize(dimens.u(DesignTokens.fsLabel))
                  .fontColor($r('app.color.text_primary'))
              }
              .width('100%')
              Text($r('app.string.location_shared'))
                .fontSize(dimens.u(DesignTokens.fsMin))
                .fontColor($r('app.color.green'))
            }
            .width(dimens.cqw(DesignTokens.alertCardWidthCqw))
            .padding(dimens.cqw(DesignTokens.infoCardPaddingCqw))
            .backgroundColor($r('app.color.card'))
            .borderRadius(dimens.radiusCard())

            if (this.hasContacts()) {
              List({ space: dimens.cqw(DesignTokens.demoGapCqw) }) {
                ForEach(appStore.contacts, (contact: EmergencyContact): void => {
                  ListItem() {
                    this.contactCard(contact)
                  }
                }, (contact: EmergencyContact): string => contact.id)
              }
              .width(dimens.cqw(DesignTokens.alertCardWidthCqw))
              .height(dimens.cqw(DesignTokens.alertContactRowMinHeightCqw * 2.6))
              .scrollBar(BarState.Off)
              .edgeEffect(EdgeEffect.Fade)

              Column({ space: dimens.vp(DesignTokens.thinBorder) }) {
                Text($r('app.string.next_notice_time', this.formatTime(appStore.nextNoticeSeconds)))
                  .fontSize(dimens.u(DesignTokens.fsMin))
                  .fontColor($r('app.color.text_secondary'))
                if (this.onWayName().length > 0) {
                  Text($r('app.string.on_way_name', this.onWayName()))
                    .fontSize(dimens.u(DesignTokens.fsMin))
                    .fontColor($r('app.color.green'))
                }
              }
              .width(dimens.cqw(DesignTokens.alertCardWidthCqw))
            } else {
              Text($r('app.string.no_emergency_contacts'))
                .fontSize(dimens.u(DesignTokens.fsMin))
                .fontColor($r('app.color.muted'))
            }

            Column({ space: dimens.vp(DesignTokens.countdownButtonGap) }) {
              Button() {
                Text($r('app.string.call_911_action'))
                  .fontSize(dimens.u(DesignTokens.fsLabel))
                  .fontColor($r('app.color.text_primary'))
              }
              .width(dimens.cqw(DesignTokens.alertCardWidthCqw))
              .height(dimens.primaryButtonHeight())
              .borderRadius(dimens.cqw(DesignTokens.demoButtonRadiusCqw))
              .backgroundColor($r('app.color.red'))
              .onClick((): void => {
                emergencyService.openDialog(DialogKind.Call911);
              })

              if (this.hasContacts()) {
                Button() {
                  Text($r('app.string.cancel_alert'))
                    .fontSize(dimens.u(DesignTokens.fsLabel))
                    .fontColor($r('app.color.text_primary'))
                }
                .width(dimens.cqw(DesignTokens.alertCardWidthCqw))
                .height(dimens.primaryButtonHeight())
                .borderRadius(dimens.cqw(DesignTokens.demoButtonRadiusCqw))
                .backgroundColor($r('app.color.card'))
                .onClick((): void => {
                  emergencyService.openDialog(DialogKind.CancelAlert);
                })
              } else {
                Button() {
                  Text($r('app.string.add_contact'))
                    .fontSize(dimens.u(DesignTokens.fsLabel))
                    .fontColor($r('app.color.text_primary'))
                }
                .width(dimens.cqw(DesignTokens.alertCardWidthCqw))
                .height(dimens.primaryButtonHeight())
                .borderRadius(dimens.cqw(DesignTokens.demoButtonRadiusCqw))
                .backgroundColor($r('app.color.green'))
                .onClick((): void => {
                  emergencyService.openDialog(DialogKind.AddContact);
                })
              }
            }
            .width(dimens.cqw(DesignTokens.alertCardWidthCqw))
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }

  build() {
    ScreenScaffold({
      logTag: 'AlertSentScreen',
      scaffoldBackground: $r('app.color.surface_deep'),
      bodyContent: (): void => {
        this.alertBody();
      }
    })
  }
}
