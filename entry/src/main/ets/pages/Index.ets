import { ArcDirection, ArcDotIndicator, ArcSwiper } from '@kit.ArkUI';
import { Context } from '@kit.AbilityKit';
import { DesignTokens } from '../util/DesignTokens';
import { DEBUG_LAYOUT, debugRootSize, dimens } from '../util/Dimens';
import { Logger } from '../util/Logger';
import { sensorService } from '../service/SensorService';
import { emergencyService } from '../service/EmergencyService';
import { vibrationService } from '../service/VibrationService';
import { appStore, DialogKind } from '../state/AppStore';
import { AlertState } from '../model/Alert';
import { MonitorPage } from './MonitorPage';
import { DemoPanelPage } from './DemoPanelPage';
import { SensorsPage } from './SensorsPage';
import { RangePage } from './RangePage';
import { MedicalPage } from './MedicalPage';
import { ContactsPage } from './ContactsPage';
import { SettingsPage } from './SettingsPage';
import { AlertRoute } from '../components/AlertRoute';
import { AddContactPage } from './AddContactPage';
import { DEMO_GESTURE_ENABLED } from '../util/AppConfig';
import { crownNav, NAV_TRACE } from '../util/CrownNav';
import { AlertConfirmDialog } from '../components/AlertConfirmDialog';

const MAIN_SWIPER_ID: string = 'mainSwiper';
/** Contenedor que envuelve al ArcSwiper: único receptor de la corona en la pantalla principal. */
const CROWN_HOST_ID: string = 'crownHost';


@Entry
@ComponentV2
struct Index {
  @Local pathStack: NavPathStack = new NavPathStack();
  @Local activePage: number = 0;
  @Local debugScale: number = dimens.scale;
  @Local debugRoot: string = debugRootSize(dimens.rootWidthVp, dimens.rootHeightVp);
  private indicator: ArcDotIndicator = new ArcDotIndicator();
  /** Momento del último cambio de página (toque o corona) y si lo provocó la corona. */
  private lastPageChangeAt: number = 0;
  // Espejos locales: Index no re-renderiza con lecturas directas de appStore (comprobado en
  // previewer.log: disableSwipe y las capas de alerta no reaccionaban). Los alimenta EmergencyService.
  @Local alertState: AlertState = AlertState.None;
  @Local dialogVisible: boolean = false;
  @Local callFailedVisible: boolean = false;
  @Local infoVisible: boolean = false;
  private unsubscribeUi: () => void = (): void => {};

  private syncFromStore(event: string): void {
    this.alertState = appStore.emergency.state;
    this.dialogVisible = appStore.dialogOpen;
    this.callFailedVisible = appStore.callFailedVisible;
    this.infoVisible = appStore.infoVisible;
    if (DEBUG_LAYOUT) {
      Logger.info('Index',
        `[trace] espejo actualizado (${event}): alert=${this.alertState} dialog=${this.dialogVisible} navStackDepth=${this.pathStack.size()}`);
    }
    this.syncRoutes(event);
    if (event === 'addContact' && this.pathStack.getAllPathName().indexOf('addContact') < 0) {
      this.pathStack.pushPath({ name: 'addContact' });
      this.traceRoute('push addContact');
    }
  }

  /** Alerta y diálogos como rutas: lo único que se dibuja encima de Navigation. */
  private syncRoutes(event: string): void {
    try {
      const wantAlert: boolean = this.alertState !== AlertState.None;
      if (wantAlert && this.pathStack.getAllPathName().indexOf('alert') < 0) {
        // La alerta toma la pantalla: se cierra el panel demo o lo que esté abierto.
        this.pathStack.clear(false);
        this.pathStack.pushPath({ name: 'alert' }, false);
        this.traceRoute(`push alert (${event})`);
      } else if (!wantAlert && this.pathStack.getAllPathName().indexOf('alert') >= 0) {
        this.pathStack.removeByName('alert');
        this.traceRoute(`remove alert (${event})`);
        this.focusSwiper('remove alert');
      }
      const hasDialog: boolean = this.pathStack.getAllPathName().indexOf('dialog') >= 0;
      if (this.dialogVisible && !hasDialog) {
        this.pathStack.pushPath({ name: 'dialog' }, false);
        this.traceRoute(`push dialog (${event})`);
      } else if (!this.dialogVisible && hasDialog) {
        this.pathStack.removeByName('dialog');
        this.traceRoute(`remove dialog (${event})`);
        this.focusSwiper('remove dialog');
      }
    } catch (err) {
      Logger.error('Index', `syncRoutes falló (${event})`, err as Object);
    } finally {
      appStore.navStackDepth = this.pathStack.size();
    }
  }

