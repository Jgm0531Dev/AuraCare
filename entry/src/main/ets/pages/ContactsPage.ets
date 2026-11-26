import { PageHeader } from '../components/PageHeader';
import { PhoneIcon } from '../components/PhoneIcon';
import { ScreenScaffold } from '../components/ScreenScaffold';
import { EmergencyContact } from '../model/EmergencyContact';
import { DialogKind, appStore } from '../state/AppStore';
import { emergencyService } from '../service/EmergencyService';
import { isUserContact } from '../service/ContactRepository';
import { DesignTokens } from '../util/DesignTokens';
import { DEBUG_LAYOUT, dimens } from '../util/Dimens';
import { Logger } from '../util/Logger';
import { crownNav } from '../util/CrownNav';

const TAG: string = 'ContactsPage';
const LONG_PRESS_MS: number = 600;
const EDGE_SWIPE_BASE: number = 40;
const DIRECTION_UP: number = 1;
const DIRECTION_DOWN: number = -1;

@ComponentV2
export struct ContactsPage {
  /** Página 4 del ArcSwiper: al salir de ella, su contenido vuelve arriba (sin animación). */
  private readonly scroller: Scroller = new Scroller();
  private unsubscribePage: () => void = (): void => {};
  private unregisterScroller: () => void = (): void => {};

  aboutToAppear(): void {
    // La corona (recibida por Index) desplaza esta lista cuando la página 4 está visible.
    this.unregisterScroller = crownNav.registerScroller(4, this.scroller);
    this.unsubscribePage = crownNav.onPageChanged((index: number): void => {
      if (index !== 4) {
        try {
          this.scroller.scrollTo({ xOffset: 0, yOffset: 0, animation: false });
        } catch (err) {
          // Sin lista montada (p. ej., Contactos vacío): no hay nada que desplazar.
        }
      }
    });
  }

  @Event onPageStep: (delta: number) => void = () => {};
  @Local listAtStart: boolean = true;
  @Local listAtEnd: boolean = true;
  private pressTimer: number | undefined = undefined;
  private touchStartX: number = 0;
  private touchStartY: number = 0;

  aboutToDisappear(): void {
    this.unsubscribePage();
    this.unregisterScroller();
    this.cancelPress();
  }

  private startPress(contact: EmergencyContact): void {
    this.cancelPress();
    this.pressTimer = setTimeout((): void => {
      this.pressTimer = undefined;
      // Contacto real: Editar (desde ahí también se puede borrar). Ejemplo: solo borrar.
      if (isUserContact(contact)) {
        emergencyService.requestEditContact(contact.id);
      } else {
        emergencyService.openDialog(DialogKind.RemoveContact, contact.id, contact.name);
      }
    }, LONG_PRESS_MS);
  }

  private cancelPress(): void {
    if (this.pressTimer !== undefined) {
      clearTimeout(this.pressTimer);
      this.pressTimer = undefined;
    }
  }

  /** ArcSwiper no expone nestedScroll en este SDK: al llegar al extremo cedemos el gesto. */
  private requestPageStep(delta: number): void {
    if (DEBUG_LAYOUT) {
      Logger.info(TAG,
        `listEdge: delta=${delta} atStart=${this.listAtStart} atEnd=${this.listAtEnd} overlayOpen=${appStore.dialogOpen}`);
    }
    this.onPageStep(delta);
  }

  private handleListTouch(event: TouchEvent): void {
    const touch: TouchObject | undefined = event.touches.length > 0 ? event.touches[0] : undefined;
    if (touch === undefined) {
      return;
    }
    if (event.type === TouchType.Down) {
      this.touchStartX = touch.x;
      this.touchStartY = touch.y;
      return;
    }
    if (event.type !== TouchType.Up) {
      return;
    }
    const deltaY: number = touch.y - this.touchStartY;
    const deltaX: number = touch.x - this.touchStartX;
    const threshold: number = dimens.u(EDGE_SWIPE_BASE);
    if (Math.abs(deltaY) < threshold || Math.abs(deltaY) < Math.abs(deltaX)) {
      return;
    }
    if (deltaY < 0 && this.listAtEnd) {
      this.requestPageStep(DIRECTION_UP);
    } else if (deltaY > 0 && this.listAtStart) {
      this.requestPageStep(DIRECTION_DOWN);
    }
  }

  @Builder
  contactHeader() {
    PageHeader({
      title: $r('app.string.page_contacts'),
      icon: $r('app.string.icon_users')
    })
  }

