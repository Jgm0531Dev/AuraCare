import { PageHeader } from '../components/PageHeader';
import { ScreenScaffold } from '../components/ScreenScaffold';
import { DesignTokens } from '../util/DesignTokens';

@ComponentV2
export struct SensorsPage {
  @Builder
  sensorsHeader() {
    PageHeader({ title: $r('app.string.page_sensors'), icon: $r('app.string.icon_sensor') })
  }

  build() {
    ScreenScaffold({
      headerHeightBase: DesignTokens.scaffoldHeaderBase,
      logTag: 'SensorsPage',
      headerContent: (): void => {
        this.sensorsHeader();
      }
    })
  }
}
