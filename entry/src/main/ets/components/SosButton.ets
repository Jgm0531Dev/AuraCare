import { DesignTokens } from '../util/DesignTokens';
import { dimens } from '../util/Dimens';

const HOLD_TICK_MS: number = 20;
const HOLD_STEPS: number = 100;

@ComponentV2
export struct SosButton {
  @Event onHoldStart: () => void = () => {};
  @Event onHoldCancel: () => void = () => {};
  @Local holding: boolean = false;
  @Local progress: number = 0;
  private holdTimer: number | undefined = undefined;

  aboutToDisappear(): void {
    this.stopTimer();
  }

  private startHold(): void {
    this.stopTimer();
    this.holding = true;
    this.progress = 0;
    this.onHoldStart();
    this.holdTimer = setInterval((): void => {
      this.progress = Math.min(HOLD_STEPS, this.progress + 1);
      if (this.progress >= HOLD_STEPS) {
        this.stopTimer();
      }
    }, HOLD_TICK_MS);
  }

  private stopHold(): void {
    this.stopTimer();
    this.holding = false;
    this.progress = 0;
    this.onHoldCancel();
  }

  private stopTimer(): void {
    if (this.holdTimer !== undefined) {
      clearInterval(this.holdTimer);
      this.holdTimer = undefined;
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.progress > 0) {
        Gauge({ value: this.progress, min: 0, max: HOLD_STEPS })
          .width(dimens.u(DesignTokens.sosRingSizeBase))
          .height(dimens.u(DesignTokens.sosRingSizeBase))
          .startAngle(0)
          .endAngle(360)
          .colors([[$r('app.color.text_primary'), 1]])
          .strokeWidth(dimens.vp(DesignTokens.sosRingStroke))
          .backgroundColor($r('app.color.card'))
      }

      Row({ space: dimens.u(DesignTokens.chipGapBase) }) {
        Text($r('app.string.sos'))
          .fontSize(dimens.u(DesignTokens.sosLabelBase))
          .fontColor($r('app.color.text_primary'))
          .fontWeight(FontWeight.Bold)
          .maxLines(1)
        Text($r('app.string.two_seconds'))
          .fontSize(dimens.u(DesignTokens.fsMin))
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
      }
      .width(dimens.u(DesignTokens.sosButtonWidthBase))
      .height(dimens.u(DesignTokens.monitorActionsBase))
      .borderRadius(dimens.u(DesignTokens.monitorActionsBase / 2))
      .backgroundColor(this.holding ? $r('app.color.orange') : $r('app.color.accion_principal'))
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .width(dimens.u(DesignTokens.sosButtonWidthBase))
    .height(dimens.u(DesignTokens.monitorActionsBase))
    .accessibilityText($r('app.string.a11y_sos_hold'))
    .onTouch((event: TouchEvent): void => {
      if (event.type === TouchType.Down) {
        this.startHold();
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.stopHold();
      }
    })
  }
}
