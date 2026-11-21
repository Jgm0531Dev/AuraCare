import { DesignTokens } from '../util/DesignTokens';
import { dimens } from '../util/Dimens';
import { appStore } from '../state/AppStore';
import { sensorService } from '../service/SensorService';
import { emergencyService } from '../service/EmergencyService';
import { AlertReason } from '../model/AlertReason';
import { PulseState } from '../model/PulseState';
import { SensorStatus } from '../model/SensorAvailability';
import { WatchBackButton } from '../components/WatchBackButton';
import { ScreenScaffold } from '../components/ScreenScaffold';

@ComponentV2
export struct DemoPanelPage {
  @Param onBack: () => void = () => {};
  @Local reason: AlertReason = AlertReason.PulsoCritico;

  aboutToAppear(): void {
    appStore.demoPanelVisible = true;
  }

  aboutToDisappear(): void {
    appStore.demoPanelVisible = false;
  }

  @Builder
  private choiceButton(label: Resource, color: Resource, onPress: () => void): void {
    Button() {
      Text(label)
        .fontSize(dimens.u(DesignTokens.fsLabel))
        .fontColor($r('app.color.text_primary'))
    }
    .layoutWeight(1)
    .height(dimens.cqw(DesignTokens.demoButtonHeightCqw))
    .borderRadius(dimens.cqw(DesignTokens.demoButtonRadiusCqw))
    .backgroundColor(color)
    .onClick(onPress)
  }

  @Builder
  private sectionTitle(label: Resource): void {
    Text(label)
      .fontSize(dimens.u(DesignTokens.fsBody))
      .fontColor($r('app.color.text_primary'))
      .fontWeight(FontWeight.Medium)
      .margin({ top: dimens.cqw(DesignTokens.demoSectionGapCqw) })
  }

  @Builder
  private hardwareSwitch(label: Resource, isOn: boolean, onChange: (value: boolean) => void): void {
    Row() {
      Text(label)
        .fontSize(dimens.u(DesignTokens.fsLabel))
        .fontColor($r('app.color.text_primary'))
      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor($r('app.color.green'))
        .onChange(onChange)
    }
    .width('100%')
    .constraintSize({ minHeight: dimens.touchMin() })
    .justifyContent(FlexAlign.SpaceBetween)
  }

