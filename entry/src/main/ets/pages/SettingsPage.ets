import { ExtraPageHeader } from '../components/ExtraPageHeader';
import { ExtraSettingButton } from '../components/ExtraSettingButton';
import { ExtraSettingToggle } from '../components/ExtraSettingToggle';
import { ScreenScaffold } from '../components/ScreenScaffold';
import { SensorStatus } from '../model/SensorAvailability';
import { vibrationService } from '../service/VibrationService';
import { emergencyService } from '../service/EmergencyService';
import { sensorService } from '../service/SensorService';
import { DemoChoiceButton } from '../components/DemoChoiceButton';
import { PulseState } from '../model/PulseState';
import { appStore } from '../state/AppStore';
import { SENSITIVITY_THRESHOLDS, VibrationPattern } from '../state/EmergencyMachine';
import { DesignTokens } from '../util/DesignTokens';
import { dimens } from '../util/Dimens';
import { Logger } from '../util/Logger';
import { crownNav } from '../util/CrownNav';

// REGISTRAR: Index.ets -> ArcSwiper() ya contiene SettingsPage() como sexta página; no añadir nada.

const TAG: string = 'SettingsPage';
const VIBRATION_FEEDBACK_MS: number = 1600;
const DEMO_UNLOCK_MS: number = 3000;

@ComponentV2
export struct SettingsPage {
  /** Página 5 del ArcSwiper: al salir de ella, su contenido vuelve arriba (sin animación). */
  private readonly scroller: Scroller = new Scroller();
  private unsubscribePage: () => void = (): void => {};
  private unregisterScroller: () => void = (): void => {};

  aboutToAppear(): void {
    // La corona (recibida por Index) desplaza esta lista cuando la página 5 está visible.
    this.unregisterScroller = crownNav.registerScroller(5, this.scroller);
    this.unsubscribePage = crownNav.onPageChanged((index: number): void => {
      if (index !== 5) {
        try {
          this.scroller.scrollTo({ xOffset: 0, yOffset: 0, animation: false });
        } catch (err) {
          // Sin lista montada (p. ej., Contactos vacío): no hay nada que desplazar.
        }
      }
    });
  }

  @Local vibrationSent: boolean = false;
  @Local locationDenied: boolean = false;
  /** Sección de Modo demostración visible (gesto de 3 s en el título). No se guarda. */
  @Local demoUnlocked: boolean = false;
  private feedbackTimer: number | undefined = undefined;

  aboutToDisappear(): void {
    this.unsubscribePage();
    this.unregisterScroller();
    if (this.feedbackTimer !== undefined) {
      clearTimeout(this.feedbackTimer);
      this.feedbackTimer = undefined;
    }
  }

  private sensitivityLabel(): Resource {
    if (appStore.settings.sensitivity === 'Baja') {
      return $r('app.string.sensitivity_low');
    }
    if (appStore.settings.sensitivity === 'Alta') {
      return $r('app.string.sensitivity_high');
    }
    return $r('app.string.sensitivity_medium');
  }

  private sensitivityThreshold(): number {
    if (appStore.settings.sensitivity === 'Baja') {
      return SENSITIVITY_THRESHOLDS.Baja;
    }
    if (appStore.settings.sensitivity === 'Alta') {
      return SENSITIVITY_THRESHOLDS.Alta;
    }
    return SENSITIVITY_THRESHOLDS.Media;
  }

  private cycleSensitivity(): void {
    Logger.info(TAG, `sensibilidad antes=${appStore.settings.sensitivity}`);
    if (appStore.settings.sensitivity === 'Baja') {
      appStore.settings.sensitivity = 'Media';
    } else if (appStore.settings.sensitivity === 'Media') {
      appStore.settings.sensitivity = 'Alta';
    } else {
      appStore.settings.sensitivity = 'Baja';
    }
    Logger.info(TAG, `sensibilidad despues=${appStore.settings.sensitivity}`);
    emergencyService.saveSettings();
  }

