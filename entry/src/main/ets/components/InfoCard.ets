import { DesignTokens } from '../util/DesignTokens';
import { dimens } from '../util/Dimens';

@ComponentV2
export struct InfoCard {
  @Param label: Resource = $r('app.string.sensitivity');
  @Param value: Resource = $r('app.string.sensitivity_medium');

  build() {
    Row() {
      Text(this.label)
        .fontSize(dimens.u(DesignTokens.fsLabel))
        .fontColor($r('app.color.text_primary'))
      Text(this.value)
        .fontSize(dimens.u(DesignTokens.fsLabel))
        .fontColor($r('app.color.muted'))
    }
    .width('100%')
    .constraintSize({ minHeight: dimens.cqw(DesignTokens.infoCardMinHeightCqw) })
    .padding({ left: dimens.cqw(DesignTokens.infoCardPaddingCqw), right: dimens.cqw(DesignTokens.infoCardPaddingCqw) })
    .border({ width: dimens.thinBorder(), color: $r('app.color.border') })
    .borderRadius(dimens.radiusInfoCard())
    .backgroundColor($r('app.color.card'))
    .justifyContent(FlexAlign.SpaceBetween)
  }
}
