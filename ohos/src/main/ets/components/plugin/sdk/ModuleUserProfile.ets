import { RequestQueue } from './RequestQueue';
import { ModuleConsent } from './ModuleConsent';

export class ModuleUserProfile {
  private requestQueue: RequestQueue;
  private consentModule: ModuleConsent;
  private currentPropertiesRaw: Object | null = null;

  constructor(requestQueue: RequestQueue, consentModule: ModuleConsent) {
    this.requestQueue = requestQueue;
    this.consentModule = consentModule;
  }

  setPropertiesRaw(propertiesRaw: Object): void {
    this.currentPropertiesRaw = propertiesRaw;
  }

  setProperty(key: string, value: Object): void {
    const propertyJson = '{"' + this.escape(key) + '":' + JSON.stringify(value) + '}';
    this.currentPropertiesRaw = JSON.parse(propertyJson) as Object;
  }

  increment(_key: string): void {
  }

  incrementBy(_key: string, _value: number): void {
  }

  multiply(_key: string, _value: number): void {
  }

  saveMax(_key: string, _value: number): void {
  }

  saveMin(_key: string, _value: number): void {
  }

  setOnce(_key: string, _value: string): void {
  }

  pushUnique(_key: string, _value: string): void {
  }

  push(_key: string, _value: string): void {
  }

  pull(_key: string, _value: string): void {
  }

  clear(): void {
    this.currentPropertiesRaw = null;
  }

  async save(): Promise<void> {
    if (!this.consentModule.canCollect('users')) {
      return;
    }
    if (this.currentPropertiesRaw == null) {
      return;
    }
    const params = new Map<string, string>();
    params.set('user_details', JSON.stringify(this.currentPropertiesRaw));
    await this.requestQueue.sendOrQueue(params);
  }

  private escape(value: string): string {
    return value.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
  }
}
