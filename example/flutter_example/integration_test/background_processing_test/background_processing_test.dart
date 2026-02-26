import 'dart:io';

import 'package:countly_flutter_lite/countly_flutter_lite.dart';
import 'package:countly_sdk_dart_core/src/networking.dart';
import 'package:flutter/widgets.dart';
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

void _simulateBackground() {
  WidgetsBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.paused);
}

void _simulateForeground() {
  WidgetsBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await Countly.disposeAll();
  });

  group('Background Processing', () {
    testWidgets('going to background processes event queue', (WidgetTester tester) async {
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

      // Record events that sit in the event queue
      await sdk.events.record(key: 'bg_event_1', count: 1);
      await sdk.events.record(key: 'bg_event_2', count: 2);

      // Events should be in event queue, not yet bundled to request queue
      expect(sdk.debugEventQueueLength, 2, reason: 'Two events should be in event queue');

      // Simulate going to background via SDK lifecycle helpers
      _simulateBackground();

      // Allow fire-and-forget async processing to complete
      await Future.delayed(const Duration(milliseconds: 500));

      // Event queue should be flushed
      expect(sdk.debugEventQueueLength, 0, reason: 'Event queue should be empty after background processing');

      // Events should have been sent to server
      final eventRequests = network.sent.where((r) => r.containsKey('events')).toList();
      expect(eventRequests, isNotEmpty, reason: 'Events should have been sent to server');

      // Verify our events are in the sent requests using helper deconstruction
      final allSentEvents = <Map<String, dynamic>>[];
      for (final req in eventRequests) {
        final evts = req['events'];
        if (evts is List) {
          for (final e in evts) {
            allSentEvents.add(Map<String, dynamic>.from(e as Map));
          }
        } else if (evts is String) {
          final parsed = (evts.startsWith('[')) ? (evts.substring(1, evts.length - 1)) : evts;
          // Fallback: string contains check
          expect(evts.contains('bg_event_1'), isTrue);
          expect(evts.contains('bg_event_2'), isTrue);
        }
      }
      if (allSentEvents.isNotEmpty) {
        final evt1 = allSentEvents.where((e) => e['key'] == 'bg_event_1');
        final evt2 = allSentEvents.where((e) => e['key'] == 'bg_event_2');
        expect(evt1, isNotEmpty, reason: 'bg_event_1 should be in sent events');
        expect(evt2, isNotEmpty, reason: 'bg_event_2 should be in sent events');
        expect(evt1.first['count'], 1, reason: 'bg_event_1 count should be 1');
        expect(evt2.first['count'], 2, reason: 'bg_event_2 count should be 2');
      }

      // Request queue should also be drained
      expect(sdk.debugRequestQueueLength, 0, reason: 'Request queue should be empty after background processing');
      expect(sdk.debugIsInBackground, isTrue, reason: 'SDK should report being in background');
    });

    testWidgets('going to background processes user properties cache', (WidgetTester tester) async {
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

      // Set user properties (these stay in cache until flushed)
      await sdk.users.setProperties({'name': 'TestUser', 'custom_prop': 'value1'});

      // Simulate going to background via SDK lifecycle helpers
      _simulateBackground();

      await Future.delayed(const Duration(milliseconds: 500));

      // User properties should have been sent
      final userDetailRequests = network.sent.where((r) => r.containsKey('user_details')).toList();
      expect(userDetailRequests, isNotEmpty, reason: 'User properties should have been sent to server');

      final sentUserDetails = userDetailRequests.last['user_details'];
      expect(sentUserDetails, isA<Map>());
      expect(sentUserDetails['name'], 'TestUser');
      expect(sentUserDetails['custom'], containsPair('custom_prop', 'value1'));
    });

    testWidgets('going to background processes request queue', (WidgetTester tester) async {
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

      // Set short backoff so we can recover quickly (backoff = timer interval)
      sdk.debugOverrideBehaviorSettings(timerIntervalSeconds: 1);

      // Record events to build up request queue
      await sdk.events.record(key: 'queued_event', count: 1);
      await sdk.processEventsAndRequests();

      // Requests are queued because network is failing
      expect(sdk.debugRequestQueueLength, greaterThan(0), reason: 'Requests should be queued due to network failure');

      // Now swap to a working network
      final workingNetwork = FakeNetworkClient('https://example.com');
      sdk.debugOverrideNetworkClient = workingNetwork;

      // Wait for 1-second backoff to expire
      await Future.delayed(const Duration(milliseconds: 1200));

      // Simulate going to background - should attempt to process request queue
      _simulateBackground();

      await Future.delayed(const Duration(milliseconds: 500));

      // Request queue should be drained
      expect(sdk.debugRequestQueueLength, 0, reason: 'Request queue should be drained after background processing');
      expect(workingNetwork.sent, isNotEmpty, reason: 'Requests should have been sent');
    });

    testWidgets('background and foreground flags are set correctly', (WidgetTester tester) async {
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

      expect(sdk.debugIsInBackground, isFalse);

      _simulateBackground();
      await Future.delayed(const Duration(milliseconds: 100));
      expect(sdk.debugIsInBackground, isTrue);

      _simulateForeground();
      await Future.delayed(const Duration(milliseconds: 100));
      expect(sdk.debugIsInBackground, isFalse);

      // Multiple transitions
      _simulateBackground();
      await Future.delayed(const Duration(milliseconds: 100));
      expect(sdk.debugIsInBackground, isTrue);

      _simulateForeground();
      await Future.delayed(const Duration(milliseconds: 100));
      expect(sdk.debugIsInBackground, isFalse);
    });

    testWidgets('going to background with empty queues does not error', (WidgetTester tester) async {
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

      // Wait for init requests to be sent
      await Future.delayed(const Duration(milliseconds: 500));

      final sentCountBefore = network.sent.length;
      final eqBefore = sdk.debugEventQueueLength;
      final rqBefore = sdk.debugRequestQueueLength;

      // Go to background with empty event queue - should not throw
      _simulateBackground();
      await Future.delayed(const Duration(milliseconds: 200));

      // Should complete without error and without unnecessary network calls
      expect(sdk.debugIsInBackground, isTrue);
      expect(sdk.debugEventQueueLength, eqBefore, reason: 'Event queue should be unchanged');
      expect(sdk.debugRequestQueueLength, lessThanOrEqualTo(rqBefore), reason: 'Request queue should not grow from empty background');
      // No new event-type requests should have been sent (init requests already drained)
      final newEventReqs = network.sent.skip(sentCountBefore).where((r) => r.containsKey('events')).toList();
      expect(newEventReqs, isEmpty, reason: 'No event requests should be sent with empty queues');
    });
  });
}
