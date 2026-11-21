import { DesignTokens } from '../util/DesignTokens';
import { DEBUG_LAYOUT, dimens } from '../util/Dimens';
import { Logger } from '../util/Logger';
import { appStore } from '../state/AppStore';
import { emergencyService } from '../service/EmergencyService';
import { PulseState } from '../model/PulseState';
import { SensorStatus } from '../model/SensorAvailability';
import { ScreenScaffold } from '../components/ScreenScaffold';
import { HeartRateGauge } from '../components/HeartRateGauge';
import { SensorChip } from '../components/SensorChip';
import { SosButton } from '../components/SosButton';
import { DEMO_VISIBLE } from '../util/AppConfig';

const TAG: string = 'MonitorPage';

// DEMO_VISIBLE vive en util/AppConfig.ets (se apaga con RELEASE_MODE).

@ComponentV2
export struct MonitorPage {
  @Event onOpenDemo: () => void = () => {};
  @Event onOpenContacts: () => void = () => {};
  @Local bodyHeightVp: number = dimens.u(DesignTokens.monitorUsableHeightBase);

  private isFirstUse(): boolean {
    return appStore.mode === 'first-use';
  }

  private liveLabel(): Resource {
    if (this.isFirstUse()) {
      return $r('app.string.monitor_first_use');
    }
    if (appStore.mode === 'offline') {
      return $r('app.string.monitor_offline');
    }
    return $r('app.string.monitor_live');
  }

  private liveDotColor(): Resource {
    return appStore.mode === 'offline' ? $r('app.color.orange') : $r('app.color.accion_principal');
  }

  private stateLabel(): Resource {
    if (this.isFirstUse()) {
      return $r('app.string.calibrating_ellipsis');
    }
    if (appStore.pulseState === PulseState.Critical) {
      return $r('app.string.pulse_critical');
    }
    if (appStore.pulseState === PulseState.Elevated) {
      return $r('app.string.pulse_elevated');
    }
    return $r('app.string.pulse_normal');
  }

  private stateTone(): Resource {
    return this.isFirstUse() ? $r('app.color.muted') : appStore.stateColor;
  }

  private spo2Available(): boolean {
    return !this.isFirstUse() && appStore.capabilities.spo2 === SensorStatus.Available;
  }

  private spo2Chip(): Resource {
    if (!this.spo2Available()) {
      return $r('app.string.dash');
    }
    if (appStore.spo2 >= 95) {
      return $r('app.string.spo2_chip_98');
    }
    if (appStore.spo2 >= 90) {
      return $r('app.string.spo2_chip_93');
    }
    return $r('app.string.spo2_chip_88');
  }

  private spo2Tone(): Resource {
    if (!this.spo2Available()) {
      return $r('app.color.muted');
    }
    if (appStore.spo2 >= 95) {
      return $r('app.color.green');
    }
    if (appStore.spo2 >= 90) {
      return $r('app.color.orange');
    }
    return $r('app.color.red');
  }

  private spo2Accessibility(): Resource {
    return this.spo2Available() ? $r('app.string.a11y_spo2_detail') : $r('app.string.a11y_spo2_unavailable');
  }

  private movementText(): Resource {
    return this.isFirstUse() ? $r('app.string.calibrating') : appStore.movementLabel;
  }

  /** Presupuesto real del cuerpo: primero se reduce el arco, después los espacios. */
  private availableBase(): number {
    return dimens.scale > 0 ? this.bodyHeightVp / dimens.scale : DesignTokens.monitorUsableHeightBase;
  }

  private arcSizeBase(): number {
    const fixed: number = DesignTokens.monitorLiveRowBase + DesignTokens.monitorStatusRowBase +
      DesignTokens.monitorChipRowBase + DesignTokens.monitorActionsBase +
      DesignTokens.monitorGapSmallBase * 2 + DesignTokens.monitorGapLargeBase * 2;
    return Math.max(DesignTokens.monitorArcMinBase,
      Math.min(DesignTokens.monitorArcBase, this.availableBase() - fixed));
  }

  private gapScale(): number {
    const fixedWithoutGaps: number = this.arcSizeBase() +
      DesignTokens.monitorLiveRowBase + DesignTokens.monitorStatusRowBase +
      DesignTokens.monitorChipRowBase + DesignTokens.monitorActionsBase;
    const gaps: number = DesignTokens.monitorGapSmallBase * 2 + DesignTokens.monitorGapLargeBase * 2;
    return Math.max(0, Math.min(1, (this.availableBase() - fixedWithoutGaps) / gaps));
  }

  private gap(base: number): number {
    return dimens.u(base * this.gapScale());
  }

