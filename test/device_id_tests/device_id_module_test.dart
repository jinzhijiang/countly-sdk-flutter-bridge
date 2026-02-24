import 'dart:convert';

import 'package:countly_flutter_lite/countly_flutter_lite.dart';
import 'package:countly_sdk_dart_core/src/constants.dart';
import 'package:countly_sdk_dart_core/src/networking.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class TestLogger implements SdkLogger {
  final List<String> logs = [];
  @override
  bool isEnabled(LogLevel level) => true;
  @override
  void log(LogLevel level, String message, {Object? error, StackTrace? stack}) {
    logs.add('[${level.name}] $message');
  }
}

class FakeResponseSuccess extends http.Response {
  FakeResponseSuccess({String body = '{"result":"Success"}', int status = 200}) : super(body, status);
}

class FakeNetworkClient extends NetworkClient {
  final List<Map<String, dynamic>> sent = [];
  FakeNetworkClient(String baseUrl) : super(baseUrl);
  @override
  Future<http.Response> makeRequest(Map<String, dynamic> data, String endPoint) async {
    sent.add({...data});
    // if sbs fetch, return empty config
    if (data['method'] == 'sc') {
      return FakeResponseSuccess(body: '{"c":{}}');
    }
    return FakeResponseSuccess();
  }

  @override
  Future<http.Response> makeSelectiveRequest(Map<String, dynamic> data) async {
    sent.add({...data});
    return FakeResponseSuccess();
  }
}

class MemoryBackedStorage {
  final Map<String, String> backing;
  MemoryBackedStorage(this.backing);

  CustomStorageMethods toMethods() {
    return CustomStorageMethods(
      read: (key) async => backing[key],
      write: (key, value) async => backing[key] = value,
      remove: (key) async => backing.remove(key),
      keys: () async => backing.keys.toList(),
    );
  }
}

Future<CountlyInstance> _createInstance({
  String? deviceId,
  Map<String, String>? storageBacking,
  StorageMode storageMode = StorageMode.persistent,
  bool startWithUnknownConsent = true,
  bool giveConsent = true,
  FakeNetworkClient? networkClient,
}) async {
  final logger = TestLogger();
  final client = networkClient ?? FakeNetworkClient('https://example.com');
  final cfg = CountlyConfig(
    appKey: 'app-key',
    serverUrl: 'https://example.com',
    deviceId: deviceId,
    storageMode: storageMode,
    storageMethods: storageBacking == null ? null : MemoryBackedStorage(storageBacking).toMethods(),
    startWithUnknownConsent: startWithUnknownConsent,
    giveConsent: giveConsent,
    enableSDKLogs: true,
    logLevel: LogLevel.verbose,
    networkClientOverride: networkClient,
  );
  final inst = await Countly.init(cfg);
  if (networkClient == null) {
    // Fallback override for tests that only need post-init capture.
    inst.debugOverrideNetworkClient = client;
  }
  addTearDown(() async {
    await Countly.disposeAll();
  });
  return inst;
}

