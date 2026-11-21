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

  @Local haloLow: boolean = false;

  private ringCritical(): boolean {
    return this.isSos() || appStore.emergencySeconds <= 10;
  }

  @Builder
  actionButton(label: Resource, color: Resource, a11y: Resource, bordered: boolean, onPress: () => void) {
    Button() {
      Text(label)
        .fontSize(dimens.u(DesignTokens.fsLabel))
        .fontColor($r('app.color.text_primary'))
        .fontWeight(FontWeight.Bold)
        .maxLines(1)
    }
    .width(dimens.percent(DesignTokens.primaryButtonWidthPercent))
    .height(dimens.primaryButtonHeight())
    .borderRadius(dimens.primaryButtonHeight() / 2)
    .backgroundColor(color)
    .border({ width: bordered ? dimens.thinBorder() * 1.5 : 0, color: $r('app.color.text_primary') })
    .accessibilityText(a11y)
    .onClick(onPress)
  }

  /** Presupuesto (base 466, zona útil ≈ 336): 30 + 6 + 96 + 6 + 30 + 6 + 72 + 8 + 72 = 326. */
  @Builder
  countdownBody() {
    Column({ space: dimens.u(DesignTokens.countdownGapBase) }) {
      Text(this.title())
        .fontSize(dimens.u(DesignTokens.fsBody))
        .lineHeight(dimens.u(DesignTokens.fsBody * 1.15))
        .fontColor($r('app.color.text_primary'))
        .fontWeight(FontWeight.Bold)
        .maxLines(1)

      CountdownRing({
        value: appStore.emergencySeconds,
        total: this.isSos() ? 5 : 30,
        critical: this.ringCritical()
      })

      Text(this.reasonText())
        .fontSize(dimens.u(DesignTokens.fsLabel))
        .lineHeight(dimens.u(DesignTokens.fsLabel * 1.15))
        .fontColor($r('app.color.text_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Column({ space: dimens.u(DesignTokens.countdownButtonGapBase) }) {
        if (this.isSos()) {
          this.actionButton($r('app.string.cancel'), $r('app.color.card'), $r('app.string.a11y_cancel_sos'), false,
            (): void => {
              emergencyService.cancelSos();
            })
        } else {
          this.actionButton($r('app.string.im_fine'), $r('app.color.green'), $r('app.string.a11y_im_fine'), false,
            (): void => {
              emergencyService.safe();
            })
          this.actionButton($r('app.string.help_now'), $r('app.color.red'), $r('app.string.a11y_help_now'), true,
            (): void => {
              emergencyService.helpNow();
            })
        }
      }
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    // Halo en la raíz: ocupa todo el círculo (clip circular) y pulsa cada 2 s.
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .radialGradient({
          center: ['50%', '50%'],
          radius: '50%',
          colors: [[$r('app.color.halo_clear'), 0.0], [$r('app.color.halo_clear'), 0.55], [$r('app.color.halo_red'), 1.0]]
        })
        .opacity(this.haloLow ? DesignTokens.haloOpacityLow : 1)
        .animation({
          duration: DesignTokens.haloPulseMs,
          curve: Curve.EaseInOut,
          iterations: -1,
          playMode: PlayMode.Alternate
        })
        .onAppear((): void => {
          this.haloLow = true;
        })

      ScreenScaffold({
        logTag: 'CountdownAlertScreen',
        scaffoldBackground: $r('app.color.transparent'),
        bodyContent: (): void => {
          this.countdownBody();
        }
      })
    }
    .width('100%')
    .height('100%')
    .borderRadius(dimens.watchSize() / 2)
    .clip(true)
  }
}
