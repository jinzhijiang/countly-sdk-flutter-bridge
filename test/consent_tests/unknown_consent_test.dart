import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:countly_flutter_lite/countly_flutter_lite.dart';
import 'package:countly_sdk_dart_core/src/constants.dart';
import 'package:http/http.dart' as http;
import 'package:countly_sdk_dart_core/src/networking.dart';

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
  final List<String> endpoints = [];
  FakeNetworkClient(String baseUrl) : super(baseUrl);
  @override
  Future<http.Response> makeRequest(Map<String, dynamic> data, String endPoint) async {
    sent.add({...data});
    endpoints.add(endPoint);
    return FakeResponseSuccess();
  }
}

class RecordingStorage {
  final Map<String, String> writes = {};

  Future<String?> read(String key) async => writes[key];
  Future<void> write(String key, String value) async {
    writes[key] = value;
  }

  Future<void> remove(String key) async => writes.remove(key);
}

Future<CountlyInstance> _createInstanceWithUnknownConsent({
  required FakeNetworkClient networkClient,
}) async {
  final logger = TestLogger();
  final cfg = CountlyConfig(
    appKey: 'app-key',
    serverUrl: 'https://example.com',
    enableSDKLogs: true,
    logger: logger,
    giveConsent: false,
    startWithUnknownConsent: true,
    storageMode: StorageMode.memory,
  );
  final inst = await Countly.init(cfg);
  inst.debugOverrideNetworkClient = networkClient;
  addTearDown(() async {
    await Countly.disposeAll();
  });
  return inst;
}

Future<CountlyInstance> _createInstance({
  required FakeNetworkClient networkClient,
  bool giveConsent = false,
  bool startWithUnknownConsent = false,
  StorageMode storageMode = StorageMode.memory,
  CustomStorageMethods? storageMethods,
}) async {
  final logger = TestLogger();
  final cfg = CountlyConfig(
    appKey: 'app-key',
    serverUrl: 'https://example.com',
    enableSDKLogs: true,
    logLevel: LogLevel.verbose,
    giveConsent: giveConsent,
    startWithUnknownConsent: startWithUnknownConsent,
    storageMode: storageMode,
    storageMethods: storageMethods,
    networkClientOverride: networkClient,
  );
  final inst = await Countly.init(cfg);
  addTearDown(() async {
    await Countly.disposeAll();
  });
  return inst;
}

Future<CountlyInstance> _createNormalInstance({
  required FakeNetworkClient networkClient,
}) async {
  final logger = TestLogger();
  final cfg = CountlyConfig(
    appKey: 'app-key',
    serverUrl: 'https://example.com',
    enableSDKLogs: true,
    logger: logger,
    giveConsent: true,
    storageMode: StorageMode.memory,
  );
  final inst = await Countly.init(cfg);
  inst.debugOverrideNetworkClient = networkClient;
  addTearDown(() async {
    await Countly.disposeAll();
  });
  return inst;
}

