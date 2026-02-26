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

  group('Consent - Given at Init', () {
    testWidgets('consent=true at init sends true consent request', (WidgetTester tester) async {
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

      final consentReqs = sdk.debugRequestQueueSnapshot.where((r) => r.containsKey('consent')).toList();
      expect(consentReqs, isNotEmpty, reason: 'A consent request must be queued on init');
      final consent = consentReqs.first['consent'] as Map<String, dynamic>;
      expect(consent['events'], isTrue);
      expect(consent['users'], isTrue);
      expect(consent['metrics'], isTrue);
      expect(consent['views'], isTrue);
      expect(consent['feedback'], isTrue, reason: 'All 5 feature types should be true');
      expect(consent.length, 5, reason: 'Consent map should have exactly 5 feature types');
    });

    testWidgets('consent=true allows events and metrics', (WidgetTester tester) async {
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

      await sdk.events.record(key: 'consented_event', count: 1);
      expect(sdk.debugEventQueueLength, 1, reason: 'Events should be accepted with consent');
      expect(sdk.debugEventQueueSnapshot.first['key'], 'consented_event');
      expect(sdk.debugEventQueueSnapshot.first['count'], 1);

      // Metrics should be in request queue from init
      final metricsReqs = sdk.debugRequestQueueSnapshot.where((r) => r.containsKey('metrics')).toList();
      expect(metricsReqs, isNotEmpty, reason: 'Metrics should be recorded with consent');
      final metrics = metricsReqs.first['metrics'] as Map<String, dynamic>;
      expect(metrics.containsKey('_os'), isTrue, reason: 'Metrics should contain _os');
      expect(metrics.containsKey('_app_version'), isTrue, reason: 'Metrics should contain _app_version');
    });
  });

  group('Consent - Not Given at Init', () {
    testWidgets('consent=false blocks events and user properties', (WidgetTester tester) async {
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

      await sdk.events.record(key: 'blocked_event', count: 1);
      expect(sdk.debugEventQueueLength, 0, reason: 'Events should be blocked without consent');

      await sdk.users.setProperties({'name': 'Blocked'});
      await sdk.processEventsAndRequests();

      final userReqs = network.sent.where((r) => r.containsKey('user_details')).toList();
      expect(userReqs, isEmpty, reason: 'User properties should be blocked without consent');
    });

    testWidgets('giving consent after init enables tracking', (WidgetTester tester) async {
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

      // Events blocked before consent
      await sdk.events.record(key: 'before_consent', count: 1);
      expect(sdk.debugEventQueueLength, 0);

      // Give consent
      await sdk.consents.giveConsent();

      // Events now allowed
      await sdk.events.record(key: 'after_consent', count: 1);
      expect(sdk.debugEventQueueLength, 1, reason: 'Events should be accepted after giving consent');
      expect(sdk.debugEventQueueSnapshot.first['key'], 'after_consent');
    });
  });

  group('Consent - Revoke', () {
    testWidgets('revoking consent sends false consent and flushes queues', (WidgetTester tester) async {
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

      await sdk.events.record(key: 'pre_revoke', count: 1);
      expect(sdk.debugEventQueueLength, 1);

      await sdk.consents.revokeConsent();

      // Event queue should be cleared after revoke
      expect(sdk.debugEventQueueLength, 0, reason: 'Event queue should be cleared on revoke');

      // False consent request should be sent
      final consentReqs = network.sent.where((r) => r.containsKey('consent')).toList();
      final falseConsent = consentReqs.where((r) {
        final c = r['consent'] as Map<String, dynamic>;
        return c['events'] == false;
      }).toList();
      expect(falseConsent, isNotEmpty, reason: 'False consent request should be sent on revoke');
      // Verify ALL feature types are false
      final fc = falseConsent.first['consent'] as Map<String, dynamic>;
      expect(fc['events'], isFalse);
      expect(fc['users'], isFalse);
      expect(fc['metrics'], isFalse);
      expect(fc['views'], isFalse);
      expect(fc['feedback'], isFalse);
      expect(fc.length, 5, reason: 'False consent should have exactly 5 feature types');
    });

    testWidgets('events are blocked after consent is revoked', (WidgetTester tester) async {
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

      await sdk.consents.revokeConsent();

      // Clear event queue to isolate the test
      await sdk.processEventsAndRequests();
      final queueAfterRevoke = sdk.debugEventQueueLength;

      await sdk.events.record(key: 'after_revoke', count: 1);
      expect(sdk.debugEventQueueLength, queueAfterRevoke, reason: 'No events should be added after revoking consent');
    });
  });

  group('Consent - Unknown State', () {
    testWidgets('SDK starts in unknown consent state and buffers data', (WidgetTester tester) async {
      final network = FakeNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'test-device',
        giveConsent: true,
        startWithUnknownConsent: true,
        enableSDKLogs: true,
      );
      final sdk = await Countly.init(cfg);

      // Should still be able to record events (buffered)
      await sdk.events.record(key: 'buffered_event', count: 1);
      expect(sdk.debugEventQueueLength, 1, reason: 'Events should be buffered in unknown consent state');
      expect(sdk.debugEventQueueSnapshot.first['key'], 'buffered_event');

      // No event-type requests should be sent yet (only HC may go out)
      final sentBeforeConsent = network.sent.length;
      final eventReqsBefore = network.sent.where((r) => r.containsKey('events')).length;

      // Give consent to exit unknown state
      await sdk.consents.giveConsent();

      // Now buffered data should be processed
      await sdk.processEventsAndRequests();

      expect(network.sent.length, greaterThan(sentBeforeConsent), reason: 'Buffered requests should be sent after giving consent');
      // Specifically, event requests should now have been sent
      final eventReqsAfter = network.sent.where((r) => r.containsKey('events')).length;
      expect(eventReqsAfter, greaterThan(eventReqsBefore), reason: 'Buffered events should be flushed after giving consent');
      // Event queue should be drained
      expect(sdk.debugEventQueueLength, 0, reason: 'Event queue should be empty after processing');
    });
  });
}