  private noticeLabel(): Resource {
    if (appStore.settings.noticeMinutes === 1) {
      return $r('app.string.minutes_1');
    }
    if (appStore.settings.noticeMinutes === 3) {
      return $r('app.string.minutes_3');
    }
    if (appStore.settings.noticeMinutes === 10) {
      return $r('app.string.minutes_10');
    }
    return $r('app.string.minutes_5');
  }

  private cycleNotice(): void {
    Logger.info(TAG, `aviso antes=${appStore.settings.noticeMinutes}`);
    if (appStore.settings.noticeMinutes === 1) {
      appStore.settings.noticeMinutes = 3;
    } else if (appStore.settings.noticeMinutes === 3) {
      appStore.settings.noticeMinutes = 5;
    } else if (appStore.settings.noticeMinutes === 5) {
      appStore.settings.noticeMinutes = 10;
    } else {
      appStore.settings.noticeMinutes = 1;
    }
    Logger.info(TAG, `aviso despues=${appStore.settings.noticeMinutes}`);
    emergencyService.saveSettings();
  }

  private fallAvailable(): boolean {
    return appStore.capabilities.fallDetection === SensorStatus.Available;
  }

  private testVibration(): void {
    Logger.info(TAG, 'onClick vibracion');
    vibrationService.vibrate(VibrationPattern.Triple, 'probar-vibracion');
    this.vibrationSent = true;
    if (this.feedbackTimer !== undefined) {
      clearTimeout(this.feedbackTimer);
    }
    this.feedbackTimer = setTimeout((): void => {
      this.feedbackTimer = undefined;
      this.vibrationSent = false;
    }, VIBRATION_FEEDBACK_MS);
  }

  @Builder
  settingsHeader() {
    ExtraPageHeader({
      title: $r('app.string.page_settings'),
      symbol: $r('sys.symbol.gearshape')
    })
      // Acceso oculto para revisores: mantener pulsado el título 3 s muestra "Modo demostración".
      .gesture(LongPressGesture({ duration: DEMO_UNLOCK_MS }).onAction((_event: GestureEvent): void => {
        Logger.info(TAG, 'sección de Modo demostración desbloqueada');
        this.demoUnlocked = true;
      }))
  }

