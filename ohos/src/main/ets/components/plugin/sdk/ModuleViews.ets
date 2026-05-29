import { RequestQueue } from './RequestQueue';
import { ModuleConsent } from './ModuleConsent';

interface ActiveView {
  id: string;
  name: string;
  startedAt: number;
  paused: boolean;
}

export class ModuleViews {
  private requestQueue: RequestQueue;
  private consentModule: ModuleConsent;
  private views: Map<string, ActiveView> = new Map<string, ActiveView>();
  private globalSegmentation: Object | null = null;
  private autoStoppedViewId: string = '';

  constructor(requestQueue: RequestQueue, consentModule: ModuleConsent) {
    this.requestQueue = requestQueue;
    this.consentModule = consentModule;
  }

  async startView(viewName: string, segmentation: Object | null): Promise<string> {
    const viewId = this.newViewId();
    this.views.set(viewId, {
      id: viewId,
      name: viewName,
      startedAt: Date.now(),
      paused: false
    });
    await this.recordViewStart(viewName, segmentation);
    return viewId;
  }

  async startAutoStoppedView(viewName: string, segmentation: Object | null): Promise<string> {
    if (this.autoStoppedViewId.length > 0) {
      await this.stopViewWithID(this.autoStoppedViewId, null);
    }
    const viewId = await this.startView(viewName, segmentation);
    this.autoStoppedViewId = viewId;
    return viewId;
  }

  async stopViewWithID(viewId: string, segmentation: Object | null): Promise<void> {
    const active = this.views.get(viewId);
    if (active == null) {
      return;
    }
    this.views.delete(viewId);
    await this.recordViewStop(active.name, active.startedAt, segmentation);
  }

  async stopViewWithName(viewName: string, segmentation: Object | null): Promise<void> {
    let targetId = '';
    this.views.forEach((value: ActiveView, key: string) => {
      if (value.name === viewName && targetId.length === 0) {
        targetId = key;
      }
    });
    if (targetId.length > 0) {
      await this.stopViewWithID(targetId, segmentation);
    }
  }

  pauseViewWithID(viewId: string): void {
    const active = this.views.get(viewId);
    if (active != null) {
      active.paused = true;
      this.views.set(viewId, active);
    }
  }

  resumeViewWithID(viewId: string): void {
    const active = this.views.get(viewId);
    if (active != null) {
      active.paused = false;
      this.views.set(viewId, active);
    }
  }

  async stopAllViews(segmentation: Object | null): Promise<void> {
    const ids: Array<string> = [];
    this.views.forEach((_value: ActiveView, key: string) => {
      ids.push(key);
    });
    for (let i = 0; i < ids.length; i++) {
      await this.stopViewWithID(ids[i], segmentation);
    }
  }

  setGlobalViewSegmentation(segmentation: Object): void {
    this.globalSegmentation = segmentation;
  }

  updateGlobalViewSegmentation(segmentation: Object): void {
    this.globalSegmentation = segmentation;
  }

  addSegmentationToViewWithID(_viewId: string, _segmentation: Object): void {
  }

  addSegmentationToViewWithName(_viewName: string, _segmentation: Object): void {
  }

  private async recordViewStart(viewName: string, segmentation: Object | null): Promise<void> {
    if (!this.consentModule.canCollect('views')) {
      return;
    }
    const params = new Map<string, string>();
    const eventSeg = segmentation != null ? JSON.stringify(segmentation) : '{}';
    const eventJson = '{"key":"[CLY]_view_start","count":1,"sum":0,"dur":0,"segmentation":{"name":' +
      JSON.stringify(viewName) + ',"segmentation":' + eventSeg + '}}';
    params.set('events', '[' + eventJson + ']');
    await this.requestQueue.sendOrQueue(params);
  }

  private async recordViewStop(viewName: string, startedAt: number, segmentation: Object | null): Promise<void> {
    if (!this.consentModule.canCollect('views')) {
      return;
    }
    const duration = Math.max(1, Math.floor((Date.now() - startedAt) / 1000));
    const params = new Map<string, string>();
    const eventSeg = segmentation != null ? JSON.stringify(segmentation) : '{}';
    const globalSeg = this.globalSegmentation != null ? JSON.stringify(this.globalSegmentation) : '{}';
    const eventJson = '{"key":"[CLY]_view_stop","count":1,"sum":0,"dur":' + duration.toString() +
      ',"segmentation":{"name":' + JSON.stringify(viewName) + ',"segmentation":' + eventSeg +
      ',"global":' + globalSeg + '}}';
    params.set('events', '[' + eventJson + ']');
    await this.requestQueue.sendOrQueue(params);
  }

  private newViewId(): string {
    const now = Date.now().toString();
    const random = Math.floor(Math.random() * 1000000).toString();
    return 'view_' + now + '_' + random;
  }
}
