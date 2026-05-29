export interface CountlyConfigPayload {
  appKey: string;
  serverURL: string;
  deviceID?: string;
  loggingEnabled?: boolean;
  shouldRequireConsent?: boolean;
  enableUnhandledCrashReporting?: boolean;
  customCrashSegment?: Object;
  locationDisabled?: boolean;
  locationCity?: string;
  locationCountryCode?: string;
  locationGpsCoordinates?: string;
  locationIpAddress?: string;
  tamperingProtectionSalt?: string;
  manualSessionEnabled?: boolean;
  enableForegroundBackground?: boolean;
  enableManualAppLoaded?: boolean;
  enableAllConsents?: boolean;
}

export class CountlyConfig {
  appKey: string = '';
  serverURL: string = '';
  deviceID: string = '';
  loggingEnabled: boolean = false;
  requiresConsent: boolean = false;
  enableUnhandledCrashReporting: boolean = false;
  customCrashSegment: Object | null = null;
  locationDisabled: boolean = false;
  locationCity: string = '';
  locationCountryCode: string = '';
  locationGpsCoordinates: string = '';
  locationIpAddress: string = '';
  tamperingProtectionSalt: string = '';
  manualSessionEnabled: boolean = false;
  enableForegroundBackground: boolean = false;
  enableManualAppLoaded: boolean = false;
  enableAllConsents: boolean = false;

  static fromPayload(payload: CountlyConfigPayload): CountlyConfig {
    const config = new CountlyConfig();
    config.appKey = payload.appKey;
    config.serverURL = payload.serverURL;
    config.deviceID = payload.deviceID != null ? payload.deviceID : '';
    config.loggingEnabled = payload.loggingEnabled === true;
    config.requiresConsent = payload.shouldRequireConsent === true;
    config.enableUnhandledCrashReporting = payload.enableUnhandledCrashReporting === true;
    config.customCrashSegment = payload.customCrashSegment != null ? payload.customCrashSegment : null;
    config.locationDisabled = payload.locationDisabled === true;
    config.locationCity = payload.locationCity != null ? payload.locationCity : '';
    config.locationCountryCode = payload.locationCountryCode != null ? payload.locationCountryCode : '';
    config.locationGpsCoordinates = payload.locationGpsCoordinates != null ? payload.locationGpsCoordinates : '';
    config.locationIpAddress = payload.locationIpAddress != null ? payload.locationIpAddress : '';
    config.tamperingProtectionSalt = payload.tamperingProtectionSalt != null ? payload.tamperingProtectionSalt : '';
    config.manualSessionEnabled = payload.manualSessionEnabled === true;
    config.enableForegroundBackground = payload.enableForegroundBackground === true;
    config.enableManualAppLoaded = payload.enableManualAppLoaded === true;
    config.enableAllConsents = payload.enableAllConsents === true;
    return config;
  }
}
