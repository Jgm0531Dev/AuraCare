import { UIContext } from '@kit.ArkUI';
import { DesignTokens } from './DesignTokens';
import { Logger } from './Logger';

import { DEBUG_LAYOUT as DEBUG_LAYOUT_FLAG } from './AppConfig';

/** Se controla desde util/AppConfig.ets (apagado siempre con RELEASE_MODE). */
export const DEBUG_LAYOUT: boolean = DEBUG_LAYOUT_FLAG;

/** Tamaño de la raíz en vp para la superposición opcional de depuración. */
export function debugRootSize(widthVp: number, heightVp: number): string {
  return `${widthVp.toFixed(0)}x${heightVp.toFixed(0)}`;
}

const TAG: string = 'Dimens';
const BASE_SIZE: number = DesignTokens.base;
const SCALE_FALLBACK: number = 0.5;

export class Dimens {
  readonly base: number = BASE_SIZE;
  rootWidthVp: number = 0;
  rootHeightVp: number = 0;
  scale: number = SCALE_FALLBACK;
  private uiContext: UIContext | undefined = undefined;

  init(context: UIContext): void {
    this.uiContext = context;
  }

  /** Escala única: ancho real del contenedor raíz (vp) / 466. */
  updateFromRoot(area: Area): void {
    const width: number = Number(area.width);
    this.rootWidthVp = width;
    this.rootHeightVp = Number(area.height);
    if (!Number.isFinite(width) || width <= 0) {
      this.scale = SCALE_FALLBACK;
      Logger.warn(TAG, `anchoRaízVp inválido=${area.width}; escala de respaldo=${SCALE_FALLBACK}`);
      return;
    }
    const next: number = width / this.base;
    if (Math.abs(next - this.scale) > 0.001) {
      this.scale = next;
    }
    if (DEBUG_LAYOUT) {
      Logger.info(TAG,
        `anchoRaízVp=${width} altoRaízVp=${this.rootHeightVp} escala=${this.scale} contexto=${this.uiContext !== undefined}`);
      Logger.info(TAG,
        `headerWidthVp=${this.headerWidth()} fsSubtitleVp=${this.u(DesignTokens.fsSubtitle)} fsMinVp=${this.u(DesignTokens.fsMin)}`);
    }
  }

  logArea(tag: string, name: string, area: Area): void {
    if (!DEBUG_LAYOUT) {
      return;
    }
    Logger.info(tag,
      `${name} areaVp=${area.width}x${area.height} pos=${JSON.stringify(area.position)} global=${JSON.stringify(area.globalPosition)} escala=${this.scale}`);
  }

  /** Factor único para toda medida, incluida la tipografía. */
  u(baseValue: number): number {
    return baseValue * this.scale;
  }

  vp(baseValue: number): number {
    return this.u(baseValue);
  }

  cqw(valueInCqw: number): number {
    return this.vp(valueInCqw * BASE_SIZE / 100);
  }

  percent(valueInPercent: number): number {
    return this.vp(BASE_SIZE * valueInPercent / 100);
  }

  watchSize(): number {
    return this.vp(BASE_SIZE);
  }

  safeTop(): number {
    return this.percent(DesignTokens.safeBlockPercent);
  }

  safeBottom(): number {
    return this.percent(DesignTokens.safeBlockPercent);
  }

  safeLeft(): number {
    return this.percent(DesignTokens.safeInlinePercent);
  }

  safeRight(): number {
    return this.percent(DesignTokens.safeInlinePercent);
  }

  touchMin(): number {
    return this.vp(DesignTokens.touchMin);
  }

  primaryButtonHeight(): number {
    return this.vp(DesignTokens.primaryButtonHeight);
  }

  thinBorder(): number {
    return this.vp(DesignTokens.thinBorder);
  }

  headerWidth(): number {
    return this.cqw(DesignTokens.headerWidthCqw);
  }

  headerMinHeight(): number {
    return this.cqw(DesignTokens.headerMinHeightCqw);
  }

  headerTitleWidth(): number {
    return this.vp(DesignTokens.headerTitleWidth);
  }

  headerIconSize(): number {
    return this.vp(DesignTokens.headerIconSize);
  }

  headerGap(): number {
    return this.cqw(DesignTokens.headerGapCqw);
  }

  backTop(): number {
    return this.percent(DesignTokens.backTopPercent);
  }

  backLeft(): number {
    return this.percent(DesignTokens.backLeftPercent);
  }

  scrollMaxHeight(): number {
    return this.cqw(DesignTokens.scrollMaxHeightCqw);
  }

  gradientEdge(): number {
    return this.vp(DesignTokens.gradientEdge);
  }

  radiusChip(): number {
    return this.cqw(DesignTokens.radiusChipCqw);
  }

  radiusCard(): number {
    return this.cqw(DesignTokens.radiusCardCqw);
  }

  radiusInfoCard(): number {
    return this.cqw(DesignTokens.radiusInfoCardCqw);
  }
}

export const dimens: Dimens = new Dimens();
