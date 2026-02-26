import 'dart:convert';

import 'package:countly_flutter_lite/countly_flutter_lite.dart';
import 'package:countly_sdk_dart_core/src/networking.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import '../../../../test/helper/helper.dart' as helper;

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

  group('Event Recording', () {
    testWidgets('recorded event appears in event queue and is sent on flush', (WidgetTester tester) async {
      final network = FakeNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'test-device',
        giveConsent: true,
        enableSDKLogs: true,
      );
      final sdk = await Countly.init(cfg);

      await sdk.events.record(key: 'purchase', count: 3, sum: 19.99, segmentation: {'category': 'electronics'});

      expect(sdk.debugEventQueueLength, 1);
      final evt = sdk.debugEventQueueSnapshot.first;
      expect(evt['key'], 'purchase');
      expect(evt['count'], 3);
      expect(evt['sum'], 19.99);
      expect(evt['segmentation']['category'], 'electronics');
      expect(evt['timestamp'], isA<int>());

      // Flush and verify it's sent
      await sdk.processEventsAndRequests();

      expect(sdk.debugEventQueueLength, 0, reason: 'Event queue should be empty after flush');

      final eventRequests = network.sent.where((r) => r.containsKey('events')).toList();
      expect(eventRequests, isNotEmpty);

      final events = helper.deconstructEventsRequest(eventRequests.last);
      final purchase = events.firstWhere((e) => e['key'] == 'purchase');
      expect(purchase['count'], 3);
      expect(purchase['sum'], 19.99);
    });

    testWidgets('multiple events are batched in a single request', (WidgetTester tester) async {
      final network = FakeNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'test-device',
        giveConsent: true,
        enableSDKLogs: true,
      );
      final sdk = await Countly.init(cfg);

      await sdk.events.record(key: 'event_a', count: 1);
      await sdk.events.record(key: 'event_b', count: 2);
      await sdk.events.record(key: 'event_c', count: 3);

      expect(sdk.debugEventQueueLength, 3);

      await sdk.processEventsAndRequests();

      // All events should be bundled in one request
      final eventRequests = network.sent.where((r) => r.containsKey('events')).toList();
      expect(eventRequests, isNotEmpty);

      final lastBatch = helper.deconstructEventsRequest(eventRequests.last);
      expect(lastBatch.length, 3, reason: 'All 3 events should be in one batch');
      final evtA = lastBatch.firstWhere((e) => e['key'] == 'event_a');
      final evtB = lastBatch.firstWhere((e) => e['key'] == 'event_b');
      final evtC = lastBatch.firstWhere((e) => e['key'] == 'event_c');
      expect(evtA['count'], 1, reason: 'event_a count should be preserved');
      expect(evtB['count'], 2, reason: 'event_b count should be preserved');
      expect(evtC['count'], 3, reason: 'event_c count should be preserved');
      // Each event should have its own timestamp
      expect(evtA['timestamp'], isA<int>());
      expect(evtB['timestamp'], isA<int>());
      expect(evtC['timestamp'], isA<int>());
    });

    testWidgets('event with empty key is rejected', (WidgetTester tester) async {
      final network = FakeNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'test-device',
        giveConsent: true,
        enableSDKLogs: true,
      );
      final sdk = await Countly.init(cfg);

      await sdk.events.record(key: '');

      expect(sdk.debugEventQueueLength, 0, reason: 'Empty key event should be rejected');
    });

    testWidgets('event without consent is dropped', (WidgetTester tester) async {
      final network = FakeNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'test-device',
        giveConsent: false,
        enableSDKLogs: true,
      );
      final sdk = await Countly.init(cfg);

      await sdk.events.record(key: 'should_not_record');

      expect(sdk.debugEventQueueLength, 0, reason: 'Events should be dropped without consent');
    });
  });

  group('User Properties', () {
    testWidgets('custom user properties go under custom key', (WidgetTester tester) async {
      final network = FakeNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'test-device',
        giveConsent: true,
        enableSDKLogs: true,
      );
      final sdk = await Countly.init(cfg);

      await sdk.users.setProperties({
        'tier': 'premium',
        'score': 42,
      });

      await sdk.processEventsAndRequests();

      final userRequests = network.sent.where((r) => r.containsKey('user_details')).toList();
      expect(userRequests, isNotEmpty);

      final details = userRequests.last['user_details'] as Map<String, dynamic>;
      expect(details['custom'], isA<Map>());
      expect(details['custom']['tier'], 'premium');
      expect(details['custom']['score'], 42);
      // Custom properties should NOT leak to top level
      expect(details.containsKey('tier'), isFalse, reason: 'Custom prop tier should not be at top level');
      expect(details.containsKey('score'), isFalse, reason: 'Custom prop score should not be at top level');
    });

    testWidgets('mixed named and custom properties are split correctly', (WidgetTester tester) async {
      final network = FakeNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'test-device',
        giveConsent: true,
        enableSDKLogs: true,
      );
      final sdk = await Countly.init(cfg);

      await sdk.users.setProperties({
        'name': 'John',
        'email': 'john@test.com',
        'loyalty_level': 'gold', // custom
        'signup_date': '2025-01-01', // custom
      });

      await sdk.processEventsAndRequests();

      final userRequests = network.sent.where((r) => r.containsKey('user_details')).toList();
      expect(userRequests, isNotEmpty);

      final details = userRequests.last['user_details'] as Map<String, dynamic>;
      // Named properties at top level
      expect(details['name'], 'John');
      expect(details['email'], 'john@test.com');
      // Custom properties under 'custom' key
      expect(details['custom']['loyalty_level'], 'gold');
      expect(details['custom']['signup_date'], '2025-01-01');
      // Custom props should NOT be at top level
      expect(details.containsKey('loyalty_level'), isFalse, reason: 'loyalty_level should not be at top level');
      expect(details.containsKey('signup_date'), isFalse, reason: 'signup_date should not be at top level');
      // Named props should NOT be under custom
      final custom = details['custom'] as Map<String, dynamic>;
      expect(custom.containsKey('name'), isFalse, reason: 'Named prop name should not be under custom');
      expect(custom.containsKey('email'), isFalse, reason: 'Named prop email should not be under custom');
    });

    testWidgets('user properties without consent are dropped', (WidgetTester tester) async {
      final network = FakeNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'test-device',
        giveConsent: false,
        enableSDKLogs: true,
      );
      final sdk = await Countly.init(cfg);

      await sdk.users.setProperties({'name': 'NeverSent'});
      await sdk.processEventsAndRequests();

      final userRequests = network.sent.where((r) => r.containsKey('user_details')).toList();
      expect(userRequests, isEmpty, reason: 'User properties should not be sent without consent');
    });

    testWidgets('user properties flushed when recording event', (WidgetTester tester) async {
      final network = FakeNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'test-device',
        giveConsent: true,
        enableSDKLogs: true,
      );
      final sdk = await Countly.init(cfg);

      await sdk.users.setProperties({'custom_key': 'val'});

      // Recording an event should trigger user properties flush
      await sdk.events.record(key: 'trigger_flush', count: 1);
      await sdk.processEventsAndRequests();

      final userRequests = network.sent.where((r) => r.containsKey('user_details')).toList();
      expect(userRequests, isNotEmpty, reason: 'User properties should be flushed when event is recorded');
      final details = userRequests.last['user_details'] as Map<String, dynamic>;
      expect(details['custom']['custom_key'], 'val', reason: 'Flushed user properties should contain our data');
    });
  });
}
