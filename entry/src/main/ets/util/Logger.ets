import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0xA10A;

export class Logger {
  static info(tag: string, message: string): void {
    hilog.info(DOMAIN, tag, '%{public}s', message);
  }

  static error(tag: string, message: string, err: Object): void {
    hilog.error(DOMAIN, tag, '%{public}s %{public}s', message, JSON.stringify(err));
  }

  static warn(tag: string, message: string): void {
    hilog.warn(DOMAIN, tag, '%{public}s', message);
  }
}
