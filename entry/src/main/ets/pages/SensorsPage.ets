import { ExtraPageHeader } from '../components/ExtraPageHeader';
import { ScreenScaffold } from '../components/ScreenScaffold';
import { SensorCard } from '../components/SensorCard';
import { appStore } from '../state/AppStore';
import { sensorService } from '../service/SensorService';
import { PulseState } from '../model/PulseState';
import { SensorCapabilities, SensorStatus } from '../model/SensorAvailability';
import { DesignTokens } from '../util/DesignTokens';
import { dimens } from '../util/Dimens';

const SPO2_NORMAL: number = 95;
const SPO2_LOW: number = 90;
const TEMP_HIGH: number = 37.5;
const TEMP_FEVER: number = 38.0;

/**
 * Sensores (solo lectura). Mismo store que el Monitor: el panel demo mueve todas las tarjetas.
 * Scroll copiado de Ajustes (SELF_FIRST, sin rebote). Presupuesto: cuerpo 296 base; 5 tarjetas de
 * 88 + separador -> ~520 base, por eso el cuerpo hace scroll.
 * Las tarjetas se dibujan con @Builder SIN parámetros (leen el store dentro: se refrescan).
 */
@ComponentV2
export struct SensorsPage {
  @Builder
  sensorsHeader() {
    ExtraPageHeader({
      title: $r('app.string.page_sensors'),
      symbol: $r('sys.symbol.waveform')
    })
  }

  private caps(): SensorStatus[] {
    const c: SensorCapabilities = appStore.capabilities;
    return [c.heartRate, c.spo2, c.temperature, c.movement, c.location];
  }

  private isAvailable(status: SensorStatus): boolean {
    return status !== SensorStatus.Unavailable;
  }

  private anyUnavailable(): boolean {
    return this.caps().some((status: SensorStatus): boolean => !this.isAvailable(status));
  }

  private pulseStatus(): Resource {
    if (appStore.pulseState === PulseState.Critical) {
      return $r('app.string.pulse_critical');
    }
    if (appStore.pulseState === PulseState.Elevated) {
      return $r('app.string.pulse_elevated');
    }
    return $r('app.string.pulse_normal');
  }

  private spo2Color(): Resource {
    if (appStore.spo2 >= SPO2_NORMAL) {
      return $r('app.color.text_primary');
    }
    return appStore.spo2 >= SPO2_LOW ? $r('app.color.orange') : $r('app.color.red');
  }

  private spo2Status(): Resource {
    if (appStore.spo2 >= SPO2_NORMAL) {
      return $r('app.string.sensor_normal');
    }
    return appStore.spo2 >= SPO2_LOW ? $r('app.string.sensor_low') : $r('app.string.sensor_very_low');
  }

  private spo2StatusColor(): Resource {
    return appStore.spo2 >= SPO2_NORMAL ? $r('app.color.green') : this.spo2Color();
  }

  private tempColor(): Resource {
    if (appStore.temperature < TEMP_HIGH) {
      return $r('app.color.text_primary');
    }
    return appStore.temperature <= TEMP_FEVER ? $r('app.color.orange') : $r('app.color.red');
  }

  private tempStatus(): Resource {
    if (appStore.temperature < TEMP_HIGH) {
      return $r('app.string.sensor_stable');
    }
    return appStore.temperature <= TEMP_FEVER ? $r('app.string.sensor_high') : $r('app.string.sensor_fever');
  }

  private tempStatusColor(): Resource {
    return appStore.temperature < TEMP_HIGH ? $r('app.color.green') : this.tempColor();
  }

  private movementColor(): Resource {
    return appStore.movementImmobile && appStore.pulseState === PulseState.Critical ?
      $r('app.color.red') : $r('app.color.text_primary');
  }

  @Builder
  heartCard() {
    SensorCard({
      symbol: $r('sys.symbol.heart_fill'),
      name: $r('app.string.sensor_heart_rate'),
      value: $r('app.string.frequency_value', appStore.bpm),
      status: this.pulseStatus(),
      valueColor: $r('app.color.text_primary'),
      statusColor: appStore.stateColor,
      variant: appStore.capabilities.heartRate,
      simulated: sensorService.isSimulated()
    })
  }

