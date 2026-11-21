import { PageHeader } from '../components/PageHeader';
import { ScreenScaffold } from '../components/ScreenScaffold';
import { DesignTokens } from '../util/DesignTokens';

@ComponentV2
export struct SettingsPage {
  @Builder
  settingsHeader() {
    PageHeader({ title: $r('app.string.page_settings'), icon: $r('app.string.icon_sensor') })
  }

  build() {
    ScreenScaffold({
      headerHeightBase: DesignTokens.scaffoldHeaderBase,
      logTag: 'SettingsPage',
      headerContent: (): void => {
        this.settingsHeader();
      }
    })
  }
}
