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
  // Mínimo global: ningún texto baja de 26 unidades base (AGENTS.md).
  static readonly fsBody: number = 26;
  static readonly fsLabel: number = 26;
  static readonly fsMin: number = 26;
  static readonly bpmThreeDigit: number = 63.842;
  static readonly spo2PercentageNumber: number = 63.842;
  static readonly spo2PercentageThree: number = 55.92;
  static readonly countdownNumber: number = 65.24;
  static readonly countdownUnit: number = 26;
  static readonly rangeHeroValue: number = 62.444;
  static readonly rangeCurrentBadge: number = 26;
  static readonly sensorValue: number = 28.892;
  static readonly sensorValueText: number = 26;
  static readonly sensorValueUnavailable: number = 26;
  static readonly sensorValuePermission: number = 26;
  static readonly sensorStatePill: number = 26;
  static readonly sensorStatePillPermission: number = 26;
  static readonly sensorsUnavailableLabel: number = 26;
  static readonly watchOfflinePill: number = 26;
  static readonly watchToastCancelled: number = 26;
  static readonly contactAvatarBubble: number = 26;
  static readonly medicalRowValue: number = 26;
  static readonly settingCycleBadge: number = 26;
  static readonly alertDialogTitle: number = 27.96;
  static readonly areYouOkHeader: number = 27.96;
  static readonly alertSentHeader: number = 26;
  static readonly alertContentGapCqw: number = 2;
  static readonly alertCardWidthCqw: number = 70;
  static readonly alertContactAvatarCqw: number = 9;
  static readonly alertContactRowMinHeightCqw: number = 8;
  static readonly alertHeaderIconSize: number = 32;
  static readonly alertDialogIconCqw: number = 12;
  static readonly alertDialogGlyphCqw: number = 6.5;

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
  // Mínimo global: toda área táctil mide al menos 72 unidades base (AGENTS.md).
  static readonly touchMin: number = 72;
  static readonly primaryButtonHeight: number = 72;
  static readonly primaryButtonWidthPercent: number = 70;
  static readonly ringSizeCqw: number = 34;
  static readonly ringStrokeWidth: number = 8;
  static readonly countdownButtonGap: number = 8;
  static readonly countdownReasonMarginBottom: number = 12;
  static readonly countdownHaloSizeCqw: number = 92;
  static readonly sosRingSizeCqw: number = 38;
  static readonly sosRingStroke: number = 2.5;
  static readonly demoGapCqw: number = 1.6;
  static readonly demoSectionGapCqw: number = 2.8;
  static readonly demoButtonHeightCqw: number = 10;
  static readonly demoButtonRadiusCqw: number = 3;
  static readonly demoBadgeHeightBase: number = 30;
  static readonly demoBadgePaddingBase: number = 8;
  static readonly demoBadgeHitWidthBase: number = 100;
  static readonly demoBadgeHitExpandXBase: number = 8;
  static readonly demoBadgeHitExpandYBase: number = 21;

  // ScreenScaffold (base 466): cabecera y pie de alto fijo, cuerpo recortado.
  static readonly scaffoldHeaderBase: number = 40;
  static readonly scaffoldFooterBase: number = 72;

  // Monitor (base 466). Con safe 11% arriba/abajo hay ≈363 base útiles.
  static readonly monitorUsableHeightBase: number = 363;
  static readonly monitorSafeBlockPercent: number = 11;
  static readonly monitorContentWidthBase: number = 320;
  static readonly monitorLiveRowWidthBase: number = 300;
  static readonly monitorChipsWidthPercent: number = 82;
  static readonly monitorLiveRowBase: number = 26;
  static readonly monitorArcBase: number = 160;
  static readonly monitorArcMinBase: number = 150;
  static readonly monitorArcStrokeBase: number = 12;
  static readonly monitorStatusRowBase: number = 26;
  static readonly monitorChipRowBase: number = 44;
  static readonly monitorActionsBase: number = 72;
  static readonly monitorGapSmallBase: number = 6;
  static readonly monitorGapLargeBase: number = 8;
  static readonly monitorChipsGapBase: number = 12;
  static readonly monitorActionsGapBase: number = 12;
  static readonly bpmTwoDigitBase: number = 60;
  static readonly bpmThreeDigitBase: number = 52;
  static readonly liveDotBase: number = 9;
  static readonly sosButtonWidthBase: number = 190;
  static readonly sosRingSizeBase: number = 72;
  static readonly sosLabelBase: number = 32;
  static readonly contactsButtonBase: number = 72;
  static readonly usersIconGapBase: number = 2;
  static readonly usersIconHeadBase: number = 8;
  static readonly usersIconBodyWidthBase: number = 12;
  static readonly usersIconBodyHeightBase: number = 7;
  static readonly usersIconRadiusBase: number = 4;
  static readonly chipHeightBase: number = 44;
  static readonly chipPaddingBase: number = 6;
  static readonly chipGapBase: number = 6;

  // Contactos (base 466): filas fijas de 96 y lista con scroll.
  static readonly contactsRowHeightBase: number = 96;
  static readonly contactsAvatarBase: number = 56;
  static readonly contactsRowGapBase: number = 12;
  static readonly contactsRowPaddingBase: number = 12;
  static readonly contactsListGapBase: number = 4;
  static readonly contactsFooterBottomBase: number = 12;
  static readonly contactsFooterGapBase: number = 8;
  static readonly phoneIconBase: number = 34;
  static readonly plusGlyphBase: number = 40;

  // Paleta del arco Canvas: espejo de app.color.* (Canvas exige cadenas, no Resource).
  static readonly arcBlue: string = '#32ADE6';
  static readonly arcGreen: string = '#34C759';
  static readonly arcOrange: string = '#FF9500';
  static readonly arcRed: string = '#FF3B30';
  static readonly arcMuted: string = '#8E8E93';
  static readonly arcMarker: string = '#FFFFFF';
  static readonly iconWhite: string = '#FFFFFF';
  static readonly toastTopCqw: number = 11;

  // Radios y bordes.
  static readonly thinBorder: number = 1;
  static readonly radiusChipCqw: number = 3.6;
  static readonly radiusCardCqw: number = 4;
  static readonly radiusInfoCardCqw: number = 4.2;
  static readonly radiusSensorCardCqw: number = 4.6;
}
