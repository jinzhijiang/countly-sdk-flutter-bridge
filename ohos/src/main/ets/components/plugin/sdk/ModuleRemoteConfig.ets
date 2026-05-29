import { StorageManager } from './StorageManager';

const STORAGE_KEY_REMOTE_CONFIG = 'countly_remote_config_values_v1';
const STORAGE_KEY_REMOTE_VARIANTS = 'countly_remote_variants_v1';

export interface RCDataValue {
  value: Object | null;
  isCurrentUsersData: boolean;
}

interface RemoteConfigStoredValueEntry {
  value: Object | null;
  isCurrentUsersData: boolean;
}

export class ModuleRemoteConfig {
  private storage: StorageManager;
  private values: Map<string, RCDataValue> = new Map<string, RCDataValue>();
  private variants: Map<string, Array<string>> = new Map<string, Array<string>>();
  private automaticDownloadEnabled: boolean = false;

  constructor(storage: StorageManager) {
    this.storage = storage;
  }

  async init(): Promise<void> {
    const valueText = await this.storage.getString(STORAGE_KEY_REMOTE_CONFIG, '{}');
    const variantText = await this.storage.getString(STORAGE_KEY_REMOTE_VARIANTS, '{}');
    this.values = this.parseValues(valueText);
    this.variants = this.parseVariants(variantText);
  }

  setAutomaticDownloadEnabled(enabled: boolean): void {
    this.automaticDownloadEnabled = enabled;
  }

  isAutomaticDownloadEnabled(): boolean {
    return this.automaticDownloadEnabled;
  }

  async clearAll(): Promise<void> {
    this.values.clear();
    this.variants.clear();
    await this.persist();
  }

  async updateAll(): Promise<Map<string, RCDataValue>> {
    return this.getAllValues();
  }

  async updateForKeysOnly(keys: Array<string>): Promise<Map<string, RCDataValue>> {
    const selected = new Map<string, RCDataValue>();
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      const value = this.values.get(key);
      if (value != null) {
        selected.set(key, value);
      }
    }
    return selected;
  }

  async updateExceptKeys(keys: Array<string>): Promise<Map<string, RCDataValue>> {
    const omitted = new Set<string>(keys);
    const selected = new Map<string, RCDataValue>();
    this.values.forEach((value: RCDataValue, key: string) => {
      if (!omitted.has(key)) {
        selected.set(key, value);
      }
    });
    return selected;
  }

  getAllValues(): Map<string, RCDataValue> {
    const snapshot = new Map<string, RCDataValue>();
    this.values.forEach((value: RCDataValue, key: string) => {
      snapshot.set(key, {
        value: value.value,
        isCurrentUsersData: value.isCurrentUsersData
      });
    });
    return snapshot;
  }

  getValue(key: string): RCDataValue {
    const value = this.values.get(key);
    if (value != null) {
      return value;
    }
    return {
      value: null,
      isCurrentUsersData: true
    };
  }

  getAllVariants(): Map<string, Array<string>> {
    const snapshot = new Map<string, Array<string>>();
    this.variants.forEach((value: Array<string>, key: string) => {
      const list: Array<string> = [];
      for (let i = 0; i < value.length; i++) {
        list.push(value[i]);
      }
      snapshot.set(key, list);
    });
    return snapshot;
  }

  getVariantsForKey(key: string): Array<string> {
    const variants = this.variants.get(key);
    if (variants == null) {
      return [];
    }
    const copied: Array<string> = [];
    for (let i = 0; i < variants.length; i++) {
      copied.push(variants[i]);
    }
    return copied;
  }

  async enrollIntoVariant(key: string, variant: string): Promise<void> {
    const current = this.values.get(key);
    if (current != null) {
      this.values.set(key, {
        value: variant,
        isCurrentUsersData: true
      });
    } else {
      this.values.set(key, {
        value: variant,
        isCurrentUsersData: true
      });
    }
    await this.persist();
  }

  async enrollIntoABTestsForKeys(keys: Array<string>): Promise<void> {
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      if (!this.values.has(key)) {
        this.values.set(key, {
          value: null,
          isCurrentUsersData: true
        });
      }
    }
    await this.persist();
  }

  async exitABTestsForKeys(_keys: Array<string>): Promise<void> {
    await this.persist();
  }

  async setValueForTesting(key: string, value: Object | null): Promise<void> {
    this.values.set(key, {
      value: value,
      isCurrentUsersData: true
    });
    await this.persist();
  }

  async setVariantsForTesting(key: string, values: Array<string>): Promise<void> {
    this.variants.set(key, values);
    await this.persist();
  }

  private parseValues(text: string): Map<string, RCDataValue> {
    const map = new Map<string, RCDataValue>();
    try {
      const parsedObject = JSON.parse(text) as Object;
      const record = parsedObject as Record<string, Object>;
      const keys = Object.keys(record);
      for (let i = 0; i < keys.length; i++) {
        const key = keys[i];
        const rawEntry = record[key] as Record<string, Object>;
        const value = rawEntry['value'] != null ? rawEntry['value'] : null;
        const isCurrentUsersData = rawEntry['isCurrentUsersData'] === true;
        map.set(key, {
          value: value,
          isCurrentUsersData: isCurrentUsersData
        });
      }
    } catch (_) {
    }
    return map;
  }

  private parseVariants(text: string): Map<string, Array<string>> {
    const map = new Map<string, Array<string>>();
    try {
      const parsedObject = JSON.parse(text) as Object;
      const record = parsedObject as Record<string, Object>;
      const keys = Object.keys(record);
      for (let i = 0; i < keys.length; i++) {
        const key = keys[i];
        const rawList = record[key] as Array<Object>;
        const list: Array<string> = [];
        for (let j = 0; j < rawList.length; j++) {
          const value = rawList[j];
          if (typeof value === 'string') {
            list.push(value);
          }
        }
        map.set(key, list);
      }
    } catch (_) {
    }
    return map;
  }

  private async persist(): Promise<void> {
    const valuesRecord: Record<string, RemoteConfigStoredValueEntry> = {};
    this.values.forEach((value: RCDataValue, key: string) => {
      const storedEntry: RemoteConfigStoredValueEntry = {
        value: value.value,
        isCurrentUsersData: value.isCurrentUsersData
      };
      valuesRecord[key] = storedEntry;
    });
    await this.storage.putString(STORAGE_KEY_REMOTE_CONFIG, JSON.stringify(valuesRecord));

    const variantsRecord: Record<string, Object> = {};
    this.variants.forEach((value: Array<string>, key: string) => {
      variantsRecord[key] = value;
    });
    await this.storage.putString(STORAGE_KEY_REMOTE_VARIANTS, JSON.stringify(variantsRecord));
  }
}