  @Builder
  spo2Card() {
    SensorCard({
      symbol: $r('sys.symbol.drop_fill'),
      name: $r('app.string.sensor_oxygen'),
      value: `${appStore.spo2}`,
      unit: $r('app.string.unit_percent'),
      status: this.spo2Status(),
      valueColor: this.spo2Color(),
      statusColor: this.spo2StatusColor(),
      variant: appStore.capabilities.spo2,
      simulated: true
    })
  }

  @Builder
  temperatureCard() {
    SensorCard({
      symbol: $r('sys.symbol.thermometer'),
      name: $r('app.string.sensor_temperature'),
      value: appStore.temperature.toFixed(1),
      unit: $r('app.string.unit_celsius'),
      status: this.tempStatus(),
      valueColor: this.tempColor(),
      statusColor: this.tempStatusColor(),
      variant: appStore.capabilities.temperature,
      simulated: true
    })
  }

  @Builder
  movementCard() {
    SensorCard({
      symbol: $r('sys.symbol.figure_walk'),
      name: $r('app.string.sensor_movement'),
      value: appStore.movementLabel,
      status: this.pulseStatus(),
      valueColor: this.movementColor(),
      statusColor: appStore.stateColor,
      variant: appStore.capabilities.movement,
      simulated: sensorService.isSimulated()
    })
  }

  @Builder
  locationCard() {
    SensorCard({
      symbol: $r('sys.symbol.location_north_up_right'),
      name: $r('app.string.sensor_location'),
      value: $r('app.string.sensor_location_share'),
      status: $r('app.string.sensor_ready'),
      valueColor: $r('app.color.text_primary'),
      statusColor: $r('app.color.green'),
      variant: appStore.capabilities.location,
      simulated: false
    })
  }

  @Builder
  sensorsBody() {
    Scroll() {
      Column({ space: dimens.u(DesignTokens.sensorCardGapBase) }) {
        // Disponibles (activas o con permiso pendiente) primero.
        if (this.isAvailable(appStore.capabilities.heartRate)) {
          this.heartCard()
        }
        if (this.isAvailable(appStore.capabilities.spo2)) {
          this.spo2Card()
        }
        if (this.isAvailable(appStore.capabilities.temperature)) {
          this.temperatureCard()
        }
        if (this.isAvailable(appStore.capabilities.movement)) {
          this.movementCard()
        }
        if (this.isAvailable(appStore.capabilities.location)) {
          this.locationCard()
        }

        if (this.anyUnavailable()) {
          Text($r('app.string.sensor_not_available_watch'))
            .fontSize(dimens.u(DesignTokens.fsMin))
            .fontColor($r('app.color.muted'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: dimens.u(DesignTokens.sensorCardGapBase) })
          if (!this.isAvailable(appStore.capabilities.heartRate)) {
            this.heartCard()
          }
          if (!this.isAvailable(appStore.capabilities.spo2)) {
            this.spo2Card()
          }
          if (!this.isAvailable(appStore.capabilities.temperature)) {
            this.temperatureCard()
          }
          if (!this.isAvailable(appStore.capabilities.movement)) {
            this.movementCard()
          }
          if (!this.isAvailable(appStore.capabilities.location)) {
            this.locationCard()
          }
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .padding({ top: dimens.cqw(2.4), bottom: dimens.cqw(6) })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.None)
    .nestedScroll({
      scrollForward: NestedScrollMode.SELF_FIRST,
      scrollBackward: NestedScrollMode.SELF_FIRST
    })
  }

  build() {
    ScreenScaffold({
      headerHeightBase: DesignTokens.scaffoldHeaderBase,
      logTag: 'SensorsPage',
      headerContent: (): void => {
        this.sensorsHeader();
      },
      bodyContent: (): void => {
        this.sensorsBody();
      }
    })
  }
}
