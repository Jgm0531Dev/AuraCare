import { DesignTokens } from '../util/DesignTokens';
import { dimens } from '../util/Dimens';

/**
 * Botón del panel demo como componente: un @Builder con varios parámetros los recibe por
 * valor y no se refresca (el resaltado de x1/x5/x10 no cambiaba). Con @Param sí se re-evalúa.
 */
@ComponentV2
export struct DemoChoiceButton {
  @Param label: Resource = $r('app.string.demo_badge');
  @Param color: Resource = $r('app.color.card');
  /** Ancho completo y texto en negrita (etiquetas largas). */
  @Param wide: boolean = false;
  @Event onPress: () => void = () => {};

  build() {
    Button() {
      Text(this.label)
        .fontSize(dimens.u(this.wide ? DesignTokens.fsBody : DesignTokens.fsLabel))
        .fontColor($r('app.color.text_primary'))
        .fontWeight(this.wide ? FontWeight.Bold : FontWeight.Normal)
        .maxLines(2)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .height(dimens.touchMin())
    .borderRadius(dimens.cqw(DesignTokens.demoButtonRadiusCqw))
    .backgroundColor(this.color)
    .padding({ left: dimens.u(DesignTokens.chipGapBase), right: dimens.u(DesignTokens.chipGapBase), top: 0, bottom: 0 })
    .onClick((): void => {
      this.onPress();
    })
  }
}
