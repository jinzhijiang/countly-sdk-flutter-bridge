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

  group('Device ID - Generation', () {
    testWidgets('auto-generates UUID when no deviceId provided', (WidgetTester tester) async {
      final network = FakeNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        giveConsent: true,
        enableSDKLogs: true,
        storageMode: StorageMode.memory,
      );
      final sdk = await Countly.init(cfg);

      expect(sdk.deviceId, isNotNull);
      expect(sdk.deviceId!.length, greaterThan(0));
      // UUID v4 format: 8-4-4-4-12 hex chars
      expect(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$').hasMatch(sdk.deviceId!), isTrue, reason: 'Generated device ID should be a valid UUID v4');
      expect(sdk.deviceIdType, 1, reason: 'Generated device ID type should be 1');
    });

    testWidgets('provided deviceId uses type 0', (WidgetTester tester) async {
      final network = FakeNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'my-custom-id',
        giveConsent: true,
        enableSDKLogs: true,
        storageMode: StorageMode.memory,
      );
      final sdk = await Countly.init(cfg);

      expect(sdk.deviceId, 'my-custom-id');
      expect(sdk.deviceIdType, 0, reason: 'Provided device ID type should be 0');
    });

    testWidgets('two instances without deviceId get different UUIDs', (WidgetTester tester) async {
      final network1 = FakeNetworkClient('https://example.com');
      final cfg1 = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network1,
        giveConsent: true,
        enableSDKLogs: true,
        storageMode: StorageMode.memory,
      );
      final sdk1 = await Countly.init(cfg1, instanceKey: 'auto_id_1');

      final network2 = FakeNetworkClient('https://example.com');
      final cfg2 = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network2,
        giveConsent: true,
        enableSDKLogs: true,
        storageMode: StorageMode.memory,
      );
      final sdk2 = await Countly.init(cfg2, instanceKey: 'auto_id_2');

      expect(sdk1.deviceId, isNot(equals(sdk2.deviceId)), reason: 'Two auto-generated device IDs should be different');
      // Both should be valid UUID v4
      final uuidRegex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
      expect(uuidRegex.hasMatch(sdk1.deviceId!), isTrue, reason: 'Instance 1 should have valid UUID v4');
      expect(uuidRegex.hasMatch(sdk2.deviceId!), isTrue, reason: 'Instance 2 should have valid UUID v4');
      expect(sdk1.deviceIdType, 1, reason: 'Instance 1 should be generated type');
      expect(sdk2.deviceIdType, 1, reason: 'Instance 2 should be generated type');
    });
  });

  group('Event Bundling', () {
    testWidgets('event with all parameters records correctly', (WidgetTester tester) async {
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

      await sdk.events.record(
        key: 'purchase',
        count: 3,
        sum: 29.99,
        dur: 12.5,
        segmentation: {'category': 'electronics', 'brand': 'acme'},
      );

      final evt = sdk.debugEventQueueSnapshot.first;
      expect(evt['key'], 'purchase');
      expect(evt['count'], 3);
      expect(evt['sum'], 29.99);
      expect(evt['dur'], 12.5);
      expect(evt['segmentation']['category'], 'electronics');
      expect(evt['segmentation']['brand'], 'acme');
      expect(evt['timestamp'], isA<int>());
      expect(evt['hour'], isA<int>());
      expect(evt['dow'], isA<int>());
    });
  });

  group('Request Processing', () {
    testWidgets('sent requests include rr (remaining requests) field', (WidgetTester tester) async {
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

      await sdk.events.record(key: 'rr_test');
      await sdk.processEventsAndRequests();

      // Check that sent requests include 'rr' field
      final sentWithRR = network.sent.where((r) => r.containsKey('rr')).toList();
      expect(sentWithRR, isNotEmpty, reason: 'Sent requests should include rr field');
      expect(sentWithRR.first['rr'], isA<int>());
      expect(sentWithRR.first['rr'] as int, greaterThanOrEqualTo(0), reason: 'rr must be non-negative');
    });

    testWidgets('requests are sent in FIFO order', (WidgetTester tester) async {
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

      // Record events and process with failing network to queue requests
      await sdk.events.record(key: 'first_event');
      await sdk.processEventsAndRequests();
      await sdk.events.record(key: 'second_event');
      await sdk.processEventsAndRequests();

      // Verify requests are queued in order by inspecting the request queue directly
      final rqSnapshot = sdk.debugRequestQueueSnapshot;
      expect(rqSnapshot.length, greaterThanOrEqualTo(2), reason: 'At least 2 requests should be queued');
      // Verify timestamps are in non-decreasing order (FIFO)
      for (int i = 1; i < rqSnapshot.length; i++) {
        if (rqSnapshot[i - 1].containsKey('timestamp') && rqSnapshot[i].containsKey('timestamp')) {
          expect(rqSnapshot[i - 1]['timestamp'] as int, lessThanOrEqualTo(rqSnapshot[i]['timestamp'] as int), reason: 'Request queue should maintain FIFO order (index ${i - 1} vs $i)');
        }
      }
      // Verify the first event request contains 'first_event'
      final eventReqs = rqSnapshot.where((r) => r.containsKey('events')).toList();
      expect(eventReqs.length, greaterThanOrEqualTo(2), reason: 'At least 2 event requests should be queued');
      expect(eventReqs[0].toString().contains('first_event'), isTrue, reason: 'First queued event request should contain first_event');
      expect(eventReqs[1].toString().contains('second_event'), isTrue, reason: 'Second queued event request should contain second_event');
    });

    testWidgets('backoff suspends processing after failure', (WidgetTester tester) async {
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

      await sdk.events.record(key: 'fail_event');
      await sdk.processEventsAndRequests();

      final queueAfterFailure = sdk.debugRequestQueueLength;
      expect(queueAfterFailure, greaterThan(0), reason: 'Failed requests should remain in queue');

      // Now switch to working network - but backoff should prevent processing
      final workingNetwork = FakeNetworkClient('https://example.com');
      sdk.debugOverrideNetworkClient = workingNetwork;

      await sdk.processEventsAndRequests();

      // Requests should still be in queue due to backoff
      expect(sdk.debugRequestQueueLength, queueAfterFailure, reason: 'Backoff should prevent processing even with working network');
    });
  });

  group('Timer-Driven Processing', () {
    testWidgets('internal timer processes queued events', (WidgetTester tester) async {
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

      // Override timer interval to 1 second for testing
      sdk.debugOverrideBehaviorSettings(timerIntervalSeconds: 1);

      await sdk.events.record(key: 'timer_event');
      expect(sdk.debugEventQueueLength, 1);

      // Wait for timer to fire (1 second interval + margin)
      await Future.delayed(const Duration(milliseconds: 1500));

      // Timer should have triggered processEventsAndRequests
      expect(sdk.debugEventQueueLength, 0, reason: 'Timer should have processed events');
      final eventReqs = network.sent.where((r) => r.containsKey('events')).toList();
      expect(eventReqs, isNotEmpty, reason: 'Timer-processed events should be sent');
      // Verify the sent event data contains our specific event
      final allSentEventsStr = eventReqs.map((r) => r['events'].toString()).join();
      expect(allSentEventsStr.contains('timer_event'), isTrue, reason: 'Sent events should contain our timer_event');
      // Request queue should also be drained
      expect(sdk.debugRequestQueueLength, 0, reason: 'Request queue should be empty after timer processing');
    });
  });

  group('Consent - Advanced', () {
    testWidgets('revoke consent blocks user properties', (WidgetTester tester) async {
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

      await sdk.consents.revokeConsent();

      final sentBefore = network.sent.length;
      await sdk.users.setProperties({'name': 'Blocked'});
      await sdk.processEventsAndRequests();

      // No user_details request should have been sent after the revoke
      final userReqs = network.sent.skip(sentBefore).where((r) => r.containsKey('user_details')).toList();
      expect(userReqs, isEmpty, reason: 'User properties should be blocked after consent revoke');
    });

    testWidgets('revoke consent blocks views', (WidgetTester tester) async {
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

      await sdk.consents.revokeConsent();

      await sdk.views.startAutoStoppedView('BlockedView');
      expect(sdk.debugActiveViewName, isNull, reason: 'Views should be blocked after consent revoke');
    });

    testWidgets('unknown consent state: revokeConsent clears buffered data', (WidgetTester tester) async {
      final network = FakeNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'test-device',
        startWithUnknownConsent: true,
        enableSDKLogs: true,
        storageMode: StorageMode.memory,
      );
      final sdk = await Countly.init(cfg);

      // Events are buffered in unknown consent state (consent is true for recording)
      await sdk.events.record(key: 'buffered_event');
      expect(sdk.debugEventQueueLength, greaterThan(0));

      // Revoking consent in unknown state clears all data then records consent status
      await sdk.consents.revokeConsent();

      expect(sdk.debugEventQueueLength, 0, reason: 'Event queue should be cleared after revoke in unknown state');
      // Request queue has exactly 1 item: the consent status request recorded after clearing
      expect(sdk.debugRequestQueueLength, 1, reason: 'Only the consent status request should remain after revoke in unknown state');
      final req = sdk.debugRequestQueueSnapshot.first;
      expect(req.containsKey('consent'), isTrue, reason: 'The remaining request should be a consent request');
      final consent = req['consent'] as Map<String, dynamic>;
      expect(consent['events'], isFalse, reason: 'Revoked consent should have events=false');
      expect(consent['users'], isFalse, reason: 'Revoked consent should have users=false');
      expect(consent['metrics'], isFalse, reason: 'Revoked consent should have metrics=false');
      expect(consent['views'], isFalse, reason: 'Revoked consent should have views=false');
      expect(consent['feedback'], isFalse, reason: 'Revoked consent should have feedback=false');
    });

    testWidgets('consent request contains all feature types', (WidgetTester tester) async {
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
      await Countly.init(cfg);

      // Init should queue a consent request — check both sent and queued
      final sdk = Countly.defaultInstance!;
      final allConsentReqs = <Map<String, dynamic>>[
        ...network.sent.where((r) => r.containsKey('consent')),
        ...sdk.debugRequestQueueSnapshot.where((r) => r.containsKey('consent')),
      ];
      expect(allConsentReqs, isNotEmpty, reason: 'A consent request must exist after init');
      final consent = allConsentReqs.first['consent'] as Map<String, dynamic>;
      expect(consent['events'], isTrue, reason: 'events consent should be true');
      expect(consent['users'], isTrue, reason: 'users consent should be true');
      expect(consent['metrics'], isTrue, reason: 'metrics consent should be true');
      expect(consent['views'], isTrue, reason: 'views consent should be true');
      expect(consent['feedback'], isTrue, reason: 'feedback consent should be true');
      expect(consent.length, 5, reason: 'Consent map should have exactly 5 feature types');
    });
  });

  group('Health Check', () {
    testWidgets('health check sent during init contains el and wl', (WidgetTester tester) async {
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
      await Countly.init(cfg);

      // Health check is sent directly (not queued) during init
      final hcRequests = network.sent.where((r) => r.containsKey('hc')).toList();
      expect(hcRequests, isNotEmpty, reason: 'Health check should be sent during init');

      final hc = hcRequests.first['hc'] as Map<String, dynamic>;
      expect(hc['el'], 0, reason: 'Fresh init should have 0 errors');
      expect(hc['wl'], 0, reason: 'Fresh init should have 0 warnings');
      expect(hc['sc'], '', reason: 'Fresh init should have empty status code');
      expect(hc['em'], '', reason: 'Fresh init should have empty error message');
      expect(hc.length, 4, reason: 'HC map should have exactly 4 fields: el, wl, sc, em');
    });

    testWidgets('health check includes app version in metrics', (WidgetTester tester) async {
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
      await Countly.init(cfg);

      final hcRequests = network.sent.where((r) => r.containsKey('hc')).toList();
      expect(hcRequests, isNotEmpty);

      final hcReq = hcRequests.first;
      expect(hcReq['metrics'], isA<Map>());
      expect((hcReq['metrics'] as Map)['_app_version'], '1.0.0', reason: 'HC metrics should include the correct app version');
      // HC request should also include standard metadata
      expect(hcReq['app_key'], 'app-key');
      expect(hcReq['device_id'], 'test-device');
      expect(hcReq['sdk_name'], 'countly-sdk-flutter-lite');
    });

    testWidgets('health check is only sent once per init', (WidgetTester tester) async {
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

      // Process multiple times - should not trigger additional health checks
      await sdk.processEventsAndRequests();
      await sdk.processEventsAndRequests();

      final hcRequests = network.sent.where((r) => r.containsKey('hc')).toList();
      expect(hcRequests.length, 1, reason: 'Health check should only be sent once per init');
    });
  });

  group('User Properties - Advanced', () {
    testWidgets('custom user property keys are truncated to lkl', (WidgetTester tester) async {
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
          'c': {'lkl': 10}
        },
      );
      final sdk = await Countly.init(cfg);

      await sdk.users.setProperties({'long_custom_key_name': 'value'});
      await sdk.processEventsAndRequests();

      final userReqs = network.sent.where((r) => r.containsKey('user_details')).toList();
      expect(userReqs, isNotEmpty);

      final custom = (userReqs.last['user_details'] as Map<String, dynamic>)['custom'] as Map<String, dynamic>;
      final keys = custom.keys.toList();
      expect(keys.length, 1, reason: 'Should have exactly 1 custom property');
      expect(keys.first, 'long_custo', reason: 'Key should be truncated to first 10 chars');
      expect(custom[keys.first], 'value', reason: 'Value should be preserved after key truncation');
    });

    testWidgets('mixed named and operator properties in single call', (WidgetTester tester) async {
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

      // Set named + custom in one call, then push in another
      await sdk.users.setProperties({'name': 'Bob', 'score': 42});
      await sdk.users.pushToArray('tags', ['new_tag']);
      await sdk.processEventsAndRequests();

      final userReqs = network.sent.where((r) => r.containsKey('user_details')).toList();
      expect(userReqs, isNotEmpty);

      final allDetails = userReqs.map((r) => r['user_details'] as Map<String, dynamic>).toList();

      // Named property should be at top level in one of the requests
      final hasName = allDetails.any((d) => d['name'] == 'Bob');
      expect(hasName, isTrue, reason: 'Named property should be present at top level');

      // Custom property 'score' should be under 'custom' key
      final hasScore = allDetails.any((d) => d.containsKey('custom') && (d['custom'] as Map<String, dynamic>)['score'] == 42);
      expect(hasScore, isTrue, reason: 'Custom property score=42 should be under custom key');

      // Push operator should be in one of the requests
      final hasPush = allDetails.any((d) {
        if (!d.containsKey('custom')) return false;
        final custom = d['custom'] as Map<String, dynamic>;
        if (!custom.containsKey('tags')) return false;
        final tags = custom['tags'];
        return tags is Map && tags.containsKey('\$push');
      });
      expect(hasPush, isTrue, reason: '\$push operator for tags should be present');
    });
  });

  group('Segmentation Limits', () {
    testWidgets('empty segmentation does not add segmentation key', (WidgetTester tester) async {
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

      await sdk.events.record(key: 'no_seg');

      final evt = sdk.debugEventQueueSnapshot.first;
      expect(evt.containsKey('segmentation'), isFalse, reason: 'Event without segmentation should not have segmentation key');
    });
  });

  group('SDK Metadata', () {
    testWidgets('all requests include correct SDK metadata', (WidgetTester tester) async {
      final network = FakeNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'test-app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'meta-test-device',
        giveConsent: true,
        enableSDKLogs: true,
        storageMode: StorageMode.memory,
      );
      final sdk = await Countly.init(cfg);

      await sdk.events.record(key: 'meta_event');
      await sdk.processEventsAndRequests();

      // Check a sent request
      final reqs = network.sent.where((r) => r.containsKey('events')).toList();
      expect(reqs, isNotEmpty);

      final req = reqs.last;
      expect(req['app_key'], 'test-app-key');
      expect(req['device_id'], 'meta-test-device');
      expect(req['sdk_name'], 'countly-sdk-flutter-lite');
      expect(req['sdk_version'], '26.1.0');
      expect(req['av'], '1.0.0');
      // Timestamp should be recent (within last 60 seconds)
      final ts = req['timestamp'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      expect(ts, greaterThan(now - 60000), reason: 'Timestamp should be within last 60 seconds');
      expect(ts, lessThanOrEqualTo(now), reason: 'Timestamp should not be in the future');
      // Dynamic metadata should also be present
      expect(req['hour'], isA<int>());
      expect(req['dow'], isA<int>());
      expect(req['tz'], isA<int>());
      // rr field should be present
      expect(req.containsKey('rr'), isTrue, reason: 'Sent request must have rr field');
    });

    testWidgets('dynamic request metadata is attached when sent', (WidgetTester tester) async {
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

      await sdk.events.record(key: 'ts_event');
      await sdk.processEventsAndRequests();

      // Find sent request (via makeSelectiveRequest)
      final sentReqs = network.sent.where((r) => r.containsKey('events')).toList();
      expect(sentReqs, isNotEmpty);

      final req = sentReqs.last;
      expect(req['timestamp'], isA<int>());
      expect(req['hour'], isA<int>());
      expect(req['dow'], isA<int>());
      expect(req['tz'], isA<int>());
      // hour should be 0-23
      expect(req['hour'] as int, inInclusiveRange(0, 23));
      // dow should be 0-6 (Sunday=0 through Saturday=6)
      expect(req['dow'] as int, inInclusiveRange(0, 6));
      // tz should be a valid UTC offset in minutes (-720 to +840)
      expect(req['tz'] as int, inInclusiveRange(-720, 840), reason: 'tz must be a valid UTC offset in minutes');
      // Timestamp should be recent
      final ts = req['timestamp'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      expect(ts, greaterThan(now - 60000), reason: 'Timestamp should be within last 60 seconds');
      expect(ts, lessThanOrEqualTo(now), reason: 'Timestamp should not be in the future');
    });
  });

  group('Queue Persistence with Memory Mode', () {
    testWidgets('memory mode does not persist between instances', (WidgetTester tester) async {
      final network1 = FakeNetworkClient('https://example.com');
      final cfg1 = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network1,
        deviceId: 'mem-device',
        giveConsent: true,
        enableSDKLogs: true,
        storageMode: StorageMode.memory,
      );
      final sdk1 = await Countly.init(cfg1, instanceKey: 'mem_test');

      await sdk1.events.record(key: 'mem_event');
      expect(sdk1.debugEventQueueLength, 1);

      // Dispose without flush
      await sdk1.dispose(flush: false);

      // New instance with same key - should not have old events
      final network2 = FakeNetworkClient('https://example.com');
      final cfg2 = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network2,
        deviceId: 'mem-device',
        giveConsent: true,
        enableSDKLogs: true,
        storageMode: StorageMode.memory,
      );
      final sdk2 = await Countly.init(cfg2, instanceKey: 'mem_test');

      expect(sdk2.debugEventQueueLength, 0, reason: 'Memory mode should not persist events between instances');
      // Request queue should only have fresh init requests (consent, metrics, location), not old data
      final rqSnapshot = sdk2.debugRequestQueueSnapshot;
      final hasOldEvent = rqSnapshot.any((r) {
        if (!r.containsKey('events')) return false;
        return r['events'].toString().contains('mem_event');
      });
      expect(hasOldEvent, isFalse, reason: 'Old events should not leak into new instance request queue');
    });
  });
}
