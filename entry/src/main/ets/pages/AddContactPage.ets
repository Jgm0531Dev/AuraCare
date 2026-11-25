import { DesignTokens } from '../util/DesignTokens';
import { dimens } from '../util/Dimens';
import { Logger } from '../util/Logger';
import { emergencyService } from '../service/EmergencyService';
import { ScreenScaffold } from '../components/ScreenScaffold';
import { DemoChoiceButton } from '../components/DemoChoiceButton';
import { appStore, DialogKind } from '../state/AppStore';
import { EmergencyContact } from '../model/EmergencyContact';
import { contactPickerService, PickedContact } from '../service/ContactPickerService';

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
  /** Id del contacto en edición; vacío = alta nueva. */
  @Local editingId: string = '';
  @Local pickerAvailable: boolean = false;
  @Local pickerFailed: boolean = false;
  private readonly relations: Resource[] = [
    $r('app.string.relation_mama'), $r('app.string.relation_papa'), $r('app.string.relation_pareja'),
    $r('app.string.relation_hijo'), $r('app.string.relation_hermano'), $r('app.string.relation_amigo'),
    $r('app.string.relation_medico')
  ];

  aboutToAppear(): void {
    this.pickerAvailable = contactPickerService.isAvailable();
    const id: string = appStore.editingContactId;
    if (id.length === 0) {
      return;
    }
    const found: EmergencyContact | undefined =
      appStore.contacts.find((item: EmergencyContact): boolean => item.id === id);
    if (found !== undefined) {
      this.editingId = id;
      this.relation = found.name;
      this.digits = found.phone ?? '';
    }
  }

  private isEditing(): boolean {
    return this.editingId.length > 0;
  }

  /** Picker del sistema: el resultado pasa por el mismo teclado y la misma validación. */
  private pickFromContacts(): void {
    this.pickerFailed = false;
    contactPickerService.pick().then((picked: PickedContact | undefined): void => {
      if (picked === undefined) {
        this.pickerFailed = true;
        return;
      }
      this.relation = picked.name.length > 0 ? picked.name : this.relation;
      this.digits = picked.phone.substring(0, DesignTokens.phoneMaxDigits);
      this.step = 2;
    }).catch((err: Object): void => {
      this.pickerFailed = true;
      Logger.error(TAG, 'pickFromContacts falló', err);
    });
  }

  private removeEditing(): void {
    const id: string = this.editingId;
    const name: string = this.relation;
    this.onDone();
    emergencyService.openDialog(DialogKind.RemoveContact, id, name);
  }

  private canSave(): boolean {
    return this.digits.length >= DesignTokens.phoneMinDigits;
  }

  private pickRelation(label: Resource): void {
    try {
      this.relation = this.getUIContext().getHostContext()!.resourceManager.getStringSync(label.id);
      if (!this.isEditing()) {
        this.digits = '';
      }
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
    const saved: boolean = this.isEditing() ?
      emergencyService.updateUserContact(this.editingId, this.relation, this.digits) :
      emergencyService.addUserContact(this.relation, this.digits);
    if (saved) {
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
        Text(this.isEditing() ? $r('app.string.edit_contact_title') : $r('app.string.add_contact_title'))
          .fontSize(dimens.u(DesignTokens.fsBody))
          .fontColor($r('app.color.text_primary'))
          .fontWeight(FontWeight.Bold)
          .maxLines(1)
        if (this.isEditing()) {
          DemoChoiceButton({
            label: $r('app.string.edit_keep_name', this.relation),
            color: $r('app.color.green'),
            onPress: (): void => {
              this.step = 2;
            }
          })
        } else if (this.pickerAvailable) {
          DemoChoiceButton({
            label: $r('app.string.pick_from_contacts'),
            color: $r('app.color.green'),
            onPress: (): void => {
              this.pickFromContacts();
            }
          })
          if (this.pickerFailed) {
            Text($r('app.string.pick_failed'))
              .fontSize(dimens.u(DesignTokens.fsMin))
              .fontColor($r('app.color.orange'))
              .maxLines(2)
              .textAlign(TextAlign.Center)
          }
        }
        ForEach(this.relations, (label: Resource): void => {
          DemoChoiceButton({
            label: label,
            color: $r('app.color.card'),
            onPress: (): void => {
              this.pickRelation(label);
            }
          })
        }, (label: Resource): string => `${label.id}`)
        if (this.isEditing()) {
          DemoChoiceButton({
            label: $r('app.string.remove_contact'),
            color: $r('app.color.red'),
            onPress: (): void => {
              this.removeEditing();
            }
          })
        }
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
