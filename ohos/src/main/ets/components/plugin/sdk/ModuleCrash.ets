import { RequestQueue } from './RequestQueue';
import { ModuleConsent } from './ModuleConsent';

export class ModuleCrash {
  private requestQueue: RequestQueue;
  private consentModule: ModuleConsent;
  private enabled: boolean = false;
  private customSegment: Object | null = null;
  private breadcrumbs: Array<string> = [];

  constructor(requestQueue: RequestQueue, consentModule: ModuleConsent) {
    this.requestQueue = requestQueue;
    this.consentModule = consentModule;
  }

  enable(): void {
    this.enabled = true;
  }

  setCustomSegment(segment: Object): void {
    this.customSegment = segment;
  }

  addCrashLog(record: string): void {
    this.breadcrumbs.push(record);
    if (this.breadcrumbs.length > 20) {
      this.breadcrumbs.shift();
    }
  }

  async logException(exception: string, nonfatal: boolean, segmentation: Object | null): Promise<void> {
    if (!this.enabled) {
      return;
    }
    if (!this.consentModule.canCollect('crashes')) {
      return;
    }
    const params = new Map<string, string>();
    const customSegmentJson = this.customSegment != null ? JSON.stringify(this.customSegment) : '{}';
    const segmentationJson = segmentation != null ? JSON.stringify(segmentation) : '{}';
    const breadcrumbsJson = JSON.stringify(this.breadcrumbs);
    const crashJson = '{"_error":' + JSON.stringify(exception) +
      ',"_nonfatal":' + (nonfatal ? 'true' : 'false') +
      ',"_custom":' + customSegmentJson +
      ',"_segmentation":' + segmentationJson +
      ',"_logs":' + breadcrumbsJson + '}';
    params.set('crash', crashJson);
    await this.requestQueue.sendOrQueue(params);
  }
}
