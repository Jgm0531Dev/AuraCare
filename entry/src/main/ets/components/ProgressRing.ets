import { DesignTokens } from '../util/DesignTokens';
import { dimens } from '../util/Dimens';

@ComponentV2
export struct ProgressRing {
  @Param value: number = 75;
  @Param total: number = 100;
  @Param color: Resource = $r('app.color.green');

  build() {
    Progress({ value: this.value, total: this.total, type: ProgressType.Ring })
      .width(dimens.cqw(DesignTokens.ringSizeCqw))
      .height(dimens.cqw(DesignTokens.ringSizeCqw))
      .color(this.color)
      .backgroundColor($r('app.color.card'))
      .style({ strokeWidth: dimens.u(DesignTokens.ringStrokeWidth) })
  }
}