  /**
   * Cambio de página por cualquier método (toque o corona nativa del ArcSwiper): las listas de otras
   * páginas vuelven arriba y el foco sale de cualquier Scroll para que la corona llegue al swiper.
   */
  private onPageChanged(from: number, to: number): void {
    const now: number = Date.now();
    if (NAV_TRACE) {
      Logger.info('Index', `[nav] cambio ${from} -> ${to} msDesdeCambio=${now - this.lastPageChangeAt}`);
    }
    this.lastPageChangeAt = now;
    crownNav.notifyPageChanged(to);
    this.focusSwiper(`onChange ${from}->${to}`);
  }

  /**
   * Foco coherente tras cada cambio de página o al cerrar alerta/diálogo/ruta: se limpia el foco (p. ej.,
   * el de una lista de otra página) y se da al contenedor de la página visible. Siguiente frame.
   */
  private focusSwiper(reason: string): void {
    // El foco va al contenedor que envuelve al swiper (el swiper es focusable(false) y no puede tenerlo).
    setTimeout((): void => {
      try {
        this.getUIContext().getFocusController().requestFocus(CROWN_HOST_ID);
        if (NAV_TRACE) {
          Logger.info('Index', `[nav] foco -> ${CROWN_HOST_ID} (${reason})`);
        }
      } catch (err) {
        Logger.error('Index', `requestFocus contenedor falló (${reason})`, err as Object);
      }
    }, 0);
  }

  private traceRoute(action: string): void {
    if (DEBUG_LAYOUT) {
      Logger.info('Index',
        `[trace] ruta ${action}: pila=[${this.pathStack.getAllPathName().join(',')}]`);
    }
  }

  private logOverlay(name: string): void {
    if (DEBUG_LAYOUT) {
      Logger.info('Index', `[trace] capa visible: ${name} alert=${this.alertState}`);
    }
  }

  aboutToAppear(): void {
    dimens.init(this.getUIContext());
    const context: Context | undefined = this.getUIContext().getHostContext();
    if (context !== undefined) {
      vibrationService.init(context);
      sensorService.init(context);
    }
    emergencyService.start(appStore);
    if (context !== undefined) {
      // Contactos y Ajustes persistidos antes de arrancar los sensores (modo demostración incluido).
      emergencyService.loadContacts(context);
    }
    sensorService.start(appStore);
    if (context !== undefined) {
      // READ_HEALTH_DATA (user_grant): sin permiso el pulso queda "sin lectura", nunca simulado.
      sensorService.requestPermissions(context).catch((err: Object): void => {
        Logger.error('Index', 'requestPermissions falló', err);
      });
    }
    this.unsubscribeUi = emergencyService.onUiChange((event: string): void => {
      this.syncFromStore(event);
    });
    this.syncFromStore('aboutToAppear');
    this.indicator
      .arcDirection(ArcDirection.THREE_CLOCK_DIRECTION)
      .itemColor($r('app.color.gray_636366'))
      .selectedItemColor($r('app.color.text_primary'));
    this.syncNavDepth('aboutToAppear');
  }

  /** Mantiene el espejo de profundidad y registra el overlay bajo DEBUG_LAYOUT. */
  private syncNavDepth(event: string): void {
    appStore.navStackDepth = this.pathStack.size();
    if (DEBUG_LAYOUT) {
      Logger.info('Index',
        `${event}: overlayOpen=${appStore.dialogOpen} navStackDepth=${appStore.navStackDepth}`);
    }
  }

