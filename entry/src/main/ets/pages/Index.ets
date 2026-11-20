import { ArcDirection, ArcDotIndicator, ArcSwiper } from '@kit.ArkUI';
import { DesignTokens } from '../util/DesignTokens';
import { DEBUG_LAYOUT, debugRootSize, dimens } from '../util/Dimens';
import { sensorService } from '../service/SensorService';
import { appStore } from '../state/AppStore';
import { MonitorPage } from './MonitorPage';
import { SensorsPage } from './SensorsPage';
import { RangePage } from './RangePage';
import { MedicalPage } from './MedicalPage';
import { ContactsPage } from './ContactsPage';
import { SettingsPage } from './SettingsPage';

@Entry
@ComponentV2
struct Index {
  @Local pathStack: NavPathStack = new NavPathStack();
  @Local activePage: number = 0;
  @Local debugScale: number = dimens.scale;
  @Local debugRoot: string = debugRootSize(dimens.rootWidthVp, dimens.rootHeightVp);
  private indicator: ArcDotIndicator = new ArcDotIndicator();

  aboutToAppear(): void {
    dimens.init(this.getUIContext());
    sensorService.start(appStore);
    this.indicator
      .arcDirection(ArcDirection.THREE_CLOCK_DIRECTION)
      .itemColor($r('app.color.gray_636366'))
      .selectedItemColor($r('app.color.text_primary'));
  }

  @Builder
  destinationBuilder(name: string, param: Object) {
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

  @Builder
  debugOverlay() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        Column()
          .width('100%')
          .height('100%')
          .border({ width: dimens.thinBorder(), color: $r('app.color.accion_principal') })
      }
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
          ArcSwiper() {
            MonitorPage()
            SensorsPage()
            RangePage()
            MedicalPage()
            ContactsPage()
            SettingsPage()
          }
          .width('100%')
          .height('100%')
          .vertical(true)
          .indicator(this.indicator)
          .index(this.activePage)
          .onChange((index: number) => {
            this.activePage = index;
          })
          .onAreaChange((_oldValue: Area, newValue: Area) => {
            dimens.logArea('Index', 'ArcSwiper', newValue);
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
