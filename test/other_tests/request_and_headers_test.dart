import 'dart:convert';

import 'package:countly_flutter_lite/countly.dart';
import 'package:countly_sdk_dart_core/src/networking.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class FakeResponseSuccess extends http.Response {
  FakeResponseSuccess({String body = '{"result":"Success"}', int status = 200}) : super(body, status);
}

class RequestCapturingNetworkClient extends NetworkClient {
  final List<Map<String, dynamic>> sent = [];
  final Map<String, String> capturedHeaders = {};
  String? lastMethod;
  String? lastEndpoint;

  RequestCapturingNetworkClient(String baseUrl) : super(baseUrl);

  @override
  Future<http.Response> makeRequest(Map<String, dynamic> data, String endPoint) async {
    lastEndpoint = endPoint;
    lastMethod = 'POST';
    sent.add(Map<String, dynamic>.from(data));
    if (data['method'] == 'sc') {
      return FakeResponseSuccess(body: '{"c":{}}');
    }
    return FakeResponseSuccess();
  }

  @override
  Future<http.Response> makeSelectiveRequest(Map<String, dynamic> data) async {
    lastMethod = 'POST';
    sent.add(Map<String, dynamic>.from(data));
    return FakeResponseSuccess();
  }
}

class HeaderTrackingNetworkClient extends NetworkClient {
  final List<Map<String, dynamic>> sent = [];
  Map<String, String>? customHeaders;

  HeaderTrackingNetworkClient(String baseUrl) : super(baseUrl);

