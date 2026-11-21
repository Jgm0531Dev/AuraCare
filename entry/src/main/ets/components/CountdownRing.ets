import { DesignTokens } from '../util/DesignTokens';
import { dimens } from '../util/Dimens';

/**
 * Anillo de cuenta atrás con Progress en modo anillo (declarativo: se redibuja con cada
 * cambio de `value`; el Canvas anterior dependía de @Monitor y solo se veía al cambiar el color).
 * progreso = restante / total, ambos de la máquina (Clock inyectado, respeta x5/x10).
 * Espejo horizontal: el arco se vacía en sentido horario desde las 12. El número va aparte.
 */
@ComponentV2
export struct CountdownRing {
  @Param value: number = 30;
  @Param total: number = 30;
  /** Solo color: rojo en los últimos 10 s de ¿Estás bien? y en Pidiendo ayuda. */
  @Param critical: boolean = false;

  private ringSize(): number {
    return dimens.u(DesignTokens.countdownRingBase);
  }

  private arcColor(): Resource {
    return this.critical ? $r('app.color.red') : $r('app.color.text_primary');
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Progress({
        value: Math.max(0, Math.min(this.value, this.total)),
        total: this.total > 0 ? this.total : 1,
        type: ProgressType.Ring
      })
        .width(this.ringSize())
        .height(this.ringSize())
        .color(this.arcColor())
        .backgroundColor($r('app.color.ring_track'))
        .style({
          strokeWidth: dimens.u(DesignTokens.countdownRingStrokeBase),
          shadow: false,
          enableScanEffect: false
        })
        .scale({ x: -1, y: 1 })

      Text(`${this.value}`)
        .fontSize(dimens.u(DesignTokens.countdownNumberBase))
        .fontColor(this.arcColor())
        .fontWeight(FontWeight.Bold)
        .maxLines(1)
    }
    .width(this.ringSize())
    .height(this.ringSize())
  }
}
