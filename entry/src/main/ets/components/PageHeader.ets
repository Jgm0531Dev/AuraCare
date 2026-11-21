import { DesignTokens } from '../util/DesignTokens';
import { dimens } from '../util/Dimens';

@ComponentV2
export struct PageHeader {
  @Param title: Resource = $r('app.string.page_monitor');
  @Param icon: Resource = $r('app.string.icon_heart');
  @Param onLongPress: (() => void) | undefined = undefined;

  build() {
    Row({ space: dimens.headerGap() }) {
      Text(this.icon)
        .fontSize(dimens.u(DesignTokens.fsBody))
        .fontColor($r('app.color.accion_principal'))
      Text(this.title)
        .fontSize(dimens.u(DesignTokens.fsSubtitle))
        .fontColor($r('app.color.text_primary'))
        .fontWeight(FontWeight.Medium)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .gesture(LongPressGesture({ duration: 3000 }).onAction((_event: GestureEvent) => {
          const handler: (() => void) | undefined = this.onLongPress;
          if (handler !== undefined) {
            handler();
          }
        }))
    }
    .width(dimens.headerWidth())
    .constraintSize({ minHeight: dimens.headerMinHeight() })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
  }
}
