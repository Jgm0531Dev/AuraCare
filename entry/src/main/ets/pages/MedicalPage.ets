import { PageHeader } from '../components/PageHeader';
import { dimens } from '../util/Dimens';

@ComponentV2
export struct MedicalPage {
  build() {
    Column() {
      PageHeader({ title: $r('app.string.page_medical') })
    }
    .width('100%')
    .height('100%')
    .padding({
      top: dimens.safeTop(), bottom: dimens.safeBottom(),
      left: dimens.safeLeft(), right: dimens.safeRight()
    })
  }
}
