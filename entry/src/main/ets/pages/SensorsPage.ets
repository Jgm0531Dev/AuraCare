import { crownNav } from '../util/CrownNav';
import { ExtraPageHeader } from '../components/ExtraPageHeader';
import { ScreenScaffold } from '../components/ScreenScaffold';
import { SensorCard } from '../components/SensorCard';
import { appStore } from '../state/AppStore';
import { sensorService } from '../service/SensorService';
import { PulseState } from '../model/PulseState';
import { AlertState } from '../model/Alert';
import { AlertReason } from '../model/AlertReason';
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
  /** Página 1 del ArcSwiper: al salir de ella, su contenido vuelve arriba (sin animación). */
  private readonly scroller: Scroller = new Scroller();
  private unsubscribePage: () => void = (): void => {};
  private unregisterScroller: () => void = (): void => {};

  aboutToDisappear(): void {
    this.unsubscribePage();
    this.unregisterScroller();
  }

  aboutToAppear(): void {
    // La corona (recibida por Index) desplaza esta lista cuando la página 1 está visible.
    this.unregisterScroller = crownNav.registerScroller(1, this.scroller);
    this.unsubscribePage = crownNav.onPageChanged((index: number): void => {
      if (index !== 1) {
        try {
          this.scroller.scrollTo({ xOffset: 0, yOffset: 0, animation: false });
        } catch (err) {
          // Sin lista montada (p. ej., Contactos vacío): no hay nada que desplazar.
        }
      }
    });
  }

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
    if (!appStore.heartRateValid) {
      return $r('app.string.pulse_no_reading');
    }
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

  /** Alerta en curso disparada por una caída (impacto + inmovilidad, según AnomalyEngine). */
  private fallAlertActive(): boolean {
    return appStore.emergency.state !== AlertState.None && appStore.emergency.reason === AlertReason.Caida;
  }

  private movementColor(): Resource {
    return this.fallAlertActive() ? $r('app.color.red') : $r('app.color.text_primary');
  }

  /** Estado propio del movimiento (antes repetía el del ritmo cardiaco). */
  private movementStatus(): Resource {
    if (appStore.notWorn) {
      return $r('app.string.movement_not_worn');
    }
    if (this.fallAlertActive()) {
      return $r('app.string.movement_alert');
    }
    if (!appStore.motionValid) {
      return $r('app.string.pulse_no_reading');
    }
    return $r('app.string.movement_normal');
  }

  private movementStatusColor(): Resource {
    if (appStore.notWorn || (!this.fallAlertActive() && !appStore.motionValid)) {
      return $r('app.color.muted');
    }
    return this.fallAlertActive() ? $r('app.color.red') : $r('app.color.green');
  }

  @Builder
  heartCard() {
    SensorCard({
      symbol: $r('sys.symbol.heart_fill'),
      name: $r('app.string.sensor_heart_rate'),
      value: appStore.heartRateValid ? $r('app.string.frequency_value', appStore.bpm) : $r('app.string.value_dash'),
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
      simulated: sensorService.isSimulated()
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
      simulated: sensorService.isSimulated()
    })
  }

  @Builder
  movementCard() {
    SensorCard({
      symbol: $r('sys.symbol.figure_walk'),
      name: $r('app.string.sensor_movement'),
      value: appStore.movementLabel,
      status: this.movementStatus(),
      valueColor: this.movementColor(),
      statusColor: this.movementStatusColor(),
      variant: appStore.capabilities.movement,
      simulated: sensorService.isSimulated()
    })
  }

  @Builder
  locationCard() {
    SensorCard({
      symbol: $r('sys.symbol.location_north_up_right'),
      name: $r('app.string.sensor_location'),
      // Título "Ubicación" (fila 1); estado corto en la fila 2, sin cortes.
      value: appStore.settings.locationEnabled ? $r('app.string.location_card_on') : $r('app.string.location_card_off'),
      status: $r('app.string.location_value_optional'),
      valueColor: $r('app.color.text_primary'),
      statusColor: $r('app.color.green'),
      variant: appStore.capabilities.location,
      simulated: false
    })
  }

  @Builder
  sensorsBody() {
    Scroll(this.scroller) {
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
      .padding({ top: dimens.cqw(2.4), bottom: dimens.u(DesignTokens.scrollEndPaddingBase) })
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
