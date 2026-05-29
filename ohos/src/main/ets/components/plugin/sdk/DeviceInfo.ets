import bundleManager from '@ohos.bundle.bundleManager';
import deviceInfo from '@ohos.deviceInfo';

export class DeviceInfoProvider {
  private appVersion: string = 'unknown';
  private osVersion: string = 'unknown';
  private model: string = 'unknown';

  init(): void {
    try {
      const bundleInfo = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      this.appVersion = bundleInfo.versionName != null ? bundleInfo.versionName : 'unknown';
    } catch (_) {
      this.appVersion = 'unknown';
    }
    try {
      this.osVersion = deviceInfo.osFullName;
    } catch (_) {
      this.osVersion = 'unknown';
    }
    try {
      this.model = deviceInfo.deviceType;
    } catch (_) {
      this.model = 'unknown';
    }
  }

  buildMetricsJson(): string {
    const language: string = 'zh';
    const country: string = 'CN';
    const appVersionPart: string = '"_app_version":"' + this.escape(this.appVersion) + '"';
    const osPart: string = '"_os":"HarmonyOS"';
    const osVersionPart: string = '"_os_version":"' + this.escape(this.osVersion) + '"';
    const devicePart: string = '"_device":"' + this.escape(this.model) + '"';
    const localePart: string = '"_locale":"' + language + '_' + country + '"';
    return '{' + [appVersionPart, osPart, osVersionPart, devicePart, localePart].join(',') + '}';
  }

  private escape(value: string): string {
    return value.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
  }
}
