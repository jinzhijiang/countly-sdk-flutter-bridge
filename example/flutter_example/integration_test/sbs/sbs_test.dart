import 'dart:convert';

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

/// A FakeNetworkClient that returns custom SBS from server on `method=sc` requests.
class SBSNetworkClient extends NetworkClient {
  final List<Map<String, dynamic>> sent = [];
  final Map<String, dynamic> serverSBS;
  SBSNetworkClient(String baseUrl, this.serverSBS) : super(baseUrl);

  @override
  Future<http.Response> makeRequest(Map<String, dynamic> data, String endPoint) async {
    sent.add(Map<String, dynamic>.from(data));
    if (data['method'] == 'sc') {
      return FakeResponseSuccess(body: jsonEncode(serverSBS));
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

  group('SBS - Master Switches', () {
    testWidgets('tracking=false blocks events and new requests', (WidgetTester tester) async {
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
          'c': {'tracking': false}
        },
      );
      final sdk = await Countly.init(cfg);

      await sdk.events.record(key: 'blocked_event', count: 1);
      expect(sdk.debugEventQueueLength, 0, reason: 'Events should be blocked when tracking=false');

      await sdk.users.setProperties({'name': 'Blocked'});
      await sdk.processEventsAndRequests();

      // User properties should not have been sent
      final userReqs = network.sent.where((r) => r.containsKey('user_details')).toList();
      expect(userReqs, isEmpty, reason: 'User properties should be blocked when tracking=false');
    });

    testWidgets('networking=false prevents requests from being sent', (WidgetTester tester) async {
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
          'c': {'networking': false}
        },
      );
      final sdk = await Countly.init(cfg);

      await sdk.events.record(key: 'queued_event', count: 1);
      await sdk.processEventsAndRequests();

      // Requests should accumulate in the request queue but not be sent
      // (SBS fetch and healthcheck are direct calls, not through _processRequestQueue)
      final eventRequests = network.sent.where((r) => r.containsKey('events')).toList();
      expect(eventRequests, isEmpty, reason: 'No event requests should be sent when networking=false');
      expect(sdk.debugRequestQueueLength, greaterThan(0), reason: 'Requests should accumulate in queue');
    });

    testWidgets('cet=false disables custom event tracking', (WidgetTester tester) async {
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
          'c': {'cet': false}
        },
      );
      final sdk = await Countly.init(cfg);