  @Builder
  demoBody() {
    Scroll() {
      Column() {
        WatchBackButton({ label: $r('app.string.back'), onBack: this.onBack })

        Text($r('app.string.demo_panel_title'))
          .fontSize(dimens.u(DesignTokens.fsSubtitle))
          .fontColor($r('app.color.text_primary'))
          .fontWeight(FontWeight.Bold)
        Text($r('app.string.demo_control_title'))
          .fontSize(dimens.u(DesignTokens.fsLabel))
          .fontColor($r('app.color.muted'))

        this.sectionTitle($r('app.string.demo_pulse_selector'))
        Row({ space: dimens.cqw(DesignTokens.demoGapCqw) }) {
          this.choiceButton($r('app.string.demo_state_normal'), $r('app.color.green'), (): void => {
            this.selectPulse(PulseState.Normal);
          })
          this.choiceButton($r('app.string.demo_state_elevated'), $r('app.color.orange'), (): void => {
            this.selectPulse(PulseState.Elevated);
          })
          this.choiceButton($r('app.string.demo_state_critical'), $r('app.color.red'), (): void => {
            this.selectPulse(PulseState.Critical);
          })
        }
        .width('100%')

        this.sectionTitle($r('app.string.demo_hardware_title'))
        this.hardwareSwitch($r('app.string.demo_spo2_switch'),
          appStore.capabilities.spo2 === SensorStatus.Available, (value: boolean): void => {
            sensorService.toggleCapability('spo2', value, appStore);
          })
        this.hardwareSwitch($r('app.string.demo_temperature_switch'),
          appStore.capabilities.temperature === SensorStatus.Available, (value: boolean): void => {
            sensorService.toggleCapability('temperature', value, appStore);
          })
        this.hardwareSwitch($r('app.string.demo_fall_switch'),
          appStore.capabilities.fallDetection === SensorStatus.Available, (value: boolean): void => {
            sensorService.toggleCapability('fallDetection', value, appStore);
          })

        this.sectionTitle($r('app.string.demo_alert_title'))
        this.hardwareSwitch($r('app.string.demo_auto_alerts'), appStore.autoAlerts, (value: boolean): void => {
          appStore.autoAlerts = value;
          emergencyService.updateAutoAlert(appStore);
        })
        this.sectionTitle($r('app.string.demo_reason_title'))
        Row({ space: dimens.cqw(DesignTokens.demoGapCqw) }) {
          this.choiceButton($r('app.string.demo_reason_pulse'), $r('app.color.card'), (): void => {
            this.reason = AlertReason.PulsoCritico;
          })
          this.choiceButton($r('app.string.demo_reason_fall'), $r('app.color.card'), (): void => {
            this.reason = AlertReason.Caida;
          })
          this.choiceButton($r('app.string.demo_reason_sos'), $r('app.color.card'), (): void => {
            this.reason = AlertReason.SosManual;
          })
        }
        .width('100%')

        Button() {
          Text($r('app.string.demo_simulate_alert'))
            .fontSize(dimens.u(DesignTokens.fsBody))
            .fontColor($r('app.color.text_primary'))
            .fontWeight(FontWeight.Bold)
        }
        .width('100%')
        .height(dimens.cqw(DesignTokens.demoButtonHeightCqw))
        .borderRadius(dimens.cqw(DesignTokens.demoButtonRadiusCqw))
        .backgroundColor($r('app.color.accion_principal'))
        .margin({ top: dimens.cqw(DesignTokens.demoSectionGapCqw) })
        .onClick((): void => {
          emergencyService.simulateAlert(this.reason);
        })

        Button() {
          Text($r('app.string.demo_view_alert_sent'))
            .fontSize(dimens.u(DesignTokens.fsBody))
            .fontColor($r('app.color.text_primary'))
            .fontWeight(FontWeight.Bold)
        }
        .width('100%')
        .height(dimens.cqw(DesignTokens.demoButtonHeightCqw))
        .borderRadius(dimens.cqw(DesignTokens.demoButtonRadiusCqw))
        .backgroundColor($r('app.color.card'))
        .margin({ top: dimens.cqw(DesignTokens.demoGapCqw) })
        .onClick((): void => {
          emergencyService.viewAlertSent();
        })

        Button() {
          Text($r('app.string.demo_simulate_contact_response'))
            .fontSize(dimens.u(DesignTokens.fsBody))
            .fontColor($r('app.color.text_primary'))
            .fontWeight(FontWeight.Bold)
        }
        .width('100%')
        .height(dimens.cqw(DesignTokens.demoButtonHeightCqw))
        .borderRadius(dimens.cqw(DesignTokens.demoButtonRadiusCqw))
        .backgroundColor($r('app.color.card'))
        .margin({ top: dimens.cqw(DesignTokens.demoGapCqw) })
        .onClick((): void => {
          emergencyService.advanceContactResponse();
        })

        Row({ space: dimens.cqw(DesignTokens.demoGapCqw) }) {
          this.choiceButton($r('app.string.demo_offline'), $r('app.color.card'), (): void => {
            appStore.mode = 'offline';
          })
          this.choiceButton($r('app.string.demo_first_use'), $r('app.color.card'), (): void => {
            appStore.mode = 'first-use';
          })
          this.choiceButton($r('app.string.monitor_live'), $r('app.color.card'), (): void => {
            appStore.mode = 'live';
            emergencyService.updateAutoAlert(appStore);
          })
        }
        .width('100%')
        .margin({ top: dimens.cqw(DesignTokens.demoSectionGapCqw) })

        this.hardwareSwitch($r('app.string.demo_contacts_empty'), appStore.contacts.length === 0,
          (value: boolean): void => {
            emergencyService.setContactsEmpty(value);
          })

        Button() {
          Text($r('app.string.demo_contact_added'))
            .fontSize(dimens.u(DesignTokens.fsBody))
            .fontColor($r('app.color.text_primary'))
            .fontWeight(FontWeight.Bold)
        }
        .width('100%')
        .height(dimens.cqw(DesignTokens.demoButtonHeightCqw))
        .borderRadius(dimens.cqw(DesignTokens.demoButtonRadiusCqw))
        .backgroundColor($r('app.color.card'))
        .margin({ top: dimens.cqw(DesignTokens.demoGapCqw) })
        .onClick((): void => {
          emergencyService.addDemoContact();
        })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
  }

  build() {
    NavDestination() {
      ScreenScaffold({
        logTag: 'DemoPanelPage',
        bodyContent: (): void => {
          this.demoBody();
        }
      })
    }
    .hideTitleBar(true)
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.watch_background'))
  }

  private selectPulse(state: PulseState): void {
    sensorService.selectVariant(state, appStore);
    appStore.mode = 'live';
    emergencyService.updateAutoAlert(appStore);
  }
}
