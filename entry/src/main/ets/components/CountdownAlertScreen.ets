import { AlertReason } from '../model/AlertReason';
import { AlertState } from '../model/Alert';
import { appStore } from '../state/AppStore';
import { emergencyService } from '../service/EmergencyService';
import { CountdownRing } from './CountdownRing';
import { ScreenScaffold } from './ScreenScaffold';
import { DesignTokens } from '../util/DesignTokens';
import { dimens } from '../util/Dimens';

const CRITICAL_REASON_BPM: number = 132;

/** Pantalla de `¿Estás bien?` y de `Pidiendo ayuda`. Bloquea navegación y gestos. */
@ComponentV2
export struct CountdownAlertScreen {
  private isSos(): boolean {
    return appStore.emergency.state === AlertState.SosCountdown;
  }

  private title(): Resource {
    return this.isSos() ? $r('app.string.asking_help') : $r('app.string.are_you_ok');
  }

  private reasonText(): Resource {
    const reason: AlertReason = appStore.emergency.reason;
    if (reason === AlertReason.Caida) {
      return $r('app.string.reason_fall');
    }
    if (reason === AlertReason.SosManual) {
      return $r('app.string.reason_sos');
    }
    return $r('app.string.reason_pulse', CRITICAL_REASON_BPM);
  }

  @Builder
  countdownBody() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width(dimens.cqw(DesignTokens.countdownHaloSizeCqw))
        .height(dimens.cqw(DesignTokens.countdownHaloSizeCqw))
        .borderRadius(dimens.cqw(DesignTokens.countdownHaloSizeCqw / 2))
        .backgroundColor($r('app.color.red'))
        .opacity(0.12)

      Column({ space: dimens.vp(DesignTokens.countdownButtonGap) }) {
        Text(this.title())
          .fontSize(dimens.u(DesignTokens.areYouOkHeader))
          .fontColor($r('app.color.text_primary'))
          .fontWeight(FontWeight.Bold)

        CountdownRing({
          value: appStore.emergencySeconds,
          total: this.isSos() ? 5 : 30,
          emptyClockwise: !this.isSos(),
          critical: !this.isSos() && appStore.emergencySeconds <= 10
        })

        Text(this.reasonText())
          .fontSize(dimens.u(DesignTokens.fsLabel))
          .fontColor($r('app.color.text_secondary'))
          .margin({ bottom: dimens.vp(DesignTokens.countdownReasonMarginBottom) })

        if (this.isSos()) {
          Button() {
            Text($r('app.string.cancel'))
              .fontSize(dimens.u(DesignTokens.fsLabel))
              .fontColor($r('app.color.text_primary'))
          }
          .width(dimens.percent(DesignTokens.primaryButtonWidthPercent))
          .height(dimens.primaryButtonHeight())
          .borderRadius(dimens.cqw(DesignTokens.demoButtonRadiusCqw))
          .backgroundColor($r('app.color.card'))
          .accessibilityText($r('app.string.a11y_cancel_sos'))
          .onClick((): void => {
            emergencyService.cancelSos();
          })
        } else {
          Button() {
            Text($r('app.string.im_fine'))
              .fontSize(dimens.u(DesignTokens.fsLabel))
              .fontColor($r('app.color.text_primary'))
          }
          .width(dimens.percent(DesignTokens.primaryButtonWidthPercent))
          .height(dimens.primaryButtonHeight())
          .borderRadius(dimens.cqw(DesignTokens.demoButtonRadiusCqw))
          .backgroundColor($r('app.color.green'))
          .accessibilityText($r('app.string.a11y_im_fine'))
          .onClick((): void => {
            emergencyService.safe();
          })

          Button() {
            Text($r('app.string.help_now'))
              .fontSize(dimens.u(DesignTokens.fsLabel))
              .fontColor($r('app.color.text_primary'))
          }
          .width(dimens.percent(DesignTokens.primaryButtonWidthPercent))
          .height(dimens.primaryButtonHeight())
          .borderRadius(dimens.cqw(DesignTokens.demoButtonRadiusCqw))
          .backgroundColor($r('app.color.red'))
          .border({ width: dimens.thinBorder(), color: $r('app.color.text_primary') })
          .accessibilityText($r('app.string.a11y_help_now'))
          .onClick((): void => {
            emergencyService.helpNow();
          })
        }
      }
      .width('100%')
      .height('100%')
      .justifyContent(this.isSos() ? FlexAlign.SpaceBetween : FlexAlign.Start)
    }
    .width('100%')
    .height('100%')
  }

  build() {
    ScreenScaffold({
      logTag: 'CountdownAlertScreen',
      bodyContent: (): void => {
        this.countdownBody();
      }
    })
  }
}