      await sdk.events.record(key: 'any_event', count: 1);
      expect(sdk.debugEventQueueLength, 0, reason: 'No events should be recorded when cet=false');
    });
  });

  group('SBS - Event Filtering', () {
    testWidgets('event blacklist drops matching events', (WidgetTester tester) async {
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
          'c': {
            'eb': ['blocked_event']
          }
        },
      );
      final sdk = await Countly.init(cfg);

      await sdk.events.record(key: 'blocked_event', count: 1);
      await sdk.events.record(key: 'allowed_event', count: 1);

      expect(sdk.debugEventQueueLength, 1);
      expect(sdk.debugEventQueueSnapshot.first['key'], 'allowed_event');
    });

    testWidgets('event whitelist allows only listed events', (WidgetTester tester) async {
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
          'c': {
            'ew': ['permitted_event']
          }
        },
      );
      final sdk = await Countly.init(cfg);

      await sdk.events.record(key: 'permitted_event', count: 1);
      await sdk.events.record(key: 'other_event', count: 1);

      expect(sdk.debugEventQueueLength, 1);
      expect(sdk.debugEventQueueSnapshot.first['key'], 'permitted_event');
    });
  });

  group('SBS - Segmentation Filtering', () {
    testWidgets('segmentation blacklist removes matching keys', (WidgetTester tester) async {
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
          'c': {
            'sb': ['secret_key']
          }
        },
      );
      final sdk = await Countly.init(cfg);

      await sdk.events.record(
        key: 'evt',
        segmentation: {'secret_key': 'val', 'ok_key': 'val'},
      );

      final seg = sdk.debugEventQueueSnapshot.first['segmentation'] as Map<String, dynamic>;
      expect(seg.containsKey('ok_key'), isTrue);
      expect(seg.containsKey('secret_key'), isFalse, reason: 'Blacklisted segmentation key should be removed');
    });

    testWidgets('segmentation whitelist allows only listed keys', (WidgetTester tester) async {
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
          'c': {
            'sw': ['allowed_seg']
          }
        },
      );
      final sdk = await Countly.init(cfg);

      await sdk.events.record(
        key: 'evt',
        segmentation: {'allowed_seg': 1, 'banned_seg': 2},
      );

      final seg = sdk.debugEventQueueSnapshot.first['segmentation'] as Map<String, dynamic>;
      expect(seg.containsKey('allowed_seg'), isTrue);
      expect(seg.containsKey('banned_seg'), isFalse, reason: 'Non-whitelisted segmentation key should be removed');
    });

    testWidgets('per-event segmentation blacklist applies only to matching event', (WidgetTester tester) async {
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
          'c': {
            'esb': {
              'purchase': ['internal_id']
            }
          }
        },
      );
      final sdk = await Countly.init(cfg);

      await sdk.events.record(
        key: 'purchase',
        segmentation: {'internal_id': '123', 'category': 'food'},
      );
      await sdk.events.record(
        key: 'other_event',
        segmentation: {'internal_id': '456', 'category': 'tech'},
      );

      final purchaseSeg = sdk.debugEventQueueSnapshot[0]['segmentation'] as Map<String, dynamic>;
      expect(purchaseSeg.containsKey('internal_id'), isFalse, reason: 'internal_id should be removed for purchase');
      expect(purchaseSeg.containsKey('category'), isTrue);

      final otherSeg = sdk.debugEventQueueSnapshot[1]['segmentation'] as Map<String, dynamic>;
      expect(otherSeg.containsKey('internal_id'), isTrue, reason: 'internal_id should NOT be removed for other_event');
    });

    testWidgets('per-event segmentation whitelist overrides global blacklist', (WidgetTester tester) async {
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
          'c': {
            'sb': ['price'], // globally blacklisted
            'esw': {
              'checkout': ['price', 'currency'] // but whitelisted for checkout
            }
          }
        },
      );
      final sdk = await Countly.init(cfg);

      await sdk.events.record(
        key: 'checkout',
        segmentation: {'price': 10, 'currency': 'USD', 'debug': true},
      );

      final seg = sdk.debugEventQueueSnapshot.first['segmentation'] as Map<String, dynamic>;
      expect(seg.containsKey('price'), isTrue, reason: 'Per-event whitelist should override global blacklist');
      expect(seg.containsKey('currency'), isTrue);
      expect(seg.containsKey('debug'), isFalse, reason: 'Non-whitelisted key should be removed');
    });
  });

  group('SBS - User Properties Filtering', () {
    testWidgets('user properties blacklist removes matching keys', (WidgetTester tester) async {
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
          'c': {
            'upb': ['ssn']
          }
        },
      );
      final sdk = await Countly.init(cfg);

      await sdk.users.setProperties({'ssn': '123-45-6789', 'name': 'Alice'});
      await sdk.processEventsAndRequests();

      final userReqs = network.sent.where((r) => r.containsKey('user_details')).toList();
      expect(userReqs, isNotEmpty);

      final details = userReqs.last['user_details'] as Map<String, dynamic>;
      expect(details['name'], 'Alice');
      // ssn is a custom property, should be under 'custom' but blacklisted
      final custom = details['custom'] as Map<String, dynamic>?;
      expect(custom == null || !custom.containsKey('ssn'), isTrue, reason: 'Blacklisted user property should be removed');
    });

    testWidgets('user properties whitelist allows only listed keys', (WidgetTester tester) async {
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
          'c': {
            'upw': ['name', 'email']
          }
        },
      );
      final sdk = await Countly.init(cfg);

      await sdk.users.setProperties({'name': 'Alice', 'email': 'a@b.com', 'phone': '555'});
      await sdk.processEventsAndRequests();

      final userReqs = network.sent.where((r) => r.containsKey('user_details')).toList();
      expect(userReqs, isNotEmpty);

      final details = userReqs.last['user_details'] as Map<String, dynamic>;
      expect(details['name'], 'Alice');
      expect(details['email'], 'a@b.com');
      expect(details.containsKey('phone'), isFalse, reason: 'Non-whitelisted user property should be removed');
    });
  });

  group('SBS - Truncation Limits', () {
    testWidgets('key length limit truncates long event keys', (WidgetTester tester) async {
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

      await sdk.events.record(key: 'a_very_long_event_key_name');

      final evt = sdk.debugEventQueueSnapshot.first;
      expect(evt['key'], 'a_very_lon', reason: 'Event key should be truncated to lkl limit');
    });

    testWidgets('value size limit truncates long segmentation values', (WidgetTester tester) async {
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
          'c': {'lvs': 5}
        },
      );
      final sdk = await Countly.init(cfg);

      await sdk.events.record(key: 'evt', segmentation: {'k': 'abcdefgh'});

      final seg = sdk.debugEventQueueSnapshot.first['segmentation'] as Map<String, dynamic>;
      expect(seg['k'], 'abcde', reason: 'String value should be truncated to lvs limit');
    });

    testWidgets('segmentation values count limit caps entries', (WidgetTester tester) async {
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
          'c': {'lsv': 2}
        },
      );
      final sdk = await Countly.init(cfg);

      await sdk.events.record(
        key: 'evt',
        segmentation: {'a': 1, 'b': 2, 'c': 3, 'd': 4},
      );

      final seg = sdk.debugEventQueueSnapshot.first['segmentation'] as Map<String, dynamic>;
      expect(seg.length, 2, reason: 'Segmentation should be capped at lsv limit');
    });
  });

  group('SBS - Queue Size Limits', () {
    testWidgets('event queue size triggers auto-bundling', (WidgetTester tester) async {
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
          'c': {'eqs': 3}
        },
      );
      final sdk = await Countly.init(cfg);

      // Record 3 events - should fill queue
      await sdk.events.record(key: 'e1');
      await sdk.events.record(key: 'e2');
      await sdk.events.record(key: 'e3');

      // At this point, the queue hit the limit at e3 and auto-bundled e1, e2
      // Then e3 was added. The 4th event should trigger another bundle.
      await sdk.events.record(key: 'e4');

      // The event queue should have been auto-bundled at least once
      // Check that an events request was created in the request queue
      final rqSnapshot = sdk.debugRequestQueueSnapshot;
      final hasEventsRequest = rqSnapshot.any((r) => r.containsKey('events'));
      expect(hasEventsRequest, isTrue, reason: 'Auto-bundling should create events request when queue overflows');
    });
  });

  group('SBS - Server Fetch and Persist', () {
    testWidgets('SBS fetched from server is applied and persisted', (WidgetTester tester) async {
      final network = SBSNetworkClient('https://example.com', {
        'c': {
          'eb': ['server_blocked']
        }
      });
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

      // Wait for async SBS fetch to complete
      await Future.delayed(const Duration(milliseconds: 500));

      await sdk.events.record(key: 'server_blocked');
      await sdk.events.record(key: 'allowed');

      expect(sdk.debugEventQueueLength, 1);
      expect(sdk.debugEventQueueSnapshot.first['key'], 'allowed', reason: 'Server-fetched blacklist should block event');
    });
  });
}
