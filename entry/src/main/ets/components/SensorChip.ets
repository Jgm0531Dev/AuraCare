import { DesignTokens } from '../util/DesignTokens';
import { dimens } from '../util/Dimens';

/** Chip informativo de una sola línea; no es un control táctil. */
@ComponentV2
export struct SensorChip {
  @Param text: Resource = $r('app.string.spo2_chip_98');
  @Param tone: Resource = $r('app.color.green');
  @Param glyph: Resource = $r('app.string.icon_lock');
  @Param showGlyph: boolean = false;
  @Param accessibility: Resource = $r('app.string.a11y_spo2_detail');

  build() {
    Row({ space: dimens.u(DesignTokens.chipGapBase) }) {
      if (this.showGlyph) {
        Text(this.glyph)
          .fontSize(dimens.u(DesignTokens.fsMin))
          .fontColor($r('app.color.muted'))
          .maxLines(1)
      }
      Text(this.text)
        .fontSize(dimens.u(DesignTokens.fsMin))
        .fontColor(this.tone)
        .maxLines(1)
        .layoutWeight(1)
    }
    .layoutWeight(1)
    .height(dimens.u(DesignTokens.chipHeightBase))
    .padding({ left: dimens.u(DesignTokens.chipPaddingBase), right: dimens.u(DesignTokens.chipPaddingBase) })
    .borderRadius(dimens.radiusChip())
    .backgroundColor($r('app.color.card'))
    .alignItems(VerticalAlign.Center)
    .accessibilityText(this.accessibility)
  }
}
