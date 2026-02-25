import 'dart:io';

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

class FailingNetworkClient extends NetworkClient {
  FailingNetworkClient(String baseUrl) : super(baseUrl);

  @override
  Future<http.Response> makeRequest(Map<String, dynamic> data, String endPoint) async {
    throw const SocketException('Simulated network failure');
  }

  @override
  Future<http.Response> makeSelectiveRequest(Map<String, dynamic> data) async {
    throw const SocketException('Simulated network failure');
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await Countly.disposeAll();
  });

  group('Views - Extended', () {
    testWidgets('endActiveView with no active view is a safe no-op', (WidgetTester tester) async {
      final network = FakeNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'test-device',
        giveConsent: true,
        enableSDKLogs: true,
        storageMode: StorageMode.memory,
        sbs: {
          'c': {'vt': true}
        },
      );
      final sdk = await Countly.init(cfg);

      // Verify no active view before test
      expect(sdk.debugActiveViewName, isNull, reason: 'No active view should exist before test');
      final eqBefore = sdk.debugEventQueueLength;

      // No active view, should not throw or add events
      await sdk.views.endActiveView();

      expect(sdk.debugEventQueueLength, eqBefore, reason: 'Event queue should not grow');
      final viewEvents = sdk.debugEventQueueSnapshot.where((e) => e['key'] == '[CLY]_view').toList();
      expect(viewEvents, isEmpty, reason: 'Ending non-existent view should not add events');
      expect(sdk.debugActiveViewName, isNull, reason: 'No active view should exist after no-op end');
    });

    testWidgets('view name truncation via key length limit', (WidgetTester tester) async {
      final network = FakeNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'test-device',
        giveConsent: true,
        enableSDKLogs: true,
        storageMode: StorageMode.memory,
        sbs: {
          'c': {'lkl': 5, 'vt': true}
        },
      );
      final sdk = await Countly.init(cfg);

      await sdk.views.startAutoStoppedView('LongViewName');
      expect(sdk.debugActiveViewName, 'LongV', reason: 'View name should be truncated to lkl limit');
      // End the view so a [CLY]_view event is generated and queued
      await sdk.views.endActiveView();
      expect(sdk.debugActiveViewName, isNull, reason: 'Active view should be cleared after end');
      // Verify a view event was queued with the truncated name
      final viewEvents = sdk.debugEventQueueSnapshot.where((e) => e['key'] == '[CLY]_view').toList();
      expect(viewEvents, isNotEmpty, reason: 'A view event should be queued after ending view');
      expect(viewEvents.first['segmentation']['name'], 'LongV', reason: 'View event segmentation should contain truncated name');
    });
  });

  group('Network - Backoff', () {
    testWidgets('request queue retains requests on failure and processes after backoff', (WidgetTester tester) async {
      final failingNetwork = FailingNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: failingNetwork,
        deviceId: 'test-device',
        giveConsent: true,
        enableSDKLogs: true,
        storageMode: StorageMode.memory,
      );
      final sdk = await Countly.init(cfg);

      await sdk.events.record(key: 'queued_event', count: 1);
      await sdk.processEventsAndRequests();

      // Requests should be retained in queue due to failure
      expect(sdk.debugRequestQueueLength, greaterThan(0), reason: 'Requests should be retained on failure');

      // Swap to working network
      final workingNetwork = FakeNetworkClient('https://example.com');
      sdk.debugOverrideNetworkClient = workingNetwork;

      final rqAfterFailure = sdk.debugRequestQueueLength;

      // Call process again - but backoff is in effect, so nothing should be sent
      await sdk.processEventsAndRequests();

      // Requests should still be in queue due to backoff (default 60s)
      expect(sdk.debugRequestQueueLength, rqAfterFailure, reason: 'Backoff should prevent processing; queue should remain unchanged');
      expect(workingNetwork.sent, isEmpty, reason: 'No requests should be sent during backoff window');
    });

    testWidgets('request queue overflow evicts oldest request', (WidgetTester tester) async {
      final failingNetwork = FailingNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: failingNetwork,
        deviceId: 'test-device',
        giveConsent: true,
        enableSDKLogs: true,
        storageMode: StorageMode.memory,
        sbs: {
          'c': {'rqs': 5}
        },
      );
      final sdk = await Countly.init(cfg);

      // Fill up the queue beyond its limit
      for (int i = 0; i < 10; i++) {
        await sdk.events.record(key: 'overflow_$i');
        await sdk.processEventsAndRequests();
      }

      expect(sdk.debugRequestQueueLength, lessThanOrEqualTo(5), reason: 'Request queue should not exceed rqs limit');
      expect(sdk.debugRequestQueueLength, greaterThan(0), reason: 'Queue should still contain requests');
      // The oldest requests should have been evicted — verify remaining are the newer ones
      final remaining = sdk.debugRequestQueueSnapshot;
      final remainingEventsStr = remaining.map((r) => r.toString()).join();
      // overflow_0 (the first event) should have been evicted
      expect(remainingEventsStr.contains('overflow_0'), isFalse, reason: 'Oldest request (overflow_0) should have been evicted');
    });
  });

  group('Dispose - Extended', () {
    testWidgets('dispose with flush=false does not send pending data', (WidgetTester tester) async {
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

      await sdk.events.record(key: 'not_sent');
      final sentBefore = network.sent.length;

      await sdk.dispose(flush: false);

      // No new events requests should have been sent
      final eventReqs = network.sent.skip(sentBefore).where((r) => r.containsKey('events')).toList();
      expect(eventReqs, isEmpty, reason: 'flush=false should not send pending events');
    });

    testWidgets('double dispose is a safe no-op', (WidgetTester tester) async {
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

      expect(sdk.isTimerActive, isTrue, reason: 'Timer should be active before dispose');
      await sdk.dispose();
      expect(sdk.isTimerActive, isFalse, reason: 'Timer should be cancelled after first dispose');
      await sdk.dispose(); // Should not throw
      expect(sdk.isTimerActive, isFalse, reason: 'Timer should remain cancelled after second dispose');
    });

    testWidgets('dispose cancels internal timer', (WidgetTester tester) async {
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

      expect(sdk.isTimerActive, isTrue);
      await sdk.dispose();
      expect(sdk.isTimerActive, isFalse, reason: 'Timer should be cancelled after dispose');
    });
  });

  group('Multi-Instance - Extended', () {
    testWidgets('re-init with same instanceKey replaces old instance', (WidgetTester tester) async {
      final network1 = FakeNetworkClient('https://example.com');
      final cfg1 = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network1,
        deviceId: 'old-device',
        giveConsent: true,
        enableSDKLogs: true,
        storageMode: StorageMode.memory,
      );
      final sdk1 = await Countly.init(cfg1, instanceKey: 'replace_test');

      await sdk1.events.record(key: 'old_event');

      // Re-init with same key - old instance should be disposed and replaced
      final network2 = FakeNetworkClient('https://example.com');
      final cfg2 = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network2,
        deviceId: 'new-device',
        giveConsent: true,
        enableSDKLogs: true,
        storageMode: StorageMode.memory,
      );
      final sdk2 = await Countly.init(cfg2, instanceKey: 'replace_test');

      // Old instance should be disposed (timer cancelled)
      expect(sdk1.isTimerActive, isFalse, reason: 'Old instance timer should be cancelled after replacement');

      // Old events should be gone (flushed during replacement)
      expect(sdk2.debugEventQueueLength, 0, reason: 'New instance should have clean event queue');
      expect(sdk2.deviceId, 'new-device');
      expect(sdk2.isTimerActive, isTrue, reason: 'New instance timer should be active');

      // New instance is functional
      await sdk2.events.record(key: 'new_event');
      expect(sdk2.debugEventQueueLength, 1);
      expect(sdk2.debugEventQueueSnapshot.first['key'], 'new_event');
    });

    testWidgets('Countly.instance() returns correct instance', (WidgetTester tester) async {
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
      final sdk = await Countly.init(cfg, instanceKey: 'custom_key');

      expect(Countly.instance('custom_key'), isNotNull);
      expect(Countly.instance('custom_key'), same(sdk));
      expect(Countly.instance('nonexistent'), isNull);
    });

    testWidgets('Countly.defaultInstance returns the default', (WidgetTester tester) async {
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
      final sdk = await Countly.init(cfg); // default key

      expect(Countly.defaultInstance, isNotNull);
      expect(Countly.defaultInstance, same(sdk));
    });
  });
}
