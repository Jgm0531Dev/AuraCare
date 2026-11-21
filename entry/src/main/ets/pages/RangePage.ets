import { PageHeader } from '../components/PageHeader';
import { ScreenScaffold } from '../components/ScreenScaffold';
import { DesignTokens } from '../util/DesignTokens';

@ComponentV2
export struct RangePage {
  @Builder
  rangeHeader() {
    PageHeader({ title: $r('app.string.page_range'), icon: $r('app.string.icon_heart') })
  }

  build() {
    ScreenScaffold({
      headerHeightBase: DesignTokens.scaffoldHeaderBase,
      logTag: 'RangePage',
      headerContent: (): void => {
        this.rangeHeader();
      }
    })
  }
}
