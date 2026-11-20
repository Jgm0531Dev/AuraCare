import { DesignTokens } from '../util/DesignTokens';
import { dimens } from '../util/Dimens';

@ComponentV2
export struct PageHeader {
  @Param title: Resource = $r('app.string.page_monitor');

  build() {
    Row({ space: dimens.headerGap() }) {
      Text($r('app.string.icon_heart'))
        .fontSize(dimens.u(DesignTokens.fsBody))
        .fontColor($r('app.color.accion_principal'))
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