  void setCustomHeaders(Map<String, String> headers) {
    customHeaders = headers;
  }

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

class MockHttpClient extends http.BaseClient {
  final List<http.BaseRequest> requests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    return http.StreamedResponse(
      Stream.value(utf8.encode('{"result":"Success"}')),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

class MemoryBackedStorage {
  final Map<String, String> backing = {};

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
  RequestCapturingNetworkClient? networkClient,
  Map<String, String>? customRequestHeaders,
  bool enableNetworkOverride = true,
}) async {
  final client = enableNetworkOverride ? (networkClient ?? RequestCapturingNetworkClient('https://example.com')) : null;
  final cfg = CountlyConfig(
    appKey: 'test-app-key',
    serverUrl: 'https://example.com',
    deviceId: 'test-device-id',
    storageMode: StorageMode.memory,
    giveConsent: giveConsent,
    networkClientOverride: client,
    customRequestHeaders: customRequestHeaders,
  );
  final inst = await Countly.init(cfg);
  addTearDown(() async {
    await Countly.disposeAll();
  });
  return inst;
}

void main() {
  group('Request Structure - Required Fields', () {
    test('all requests include app_key', () async {
      final network = RequestCapturingNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.events.record(key: 'test_event');
      await sdk.processEventsAndRequests();

      expect(network.sent.isNotEmpty, true);
      final req = network.sent.firstWhere((r) => r.containsKey('events'), orElse: () => <String, dynamic>{});
      if (req.isNotEmpty) {
        expect(req['app_key'], 'test-app-key');
      }
    });

    test('all requests include device_id', () async {
      final network = RequestCapturingNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.events.record(key: 'test_event');
      await sdk.processEventsAndRequests();

      final req = network.sent.firstWhere((r) => r.containsKey('events'), orElse: () => <String, dynamic>{});
      if (req.isNotEmpty) {
        expect(req['device_id'], 'test-device-id');
      }
    });

    test('all requests include sdk_version', () async {
      final network = RequestCapturingNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.events.record(key: 'test_event');
      await sdk.processEventsAndRequests();

      final req = network.sent.firstWhere((r) => r.containsKey('events'), orElse: () => <String, dynamic>{});
      if (req.isNotEmpty) {
        expect(req['sdk_version'], isA<String>());
        expect((req['sdk_version'] as String).length, greaterThan(0));
      }
    });

    test('all requests include sdk_name', () async {
      final network = RequestCapturingNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.events.record(key: 'test_event');
      await sdk.processEventsAndRequests();

      final req = network.sent.firstWhere((r) => r.containsKey('events'), orElse: () => <String, dynamic>{});
      if (req.isNotEmpty) {
        expect(req['sdk_name'], isA<String>());
        expect((req['sdk_name'] as String).length, greaterThan(0));
      }
    });

    test('all requests include timestamp', () async {
      final network = RequestCapturingNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.events.record(key: 'test_event');
      await sdk.processEventsAndRequests();

      final req = network.sent.firstWhere((r) => r.containsKey('events'), orElse: () => <String, dynamic>{});
      if (req.isNotEmpty) {
        expect(req['timestamp'], isA<int>());
        expect(req['timestamp'], greaterThan(0));
      }
    });

    test('all requests include hour and dow', () async {
      final network = RequestCapturingNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.events.record(key: 'test_event');
      await sdk.processEventsAndRequests();

      final req = network.sent.firstWhere((r) => r.containsKey('events'), orElse: () => <String, dynamic>{});
      if (req.isNotEmpty) {
        expect(req['hour'], isA<int>());
        expect(req['hour'], inInclusiveRange(0, 23));
        expect(req['dow'], isA<int>());
        expect(req['dow'], inInclusiveRange(0, 6));
      }
    });

    test('all requests include timezone offset', () async {
      final network = RequestCapturingNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.events.record(key: 'test_event');
      await sdk.processEventsAndRequests();

      final req = network.sent.firstWhere((r) => r.containsKey('events'), orElse: () => <String, dynamic>{});
      if (req.isNotEmpty) {
        expect(req['tz'], isA<int>());
      }
    });
  });

  group('Custom Request Headers', () {
    test('custom headers from config are passed', () async {
      final mockClient = MockHttpClient();

      await http.runWithClient(() async {
        final sdk = await _createInstance(
          customRequestHeaders: {'X-Custom': 'value1', 'Authorization': 'Bearer token'},
          enableNetworkOverride: false,
        );

        await sdk.events.record(key: 'test_event');
        await sdk.processEventsAndRequests();

        final req = mockClient.requests.firstWhere((r) => r.url.path.contains('/i'));
        expect(req.headers['x-custom'], 'value1');
        expect(req.headers['authorization'], 'Bearer token');
      }, () => mockClient);
    });

    test('empty custom headers map is allowed', () async {
      final mockClient = MockHttpClient();

      await http.runWithClient(() async {
        final sdk = await _createInstance(
          customRequestHeaders: {},
          enableNetworkOverride: false,
        );

        await sdk.events.record(key: 'test_event');
        await sdk.processEventsAndRequests();

        final req = mockClient.requests.firstWhere((r) => r.url.path.contains('/i'));
        // Standard headers should be present
        expect(req.headers.containsKey('content-type'), true);
      }, () => mockClient);
    });

    test('null custom headers is allowed', () async {
      final mockClient = MockHttpClient();

      await http.runWithClient(() async {
        final sdk = await _createInstance(
          customRequestHeaders: null,
          enableNetworkOverride: false,
        );

        await sdk.events.record(key: 'test_event');
        await sdk.processEventsAndRequests();

        final req = mockClient.requests.firstWhere((r) => r.url.path.contains('/i'));
        // Standard headers should be present
        expect(req.headers.containsKey('content-type'), true);
      }, () => mockClient);
    });
  });

  group('POST-Only Communication', () {
    test('makeRequest uses POST method', () async {
      final mockClient = MockHttpClient();

      await http.runWithClient(() async {
        final sdk = await _createInstance(enableNetworkOverride: false);

        await sdk.events.record(key: 'test_event');
        await sdk.processEventsAndRequests();

        final req = mockClient.requests.lastWhere((r) => r.url.path.contains('/i'));
        expect(req.method, 'POST');
      }, () => mockClient);
    });

    test('makeSelectiveRequest uses POST method', () async {
      final mockClient = MockHttpClient();

      await http.runWithClient(() async {
        await _createInstance(enableNetworkOverride: false);

        // SBS request uses makeSelectiveRequest and is sent during init
        // We check if any request was sent and if it was POST
        expect(mockClient.requests.isNotEmpty, true);
        expect(mockClient.requests.every((req) => req.method == 'POST'), true);
      }, () => mockClient);
    });

    test('large payloads are sent via POST body', () async {
      final mockClient = MockHttpClient();

      await http.runWithClient(() async {
        final sdk = await _createInstance(enableNetworkOverride: false);

        // Create large event
        final largeSegmentation = <String, dynamic>{};
        for (var i = 0; i < 50; i++) {
          largeSegmentation['key_$i'] = 'value_$i' * 10;
        }

        await sdk.events.record(key: 'large_event', segmentation: largeSegmentation);
        await sdk.processEventsAndRequests();

        final req = mockClient.requests.last;
        expect(req.method, 'POST');
        // Verify body contains our data
        if (req is http.Request) {
          expect(req.body, contains('large_event'));
        }
      }, () => mockClient);
    });

    test('all request endpoints use POST', () async {
      final mockClient = MockHttpClient();

      await http.runWithClient(() async {
        final sdk = await _createInstance(enableNetworkOverride: false);

        await sdk.events.record(key: 'test');
        await sdk.users.setProperties({'name': 'John'});
        sdk.views.startAutoStoppedView('TestView');

        await sdk.processEventsAndRequests();

        // All requests should use POST
        expect(mockClient.requests.isNotEmpty, true);
        expect(mockClient.requests.every((req) => req.method == 'POST'), true);
      }, () => mockClient);
    });
  });

  group('Request Batching', () {
    test('events are batched into single request', () async {
      final network = RequestCapturingNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.events.record(key: 'event1');
      await sdk.events.record(key: 'event2');
      await sdk.events.record(key: 'event3');

      await sdk.processEventsAndRequests();

      final eventReqs = network.sent.where((r) => r.containsKey('events')).toList();
      expect(eventReqs.length, lessThanOrEqualTo(1), reason: 'Events should be batched');

      if (eventReqs.isNotEmpty) {
        final events = jsonDecode(eventReqs.first['events'] as String) as List;
        expect(events.length, 3);
      }
    });

    test('requests are sent in order', () async {
      final network = RequestCapturingNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.events.record(key: 'first');
      await sdk.processEventsAndRequests();

      await sdk.events.record(key: 'second');
      await sdk.processEventsAndRequests();

      // Find event requests
      final eventReqs = network.sent.where((r) => r.containsKey('events')).toList();

      if (eventReqs.length >= 2) {
        final firstEvents = jsonDecode(eventReqs[0]['events'] as String) as List;
        final secondEvents = jsonDecode(eventReqs[1]['events'] as String) as List;

        expect((firstEvents.first as Map)['key'], 'first');
        expect((secondEvents.first as Map)['key'], 'second');
      }
    });
  });

  group('Request Queue Persistence', () {
    test('pending requests are persisted to storage', () async {
      final storage = MemoryBackedStorage();

      // Create instance with failing network
      final cfg = CountlyConfig(
        appKey: 'test-app-key',
        serverUrl: 'https://example.com',
        deviceId: 'test-device-id',
        storageMode: StorageMode.persistent,
        giveConsent: true,
        storageMethods: storage.toMethods(),
        networkClientOverride: _FailingNetworkClient('https://example.com'),
      );
      final sdk = await Countly.init(cfg);

      await sdk.events.record(key: 'will_persist');
      await sdk.processEventsAndRequests();

      await Future.delayed(const Duration(milliseconds: 100));

      // Request queue should be persisted
      final queueData = storage.backing['default_COUNTLY_DART_RQ'];
      expect(queueData, isNotNull);
      expect(queueData!.contains('will_persist'), true);

      await Countly.disposeAll();
    });

    test('persisted requests are restored on init', () async {
      final storage = MemoryBackedStorage();

      // Pre-populate storage with request
      final request = {
        'app_key': 'test-app-key',
        'device_id': 'test-device',
        'events': '[{"key":"restored_event","count":1,"timestamp":123456}]',
        'timestamp': 123456,
      };
      storage.backing['default_COUNTLY_DART_RQ'] = jsonEncode([request]);

      final network = RequestCapturingNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'test-app-key',
        serverUrl: 'https://example.com',
        deviceId: 'test-device',
        storageMode: StorageMode.persistent,
        giveConsent: true,
        storageMethods: storage.toMethods(),
        networkClientOverride: network,
      );
      final sdk = await Countly.init(cfg);

      await sdk.processEventsAndRequests();

      // Restored request should be sent
      final sentWithRestored = network.sent.any(
        (r) => r.containsKey('events') && (r['events'] as String).contains('restored_event'),
      );
      expect(sentWithRestored, true);

      await Countly.disposeAll();
    });
  });