  @Builder
  contactRow(contact: EmergencyContact) {
    Row({ space: dimens.u(DesignTokens.contactsRowGapBase) }) {
      Text(contact.initials)
        .fontSize(dimens.u(DesignTokens.fsMin))
        .fontColor($r('app.color.text_primary'))
        .fontWeight(FontWeight.Bold)
        .width(dimens.u(DesignTokens.contactsAvatarBase))
        .height(dimens.u(DesignTokens.contactsAvatarBase))
        .borderRadius(dimens.u(DesignTokens.contactsAvatarBase / 2))
        .backgroundColor(contact.color)
        .textAlign(TextAlign.Center)
        .maxLines(1)

      Column({ space: 0 }) {
        Text(contact.name)
          .fontSize(dimens.u(DesignTokens.fsMin))
          .fontColor($r('app.color.text_primary'))
          .fontWeight(FontWeight.Bold)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(contact.role)
          .fontSize(dimens.u(DesignTokens.fsMin))
          .fontColor($r('app.color.muted'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Center)

      Button() {
        PhoneIcon()
      }
      .width(dimens.touchMin())
      .height(dimens.touchMin())
      .borderRadius(dimens.touchMin() / 2)
      .backgroundColor($r('app.color.green'))
      .accessibilityText($r('app.string.a11y_call_contact', contact.name))
      .onClick((): void => {
        this.cancelPress();
        emergencyService.callContact(contact);
      })
    }
    .width('100%')
    .height(dimens.u(DesignTokens.contactsRowHeightBase))
    .padding({
      left: dimens.u(DesignTokens.contactsRowPaddingBase),
      right: dimens.u(DesignTokens.contactsRowPaddingBase)
    })
    .backgroundColor($r('app.color.card'))
    .borderRadius(dimens.radiusCard())
    .alignItems(VerticalAlign.Center)
    .accessibilityText($r('app.string.a11y_contact_hint', contact.name, contact.role))
    .onTouch((event: TouchEvent): void => {
      if (event.type === TouchType.Down) {
        this.startPress(contact);
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.cancelPress();
      }
    })
  }

  @Builder
  contactBody() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (appStore.contacts.length === 0) {
        Column({ space: dimens.u(DesignTokens.contactsListGapBase) }) {
          Text($r('app.string.contacts_empty_title'))
            .fontSize(dimens.u(DesignTokens.fsLabel))
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
          Text($r('app.string.contacts_empty_subtitle'))
            .fontSize(dimens.u(DesignTokens.fsMin))
            .fontColor($r('app.color.muted'))
            .maxLines(1)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        List({ scroller: this.scroller, space: dimens.u(DesignTokens.contactsListGapBase) }) {
          ForEach(appStore.contacts, (contact: EmergencyContact): void => {
            ListItem() {
              this.contactRow(contact)
            }
          }, (contact: EmergencyContact): string => `${contact.id}|${contact.name}|${contact.phone ?? ''}`)
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.None)
        .nestedScroll({
          scrollForward: NestedScrollMode.SELF_FIRST,
          scrollBackward: NestedScrollMode.SELF_FIRST
        })
        .onScrollStart((): void => {
          this.cancelPress();
          this.listAtStart = false;
          this.listAtEnd = false;
        })
        .onReachStart((): void => {
          this.listAtStart = true;
        })
        .onReachEnd((): void => {
          this.listAtEnd = true;
        })
        .onTouch((event: TouchEvent): void => {
          this.handleListTouch(event);
        })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  contactFooter() {
    if (appStore.contacts.length >= 5) {
      Text($r('app.string.max_contacts'))
        .fontSize(dimens.u(DesignTokens.fsLabel))
        .fontColor($r('app.color.muted'))
        .maxLines(1)
        .margin({ bottom: dimens.u(DesignTokens.contactsFooterBottomBase) })
    } else {
      Button() {
        Row({ space: dimens.u(DesignTokens.contactsFooterGapBase) }) {
          Text($r('app.string.icon_plus'))
            .fontSize(dimens.u(DesignTokens.plusGlyphBase))
            .fontColor($r('app.color.red'))
            .maxLines(1)
          Text($r('app.string.add_contact'))
            .fontSize(dimens.u(DesignTokens.fsLabel))
            .fontColor($r('app.color.red'))
            .maxLines(1)
        }
        .alignItems(VerticalAlign.Center)
        .justifyContent(FlexAlign.Center)
      }
      .width(dimens.percent(DesignTokens.primaryButtonWidthPercent))
      .height(dimens.primaryButtonHeight())
      .borderRadius(dimens.radiusChip())
      .backgroundColor($r('app.color.card'))
      .border({ width: dimens.thinBorder(), color: $r('app.color.border') })
      .margin({ bottom: dimens.u(DesignTokens.contactsFooterBottomBase) })
      .onClick((): void => {
        emergencyService.requestAddContact();
      })
    }
  }

  build() {
    ScreenScaffold({
      headerHeightBase: DesignTokens.scaffoldHeaderBase,
      footerHeightBase: DesignTokens.scaffoldFooterBase + DesignTokens.contactsFooterBottomBase,
      logTag: 'ContactsPage',
      headerContent: (): void => {
        this.contactHeader();
      },
      bodyContent: (): void => {
        this.contactBody();
      },
      footerContent: (): void => {
        this.contactFooter();
      }
    })
  }
}
