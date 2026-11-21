import { ExtraPageHeader } from '../components/ExtraPageHeader';
import { ExtraSettingButton } from '../components/ExtraSettingButton';
import { ExtraSettingToggle } from '../components/ExtraSettingToggle';
import { ScreenScaffold } from '../components/ScreenScaffold';
import { SensorStatus } from '../model/SensorAvailability';
import { vibrationService } from '../service/VibrationService';
import { appStore } from '../state/AppStore';
import { SENSITIVITY_THRESHOLDS, VibrationPattern } from '../state/EmergencyMachine';
import { DesignTokens } from '../util/DesignTokens';
import { dimens } from '../util/Dimens';
import { Logger } from '../util/Logger';

// REGISTRAR: Index.ets -> ArcSwiper() ya contiene SettingsPage() como sexta página; no añadir nada.

const TAG: string = 'SettingsPage';
const VIBRATION_FEEDBACK_MS: number = 1600;

@ComponentV2
export struct SettingsPage {
  @Local vibrationSent: boolean = false;
  private feedbackTimer: number | undefined = undefined;

  aboutToDisappear(): void {
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
  }

  private fallAvailable(): boolean {
    return appStore.capabilities.fallDetection === SensorStatus.Available;
  }

  private testVibration(): void {
    Logger.info(TAG, 'onClick vibracion');
    vibrationService.vibrate(VibrationPattern.Triple);
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
  }

  @Builder
  settingsBody() {
    Scroll() {
      Column({ space: dimens.cqw(1.8) }) {
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
          subtitle: $r('app.string.extra_settings_notice_desc'),
          value: this.noticeLabel(),
          name: 'notice',
          onPress: (): void => {
            this.cycleNotice();
          }
        })

        ExtraSettingToggle({
          title: $r('app.string.exercise_mode'),
          subtitle: $r('app.string.extra_settings_exercise_desc'),
          isOn: appStore.settings.exerciseMode,
          name: 'exerciseMode',
          onValueChange: (value: boolean): void => {
            appStore.settings.exerciseMode = value;
          }
        })

        ExtraSettingToggle({
          title: $r('app.string.battery_saver'),
          subtitle: $r('app.string.battery_desc'),
          isOn: appStore.settings.batterySaver,
          name: 'batterySaver',
          onValueChange: (value: boolean): void => {
            appStore.settings.batterySaver = value;
          }
        })

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
            }
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
