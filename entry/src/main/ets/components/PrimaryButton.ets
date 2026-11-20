import { DesignTokens } from '../util/DesignTokens';
import { dimens } from '../util/Dimens';

@ComponentV2
export struct PrimaryButton {
  @Param label: Resource = $r('app.string.add');
  @Param isEnabled: boolean = true;
  @Event onPress: () => void = () => {};

  build() {
    Button() {
      Text(this.label)
        .fontSize(dimens.u(DesignTokens.fsBody))
        .fontColor($r('app.color.text_primary'))
        .fontWeight(FontWeight.Bold)
    }
    .width('70%')
    .height(dimens.primaryButtonHeight())
    .borderRadius(dimens.primaryButtonHeight() / 2)
    .backgroundColor(this.isEnabled ? $r('app.color.accion_principal') : $r('app.color.disabled_background'))
    .enabled(this.isEnabled)
    .onClick(() => {
      this.onPress();
    })
  }
}
