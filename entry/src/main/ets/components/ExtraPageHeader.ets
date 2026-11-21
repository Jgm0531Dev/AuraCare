import { DesignTokens } from '../util/DesignTokens';
import { dimens } from '../util/Dimens';

@ComponentV2
export struct ExtraPageHeader {
  @Param title: Resource = $r('app.string.page_range');
  @Param symbol: Resource = $r('sys.symbol.waveform_path_ecg_heart');

  build() {
    Row({ space: dimens.headerGap() }) {
      SymbolGlyph(this.symbol)
        .fontSize(dimens.u(DesignTokens.headerIconSize))
        .fontWeight(FontWeight.Medium)
        .renderingStrategy(SymbolRenderingStrategy.SINGLE)
        .fontColor([$r('app.color.accion_principal')])
      Text(this.title)
        .fontSize(dimens.u(DesignTokens.fsSubtitle))
        .fontColor($r('app.color.text_primary'))
        .fontWeight(FontWeight.Medium)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width(dimens.headerWidth())
    .constraintSize({ minHeight: dimens.headerMinHeight() })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
  }
}
