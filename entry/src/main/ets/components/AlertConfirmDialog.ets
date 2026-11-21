import { DesignTokens } from '../util/DesignTokens';
import { dimens } from '../util/Dimens';

/** Confirmación de fondo limpio, reutilizada para alerta, 911 y contactos. */
@ComponentV2
export struct AlertConfirmDialog {
  @Param title: Resource = $r('app.string.confirm_well_title');
  @Param description: Resource = $r('app.string.confirm_well_desc');
  @Param confirmLabel: Resource = $r('app.string.confirm_well_yes');
  @Param cancelLabel: Resource = $r('app.string.cancel');
  @Param tone: Resource = $r('app.color.green');
  @Param icon: Resource = $r('app.string.icon_check');
  @Param hideCancel: boolean = false;
  @Param showSimulationNote: boolean = true;
  @Event onConfirm: () => void = () => {};
  @Event onCancel: () => void = () => {};

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column({ space: dimens.cqw(DesignTokens.alertContentGapCqw) }) {
        Text(this.icon)
          .fontSize(dimens.cqw(DesignTokens.alertDialogGlyphCqw))
          .fontColor(this.tone)
          .fontWeight(FontWeight.Bold)
          .width(dimens.cqw(DesignTokens.alertDialogIconCqw))
          .height(dimens.cqw(DesignTokens.alertDialogIconCqw))
          .textAlign(TextAlign.Center)

        Text(this.title)
          .fontSize(dimens.u(DesignTokens.alertDialogTitle))
          .fontColor($r('app.color.text_primary'))
          .fontWeight(FontWeight.Bold)
          .textAlign(TextAlign.Center)

        Text(this.description)
          .fontSize(dimens.u(DesignTokens.fsLabel))
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center)

        Column({ space: dimens.vp(DesignTokens.countdownButtonGap) }) {
          Button() {
            Text(this.confirmLabel)
              .fontSize(dimens.u(DesignTokens.fsLabel))
              .fontColor($r('app.color.text_primary'))
              .fontWeight(FontWeight.Bold)
          }
          .width(dimens.cqw(DesignTokens.alertCardWidthCqw))
          .height(dimens.primaryButtonHeight())
          .borderRadius(dimens.cqw(DesignTokens.demoButtonRadiusCqw))
          .backgroundColor(this.tone)
          .onClick((): void => {
            this.onConfirm();
          })

          if (!this.hideCancel) {
            Button() {
              Text(this.cancelLabel)
                .fontSize(dimens.u(DesignTokens.fsLabel))
                .fontColor($r('app.color.text_primary'))
            }
            .width(dimens.cqw(DesignTokens.alertCardWidthCqw))
            .height(dimens.primaryButtonHeight())
            .borderRadius(dimens.cqw(DesignTokens.demoButtonRadiusCqw))
            .backgroundColor($r('app.color.card'))
            .onClick((): void => {
              this.onCancel();
            })
          }
        }
        .width(dimens.cqw(DesignTokens.alertCardWidthCqw))

        if (this.showSimulationNote) {
          Text($r('app.string.simulation_note'))
            .fontSize(dimens.u(DesignTokens.fsMin))
            .fontColor($r('app.color.muted'))
            .textAlign(TextAlign.Center)
            .width(dimens.cqw(DesignTokens.alertCardWidthCqw))
        }
      }
      .width(dimens.cqw(DesignTokens.alertCardWidthCqw))
    }
    .width('100%')
    .height('100%')
    .padding({
      top: dimens.safeTop(), bottom: dimens.safeBottom(),
      left: dimens.safeLeft(), right: dimens.safeRight()
    })
    .backgroundColor($r('app.color.watch_background'))
  }
}
