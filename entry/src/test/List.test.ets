import localUnitTest from './LocalUnit.test';
import emergencyMachineTest from './EmergencyMachine.test';

export default function testsuite() {
  localUnitTest();
  emergencyMachineTest();
}