void main() {
  group('Device ID initialization', () {
    test('uses stored device ID in preference to provided config ID', () async {
      final backing = <String, String>{
        'default_${StorageSubKeys.deviceId}': 'stored-id-123',
        'default_${StorageSubKeys.deviceIdType}': DeviceIdType.generated.toString(),
      };

      final sdk = await _createInstance(
        deviceId: 'provided-id-xyz',
        storageBacking: backing,
        storageMode: StorageMode.persistent,
        startWithUnknownConsent: true,
        giveConsent: false,
      );

      expect(sdk.deviceId, 'stored-id-123');
      expect(sdk.deviceIdType, DeviceIdType.generated);
      expect(backing['default_${StorageSubKeys.deviceId}'], 'stored-id-123');
      expect(backing['default_${StorageSubKeys.deviceIdType}'], DeviceIdType.generated.toString());
    });

    test('falls back to provided device ID when no stored ID exists', () async {
      final backing = <String, String>{};
      final sdk = await _createInstance(
        deviceId: 'provided-abc',
        storageBacking: backing,
        storageMode: StorageMode.persistent,
        startWithUnknownConsent: true,
        giveConsent: false,
      );

      expect(sdk.deviceId, 'provided-abc');
      expect(sdk.deviceIdType, DeviceIdType.provided);
      expect(backing['default_${StorageSubKeys.deviceId}'], 'provided-abc');
      expect(backing['default_${StorageSubKeys.deviceIdType}'], DeviceIdType.provided.toString());
    });

    test('generates device ID when neither stored nor provided', () async {
      final backing = <String, String>{};
      final sdk = await _createInstance(
        storageBacking: backing,
        storageMode: StorageMode.persistent,
        startWithUnknownConsent: true,
        giveConsent: false,
      );

      expect(sdk.deviceId, isNotNull);
      expect(sdk.deviceId!.isNotEmpty, isTrue);
      expect(sdk.deviceIdType, DeviceIdType.generated);
      expect(backing['default_${StorageSubKeys.deviceId}'], sdk.deviceId);
      expect(backing['default_${StorageSubKeys.deviceIdType}'], DeviceIdType.generated.toString());
    });
  });

  group('Device ID change flows', () {
    test('changeWithMerge updates ID and enqueues merge request', () async {
      final sdk = await _createInstance(
        deviceId: 'old-device',
        storageMode: StorageMode.memory,
        startWithUnknownConsent: true,
        giveConsent: false,
      );

      await sdk.id.changeWithMerge('');
      await sdk.id.changeWithMerge('new-device');
      await sdk.id.changeWithMerge('new-device'); // should be ignored

      expect(sdk.deviceId, 'new-device');
      expect(sdk.deviceIdType, DeviceIdType.provided);

      Map<String, dynamic>? mergeReq;
      for (final r in sdk.debugRequestQueueSnapshot) {
        if (r['old_device_id'] == 'old-device') {
          mergeReq = r;
          break;
        }
      }

      expect(mergeReq, isNotNull, reason: 'Merge request should be enqueued');
      expect(mergeReq!['device_id'], 'new-device');
      expect(mergeReq['app_key'], 'app-key');
    });

    test('changeWithoutMerge clears queues, resets consent, and switches ID', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(
        deviceId: 'initial-device',
        storageMode: StorageMode.memory,
        startWithUnknownConsent: false,
        giveConsent: true,
        networkClient: network,
      );

      // CHECKING INITIALIZATION REQUESTS
      final postInitRequests = List<Map<String, dynamic>>.from(network.sent);

      // Verify all post-init requests use initial device ID.
      expect(postInitRequests, isNotEmpty, reason: 'Init should send requests');
      for (final req in postInitRequests) {
        expect(req['device_id'], 'initial-device');
      }

      // Check for sbs (method='sc') and health check (hc). Consent, location and metrics are queued, not sent immediately.
      final hasSbsRequest = postInitRequests.any((r) => r['method'] == 'sc');
      final hasHcRequest = postInitRequests.any((r) => r['hc'] != null);
      final hasQueuedConsentInit = sdk.debugRequestQueueSnapshot.any((r) => r.containsKey('consent'));
      final hasQueuedLocationInit = sdk.debugRequestQueueSnapshot.any((r) => r.containsKey('location'));
      final hasQueuedMetricsInit = sdk.debugRequestQueueSnapshot.any((r) => r.containsKey('metrics'));
      expect(sdk.debugRequestQueueSnapshot.length, 3);
      expect(hasSbsRequest, isTrue, reason: 'SBS fetch should run after init');
      expect(hasHcRequest, isTrue, reason: 'Health check should run after init');
      expect(hasQueuedConsentInit, isTrue, reason: 'Consent request should be enqueued after init');
      expect(hasQueuedLocationInit, isTrue, reason: 'Location request should be enqueued after init');
      expect(hasQueuedMetricsInit, isTrue, reason: 'Metrics request should be enqueued after init');

      // PRE-ID-CHANGE tracking
      await sdk.events.record(key: 'pre_event');
      await sdk.views.startAutoStoppedView('Home');
      await Future.delayed(const Duration(milliseconds: 10));
      await sdk.views.startAutoStoppedView('Details');
      expect(sdk.debugEventQueueLength, greaterThan(0));

      // CHANGE ID WITHOUT MERGE
      await sdk.id.changeWithoutMerge('');
      await sdk.id.changeWithoutMerge('fresh-device');
      await sdk.id.changeWithoutMerge('fresh-device'); // should be ignored

      // pre-ID-change requests after device ID change (pre_event, Home, Details view).
      final preChangeRequests = List<Map<String, dynamic>>.from(network.sent);

      // Checking ID is changed correctly
      expect(sdk.deviceId, 'fresh-device');
      expect(sdk.deviceIdType, DeviceIdType.provided);
      expect(sdk.debugEventQueueLength, 0, reason: 'Old data should be cleared');
      expect(sdk.debugRequestQueueLength, 0, reason: 'Old requests should be cleared');

      // Verify pre-change requests were flushed with old device ID.
      expect(preChangeRequests, isNotEmpty, reason: 'Pre-change events should have been sent');

      final preEventKeys = <String>[];
      final viewEvents = <Map<String, dynamic>>[];
      for (final req in preChangeRequests.where((r) => r.containsKey('events'))) {
        expect(req['device_id'], 'initial-device', reason: 'Pre-change requests should use old device ID');
        final eventsJson = req['events'] as String;
        final events = jsonDecode(eventsJson) as List<dynamic>;
        for (final e in events) {
          preEventKeys.add(e['key'] as String);
          if (e['key'] == '[CLY]_view') {
            viewEvents.add(e as Map<String, dynamic>);
          }
        }
      }
      for (final req in preChangeRequests) {
        expect(req['device_id'], 'initial-device', reason: 'Pre-change requests should use old device ID');
      }
      expect(preEventKeys.length, 3, reason: 'There should be three pre-change events sent');
      expect(preEventKeys, contains('pre_event'), reason: 'Pre-change should include pre_event');
      expect(preEventKeys, contains('[CLY]_view'), reason: 'Pre-change should include view events');
      final viewNames = viewEvents.map((e) => e['segmentation']?['name'] as String?).toList();
      expect(viewNames, contains('Home'), reason: 'Home view should be in pre-change requests');
      expect(viewNames, contains('Details'), reason: 'Details view should be in pre-change requests');
      expect(preChangeRequests[2]['consent'], isNotNull, reason: 'Consent status should be included in pre-change requests');
      expect(preChangeRequests[3]['location'], "", reason: 'Empty location should be included in pre-change requests');
      expect(preChangeRequests[4]['metrics'], isNotNull, reason: 'Metrics should be included in pre-change requests');

      network.sent.clear();

      // 3) Check post-ID-change requests at the end.
      // Consent should be reset to allow recording under unknown-consent gating.
      await sdk.events.record(key: 'post_change_event');
      expect(sdk.debugEventQueueLength, 1);

      // Exit unknown consent so data can be sent, then verify payload uses new device id.
      await sdk.consents.giveConsent();
      await Future.delayed(const Duration(milliseconds: 50));
      final postChangeRequests = List<Map<String, dynamic>>.from(network.sent);
      expect(postChangeRequests, isNotEmpty, reason: 'Post-change requests should be sent after consent is restored');

      // Every post-change request should use the new device id.
      for (final req in postChangeRequests) {
        expect(req['device_id'], 'fresh-device');
      }

      // Ensure events payload includes the post-change event, and no stale pre-change events.
      final postEventKeys = <String>[];
      for (final req in postChangeRequests.where((r) => r.containsKey('events'))) {
        final eventsJson = req['events'] as String;
        final events = jsonDecode(eventsJson) as List<dynamic>;
        for (final e in events) {
          postEventKeys.add(e['key'] as String);
        }
      }
      expect(postEventKeys, contains('post_change_event'));
      expect(postEventKeys, isNot(contains('pre_event')));

      // Consent status should be recorded in the request queue.
      final hasQueuedConsent = sdk.debugRequestQueueSnapshot.any((r) => r.containsKey('consent'));
      expect(hasQueuedConsent, isTrue, reason: 'Consent request should be enqueued after exiting unknown state');

      // SBS fetch should run after consent; health check may already have run during init, so skip asserting it here.
      final hasSbsRequest2 = postChangeRequests.any((r) => r['method'] == 'sc');
      final hasHcRequest2 = postChangeRequests.any((r) => r['hc'] != null);
      expect(hasSbsRequest2, isTrue, reason: 'SBS fetch should run after consent');
      expect(hasHcRequest2, isFalse, reason: 'Health check should not run again after ID change');
    });

    test('changeWithoutMerge persists new device ID via custom storage', () async {
      final backing = <String, String>{};
      final sdk = await _createInstance(
        deviceId: 'old-id',
        storageBacking: backing,
        storageMode: StorageMode.persistent,
        startWithUnknownConsent: false,
        giveConsent: true,
      );

      await sdk.id.changeWithoutMerge('new-persisted-id');

      expect(backing['default_${StorageSubKeys.deviceId}'], 'new-persisted-id');
      expect(backing['default_${StorageSubKeys.deviceIdType}'], DeviceIdType.provided.toString());
      expect(sdk.deviceId, 'new-persisted-id');
      expect(sdk.deviceIdType, DeviceIdType.provided);
    });
  });
}
