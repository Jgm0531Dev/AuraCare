import { DesignTokens } from '../util/DesignTokens';
import { dimens } from '../util/Dimens';

@ComponentV2
export struct SensorChip {
  @Param title: Resource = $r('app.string.spo2');
  @Param value: Resource = $r('app.string.spo2_98');
  @Param color: Resource = $r('app.color.green');
  @Event onPress: () => void = () => {};

  build() {
    Column() {
      Text(this.title)
        .fontSize(dimens.u(DesignTokens.fsLabel))
        .fontColor($r('app.color.muted'))
      Text(this.value)
        .fontSize(dimens.u(DesignTokens.sensorValue))
        .fontColor(this.color)
        .margin({ top: dimens.cqw(DesignTokens.chipValueGapCqw) })
    }
    .width('50%')
    .height(dimens.cqw(DesignTokens.chipHeightCqw))
    .padding({ left: dimens.cqw(DesignTokens.chipPaddingCqw), right: dimens.cqw(DesignTokens.chipPaddingCqw) })
    .borderRadius(dimens.radiusChip())
    .backgroundColor($r('app.color.card'))
    .onClick(() => {
      this.onPress();
    })
  }
}
