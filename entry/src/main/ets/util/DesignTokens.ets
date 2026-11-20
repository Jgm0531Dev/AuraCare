/**
 * Tokens de diseño sobre una base de 466 unidades (UI_SPEC.md).
 * Ninguna medida se usa directamente: siempre se aplica con Dimens.u().
 */
export class DesignTokens {
  static readonly base: number = 466;

  // Tipografía (antes en float.json, en fp).
  static readonly pageTextFontSize: number = 50;
  static readonly fsHero: number = 75.958;
  static readonly fsSubtitle: number = 27.028;
  static readonly fsBody: number = 22.601;
  static readonly fsLabel: number = 20.271;
  static readonly fsMin: number = 20;
  static readonly bpmThreeDigit: number = 63.842;
  static readonly spo2PercentageNumber: number = 63.842;
  static readonly spo2PercentageThree: number = 55.92;
  static readonly countdownNumber: number = 65.24;
  static readonly countdownUnit: number = 20;
  static readonly rangeHeroValue: number = 62.444;
  static readonly rangeCurrentBadge: number = 20.271;
  static readonly sensorValue: number = 28.892;
  static readonly sensorValueText: number = 18.64;
  static readonly sensorValueUnavailable: number = 22.368;
  static readonly sensorValuePermission: number = 17.708;
  static readonly sensorStatePill: number = 13.747;
  static readonly sensorStatePillPermission: number = 13.98;
  static readonly sensorsUnavailableLabel: number = 14.446;
  static readonly watchOfflinePill: number = 15.378;
  static readonly watchToastCancelled: number = 16.776;
  static readonly contactAvatarBubble: number = 17.708;
  static readonly medicalRowValue: number = 21.436;
  static readonly settingCycleBadge: number = 21.436;
  static readonly alertDialogTitle: number = 27.96;
  static readonly areYouOkHeader: number = 27.96;
  static readonly alertSentHeader: number = 24.232;

  // Espaciados y zona segura.
  static readonly safeBlockPercent: number = 14;
  static readonly safeInlinePercent: number = 9;
  static readonly pageGapCqw: number = 2.8;
  static readonly pageMarginTopCqw: number = 3;
  static readonly headerWidthCqw: number = 64;
  static readonly headerMinHeightCqw: number = 7.4;
  static readonly headerGapCqw: number = 1.8;
  static readonly headerIconSize: number = 32;
  static readonly headerTitleWidth: number = 260;
  static readonly backTopPercent: number = 15;
  static readonly backLeftPercent: number = 13;
  static readonly chipWidthPercent: number = 50;
  static readonly chipHeightCqw: number = 11.8;
  static readonly chipPaddingCqw: number = 3;
  static readonly chipValueGapCqw: number = 1;
  static readonly infoCardMinHeightCqw: number = 15.5;
  static readonly infoCardPaddingCqw: number = 3.6;
  static readonly scrollWidth74Cqw: number = 74;
  static readonly scrollWidth76Cqw: number = 76;
  static readonly scrollMaxHeightCqw: number = 63;
  static readonly gradientEdge: number = 24;
  static readonly touchMin: number = 48;
  static readonly primaryButtonHeight: number = 52;
  static readonly primaryButtonWidthPercent: number = 70;
  static readonly ringSizeCqw: number = 34;
  static readonly ringStrokeWidth: number = 8;

  // Radios y bordes.
  static readonly thinBorder: number = 1;
  static readonly radiusChipCqw: number = 3.6;
  static readonly radiusCardCqw: number = 4;
  static readonly radiusInfoCardCqw: number = 4.2;
  static readonly radiusSensorCardCqw: number = 4.6;
}
