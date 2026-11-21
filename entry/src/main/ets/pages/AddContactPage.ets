import { DesignTokens } from '../util/DesignTokens';
import { dimens } from '../util/Dimens';
import { Logger } from '../util/Logger';
import { emergencyService } from '../service/EmergencyService';
import { ScreenScaffold } from '../components/ScreenScaffold';
import { DemoChoiceButton } from '../components/DemoChoiceButton';

const TAG: string = 'AddContactPage';
const DIGIT_ROWS: string[][] = [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9']];

/**
 * Alta de contacto propia, sin teclado de texto (ruta 'addContact').
 * Paso 1: relación (es el nombre mostrado). Paso 2: teclado numérico 3 x 4, mínimo 10 dígitos.
 */
@ComponentV2
export struct AddContactPage {
  @Event onDone: () => void = () => {};
  @Local step: number = 1;
  @Local relation: string = '';
  @Local digits: string = '';
  private readonly relations: Resource[] = [
    $r('app.string.relation_mama'), $r('app.string.relation_papa'), $r('app.string.relation_pareja'),
    $r('app.string.relation_hijo'), $r('app.string.relation_hermano'), $r('app.string.relation_amigo'),
    $r('app.string.relation_medico')
  ];

  private canSave(): boolean {
    return this.digits.length >= DesignTokens.phoneMinDigits;
  }

  private pickRelation(label: Resource): void {
    try {
      this.relation = this.getUIContext().getHostContext()!.resourceManager.getStringSync(label.id);
      this.digits = '';
      this.step = 2;
    } catch (err) {
      Logger.error(TAG, 'no se pudo leer la relación', err as Object);
    }
  }

  private press(digit: string): void {
    if (this.digits.length < DesignTokens.phoneMaxDigits) {
      this.digits = this.digits + digit;
    }
  }

  private erase(): void {
    this.digits = this.digits.substring(0, Math.max(0, this.digits.length - 1));
  }

  private save(): void {
    if (!this.canSave()) {
      return;
    }
    if (emergencyService.addUserContact(this.relation, this.digits)) {
      this.onDone();
    }
  }

  private back(): void {
    if (this.step === 2) {
      this.step = 1;
      return;
    }
    this.onDone();
  }

  @Builder
  digitKey(label: string) {
    Button(label)
      .fontSize(dimens.u(DesignTokens.fsSubtitle))
      .fontColor($r('app.color.text_primary'))
      .width(dimens.u(DesignTokens.keypadKeyWidthBase))
      .height(dimens.u(DesignTokens.keypadKeyHeightBase))
      .borderRadius(dimens.u(DesignTokens.keypadKeyHeightBase / 2))
      .backgroundColor($r('app.color.card'))
      .onClick((): void => {
        this.press(label);
      })
  }

  @Builder
  relationStep() {
    Scroll() {
      Column({ space: dimens.u(DesignTokens.alertGapBase) }) {
        Text($r('app.string.add_contact_title'))
          .fontSize(dimens.u(DesignTokens.fsBody))
          .fontColor($r('app.color.text_primary'))
          .fontWeight(FontWeight.Bold)
          .maxLines(1)
        ForEach(this.relations, (label: Resource): void => {
          DemoChoiceButton({
            label: label,
            color: $r('app.color.card'),
            onPress: (): void => {
              this.pickRelation(label);
            }
          })
        }, (label: Resource): string => `${label.id}`)
        DemoChoiceButton({
          label: $r('app.string.cancel'),
          color: $r('app.color.surface_deep'),
          onPress: (): void => {
            this.onDone();
          }
        })
      }
      .width(dimens.percent(DesignTokens.primaryButtonWidthPercent))
      .alignItems(HorizontalAlign.Center)
      .padding({ bottom: dimens.touchMin() })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
  }

  /** Presupuesto: visor 36 + 4 filas x 72 + 3 x 4 = 336 base (zona útil). */
  @Builder
  keypadStep() {
    Column({ space: dimens.u(DesignTokens.keypadGapBase) }) {
      Text(this.digits.length > 0 ? this.digits : this.relation)
        .fontSize(dimens.u(DesignTokens.fsBody))
        .fontColor(this.canSave() ? $r('app.color.green') : $r('app.color.text_primary'))
        .fontWeight(FontWeight.Bold)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .height(dimens.u(DesignTokens.keypadDisplayBase))
        .accessibilityText($r('app.string.phone_min_hint'))

      ForEach(DIGIT_ROWS, (row: string[]): void => {
        Row({ space: dimens.u(DesignTokens.keypadGapBase) }) {
          ForEach(row, (digit: string): void => {
            this.digitKey(digit)
          }, (digit: string): string => digit)
        }
      }, (row: string[]): string => row.join(''))

      Row({ space: dimens.u(DesignTokens.keypadGapBase) }) {
        Button($r('app.string.key_delete'))
          .fontSize(dimens.u(DesignTokens.fsSubtitle))
          .fontColor($r('app.color.text_primary'))
          .width(dimens.u(DesignTokens.keypadKeyWidthBase))
          .height(dimens.u(DesignTokens.keypadKeyHeightBase))
          .borderRadius(dimens.u(DesignTokens.keypadKeyHeightBase / 2))
          .backgroundColor($r('app.color.surface_deep'))
          .accessibilityText($r('app.string.a11y_key_delete'))
          .onClick((): void => {
            this.erase();
          })
        this.digitKey('0')
        // Guardar: color reactivo (inline, no @Builder) y bloqueado con < 10 dígitos.
        Button($r('app.string.key_save'))
          .fontSize(dimens.u(DesignTokens.fsSubtitle))
          .fontColor($r('app.color.text_primary'))
          .width(dimens.u(DesignTokens.keypadKeyWidthBase))
          .height(dimens.u(DesignTokens.keypadKeyHeightBase))
          .borderRadius(dimens.u(DesignTokens.keypadKeyHeightBase / 2))
          .backgroundColor(this.canSave() ? $r('app.color.green') : $r('app.color.gray_636366'))
          .enabled(this.canSave())
          .accessibilityText($r('app.string.a11y_key_save'))
          .onClick((): void => {
            this.save();
          })
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  stepBody() {
    if (this.step === 1) {
      this.relationStep();
    } else {
      this.keypadStep();
    }
  }

  build() {
    NavDestination() {
      ScreenScaffold({
        logTag: 'AddContactPage',
        bodyContent: (): void => {
          this.stepBody();
        }
      })
    }
    .hideTitleBar(true)
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.watch_background'))
    .onBackPressed((): boolean => {
      this.back();
      return true;
    })
  }
}
