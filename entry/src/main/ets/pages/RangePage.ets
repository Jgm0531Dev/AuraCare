import { ExtraPageHeader } from '../components/ExtraPageHeader';
import { ScreenScaffold } from '../components/ScreenScaffold';
import { appStore } from '../state/AppStore';
import { DesignTokens } from '../util/DesignTokens';
import { dimens } from '../util/Dimens';

// REGISTRAR: Index.ets -> ArcSwiper() ya contiene RangePage() como tercera página; no añadir nada.

class CurvePoint {
  x: number = 0;
  y: number = 0;
}

const CURVE_VIEW_WIDTH: number = 240;
const CURVE_VIEW_HEIGHT: number = 70;
const CURVE_MIN_BPM: number = 40;
const CURVE_MAX_BPM: number = 160;
const PERSONAL_MIN_BPM: number = 58;
const PERSONAL_MAX_BPM: number = 92;
const GENERAL_MIN_BPM: number = 60;
const GENERAL_MAX_BPM: number = 100;
const ORANGE_MAX_BPM: number = 110;
const LOW_BPM: number = 45;

@ComponentV2
export struct RangePage {
  @Builder
  rangeHeader() {
    ExtraPageHeader({
      title: $r('app.string.page_range'),
      symbol: $r('sys.symbol.waveform_path_ecg_heart')
    })
  }

  private isFirstUse(): boolean {
    return appStore.mode === 'first-use';
  }

  private ratio(bpm: number): number {
    const raw: number = (bpm - CURVE_MIN_BPM) / (CURVE_MAX_BPM - CURVE_MIN_BPM);
    return Math.max(0.02, Math.min(0.98, raw));
  }

  private rangeMin(): number {
    return this.isFirstUse() ? GENERAL_MIN_BPM : PERSONAL_MIN_BPM;
  }

  private rangeMax(): number {
    return this.isFirstUse() ? GENERAL_MAX_BPM : PERSONAL_MAX_BPM;
  }

  private markerProgress(): number {
    const raw: number = (appStore.bpm - this.rangeMin()) / (this.rangeMax() - this.rangeMin());
    return Math.max(0, Math.min(1, raw));
  }

  private markerPoint(): CurvePoint {
    const from: number = this.ratio(this.rangeMin());
    const to: number = this.ratio(this.rangeMax());
    return this.curvePoint(from + (to - from) * this.markerProgress());
  }

  private curvePoint(t: number): CurvePoint {
    const inverse: number = 1 - t;
    const point: CurvePoint = new CurvePoint();
    point.x = inverse * inverse * 20 + 2 * inverse * t * 120 + t * t * 220;
    point.y = inverse * inverse * 52 + 2 * inverse * t * 16 + t * t * 52;
    return point;
  }

  private curveTangent(t: number): CurvePoint {
    const tangent: CurvePoint = new CurvePoint();
    tangent.x = 2 * ((1 - t) * (120 - 20) + t * (220 - 120));
    tangent.y = 2 * ((1 - t) * (16 - 52) + t * (52 - 16));
    return tangent;
  }

  private sx(value: number): number {
    return value * dimens.cqw(66) / CURVE_VIEW_WIDTH;
  }

  private sy(value: number): number {
    return value * dimens.cqw(17) / CURVE_VIEW_HEIGHT;
  }

  private trackCommands(): string {
    return `M ${this.sx(20).toFixed(2)} ${this.sy(52).toFixed(2)} Q ${this.sx(120).toFixed(2)} ${this.sy(16).toFixed(2)} ${this.sx(220).toFixed(2)} ${this.sy(52).toFixed(2)}`;
  }

  private highlightCommands(): string {
    const from: number = this.ratio(this.rangeMin());
    const to: number = this.ratio(this.rangeMax());
    const start: CurvePoint = this.curvePoint(from);
    const end: CurvePoint = this.curvePoint(to);
    const tangent: CurvePoint = this.curveTangent(from);
    const span: number = to - from;
    const control: CurvePoint = new CurvePoint();
    control.x = start.x + span * tangent.x / 2;
    control.y = start.y + span * tangent.y / 2;
    return `M ${this.sx(start.x).toFixed(2)} ${this.sy(start.y).toFixed(2)} Q ${this.sx(control.x).toFixed(2)} ${this.sy(control.y).toFixed(2)} ${this.sx(end.x).toFixed(2)} ${this.sy(end.y).toFixed(2)}`;
  }

  private markerColor(): Resource {
    if (this.isFirstUse()) {
      return $r('app.color.muted');
    }
    const value: number = appStore.bpm;
    if (value >= this.rangeMin() && value <= this.rangeMax()) {
      return $r('app.color.green');
    }
    if ((value > this.rangeMax() && value < ORANGE_MAX_BPM) ||
        (value < this.rangeMin() && value >= LOW_BPM)) {
      return $r('app.color.orange');
    }
    return $r('app.color.red');
  }

  @Builder
  curvedBar() {
    Stack() {
      Path()
        .commands(this.trackCommands())
        .stroke($r('app.color.gray_3a3a40'))
        .strokeWidth(dimens.u(13))
        .strokeLineCap(LineCapStyle.Round)
        .fill(Color.Transparent)

      Path()
        .commands(this.highlightCommands())
        .stroke($r('app.color.green'))
        .strokeWidth(dimens.u(14))
        .strokeLineCap(LineCapStyle.Round)
        .fill(Color.Transparent)
        .opacity(this.isFirstUse() ? 0.4 : 1)

      Circle()
        .width(dimens.u(14))
        .height(dimens.u(14))
        .fill(this.markerColor())
        .position({
          x: this.sx(this.markerPoint().x) - dimens.u(7),
          y: this.sy(this.markerPoint().y) - dimens.u(7)
        })
    }
    .width(dimens.cqw(70))
    .height(dimens.cqw(17))
  }

  @Builder
  rangeBody() {
    Column({ space: dimens.cqw(1.4) }) {
      Text(this.isFirstUse() ? $r('app.string.extra_range_general_compact') : $r('app.string.extra_range_normal_compact'))
        .fontSize(dimens.u(DesignTokens.rangeHeroValue))
        .fontColor($r('app.color.text_primary'))
        .fontWeight(FontWeight.Bold)
        .maxLines(1)

      this.curvedBar()

      Column({ space: dimens.u(DesignTokens.monitorGapSmallBase) }) {
        if (this.isFirstUse()) {
          Text($r('app.string.range_learning'))
            .fontSize(dimens.u(DesignTokens.fsLabel))
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
          Text($r('app.string.range_days_left'))
            .fontSize(dimens.u(DesignTokens.fsMin))
            .fontColor($r('app.color.muted'))
            .maxLines(1)
        } else {
          Text($r('app.string.extra_range_current_short', appStore.bpm))
            .fontSize(dimens.u(DesignTokens.fsBody))
            .fontColor(this.markerColor())
            .maxLines(1)
          Text($r('app.string.extra_range_resting_short'))
            .fontSize(dimens.u(DesignTokens.fsMin))
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
          Text($r('app.string.extra_range_learned_short'))
            .fontSize(dimens.u(DesignTokens.fsMin))
            .fontColor($r('app.color.muted'))
            .maxLines(1)
        }
      }
      .width(dimens.cqw(76))
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    ScreenScaffold({
      headerHeightBase: DesignTokens.scaffoldHeaderBase,
      logTag: 'RangePage',
      headerContent: (): void => {
        this.rangeHeader();
      },
      bodyContent: (): void => {
        this.rangeBody();
      }
    })
  }
}
