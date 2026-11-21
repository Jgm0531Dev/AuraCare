import { DesignTokens } from '../util/DesignTokens';
import { dimens } from '../util/Dimens';

/** Anillo de cuenta atrás: el arco se vacía y pasa a rojo en el tramo crítico. */
@ComponentV2
export struct CountdownRing {
  @Param value: number = 30;
  @Param total: number = 30;
  @Param emptyClockwise: boolean = true;
  @Param critical: boolean = false;

  private gaugeValue(): number {
    if (this.emptyClockwise) {
      return this.value;
    }
    return Math.max(0, this.total - this.value);
  }

  private arcColor(): Resource {
    return this.critical ? $r('app.color.red') : $r('app.color.text_primary');
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Gauge({ value: this.gaugeValue(), min: 0, max: this.total })
        .width(dimens.cqw(DesignTokens.ringSizeCqw))
        .height(dimens.cqw(DesignTokens.ringSizeCqw))
        .startAngle(0)
        .endAngle(360)
        .colors([[this.arcColor(), 1]])
        .strokeWidth(dimens.vp(DesignTokens.ringStrokeWidth))
        .backgroundColor($r('app.color.card'))

      Text(`${this.value}`)
        .fontSize(dimens.u(DesignTokens.countdownNumber))
        .fontColor(this.arcColor())
        .fontWeight(FontWeight.Bold)
    }
    .width(dimens.cqw(DesignTokens.ringSizeCqw))
    .height(dimens.cqw(DesignTokens.ringSizeCqw))
  }
}
