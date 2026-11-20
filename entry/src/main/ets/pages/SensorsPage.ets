import { PageHeader } from '../components/PageHeader';
import { dimens } from '../util/Dimens';

@ComponentV2
export struct SensorsPage {
  build() {
    Column() {
      PageHeader({ title: $r('app.string.page_sensors') })
    }
    .width('100%')
    .height('100%')
    .padding({
      top: dimens.safeTop(), bottom: dimens.safeBottom(),
      left: dimens.safeLeft(), right: dimens.safeRight()
    })
  }
}