  private logChord(name: string, centerY: number, width: number): void {
    const radius: number = DesignTokens.base / 2;
    const dy: number = centerY - radius;
    const chordHalf: number = Math.sqrt(Math.max(0, radius * radius - dy * dy));
    Logger.info(TAG,
      `${name}: centerY=${centerY.toFixed(1)} width=${width.toFixed(1)} half=${(width / 2).toFixed(1)} chordHalf=${chordHalf.toFixed(1)} inside=${width / 2 <= chordHalf}`);
  }

  /** Comprueba la cuerda del círculo disponible para cada fila (solo con DEBUG_LAYOUT). */
  private logCircleFit(): void {
    if (!DEBUG_LAYOUT) {
      return;
    }
    const radius: number = DesignTokens.base / 2;
    const top: number = dimens.percent(DesignTokens.monitorSafeBlockPercent) / dimens.scale;
    const innerWidth: number = DesignTokens.base * (1 - 2 * DesignTokens.safeInlinePercent / 100);
    const arc: number = this.arcSizeBase();
    const small: number = DesignTokens.monitorGapSmallBase;
    const large: number = DesignTokens.monitorGapLargeBase;
    let y: number = top;

    y += DesignTokens.monitorLiveRowBase / 2;
    this.logChord('live', y, DesignTokens.monitorLiveRowWidthBase);
    y += DesignTokens.monitorLiveRowBase / 2 + small;

    y += arc / 2;
    this.logChord('arc', y, arc);
    y += arc / 2 + small;

    y += DesignTokens.monitorStatusRowBase / 2;
    this.logChord('status', y, innerWidth);
    y += DesignTokens.monitorStatusRowBase / 2 + large;

    y += DesignTokens.monitorChipRowBase / 2;
    this.logChord('chips', y,
      DesignTokens.base * DesignTokens.monitorChipsWidthPercent / 100);
    y += DesignTokens.monitorChipRowBase / 2 + large;

    y += DesignTokens.monitorActionsBase / 2;
    this.logChord('actions', y, DesignTokens.sosButtonWidthBase +
      DesignTokens.monitorActionsGapBase + DesignTokens.contactsButtonBase);
    Logger.info(TAG, `circleRadius=${radius} contentBottom=${(y + DesignTokens.monitorActionsBase / 2).toFixed(1)}`);
  }

  @Builder
  usersIcon() {
    Row({ space: dimens.u(DesignTokens.usersIconGapBase) }) {
      Column({ space: dimens.u(DesignTokens.usersIconGapBase) }) {
        Circle()
          .width(dimens.u(DesignTokens.usersIconHeadBase))
          .height(dimens.u(DesignTokens.usersIconHeadBase))
          .fill($r('app.color.text_primary'))
        Column()
          .width(dimens.u(DesignTokens.usersIconBodyWidthBase))
          .height(dimens.u(DesignTokens.usersIconBodyHeightBase))
          .borderRadius(dimens.u(DesignTokens.usersIconRadiusBase))
          .backgroundColor($r('app.color.text_primary'))
      }
      Column({ space: dimens.u(DesignTokens.usersIconGapBase) }) {
        Circle()
          .width(dimens.u(DesignTokens.usersIconHeadBase))
          .height(dimens.u(DesignTokens.usersIconHeadBase))
          .fill($r('app.color.text_primary'))
        Column()
          .width(dimens.u(DesignTokens.usersIconBodyWidthBase))
          .height(dimens.u(DesignTokens.usersIconBodyHeightBase))
          .borderRadius(dimens.u(DesignTokens.usersIconRadiusBase))
          .backgroundColor($r('app.color.text_primary'))
      }
    }
    .alignItems(VerticalAlign.Bottom)
  }

  @Builder
  demoBadge() {
    Button($r('app.string.demo_badge'))
      .fontSize(dimens.u(DesignTokens.fsMin))
      .fontColor($r('app.color.red'))
      .height(dimens.u(DesignTokens.demoBadgeHeightBase))
      .padding({
        left: dimens.u(DesignTokens.demoBadgePaddingBase),
        right: dimens.u(DesignTokens.demoBadgePaddingBase)
      })
      .borderRadius(dimens.radiusChip())
      .backgroundColor($r('app.color.card'))
      .border({ width: dimens.thinBorder(), color: $r('app.color.red') })
      .responseRegion({
        x: -dimens.u(DesignTokens.demoBadgeHitExpandXBase),
        y: -dimens.u(DesignTokens.demoBadgeHitExpandYBase),
        width: dimens.u(DesignTokens.demoBadgeHitWidthBase),
        height: dimens.touchMin()
      })
      .onClick((): void => {
        this.onOpenDemo();
      })
  }

