import { DesignTokens } from '../util/DesignTokens';
import { dimens } from '../util/Dimens';

// Auricular escalado a 24x24; se dibuja en Canvas para garantizar el color blanco.
const HANDSET_PATH: string =
  'M6.62 10.79a15.05 15.05 0 0 0 6.59 6.59l2.2-2.2a1 1 0 0 1 1.02-.24' +
  'c1.12.37 2.33.57 3.57.57a1 1 0 0 1 1 1V20a1 1 0 0 1-1 1' +
  'A17 17 0 0 1 3 4a1 1 0 0 1 1-1h3.5a1 1 0 0 1 1 1' +
  'c0 1.25.2 2.45.57 3.57a1 1 0 0 1-.25 1.02l-2.2 2.2z';

/** Icono de teléfono en blanco, dibujado para no depender del color del glifo. */
@ComponentV2
export struct PhoneIcon {
  @Param sizeBase: number = DesignTokens.phoneIconBase;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  private draw(): void {
    const size: number = dimens.u(this.sizeBase);
    this.ctx.clearRect(0, 0, size, size);
    this.ctx.save();
    this.ctx.scale(size / 24, size / 24);
    this.ctx.fillStyle = DesignTokens.iconWhite;
    this.ctx.fill(new Path2D(HANDSET_PATH));
    this.ctx.restore();
  }

  build() {
    Canvas(this.ctx)
      .width(dimens.u(this.sizeBase))
      .height(dimens.u(this.sizeBase))
      .onReady((): void => {
        this.draw();
      })
  }
}
