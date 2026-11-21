import { hilog } from '@kit.PerformanceAnalysisKit';
import { BackupExtensionAbility, BundleVersion } from '@kit.CoreFileKit';

const DOMAIN: number = 0xA10A;

export default class EntryBackupAbility extends BackupExtensionAbility {
  async onBackup() {
    hilog.info(DOMAIN, 'EntryBackupAbility', 'onBackup ok');
    await Promise.resolve();
  }

  async onRestore(bundleVersion: BundleVersion) {
    hilog.info(DOMAIN, 'EntryBackupAbility', 'onRestore ok %{public}s', JSON.stringify(bundleVersion));
    await Promise.resolve();
  }
}