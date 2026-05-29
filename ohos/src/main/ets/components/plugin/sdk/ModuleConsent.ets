import { StorageManager } from './StorageManager';

const STORAGE_KEY_REQUIRES_CONSENT = 'countly_requires_consent';
const STORAGE_KEY_ALL_GRANTED = 'countly_consent_all_granted';
const STORAGE_KEY_GRANTED_LIST = 'countly_consent_granted_list';

export class ModuleConsent {
  private storage: StorageManager;
  private requiresConsent: boolean = false;
  private allGranted: boolean = false;
  private grantedFeatures: Array<string> = [];

  constructor(storage: StorageManager) {
    this.storage = storage;
  }

  async init(requiresConsent: boolean, grantAllOnInit: boolean): Promise<void> {
    const storedRequires = await this.storage.getBoolean(STORAGE_KEY_REQUIRES_CONSENT, requiresConsent);
    const storedAllGranted = await this.storage.getBoolean(STORAGE_KEY_ALL_GRANTED, grantAllOnInit);
    const storedListText = await this.storage.getString(STORAGE_KEY_GRANTED_LIST, '[]');
    this.requiresConsent = storedRequires;
    this.allGranted = storedAllGranted;
    this.grantedFeatures = this.parseConsentList(storedListText);
    await this.persist();
  }

  async setRequiresConsent(value: boolean): Promise<void> {
    this.requiresConsent = value;
    await this.persist();
  }

  async giveConsentInit(features: Array<string>): Promise<void> {
    await this.giveConsent(features);
  }

  async giveConsent(features: Array<string>): Promise<void> {
    for (let i = 0; i < features.length; i++) {
      const feature = features[i];
      if (!this.grantedFeatures.includes(feature)) {
        this.grantedFeatures.push(feature);
      }
    }
    await this.persist();
  }

  async removeConsent(features: Array<string>): Promise<void> {
    this.grantedFeatures = this.grantedFeatures.filter((value: string) => !features.includes(value));
    this.allGranted = false;
    await this.persist();
  }

  async giveAllConsent(): Promise<void> {
    this.allGranted = true;
    await this.persist();
  }

  async removeAllConsent(): Promise<void> {
    this.allGranted = false;
    this.grantedFeatures = [];
    await this.persist();
  }

  canCollect(feature: string): boolean {
    if (!this.requiresConsent) {
      return true;
    }
    if (this.allGranted) {
      return true;
    }
    return this.grantedFeatures.includes(feature);
  }

  private parseConsentList(input: string): Array<string> {
    try {
      const parsed = JSON.parse(input) as Object;
      if (Array.isArray(parsed)) {
        const parsedList = parsed as Array<Object>;
        const values: Array<string> = [];
        for (let i = 0; i < parsedList.length; i++) {
          const value = parsedList[i];
          if (typeof value === 'string') {
            values.push(value);
          }
        }
        return values;
      }
    } catch (_) {
    }
    return [];
  }

  private async persist(): Promise<void> {
    await this.storage.putBoolean(STORAGE_KEY_REQUIRES_CONSENT, this.requiresConsent);
    await this.storage.putBoolean(STORAGE_KEY_ALL_GRANTED, this.allGranted);
    await this.storage.putString(STORAGE_KEY_GRANTED_LIST, JSON.stringify(this.grantedFeatures));
  }
}
