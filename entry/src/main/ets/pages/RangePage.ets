import { ExtraPageHeader } from '../components/ExtraPageHeader';
import { ScreenScaffold } from '../components/ScreenScaffold';
import { appStore } from '../state/AppStore';
import { DesignTokens } from '../util/DesignTokens';
import { dimens } from '../util/Dimens';
import { Logger } from '../util/Logger';

// REGISTRAR: Index.ets -> ArcSwiper() ya contiene RangePage() como tercera página; no añadir nada.

class ArcPoint {
  x: number = 0;
  y: number = 0;
}

const TAG: string = 'RangePage';
/** Dominio único de la barra: 30-120 BPM -> 0-1 (58-92 queda centrado). */
const DOMAIN_MIN_BPM: number = 30;
const DOMAIN_MAX_BPM: number = 120;
const GENERAL_MIN_BPM: number = 60;
const GENERAL_MAX_BPM: number = 100;
/** Fuera del rango por menos de esto: naranja; por esto o más: rojo. */
const WARN_MARGIN_BPM: number = 20;
// Geometría en base 466 (todo pasa por dimens.u).
const BAR_WIDTH_BASE: number = 326;   // 70 % del reloj (mínimo pedido: 64 %)
const BAR_HEIGHT_BASE: number = 70;
const BAR_STROKE_BASE: number = 14;
const BAR_SAG_BASE: number = 34;      // profundidad de la "sonrisa"
const MARKER_BASE: number = 18;
const MARKER_BORDER_BASE: number = 2;
const HERO_BASE: number = 40;
const ARC_STEPS: number = 48;

/** ÚNICA conversión BPM -> fracción (tramo y marcador usan esta misma función). */
export function bpmToFraccion(bpm: number): number {
  const raw: number = (bpm - DOMAIN_MIN_BPM) / (DOMAIN_MAX_BPM - DOMAIN_MIN_BPM);
  return Math.max(0, Math.min(1, raw));
}

@ComponentV2
export struct RangePage {
  private readonly settings: RenderingContextSettings = new RenderingContextSettings(true);
  private readonly context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  aboutToAppear(): void {
    [50, 78, 92, 104, 120, 132].forEach((bpm: number): void => {
      Logger.info(TAG, `bpm=${bpm} fraccion=${bpmToFraccion(bpm).toFixed(3)}`);
    });
  }

  @Builder
  rangeHeader() {
    ExtraPageHeader({
      title: $r('app.string.page_range'),
      symbol: $r('sys.symbol.waveform_path_ecg_heart')
    })
  }

  /** v1.0.1: "aprendiendo" hasta reunir lecturas reales suficientes (RangeModel, persistido). */
  private isFirstUse(): boolean {
    return appStore.mode === 'first-use' || !appStore.rangeReady;
  }

  private rangeMin(): number {
    return this.isFirstUse() ? GENERAL_MIN_BPM : appStore.rangeMin;
  }

  private rangeMax(): number {
    return this.isFirstUse() ? GENERAL_MAX_BPM : appStore.rangeMax;
  }

  /** Minutos de lecturas reunidos (lecturas a 1 Hz). */
  private learnedMinutes(): number {
    return Math.floor(appStore.rangeSamples / 60);
  }

  /** ÚNICO punto sobre la curva (vp, origen arriba-izquierda del Canvas). Bezier cuadrática simétrica. */
  private puntoEnArco(fraccion: number): ArcPoint {
    const t: number = Math.max(0, Math.min(1, fraccion));
    const pad: number = dimens.u(MARKER_BASE / 2 + MARKER_BORDER_BASE);
    const x0: number = pad;
    const x2: number = dimens.u(BAR_WIDTH_BASE) - pad;
    const yEnds: number = pad;
    const yControl: number = pad + dimens.u(BAR_SAG_BASE) * 2;
    const point: ArcPoint = new ArcPoint();
    point.x = x0 + (x2 - x0) * t;   // control en el centro: x es lineal en t
    point.y = (1 - t) * (1 - t) * yEnds + 2 * (1 - t) * t * yControl + t * t * yEnds;
    return point;
  }

  private stateColor(): Resource {
    if (this.isFirstUse() || !appStore.heartRateValid) {
      return $r('app.color.muted');
    }
    const bpm: number = appStore.bpm;
    const distance: number = bpm < this.rangeMin() ? this.rangeMin() - bpm :
      (bpm > this.rangeMax() ? bpm - this.rangeMax() : 0);
    if (distance === 0) {
      return $r('app.color.green');
    }
    return distance < WARN_MARGIN_BPM ? $r('app.color.orange') : $r('app.color.red');
  }

