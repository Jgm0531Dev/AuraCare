import { DesignTokens } from '../util/DesignTokens';
import { dimens } from '../util/Dimens';
import { Logger } from '../util/Logger';

const TAG: string = 'ExtraSettingButton';

@ComponentV2
export struct ExtraSettingButton {
  @Param title: Resource = $r('app.string.sensitivity');
  @Param subtitle: Resource = $r('app.string.threshold');
  @Param value: Resource = $r('app.string.sensitivity_medium');
  @Param accent: boolean = false;
  @Param name: string = 'row';
  @Event onPress: () => void = () => {};

  build() {
    Button() {
      Row() {
        Column({ space: 0 }) {
          Text(this.title)
            .fontSize(dimens.u(DesignTokens.fsLabel))
            .fontColor($r('app.color.text_primary'))
            .fontWeight(FontWeight.Medium)
            .maxLines(2)
          Text(this.subtitle)
            .fontSize(dimens.u(DesignTokens.fsMin))
            .fontColor($r('app.color.muted'))
            .maxLines(2)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Center)

        Text(this.value)
          .fontSize(dimens.u(DesignTokens.fsMin))
          .fontColor(this.accent ? $r('app.color.green') : $r('app.color.text_primary'))
          .fontWeight(FontWeight.Bold)
          .constraintSize({ minHeight: dimens.u(DesignTokens.demoBadgeHeightBase) })
          .padding({
            left: dimens.u(DesignTokens.demoBadgePaddingBase),
            right: dimens.u(DesignTokens.demoBadgePaddingBase)
          })
          .borderRadius(dimens.radiusChip())
          .backgroundColor($r('app.color.card'))
          .border({ width: dimens.thinBorder(), color: $r('app.color.border') })
          .maxLines(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width('100%')
    .constraintSize({ minHeight: dimens.cqw(DesignTokens.infoCardMinHeightCqw) })
    .padding({
      top: dimens.cqw(2.4), bottom: dimens.cqw(2.4),
      left: dimens.cqw(3.6), right: dimens.cqw(3.6)
    })
    .backgroundColor($r('app.color.card'))
    .border({ width: dimens.thinBorder(), color: $r('app.color.border') })
    .borderRadius(dimens.radiusCard())
    .onClick((): void => {
      Logger.info(TAG, `onClick ${this.name}`);
      try {
        this.onPress();
      } catch (err) {
        Logger.error(TAG, `onClick ${this.name} falló`, err as Object);
      }
    })
  }
}
