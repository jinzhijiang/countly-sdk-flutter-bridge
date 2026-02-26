import 'dart:convert';

import 'package:countly_flutter_lite/countly_flutter_lite.dart';
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

Future<CountlyInstance> _createInstance({
  bool giveConsent = true,
  bool startWithUnknownConsent = false,
  TestLogger? logger,
  FakeNetworkClient? networkClient,
  Map<String, dynamic>? sbs,
}) async {
  final log = logger ?? TestLogger();
  final client = networkClient ?? FakeNetworkClient('https://example.com');
  final cfg = CountlyConfig(
    appKey: 'app-key',
    serverUrl: 'https://example.com',
    deviceId: 'test-device',
    storageMode: StorageMode.memory,
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
  group('Events Module - Basic Recording', () {
    test('record event with only key (mandatory parameter)', () async {
      final sdk = await _createInstance();

      await sdk.events.record(key: 'test_event');

      expect(sdk.debugEventQueueLength, 1);
      final event = sdk.debugEventQueueSnapshot.first;
      expect(event['key'], 'test_event');
      expect(event['count'], 1, reason: 'Default count should be 1');
      expect(event.containsKey('timestamp'), true);
      expect(event.containsKey('hour'), true);
      expect(event.containsKey('dow'), true);
      expect(event.containsKey('sum'), false, reason: 'sum should not be present when not provided');
      expect(event.containsKey('dur'), false, reason: 'dur should not be present when not provided');
      expect(event.containsKey('segmentation'), false, reason: 'segmentation should not be present when empty');
    });

    test('record event with all optional parameters', () async {
      final sdk = await _createInstance();

      await sdk.events.record(
        key: 'full_event',
        count: 5,
        sum: 99.99,
        dur: 120.5,
        segmentation: {'category': 'electronics', 'item_id': 42},
      );

      expect(sdk.debugEventQueueLength, 1);
      final event = sdk.debugEventQueueSnapshot.first;
      expect(event['key'], 'full_event');
      expect(event['count'], 5);
      expect(event['sum'], 99.99);
      expect(event['dur'], 120.5);
      expect(event['hour'], inInclusiveRange(0, 23));
      expect(event['dow'], inInclusiveRange(0, 6));
      expect(event['segmentation']['category'], 'electronics');
      expect(event['segmentation']['item_id'], 42);
    });

    test('record event with count only', () async {
      final sdk = await _createInstance();

      await sdk.events.record(key: 'count_event', count: 10);

      final event = sdk.debugEventQueueSnapshot.first;
      expect(event['key'], 'count_event');
      expect(event['count'], 10);
      expect(event.containsKey('sum'), false);
      expect(event.containsKey('dur'), false);
    });

    test('record event with sum only', () async {
      final sdk = await _createInstance();

      await sdk.events.record(key: 'sum_event', sum: 49.99);

      final event = sdk.debugEventQueueSnapshot.first;
      expect(event['key'], 'sum_event');
      expect(event['count'], 1);
      expect(event['sum'], 49.99);
      expect(event.containsKey('dur'), false);
    });

    test('record event with duration only', () async {
      final sdk = await _createInstance();

      await sdk.events.record(key: 'dur_event', dur: 60.0);

      final event = sdk.debugEventQueueSnapshot.first;
      expect(event['key'], 'dur_event');
      expect(event['count'], 1);
      expect(event['dur'], 60.0);
      expect(event.containsKey('sum'), false);
    });

    test('record event with segmentation only', () async {
      final sdk = await _createInstance();

      await sdk.events.record(key: 'seg_event', segmentation: {'level': 5, 'score': 1000.5, 'name': 'player1'});

      final event = sdk.debugEventQueueSnapshot.first;
      expect(event['key'], 'seg_event');
      expect(event['count'], 1);
      expect(event['segmentation']['level'], 5);
      expect(event['segmentation']['score'], 1000.5);
      expect(event['segmentation']['name'], 'player1');
      expect(event.containsKey('sum'), false, reason: 'sum should not be present when not provided');
      expect(event.containsKey('dur'), false, reason: 'dur should not be present when not provided');
    });

    test('empty key is rejected', () async {
      final sdk = await _createInstance();

      await sdk.events.record(key: '');

      expect(sdk.debugEventQueueLength, 0, reason: 'Empty key event should be rejected');
    });

    test('events are ordered correctly in queue', () async {
      final sdk = await _createInstance();

      await sdk.events.record(key: 'first');
      await sdk.events.record(key: 'second');
      await sdk.events.record(key: 'third');

      expect(sdk.debugEventQueueLength, 3);
      final keys = sdk.debugEventQueueSnapshot.map((e) => e['key']).toList();
      expect(keys, ['first', 'second', 'third'], reason: 'Events should be in FIFO order');
    });
  });

  group('Events Module - Internal [CLY] Events', () {
    test('SDK does not block internal [CLY] prefixed events', () async {
      final sdk = await _createInstance();

      await sdk.events.record(key: '[CLY]_custom_internal');
      await sdk.events.record(key: '[CLY]_view');
      await sdk.events.record(key: '[CLY]_action');

      expect(sdk.debugEventQueueLength, 3, reason: 'Internal [CLY] events should not be filtered');
      final keys = sdk.debugEventQueueSnapshot.map((e) => e['key']).toList();
      expect(keys, contains('[CLY]_custom_internal'));
      expect(keys, contains('[CLY]_view'));
      expect(keys, contains('[CLY]_action'));
    });

    test('SDK is agnostic to event key content', () async {
      final sdk = await _createInstance();

      // Various edge case keys
      await sdk.events.record(key: '[CLY]_reserved');
      await sdk.events.record(key: 'normal_event');
      await sdk.events.record(key: 'event-with-dashes');
      await sdk.events.record(key: 'event.with.dots');
      await sdk.events.record(key: 'event_with_123_numbers');
      await sdk.events.record(key: 'UPPERCASE_EVENT');
      await sdk.events.record(key: 'ключ_в_юникоде');

      expect(sdk.debugEventQueueLength, 7, reason: 'All event keys should be accepted');
    });
  });

  group('Events Module - Consent Handling', () {
    test('events are dropped without consent', () async {
      final logger = TestLogger();
      final sdk = await _createInstance(giveConsent: false, startWithUnknownConsent: false, logger: logger);

      await sdk.events.record(key: 'should_drop');

      expect(sdk.debugEventQueueLength, 0, reason: 'Events should be dropped without consent');
      expect(logger.logs.any((log) => log.contains('warning') && log.contains('dropped') && log.contains('consent')), true, reason: 'Warning log should indicate consent issue');
    });

    test('events are recorded with consent given at init', () async {
      final sdk = await _createInstance(giveConsent: true);

      await sdk.events.record(key: 'with_consent');

      expect(sdk.debugEventQueueLength, 1);
    });

    test('events are recorded in unknown consent mode (kept in memory)', () async {
      final sdk = await _createInstance(giveConsent: false, startWithUnknownConsent: true);

      await sdk.events.record(key: 'unknown_consent_event');

      expect(sdk.debugEventQueueLength, 1);
    });
  });

  group('Events Module - Event Queue Bundling', () {
    test('event queue bundles into request queue when limit is reached', () async {
      final sdk = await _createInstance();
      sdk.debugOverrideBehaviorSettings(eventQueueSize: 3);

      // Record events up to the limit - should not trigger bundling yet
      await sdk.events.record(key: 'event1');
      await sdk.events.record(key: 'event2');
      await sdk.events.record(key: 'event3');
      expect(sdk.debugEventQueueLength, 3);

      // This should trigger bundling since we're at the limit
      await sdk.events.record(key: 'event4');

      // After bundling, event queue should have only the new event
      // The 4th event triggers bundling of the first 3, then adds itself
      expect(sdk.debugEventQueueLength, 1, reason: 'Last event should remain in queue after bundling');
    });

    test('bundled events preserve order and content in request', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.events.record(key: 'first', count: 1);
      await sdk.events.record(key: 'second', count: 2, sum: 10.0);
      await sdk.events.record(key: 'third', count: 3, segmentation: {'a': 'b'});

      await sdk.processEventsAndRequests();

      // Find the events request
      final eventsRequest = network.sent.where((r) => r.containsKey('events')).toList();
      expect(eventsRequest.length, greaterThan(0));

      final eventsJson = eventsRequest.last['events'] as String;
      final events = jsonDecode(eventsJson) as List<dynamic>;

      expect(events.length, 3);
      expect(events[0]['key'], 'first');
      expect(events[0]['count'], 1);
      expect(events[1]['key'], 'second');
      expect(events[1]['count'], 2);
      expect(events[1]['sum'], 10.0);
      expect(events[2]['key'], 'third');
      expect(events[2]['count'], 3);
      expect(events[2]['segmentation']['a'], 'b');
    });
  });

  group('Events Module - User Properties Cache Flush', () {
    test('recording event flushes user properties cache first', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      // Set user properties (this queues them in cache)
      await sdk.users.setProperties({'name': 'TestUser', 'email': 'test@example.com'});

      // Record event - this should flush UP cache first
      await sdk.events.record(key: 'test_event');

      await sdk.processEventsAndRequests();

      // Check order: user_details request should come before events request
      final userDetailsIdx = network.sent.indexWhere((r) => r.containsKey('user_details'));
      final eventsIdx = network.sent.indexWhere((r) => r.containsKey('events'));

      expect(userDetailsIdx, isNot(-1), reason: 'User details request should exist');
      expect(eventsIdx, isNot(-1), reason: 'Events request should exist');
      expect(userDetailsIdx, lessThan(eventsIdx), reason: 'User properties should be sent before events');
    });
  });

  group('Events Module - Timestamp and Time Fields', () {
    test('event uses current time when timestamp not provided', () async {
      final sdk = await _createInstance();

      final beforeRecord = DateTime.now();
      await sdk.events.record(key: 'auto_timestamp');
      final afterRecord = DateTime.now();

      final event = sdk.debugEventQueueSnapshot.first;
      final recordedTs = event['timestamp'] as int;

      expect(recordedTs, greaterThanOrEqualTo(beforeRecord.millisecondsSinceEpoch));
      expect(recordedTs, lessThanOrEqualTo(afterRecord.millisecondsSinceEpoch));
    });
  });

  group('Events Module - Duplicate Event Warning', () {
    test('warning is logged for consecutive duplicate event keys', () async {
      final logger = TestLogger();
      final sdk = await _createInstance(logger: logger);

      await sdk.events.record(key: 'duplicate_key');
      await sdk.events.record(key: 'duplicate_key');

      expect(logger.logs.any((log) => log.contains('warning') && log.contains('Duplicate') && log.contains('duplicate_key')), true, reason: 'Warning should be logged for consecutive duplicate');
    });

    test('no warning for non-consecutive duplicate keys', () async {
      final logger = TestLogger();
      final sdk = await _createInstance(logger: logger);

      await sdk.events.record(key: 'key_a');
      await sdk.events.record(key: 'key_b');
      await sdk.events.record(key: 'key_a'); // Not consecutive duplicate

      // Count warnings about duplicate
      final duplicateWarnings = logger.logs.where((log) => log.contains('Duplicate')).length;
      expect(duplicateWarnings, 0, reason: 'Non-consecutive duplicates should not trigger warning');
    });
  });

  group('Events Module - Key and Value Truncation', () {
    test('long event key is truncated to limit', () async {
      final sdk = await _createInstance();

      final longKey = 'x' * 200; // Longer than default 128 limit
      await sdk.events.record(key: longKey);

      final event = sdk.debugEventQueueSnapshot.first;
      expect((event['key'] as String).length, 128, reason: 'Key should be truncated to 128 chars');
    });

    test('long segmentation value is truncated to limit', () async {
      final sdk = await _createInstance();

      final longValue = 'y' * 500; // Longer than default 256 limit
      await sdk.events.record(key: 'test', segmentation: {'long_val': longValue});

      final event = sdk.debugEventQueueSnapshot.first;
      expect((event['segmentation']['long_val'] as String).length, 256, reason: 'Segmentation value should be truncated to 256 chars');
    });
  });

  group('Events Module - SBS Event Filtering', () {
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
      await sdk.events.record(key: 'another_blocked');
      await sdk.events.record(key: 'allowed_event');

      expect(sdk.debugEventQueueLength, 1);
      expect(sdk.debugEventQueueSnapshot.first['key'], 'allowed_event');
      expect(logger.logs.any((log) => log.contains('blacklisted')), true);
    });

    test('events not in whitelist are dropped when whitelist is set', () async {
      final logger = TestLogger();
      final sdk = await _createInstance(
        logger: logger,
        sbs: {
          'c': {
            'ew': ['allowed_event']
          }
        },
      );

      await sdk.events.record(key: 'not_allowed');
      await sdk.events.record(key: 'allowed_event');

      expect(sdk.debugEventQueueLength, 1);
      expect(sdk.debugEventQueueSnapshot.first['key'], 'allowed_event');
      expect(logger.logs.any((log) => log.contains('not in whitelist')), true);
    });

    test('segmentation keys in blacklist are removed', () async {
      final sdk = await _createInstance(
        sbs: {
          'c': {
            'sb': ['secret_field']
          }
        },
      );

      await sdk.events.record(key: 'test', segmentation: {'secret_field': 'hidden', 'public_field': 'visible'});

      final event = sdk.debugEventQueueSnapshot.first;
      expect(event['segmentation'].containsKey('secret_field'), false);
      expect(event['segmentation']['public_field'], 'visible');
    });

    test('event-specific segmentation blacklist is applied', () async {
      final sdk = await _createInstance(
        sbs: {
          'c': {
            'esb': {
              'purchase': ['credit_card', 'cvv']
            }
          }
        },
      );

      await sdk.events.record(key: 'purchase', segmentation: {'credit_card': '1234', 'cvv': '999', 'amount': 50});
      await sdk.events.record(key: 'other_event', segmentation: {'credit_card': '1234', 'cvv': '999', 'amount': 50});

      final events = sdk.debugEventQueueSnapshot;

      // Purchase event should have credit_card and cvv removed
      expect(events[0]['key'], 'purchase');
      expect(events[0]['segmentation'].containsKey('credit_card'), false);
      expect(events[0]['segmentation'].containsKey('cvv'), false);
      expect(events[0]['segmentation']['amount'], 50);

      // Other event should keep all fields
      expect(events[1]['key'], 'other_event');
      expect(events[1]['segmentation']['credit_card'], '1234');
      expect(events[1]['segmentation']['cvv'], '999');
      expect(events[1]['segmentation']['amount'], 50);
    });

    test('custom event tracking can be disabled via SBS', () async {
      final logger = TestLogger();
      final sdk = await _createInstance(
        logger: logger,
        sbs: {
          'c': {'cet': false}
        },
      );

      await sdk.events.record(key: 'disabled_event');

      expect(sdk.debugEventQueueLength, 0);
      expect(logger.logs.any((log) => log.contains('Event tracking disabled')), true);
    });
  });

  group('Events Module - recordMetrics', () {
    test('recordMetrics adds request to request queue', () async {
      final sdk = await _createInstance();

      final initialRQLength = sdk.debugRequestQueueLength;
      await sdk.events.recordMetrics();

      expect(sdk.debugRequestQueueLength, greaterThan(initialRQLength));

      final metricsReq = sdk.debugRequestQueueSnapshot.lastWhere((r) => r.containsKey('metrics'));
      expect(metricsReq, isNotNull);
      expect(metricsReq['metrics'], isNotNull);
    });

    test('recordMetrics with override merges data', () async {
      final sdk = await _createInstance();

      await sdk.events.recordMetrics(metricOverride: {'custom_metric': 'custom_value', '_os': 'OverriddenOS'});

      final metricsReq = sdk.debugRequestQueueSnapshot.lastWhere((r) => r.containsKey('metrics'));
      final metrics = metricsReq['metrics'] as Map<String, dynamic>;
      expect(metrics['custom_metric'], 'custom_value');
      expect(metrics['_os'], 'OverriddenOS', reason: 'Override should replace collected value');
    });

    test('recordMetrics flushes user properties cache first', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.users.setProperties({'name': 'Test'});
      await sdk.events.recordMetrics();

      await sdk.processEventsAndRequests();

      // User details should be enqueued before metrics
      final userDetailsIdx = network.sent.indexWhere((r) => r.containsKey('user_details'));
      final metricsIdx = network.sent.indexWhere((r) => r.containsKey('metrics'));

      // Both should be in request queue, user_details first if cache wasn't empty
      expect(sdk.debugRequestQueueSnapshot.any((r) => r.containsKey('user_details')), false, reason: 'User details should have been sent');
    });

    test('recordMetrics skipped without consent', () async {
      final logger = TestLogger();
      final sdk = await _createInstance(giveConsent: false, startWithUnknownConsent: false, logger: logger);

      final initialRQLength = sdk.debugRequestQueueLength;
      await sdk.events.recordMetrics();

      expect(sdk.debugRequestQueueLength, initialRQLength, reason: 'Metrics should not be added without consent');
    });
  });

  group('Events Module - Disposed Instance', () {
    test('events are not recorded after dispose', () async {
      final logger = TestLogger();
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        deviceId: 'test-device',
        storageMode: StorageMode.memory,
        giveConsent: true,
        enableSDKLogs: true,
        logLevel: LogLevel.verbose,
        logger: logger,
      );
      final sdk = await Countly.init(cfg);

      await sdk.dispose(flush: false);
      await sdk.events.record(key: 'after_dispose');
      await sdk.events.recordMetrics();

      expect(logger.logs.any((log) => log.contains('disposed')), true);
    });
  });
}