  /** Salida de Contactos cuando la lista no puede seguir scrolleando. */
  private stepPage(delta: number): void {
    const from: number = this.activePage;
    const next: number = Math.max(0, Math.min(5, from + delta));
    if (next === from) {
      return;
    }
    this.activePage = next;
    if (DEBUG_LAYOUT) {
      Logger.info('Index',
        `contactsEdge: from=${from} to=${next} overlayOpen=${appStore.dialogOpen} navStackDepth=${appStore.navStackDepth}`);
    }
  }

  @Builder
  destinationBuilder(name: string, param: Object) {
    if (name === 'demo') {
      DemoPanelPage({
        onBack: (): void => {
          try {
            this.pathStack.pop();
          } finally {
            this.focusSwiper('demoPop');
            this.syncNavDepth('demoPop');
          }
        }
      })
    } else if (name === 'addContact') {
      AddContactPage({
        onDone: (): void => {
          this.pathStack.removeByName('addContact');
          this.syncNavDepth('addContactDone');
          this.focusSwiper('addContactDone');
        }
      })
    } else if (name === 'alert') {
      AlertRoute()
    } else if (name === 'dialog') {
      NavDestination() {
        this.confirmDialog()
      }
      .hideTitleBar(true)
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.watch_background'))
      .onShown((): void => {
        this.logOverlay(`confirmDialog kind=${appStore.dialogKind}`);
      })
      .onBackPressed((): boolean => {
        emergencyService.closeDialog();
        return true;
      })
    } else {
      NavDestination() {
        Column() {
          Text(name)
            .fontSize(dimens.u(DesignTokens.fsBody))
            .fontColor($r('app.color.text_primary'))
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      }
      .title(name)
    }
  }

  aboutToDisappear(): void {
    this.unsubscribeUi();
    emergencyService.dispose();
    sensorService.release();
  }

  onBackPress(): boolean {
    return appStore.emergency.state !== AlertState.None || appStore.dialogOpen;
  }

  private dialogTitle(): Resource {
    if (appStore.dialogKind === DialogKind.Call911) {
      return $r('app.string.call_911_title');
    }
    if (appStore.dialogKind === DialogKind.RemoveContact) {
      return $r('app.string.remove_contact_title');
    }
    if (appStore.dialogKind === DialogKind.AddContact) {
      return $r('app.string.pick_phone');
    }
    return $r('app.string.confirm_well_title');
  }

  private dialogDescription(): Resource {
    if (appStore.dialogKind === DialogKind.Call911) {
      return $r('app.string.emergency_911_desc');
    }
    if (appStore.dialogKind === DialogKind.RemoveContact) {
      return $r('app.string.remove_contact_desc', appStore.contactToRemoveName);
    }
    if (appStore.dialogKind === DialogKind.AddContact) {
      return $r('app.string.pick_phone_desc');
    }
    return $r('app.string.confirm_well_desc');
  }

  private dialogConfirmLabel(): Resource {
    if (appStore.dialogKind === DialogKind.Call911) {
      return $r('app.string.call');
    }
    if (appStore.dialogKind === DialogKind.RemoveContact) {
      return $r('app.string.remove_contact');
    }
    if (appStore.dialogKind === DialogKind.AddContact) {
      return $r('app.string.understand');
    }
    return $r('app.string.confirm_well_yes');
  }

  private dialogIcon(): Resource {
    if (appStore.dialogKind === DialogKind.Call911) {
      return $r('app.string.icon_phone');
    }
    if (appStore.dialogKind === DialogKind.RemoveContact) {
      return $r('app.string.icon_warning');
    }
    if (appStore.dialogKind === DialogKind.AddContact) {
      return $r('app.string.icon_phone');
    }
    return $r('app.string.icon_check');
  }

  private dialogTone(): Resource {
    return appStore.dialogKind === DialogKind.Call911 ? $r('app.color.red') : $r('app.color.green');
  }

  @Builder
  confirmDialog() {
    AlertConfirmDialog({
      title: this.dialogTitle(),
      description: this.dialogDescription(),
      confirmLabel: this.dialogConfirmLabel(),
      icon: this.dialogIcon(),
      tone: this.dialogTone(),
      hideCancel: appStore.dialogKind === DialogKind.AddContact,
      // v1.0.1: el marcador es real; ya no hay nota de simulación.
      showSimulationNote: false,
      onConfirm: (): void => {
        emergencyService.confirmDialog();
      },
      onCancel: (): void => {
        emergencyService.closeDialog();
      }
    })
    .width('100%')
    .height('100%')
  }

  @Builder
  monitorPage() {
    MonitorPage({
      onOpenDemo: (): void => {
        // Ruta 'demo' inalcanzable en release (salvo REVIEWER_DEMO_GESTURE).
        if (!DEMO_GESTURE_ENABLED) {
          return;
        }
        // Badge y pulsación larga pueden disparar dos veces: un solo panel en la pila.
        if (this.pathStack.getAllPathName().indexOf('demo') >= 0) {
          this.syncNavDepth('demoPush ignorado (ya abierto)');
          return;
        }
        this.pathStack.pushPath({ name: 'demo' });
        this.syncNavDepth('demoPush');
      },
      onOpenContacts: (): void => {
        this.activePage = 4;
      }
    })
  }

  @Builder
  sensorsPage() {
    SensorsPage()
  }

  @Builder
  rangePage() {
    RangePage()
  }

  @Builder
  medicalPage() {
    MedicalPage()
  }

  @Builder
  contactsPage() {
    ContactsPage({
      onPageStep: (delta: number): void => {
        this.stepPage(delta);
      }
    })
  }

  @Builder
  settingsPage() {
    SettingsPage()
  }

  @Builder
  debugOverlay() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        Column()
          .width('100%')
          .height('100%')
          .border({ width: dimens.thinBorder(), color: $r('app.color.accion_principal') })
          .hitTestBehavior(HitTestMode.None)
      }
      .hitTestBehavior(HitTestMode.None)
      .width('100%')
      .height('100%')
      .padding({
        top: dimens.safeTop(), bottom: dimens.safeBottom(),
        left: dimens.safeLeft(), right: dimens.safeRight()
      })

