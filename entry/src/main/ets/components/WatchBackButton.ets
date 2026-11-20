import { DesignTokens } from '../util/DesignTokens';
import { dimens } from '../util/Dimens';

@ComponentV2
export struct WatchBackButton {
  @Param label: Resource = $r('app.string.back');
  @Event onBack: () => void = () => {};

  build() {
    Button() {
      Text($r('app.string.icon_back'))
        .fontSize(dimens.u(DesignTokens.fsSubtitle))
        .fontColor($r('app.color.text_primary'))
    }
    .width(dimens.touchMin())
    .height(dimens.touchMin())
    .borderRadius(dimens.touchMin() / 2)
    .backgroundColor($r('app.color.card'))
    .position({ top: dimens.backTop(), left: dimens.backLeft() })
    .accessibilityText(this.label)
    .onClick(() => {
      this.onBack();
    })
  }
}
