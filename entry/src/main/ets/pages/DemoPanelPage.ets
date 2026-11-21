import { DesignTokens } from '../util/DesignTokens';
import { dimens } from '../util/Dimens';
import { appStore, extraDemoState } from '../state/AppStore';
import { sensorService } from '../service/SensorService';
import { emergencyService } from '../service/EmergencyService';
import { AlertReason } from '../model/AlertReason';
import { PulseState } from '../model/PulseState';
import { SensorStatus } from '../model/SensorAvailability';
import { ScreenScaffold } from '../components/ScreenScaffold';
import { DEBUG_LAYOUT } from '../util/Dimens';
import { Logger } from '../util/Logger';

const TAG: string = 'DemoPanelPage';
/** Distancia mínima (base 466) del deslizamiento a la derecha que cierra el panel. */
const SWIPE_CLOSE_BASE: number = 60;
/** EXPERIMENTO: botón TEST y logs del panel sin depender de DEBUG_LAYOUT. Poner a false al cerrar el diagnóstico. */
const PANEL_PROBE: boolean = true;

@ComponentV2
export struct DemoPanelPage {
  @Param onBack: () => void = () => {};
  @Local reason: AlertReason = AlertReason.PulsoCritico;
  @Local timeScale: number = 1;
  private closing: boolean = false;

  aboutToAppear(): void {
    appStore.demoPanelVisible = true;
    this.log('aboutToAppear');
  }

  aboutToDisappear(): void {
    appStore.demoPanelVisible = false;
    this.log('aboutToDisappear');
  }

  private log(event: string): void {
    if (DEBUG_LAYOUT || PANEL_PROBE) {
      Logger.info(TAG,
        `${event}: navStackDepth=${appStore.navStackDepth} overlayOpen=${appStore.dialogOpen} alert=${appStore.emergency.state}`);
    }
  }

  /** Envoltura de cada onClick: log de entrada y excepciones que no se pierden en silencio. */
  private runClick(name: string, action: () => void): void {
    this.log(`onClick ${name}`);
    try {
      action();
    } catch (err) {
      Logger.error(TAG, `onClick ${name} falló`, err as Object);
    }
  }

  /** Único camino de salida (botón Cerrar, gesto atrás, swipe a la derecha). */
  private close(source: string): void {
    if (this.closing) {
      this.log(`close ignorado (ya cerrando) source=${source}`);
      return;
    }
    this.closing = true;
    this.log(`close source=${source}`);
    try {
      this.onBack();
    } catch (err) {
      Logger.error(TAG, `close falló source=${source}`, err as Object);
    } finally {
      // La bandera global se limpia aunque pop() falle.
      appStore.demoPanelVisible = false;
      this.closing = false;
    }
  }

  @Builder
  private choiceButton(name: string, label: Resource, color: Resource, onPress: () => void): void {
    Button() {
      Text(label)
        .fontSize(dimens.u(DesignTokens.fsLabel))
        .fontColor($r('app.color.text_primary'))
        .maxLines(2)
        .textAlign(TextAlign.Center)
    }
    .layoutWeight(1)
    .height(dimens.touchMin())
    .borderRadius(dimens.cqw(DesignTokens.demoButtonRadiusCqw))
    .backgroundColor(color)
    .padding({ left: dimens.u(DesignTokens.chipGapBase), right: dimens.u(DesignTokens.chipGapBase), top: 0, bottom: 0 })
    .onClick((): void => {
      this.runClick(name, onPress);
    })
  }

