import 'package:countly_flutter_lite/countly_flutter_lite.dart';
import 'package:countly_sdk_dart_core/src/networking.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

class FakeResponseSuccess extends http.Response {
  FakeResponseSuccess({String body = '{"result":"Success"}', int status = 200}) : super(body, status);
}

class FakeNetworkClient extends NetworkClient {
  final List<Map<String, dynamic>> sent = [];
  FakeNetworkClient(String baseUrl) : super(baseUrl);
  @override
  Future<http.Response> makeRequest(Map<String, dynamic> data, String endPoint) async {
    sent.add(Map<String, dynamic>.from(data));
    if (data['method'] == 'sc') {
      return FakeResponseSuccess(body: '{"c":{}}');
    }
    return FakeResponseSuccess();
  }

  @override
  Future<http.Response> makeSelectiveRequest(Map<String, dynamic> data) async {
    sent.add(Map<String, dynamic>.from(data));
    return FakeResponseSuccess();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await Countly.disposeAll();
  });

  group('Device ID - Change With Merge', () {
    testWidgets('changeWithMerge sends old_device_id in merge request', (WidgetTester tester) async {
      final network = FakeNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'original-device',
        giveConsent: true,
        enableSDKLogs: true,
        storageMode: StorageMode.memory,
      );
      final sdk = await Countly.init(cfg);

      await sdk.id.changeWithMerge('new-device-id');

      // Should have a merge request with old_device_id
      final mergeReqs = sdk.debugRequestQueueSnapshot.where((r) => r.containsKey('old_device_id')).toList();
      expect(mergeReqs, isNotEmpty, reason: 'Merge request should be queued');
      expect(mergeReqs.first['old_device_id'], 'original-device');
      expect(mergeReqs.first['device_id'], 'new-device-id');
    });

    testWidgets('changeWithMerge to same ID is a no-op', (WidgetTester tester) async {
      final network = FakeNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'same-id',
        giveConsent: true,
        enableSDKLogs: true,
        storageMode: StorageMode.memory,
      );
      final sdk = await Countly.init(cfg);

      final queueBefore = sdk.debugRequestQueueLength;
      await sdk.id.changeWithMerge('same-id');

      expect(sdk.debugRequestQueueLength, queueBefore, reason: 'No merge request for same device ID');
      expect(sdk.deviceId, 'same-id', reason: 'Device ID should remain unchanged');
      expect(sdk.deviceIdType, 0, reason: 'Device ID type should remain provided');
    });

    testWidgets('changeWithMerge with empty ID is rejected', (WidgetTester tester) async {
      final network = FakeNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'test-device',
        giveConsent: true,
        enableSDKLogs: true,
        storageMode: StorageMode.memory,
      );
      final sdk = await Countly.init(cfg);

      final queueBefore = sdk.debugRequestQueueLength;
      await sdk.id.changeWithMerge('');

      expect(sdk.debugRequestQueueLength, queueBefore, reason: 'Empty device ID should be rejected');
      expect(sdk.deviceId, 'test-device', reason: 'Device ID should remain unchanged after empty merge attempt');
    });
  });

  group('Device ID - Change Without Merge', () {
    testWidgets('changeWithoutMerge clears queues and enters unknown consent', (WidgetTester tester) async {
      final network = FakeNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'old-device',
        giveConsent: true,
        enableSDKLogs: true,
        storageMode: StorageMode.memory,
      );
      final sdk = await Countly.init(cfg);

      // Add some events before changing device ID
      await sdk.events.record(key: 'before_change', count: 1);
      expect(sdk.debugEventQueueLength, 1);

      await sdk.id.changeWithoutMerge('brand-new-device');

      // Event queue should be cleared after device ID change
      expect(sdk.debugEventQueueLength, 0, reason: 'Event queue should be cleared');
      expect(sdk.debugRequestQueueLength, 0, reason: 'Request queue should be cleared');
      // Device ID should actually change
      expect(sdk.deviceId, 'brand-new-device', reason: 'Device ID should be updated');
      expect(sdk.deviceIdType, 0, reason: 'New provided device ID type should be 0');

      // Events can still be buffered in unknown consent state
      await sdk.events.record(key: 'buffered_in_unknown', count: 1);
      expect(sdk.debugEventQueueLength, 1, reason: 'Events should be buffered in unknown consent state');

      // But nothing should be sent to network
      final sentBefore = network.sent.length;
      await sdk.processEventsAndRequests();
      final eventReqsSent = network.sent.skip(sentBefore).where((r) => r.containsKey('events')).toList();
      expect(eventReqsSent, isEmpty, reason: 'No event requests should be sent in unknown consent state');
    });

    testWidgets('changeWithoutMerge with empty ID is rejected', (WidgetTester tester) async {
      final network = FakeNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'test-device',
        giveConsent: true,
        enableSDKLogs: true,
        storageMode: StorageMode.memory,
      );
      final sdk = await Countly.init(cfg);

      await sdk.events.record(key: 'should_survive', count: 1);
      await sdk.id.changeWithoutMerge('');

      // Nothing should change
      expect(sdk.debugEventQueueLength, 1, reason: 'Queue should remain unchanged for empty ID');
      expect(sdk.deviceId, 'test-device', reason: 'Device ID should remain unchanged after empty changeWithoutMerge');
    });

    testWidgets('after changeWithoutMerge, new events use new device ID', (WidgetTester tester) async {
      final network = FakeNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'old-device',
        giveConsent: true,
        enableSDKLogs: true,
        storageMode: StorageMode.memory,
      );
      final sdk = await Countly.init(cfg);

      await sdk.id.changeWithoutMerge('new-device');

      // Give consent to resume tracking
      await sdk.consents.giveConsent();

      await sdk.events.record(key: 'new_device_event', count: 1);
      await sdk.processEventsAndRequests();

      // Verify the device ID was changed
      expect(sdk.deviceId, 'new-device', reason: 'Device ID should be updated');

      // Verify requests use new device ID
      final eventReqs = network.sent.where((r) => r.containsKey('events')).toList();
      expect(eventReqs, isNotEmpty, reason: 'Event requests should have been sent');
      expect(eventReqs.last['device_id'], 'new-device', reason: 'Sent requests should use the new device ID');
      // All sent requests after the change should use the new device ID
      for (final req in eventReqs) {
        expect(req['device_id'], 'new-device', reason: 'All event requests should use new device ID');
      }
    });
  });

  group('Device ID - Persistence', () {
    testWidgets('device ID persists across SDK instances', (WidgetTester tester) async {
      const instanceKey = 'device_id_persist_test';
      final network1 = FakeNetworkClient('https://example.com');
      final cfg1 = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network1,
        deviceId: 'persisted-device',
        giveConsent: true,
        enableSDKLogs: true,
        // Uses persistent storage intentionally to test device ID persistence
      );
      final sdk1 = await Countly.init(cfg1, instanceKey: instanceKey);

      // Device ID should be used in requests
      final snapshot = sdk1.debugRequestQueueSnapshot;
      expect(snapshot.any((r) => r['device_id'] == 'persisted-device'), isTrue);

      await Countly.disposeAll();

      // Reinitialize without providing device ID - should load from storage
      final network2 = FakeNetworkClient('https://example.com');
      final cfg2 = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network2,
        giveConsent: true,
        enableSDKLogs: true,
        // Uses persistent storage intentionally to test device ID persistence
      );
      final sdk2 = await Countly.init(cfg2, instanceKey: instanceKey);

      final snapshot2 = sdk2.debugRequestQueueSnapshot;
      expect(snapshot2.any((r) => r['device_id'] == 'persisted-device'), isTrue, reason: 'Device ID should be loaded from storage');
    });
  });
}
