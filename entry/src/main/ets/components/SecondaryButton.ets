import { DesignTokens } from '../util/DesignTokens';
import { dimens } from '../util/Dimens';

@ComponentV2
export struct SecondaryButton {
  @Param label: Resource = $r('app.string.cancel');
  @Event onPress: () => void = () => {};

  build() {
    Button() {
      Text(this.label)
        .fontSize(dimens.u(DesignTokens.fsBody))
        .fontColor($r('app.color.text_primary'))
    }
    .width('70%')
    .height(dimens.primaryButtonHeight())
    .borderRadius(dimens.primaryButtonHeight() / 2)
    .backgroundColor($r('app.color.secondary_background'))
    .border({ width: dimens.thinBorder(), color: $r('app.color.secondary_border') })
    .onClick(() => {
      this.onPress();
    })
  }
}