  private rgba(color: Resource, alpha: number = 1): string {
    try {
      const argb: number = this.getUIContext().getHostContext()!.resourceManager.getColorSync(color.id);
      const a: number = (((argb >>> 24) & 0xff) / 255) * alpha;
      return `rgba(${(argb >>> 16) & 0xff},${(argb >>> 8) & 0xff},${argb & 0xff},${a.toFixed(3)})`;
    } catch (err) {
      Logger.error(TAG, 'color no resuelto', err as Object);
      return `rgba(255,255,255,${alpha})`;
    }
  }

  private strokeArc(from: number, to: number, color: string): void {
    const ctx: CanvasRenderingContext2D = this.context;
    ctx.beginPath();
    ctx.strokeStyle = color;
    ctx.lineWidth = dimens.u(BAR_STROKE_BASE);
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    const steps: number = Math.max(2, Math.ceil(ARC_STEPS * (to - from)));
    for (let i = 0; i <= steps; i++) {
      const p: ArcPoint = this.puntoEnArco(from + (to - from) * i / steps);
      if (i === 0) {
        ctx.moveTo(p.x, p.y);
      } else {
        ctx.lineTo(p.x, p.y);
      }
    }
    ctx.stroke();
  }

  /** Aro, tramo y marcador con la MISMA curva y la MISMA fracción. */
  private draw(): void {
    const ctx: CanvasRenderingContext2D = this.context;
    ctx.clearRect(0, 0, dimens.u(BAR_WIDTH_BASE), dimens.u(BAR_HEIGHT_BASE));
    this.strokeArc(0, 1, this.rgba($r('app.color.gray_3a3a40')));
    this.strokeArc(bpmToFraccion(this.rangeMin()), bpmToFraccion(this.rangeMax()),
      this.rgba($r('app.color.green'), this.isFirstUse() ? 0.4 : 1));
    // Sin lectura de pulso no hay marcador.
    if (!appStore.heartRateValid) {
      return;
    }
    // Fuera del dominio, el clamp de bpmToFraccion deja el marcador en el extremo.
    const marker: ArcPoint = this.puntoEnArco(bpmToFraccion(appStore.bpm));
    ctx.beginPath();
    ctx.arc(marker.x, marker.y, dimens.u(MARKER_BASE / 2), 0, Math.PI * 2);
    ctx.fillStyle = this.rgba(this.stateColor());
    ctx.fill();
    ctx.lineWidth = dimens.u(MARKER_BORDER_BASE);
    ctx.strokeStyle = this.rgba($r('app.color.text_primary'));
    ctx.stroke();
  }

  /** Clave de redibujo: si cambia, el Canvas se recrea y onReady vuelve a dibujar (sin depender de @Monitor). */
  private drawKey(): string {
    return `${appStore.bpm}|${appStore.heartRateValid}|${this.isFirstUse()}|${appStore.rangeMin}|${appStore.rangeMax}|${dimens.scale}`;
  }

  @Builder
  curvedBar() {
    Stack() {
      ForEach([this.drawKey()], (key: string): void => {
        Canvas(this.context)
          .width(dimens.u(BAR_WIDTH_BASE))
          .height(dimens.u(BAR_HEIGHT_BASE))
          .backgroundColor($r('app.color.transparent'))
          .onReady((): void => {
            this.draw();
          })
      }, (key: string): string => key)
    }
    .width(dimens.u(BAR_WIDTH_BASE))
    .height(dimens.u(BAR_HEIGHT_BASE))
  }

  @Builder
  rangeBody() {
    // Presupuesto (base, cuerpo 296): héroe 46 + 8 + barra 70 + 8 + 3 x 30 + 2 x 6 = 234.
    Column({ space: dimens.u(8) }) {
      Text(this.isFirstUse() ? $r('app.string.extra_range_general_compact') :
        $r('app.string.range_personal_compact', appStore.rangeMin, appStore.rangeMax))
        .fontSize(dimens.u(HERO_BASE))
        .maxFontSize(dimens.u(HERO_BASE))
        .minFontSize(dimens.u(DesignTokens.fsBody))
        .fontColor($r('app.color.text_primary'))
        .fontWeight(FontWeight.Bold)
        .maxLines(1)
        .width('100%')
        .textAlign(TextAlign.Center)

      this.curvedBar()

      Column({ space: dimens.u(DesignTokens.monitorGapSmallBase) }) {
        if (this.isFirstUse()) {
          Text($r('app.string.range_learning'))
            .fontSize(dimens.u(DesignTokens.fsLabel))
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
          Text($r('app.string.range_learning_progress', this.learnedMinutes()))
            .fontSize(dimens.u(DesignTokens.fsMin))
            .fontColor($r('app.color.muted'))
            .maxLines(1)
        } else {
          Text(appStore.heartRateValid ? $r('app.string.extra_range_current_short', appStore.bpm) :
            $r('app.string.pulse_no_reading'))
            .fontSize(dimens.u(DesignTokens.fsBody))
            .fontColor(this.stateColor())
            .maxLines(1)
          Text($r('app.string.range_minutes_short', this.learnedMinutes()))
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
