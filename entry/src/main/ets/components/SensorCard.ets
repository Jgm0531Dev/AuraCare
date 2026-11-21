import { SensorStatus } from '../model/SensorAvailability';
import { DesignTokens } from '../util/DesignTokens';
import { dimens } from '../util/Dimens';

/**
 * Tarjeta de solo lectura (sin toques) de la pantalla Sensores. Dos líneas de alto fijo:
 * 1) ícono + nombre (+ chip "Simulado"); 2) valor a la izquierda y estado a la derecha.
 * Componente con @Param (no @Builder con parámetros) para que se refresque con el store.
 */
@ComponentV2
export struct SensorCard {
  @Param symbol: Resource = $r('sys.symbol.waveform');
  @Param name: Resource = $r('app.string.sensor_heart_rate');
  @Param value: ResourceStr = '';
  @Param unit: ResourceStr = '';
  @Param status: Resource = $r('app.string.sensor_normal');
  @Param valueColor: Resource = $r('app.color.text_primary');
  @Param statusColor: Resource = $r('app.color.green');
  @Param variant: SensorStatus = SensorStatus.Available;
  @Param simulated: boolean = false;

  private isUnavailable(): boolean {
    return this.variant === SensorStatus.Unavailable;
  }

  private isPermission(): boolean {
    return this.variant === SensorStatus.PermissionRequired;
  }

  private shownStatus(): Resource {
    if (this.isUnavailable()) {
      return $r('app.string.sensor_unavailable');
    }
    return this.isPermission() ? $r('app.string.sensor_activate') : this.status;
  }

  private shownStatusColor(): Resource {
    if (this.isUnavailable()) {
      return $r('app.color.muted');
    }
    return this.isPermission() ? $r('app.color.orange') : this.statusColor;
  }

  private shownValueColor(): Resource {
    if (this.isUnavailable()) {
      return $r('app.color.muted');
    }
    return this.isPermission() ? $r('app.color.orange') : this.valueColor;
  }

  build() {
    Column({ space: dimens.u(DesignTokens.chipGapBase) }) {
      Row({ space: dimens.u(DesignTokens.sensorCardGapBase) }) {
        SymbolGlyph(this.isUnavailable() ? $r('sys.symbol.lock') : this.symbol)
          .fontSize(dimens.u(DesignTokens.sensorIconBase))
          .fontColor([this.isUnavailable() ? $r('app.color.muted') : $r('app.color.accion_principal')])
          .flexShrink(0)
        Text(this.name)
          .fontSize(dimens.u(DesignTokens.fsLabel))
          .fontColor($r('app.color.text_primary'))
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        if (this.simulated && !this.isUnavailable()) {
          Text($r('app.string.sensor_simulated'))
            .fontSize(dimens.u(DesignTokens.sensorChipFontBase))
            .fontColor($r('app.color.muted'))
            .maxLines(1)
            .padding({
              left: dimens.u(DesignTokens.sensorChipPaddingBase),
              right: dimens.u(DesignTokens.sensorChipPaddingBase)
            })
            .borderRadius(dimens.radiusChip())
            .border({ width: dimens.thinBorder(), color: $r('app.color.gray_636366') })
            .flexShrink(0)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: dimens.u(DesignTokens.sensorCardGapBase) }) {
        Row() {
          if (this.isUnavailable() || this.isPermission()) {
            Text($r('app.string.dash'))
              .fontSize(dimens.u(DesignTokens.fsBody))
              .fontColor(this.shownValueColor())
              .fontWeight(FontWeight.Bold)
              .maxLines(1)
          } else {
            Text(this.value)
              .fontSize(dimens.u(DesignTokens.fsBody))
              .fontColor(this.shownValueColor())
              .fontWeight(FontWeight.Bold)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .flexShrink(1)
            Text(this.unit)
              .fontSize(dimens.u(DesignTokens.fsBody))
              .fontColor(this.shownValueColor())
              .fontWeight(FontWeight.Bold)
              .maxLines(1)
              .flexShrink(0)
          }
        }
        .layoutWeight(1)

        Text(this.shownStatus())
          .fontSize(dimens.u(DesignTokens.fsMin))
          .fontColor(this.shownStatusColor())
          .maxLines(1)
          .flexShrink(0)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(dimens.u(DesignTokens.sensorCardHeightBase))
    .justifyContent(FlexAlign.Center)
    .padding({
      left: dimens.u(DesignTokens.sensorCardPaddingBase),
      right: dimens.u(DesignTokens.sensorCardPaddingBase)
    })
    .backgroundColor($r('app.color.card'))
    .borderRadius(dimens.radiusCard())
    .border({
      width: this.isPermission() ? dimens.thinBorder() * 1.5 : 0,
      color: $r('app.color.orange')
    })
    .opacity(this.isUnavailable() ? DesignTokens.sensorUnavailableOpacity : 1)
    .hitTestBehavior(HitTestMode.Transparent)
  }
}
