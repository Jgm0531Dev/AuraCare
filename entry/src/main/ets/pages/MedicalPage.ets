import { PageHeader } from '../components/PageHeader';
import { ScreenScaffold } from '../components/ScreenScaffold';
import { DesignTokens } from '../util/DesignTokens';

@ComponentV2
export struct MedicalPage {
  @Builder
  medicalHeader() {
    PageHeader({ title: $r('app.string.page_medical'), icon: $r('app.string.icon_check') })
  }

  build() {
    ScreenScaffold({
      headerHeightBase: DesignTokens.scaffoldHeaderBase,
      logTag: 'MedicalPage',
      headerContent: (): void => {
        this.medicalHeader();
      }
    })
  }
}