  /** Botón de ancho completo, para etiquetas largas. */
  @Builder
  private wideButton(name: string, label: Resource, color: Resource, onPress: () => void): void {
    Button() {
      Text(label)
        .fontSize(dimens.u(DesignTokens.fsBody))
        .fontColor($r('app.color.text_primary'))
        .fontWeight(FontWeight.Bold)
        .maxLines(2)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .height(dimens.touchMin())
    .borderRadius(dimens.cqw(DesignTokens.demoButtonRadiusCqw))
    .backgroundColor(color)
    .margin({ top: dimens.cqw(DesignTokens.demoGapCqw) })
    .padding({ left: dimens.u(DesignTokens.chipGapBase), right: dimens.u(DesignTokens.chipGapBase), top: 0, bottom: 0 })
    .onClick((): void => {
      this.runClick(name, onPress);
    })
  }

  private reasonColor(reason: AlertReason): Resource {
    return this.reason === reason ? $r('app.color.accion_principal') : $r('app.color.card');
  }

  @Builder
  private sectionTitle(label: Resource): void {
    Text(label)
      .fontSize(dimens.u(DesignTokens.fsBody))
      .fontColor($r('app.color.text_primary'))
      .fontWeight(FontWeight.Medium)
      .margin({ top: dimens.cqw(DesignTokens.demoSectionGapCqw) })
  }

  @Builder
  private hardwareSwitch(label: Resource, isOn: boolean, onChange: (value: boolean) => void): void {
    Row() {
      Text(label)
        .fontSize(dimens.u(DesignTokens.fsLabel))
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor($r('app.color.green'))
        .onChange((value: boolean): void => {
          this.log(`onChange switch id=${label.id} value=${value}`);
          onChange(value);
        })
    }
    .width('100%')
    .constraintSize({ minHeight: dimens.touchMin() })
    .justifyContent(FlexAlign.SpaceBetween)
  }

  @Builder
  demoBody() {
    Scroll() {
      Column() {
        // Dentro del flujo (no position): siempre visible arriba y de 72 base.
        Button() {
          Text($r('app.string.close'))
            .fontSize(dimens.u(DesignTokens.fsBody))
            .fontColor($r('app.color.text_primary'))
            .fontWeight(FontWeight.Bold)
        }
        .width(dimens.percent(DesignTokens.primaryButtonWidthPercent))
        .height(dimens.touchMin())
        .borderRadius(dimens.touchMin() / 2)
        .backgroundColor($r('app.color.card'))
        .border({ width: dimens.thinBorder(), color: $r('app.color.border') })
        .accessibilityText($r('app.string.close'))
        .onClick((): void => {
          this.runClick('close', (): void => {
            this.close('button');
          });
        })

        Text($r('app.string.demo_panel_title'))
          .fontSize(dimens.u(DesignTokens.fsSubtitle))
          .fontColor($r('app.color.text_primary'))
          .fontWeight(FontWeight.Bold)
        Text($r('app.string.demo_control_title'))
          .fontSize(dimens.u(DesignTokens.fsLabel))
          .fontColor($r('app.color.muted'))

        this.sectionTitle($r('app.string.demo_time_speed_title', this.timeScale))
        Row({ space: dimens.cqw(DesignTokens.demoGapCqw) }) {
          this.choiceButton('speed1', $r('app.string.demo_speed_1'), this.speedColor(1), (): void => {
            this.selectSpeed(1);
          })
          this.choiceButton('speed5', $r('app.string.demo_speed_5'), this.speedColor(5), (): void => {
            this.selectSpeed(5);
          })
          this.choiceButton('speed10', $r('app.string.demo_speed_10'), this.speedColor(10), (): void => {
            this.selectSpeed(10);
          })
        }
        .width('100%')

        this.sectionTitle($r('app.string.demo_pulse_selector'))
        Row({ space: dimens.cqw(DesignTokens.demoGapCqw) }) {
          this.choiceButton('pulseNormal', $r('app.string.demo_state_normal'), $r('app.color.green'), (): void => {
            this.selectPulse(PulseState.Normal);
          })
          this.choiceButton('pulseElevated', $r('app.string.demo_state_elevated'), $r('app.color.orange'), (): void => {
            this.selectPulse(PulseState.Elevated);
          })
          this.choiceButton('pulseCritical', $r('app.string.demo_state_critical'), $r('app.color.red'), (): void => {
            this.selectPulse(PulseState.Critical);
          })
        }
        .width('100%')

        this.sectionTitle($r('app.string.demo_hardware_title'))
        this.hardwareSwitch($r('app.string.demo_spo2_switch'),
          appStore.capabilities.spo2 === SensorStatus.Available, (value: boolean): void => {
            sensorService.toggleCapability('spo2', value, appStore);
          })
        this.hardwareSwitch($r('app.string.demo_temperature_switch'),
          appStore.capabilities.temperature === SensorStatus.Available, (value: boolean): void => {
            sensorService.toggleCapability('temperature', value, appStore);
          })
        this.hardwareSwitch($r('app.string.demo_fall_switch'),
          appStore.capabilities.fallDetection === SensorStatus.Available, (value: boolean): void => {
            sensorService.toggleCapability('fallDetection', value, appStore);
          })

        this.sectionTitle($r('app.string.demo_alert_title'))
        this.hardwareSwitch($r('app.string.demo_auto_alerts'), appStore.autoAlerts, (value: boolean): void => {
          appStore.autoAlerts = value;
          emergencyService.updateAutoAlert(appStore);
        })
        this.sectionTitle($r('app.string.demo_reason_title'))
        // Etiquetas largas: una por fila y la elegida resaltada.
        this.wideButton('reasonPulse', $r('app.string.demo_reason_pulse'),
          this.reasonColor(AlertReason.PulsoCritico), (): void => {
            this.reason = AlertReason.PulsoCritico;
          })
        this.wideButton('reasonFall', $r('app.string.demo_reason_fall'),
          this.reasonColor(AlertReason.Caida), (): void => {
            this.reason = AlertReason.Caida;
          })
        this.wideButton('reasonSos', $r('app.string.demo_reason_sos'),
          this.reasonColor(AlertReason.SosManual), (): void => {
            this.reason = AlertReason.SosManual;
          })

        this.wideButton('simulateAlert', $r('app.string.demo_simulate_alert'),
          $r('app.color.accion_principal'), (): void => {
            emergencyService.simulateAlert(this.reason);
          })
        this.wideButton('viewAlertSent', $r('app.string.demo_view_alert_sent'),
          $r('app.color.card'), (): void => {
            emergencyService.viewAlertSent();
          })
        this.wideButton('contactResponse', $r('app.string.demo_simulate_contact_response'),
          $r('app.color.card'), (): void => {
            emergencyService.advanceContactResponse();
          })

        Row({ space: dimens.cqw(DesignTokens.demoGapCqw) }) {
          this.choiceButton('modeOffline', $r('app.string.demo_offline'), this.modeColor('offline'), (): void => {
            appStore.mode = 'offline';
          })
          this.choiceButton('modeLive', $r('app.string.monitor_live'), this.modeColor('live'), (): void => {
            appStore.mode = 'live';
            emergencyService.updateAutoAlert(appStore);
          })
        }
        .width('100%')
        .margin({ top: dimens.cqw(DesignTokens.demoSectionGapCqw) })

        // Primer uso como interruptor: encendido = 'first-use'; apagado vuelve a 'live'.
        this.hardwareSwitch($r('app.string.demo_first_use'), appStore.mode === 'first-use',
          (value: boolean): void => {
            appStore.mode = value ? 'first-use' : 'live';
            emergencyService.updateAutoAlert(appStore);
          })

        this.hardwareSwitch($r('app.string.demo_contacts_empty'), appStore.contacts.length === 0,
          (value: boolean): void => {
            emergencyService.setContactsEmpty(value);
          })
        this.hardwareSwitch($r('app.string.demo_medical_sample'), extraDemoState.medicalSample,
          (value: boolean): void => {
            extraDemoState.medicalSample = value;
          })

        Button() {
          Text($r('app.string.demo_contact_added'))
            .fontSize(dimens.u(DesignTokens.fsBody))
            .fontColor($r('app.color.text_primary'))
            .fontWeight(FontWeight.Bold)
            .maxLines(2)
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .height(dimens.touchMin())
        .borderRadius(dimens.cqw(DesignTokens.demoButtonRadiusCqw))
        .backgroundColor($r('app.color.card'))
        .margin({ top: dimens.cqw(DesignTokens.demoGapCqw) })
        .onClick((): void => {
          this.runClick('contactAdded', (): void => {
            emergencyService.addDemoContact();
          });
        })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      // Holgura final: lo último no queda bajo el borde redondo ni bajo TEST.
      .padding({ bottom: dimens.touchMin() })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Bottom }) {
        ScreenScaffold({
          logTag: 'DemoPanelPage',
          bodyContent: (): void => {
            this.demoBody();
          }
        })

        // EXPERIMENTO: botón nativo fuera de Scroll/List y de componentes propios.
        if (PANEL_PROBE) {
          Button('TEST')
            .fontSize(dimens.u(DesignTokens.fsLabel))
            .fontColor($r('app.color.text_primary'))
            .backgroundColor($r('app.color.orange'))
            .width(dimens.percent(DesignTokens.primaryButtonWidthPercent))
            .height(dimens.touchMin())
            .margin({ bottom: dimens.safeBottom() })
            .onClick((): void => {
              Logger.info(TAG, `TEST onClick navStackDepth=${appStore.navStackDepth}`);
            })
        }
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.watch_background'))
    .onBackPressed((): boolean => {
      // Botón/gesto de sistema: cerramos nosotros para limpiar banderas y loguear.
      this.close('system-back');
      return true;
    })
    // Swipe a la derecha (convención de Watch): paralelo para no robar el scroll vertical.
    .parallelGesture(
      PanGesture({ direction: PanDirection.Right, distance: dimens.u(SWIPE_CLOSE_BASE) })
        .onActionEnd((_event: GestureEvent): void => {
          this.close('swipe-right');
        })
    )
    // Sonda: registra Down/Up en la raíz del panel (DEBUG_LAYOUT o PANEL_PROBE).
    .onTouch((event: TouchEvent): void => {
      if ((event.type === TouchType.Down || event.type === TouchType.Up) && event.changedTouches.length > 0) {
        const touch: TouchObject = event.changedTouches[0];
        this.log(`touch type=${event.type} x=${touch.x.toFixed(0)} y=${touch.y.toFixed(0)}`);
      }
    })
  }

  private modeColor(mode: string): Resource {
    return appStore.mode === mode ? $r('app.color.green') : $r('app.color.card');
  }

  private speedColor(speed: number): Resource {
    return this.timeScale === speed ? $r('app.color.green') : $r('app.color.card');
  }

  private selectSpeed(speed: number): void {
    this.timeScale = speed;
    emergencyService.setTimeScale(speed);
  }

  private selectPulse(state: PulseState): void {
    sensorService.selectVariant(state, appStore);
    appStore.mode = 'live';
    emergencyService.updateAutoAlert(appStore);
  }
}
