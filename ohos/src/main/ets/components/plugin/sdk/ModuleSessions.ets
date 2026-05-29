import { RequestQueue } from './RequestQueue';
import { ModuleConsent } from './ModuleConsent';

export class ModuleSessions {
  private requestQueue: RequestQueue;
  private consentModule: ModuleConsent;
  private lastSessionStart: number = 0;
  private lastUpdateAt: number = 0;
  private manualSessionEnabled: boolean = false;

  constructor(requestQueue: RequestQueue, consentModule: ModuleConsent) {
    this.requestQueue = requestQueue;
    this.consentModule = consentModule;
  }

  setManualSessionEnabled(enabled: boolean): void {
    this.manualSessionEnabled = enabled;
  }

  isManualSessionEnabled(): boolean {
    return this.manualSessionEnabled;
  }

  async beginSession(): Promise<void> {
    if (!this.consentModule.canCollect('sessions')) {
      return;
    }
    this.lastSessionStart = Date.now();
    this.lastUpdateAt = this.lastSessionStart;
    const params = new Map<string, string>();
    params.set('begin_session', '1');
    await this.requestQueue.sendOrQueue(params);
  }

  async updateSession(): Promise<void> {
    if (!this.consentModule.canCollect('sessions')) {
      return;
    }
    if (this.lastSessionStart === 0) {
      return;
    }
    const now = Date.now();
    const duration = Math.max(1, Math.floor((now - this.lastUpdateAt) / 1000));
    this.lastUpdateAt = now;
    const params = new Map<string, string>();
    params.set('session_duration', duration.toString());
    await this.requestQueue.sendOrQueue(params);
  }

  async endSession(): Promise<void> {
    if (!this.consentModule.canCollect('sessions')) {
      return;
    }
    if (this.lastSessionStart === 0) {
      return;
    }
    const now = Date.now();
    const duration = Math.max(1, Math.floor((now - this.lastSessionStart) / 1000));
    const params = new Map<string, string>();
    params.set('end_session', '1');
    params.set('session_duration', duration.toString());
    await this.requestQueue.sendOrQueue(params);
    this.lastSessionStart = 0;
    this.lastUpdateAt = 0;
  }
}
