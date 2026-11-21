import { DesignTokens } from '../util/DesignTokens';
import { dimens } from '../util/Dimens';
import { Logger } from '../util/Logger';

const TAG: string = 'CountdownRing';

/**
 * Anillo de cuenta atrás en Canvas transparente: aro tenue de fondo y arco que se vacía en
 * sentido horario desde las 12. Sin fondo ni marcador (el Gauge anterior pintaba ambos).
 */
@ComponentV2
export struct CountdownRing {
  @Param value: number = 30;
  @Param total: number = 30;
  /** Arco y número en rojo (últimos 10 s de ¿Estás bien?, o Pidiendo ayuda completo). */
  @Param critical: boolean = false;
  private readonly settings: RenderingContextSettings = new RenderingContextSettings(true);
  private readonly context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private ready: boolean = false;

  @Monitor('value', 'total', 'critical')
  onRingChange(): void {
    this.draw();
  }

  private ringSize(): number {
    return dimens.u(DesignTokens.countdownRingBase);
  }

  /** Color de recurso como rgba() para Canvas (no admite Resource directamente). */
  private rgba(color: Resource): string {
    try {
      const argb: number = this.getUIContext().getHostContext()!.resourceManager.getColorSync(color.id);
      const a: number = ((argb >>> 24) & 0xff) / 255;
      const r: number = (argb >>> 16) & 0xff;
      const g: number = (argb >>> 8) & 0xff;
      const b: number = argb & 0xff;
      return `rgba(${r},${g},${b},${a.toFixed(3)})`;
    } catch (err) {
      Logger.error(TAG, 'color de recurso no resuelto', err as Object);
      return 'rgba(255,255,255,1)';
    }
  }

  private arcColor(): Resource {
    return this.critical ? $r('app.color.red') : $r('app.color.text_primary');
  }

  private draw(): void {
    if (!this.ready) {
      return;
    }
    const size: number = this.ringSize();
    const stroke: number = dimens.u(DesignTokens.countdownRingStrokeBase);
    const center: number = size / 2;
    const radius: number = (size - stroke) / 2;
    const ctx: CanvasRenderingContext2D = this.context;
    ctx.clearRect(0, 0, size, size);
    ctx.lineWidth = stroke;
    ctx.lineCap = 'round';

    ctx.beginPath();
    ctx.strokeStyle = this.rgba($r('app.color.ring_track'));
    ctx.arc(center, center, radius, 0, Math.PI * 2);
    ctx.stroke();

    const fraction: number = this.total > 0 ? Math.max(0, Math.min(1, this.value / this.total)) : 0;
    if (fraction <= 0) {
      return;
    }
    // Se vacía en sentido horario: el inicio avanza desde las 12 y el final queda fijo.
    const top: number = -Math.PI / 2;
    const start: number = top + (1 - fraction) * Math.PI * 2;
    ctx.beginPath();
    ctx.strokeStyle = this.rgba(this.arcColor());
    ctx.arc(center, center, radius, start, top + Math.PI * 2);
    ctx.stroke();
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Canvas(this.context)
        .width(this.ringSize())
        .height(this.ringSize())
        .backgroundColor($r('app.color.transparent'))
        .onReady((): void => {
          this.ready = true;
          this.draw();
        })

      Text(`${this.value}`)
        .fontSize(dimens.u(DesignTokens.countdownNumberBase))
        .fontColor(this.arcColor())
        .fontWeight(FontWeight.Bold)
        .maxLines(1)
    }
    .width(this.ringSize())
    .height(this.ringSize())
  }
}
