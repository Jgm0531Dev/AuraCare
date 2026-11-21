import { PageHeader } from '../components/PageHeader';
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
    PageHeader({ title: $r('app.string.page_medical'), icon: $r('app.string.icon_check') })
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
        .wordBreak(WordBreak.BREAK_ALL)
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
      Text($r('app.string.icon_smartphone'))
        .fontSize(dimens.cqw(6.5))
        .fontColor($r('app.color.text_primary'))
        .width(dimens.cqw(12))
        .height(dimens.cqw(12))
        .borderRadius(dimens.cqw(6))
        .backgroundColor($r('app.color.card'))
        .textAlign(TextAlign.Center)

      Text($r('app.string.medical_empty_title'))
        .fontSize(dimens.u(DesignTokens.fsLabel))
        .fontColor($r('app.color.text_primary'))
        .fontWeight(FontWeight.Bold)
        .textAlign(TextAlign.Center)
        .maxLines(2)

      Text($r('app.string.medical_empty_desc'))
        .fontSize(dimens.u(DesignTokens.fsMin))
        .fontColor($r('app.color.muted'))
        .wordBreak(WordBreak.BREAK_ALL)
        .textAlign(TextAlign.Center)
        .maxLines(6)
    }
    .width('100%')
    .constraintSize({ minHeight: '100%' })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  medicalBody() {
    Scroll() {
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