      Text($r('app.string.debug_layout_info', this.debugScale.toFixed(2), this.debugRoot))
        .fontSize(dimens.u(DesignTokens.fsMin))
        .fontColor($r('app.color.text_primary'))
        .backgroundColor($r('app.color.surface_deep'))
        .padding({
          left: dimens.cqw(DesignTokens.chipPaddingCqw),
          right: dimens.cqw(DesignTokens.chipPaddingCqw),
          top: dimens.cqw(DesignTokens.chipValueGapCqw),
          bottom: dimens.cqw(DesignTokens.chipValueGapCqw)
        })
        .margin({ top: dimens.safeTop(), left: dimens.safeLeft() })
        .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Transparent)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        Navigation(this.pathStack) {
          // El margen derecho del 9% se aplica en cada página (dimens.safeRight())
          // para que los puntos del indicador no tapen el contenido.
          // Único receptor de la corona en la pantalla principal: desplaza la lista de la página visible.
          Stack() {
            ArcSwiper() {
              this.monitorPage()
              this.sensorsPage()
              this.rangePage()
              this.medicalPage()
              this.contactsPage()
              this.settingsPage()
            }
            .width('100%')
            .height('100%')
            .vertical(true)
            .id(MAIN_SWIPER_ID)
            // Plan B (v1.0.1): la corona NO cambia de página. focusable(false) en el swiper: según el SDK 24
            // (requestFocus, error 150002 "unfocusable ancestor"), ni él ni sus páginas pueden tener el foco,
            // y la corona solo se entrega al componente con foco. Navegación: toque e indicador.
            .focusable(false)
            .disableSwipe(this.alertState !== AlertState.None || this.dialogVisible)
            .indicator(this.indicator)
            .index(this.activePage)
            .onChange((index: number) => {
              const from: number = this.activePage;
              this.activePage = index;
              this.onPageChanged(from, index);
            })
            .onAnimationStart((index: number, targetIndex: number): void => {
              if (NAV_TRACE) {
                Logger.info('Index', `[nav] animación ${index} -> ${targetIndex}`);
              }
            })
            .onAreaChange((_oldValue: Area, newValue: Area) => {
              dimens.logArea('Index', 'ArcSwiper', newValue);
            })
          }
          .width('100%')
          .height('100%')
          .id(CROWN_HOST_ID)
          .focusable(true)
          .defaultFocus(true)
          .onDigitalCrown((event: CrownEvent): void => {
            event.stopPropagation();
            if (event.action !== CrownAction.UPDATE || this.alertState !== AlertState.None || this.dialogVisible) {
              return;
            }
            crownNav.scrollPage(this.activePage, event.degree);
          })
        }
        .width('100%')
        .height('100%')
        .hideTitleBar(true)
        .onAreaChange((_oldValue: Area, newValue: Area) => {
          dimens.logArea('Index', 'Navigation', newValue);
        })
        .navDestination(this.destinationBuilder)
      }
      .width('100%')
      .height('100%')

      // Alerta y diálogos ya no van aquí: son rutas 'alert' y 'dialog' (ver syncRoutes).


      // El reloj no puede llamar: se dice y se muestra el número para marcarlo desde otro teléfono.
      if (this.callFailedVisible) {
        Column() {
          Button() {
            Column({ space: 0 }) {
              Text($r('app.string.call_unavailable'))
                .fontSize(dimens.u(DesignTokens.fsMin))
                .fontColor($r('app.color.orange'))
                .maxLines(2)
                .textAlign(TextAlign.Center)
              Text(appStore.callFailedNumber)
                .fontSize(dimens.u(DesignTokens.fsLabel))
                .fontColor($r('app.color.text_primary'))
                .fontWeight(FontWeight.Bold)
                .maxLines(1)
            }
            .padding({
              left: dimens.cqw(DesignTokens.infoCardPaddingCqw),
              right: dimens.cqw(DesignTokens.infoCardPaddingCqw),
              top: dimens.cqw(DesignTokens.chipPaddingCqw),
              bottom: dimens.cqw(DesignTokens.chipPaddingCqw)
            })
          }
          .constraintSize({ minHeight: dimens.touchMin() })
          .backgroundColor($r('app.color.card'))
          .borderRadius(dimens.radiusChip())
          .accessibilityText($r('app.string.call_unavailable'))
          .onClick((): void => {
            emergencyService.hideCallFailed();
          })
        }
        .width('100%')
        .padding({ left: dimens.safeLeft(), right: dimens.safeRight() })
        .alignItems(HorizontalAlign.Center)
        .margin({ top: dimens.cqw(DesignTokens.toastTopCqw) })
        .hitTestBehavior(HitTestMode.Transparent)
      }

      // Aviso informativo (instrucciones): se cierra al tocarlo.
      if (this.infoVisible) {
        Column() {
          Button() {
            Text(appStore.infoMessage)
              .fontSize(dimens.u(DesignTokens.fsMin))
              .fontColor($r('app.color.text_primary'))
              .maxLines(4)
              .textAlign(TextAlign.Center)
              .padding({
                left: dimens.cqw(DesignTokens.infoCardPaddingCqw),
                right: dimens.cqw(DesignTokens.infoCardPaddingCqw),
                top: dimens.cqw(DesignTokens.chipPaddingCqw),
                bottom: dimens.cqw(DesignTokens.chipPaddingCqw)
              })
          }
          .constraintSize({ minHeight: dimens.touchMin() })
          .backgroundColor($r('app.color.card'))
          .borderRadius(dimens.radiusChip())
          .onClick((): void => {
            emergencyService.hideInfo();
          })
        }
        .width('100%')
        .padding({ left: dimens.safeLeft(), right: dimens.safeRight() })
        .alignItems(HorizontalAlign.Center)
        .margin({ top: dimens.cqw(DesignTokens.toastTopCqw) })
        .hitTestBehavior(HitTestMode.Transparent)
      }

      if (DEBUG_LAYOUT) {
        this.debugOverlay()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.watch_background'))
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      dimens.updateFromRoot(newValue);
      if (DEBUG_LAYOUT) {
        this.debugScale = dimens.scale;
        this.debugRoot = debugRootSize(dimens.rootWidthVp, dimens.rootHeightVp);
      }
      dimens.logArea('Index', 'RootColumn', newValue);
    })
  }
}
