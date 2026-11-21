import { PageHeader } from '../components/PageHeader';
import { ScreenScaffold } from '../components/ScreenScaffold';
import { SensorStatus } from '../model/SensorAvailability';
import { vibrationService } from '../service/VibrationService';
import { appStore } from '../state/AppStore';
import { SENSITIVITY_THRESHOLDS, VibrationPattern } from '../state/EmergencyMachine';
import { DesignTokens } from '../util/DesignTokens';
import { dimens } from '../util/Dimens';

// REGISTRAR: Index.ets -> ArcSwiper() ya contiene SettingsPage() como sexta página; no añadir nada.

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
    if (appStore.settings.sensitivity === 'Baja') {
      appStore.settings.sensitivity = 'Media';
    } else if (appStore.settings.sensitivity === 'Media') {
      appStore.settings.sensitivity = 'Alta';
    } else {
      appStore.settings.sensitivity = 'Baja';
    }
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
    if (appStore.settings.noticeMinutes === 1) {
      appStore.settings.noticeMinutes = 3;
    } else if (appStore.settings.noticeMinutes === 3) {
      appStore.settings.noticeMinutes = 5;
    } else if (appStore.settings.noticeMinutes === 5) {
      appStore.settings.noticeMinutes = 10;
    } else {
      appStore.settings.noticeMinutes = 1;
    }
  }

  private fallAvailable(): boolean {
    return appStore.capabilities.fallDetection === SensorStatus.Available;
  }

  private testVibration(): void {
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
    PageHeader({ title: $r('app.string.page_settings'), icon: $r('app.string.icon_sensor') })
  }

  @Builder
  badge(label: Resource, accent: boolean = false) {
    Text(label)
      .fontSize(dimens.u(DesignTokens.fsMin))
      .fontColor(accent ? $r('app.color.green') : $r('app.color.text_primary'))
      .fontWeight(FontWeight.Bold)
      .constraintSize({ minHeight: dimens.u(DesignTokens.demoBadgeHeightBase) })
      .padding({
        left: dimens.u(DesignTokens.demoBadgePaddingBase),
        right: dimens.u(DesignTokens.demoBadgePaddingBase)
      })
      .borderRadius(dimens.radiusChip())
      .backgroundColor($r('app.color.card'))
      .border({ width: dimens.thinBorder(), color: $r('app.color.border') })
      .maxLines(1)
  }

  @Builder
  rowContent(title: Resource, subtitle: Resource) {
    Column({ space: 0 }) {
      Text(title)
        .fontSize(dimens.u(DesignTokens.fsLabel))
        .fontColor($r('app.color.text_primary'))
        .fontWeight(FontWeight.Medium)
        .maxLines(1)
      Text(subtitle)
        .fontSize(dimens.u(DesignTokens.fsMin))
        .fontColor($r('app.color.muted'))
        .maxLines(2)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  settingsBody() {
    Scroll() {
      Column({ space: dimens.cqw(1.8) }) {
        Row() {
          this.rowContent($r('app.string.sensitivity'), $r('app.string.threshold', this.sensitivityThreshold()))
          this.badge(this.sensitivityLabel())
        }
        .width('100%')
        .constraintSize({ minHeight: dimens.cqw(DesignTokens.infoCardMinHeightCqw) })
        .padding({
          top: dimens.cqw(2.4), bottom: dimens.cqw(2.4),
          left: dimens.cqw(3.6), right: dimens.cqw(3.6)
        })
        .backgroundColor($r('app.color.card'))
        .border({ width: dimens.thinBorder(), color: $r('app.color.border') })
        .borderRadius(dimens.radiusCard())
        .onClick((): void => {
          this.cycleSensitivity();
        })

        Row() {
          this.rowContent($r('app.string.notice_time'),
            $r('app.string.next_notice', appStore.settings.noticeMinutes))
          this.badge(this.noticeLabel())
        }
        .width('100%')
        .constraintSize({ minHeight: dimens.cqw(DesignTokens.infoCardMinHeightCqw) })
        .padding({
          top: dimens.cqw(2.4), bottom: dimens.cqw(2.4),
          left: dimens.cqw(3.6), right: dimens.cqw(3.6)
        })
        .backgroundColor($r('app.color.card'))
        .border({ width: dimens.thinBorder(), color: $r('app.color.border') })
        .borderRadius(dimens.radiusCard())
        .onClick((): void => {
          this.cycleNotice();
        })

        Row() {
          this.rowContent($r('app.string.exercise_mode'),
            appStore.settings.exerciseMode ? $r('app.string.exercise_paused') : $r('app.string.exercise_frequent'))
          Toggle({ type: ToggleType.Switch, isOn: appStore.settings.exerciseMode })
            .selectedColor($r('app.color.green'))
            .onChange((value: boolean): void => {
              appStore.settings.exerciseMode = value;
            })
        }
        .width('100%')
        .constraintSize({ minHeight: dimens.cqw(DesignTokens.infoCardMinHeightCqw) })
        .padding({
          top: dimens.cqw(2.4), bottom: dimens.cqw(2.4),
          left: dimens.cqw(3.6), right: dimens.cqw(3.6)
        })
        .backgroundColor($r('app.color.card'))
        .border({ width: dimens.thinBorder(), color: $r('app.color.border') })
        .borderRadius(dimens.radiusCard())

        Row() {
          this.rowContent($r('app.string.battery_saver'), $r('app.string.battery_desc'))
          Toggle({ type: ToggleType.Switch, isOn: appStore.settings.batterySaver })
            .selectedColor($r('app.color.green'))
            .onChange((value: boolean): void => {
              appStore.settings.batterySaver = value;
            })
        }
        .width('100%')
        .constraintSize({ minHeight: dimens.cqw(DesignTokens.infoCardMinHeightCqw) })
        .padding({
          top: dimens.cqw(2.4), bottom: dimens.cqw(2.4),
          left: dimens.cqw(3.6), right: dimens.cqw(3.6)
        })
        .backgroundColor($r('app.color.card'))
        .border({ width: dimens.thinBorder(), color: $r('app.color.border') })
        .borderRadius(dimens.radiusCard())

        Row() {
          this.rowContent($r('app.string.fall_detection'),
            this.fallAvailable() ? $r('app.string.fall_accelerometer') : $r('app.string.fall_unavailable'))
          Toggle({ type: ToggleType.Switch, isOn: appStore.settings.fallDetection })
            .selectedColor($r('app.color.green'))
            .enabled(this.fallAvailable())
            .opacity(this.fallAvailable() ? 1 : 0.4)
            .accessibilityText(this.fallAvailable() ? $r('app.string.fall_active') : $r('app.string.fall_disabled_hint'))
            .onChange((value: boolean): void => {
              if (this.fallAvailable()) {
                appStore.settings.fallDetection = value;
              }
            })
        }
        .width('100%')
        .constraintSize({ minHeight: dimens.cqw(DesignTokens.infoCardMinHeightCqw) })
        .padding({
          top: dimens.cqw(2.4), bottom: dimens.cqw(2.4),
          left: dimens.cqw(3.6), right: dimens.cqw(3.6)
        })
        .backgroundColor($r('app.color.card'))
        .border({ width: dimens.thinBorder(), color: $r('app.color.border') })
        .borderRadius(dimens.radiusCard())

        Row() {
          this.rowContent($r('app.string.test_vibration'),
            this.vibrationSent ? $r('app.string.vibration_sent') : $r('app.string.tactile_notice'))
          this.badge(this.vibrationSent ? $r('app.string.ready') : $r('app.string.test'), true)
        }
        .width('100%')
        .constraintSize({ minHeight: dimens.cqw(DesignTokens.infoCardMinHeightCqw) })
        .padding({
          top: dimens.cqw(2.4), bottom: dimens.cqw(2.4),
          left: dimens.cqw(3.6), right: dimens.cqw(3.6)
        })
        .backgroundColor($r('app.color.card'))
        .border({ width: dimens.thinBorder(), color: $r('app.color.border') })
        .borderRadius(dimens.radiusCard())
        .onClick((): void => {
          this.testVibration();
        })
      }
      .width('100%')
      .padding({ top: dimens.cqw(2.4), bottom: dimens.cqw(2.4) })
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
