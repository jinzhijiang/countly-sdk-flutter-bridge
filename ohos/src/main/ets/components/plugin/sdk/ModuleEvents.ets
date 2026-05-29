import { RequestQueue } from './RequestQueue';
import { ModuleConsent } from './ModuleConsent';

interface EventTimer {
  key: string;
  startedAt: number;
}

export class ModuleEvents {
  private requestQueue: RequestQueue;
  private consentModule: ModuleConsent;
  private activeTimers: Map<string, EventTimer> = new Map<string, EventTimer>();

  constructor(requestQueue: RequestQueue, consentModule: ModuleConsent) {
    this.requestQueue = requestQueue;
    this.consentModule = consentModule;
  }

  async recordEvent(
    key: string,
    count: number,
    sum: number,
    duration: number,
    segmentation: Object | null
  ): Promise<void> {
    if (!this.consentModule.canCollect('events')) {
      return;
    }
    const segmentationJson = segmentation != null ? JSON.stringify(segmentation) : '{}';
    const eventJson = '{"key":' + JSON.stringify(key) +
      ',"count":' + count.toString() +
      ',"sum":' + sum.toString() +
      ',"dur":' + duration.toString() +
      ',"segmentation":' + segmentationJson + '}';
    const params = new Map<string, string>();
    params.set('events', '[' + eventJson + ']');
    await this.requestQueue.sendOrQueue(params);
  }

  startEvent(key: string): void {
    this.activeTimers.set(key, {
      key: key,
      startedAt: Date.now()
    });
  }

  async endEvent(key: string, count: number, sum: number, segmentation: Object | null): Promise<void> {
    const timer = this.activeTimers.get(key);
    let duration = 0;
    if (timer != null) {
      duration = Math.floor((Date.now() - timer.startedAt) / 1000);
      this.activeTimers.delete(key);
    }
    await this.recordEvent(key, count, sum, duration, segmentation);
  }

  cancelEvent(key: string): void {
    this.activeTimers.delete(key);
  }
}
