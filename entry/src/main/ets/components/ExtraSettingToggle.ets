import { DesignTokens } from '../util/DesignTokens';
import { dimens } from '../util/Dimens';
import { Logger } from '../util/Logger';

const TAG: string = 'ExtraSettingToggle';

@ComponentV2
export struct ExtraSettingToggle {
  @Param title: Resource = $r('app.string.exercise_mode');
  @Param subtitle: Resource = $r('app.string.battery_desc');
  @Param isOn: boolean = false;
  @Param switchEnabled: boolean = true;
  @Param hint: Resource = $r('app.string.page_settings');
  @Param name: string = 'toggle';
  @Event onValueChange: (value: boolean) => void = (value: boolean): void => {};

  build() {
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

      Toggle({ type: ToggleType.Switch, isOn: this.isOn })
        .selectedColor($r('app.color.green'))
        .enabled(this.switchEnabled)
        .opacity(this.switchEnabled ? 1 : 0.4)
        .accessibilityText(this.hint)
        .onChange((value: boolean): void => {
          Logger.info(TAG, `onChange ${this.name}=${value}`);
          try {
            this.onValueChange(value);
          } catch (err) {
            Logger.error(TAG, `onChange ${this.name} falló`, err as Object);
          }
        })
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
    .alignItems(VerticalAlign.Center)
    .justifyContent(FlexAlign.SpaceBetween)
  }
}