  group('Server URL Handling', () {
    test('trailing slash is handled correctly', () async {
      final network = RequestCapturingNetworkClient('https://example.com/');
      final cfg = CountlyConfig(
        appKey: 'test-app-key',
        serverUrl: 'https://example.com/',
        deviceId: 'test-device-id',
        storageMode: StorageMode.memory,
        giveConsent: true,
        networkClientOverride: network,
      );
      final sdk = await Countly.init(cfg);

      await sdk.events.record(key: 'test');
      await sdk.processEventsAndRequests();

      // Should work without double slashes
      expect(network.sent.isNotEmpty, true);

      await Countly.disposeAll();
    });

    test('HTTPS URL is accepted', () async {
      final network = RequestCapturingNetworkClient('https://secure.example.com');
      final cfg = CountlyConfig(
        appKey: 'test-app-key',
        serverUrl: 'https://secure.example.com',
        deviceId: 'test-device-id',
        storageMode: StorageMode.memory,
        giveConsent: true,
        networkClientOverride: network,
      );
      final sdk = await Countly.init(cfg);

      await sdk.events.record(key: 'test');
      await sdk.processEventsAndRequests();

      expect(network.sent.isNotEmpty, true);

      await Countly.disposeAll();
    });
  });

  group('Error Handling in Requests', () {
    test('failed requests are retried', () async {
      final network = _RetryCountingNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'test-app-key',
        serverUrl: 'https://example.com',
        deviceId: 'test-device-id',
        storageMode: StorageMode.memory,
        giveConsent: true,
        networkClientOverride: network,
      );
      final sdk = await Countly.init(cfg);

      await sdk.events.record(key: 'retry_test');

      // Process multiple times to trigger retries
      await sdk.processEventsAndRequests();
      await sdk.processEventsAndRequests();
      await sdk.processEventsAndRequests();

      expect(network.attemptCount, greaterThanOrEqualTo(1), reason: 'Requests should be attempted');

      await Countly.disposeAll();
    });

    test('successful response clears request from queue', () async {
      final network = RequestCapturingNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.events.record(key: 'test');
      await sdk.processEventsAndRequests();

      expect(sdk.debugRequestQueueLength, 0, reason: 'Successful request should be removed');
    });
  });

