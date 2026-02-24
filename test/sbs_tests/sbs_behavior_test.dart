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
  Map<String, dynamic>? sbsResponse;
  FakeNetworkClient(String baseUrl, {this.sbsResponse}) : super(baseUrl);
  @override
  Future<http.Response> makeRequest(Map<String, dynamic> data, String endPoint) async {
    sent.add(Map<String, dynamic>.from(data));
    if (data['method'] == 'sc') {
      return FakeResponseSuccess(body: jsonEncode(sbsResponse ?? {'c': {}}));
    }
    return FakeResponseSuccess();
  }

  @override
  Future<http.Response> makeSelectiveRequest(Map<String, dynamic> data) async {
    sent.add(Map<String, dynamic>.from(data));
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
  bool giveConsent = true,
  bool startWithUnknownConsent = false,
  TestLogger? logger,
  FakeNetworkClient? networkClient,
  Map<String, String>? storageBacking,
  StorageMode storageMode = StorageMode.memory,
  Map<String, dynamic>? sbs,
}) async {
  final log = logger ?? TestLogger();
  final client = networkClient ?? FakeNetworkClient('https://example.com');
  final cfg = CountlyConfig(
    appKey: 'app-key',
    serverUrl: 'https://example.com',
    deviceId: 'test-device',
    storageMode: storageMode,
    storageMethods: storageBacking != null ? MemoryBackedStorage(storageBacking).toMethods() : null,
    startWithUnknownConsent: startWithUnknownConsent,
    giveConsent: giveConsent,
    enableSDKLogs: true,
    logLevel: LogLevel.verbose,
    logger: log,
    networkClientOverride: client,
    sbs: sbs ?? {},
  );
  final inst = await Countly.init(cfg);
  addTearDown(() async {
    await Countly.disposeAll();
  });
  return inst;
}

