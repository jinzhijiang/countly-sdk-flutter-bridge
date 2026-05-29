import dataPreferences from '@ohos.data.preferences';
import { common } from '@kit.AbilityKit';

const STORE_NAME = 'countly_flutter_store';

export class StorageManager {
  private preferences: dataPreferences.Preferences | null = null;

  async init(context: common.UIAbilityContext): Promise<void> {
    this.preferences = await dataPreferences.getPreferences(context, STORE_NAME);
  }

  private ensurePreferences(): dataPreferences.Preferences {
    if (this.preferences == null) {
      throw new Error('StorageManager is not initialized');
    }
    return this.preferences;
  }

  async putString(key: string, value: string): Promise<void> {
    const prefs = this.ensurePreferences();
    prefs.put(key, value);
    await prefs.flush();
  }

  async getString(key: string, defaultValue: string): Promise<string> {
    const prefs = this.ensurePreferences();
    const value = await prefs.get(key, defaultValue);
    if (typeof value === 'string') {
      return value;
    }
    return defaultValue;
  }

  async putBoolean(key: string, value: boolean): Promise<void> {
    const prefs = this.ensurePreferences();
    prefs.put(key, value);
    await prefs.flush();
  }

  async getBoolean(key: string, defaultValue: boolean): Promise<boolean> {
    const prefs = this.ensurePreferences();
    const value = await prefs.get(key, defaultValue);
    if (typeof value === 'boolean') {
      return value;
    }
    return defaultValue;
  }

  async putNumber(key: string, value: number): Promise<void> {
    const prefs = this.ensurePreferences();
    prefs.put(key, value);
    await prefs.flush();
  }

  async getNumber(key: string, defaultValue: number): Promise<number> {
    const prefs = this.ensurePreferences();
    const value = await prefs.get(key, defaultValue);
    if (typeof value === 'number') {
      return value;
    }
    return defaultValue;
  }

  async delete(key: string): Promise<void> {
    const prefs = this.ensurePreferences();
    await prefs.delete(key);
    await prefs.flush();
  }
}
