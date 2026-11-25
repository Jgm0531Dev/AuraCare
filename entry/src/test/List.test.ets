import localUnitTest from './LocalUnit.test';
import emergencyMachineTest from './EmergencyMachine.test';
import anomalyEngineTest from './AnomalyEngine.test';
import rangeModelTest from './RangeModel.test';
import alertRecoveryTest from './AlertRecovery.test';

export default function testsuite() {
  localUnitTest();
  emergencyMachineTest();
  anomalyEngineTest();
  rangeModelTest();
  alertRecoveryTest();
}