  @Builder
  settingsBody() {
    Scroll(this.scroller) {
      Column({ space: dimens.cqw(1.8) }) {
        // v1.0.1: alcance real de la vigilancia (sin tarea continua en segundo plano).
        Text($r('app.string.monitoring_scope'))
          .fontSize(dimens.u(DesignTokens.fsMin))
          .fontColor($r('app.color.orange'))
          .maxLines(3)
          .textAlign(TextAlign.Center)
          .width('100%')
        ExtraSettingButton({
          title: $r('app.string.sensitivity'),
          subtitle: $r('app.string.threshold', this.sensitivityThreshold()),
          value: this.sensitivityLabel(),
          name: 'sensitivity',
          onPress: (): void => {
            this.cycleSensitivity();
          }
        })

        ExtraSettingButton({
          title: $r('app.string.notice_time'),
          subtitle: $r('app.string.notice_desc_v101'),
          value: this.noticeLabel(),
          name: 'notice',
          onPress: (): void => {
            this.cycleNotice();
          }
        })

        ExtraSettingToggle({
          title: $r('app.string.exercise_mode'),
          subtitle: $r('app.string.exercise_desc_v101'),
          isOn: appStore.settings.exerciseMode,
          name: 'exerciseMode',
          onValueChange: (value: boolean): void => {
            appStore.settings.exerciseMode = value;
            emergencyService.saveSettings();
          }
        })

        // v1.0.1: "Ahorro de batería" retirado (no tenía efecto real).

        ExtraSettingToggle({
          title: $r('app.string.fall_detection'),
          subtitle: this.fallAvailable() ? $r('app.string.fall_accelerometer') : $r('app.string.fall_unavailable'),
          isOn: appStore.settings.fallDetection,
          switchEnabled: this.fallAvailable(),
          hint: this.fallAvailable() ? $r('app.string.fall_active') : $r('app.string.fall_disabled_hint'),
          name: 'fallDetection',
          onValueChange: (value: boolean): void => {
            if (this.fallAvailable()) {
              appStore.settings.fallDetection = value;
              emergencyService.saveSettings();
            }
          }
        })

        ExtraSettingToggle({
          title: $r('app.string.location_setting'),
          subtitle: this.locationDenied ? $r('app.string.location_setting_denied') : $r('app.string.location_setting_desc'),
          isOn: appStore.settings.locationEnabled,
          hint: $r('app.string.location_setting_desc'),
          name: 'location',
          onValueChange: (value: boolean): void => {
            emergencyService.setLocationEnabled(value).then((granted: boolean): void => {
              this.locationDenied = value && !granted;
            }).catch((err: Object): void => {
              Logger.error(TAG, 'setLocationEnabled falló', err);
            });
          }
        })

        ExtraSettingButton({
          title: $r('app.string.test_vibration'),
          subtitle: this.vibrationSent ? $r('app.string.vibration_sent') : $r('app.string.tactile_notice'),
          value: this.vibrationSent ? $r('app.string.ready') : $r('app.string.test'),
          accent: true,
          name: 'vibration',
          onPress: (): void => {
            this.testVibration();
          }
        })

        // Modo demostración: oculto. Se abre manteniendo pulsado el título 3 s (solo para revisión).
        if (this.demoUnlocked || appStore.settings.demoMode) {
          ExtraSettingToggle({
            title: $r('app.string.demo_mode'),
            subtitle: appStore.settings.demoMode ? $r('app.string.demo_mode_on_desc') : $r('app.string.demo_mode_desc'),
            isOn: appStore.settings.demoMode,
            hint: $r('app.string.demo_mode_desc'),
            name: 'demoMode',
            onValueChange: (value: boolean): void => {
              // No se guarda: tras reiniciar, el Modo demostración siempre arranca apagado.
              sensorService.setDemoMode(value);
            }
          })

          if (appStore.settings.demoMode) {
            Text($r('app.string.demo_mode_pick'))
              .fontSize(dimens.u(DesignTokens.fsMin))
              .fontColor($r('app.color.orange'))
              .maxLines(2)
              .textAlign(TextAlign.Center)
              .width('100%')
            DemoChoiceButton({
              label: $r('app.string.demo_state_normal'),
              color: appStore.pulseState === PulseState.Normal ? $r('app.color.green') : $r('app.color.card'),
              onPress: (): void => {
                sensorService.selectVariant(PulseState.Normal, appStore);
              }
            })
            DemoChoiceButton({
              label: $r('app.string.demo_state_elevated'),
              color: appStore.pulseState === PulseState.Elevated ? $r('app.color.orange') : $r('app.color.card'),
              onPress: (): void => {
                sensorService.selectVariant(PulseState.Elevated, appStore);
              }
            })
            DemoChoiceButton({
              label: $r('app.string.demo_state_critical'),
              color: appStore.pulseState === PulseState.Critical ? $r('app.color.red') : $r('app.color.card'),
              onPress: (): void => {
                sensorService.selectVariant(PulseState.Critical, appStore);
              }
            })
          }
          DemoChoiceButton({
            label: $r('app.string.demo_hide'),
            color: $r('app.color.surface_deep'),
            onPress: (): void => {
              sensorService.setDemoMode(false);
              this.demoUnlocked = false;
            }
          })
        }
      }
      .width('100%')
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
      logTag: 'SettingsPage',
      headerContent: (): void => {
        this.settingsHeader();
      },
      bodyContent: (): void => {
        this.settingsBody();
      }
    })
  }
}
