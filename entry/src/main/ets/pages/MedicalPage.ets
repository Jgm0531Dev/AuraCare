import { ExtraPageHeader } from '../components/ExtraPageHeader';
import { ScreenScaffold } from '../components/ScreenScaffold';
import { extraDemoState } from '../state/AppStore';
import { DesignTokens } from '../util/DesignTokens';
import { dimens } from '../util/Dimens';

// REGISTRAR: Index.ets -> ArcSwiper() ya contiene MedicalPage() como cuarta página; no añadir nada.

class MedicalRow {
  label: Resource;
  icon: Resource;
  value: Resource;
  highlight: boolean;

  constructor(label: Resource, icon: Resource, value: Resource, highlight: boolean = false) {
    this.label = label;
    this.icon = icon;
    this.value = value;
    this.highlight = highlight;
  }
}

const MEDICAL_ROWS: MedicalRow[] = [
  new MedicalRow($r('app.string.blood_type'), $r('app.string.icon_heart'), $r('app.string.blood_o_positive'), true),
  new MedicalRow($r('app.string.allergies'), $r('app.string.icon_warning'), $r('app.string.allergies_value')),
  new MedicalRow($r('app.string.medications'), $r('app.string.icon_plus'), $r('app.string.medications_value')),
  new MedicalRow($r('app.string.conditions'), $r('app.string.icon_check'), $r('app.string.conditions_value'))
];

@ComponentV2
export struct MedicalPage {
  @Builder
  medicalHeader() {
    ExtraPageHeader({
      title: $r('app.string.page_medical'),
      symbol: $r('sys.symbol.cross_square_fill')
    })
  }

  @Builder
  medicalCard(row: MedicalRow) {
    Column({ space: dimens.u(DesignTokens.monitorGapSmallBase) }) {
      Row({ space: dimens.cqw(1.2) }) {
        Text(row.icon)
          .fontSize(dimens.u(DesignTokens.fsMin))
          .fontColor($r('app.color.accion_principal'))
          .maxLines(1)
        Text(row.label)
          .fontSize(dimens.u(DesignTokens.fsMin))
          .fontColor($r('app.color.muted'))
          .maxLines(1)
      }
      .width('100%')

      Text(row.value)
        .fontSize(dimens.u(DesignTokens.fsBody))
        .fontColor(row.highlight ? $r('app.color.text_primary') : $r('app.color.gray_e5e5ea'))
        .fontWeight(row.highlight ? FontWeight.Bold : FontWeight.Normal)
        .wordBreak(WordBreak.NORMAL)
        .maxLines(2)
        .width('100%')
    }
    .width('100%')
    .constraintSize({ minHeight: dimens.cqw(16) })
    .padding({
      top: dimens.cqw(2.4), bottom: dimens.cqw(2.4),
      left: dimens.cqw(3.6), right: dimens.cqw(3.6)
    })
    .backgroundColor($r('app.color.card'))
    .border({ width: dimens.thinBorder(), color: $r('app.color.border') })
    .borderRadius(dimens.radiusCard())
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  medicalEmpty() {
    Column({ space: dimens.cqw(2) }) {
      Stack() {
        Circle()
          .width(dimens.cqw(12))
          .height(dimens.cqw(12))
          .fill($r('app.color.card'))

        SymbolGlyph($r('sys.symbol.cross_square_fill'))
          .fontSize(dimens.cqw(6.5))
          .fontWeight(FontWeight.Medium)
          .renderingStrategy(SymbolRenderingStrategy.SINGLE)
          .fontColor([$r('app.color.text_primary')])
      }
      .width(dimens.cqw(12))
      .height(dimens.cqw(12))

      Text($r('app.string.medical_empty_title'))
        .fontSize(dimens.u(DesignTokens.fsLabel))
        .fontColor($r('app.color.text_primary'))
        .fontWeight(FontWeight.Bold)
        .textAlign(TextAlign.Center)
        .maxLines(2)

      Text($r('app.string.extra_medical_empty_desc_short'))
        .fontSize(dimens.u(DesignTokens.fsMin))
        .fontColor($r('app.color.muted'))
        .wordBreak(WordBreak.NORMAL)
        .textAlign(TextAlign.Center)
        .width(dimens.cqw(76))
        .margin({ right: dimens.cqw(3) })
        .maxLines(2)
    }
    .width('100%')
    .constraintSize({ minHeight: '100%' })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  medicalBody() {
    Scroll() {
      Column() {
        if (extraDemoState.medicalSample) {
          Column({ space: dimens.cqw(1.8) }) {
            ForEach(MEDICAL_ROWS, (row: MedicalRow): void => {
              this.medicalCard(row)
            })
          }
          .width('100%')
          .padding({ top: dimens.cqw(2.4), bottom: dimens.cqw(2.4) })
        } else {
          this.medicalEmpty()
        }
      }
      .width(dimens.cqw(76))
      .margin({ right: dimens.cqw(3) })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.None)
    .nestedScroll({
      scrollForward: NestedScrollMode.SELF_FIRST,
      scrollBackward: NestedScrollMode.SELF_FIRST
    })
  }

  build() {
    ScreenScaffold({
      headerHeightBase: DesignTokens.scaffoldHeaderBase,
      logTag: 'MedicalPage',
      headerContent: (): void => {
        this.medicalHeader();
      },
      bodyContent: (): void => {
        this.medicalBody();
      }
    })
  }
}
