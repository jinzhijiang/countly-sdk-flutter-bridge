import 'dart:convert';

import 'package:countly_flutter_lite/countly.dart';
import 'package:countly_sdk_dart_core/src/networking.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helper/helper.dart' as helper;
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
  final List<String> endpoints = [];
  FakeNetworkClient(String baseUrl) : super(baseUrl);
  @override
  Future<http.Response> makeRequest(Map<String, dynamic> data, String endPoint) async {
    sent.add(Map<String, dynamic>.from(data));
    endpoints.add(endPoint);
    if (data['method'] == 'sc') {
      return FakeResponseSuccess(body: '{"c":{}}');
    }
    return FakeResponseSuccess();
  }

  @override
  Future<http.Response> makeSelectiveRequest(Map<String, dynamic> data) async {
    sent.add(Map<String, dynamic>.from(data));
    endpoints.add('/i');
    return FakeResponseSuccess();
  }
}

Future<CountlyInstance> _createInstance({
  bool giveConsent = true,
  bool startWithUnknownConsent = false,
  TestLogger? logger,
  FakeNetworkClient? networkClient,
  Map<String, dynamic>? deviceMetricOverrides,
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
    deviceMetricOverrides: deviceMetricOverrides,
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
  group('Metrics - Automatic Collection at Init', () {
    test('metrics request contains every necessary info', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      // There should be only one metrics request from init
      final metricsReq = sdk.debugRequestQueueSnapshot.singleWhere((r) => r.containsKey('metrics'));

      expect(metricsReq, helper.metricsRequest);
    });
  });
  group('Metrics - Developer Override at Init', () {
    test('device metric overrides are applied during initialization', () async {
      final sdk = await _createInstance(
        deviceMetricOverrides: {
          '_os': 'CustomOS',
          '_device': 'CustomDevice',
          '_device_type': 'Tablet',
          '_resolution': '2000x1200',
          '_density': 2.0,
          '_locale': 'en_US',
          '_app_version': '2.0.0',
          'custom_field': 'custom_value',
        },
      );

      final metricsReq = sdk.debugRequestQueueSnapshot.singleWhere((r) => r.containsKey('metrics'));

      final metrics = metricsReq['metrics'] as Map<String, dynamic>;
      expect(metrics['_os'], 'CustomOS');
      expect(metrics['_device'], 'CustomDevice');
      expect(metrics['_device_type'], 'Tablet');
      expect(metrics['_resolution'], '2000x1200');
      expect(metrics['_density'], 2.0);
      expect(metrics['_locale'], 'en_US');
      expect(metrics['_app_version'], '2.0.0');
      expect(metrics['custom_field'], 'custom_value');
    });

    test('partial overrides preserve other collected metrics', () async {
      final sdk = await _createInstance(
        deviceMetricOverrides: {
          '_custom_only': 'my_value',
        },
      );

      final metricsReq = sdk.debugRequestQueueSnapshot.singleWhere((r) => r.containsKey('metrics'));

      final metrics = metricsReq['metrics'] as Map<String, dynamic>;
      expect(metrics['_os'], isA<String>());
      expect(metrics['_device'], isA<String>());
      expect(metrics['_device_type'], isA<String>());
      expect(metrics['_resolution'], isA<String>());
      expect(metrics['_density'], isA<num>());
      expect(metrics['_locale'], isA<String>());
      expect(metrics['_app_version'], isA<String>());
      expect(metrics['_custom_only'], 'my_value');
    });
  });

  group('Metrics - Manual recordMetrics Method', () {
    test('recordMetrics adds a new metrics request to queue', () async {
      final sdk = await _createInstance();

      final initialCount = sdk.debugRequestQueueSnapshot.where((r) => r.containsKey('metrics')).length;

      await sdk.events.recordMetrics();

      final newCount = sdk.debugRequestQueueSnapshot.where((r) => r.containsKey('metrics')).length;
      expect(newCount, initialCount + 1);
    });

    test('recordMetrics with override merges custom data', () async {
      final sdk = await _createInstance();

      await sdk.events.recordMetrics(metricOverride: {
        '_os': 'CustomOS',
        '_device': 'CustomDevice',
        'battery_level': 85,
        'screen_brightness': 0.7,
        '_custom_metric': 'test_value',
      });

      final metricsReq = sdk.debugRequestQueueSnapshot.lastWhere((r) => r.containsKey('metrics'));
      final metrics = metricsReq['metrics'] as Map<String, dynamic>;

      expect(metrics['_os'], 'CustomOS');
      expect(metrics['_device'], 'CustomDevice');
      expect(metrics['_device_type'], isA<String>());
      expect(metrics['_resolution'], isA<String>());
      expect(metrics['_density'], isA<num>());
      expect(metrics['_locale'], isA<String>());
      expect(metrics['_app_version'], isA<String>());
      expect(metrics['battery_level'], 85);
      expect(metrics['screen_brightness'], 0.7);
      expect(metrics['_custom_metric'], 'test_value');
    });

    test('recordMetrics with override merges custom data + init overrides', () async {
      final sdk = await _createInstance(
        deviceMetricOverrides: {
          '_os': 'InitOS',
          '_device': 'InitDevice',
        },
      );

      // takes precedence over init overrides
      await sdk.events.recordMetrics(metricOverride: {
        '_os': 'CustomOS',
        '_device': 'CustomDevice',
        'battery_level': 85,
        'screen_brightness': 0.7,
        '_custom_metric': 'test_value',
      });

      final metricsReq = sdk.debugRequestQueueSnapshot.lastWhere((r) => r.containsKey('metrics'));
      final metrics = metricsReq['metrics'] as Map<String, dynamic>;

      expect(metrics['_os'], 'CustomOS');
      expect(metrics['_device'], 'CustomDevice');
      expect(metrics['_device_type'], isA<String>());
      expect(metrics['_resolution'], isA<String>());
      expect(metrics['_density'], isA<num>());
      expect(metrics['_locale'], isA<String>());
      expect(metrics['_app_version'], isA<String>());
      expect(metrics['battery_level'], 85);
      expect(metrics['screen_brightness'], 0.7);
      expect(metrics['_custom_metric'], 'test_value');
    });

    test('recordMetrics with override merges custom data + init overrides', () async {
      final sdk = await _createInstance(
        deviceMetricOverrides: {
          '_os': 'InitOS',
          '_device': 'InitDevice',
          'battery_level': 80,
        },
      );

      // takes precedence over init overrides
      await sdk.events.recordMetrics(metricOverride: {
        'battery_level': 85,
        'screen_brightness': 0.7,
        '_custom_metric': 'test_value',
      });

      final metricsReq = sdk.debugRequestQueueSnapshot.lastWhere((r) => r.containsKey('metrics'));
      final metrics = metricsReq['metrics'] as Map<String, dynamic>;

      expect(metrics['_os'], isNot('InitOS'));
      expect(metrics['_device'], isNot('InitDevice'));
      expect(metrics['_device_type'], isA<String>());
      expect(metrics['_resolution'], isA<String>());
      expect(metrics['_density'], isA<num>());
      expect(metrics['_locale'], isA<String>());
      expect(metrics['_app_version'], isA<String>());
      expect(metrics['battery_level'], 85);
      expect(metrics['screen_brightness'], 0.7);
      expect(metrics['_custom_metric'], 'test_value');
    });

    test('recordMetrics with override merges custom data + init overrides', () async {
      final sdk = await _createInstance(deviceMetricOverrides: {
        '_os': 'InitOS',
        '_device': 'InitDevice',
        'battery_level': 80,
      }, startWithUnknownConsent: true);

      // takes precedence over init overrides
      await sdk.events.recordMetrics(metricOverride: {
        'battery_level': 85,
        'screen_brightness': 0.7,
        '_custom_metric': 'test_value',
      });

      final metricsReq = sdk.debugRequestQueueSnapshot.lastWhere((r) => r.containsKey('metrics'));
      final metrics = metricsReq['metrics'] as Map<String, dynamic>;

      expect(metrics['_os'], isNot('InitOS'));
      expect(metrics['_device'], isNot('InitDevice'));
      expect(metrics['_device_type'], isA<String>());
      expect(metrics['_resolution'], isA<String>());
      expect(metrics['_density'], isA<num>());
      expect(metrics['_locale'], isA<String>());
      expect(metrics['_app_version'], isA<String>());
      expect(metrics['battery_level'], 85);
      expect(metrics['screen_brightness'], 0.7);
      expect(metrics['_custom_metric'], 'test_value');
    });

    test('recordMetrics flushes user properties cache before adding', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      // Set some user properties
      await sdk.users.setProperties({'name': 'MetricsTestUser'});

      // Clear sent requests to track new ones
      network.sent.clear();

      // Record metrics - should flush UP cache first
      await sdk.events.recordMetrics();

      await sdk.processEventsAndRequests();

      // Check that user_details request was enqueued/sent
      final hasUserDetails = network.sent.any((r) => r.containsKey('user_details'));
      expect(hasUserDetails, true, reason: 'User properties cache should be flushed before metrics');
    });

    test('recordMetrics goes directly to request queue (not event queue)', () async {
      final sdk = await _createInstance();

      final initialEventCount = sdk.debugEventQueueLength;
      final initialReqCount = sdk.debugRequestQueueLength;

      await sdk.events.recordMetrics();

      expect(sdk.debugEventQueueLength, initialEventCount, reason: 'Metrics should not go to event queue');
      expect(sdk.debugRequestQueueLength, greaterThan(initialReqCount), reason: 'Metrics should go to request queue');
    });
  });

  group('Metrics - Consent Handling', () {
    test('metrics are not recorded without consent', () async {
      final logger = TestLogger();
      final sdk = await _createInstance(giveConsent: false, startWithUnknownConsent: false, logger: logger);

      final initialCount = sdk.debugRequestQueueSnapshot.where((r) => r.containsKey('metrics')).length;

      await sdk.events.recordMetrics();

      final newCount = sdk.debugRequestQueueSnapshot.where((r) => r.containsKey('metrics')).length;
      expect(initialCount, 0);
      expect(newCount, initialCount, reason: 'Metrics should not be added without consent');
    });

    test('metrics are recorded with consent granted at init', () async {
      final sdk = await _createInstance(giveConsent: true);

      // Metrics should be in request queue from init
      final metricsReqs = sdk.debugRequestQueueSnapshot.where((r) => r.containsKey('metrics')).toList();
      expect(metricsReqs.length, greaterThan(0));
    });

    test('metrics are recorded in unknown consent mode (kept in memory)', () async {
      final sdk = await _createInstance(giveConsent: false, startWithUnknownConsent: true);

      // Metrics from init should be in request queue
      final metricsReqs = sdk.debugRequestQueueSnapshot.where((r) => r.containsKey('metrics')).toList();
      expect(metricsReqs.length, greaterThan(0), reason: 'Metrics should be queued in unknown consent mode');

      await sdk.events.recordMetrics();
      final newMetricsReqs = sdk.debugRequestQueueSnapshot.where((r) => r.containsKey('metrics')).toList();
      expect(newMetricsReqs.length, greaterThan(metricsReqs.length), reason: 'Metrics should be added in unknown consent mode');
    });
  });

  group('Metrics - Value Sanitization', () {
    test('metrics override values are sanitized (string truncation)', () async {
      final sdk = await _createInstance();

      final longValue = 'x' * 500; // Longer than default 256 limit
      await sdk.events.recordMetrics(metricOverride: {'long_metric': longValue});

      final metricsReq = sdk.debugRequestQueueSnapshot.lastWhere((r) => r.containsKey('metrics'));
      final metrics = metricsReq['metrics'] as Map<String, dynamic>;

      expect((metrics['long_metric'] as String).length, 256, reason: 'Long string values should be truncated');
    });

    test('metrics override keys are sanitized (key truncation)', () async {
      final sdk = await _createInstance();

      final longKey = 'k' * 200; // Longer than default 128 limit
      await sdk.events.recordMetrics(metricOverride: {longKey: 'value'});

      final metricsReq = sdk.debugRequestQueueSnapshot.lastWhere((r) => r.containsKey('metrics'));
      final metrics = metricsReq['metrics'] as Map<String, dynamic>;

      final foundKey = metrics.keys.firstWhere((k) => k.startsWith('kkk'), orElse: () => '');
      expect(foundKey.length, lessThanOrEqualTo(128), reason: 'Long keys should be truncated');
    });
  });

  group('Metrics - Disabled Instance', () {
    test('recordMetrics does nothing on disposed instance', () async {
      final logger = TestLogger();
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        deviceId: 'test-device',
        storageMode: StorageMode.memory,
        giveConsent: true,
        enableSDKLogs: true,
        logger: logger,
      );
      final sdk = await Countly.init(cfg);

      await sdk.dispose(flush: false);

      await sdk.events.recordMetrics();

      expect(logger.logs.any((log) => log.contains('disposed')), true);
    });
  });

  group('Metrics - Integration with Request Queue', () {
    test('multiple recordMetrics calls create multiple requests', () async {
      final sdk = await _createInstance();

      final initialCount = sdk.debugRequestQueueSnapshot.where((r) => r.containsKey('metrics')).length;

      await sdk.events.recordMetrics(metricOverride: {'call': 1});
      await sdk.events.recordMetrics(metricOverride: {'call': 2});
      await sdk.events.recordMetrics(metricOverride: {'call': 3});

      final newCount = sdk.debugRequestQueueSnapshot.where((r) => r.containsKey('metrics')).length;
      expect(newCount, initialCount + 3);

      // Verify each call has the correct data
      final metricsReqs = sdk.debugRequestQueueSnapshot.where((r) => r.containsKey('metrics')).toList();
      final callValues = metricsReqs.skip(initialCount).map((r) => (r['metrics'] as Map)['call']).toList();
      expect(callValues, [1, 2, 3], reason: 'Metrics should be recorded in order');
    });

    test('metrics requests are processed with other requests', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.events.recordMetrics(metricOverride: {'manual': true});
      await sdk.events.record(key: 'test_event');

      await sdk.processEventsAndRequests();

      // Both metrics and events should be sent
      expect(network.sent.any((r) => r.containsKey('metrics')), true);
      expect(network.sent.any((r) => r.containsKey('events')), true);
    });
  });
}
