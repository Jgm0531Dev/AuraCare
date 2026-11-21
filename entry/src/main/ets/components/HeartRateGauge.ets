import { PulseState } from '../model/PulseState';
import { DesignTokens } from '../util/DesignTokens';
import { dimens } from '../util/Dimens';

const ARC_START_DEG: number = 135;
const ARC_SWEEP_DEG: number = 270;
const GAP_DEG: number = 4;
const SEGMENT_WEIGHTS: number[] = [0.15, 0.30, 0.30, 0.25];
const MIN_BPM: number = 40;
const MAX_BPM: number = 180;

/** Arco de 270° dibujado en Canvas: cuatro segmentos y marcador según BPM. */
@ComponentV2
export struct HeartRateGauge {
  @Param bpm: number = 78;
  @Param state: PulseState = PulseState.Normal;
  @Param firstUse: boolean = false;
  @Param sizeBase: number = DesignTokens.monitorArcBase;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  @Monitor('bpm', 'state', 'firstUse', 'sizeBase')
  onDataChange(): void {
    this.draw();
  }

  private segmentColor(index: number): string {
    if (index === 0) {
      return DesignTokens.arcBlue;
    }
    if (index === 1) {
      return DesignTokens.arcGreen;
    }
    if (index === 2) {
      return DesignTokens.arcOrange;
    }
    return DesignTokens.arcRed;
  }

  private stateColor(): string {
    if (this.firstUse) {
      return DesignTokens.arcMuted;
    }
    if (this.state === PulseState.Critical) {
      return DesignTokens.arcRed;
    }
    if (this.state === PulseState.Elevated) {
      return DesignTokens.arcOrange;
    }
    return DesignTokens.arcGreen;
  }

  private draw(): void {
    const size: number = dimens.u(this.sizeBase);
    const stroke: number = dimens.u(DesignTokens.monitorArcStrokeBase);
    const radius: number = (size - stroke) / 2;
    const center: number = size / 2;
    const start: number = ARC_START_DEG * Math.PI / 180;
    const sweep: number = ARC_SWEEP_DEG * Math.PI / 180;
    const gap: number = GAP_DEG * Math.PI / 180;
    this.ctx.clearRect(0, 0, size, size);
    this.ctx.lineWidth = stroke;
    this.ctx.lineCap = 'round';
    this.ctx.shadowBlur = 0;

    let cursor: number = 0;
    for (let index: number = 0; index < SEGMENT_WEIGHTS.length; index++) {
      const span: number = sweep * SEGMENT_WEIGHTS[index];
      const from: number = start + cursor + (index > 0 ? gap / 2 : 0);
      const to: number = start + cursor + span - (index < SEGMENT_WEIGHTS.length - 1 ? gap / 2 : 0);
      this.ctx.beginPath();
      this.ctx.strokeStyle = this.segmentColor(index);
      this.ctx.arc(center, center, radius, from, to);
      this.ctx.stroke();
      cursor += span;
    }

    this.ctx.beginPath();
    this.ctx.lineWidth = dimens.u(2);
    this.ctx.strokeStyle = this.stateColor();
    this.ctx.arc(center, center, radius - stroke / 2 - dimens.u(4), 0, Math.PI * 2);
    this.ctx.stroke();

    const ratio: number = Math.max(0, Math.min(1, (this.bpm - MIN_BPM) / (MAX_BPM - MIN_BPM)));
    const angle: number = start + ratio * sweep;
    const markerX: number = center + radius * Math.cos(angle);
    const markerY: number = center + radius * Math.sin(angle);
    this.ctx.shadowColor = DesignTokens.arcMarker;
    this.ctx.shadowBlur = dimens.u(6);
    this.ctx.beginPath();
    this.ctx.fillStyle = DesignTokens.arcMarker;
    this.ctx.arc(markerX, markerY, dimens.u(5), 0, Math.PI * 2);
    this.ctx.fill();
    this.ctx.shadowBlur = 0;
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Canvas(this.ctx)
        .width(dimens.u(this.sizeBase))
        .height(dimens.u(this.sizeBase))
        .onReady((): void => {
          this.draw();
        })

      Column({ space: 0 }) {
        Text(this.firstUse ? $r('app.string.value_dash') : `${this.bpm}`)
          .fontSize(dimens.u(this.bpm >= 100 ? DesignTokens.bpmThreeDigitBase : DesignTokens.bpmTwoDigitBase))
          .fontColor(this.firstUse ? $r('app.color.muted') : $r('app.color.text_primary'))
          .fontWeight(FontWeight.Bold)
          .maxLines(1)
        Text($r('app.string.bpm'))
          .fontSize(dimens.u(DesignTokens.fsMin))
          .fontColor($r('app.color.muted'))
          .maxLines(1)
      }
    }
    .width(dimens.u(this.sizeBase))
    .height(dimens.u(this.sizeBase))
  }
}