  @Builder
  monitorBody() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        Row({ space: dimens.u(DesignTokens.chipGapBase) }) {
          Circle()
            .width(dimens.u(DesignTokens.liveDotBase))
            .height(dimens.u(DesignTokens.liveDotBase))
            .fill(this.liveDotColor())
          Text(this.liveLabel())
            .fontSize(dimens.u(DesignTokens.fsMin))
            .fontColor($r('app.color.text_primary'))
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
          if (appStore.settings.exerciseMode) {
            Text($r('app.string.monitor_exercise'))
              .fontSize(dimens.u(DesignTokens.fsMin))
              .fontColor($r('app.color.green'))
              .maxLines(1)
          }
        }
        .width(dimens.u(DesignTokens.monitorLiveRowWidthBase))
        .height(dimens.u(DesignTokens.monitorLiveRowBase))
        .justifyContent(FlexAlign.Center)
        .gesture(LongPressGesture({ duration: 3000 }).onAction((_event: GestureEvent): void => {
          if (!DEMO_VISIBLE) {
            return;
          }
          this.onOpenDemo();
        }))

        HeartRateGauge({
          bpm: appStore.bpm,
          state: appStore.pulseState,
          firstUse: this.isFirstUse(),
          sizeBase: this.arcSizeBase()
        })
          .margin({ top: this.gap(DesignTokens.monitorGapSmallBase) })

        Row() {
          Row() {
            Text(this.stateLabel())
              .fontSize(dimens.u(DesignTokens.fsMin))
              .fontColor(this.stateTone())
              .maxLines(1)
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)

          if (DEMO_VISIBLE) {
            this.demoBadge()
          }
        }
        .width('100%')
        .height(dimens.u(DesignTokens.monitorStatusRowBase))
        .margin({ top: this.gap(DesignTokens.monitorGapSmallBase) })
        .alignItems(VerticalAlign.Center)

        Row({ space: dimens.u(DesignTokens.monitorChipsGapBase) }) {
          SensorChip({
            text: this.spo2Chip(),
            tone: this.spo2Tone(),
            glyph: $r('app.string.icon_lock'),
            showGlyph: !this.spo2Available(),
            accessibility: this.spo2Accessibility()
          })
          SensorChip({
            text: this.movementText(),
            tone: this.stateTone(),
            accessibility: $r('app.string.a11y_spo2_detail')
          })
        }
        .width(dimens.percent(DesignTokens.monitorChipsWidthPercent))
        .height(dimens.u(DesignTokens.monitorChipRowBase))
        .margin({ top: this.gap(DesignTokens.monitorGapLargeBase) })
        .justifyContent(FlexAlign.SpaceBetween)

        Row({ space: dimens.u(DesignTokens.monitorActionsGapBase) }) {
          SosButton({
            onHoldStart: (): void => {
              emergencyService.startSosHold();
            },
            onHoldCancel: (): void => {
              emergencyService.cancelSosHold();
            }
          })
          Button() {
            this.usersIcon()
          }
          .width(dimens.u(DesignTokens.contactsButtonBase))
          .height(dimens.u(DesignTokens.contactsButtonBase))
          .borderRadius(dimens.u(DesignTokens.contactsButtonBase / 2))
          .backgroundColor($r('app.color.card'))
          .border({ width: dimens.thinBorder(), color: $r('app.color.red') })
          .accessibilityText($r('app.string.a11y_emergency_contacts'))
          .onClick((): void => {
            this.onOpenContacts();
          })
        }
        .width(dimens.u(DesignTokens.monitorContentWidthBase))
        .height(dimens.u(DesignTokens.monitorActionsBase))
        .margin({ top: this.gap(DesignTokens.monitorGapLargeBase) })
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)

      if (appStore.toastVisible) {
        Column() {
          Text(appStore.toastMessage)
            .fontSize(dimens.u(DesignTokens.fsMin))
            .fontColor($r('app.color.text_primary'))
            .padding({
              left: dimens.u(DesignTokens.chipPaddingBase),
              right: dimens.u(DesignTokens.chipPaddingBase),
              top: dimens.u(DesignTokens.chipGapBase),
              bottom: dimens.u(DesignTokens.chipGapBase)
            })
            .borderRadius(dimens.radiusChip())
            .backgroundColor($r('app.color.green'))
            .maxLines(1)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .position({ top: dimens.cqw(DesignTokens.toastTopCqw), left: 0 })
        .hitTestBehavior(HitTestMode.Transparent)
      }
    }
    .width('100%')
    .height('100%')
  }

  build() {
    ScreenScaffold({
      logTag: 'MonitorPage',
      safeTopPercent: DesignTokens.monitorSafeBlockPercent,
      safeBottomPercent: DesignTokens.monitorSafeBlockPercent,
      onBodyArea: (heightVp: number): void => {
        this.bodyHeightVp = heightVp;
        this.logCircleFit();
      },
      bodyContent: (): void => {
        this.monitorBody();
      }
    })
  }
}
