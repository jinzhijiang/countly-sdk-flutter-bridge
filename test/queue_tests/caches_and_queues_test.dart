import 'dart:convert';

import 'package:countly_flutter_lite/countly.dart';
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
  final List<String> sentOrder = []; // Track order of request types
  FakeNetworkClient(String baseUrl) : super(baseUrl);
  @override
  Future<http.Response> makeRequest(Map<String, dynamic> data, String endPoint) async {
    sent.add(Map<String, dynamic>.from(data));
    _recordType(data);
    if (data['method'] == 'sc') {
      return FakeResponseSuccess(body: '{"c":{}}');
    }
    return FakeResponseSuccess();
  }

  @override
  Future<http.Response> makeSelectiveRequest(Map<String, dynamic> data) async {
    sent.add(Map<String, dynamic>.from(data));
    _recordType(data);
    return FakeResponseSuccess();
  }

  void _recordType(Map<String, dynamic> data) {
    if (data.containsKey('user_details')) {
      sentOrder.add('user_details');
    } else if (data.containsKey('events')) {
      sentOrder.add('events');
    } else if (data.containsKey('metrics')) {
      sentOrder.add('metrics');
    } else if (data.containsKey('consent')) {
      sentOrder.add('consent');
    } else if (data.containsKey('hc')) {
      sentOrder.add('hc');
    } else if (data['method'] == 'sc') {
      sentOrder.add('sbs');
    } else if (data.containsKey('location')) {
      sentOrder.add('location');
    } else {
      sentOrder.add('other');
    }
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
  final log = logger;
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
    logger: log,
    logLevel: LogLevel.verbose,
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
  group('User Properties Cache - Flush Behavior', () {
    test('recording event flushes user properties cache', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      // Clear initial requests
      network.sent.clear();
      network.sentOrder.clear();

      // Set user properties (cached)
      await sdk.users.setProperties({'name': 'CacheTest'});

      // Record event - should flush UP cache first
      await sdk.events.record(key: 'trigger_flush');

      await sdk.processEventsAndRequests();

      // Verify user_details was sent before events
      final userIdx = network.sentOrder.indexOf('user_details');
      final eventsIdx = network.sentOrder.indexOf('events');

      expect(userIdx, isNot(-1), reason: 'User details should be sent');
      expect(eventsIdx, isNot(-1), reason: 'Events should be sent');
      expect(userIdx, lessThan(eventsIdx), reason: 'UP cache should flush before events');
    });

    test('recording view flushes user properties cache', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      // Clear initial requests
      network.sent.clear();
      network.sentOrder.clear();

      await sdk.users.setProperties({'name': 'ViewCacheTest'});
      await sdk.views.startAutoStoppedView('View1'); // TODO: Should be discussed
      await sdk.views.startAutoStoppedView('View2'); // Ends View1

      await sdk.processEventsAndRequests();

      // User details should be sent
      expect(network.sent.any((r) => r.containsKey('user_details')), true);
      final userIdx = network.sentOrder.indexOf('user_details');
      final eventsIdx = network.sentOrder.indexOf('events');
      expect(userIdx, isNot(-1), reason: 'User details should be sent');
      expect(eventsIdx, isNot(-1), reason: 'Events should be sent');
      expect(userIdx, lessThan(eventsIdx), reason: 'UP cache should flush before view end event');
    });

    test('recording metrics flushes user properties cache', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.users.setProperties({'name': 'MetricsCacheTest'});
      await sdk.events.recordMetrics();

      await sdk.processEventsAndRequests();
      // User details should be sent
      expect(network.sent.any((r) => r.containsKey('user_details')), true);
      expect(network.sent.last.containsKey('metrics'), true, reason: 'Last request should be metrics');
    });

    test('giving consent flushes user properties cache before consent request', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(
        networkClient: network,
        startWithUnknownConsent: true,
      );

      await sdk.users.setProperties({'name': 'ConsentCacheTest'});
      await sdk.consents.giveConsent();
      expect(network.sent.last.containsKey('user_details'), true);
      expect(sdk.debugRequestQueueSnapshot.last.containsKey('consent'), true);
    });

    test('setting user properties bundles existing event queue', () async {
      final sdk = await _createInstance();

      await sdk.events.record(key: 'bundle_on_user_props');
      expect(sdk.debugEventQueueLength, 1);
      expect(sdk.debugRequestQueueSnapshot.any((r) => r.containsKey('events')), false);

      await sdk.users.setProperties({'name': 'BundleTest'});

      expect(sdk.debugEventQueueLength, 0, reason: 'Event queue should be bundled when setting user properties');
      expect(sdk.debugRequestQueueSnapshot.any((r) => r.containsKey('events')), true);
      expect(sdk.debugRequestQueueSnapshot.any((r) => r.containsKey('user_details')), false);
    });

    test('user properties cache limit triggers early flush', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(
        networkClient: network,
        sbs: {
          'c': {'upcl': 3}
        },
      );

      expect(sdk.debugRequestQueueSnapshot.any((r) => r.containsKey('user_details')), false);

      // Set properties up to the limit
      await sdk.users.setProperties({'p1': 'v1'});
      await sdk.users.setProperties({'p2': 'v2'});
      await sdk.users.setProperties({'p3': 'v3'}); // Should trigger flush

      expect(sdk.debugRequestQueueSnapshot.any((r) => r.containsKey('user_details')), true);
    });
  });

  group('Event Queue - Bundling Behavior', () {
    test('event queue bundles when limit is reached', () async {
      final sdk = await _createInstance();
      sdk.debugOverrideBehaviorSettings(eventQueueSize: 3);

      expect(sdk.debugRequestQueueSnapshot.any((r) => r.containsKey('events')), false);
      await sdk.events.record(key: 'e1');
      await sdk.events.record(key: 'e2');
      await sdk.events.record(key: 'e3');
      expect(sdk.debugEventQueueLength, 3);

      // This triggers bundling of first 3 events
      await sdk.events.record(key: 'e4');

      // After bundling, only e4 should be in event queue
      expect(sdk.debugEventQueueLength, 1);
      expect(sdk.debugEventQueueSnapshot.first['key'], 'e4');

      // Request queue should have the bundled events
      expect(sdk.debugRequestQueueSnapshot.any((r) => r.containsKey('events')), true);
    });

    test('bundled events are JSON encoded in request', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.events.record(key: 'event1', count: 1);
      await sdk.events.record(key: 'event2', count: 2);

      await sdk.processEventsAndRequests();

      final eventsReq = network.sent.firstWhere((r) => r.containsKey('events'));
      final eventsJson = eventsReq['events'] as String;

      // Should be valid JSON
      final events = jsonDecode(eventsJson) as List<dynamic>;
      expect(events.length, 2);
      expect(events[0]['key'], 'event1');
      expect(events[1]['key'], 'event2');
    });

    test('multiple bundle cycles work correctly', () async {
      final sdk = await _createInstance();
      sdk.debugOverrideBehaviorSettings(eventQueueSize: 2);

      // First batch
      await sdk.events.record(key: 'batch1_e1');
      await sdk.events.record(key: 'batch1_e2');

      // Second batch (triggers first bundle, then starts second)
      await sdk.events.record(key: 'batch2_e1');
      await sdk.events.record(key: 'batch2_e2');

      // Third batch
      await sdk.events.record(key: 'batch3_e1');

      expect(sdk.debugRequestQueueSnapshot.where((r) => r.containsKey('events')).length, 2);
    });
  });

  group('Request Queue - Overflow Handling', () {
    test('oldest request is removed when queue is full', () async {
      final logger = TestLogger();
      final sdk = await _createInstance(
        logger: logger,
        sbs: {
          'c': {'rqs': 5}
        },
      );

      // Add more requests than the limit
      for (int i = 0; i < 10; i++) {
        await sdk.events.recordMetrics(metricOverride: {'batch': i});
      }

      // Queue should be at the limit
      expect(sdk.debugRequestQueueLength, lessThanOrEqualTo(5));
      expect(logger.logs.any((log) => log.contains('queue full') && log.contains('removing oldest')), true);
      expect(sdk.debugRequestQueueSnapshot.last.containsKey('metrics'), true);
      expect(sdk.debugRequestQueueSnapshot.last['metrics']['batch'], 9);
      expect(sdk.debugRequestQueueSnapshot.first['metrics']['batch'], 5);
    });
  });

  group('Flush Order - Correct Sequence', () {
    test('flush order is: UP cache -> event queue -> request queue', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      // Clear initial requests
      network.sent.clear();
      network.sentOrder.clear();

      // Set up data in all queues
      await sdk.users.setProperties({'name': 'OrderTest'});
      await sdk.events.record(key: 'order_event');

      await sdk.processEventsAndRequests();

      // Verify order: user_details before events
      final userIdx = network.sentOrder.indexOf('user_details');
      final eventsIdx = network.sentOrder.indexOf('events');

      expect(userIdx, isNot(-1));
      expect(eventsIdx, isNot(-1));
      expect(userIdx, lessThan(eventsIdx), reason: 'UP should be processed before events');
    });

    test('heartbeat triggers correct flush sequence', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);
      sdk.debugOverrideBehaviorSettings(eventQueueSize: 100, timerIntervalSeconds: 1);

      // Set up data
      await sdk.users.setProperties({'name': 'HeartbeatTest'});
      await sdk.events.record(key: 'heartbeat_event');

      // Wait for timer to fire
      await Future.delayed(const Duration(seconds: 2));

      // Both should be sent
      expect(network.sent.any((r) => r.containsKey('user_details')), true);
      expect(network.sent.any((r) => r.containsKey('events')), true);
    });
  });

  group('Queue Persistence', () {
    test('event queue is persisted to storage', () async {
      final backing = <String, String>{};
      final sdk = await _createInstance(
        storageBacking: backing,
        storageMode: StorageMode.persistent,
      );

      await sdk.events.record(key: 'persisted_event');

      // Check storage
      expect(backing.containsKey("default_" + StorageSubKeys.eventQueue), true);
      final storedEvents = jsonDecode(backing["default_" + StorageSubKeys.eventQueue]!) as List;
      expect(storedEvents.length, 1);
      expect(storedEvents[0]['key'], 'persisted_event');
    });

    test('request queue is persisted to storage', () async {
      final backing = <String, String>{};
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(
        storageBacking: backing,
        storageMode: StorageMode.persistent,
        networkClient: network,
        giveConsent: true,
      );

      await sdk.events.recordMetrics(metricOverride: {'persisted': true});

      // Check storage - request queue should be persisted
      expect(backing.containsKey("default_" + StorageSubKeys.requestQueue), true);
      final storedRequests = jsonDecode(backing["default_" + StorageSubKeys.requestQueue]!) as List;
      expect(storedRequests.any((r) => r['metrics']?['persisted'] == true), true);
    });

    test('queues are loaded from storage on init', () async {
      final backing = <String, String>{};
      final network = FakeNetworkClient('https://example.com');
      // Pre-populate storage with event queue
      backing['default_' + StorageSubKeys.eventQueue] = jsonEncode([
        {'key': 'stored_event', 'count': 1, 'timestamp': 1234567890, 'hour': 10, 'dow': 3}
      ]);
      backing['default_' + StorageSubKeys.deviceId] = 'stored-device';
      backing['default_' + StorageSubKeys.deviceIdType] = DeviceIdType.generated.toString();

      final sdk = await _createInstance(
        storageBacking: backing,
        storageMode: StorageMode.persistent,
        startWithUnknownConsent: true,
        networkClient: network,
      );

      expect(jsonDecode(network.sent.first['events'])[0]['key'], 'stored_event');
    });

    test('legacy URL-encoded request queue items are loaded and sent', () async {
      final backing = <String, String>{};
      final network = FakeNetworkClient('https://example.com');

      backing['default_' + StorageSubKeys.requestQueue] = jsonEncode(['app_key=old-app-key&device_id=legacy-device&begin_session=1&timestamp=1771689915235&user_details=%7B%22name%22%3A%22Legacy%20User%22%7D']);
      backing['default_' + StorageSubKeys.deviceId] = 'stored-device';
      backing['default_' + StorageSubKeys.deviceIdType] = DeviceIdType.generated.toString();

      await _createInstance(
        storageBacking: backing,
        storageMode: StorageMode.persistent,
        startWithUnknownConsent: true,
        networkClient: network,
      );

      final legacyReq = network.sent.firstWhere(
        (r) => r['begin_session'] == 1,
        orElse: () => <String, dynamic>{},
      );

      expect(legacyReq, isNotEmpty);
      expect(legacyReq['app_key'], 'old-app-key');
      expect(legacyReq['device_id'], 'legacy-device');
      expect(legacyReq['user_details'], {'name': 'Legacy User'});
    });

    test('queues are NOT persisted in unknown consent mode', () async {
      final backing = <String, String>{};
      final sdk = await _createInstance(
        storageBacking: backing,
        storageMode: StorageMode.persistent,
        giveConsent: false,
        startWithUnknownConsent: true,
      );

      await sdk.events.record(key: 'unknown_mode_event');

      // Event queue should NOT be persisted
      expect(backing.containsKey("default_" + StorageSubKeys.eventQueue), false, reason: 'Event queue should not be persisted in unknown consent mode');
    });
  });

  group('Queue Processing', () {
    test('processEventsAndRequests bundles events and sends requests', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.events.record(key: 'process_test');

      // Clear initial network calls
      network.sent.clear();

      await sdk.processEventsAndRequests();

      // Events should be bundled and sent
      expect(network.sent.any((r) => r.containsKey('events')), true);
    });

    test('empty queues result in no processing', () async {
      final logger = TestLogger();
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network, logger: logger);
      expect(network.sent.length, 2);

      // Process after init (clears queues)
      await sdk.processEventsAndRequests();
      expect(network.sent.length, 5);

      // Process again with empty queues
      await sdk.processEventsAndRequests();
      await sdk.processEventsAndRequests();

      // Should log that there's nothing to process
      expect(network.sent.length, 5);
    });

    test('requests are sent in FIFO order', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(
        networkClient: network,
        startWithUnknownConsent: true, // Queue without sending
      );

      // Add multiple metrics requests
      await sdk.events.recordMetrics(metricOverride: {'order': 1});
      await sdk.events.recordMetrics(metricOverride: {'order': 2});
      await sdk.events.recordMetrics(metricOverride: {'order': 3});

      // Give consent and process
      await sdk.consents.giveConsent();

      // Find the order of metrics requests sent
      final metricsRequests = network.sent.where((r) => r.containsKey('metrics')).toList();
      print(metricsRequests);
      expect(metricsRequests[2]['metrics']['order'], 1); // 0 is hc with metrics, 1 is init metrics
      expect(metricsRequests[3]['metrics']['order'], 2);
      expect(metricsRequests[4]['metrics']['order'], 3);
    });
  });

  group('Queue Limits via SBS', () {
    test('request queue size is configurable via SBS', () async {
      final sdk = await _createInstance(
        sbs: {
          'c': {'rqs': 10}
        },
        startWithUnknownConsent: true, // Prevent sending
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
          sbs: {
            'c': {'upcl': 2}
          },
          giveConsent: true);

      // Setting 2 properties should trigger flush
      await sdk.users.setProperties({'p1': 'v1'});
      await sdk.users.setProperties({'p2': 'v2'});

      final userDetailsRequests = sdk.debugRequestQueueSnapshot.where((r) => r.containsKey('user_details'));
      expect(userDetailsRequests.length, 1);
      expect(userDetailsRequests.first['user_details']['custom']['p1'], 'v1');
      expect(userDetailsRequests.first['user_details']['custom']['p2'], 'v2');
    });
  });

  group('Consent Change and Queues', () {
    test('giving consent triggers queue processing', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(
        networkClient: network,
        startWithUnknownConsent: true,
      );

      await sdk.events.record(key: 'pre_consent');

      // Nothing should be sent yet
      expect(network.sent.where((r) => r.containsKey('events')).length, 0);

      await sdk.consents.giveConsent();

      // Now events should be sent
      expect(network.sent.any((r) => r.containsKey('events')), true);
    });

    test('revoking consent clears all queues', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(
        startWithUnknownConsent: true,
        networkClient: network,
      );

      await sdk.events.record(key: 'to_be_cleared');
      expect(sdk.debugEventQueueLength, 1);

      await sdk.consents.revokeConsent();

      expect(sdk.debugEventQueueLength, 0, reason: 'Event queue should be cleared after revoking consent');
      expect(network.sent.where((r) => r.containsKey('events')).length, 0, reason: 'Event queue should be cleared');
      expect(sdk.debugRequestQueueSnapshot.where((r) => r.containsKey('consent')).length, 1, reason: 'Revoke Consent');
      expect(sdk.debugRequestQueueSnapshot.length, 1, reason: 'Only consent request should be in queue after revoking consent');
    });

    test('consent request is recorded to request queue', () async {
      final sdk = await _createInstance(
        giveConsent: false,
        startWithUnknownConsent: true,
      );

      await sdk.consents.giveConsent();

      final consentReqs = sdk.debugRequestQueueSnapshot.where((r) => r.containsKey('consent')).toList();
      expect(consentReqs.length, greaterThan(0));
    });
  });

  group('Networking Disabled', () {
    test('requests are queued but not sent when networking is disabled', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(
        networkClient: network,
        sbs: {
          'c': {'networking': false}
        },
      );

      network.sent.clear();

      await sdk.events.record(key: 'no_network');
      await sdk.processEventsAndRequests();

      // Request should be in queue but not sent
      expect(sdk.debugRequestQueueLength, greaterThan(0));
      expect(network.sent.length, 0, reason: 'No events should be sent when networking is disabled');
    });
  });

  group('Tracking Disabled', () {
    test('events are dropped when tracking is disabled', () async {
      final logger = TestLogger();
      final sdk = await _createInstance(
        logger: logger,
        sbs: {
          'c': {'tracking': false}
        },
      );

      await sdk.events.record(key: 'tracking_disabled');

      expect(sdk.debugEventQueueLength, 0);
      expect(logger.logs.any((log) => log.contains('Tracking disabled')), true);
    });

    test('requests are dropped when tracking is disabled', () async {
      final logger = TestLogger();
      final sdk = await _createInstance(
        logger: logger,
        sbs: {
          'c': {'tracking': false}
        },
      );

      final initialRQ = sdk.debugRequestQueueLength;
      await sdk.events.recordMetrics();

      expect(sdk.debugRequestQueueLength, initialRQ, reason: 'Metrics should not be added when tracking is disabled');
    });
  });
}
