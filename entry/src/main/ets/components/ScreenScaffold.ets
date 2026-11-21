import { dimens } from '../util/Dimens';
import { DesignTokens } from '../util/DesignTokens';

/**
 * Estructura común de todas las pantallas: cabecera opcional de alto fijo,
 * cuerpo con layoutWeight(1) y clip, y pie opcional de alto fijo.
 * La zona segura se aplica una sola vez desde Dimens.
 */
@ComponentV2
export struct ScreenScaffold {
  @Param headerHeightBase: number = 0;
  @Param footerHeightBase: number = 0;
  @Param logTag: string = 'ScreenScaffold';
  @Param scaffoldBackground: Resource = $r('app.color.watch_background');
  @Param safeTopPercent: number = DesignTokens.safeBlockPercent;
  @Param safeBottomPercent: number = DesignTokens.safeBlockPercent;
  @Event onBodyArea: (heightVp: number) => void = () => {};

  @Builder
  emptyBuilder(): void {}

  @BuilderParam headerContent: () => void = this.emptyBuilder;
  @BuilderParam bodyContent: () => void = this.emptyBuilder;
  @BuilderParam footerContent: () => void = this.emptyBuilder;

  build() {
    Column() {
      if (this.headerHeightBase > 0) {
        Column() {
          this.headerContent()
        }
        .width('100%')
        .height(dimens.u(this.headerHeightBase))
        .flexShrink(0)
        .onAreaChange((_oldValue: Area, newValue: Area): void => {
          dimens.logArea(this.logTag, 'Header', newValue);
        })
      }

      Stack({ alignContent: Alignment.TopStart }) {
        this.bodyContent()
      }
      .width('100%')
      .layoutWeight(1)
      .clip(true)
      .onAreaChange((_oldValue: Area, newValue: Area): void => {
        dimens.logArea(this.logTag, 'Body', newValue);
        this.onBodyArea(Number(newValue.height));
      })

      if (this.footerHeightBase > 0) {
        Column() {
          this.footerContent()
        }
        .width('100%')
        .height(dimens.u(this.footerHeightBase))
        .flexShrink(0)
        .onAreaChange((_oldValue: Area, newValue: Area): void => {
          dimens.logArea(this.logTag, 'Footer', newValue);
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.scaffoldBackground)
    .padding({
      top: dimens.percent(this.safeTopPercent), bottom: dimens.percent(this.safeBottomPercent),
      left: dimens.safeLeft(), right: dimens.safeRight()
    })
    .onAreaChange((_oldValue: Area, newValue: Area): void => {
      dimens.logArea(this.logTag, 'Root', newValue);
    })
  }
}
