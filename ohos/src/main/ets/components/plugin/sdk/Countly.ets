import { common } from '@kit.AbilityKit';
import { CountlyConfig, CountlyConfigPayload } from './CountlyConfig';
import { StorageManager } from './StorageManager';
import { DeviceInfoProvider } from './DeviceInfo';
import { RequestQueue } from './RequestQueue';
import { ModuleDeviceId } from './ModuleDeviceId';
import { ModuleConsent } from './ModuleConsent';
import { ModuleEvents } from './ModuleEvents';
import { ModuleSessions } from './ModuleSessions';
import { ModuleViews } from './ModuleViews';
import { ModuleUserProfile } from './ModuleUserProfile';
import { ModuleCrash } from './ModuleCrash';
import { ModuleLocation } from './ModuleLocation';
import { ModuleRemoteConfig } from './ModuleRemoteConfig';
import { ModuleFeedback } from './ModuleFeedback';
import { CountlyLogger } from './CountlyLogger';

export class Countly {
  private static instanceRef: Countly = new Countly();

  private context: common.UIAbilityContext | null = null;
  private initialized: boolean = false;
  private config: CountlyConfig | null = null;
  private storage: StorageManager = new StorageManager();
  private deviceInfo: DeviceInfoProvider = new DeviceInfoProvider();
  private requestQueue: RequestQueue | null = null;

  private deviceIdModule: ModuleDeviceId | null = null;
  private consentModule: ModuleConsent | null = null;
  private eventsModule: ModuleEvents | null = null;
  private sessionsModule: ModuleSessions | null = null;
  private viewsModule: ModuleViews | null = null;
  private userProfileModule: ModuleUserProfile | null = null;
  private crashModule: ModuleCrash | null = null;
  private locationModule: ModuleLocation | null = null;
  private remoteConfigModule: ModuleRemoteConfig | null = null;
  private feedbackModule: ModuleFeedback | null = null;

  private constructor() {
  }

  static sharedInstance(): Countly {
    return Countly.instanceRef;
  }

  async init(context: common.UIAbilityContext, payload: CountlyConfigPayload): Promise<void> {
    if (this.initialized) {
      return;
    }
    this.context = context;
    this.config = CountlyConfig.fromPayload(payload);
    CountlyLogger.setEnabled(this.config.loggingEnabled);
    CountlyLogger.info('init called');
    if (this.config.deviceID.length === 0) {
      this.config.deviceID = this.generateDeviceId();
    }

    await this.storage.init(context);
    this.deviceInfo.init();

    this.deviceIdModule = new ModuleDeviceId(this.storage);
    await this.deviceIdModule.init(this.config.deviceID);
    this.config.deviceID = this.deviceIdModule.getID();

    this.consentModule = new ModuleConsent(this.storage);
    await this.consentModule.init(this.config.requiresConsent, this.config.enableAllConsents);

    this.requestQueue = new RequestQueue(this.config, this.storage, this.deviceInfo);
    await this.requestQueue.init();

    this.eventsModule = new ModuleEvents(this.requestQueue, this.consentModule);
    this.sessionsModule = new ModuleSessions(this.requestQueue, this.consentModule);
    this.sessionsModule.setManualSessionEnabled(this.config.manualSessionEnabled);
    this.viewsModule = new ModuleViews(this.requestQueue, this.consentModule);
    this.userProfileModule = new ModuleUserProfile(this.requestQueue, this.consentModule);
    this.crashModule = new ModuleCrash(this.requestQueue, this.consentModule);
    this.locationModule = new ModuleLocation(this.config);
    this.remoteConfigModule = new ModuleRemoteConfig(this.storage);
    await this.remoteConfigModule.init();
    this.feedbackModule = new ModuleFeedback();

    if (this.config.enableUnhandledCrashReporting) {
      this.crashModule.enable();
    }
    if (this.config.customCrashSegment != null) {
      this.crashModule.setCustomSegment(this.config.customCrashSegment);
    }

    this.initialized = true;
    await this.requestQueue.flushQueue();
    CountlyLogger.info('sdk initialized');

    if (!this.config.manualSessionEnabled) {
      await this.sessionsModule.beginSession();
    }
  }

  isInitialized(): boolean {
    return this.initialized;
  }

  async halt(): Promise<void> {
    CountlyLogger.info('halt called');
    if (this.requestQueue != null) {
      await this.requestQueue.clearQueue();
    }
    this.initialized = false;
    this.context = null;
    this.config = null;
    this.requestQueue = null;
    this.deviceIdModule = null;
    this.consentModule = null;
    this.eventsModule = null;
    this.sessionsModule = null;
    this.viewsModule = null;
    this.userProfileModule = null;
    this.crashModule = null;
    this.locationModule = null;
    this.remoteConfigModule = null;
    this.feedbackModule = null;
  }

  getDeviceIdModule(): ModuleDeviceId {
    this.requireInit();
    return this.deviceIdModule as ModuleDeviceId;
  }

  getConsentModule(): ModuleConsent {
    this.requireInit();
    return this.consentModule as ModuleConsent;
  }

  getEventsModule(): ModuleEvents {
    this.requireInit();
    return this.eventsModule as ModuleEvents;
  }

  getSessionsModule(): ModuleSessions {
    this.requireInit();
    return this.sessionsModule as ModuleSessions;
  }

  getViewsModule(): ModuleViews {
    this.requireInit();
    return this.viewsModule as ModuleViews;
  }

  getUserProfileModule(): ModuleUserProfile {
    this.requireInit();
    return this.userProfileModule as ModuleUserProfile;
  }

  getCrashModule(): ModuleCrash {
    this.requireInit();
    return this.crashModule as ModuleCrash;
  }

  getLocationModule(): ModuleLocation {
    this.requireInit();
    return this.locationModule as ModuleLocation;
  }

  getRemoteConfigModule(): ModuleRemoteConfig {
    this.requireInit();
    return this.remoteConfigModule as ModuleRemoteConfig;
  }

  getFeedbackModule(): ModuleFeedback {
    this.requireInit();
    return this.feedbackModule as ModuleFeedback;
  }

  async appLoadingFinished(): Promise<void> {
    if (!this.initialized) {
      return;
    }
    const params = new Map<string, string>();
    params.set('events', '[{"key":"[CLY]_app_start","count":1}]');
    await (this.requestQueue as RequestQueue).sendOrQueue(params);
  }

  async setLoggingEnabled(enabled: boolean): Promise<void> {
    if (!this.initialized || this.config == null) {
      return;
    }
    this.config.loggingEnabled = enabled;
    CountlyLogger.setEnabled(enabled);
  }

  async enableApm(): Promise<void> {
    if (!this.initialized || this.config == null) {
      return;
    }
    this.config.enableForegroundBackground = true;
    this.config.enableManualAppLoaded = true;
  }

  async flushRequests(): Promise<void> {
    if (this.requestQueue != null) {
      await this.requestQueue.flushQueue();
    }
  }

  private requireInit(): void {
    if (!this.initialized) {
      throw new Error('Countly SDK is not initialized');
    }
  }

  private generateDeviceId(): string {
    const now = Date.now().toString();
    const random = Math.floor(Math.random() * 1000000).toString();
    return 'ohos_' + now + '_' + random;
  }
}