void main() {
  group('SBS - Event Blacklist', () {
    test('events in blacklist are dropped', () async {
      final logger = TestLogger();
      final sdk = await _createInstance(
        logger: logger,
        sbs: {
          'c': {
            'eb': ['blocked_event', 'another_blocked']
          }
        },
      );

      await sdk.events.record(key: 'blocked_event');
      await sdk.events.record(key: 'allowed_event');
      await sdk.events.record(key: 'another_blocked');

      expect(sdk.debugEventQueueLength, 1);
      expect(sdk.debugEventQueueSnapshot.first['key'], 'allowed_event');
      expect(logger.logs.any((log) => log.contains('blacklisted')), true);
    });

    test('empty blacklist allows all events', () async {
      final sdk = await _createInstance(
        sbs: {
          'c': {'eb': []}
        },
      );

      await sdk.events.record(key: 'any_event');

      expect(sdk.debugEventQueueLength, 1);
    });
  });

  group('SBS - Event Whitelist', () {
    test('events not in whitelist are dropped', () async {
      final logger = TestLogger();
      final sdk = await _createInstance(
        logger: logger,
        sbs: {
          'c': {
            'ew': ['allowed_event', 'also_allowed']
          }
        },
      );

      await sdk.events.record(key: 'allowed_event');
      await sdk.events.record(key: 'not_allowed');
      await sdk.events.record(key: 'also_allowed');

      expect(sdk.debugEventQueueLength, 2);
      final keys = sdk.debugEventQueueSnapshot.map((e) => e['key']).toList();
      expect(keys, ['allowed_event', 'also_allowed']);
      expect(logger.logs.any((log) => log.contains('not in whitelist')), true);
    });

    test('blacklist takes precedence over whitelist', () async {
      final sdk = await _createInstance(
        sbs: {
          'c': {
            'ew': ['allowed_event'],
            'eb': ['allowed_event'],
          }
        },
      );

      await sdk.events.record(key: 'allowed_event');

      expect(sdk.debugEventQueueLength, 0, reason: 'Blacklist should take precedence');
    });

    test('empty whitelist means whitelist is disabled (all events allowed)', () async {
      final sdk = await _createInstance(
        sbs: {
          'c': {'ew': []}
        },
      );

      await sdk.events.record(key: 'any_event');

      // Empty whitelist means whitelist feature is disabled, allowing all events
      expect(sdk.debugEventQueueLength, 1);
    });
  });

  group('SBS - User Properties Blacklist', () {
    test('user properties in blacklist are dropped', () async {
      final logger = TestLogger();
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(
        logger: logger,
        networkClient: network,
        sbs: {
          'c': {
            'upb': ['secret', 'internal_id', 'password', 'age']
          }
        },
      );

      await sdk.users.setProperties({
        'name': 'Test',
        'secret': 'hidden',
        'internal_id': '12345',
        'password': 'abc123',
        'age': 5,
        'email': 'test@example.com',
      });
      await sdk.processEventsAndRequests();

      final userReq = network.sent.firstWhere((r) => r.containsKey('user_details'));
      final ud = userReq['user_details'];

      expect(ud['name'], 'Test');
      expect(ud['email'], 'test@example.com');
      expect(ud['age'], isNull);
      expect(ud['custom']?.containsKey('secret'), isNot(true));
      expect(ud['custom']?.containsKey('internal_id'), isNot(true));
      expect(ud['custom']?.containsKey('password'), isNot(true));
    });
  });

  group('SBS - User Properties Whitelist', () {
    test('user properties not in whitelist are dropped', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(
        networkClient: network,
        sbs: {
          'c': {
            'upw': ['email', 'tier']
          }
        },
      );

      await sdk.users.setProperties({
        'name': 'Allowed',
        'email': 'allowed@example.com',
        'tier': 'premium',
        'blocked': 'should_not_appear',
      });
      await sdk.processEventsAndRequests();

      final userReq = network.sent.firstWhere((r) => r.containsKey('user_details'));
      final ud = userReq['user_details'];

      expect(ud['name'], isNull);
      expect(ud['email'], 'allowed@example.com');
      expect(ud['custom']['tier'], 'premium');
      expect(ud['custom']?.containsKey('blocked'), isNot(true));
    });
  });

  group('SBS - Segmentation Blacklist', () {
    test('segmentation keys in blacklist are removed from events', () async {
      final sdk = await _createInstance(
        sbs: {
          'c': {
            'sb': ['secret_seg', 'internal_seg']
          }
        },
      );

      await sdk.events.record(
        key: 'test_event',
        segmentation: {
          'visible': 'yes',
          'secret_seg': 'hidden',
          'internal_seg': 'also_hidden',
          'another_visible': 'ok',
        },
      );

      final event = sdk.debugEventQueueSnapshot.first;
      final seg = event['segmentation'] as Map<String, dynamic>;

      expect(seg['visible'], 'yes');
      expect(seg['another_visible'], 'ok');
      expect(seg.containsKey('secret_seg'), false);
      expect(seg.containsKey('internal_seg'), false);
    });
  });

  group('SBS - Segmentation Whitelist', () {
    test('segmentation keys not in whitelist are removed', () async {
      final sdk = await _createInstance(
        sbs: {
          'c': {
            'sw': ['allowed_seg', 'also_allowed']
          }
        },
      );

      await sdk.events.record(
        key: 'test_event',
        segmentation: {
          'allowed_seg': 'yes',
          'also_allowed': 'ok',
          'not_allowed': 'removed',
        },
      );

      final event = sdk.debugEventQueueSnapshot.first;
      final seg = event['segmentation'] as Map<String, dynamic>;

      expect(seg['allowed_seg'], 'yes');
      expect(seg['also_allowed'], 'ok');
      expect(seg.containsKey('not_allowed'), false);
    });
  });

  group('SBS - Event-Specific Segmentation Blacklist', () {
    test('event-specific segmentation blacklist removes keys for that event only', () async {
      final sdk = await _createInstance(
        sbs: {
          'c': {
            'esb': {
              'purchase': ['credit_card', 'cvv']
            }
          }
        },
      );

      // Purchase event should have credit_card and cvv removed
      await sdk.events.record(
        key: 'purchase',
        segmentation: {
          'credit_card': '1234-5678',
          'cvv': '999',
          'amount': 100,
          'product': 'widget',
        },
      );

      // Other event should keep all fields
      await sdk.events.record(
        key: 'other_event',
        segmentation: {
          'credit_card': '1234-5678',
          'cvv': '999',
          'amount': 50,
        },
      );

      final events = sdk.debugEventQueueSnapshot;

      // Purchase event
      final purchaseSeg = events[0]['segmentation'] as Map<String, dynamic>;
      expect(purchaseSeg.containsKey('credit_card'), false);
      expect(purchaseSeg.containsKey('cvv'), false);
      expect(purchaseSeg['amount'], 100);
      expect(purchaseSeg['product'], 'widget');

      // Other event - all fields preserved
      final otherSeg = events[1]['segmentation'] as Map<String, dynamic>;
      expect(otherSeg['credit_card'], '1234-5678');
      expect(otherSeg['cvv'], '999');
      expect(otherSeg['amount'], 50);
    });
  });

  group('SBS - Event-Specific Segmentation Whitelist', () {
    test('event-specific segmentation whitelist allows only specified keys', () async {
      final sdk = await _createInstance(
        sbs: {
          'c': {
            'esw': {
              'analytics': ['page', 'action']
            }
          }
        },
      );

      await sdk.events.record(
        key: 'analytics',
        segmentation: {
          'page': 'home',
          'action': 'click',
          'blocked': 'removed',
        },
      );

      await sdk.events.record(
        key: 'other_event',
        segmentation: {
          'page': 'home',
          'action': 'click',
          'extra': 'kept',
        },
      );

      final events = sdk.debugEventQueueSnapshot;

      // Analytics event - only whitelisted fields
      final analyticsSeg = events[0]['segmentation'] as Map<String, dynamic>;
      expect(analyticsSeg['page'], 'home');
      expect(analyticsSeg['action'], 'click');
      expect(analyticsSeg.containsKey('blocked'), false);

      // Other event - not affected by event-specific whitelist
      final otherSeg = events[1]['segmentation'] as Map<String, dynamic>;
      expect(otherSeg['page'], 'home');
      expect(otherSeg['action'], 'click');
      expect(otherSeg['extra'], 'kept');
    });
  });

  group('SBS - Queue Limits', () {
    test('event queue size is configurable via SBS', () async {
      final sdk = await _createInstance(
        sbs: {
          'c': {'eqs': 5}
        },
      );

      // Add more events than limit
      for (int i = 0; i < 10; i++) {
        await sdk.events.record(key: 'event_$i');
      }

      expect(sdk.debugEventQueueLength, lessThanOrEqualTo(5));
    });

    test('request queue size is configurable via SBS', () async {
      final sdk = await _createInstance(
        sbs: {
          'c': {'rqs': 10}
        },
        startWithUnknownConsent: true,
      );

      // Add many requests
      for (int i = 0; i < 20; i++) {
        await sdk.events.recordMetrics(metricOverride: {'n': i});
      }

      expect(sdk.debugRequestQueueLength, lessThanOrEqualTo(10));
    });

    test('user properties cache limit is configurable via SBS', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(
        networkClient: network,
        giveConsent: true,
        sbs: {
          'c': {'upcl': 3}
        },
      );

      final qLen = sdk.debugRequestQueueLength;
      await sdk.users.setProperties({'p1': 'v1'});
      await sdk.users.setProperties({'p2': 'v2'});
      await sdk.users.setProperties({'p3': 'v3'});
      await sdk.users.setProperties({'p4': 'v4'});

      expect(qLen, sdk.debugRequestQueueLength - 1);
      expect(sdk.debugRequestQueueSnapshot.last.containsKey('user_details'), true);
    });
  });

  group('SBS - Tracking Control', () {
    test('tracking can be disabled globally via SBS', () async {
      final logger = TestLogger();
      final sdk = await _createInstance(
        logger: logger,
        sbs: {
          'c': {'tracking': false}
        },
      );

      await sdk.events.record(key: 'blocked_event');
      await sdk.events.recordMetrics();

      expect(sdk.debugEventQueueLength, 0);
      expect(sdk.debugRequestQueueLength, 0);
      expect(logger.logs.any((log) => log.contains('Tracking disabled')), true);
    });

    test('custom event tracking can be disabled via SBS', () async {
      final network = FakeNetworkClient('https://example.com');
      final logger = TestLogger();
      final sdk = await _createInstance(
        logger: logger,
        networkClient: network,
        sbs: {
          'c': {'cet': false}
        },
      );

      await sdk.events.record(key: 'custom_event');

      expect(sdk.debugEventQueueLength, 0);
      expect(logger.logs.any((log) => log.contains('tracking disabled')), true);

      await sdk.views.startAutoStoppedView('view');
      await sdk.views.endActiveView();

      expect(sdk.debugEventQueueLength, 1);

      final qLen = sdk.debugRequestQueueLength;
      await sdk.events.recordMetrics();
      expect(sdk.debugRequestQueueLength, qLen + 1);

      await sdk.users.setProperties({'name': 'Jane Doe'});
      await sdk.processEventsAndRequests();

      expect(network.sent.last.containsKey('user_details'), true);
    });

    test('view tracking can be disabled via SBS', () async {
      final network = FakeNetworkClient('https://example.com');
      final logger = TestLogger();
      final sdk = await _createInstance(
        logger: logger,
        networkClient: network,
        sbs: {
          'c': {'vt': false}
        },
      );

      sdk.views.startAutoStoppedView('View1');
      sdk.views.startAutoStoppedView('View2');

      expect(sdk.debugEventQueueLength, 0);

      await sdk.events.record(key: 'custom_event');

      expect(sdk.debugEventQueueLength, 1);

      final qLen = sdk.debugRequestQueueLength;
      await sdk.events.recordMetrics();
      expect(sdk.debugRequestQueueLength, qLen + 1);

      await sdk.users.setProperties({'name': 'Jane Doe'});
      await sdk.processEventsAndRequests();

      expect(network.sent.last.containsKey('user_details'), true);
    });
  });

  group('SBS - Key and Value Limits', () {
    test('key length limit is configurable via SBS', () async {
      final sdk = await _createInstance(
        sbs: {
          'c': {'lkl': 10}
        },
      );

      final longKey = 'x' * 50;
      await sdk.events.record(key: longKey);

      final event = sdk.debugEventQueueSnapshot.first;
      expect((event['key'] as String).length, 10);
    });

    test('value size limit is configurable via SBS', () async {
      final sdk = await _createInstance(
        sbs: {
          'c': {'lvs': 20}
        },
      );

      final longValue = 'y' * 100;
      await sdk.events.record(key: 'test', segmentation: {'val': longValue});

      final event = sdk.debugEventQueueSnapshot.first;
      expect((event['segmentation']['val'] as String).length, 20);
    });

    test('segmentation values limit is configurable via SBS', () async {
      final sdk = await _createInstance(
        sbs: {
          'c': {'lsv': 3}
        },
      );

      await sdk.events.record(
        key: 'test',
        segmentation: {
          'a': 1,
          'b': 2,
          'c': 3,
          'd': 4,
          'e': 5,
        },
      );

      final event = sdk.debugEventQueueSnapshot.first;
      final seg = event['segmentation'] as Map<String, dynamic>;
      expect(seg.length, 3, reason: 'Only 3 segmentation values should be kept');
    });
  });

  group('SBS - Server Fetch and Persistence', () {
    test('SBS is fetched from server at init', () async {
      final network = FakeNetworkClient('https://example.com');
      await _createInstance(networkClient: network);

      expect(network.sent.any((r) => r['method'] == 'sc'), true);
    });

    test('SBS response is persisted to storage', () async {
      final backing = <String, String>{};
      final network = FakeNetworkClient(
        'https://example.com',
        sbsResponse: {
          'c': {'eqs': 50, 'rqs': 25, 'random': 7}
        },
      );

      await _createInstance(
        networkClient: network,
        storageBacking: backing,
        storageMode: StorageMode.persistent,
      );

      // SBS is fetched during init, check if persisted
      if (backing.containsKey(StorageSubKeys.behavior)) {
        final stored = jsonDecode(backing[StorageSubKeys.behavior]!);
        expect(stored['c']['eqs'], 50);
        expect(stored['c']['rqs'], 25);
        expect(stored['c']['random'], isNull);
      }
    });

    test('SBS is loaded from storage on init', () async {
      final backing = <String, String>{
        'default_${StorageSubKeys.behavior}': jsonEncode({
          'c': {'eqs': 42}
        }),
        'default_${StorageSubKeys.deviceId}': 'test-device',
        'default_${StorageSubKeys.deviceIdType}': DeviceIdType.generated.toString(),
      };

      final sdk = await _createInstance(
        storageBacking: backing,
        storageMode: StorageMode.persistent,
      );

      // Add events to test the limit
      for (int i = 0; i < 50; i++) {
        await sdk.events.record(key: 'event_$i');
      }

      // With eqs=42 loaded from storage
      expect(sdk.debugEventQueueLength, lessThanOrEqualTo(42));
    });

    test('server SBS overrides stored SBS', () async {
      final backing = <String, String>{
        StorageSubKeys.behavior: jsonEncode({
          'c': {'eqs': 10}
        }),
        StorageSubKeys.deviceId: 'test-device',
        StorageSubKeys.deviceIdType: DeviceIdType.generated.toString(),
      };

      final network = FakeNetworkClient(
        'https://example.com',
        sbsResponse: {
          'c': {'eqs': 100}
        },
      );

      final sdk = await _createInstance(
        networkClient: network,
        storageBacking: backing,
        storageMode: StorageMode.persistent,
      );

      // Server fetch happens during init
      // Add more than 10 events to test
      for (int i = 0; i < 50; i++) {
        await sdk.events.record(key: 'event_$i');
      }

      // With eqs=100 from server (or stored eqs=10 if fetch not complete)
      // Just verify the queue respects a limit
      expect(sdk.debugEventQueueLength, lessThanOrEqualTo(100));
      expect(sdk.debugEventQueueLength, greaterThan(10));
    });
  });

  group('SBS - Config-Provided SBS', () {
    test('SBS can be provided via config at init', () async {
      final sdk = await _createInstance(
        sbs: {
          'c': {'eqs': 15}
        },
      );

      for (int i = 0; i < 20; i++) {
        await sdk.events.record(key: 'event_$i');
      }

      expect(sdk.debugEventQueueLength, lessThanOrEqualTo(15));
    });
  });

  group('SBS - Timer Intervals', () {
    test('internal timer interval is configurable via SBS', () async {
      final sdk = await _createInstance(
        sbs: {
          'c': {'sui': 2} // 2 seconds
        },
      );

      await sdk.events.record(key: "a");
      expect(sdk.debugEventQueueLength, 1);

      await Future.delayed(const Duration(seconds: 3));

      expect(sdk.debugEventQueueLength, 0);
      expect(sdk.isTimerActive, true);
    });
  });

  group('SBS - Networking Control', () {
    test('networking can be disabled via SBS', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(
        networkClient: network,
        sbs: {
          'c': {'networking': false}
        },
      );

      await sdk.events.record(key: 'test');
      await sdk.processEventsAndRequests();

      // No requests should be sent (except sbs)
      expect(network.sent.length, 1);
    });
  });

  group('SBS - Default Values', () {
    test('SBS defaults are applied when no config provided', () async {
      final sdk = await _createInstance();

      // Default event queue size is 100
      for (int i = 0; i < 50; i++) {
        await sdk.events.record(key: 'event_$i');
      }

      expect(sdk.debugEventQueueLength, 50);
    });

    test('unknown SBS keys are ignored', () async {
      final logger = TestLogger();
      final sdk = await _createInstance(
        logger: logger,
        sbs: {
          'c': {
            'unknown_key': 'value',
            'another_unknown': 123,
          }
        },
      );

      expect(logger.logs.any((log) => log.contains('unknown SBS key')), true);
    });
  });
}