void main() {
  group('Unknown Consent Mode Tests', () {
    test('1. SDK in unknown consent mode does not send requests to server', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstanceWithUnknownConsent(networkClient: network);

      // Record some events
      await sdk.events.record(key: 'test_event_1');
      await sdk.events.record(key: 'test_event_2');

      // Start a view
      sdk.views.startAutoStoppedView('TestView');

      // Process events and requests
      await sdk.processEventsAndRequests();

      // Verify no requests were sent to the server
      expect(network.sent.length, 0, reason: 'No requests should be sent in unknown consent mode');

      // But events should still be tracked in memory
      // Events get bundled into request queue, so event queue may be empty
      // Check that data exists in either queue
      final totalQueued = sdk.debugEventQueueLength + sdk.debugRequestQueueLength;
      expect(totalQueued, 4, reason: 'Events should be tracked in memory');
    });

    test('2. Events are tracked in memory during unknown consent mode', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstanceWithUnknownConsent(networkClient: network);

      // Record events
      await sdk.events.record(key: 'event_a');
      await sdk.events.record(key: 'event_b');
      await sdk.events.record(key: 'event_c');

      // Verify events are in the event queue
      expect(sdk.debugEventQueueLength, 3);
      final eventKeys = sdk.debugEventQueueSnapshot.map((e) => e['key']).toList();
      expect(eventKeys, contains('event_a'));
      expect(eventKeys, contains('event_b'));
      expect(eventKeys, contains('event_c'));

      // No requests should be sent
      expect(network.sent.length, 0);
    });

    test('3. Views are tracked in memory during unknown consent mode', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstanceWithUnknownConsent(networkClient: network);

      // Start and switch views
      await sdk.views.startAutoStoppedView('HomePage');
      await Future.delayed(Duration(milliseconds: 50)); // Small delay for view duration
      await sdk.views.startAutoStoppedView('DetailsPage');

      // Check that view events are tracked
      final viewEvents = sdk.debugEventQueueSnapshot.where((e) => e['key'] == '[CLY]_view').toList();
      expect(viewEvents.length, 1, reason: 'View events should be tracked in memory');

      // No requests sent to server
      expect(network.sent.length, 0);
    });

    test('4. Giving consent exits unknown consent mode and sends queued data', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstanceWithUnknownConsent(networkClient: network);

      // Record events while in unknown consent mode
      await sdk.events.record(key: 'pre_consent_event_1');
      await sdk.events.record(key: 'pre_consent_event_2');

      // Verify no requests sent yet
      expect(network.sent.length, 0);

      // Give consent - this should exit unknown consent mode
      await sdk.consents.giveConsent();

      // Allow async operations to complete
      await Future.delayed(Duration(milliseconds: 100));

      // Now requests should be sent
      expect(network.sent.length, greaterThan(0), reason: 'Requests should be sent after consent is given');

      // Verify the events were included in the sent requests
      final sentEventsRequest = network.sent.where((r) => r.containsKey('events')).toList();
      expect(sentEventsRequest.length, greaterThan(0), reason: 'Event requests should be sent');

      // Parse and verify event keys
      final allSentEventKeys = <String>[];
      for (final req in sentEventsRequest) {
        final eventsJson = req['events'] as String;
        final events = jsonDecode(eventsJson) as List<dynamic>;
        for (final e in events) {
          allSentEventKeys.add(e['key'] as String);
        }
      }
      expect(allSentEventKeys, contains('pre_consent_event_1'));
      expect(allSentEventKeys, contains('pre_consent_event_2'));
    });

    test('5. Request queue is populated but not sent during unknown consent mode', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstanceWithUnknownConsent(networkClient: network);
      sdk.debugOverrideBehaviorSettings(eventQueueSize: 2); // Force early bundling

      // Record enough events to trigger bundling
      await sdk.events.record(key: 'e1');
      await sdk.events.record(key: 'e2');
      await sdk.events.record(key: 'e3'); // This should trigger bundling

      // Request queue should have requests
      expect(sdk.debugRequestQueueLength, greaterThan(0), reason: 'Events should be bundled into request queue');

      // But nothing should be sent to server
      expect(network.sent.length, 0, reason: 'Requests should not be sent in unknown consent mode');

      // Now process - still nothing should be sent
      await sdk.processEventsAndRequests();
      expect(network.sent.length, 0, reason: 'processEventsAndRequests should not send in unknown consent mode');
    });

    test('6. Compare: normal mode sends requests immediately', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createNormalInstance(networkClient: network);

      // Record events
      await sdk.events.record(key: 'normal_event');

      // Process
      await sdk.processEventsAndRequests();

      // Requests should be sent in normal mode
      expect(network.sent.length, greaterThan(0), reason: 'Normal mode should send requests');
    });

    test('7. After consent, new events are sent normally', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstanceWithUnknownConsent(networkClient: network);

      // Give consent first
      await sdk.consents.giveConsent();

      // Clear any sent requests from consent transition
      network.sent.clear();

      // Record new events after consent
      await sdk.events.record(key: 'post_consent_event');
      await sdk.processEventsAndRequests();

      // New events should be sent
      expect(network.sent.length, greaterThan(0), reason: 'Events after consent should be sent');

      final sentEventsRequest = network.sent.where((r) => r.containsKey('events')).toList();
      expect(sentEventsRequest.length, greaterThan(0));

      final eventsJson = sentEventsRequest.first['events'] as String;
      final events = jsonDecode(eventsJson) as List<dynamic>;
      final keys = events.map((e) => e['key']).toList();
      expect(keys, contains('post_consent_event'));
    });

    test('8. Multiple event types tracked correctly in unknown consent mode', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstanceWithUnknownConsent(networkClient: network);

      // Record various types of events
      await sdk.events.record(key: 'custom_event', count: 5, sum: 10.5);
      await sdk.events.record(key: 'event_with_segmentation', segmentation: {'category': 'test', 'value': 42});
      sdk.views.startAutoStoppedView('TestPage');

      // All should be tracked in memory
      final events = sdk.debugEventQueueSnapshot;
      expect(events.length, greaterThanOrEqualTo(2)); // At least custom events

      // Verify event properties are preserved
      final customEvent = events.firstWhere((e) => e['key'] == 'custom_event');
      expect(customEvent['count'], 5);
      expect(customEvent['sum'], 10.5);

      final segEvent = events.firstWhere((e) => e['key'] == 'event_with_segmentation');
      expect(segEvent['segmentation']['category'], 'test');
      expect(segEvent['segmentation']['value'], 42);

      // Still no requests sent
      expect(network.sent.length, 0);
    });
  });

  group('Consent Behavior Tests', () {
    test('Default configuration requires consent for tracked data', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.events.record(key: 'should_drop');
      await sdk.users.setProperties({'name': 'NoConsent'});
      await sdk.processEventsAndRequests();

      expect(sdk.debugEventQueueLength, 0, reason: 'Events must be dropped when consent is missing');
      expect(network.sent.where((r) => r.containsKey('events')).length, 0,
          reason: 'No event requests should be sent without consent');
      expect(network.sent.where((r) => r.containsKey('user_details')).length, 0,
          reason: 'User properties should be ignored without consent');
    });

    test('Consent provided at init enables all tracking flows', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network, giveConsent: true);

      await sdk.events.record(key: 'with_consent');
      await sdk.users.setProperties({'name': 'Alice'});
      await sdk.processEventsAndRequests();

      final eventRequests = network.sent.where((r) => r.containsKey('events')).toList();
      expect(eventRequests.length, greaterThan(0), reason: 'Events should be enqueued and sent when consent is given');

      final userRequests = network.sent.where((r) => r.containsKey('user_details')).toList();
      expect(userRequests.length, greaterThan(0), reason: 'User properties should be processed when consent is given');
    });

    test('Consent-excluded requests are still sent without consent', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.processEventsAndRequests();
      await Future.delayed(const Duration(milliseconds: 150));

      expect(network.sent.any((r) => r.containsKey('consent')), true,
          reason: 'Consent status request should be sent regardless of consent');
      expect(network.sent.any((r) => r.containsKey('hc')), true,
          reason: 'Health check should be sent regardless of consent');
      expect(network.sent.any((r) => r['method'] == 'sc'), true,
          reason: 'Behavior settings fetch should be sent regardless of consent');
    });

    test('Unknown consent mode keeps data in memory only', () async {
      final network = FakeNetworkClient('https://example.com');
      final storage = RecordingStorage();
      final sdk = await _createInstance(
        networkClient: network,
        startWithUnknownConsent: true,
        storageMode: StorageMode.persistent,
        storageMethods: CustomStorageMethods(
          read: storage.read,
          write: storage.write,
          remove: storage.remove,
        ),
      );

      await sdk.events.record(key: 'mem_event');
      sdk.views.startAutoStoppedView('MemView');
      await sdk.processEventsAndRequests();

      expect(storage.writes.containsKey(StorageSubKeys.eventQueue), false,
          reason: 'Event queue should not be persisted in unknown consent mode');
      expect(storage.writes.containsKey(StorageSubKeys.requestQueue), false,
          reason: 'Request queue should not be persisted in unknown consent mode');
      expect(network.sent.isEmpty, true, reason: 'No requests should be sent while consent is unknown');
      expect(sdk.debugEventQueueLength + sdk.debugRequestQueueLength, greaterThan(0),
          reason: 'Data should be kept in memory during unknown consent mode');
    });

    test('Unknown consent mode still sends previously saved data', () async {
      final network = FakeNetworkClient('https://example.com');
      final storage = RecordingStorage();

      storage.writes['default_${StorageSubKeys.requestQueue}'] = jsonEncode([
        {
          'app_key': 'app-key',
          'device_id': 'stored-device',
          'sdk_version': '26.1.0',
          'sdk_name': 'countly-sdk-flutter-lite',
          'offline': true
        },
      ]);
      storage.writes['default_${StorageSubKeys.deviceId}'] = 'stored-device';
      storage.writes['default_${StorageSubKeys.deviceIdType}'] = DeviceIdType.generated.toString();

      await _createInstance(
        networkClient: network,
        startWithUnknownConsent: true,
        storageMode: StorageMode.persistent,
        storageMethods: CustomStorageMethods(
          read: storage.read,
          write: storage.write,
          remove: storage.remove,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 100));

      expect(network.sent.any((r) => r['offline'] == true), true,
          reason: 'Data stored from previous usage should be sent before entering unknown consent state');
    });

    test('Revoking consent in unknown mode clears collected data', () async {
      final network = FakeNetworkClient('https://example.com');
      final storage = RecordingStorage();
      final sdk = await _createInstance(
        networkClient: network,
        startWithUnknownConsent: true,
        storageMode: StorageMode.persistent,
        storageMethods: CustomStorageMethods(
          read: storage.read,
          write: storage.write,
          remove: storage.remove,
        ),
      );

      await sdk.events.record(key: 'to_be_cleared');
      sdk.views.startAutoStoppedView('ToBeCleared');
      await sdk.processEventsAndRequests();

      expect(sdk.debugEventQueueLength, 0, reason: 'Event queue should be empty after processing');
      // consent, events, location, metrics requests
      expect(sdk.debugRequestQueueLength, 4, reason: 'Data should exist before consent is revoked');
      expect(sdk.debugRequestQueueSnapshot[0]['consent'], isNotNull);
      expect(sdk.debugRequestQueueSnapshot[1]['location'], isNotNull);
      expect(sdk.debugRequestQueueSnapshot[2]['metrics'], isNotNull);
      expect(sdk.debugRequestQueueSnapshot[3]['events'], isNotNull);

      await sdk.consents.revokeConsent();

      expect(sdk.debugEventQueueLength, 0, reason: 'Event queue should be cleared after revoking consent');
      expect(sdk.debugRequestQueueLength, 1, reason: 'There should be consent request');
      expect(network.sent.length, 2, reason: 'HC and SBS requests should be sent after revoking consent');
      expect(network.sent.any((r) => r.containsKey('hc')), true);
      expect(network.sent.any((r) => r['method'] == 'sc'), true);

      await sdk.events.record(key: 'to_be_cleared');
      sdk.views.startAutoStoppedView('ToBeCleared');
      await sdk.processEventsAndRequests();
      expect(sdk.debugEventQueueLength, 0, reason: 'Event queue should be empty after processing');
      expect(sdk.debugRequestQueueLength, 1,
          reason: 'Consent request should be the only request after revoking consent');
      expect(sdk.debugRequestQueueSnapshot[0]['consent'], isNotNull);
    });
  });
}