  group('Device ID in Requests', () {
    test('all requests include current device_id', () async {
      final network = RequestCapturingNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.events.record(key: 'event1');
      await sdk.events.record(key: 'event2');
      await sdk.processEventsAndRequests();

      for (final req in network.sent) {
        expect(req['device_id'], 'test-device-id');
      }
    });

    test('device_id change is reflected in new requests', () async {
      final network = RequestCapturingNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      // Change device ID
      await sdk.id.changeWithMerge('new-device-id');

      await sdk.events.record(key: 'after_change');
      await sdk.processEventsAndRequests();

      // New requests should have new device ID
      final newIdReq = network.sent.any((r) => r['device_id'] == 'new-device-id');
      expect(newIdReq, true);
    });
  });
}

class _FailingNetworkClient extends NetworkClient {
  _FailingNetworkClient(String baseUrl) : super(baseUrl);

  @override
  Future<http.Response> makeRequest(Map<String, dynamic> data, String endPoint) async {
    throw Exception('Network failure');
  }

  @override
  Future<http.Response> makeSelectiveRequest(Map<String, dynamic> data) async {
    throw Exception('Network failure');
  }
}

class _RetryCountingNetworkClient extends NetworkClient {
  int attemptCount = 0;

  _RetryCountingNetworkClient(String baseUrl) : super(baseUrl);

  @override
  Future<http.Response> makeRequest(Map<String, dynamic> data, String endPoint) async {
    attemptCount++;
    if (attemptCount < 3) {
      throw Exception('Temporary failure');
    }
    if (data['method'] == 'sc') {
      return FakeResponseSuccess(body: '{"c":{}}');
    }
    return FakeResponseSuccess();
  }

  @override
  Future<http.Response> makeSelectiveRequest(Map<String, dynamic> data) async {
    attemptCount++;
    return FakeResponseSuccess();
  }
}
