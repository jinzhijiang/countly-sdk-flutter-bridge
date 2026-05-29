import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';
import { common } from '@kit.AbilityKit';
import { Countly } from './sdk/Countly';
import { CountlyConfigPayload } from './sdk/CountlyConfig';
import { RCDataValue } from './sdk/ModuleRemoteConfig';

const METHOD_CHANNEL_NAME = 'countly_flutter';

interface FeedbackWidgetBridgeData {
  id: string;
  type: string;
  name: string;
}

interface FeedbackWidgetDetailData {
  id: string;
  type: string;
  name: string;
  ohos: boolean;
}

interface FeedbackWidgetCallbackData {
  error: string | null;
  widgetData: Object;
}

interface RemoteConfigDownloadPayload {
  requestResult: number;
  error: string | null;
  fullValueUpdate: boolean;
  downloadedValues: Record<string, RCDataValue>;
  id: number;
}

interface RemoteConfigVariantPayload {
  requestResult: number;
  error: string | null;
  id: number;
}

export class CountlyFlutterPlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;
  private abilityContext: common.UIAbilityContext | null = null;

  getUniqueClassName(): string {
    return 'CountlyFlutterPlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), METHOD_CHANNEL_NAME);
    this.channel.setMethodCallHandler(this);
    const appContext = binding.getApplicationContext();
    this.abilityContext = appContext as common.UIAbilityContext;
  }

  onDetachedFromEngine(_binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null);
      this.channel = null;
    }
    this.abilityContext = null;
  }

  async onMethodCall(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      switch (call.method) {
        case 'init':
          await this.handleInit(call, result);
          return;
        case 'isInitialized':
          result.success(Countly.sharedInstance().isInitialized() ? 'true' : 'false');
          return;
        case 'halt':
          await Countly.sharedInstance().halt();
          result.success('halted');
          return;
        case 'appLoadingFinished':
          await Countly.sharedInstance().appLoadingFinished();
          result.success('ok');
          return;
        case 'recordEvent':
          await this.handleRecordEvent(call, result);
          return;
        case 'startEvent':
          await this.handleStartEvent(call, result);
          return;
        case 'endEvent':
          await this.handleEndEvent(call, result);
          return;
        case 'cancelEvent':
          await this.handleCancelEvent(call, result);
          return;
        case 'beginSession':
          await Countly.sharedInstance().getSessionsModule().beginSession();
          result.success('ok');
          return;
        case 'updateSession':
          await Countly.sharedInstance().getSessionsModule().updateSession();
          result.success('ok');
          return;
        case 'endSession':
          await Countly.sharedInstance().getSessionsModule().endSession();
          result.success('ok');
          return;
        case 'setRequiresConsent':
          await this.handleSetRequiresConsent(call, result);
          return;
        case 'giveConsentInit':
          await this.handleGiveConsentInit(call, result);
          return;
        case 'giveConsent':
          await this.handleGiveConsent(call, result);
          return;
        case 'removeConsent':
          await this.handleRemoveConsent(call, result);
          return;
        case 'giveAllConsent':
          await Countly.sharedInstance().getConsentModule().giveAllConsent();
          result.success('ok');
          return;
        case 'removeAllConsent':
          await Countly.sharedInstance().getConsentModule().removeAllConsent();
          result.success('ok');
          return;
        case 'getID':
          result.success(Countly.sharedInstance().getDeviceIdModule().getID());
          return;
        case 'getIDType':
          result.success(Countly.sharedInstance().getDeviceIdModule().getIDTypeForBridge());
          return;
        case 'setID':
          await this.handleSetId(call, result);
          return;
        case 'changeWithMerge':
          await this.handleChangeWithMerge(call, result);
          return;
        case 'changeWithoutMerge':
          await this.handleChangeWithoutMerge(call, result);
          return;
        case 'enableTemporaryIDMode':
          await Countly.sharedInstance().getDeviceIdModule().enableTemporaryIDMode();
          result.success('ok');
          return;
        case 'userProfile_setProperties':
          await this.handleSetUserProfileProperties(call, result);
          return;
        case 'userProfile_setProperty':
          await this.handleSetUserProfileProperty(call, result);
          return;
        case 'userProfile_save':
          await Countly.sharedInstance().getUserProfileModule().save();
          result.success('ok');
          return;
        case 'userProfile_clear':
          Countly.sharedInstance().getUserProfileModule().clear();
          result.success('ok');
          return;
        case 'startView':
          await this.handleStartView(call, result);
          return;
        case 'startAutoStoppedView':
          await this.handleStartAutoStoppedView(call, result);
          return;
        case 'stopViewWithID':
          await this.handleStopViewWithId(call, result);
          return;
        case 'stopViewWithName':
          await this.handleStopViewWithName(call, result);
          return;
        case 'pauseViewWithID':
          await this.handlePauseView(call, result);
          return;
        case 'resumeViewWithID':
          await this.handleResumeView(call, result);
          return;
        case 'stopAllViews':
          await this.handleStopAllViews(call, result);
          return;
        case 'setGlobalViewSegmentation':
          await this.handleSetGlobalViewSegmentation(call, result);
          return;
        case 'updateGlobalViewSegmentation':
          await this.handleUpdateGlobalViewSegmentation(call, result);
          return;
        case 'addSegmentationToViewWithID':
          await this.handleAddSegmentationToViewWithId(call, result);
          return;
        case 'addSegmentationToViewWithName':
          await this.handleAddSegmentationToViewWithName(call, result);
          return;
        case 'setLocationInit':
          await this.handleSetLocationInit(call, result);
          return;
        case 'setUserLocation':
          await this.handleSetUserLocation(call, result);
          return;
        case 'disableLocation':
          Countly.sharedInstance().getLocationModule().disableLocation();
          result.success('ok');
          return;
        case 'setLoggingEnabled':
          await this.handleSetLoggingEnabled(call, result);
          return;
        case 'enableCrashReporting':
          Countly.sharedInstance().getCrashModule().enable();
          result.success('ok');
          return;
        case 'addCrashLog':
          await this.handleAddCrashLog(call, result);
          return;
        case 'setCustomCrashSegment':
          await this.handleSetCustomCrashSegment(call, result);
          return;
        case 'logException':
          await this.handleLogException(call, result);
          return;
        case 'enableApm':
          await Countly.sharedInstance().enableApm();
          result.success('ok');
          return;
        case 'enableParameterTamperingProtection':
          result.success('ok');
          return;
        case 'setRemoteConfigAutomaticDownload':
          await this.handleSetRemoteConfigAutomaticDownload(result);
          return;
        case 'remoteConfigUpdate':
          await this.handleRemoteConfigUpdate(result);
          return;
        case 'updateRemoteConfigForKeysOnly':
          await this.handleUpdateRemoteConfigForKeysOnly(call, result);
          return;
        case 'updateRemoteConfigExceptKeys':
          await this.handleUpdateRemoteConfigExceptKeys(call, result);
          return;
        case 'remoteConfigClearValues':
        case 'remoteConfigClearAllValues':
          await this.handleRemoteConfigClearValues(result);
          return;
        case 'getRemoteConfigValueForKey':
          await this.handleGetRemoteConfigValueForKey(call, result);
          return;
        case 'remoteConfigDownloadValues':
          await this.handleRemoteConfigDownloadValues(call, result);
          return;
        case 'remoteConfigDownloadSpecificValue':
          await this.handleRemoteConfigDownloadSpecificValue(call, result);
          return;
        case 'remoteConfigDownloadOmittingValues':
          await this.handleRemoteConfigDownloadOmittingValues(call, result);
          return;
        case 'remoteConfigGetAllValues':
          await this.handleRemoteConfigGetAllValues(result);
          return;
        case 'remoteConfigGetValue':
          await this.handleRemoteConfigGetValue(call, result);
          return;
        case 'remoteConfigGetValueAndEnroll':
          await this.handleRemoteConfigGetValueAndEnroll(call, result);
          return;
        case 'remoteConfigGetAllValuesAndEnroll':
          await this.handleRemoteConfigGetAllValuesAndEnroll(result);
          return;
        case 'remoteConfigEnrollIntoABTestsForKeys':
          await this.handleRemoteConfigEnrollIntoABTestsForKeys(call, result);
          return;
        case 'remoteConfigExitABTestsForKeys':
          await this.handleRemoteConfigExitABTestsForKeys(call, result);
          return;
        case 'remoteConfigTestingDownloadVariantInformation':
          await this.handleRemoteConfigTestingDownloadVariantInformation(call, result);
          return;
        case 'remoteConfigTestingEnrollIntoVariant':
          await this.handleRemoteConfigTestingEnrollIntoVariant(call, result);
          return;
        case 'remoteConfigTestingGetAllVariants':
          await this.handleRemoteConfigTestingGetAllVariants(result);
          return;
        case 'remoteConfigTestingGetVariantsForKey':
          await this.handleRemoteConfigTestingGetVariantsForKey(call, result);
          return;
        case 'testingDownloadExperimentInformation':
          await this.handleTestingDownloadExperimentInformation(call, result);
          return;
        case 'testingGetAllExperimentInfo':
          await this.handleTestingGetAllExperimentInfo(result);
          return;
        case 'setStarRatingDialogTexts':
          await this.handleSetStarRatingDialogTexts(call, result);
          return;
        case 'askForStarRating':
          await this.handleAskForStarRating(result);
          return;
        case 'presentRatingWidgetWithID':
          await this.handlePresentRatingWidgetWithID(call, result);
          return;
        case 'getAvailableFeedbackWidgets':
          await this.handleGetAvailableFeedbackWidgets(result);
          return;
        case 'presentFeedbackWidget':
          await this.handlePresentFeedbackWidget(call, result);
          return;
        case 'getFeedbackWidgetData':
          await this.handleGetFeedbackWidgetData(call, result);
          return;
        case 'reportFeedbackWidgetManually':
          await this.handleReportFeedbackWidgetManually(result);
          return;
        case 'presentNPS':
          await this.handlePresentFeedbackFlow('NPS', result);
          return;
        case 'presentRating':
          await this.handlePresentFeedbackFlow('Rating', result);
          return;
        case 'presentSurvey':
          await this.handlePresentFeedbackFlow('Survey', result);
          return;
        default:
          result.notImplemented();
          return;
      }
    } catch (e) {
      const message = e instanceof Error ? e.message : String(e);
      result.error('CountlyFlutterPlugin', call.method, message);
    }
  }

  private async handleInit(call: MethodCall, result: MethodResult): Promise<void> {
    if (this.abilityContext == null) {
      result.error('CountlyFlutterPlugin', 'init', 'ability context is null');
      return;
    }
    const args = this.parseDataArgs(call);
    if (args.length === 0) {
      result.error('CountlyFlutterPlugin', 'init', 'missing config payload');
      return;
    }
    const payload = args[0] as CountlyConfigPayload;
    if (payload.appKey == null || payload.serverURL == null) {
      result.error('CountlyFlutterPlugin', 'init', 'appKey/serverURL is required');
      return;
    }
    await Countly.sharedInstance().init(this.abilityContext, payload);
    result.success('initialized');
  }

  private async handleRecordEvent(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.parseDataArgs(call);
    const key = this.stringAt(args, 0);
    const count = this.intAt(args, 1, 1);
    const sum = this.doubleAt(args, 2, 0.0);
    const duration = this.intAt(args, 3, 0);
    const segmentation = this.objectAt(args, 4);
    await Countly.sharedInstance().getEventsModule().recordEvent(key, count, sum, duration, segmentation);
    result.success('ok');
  }

  private async handleStartEvent(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.parseDataArgs(call);
    const key = this.stringAt(args, 0);
    Countly.sharedInstance().getEventsModule().startEvent(key);
    result.success('ok');
  }

  private async handleEndEvent(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.parseDataArgs(call);
    const key = this.stringAt(args, 0);
    const count = this.intAt(args, 1, 1);
    const sum = this.doubleAt(args, 2, 0.0);
    const segmentation = this.objectAt(args, 3);
    await Countly.sharedInstance().getEventsModule().endEvent(key, count, sum, segmentation);
    result.success('ok');
  }

  private async handleCancelEvent(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.parseDataArgs(call);
    const key = this.stringAt(args, 0);
    Countly.sharedInstance().getEventsModule().cancelEvent(key);
    result.success('ok');
  }

  private async handleSetRequiresConsent(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.parseDataArgs(call);
    const requiresConsent = this.boolAt(args, 0);
    await Countly.sharedInstance().getConsentModule().setRequiresConsent(requiresConsent);
    result.success('ok');
  }

  private async handleGiveConsentInit(call: MethodCall, result: MethodResult): Promise<void> {
    const features = this.parseStringArrayArgs(call);
    await Countly.sharedInstance().getConsentModule().giveConsentInit(features);
    result.success('ok');
  }

  private async handleGiveConsent(call: MethodCall, result: MethodResult): Promise<void> {
    const features = this.parseStringArrayArgs(call);
    await Countly.sharedInstance().getConsentModule().giveConsent(features);
    result.success('ok');
  }

  private async handleRemoveConsent(call: MethodCall, result: MethodResult): Promise<void> {
    const features = this.parseStringArrayArgs(call);
    await Countly.sharedInstance().getConsentModule().removeConsent(features);
    result.success('ok');
  }

  private async handleSetId(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.parseDataArgs(call);
    const deviceId = this.stringAt(args, 0);
    await Countly.sharedInstance().getDeviceIdModule().setID(deviceId);
    result.success('ok');
  }

  private async handleChangeWithMerge(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.parseDataArgs(call);
    const deviceId = this.stringAt(args, 0);
    await Countly.sharedInstance().getDeviceIdModule().changeWithMerge(deviceId);
    result.success('ok');
  }

  private async handleChangeWithoutMerge(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.parseDataArgs(call);
    const deviceId = this.stringAt(args, 0);
    await Countly.sharedInstance().getDeviceIdModule().changeWithoutMerge(deviceId);
    result.success('ok');
  }

  private async handleSetUserProfileProperties(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.parseDataArgs(call);
    if (args.length > 0) {
      Countly.sharedInstance().getUserProfileModule().setPropertiesRaw(args[0]);
    }
    result.success('ok');
  }

  private async handleSetUserProfileProperty(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.parseDataArgs(call);
    if (args.length < 2) {
      result.success('ok');
      return;
    }
    const key = this.stringAt(args, 0);
    Countly.sharedInstance().getUserProfileModule().setProperty(key, args[1]);
    result.success('ok');
  }

  private async handleStartView(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.parseDataArgs(call);
    const viewName = this.stringAt(args, 0);
    const segmentation = this.objectAt(args, 1);
    const viewId = await Countly.sharedInstance().getViewsModule().startView(viewName, segmentation);
    result.success(viewId);
  }

  private async handleStartAutoStoppedView(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.parseDataArgs(call);
    const viewName = this.stringAt(args, 0);
    const segmentation = this.objectAt(args, 1);
    const viewId = await Countly.sharedInstance().getViewsModule().startAutoStoppedView(viewName, segmentation);
    result.success(viewId);
  }

  private async handleStopViewWithId(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.parseDataArgs(call);
    const viewId = this.stringAt(args, 0);
    const segmentation = this.objectAt(args, 1);
    await Countly.sharedInstance().getViewsModule().stopViewWithID(viewId, segmentation);
    result.success('ok');
  }

  private async handleStopViewWithName(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.parseDataArgs(call);
    const viewName = this.stringAt(args, 0);
    const segmentation = this.objectAt(args, 1);
    await Countly.sharedInstance().getViewsModule().stopViewWithName(viewName, segmentation);
    result.success('ok');
  }

  private async handlePauseView(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.parseDataArgs(call);
    const viewId = this.stringAt(args, 0);
    Countly.sharedInstance().getViewsModule().pauseViewWithID(viewId);
    result.success('ok');
  }

  private async handleResumeView(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.parseDataArgs(call);
    const viewId = this.stringAt(args, 0);
    Countly.sharedInstance().getViewsModule().resumeViewWithID(viewId);
    result.success('ok');
  }

  private async handleStopAllViews(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.parseDataArgs(call);
    const segmentation = this.objectAt(args, 0);
    await Countly.sharedInstance().getViewsModule().stopAllViews(segmentation);
    result.success('ok');
  }

  private async handleSetGlobalViewSegmentation(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.parseDataArgs(call);
    if (args.length > 0) {
      Countly.sharedInstance().getViewsModule().setGlobalViewSegmentation(args[0]);
    }
    result.success('ok');
  }

  private async handleUpdateGlobalViewSegmentation(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.parseDataArgs(call);
    if (args.length > 0) {
      Countly.sharedInstance().getViewsModule().updateGlobalViewSegmentation(args[0]);
    }
    result.success('ok');
  }

  private async handleAddSegmentationToViewWithId(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.parseDataArgs(call);
    if (args.length >= 2) {
      const viewId = this.stringAt(args, 0);
      Countly.sharedInstance().getViewsModule().addSegmentationToViewWithID(viewId, args[1]);
    }
    result.success('ok');
  }

  private async handleAddSegmentationToViewWithName(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.parseDataArgs(call);
    if (args.length >= 2) {
      const viewName = this.stringAt(args, 0);
      Countly.sharedInstance().getViewsModule().addSegmentationToViewWithName(viewName, args[1]);
    }
    result.success('ok');
  }

  private async handleSetLocationInit(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.parseDataArgs(call);
    const countryCode = this.stringAt(args, 0);
    const city = this.stringAt(args, 1);
    const gpsCoordinates = this.stringAt(args, 2);
    const ipAddress = this.stringAt(args, 3);
    Countly.sharedInstance().getLocationModule().setLocation(countryCode, city, gpsCoordinates, ipAddress);
    result.success('ok');
  }

  private async handleSetUserLocation(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.parseDataArgs(call);
    if (args.length > 0) {
      Countly.sharedInstance().getLocationModule().setUserLocation(args[0]);
    }
    result.success('ok');
  }

  private async handleSetLoggingEnabled(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.parseDataArgs(call);
    const enabled = this.boolAt(args, 0);
    await Countly.sharedInstance().setLoggingEnabled(enabled);
    result.success('ok');
  }

  private async handleAddCrashLog(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.parseDataArgs(call);
    const message = this.stringAt(args, 0);
    Countly.sharedInstance().getCrashModule().addCrashLog(message);
    result.success('ok');
  }

  private async handleSetCustomCrashSegment(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.parseDataArgs(call);
    const segment = this.pairsToObject(args);
    Countly.sharedInstance().getCrashModule().setCustomSegment(segment);
    result.success('ok');
  }

  private async handleLogException(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.parseDataArgs(call);
    const exception = this.stringAt(args, 0);
    const nonfatal = this.boolAt(args, 1);
    const segmentation = this.pairsToObject(this.slice(args, 2));
    await Countly.sharedInstance().getCrashModule().logException(exception, nonfatal, segmentation);
    result.success('ok');
  }

  private async handleSetRemoteConfigAutomaticDownload(result: MethodResult): Promise<void> {
    Countly.sharedInstance().getRemoteConfigModule().setAutomaticDownloadEnabled(true);
    await this.invokeDart('remoteConfigCallback', null);
    result.success('ok');
  }

  private async handleRemoteConfigUpdate(result: MethodResult): Promise<void> {
    await Countly.sharedInstance().getRemoteConfigModule().updateAll();
    await this.invokeDart('remoteConfigCallback', null);
    result.success('ok');
  }

  private async handleUpdateRemoteConfigForKeysOnly(call: MethodCall, result: MethodResult): Promise<void> {
    const keys = this.parseStringArrayArgs(call);
    await Countly.sharedInstance().getRemoteConfigModule().updateForKeysOnly(keys);
    await this.invokeDart('remoteConfigCallback', null);
    result.success('ok');
  }

  private async handleUpdateRemoteConfigExceptKeys(call: MethodCall, result: MethodResult): Promise<void> {
    const keys = this.parseStringArrayArgs(call);
    await Countly.sharedInstance().getRemoteConfigModule().updateExceptKeys(keys);
    await this.invokeDart('remoteConfigCallback', null);
    result.success('ok');
  }

  private async handleRemoteConfigClearValues(result: MethodResult): Promise<void> {
    await Countly.sharedInstance().getRemoteConfigModule().clearAll();
    await this.invokeDart('remoteConfigCallback', null);
    result.success('ok');
  }

  private async handleGetRemoteConfigValueForKey(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.parseDataArgs(call);
    const key = this.stringAt(args, 0);
    const valueData = Countly.sharedInstance().getRemoteConfigModule().getValue(key);
    const value = valueData.value;
    if (typeof value === 'string') {
      result.success(value);
      return;
    }
    if (typeof value === 'number' || typeof value === 'boolean') {
      result.success(String(value));
      return;
    }
    result.success(null);
  }

  private async handleRemoteConfigDownloadValues(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.parseDataArgs(call);
    const requestId = this.intAt(args, 0, -1);
    const downloaded = Countly.sharedInstance().getRemoteConfigModule().getAllValues();
    await this.notifyRemoteConfigDownload(requestId, downloaded);
    result.success('ok');
  }

  private async handleRemoteConfigDownloadSpecificValue(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.parseDataArgs(call);
    const requestId = this.intAt(args, 0, -1);
    const keys = this.objectStringArrayAt(args, 1);
    const downloaded = await Countly.sharedInstance().getRemoteConfigModule().updateForKeysOnly(keys);
    await this.notifyRemoteConfigDownload(requestId, downloaded);
    result.success('ok');
  }

  private async handleRemoteConfigDownloadOmittingValues(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.parseDataArgs(call);
    const requestId = this.intAt(args, 0, -1);
    const keys = this.objectStringArrayAt(args, 1);
    const downloaded = await Countly.sharedInstance().getRemoteConfigModule().updateExceptKeys(keys);
    await this.notifyRemoteConfigDownload(requestId, downloaded);
    result.success('ok');
  }

  private async handleRemoteConfigGetAllValues(result: MethodResult): Promise<void> {
    const values = Countly.sharedInstance().getRemoteConfigModule().getAllValues();
    result.success(this.toRcMapObject(values));
  }

  private async handleRemoteConfigGetValue(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.parseDataArgs(call);
    const key = this.stringAt(args, 0);
    const value = Countly.sharedInstance().getRemoteConfigModule().getValue(key);
    result.success(this.toRcDataObject(value));
  }

  private async handleRemoteConfigGetValueAndEnroll(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.parseDataArgs(call);
    const key = this.stringAt(args, 0);
    await Countly.sharedInstance().getRemoteConfigModule().enrollIntoABTestsForKeys([key]);
    const value = Countly.sharedInstance().getRemoteConfigModule().getValue(key);
    result.success(this.toRcDataObject(value));
  }

  private async handleRemoteConfigGetAllValuesAndEnroll(result: MethodResult): Promise<void> {
    const values = Countly.sharedInstance().getRemoteConfigModule().getAllValues();
    const keys: Array<string> = [];
    values.forEach((_value, key) => {
      keys.push(key);
    });
    await Countly.sharedInstance().getRemoteConfigModule().enrollIntoABTestsForKeys(keys);
    result.success(this.toRcMapObject(values));
  }

  private async handleRemoteConfigEnrollIntoABTestsForKeys(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.parseDataArgs(call);
    const keys = this.objectStringArrayAt(args, 0);
    await Countly.sharedInstance().getRemoteConfigModule().enrollIntoABTestsForKeys(keys);
    result.success('ok');
  }

  private async handleRemoteConfigExitABTestsForKeys(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.parseDataArgs(call);
    const keys = this.objectStringArrayAt(args, 0);
    await Countly.sharedInstance().getRemoteConfigModule().exitABTestsForKeys(keys);
    result.success('ok');
  }

  private async handleRemoteConfigTestingDownloadVariantInformation(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.parseDataArgs(call);
    const requestId = this.intAt(args, 0, -1);
    await this.notifyRemoteConfigVariant(requestId);
    result.success('ok');
  }

  private async handleRemoteConfigTestingEnrollIntoVariant(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.parseDataArgs(call);
    const requestId = this.intAt(args, 0, -1);
    const keyName = this.stringAt(args, 1);
    const variantName = this.stringAt(args, 2);
    await Countly.sharedInstance().getRemoteConfigModule().enrollIntoVariant(keyName, variantName);
    await this.notifyRemoteConfigVariant(requestId);
    result.success('ok');
  }

  private async handleRemoteConfigTestingGetAllVariants(result: MethodResult): Promise<void> {
    const variants = Countly.sharedInstance().getRemoteConfigModule().getAllVariants();
    const response: Record<string, Object> = {};
    variants.forEach((value: Array<string>, key: string) => {
      response[key] = value;
    });
    result.success(response);
  }

  private async handleRemoteConfigTestingGetVariantsForKey(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.parseDataArgs(call);
    const key = this.stringAt(args, 0);
    const variants = Countly.sharedInstance().getRemoteConfigModule().getVariantsForKey(key);
    result.success(variants);
  }

  private async handleTestingDownloadExperimentInformation(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.parseDataArgs(call);
    const requestId = this.intAt(args, 0, -1);
    await this.notifyRemoteConfigVariant(requestId);
    result.success('ok');
  }

  private async handleTestingGetAllExperimentInfo(result: MethodResult): Promise<void> {
    result.success([]);
  }

  private async handleSetStarRatingDialogTexts(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.parseDataArgs(call);
    const title = this.stringAt(args, 0);
    const message = this.stringAt(args, 1);
    const dismiss = this.stringAt(args, 2);
    Countly.sharedInstance().getFeedbackModule().setStarRatingDialogTexts(title, message, dismiss);
    result.success('ok');
  }

  private async handleAskForStarRating(result: MethodResult): Promise<void> {
    await this.invokeDart('ratingWidgetCallback', null);
    result.success('ok');
  }

  private async handlePresentRatingWidgetWithID(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.parseDataArgs(call);
    const widgetId = this.stringAt(args, 0);
    const widget = Countly.sharedInstance().getFeedbackModule().findWidgetById(widgetId);
    const callbackValue = widget == null ? 'rating widget not found' : null;
    await this.invokeDart('ratingWidgetCallback', callbackValue);
    result.success('ok');
  }

  private async handleGetAvailableFeedbackWidgets(result: MethodResult): Promise<void> {
    const widgets = Countly.sharedInstance().getFeedbackModule().getAvailableWidgets();
    const response: Array<FeedbackWidgetBridgeData> = [];
    for (let i = 0; i < widgets.length; i++) {
      const item = widgets[i];
      const widgetData: FeedbackWidgetBridgeData = {
        id: item.id,
        type: item.type,
        name: item.name
      };
      response.push(widgetData);
    }
    result.success(response);
  }

  private async handlePresentFeedbackWidget(_call: MethodCall, result: MethodResult): Promise<void> {
    await this.invokeDart('widgetShown', null);
    await this.invokeDart('widgetClosed', null);
    result.success('ok');
  }

  private async handleGetFeedbackWidgetData(call: MethodCall, result: MethodResult): Promise<void> {
    const args = this.parseDataArgs(call);
    const widgetId = this.stringAt(args, 0);
    const widget = Countly.sharedInstance().getFeedbackModule().findWidgetById(widgetId);
    if (widget == null) {
      const emptyWidgetData: Record<string, Object> = {};
      const callbackData: FeedbackWidgetCallbackData = {
        error: 'widget not found',
        widgetData: emptyWidgetData
      };
      await this.invokeDart('feedbackWidgetDataCallback', callbackData);
      result.success(emptyWidgetData);
      return;
    }
    const widgetData: FeedbackWidgetDetailData = {
      id: widget.id,
      type: widget.type,
      name: widget.name,
      ohos: true
    };
    const callbackData: FeedbackWidgetCallbackData = {
      error: null,
      widgetData: widgetData
    };
    await this.invokeDart('feedbackWidgetDataCallback', callbackData);
    result.success(widgetData);
  }

  private async handleReportFeedbackWidgetManually(result: MethodResult): Promise<void> {
    result.success('ok');
  }

  private async handlePresentFeedbackFlow(flowName: string, result: MethodResult): Promise<void> {
    await this.invokeDart('feedbackCallback_onFinished', flowName + ' finished');
    await this.invokeDart('feedbackCallback_onClosed', null);
    result.success('ok');
  }

  private async notifyRemoteConfigDownload(
    requestId: number,
    downloaded: Map<string, RCDataValue>
  ): Promise<void> {
    const payload: RemoteConfigDownloadPayload = {
      requestResult: 0,
      error: null,
      fullValueUpdate: true,
      downloadedValues: this.toRcMapObject(downloaded),
      id: requestId
    };
    await this.invokeDart('remoteConfigDownloadCallback', payload);
  }

  private async notifyRemoteConfigVariant(requestId: number): Promise<void> {
    const payload: RemoteConfigVariantPayload = {
      requestResult: 0,
      error: null,
      id: requestId
    };
    await this.invokeDart('remoteConfigVariantCallback', payload);
  }

  private toRcMapObject(values: Map<string, RCDataValue>): Record<string, RCDataValue> {
    const map: Record<string, RCDataValue> = {};
    values.forEach((value, key) => {
      map[key] = this.toRcDataObject(value);
    });
    return map;
  }

  private toRcDataObject(value: RCDataValue): RCDataValue {
    const rcValue: RCDataValue = {
      value: value.value,
      isCurrentUsersData: value.isCurrentUsersData
    };
    return rcValue;
  }

  private objectStringArrayAt(args: Array<Object>, index: number): Array<string> {
    if (index >= args.length) {
      return [];
    }
    const value = args[index];
    if (!Array.isArray(value)) {
      return [];
    }
    const list = value as Array<Object>;
    const result: Array<string> = [];
    for (let i = 0; i < list.length; i++) {
      const item = list[i];
      if (typeof item === 'string') {
        result.push(item);
      }
    }
    return result;
  }

  private async invokeDart(method: string, args: Object | null): Promise<void> {
    if (this.channel == null) {
      return;
    }
    await this.channel.invokeMethod(method, args);
  }

  private parseStringArrayArgs(call: MethodCall): Array<string> {
    const data = call.argument('data') as string | null;
    if (data == null || data.length === 0) {
      return [];
    }
    try {
      const parsed = JSON.parse(data) as Object;
      if (!Array.isArray(parsed)) {
        return [];
      }
      const parsedList = parsed as Array<Object>;
      const values: Array<string> = [];
      for (let i = 0; i < parsedList.length; i++) {
        const value = parsedList[i];
        if (typeof value === 'string') {
          values.push(value);
        }
      }
      return values;
    } catch (_) {
      return [];
    }
  }

  private parseDataArgs(call: MethodCall): Array<Object> {
    const data = call.argument('data') as string | null;
    if (data == null || data.length === 0) {
      return [];
    }
    try {
      const parsed = JSON.parse(data) as Object;
      if (Array.isArray(parsed)) {
        return parsed as Array<Object>;
      }
    } catch (_) {
    }
    return [];
  }

  private stringAt(args: Array<Object>, index: number): string {
    if (index >= args.length) {
      return '';
    }
    const value = args[index];
    if (typeof value === 'string') {
      return value;
    }
    return String(value);
  }

  private intAt(args: Array<Object>, index: number, fallback: number): number {
    if (index >= args.length) {
      return fallback;
    }
    const value = args[index];
    if (typeof value === 'number') {
      return Math.floor(value);
    }
    if (typeof value === 'string') {
      const parsed = Number(value);
      if (!Number.isNaN(parsed)) {
        return Math.floor(parsed);
      }
    }
    return fallback;
  }

  private doubleAt(args: Array<Object>, index: number, fallback: number): number {
    if (index >= args.length) {
      return fallback;
    }
    const value = args[index];
    if (typeof value === 'number') {
      return value;
    }
    if (typeof value === 'string') {
      const parsed = Number(value);
      if (!Number.isNaN(parsed)) {
        return parsed;
      }
    }
    return fallback;
  }

  private boolAt(args: Array<Object>, index: number): boolean {
    if (index >= args.length) {
      return false;
    }
    const value = args[index];
    if (typeof value === 'boolean') {
      return value;
    }
    if (typeof value === 'string') {
      return value === 'true';
    }
    return false;
  }

  private objectAt(args: Array<Object>, index: number): Object | null {
    if (index >= args.length) {
      return null;
    }
    const value = args[index];
    if (typeof value === 'object' && value != null) {
      return value;
    }
    return null;
  }

  private slice(args: Array<Object>, start: number): Array<Object> {
    const values: Array<Object> = [];
    for (let i = start; i < args.length; i++) {
      values.push(args[i]);
    }
    return values;
  }

  private pairsToObject(args: Array<Object>): Object {
    const entries: Array<string> = [];
    let index = 0;
    while (index + 1 < args.length) {
      const key = String(args[index]);
      const value = String(args[index + 1]);
      entries.push(JSON.stringify(key) + ':' + JSON.stringify(value));
      index = index + 2;
    }
    const jsonText = '{' + entries.join(',') + '}';
    return JSON.parse(jsonText) as Object;
  }
}
