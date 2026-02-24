import 'dart:convert';

import 'package:countly_flutter_lite/countly.dart';
import 'package:countly_sdk_dart_core/src/networking.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class TestLogger implements SdkLogger {
  final List<String> logs = [];
  final List<LogLevel> levels = [];

  @override
  bool isEnabled(LogLevel level) => true;

  @override
  void log(LogLevel level, String message, {Object? error, StackTrace? stack}) {
    logs.add('[${level.name}] $message');
    levels.add(level);
  }

  int countLevel(LogLevel level) => levels.where((l) => l == level).length;
}

class FilteredTestLogger implements SdkLogger {
  final List<String> logs = [];
  final LogLevel filterLevel;

  FilteredTestLogger(this.filterLevel);

  @override
  bool isEnabled(LogLevel level) => level.index <= filterLevel.index;

  @override
  void log(LogLevel level, String message, {Object? error, StackTrace? stack}) {
    if (isEnabled(level)) {
      logs.add('[${level.name}] $message');
    }
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

Future<CountlyInstance> _createInstance({
  bool giveConsent = true,
  bool enableSDKLogs = true,
  bool startWithUnknownConsent = false,
  LogLevel logLevel = LogLevel.verbose,
  SdkLogger? logger,
  FakeNetworkClient? networkClient,
}) async {
  final client = networkClient ?? FakeNetworkClient('https://example.com');
  final cfg = CountlyConfig(
    appKey: 'app-key',
    serverUrl: 'https://example.com',
    deviceId: 'test-device',
    storageMode: StorageMode.memory,
    giveConsent: giveConsent,
    enableSDKLogs: enableSDKLogs,
    startWithUnknownConsent: startWithUnknownConsent,
    logLevel: logLevel,
    logger: logger,
    networkClientOverride: client,
  );
  final inst = await Countly.init(cfg, instanceKey: 'debug');
  addTearDown(() async {
    await Countly.disposeAll();
  });
  return inst;
}

void main() {
  group('Debugging - Log Levels', () {
    test('verbose level logs all messages', () async {
      final logger = TestLogger();
      final sdk = await _createInstance(logger: logger, logLevel: LogLevel.verbose, giveConsent: false);

      await sdk.events.record(key: 'test_event'); // triggers warning due to no consent
      await sdk.consents.giveConsent();
      await sdk.events.record(key: ''); // empty key triggers error

      expect(logger.logs.length, greaterThan(0));
      // Should have verbose, debug, info, warning, and error level logs
      expect(logger.levels.contains(LogLevel.verbose), true);
      expect(logger.levels.contains(LogLevel.debug), true);
      expect(logger.levels.contains(LogLevel.info), true);
      expect(logger.levels.contains(LogLevel.warning), true);
      expect(logger.levels.contains(LogLevel.error), true);
    });

    test('debug level filters out verbose messages', () async {
      final logger = FilteredTestLogger(LogLevel.debug);
      await _createInstance(logger: logger, logLevel: LogLevel.debug);

      // No verbose logs should be captured
      expect(logger.logs.where((log) => log.startsWith('[verbose]')).length, 0);
    });

    test('info level filters out debug and verbose messages', () async {
      final logger = FilteredTestLogger(LogLevel.info);
      await _createInstance(logger: logger, logLevel: LogLevel.info);

      expect(logger.logs.where((log) => log.startsWith('[verbose]')).length, 0);
      expect(logger.logs.where((log) => log.startsWith('[debug]')).length, 0);
    });

    test('warning level shows only warnings and errors', () async {
      final logger = FilteredTestLogger(LogLevel.warning);
      final sdk = await _createInstance(
        logger: logger,
        logLevel: LogLevel.warning,
        giveConsent: false,
      );

      await sdk.events.record(key: 'no_consent'); // Should trigger warning

      expect(logger.logs.where((log) => log.startsWith('[verbose]')).length, 0);
      expect(logger.logs.where((log) => log.startsWith('[debug]')).length, 0);
      expect(logger.logs.where((log) => log.startsWith('[info]')).length, 0);
      expect(logger.logs.where((log) => log.startsWith('[error]')).length, 0);
      expect(logger.logs.any((log) => log.startsWith('[warning]')), true);
    });

    test('error level shows only errors', () async {
      final logger = FilteredTestLogger(LogLevel.error);
      final sdk = await _createInstance(logger: logger, logLevel: LogLevel.error);

      await sdk.events.record(key: ''); // Empty key triggers error

      expect(logger.logs.where((log) => log.startsWith('[verbose]')).length, 0);
      expect(logger.logs.where((log) => log.startsWith('[debug]')).length, 0);
      expect(logger.logs.where((log) => log.startsWith('[info]')).length, 0);
      expect(logger.logs.where((log) => log.startsWith('[warning]')).length, 0);
      expect(logger.logs.any((log) => log.startsWith('[error]')), true);
    });
  });

  group('Debugging - Enable/Disable Logs', () {
    test('logs are not emitted when enableSDKLogs is false', () async {
      final logger = TestLogger();
      await _createInstance(logger: logger, enableSDKLogs: false);

      // Logger should not receive any logs
      expect(logger.logs.length, 0);
    });

    test('logs are emitted when enableSDKLogs is true', () async {
      final logger = TestLogger();
      await _createInstance(logger: logger, enableSDKLogs: true);

      expect(logger.logs.length, greaterThan(0));
    });
  });

  group('Debugging - Custom Logger', () {
    test('custom logger receives all log calls', () async {
      final logger = TestLogger();
      final sdk = await _createInstance(logger: logger);

      await sdk.events.record(key: 'test_event');

      expect(logger.logs.length, greaterThan(0));
      expect(logger.logs.any((log) => log.contains('test_event')), true);
    });

    test('custom logger receives error with error object', () async {
      final logger = TestLogger();
      final sdk = await _createInstance(logger: logger);

      // Trigger an error condition
      await sdk.events.record(key: ''); // Empty key

      expect(logger.logs.any((log) => log.contains('error') && log.contains('empty key')), true);
    });

    test('custom logger can format messages differently', () async {
      final customLogs = <String>[];
      final customLogger = _CustomFormattingLogger(customLogs);
      await _createInstance(logger: customLogger);

      expect(customLogs.length, greaterThan(0));
      expect(customLogs.every((log) => log.startsWith('CUSTOM:')), true);
    });
  });

  group('Debugging - Duplicate Event Warning', () {
    test('warning is logged for consecutive duplicate event keys', () async {
      final logger = TestLogger();
      final sdk = await _createInstance(logger: logger);

      await sdk.events.record(key: 'same_event');
      await sdk.events.record(key: 'same_event');

      expect(logger.logs.any((log) => log.contains('warning') && log.contains('Duplicate') && log.contains('same_event')), true);
    });

    test('no warning for non-consecutive duplicate event keys', () async {
      final logger = TestLogger();
      final sdk = await _createInstance(logger: logger);

      await sdk.events.record(key: 'event_a');
      await sdk.events.record(key: 'event_b');
      await sdk.events.record(key: 'event_a'); // Not consecutive

      final duplicateWarnings = logger.logs.where((log) => log.contains('Duplicate')).length;
      expect(duplicateWarnings, 0);
    });

    test('duplicate warning shows the event key', () async {
      final logger = TestLogger();
      final sdk = await _createInstance(logger: logger);

      await sdk.events.record(key: 'purchase_button');
      await sdk.events.record(key: 'purchase_button');

      expect(logger.logs.any((log) => log.contains('purchase_button')), true);
    });
  });

  group('Debugging - Log Counts for Health Check', () {
    test('error logs are counted for health check', () async {
      final network = FakeNetworkClient('https://example.com');
      final logger = TestLogger();
      final sdk = await _createInstance(logger: logger, networkClient: network, startWithUnknownConsent: true);

      // Trigger errors
      await sdk.events.record(key: ''); // Empty key error
      await sdk.events.record(key: ''); // Another error
      await sdk.consents.giveConsent();

      // Check health check request
      final hcReq = network.sent.firstWhere((r) => r.containsKey('hc'));

      final hc = hcReq['hc'] as Map<String, dynamic>;
      expect(hc['el'], 2, reason: 'Error log count should be tracked');
    });

    test('warning logs are counted for health check', () async {
      final network = FakeNetworkClient('https://example.com');
      final logger = TestLogger();
      final sdk = await _createInstance(logger: logger, networkClient: network, startWithUnknownConsent: true);

      await sdk.events.record(key: 'dupe');
      await sdk.events.record(key: 'dupe');
      await sdk.consents.giveConsent();

      final hcReq = network.sent.firstWhere((r) => r.containsKey('hc'));

      final hc = hcReq['hc'] as Map<String, dynamic>;
      expect(hc['wl'], 1);
    });
  });

  group('Debugging - Log Message Format', () {
    test('logs include instance key prefix', () async {
      final logger = TestLogger();
      await _createInstance(logger: logger);

      // Instance key prefix (first 3 chars) should be in logs
      expect(logger.logs.any((log) => log.contains('[deb]')), true, // 'debug' first 3 chars
          reason: 'Logs should include instance key prefix');
    });

    test('error and warning logs have special formatting', () async {
      final logger = TestLogger();
      final sdk = await _createInstance(logger: logger);

      await sdk.events.record(key: ''); // Trigger error

      expect(logger.logs.any((log) => log.contains('!!!!!')), true, reason: 'Error/warning logs should have special marker');
    });
  });

  group('Debugging - Log Context Information', () {
    test('init logs include configuration details', () async {
      final logger = TestLogger();
      await _createInstance(logger: logger);

      expect(logger.logs.any((log) => log.contains('init')), true);
      expect(logger.logs.any((log) => log.contains('appKey') || log.contains('app-key')), true);
      expect(logger.logs.any((log) => log.contains('serverUrl') || log.contains('example.com')), true);
    });

    test('event recording logs include event details', () async {
      final logger = TestLogger();
      final sdk = await _createInstance(logger: logger);

      await sdk.events.record(key: 'purchase', count: 5, sum: 99.99);

      expect(logger.logs.any((log) => log.contains('purchase')), true);
      expect(logger.logs.any((log) => log.contains('5')), true);
      expect(logger.logs.any((log) => log.contains('99.99')), true);
    });

    test('view logs include view name', () async {
      final logger = TestLogger();
      final sdk = await _createInstance(logger: logger);

      await sdk.views.startAutoStoppedView('HomePage');

      expect(logger.logs.any((log) => log.contains('HomePage')), true);
    });
  });

  group('Debugging - Default Logger', () {
    test('default logger is used when no custom logger provided', () async {
      // This test verifies default logger works by checking no exceptions
      final sdk = await _createInstance(enableSDKLogs: true);

      // Should not throw
      await sdk.events.record(key: 'test');
      expect(sdk.debugEventQueueLength, 1);
    });
  });

  group('Debugging - Consent Warning Logs', () {
    test('missing consent triggers warning log', () async {
      final logger = TestLogger();
      final sdk = await _createInstance(logger: logger, giveConsent: false);

      await sdk.events.record(key: 'blocked');

      expect(logger.logs.any((log) => log.contains('warning') && log.contains('consent')), true);
    });
  });

  group('Debugging - Blacklist/Whitelist Logs', () {
    test('blacklisted event triggers warning log', () async {
      final logger = TestLogger();
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        deviceId: 'test-device',
        storageMode: StorageMode.memory,
        giveConsent: true,
        enableSDKLogs: true,
        logger: logger,
        sbs: {
          'c': {
            'eb': ['blocked_event']
          }
        },
      );
      final sdk = await Countly.init(cfg);
      addTearDown(() async {
        await Countly.disposeAll();
      });

      await sdk.events.record(key: 'blocked_event');

      expect(logger.logs.any((log) => log.contains('blacklisted')), true);
    });

    test('whitelist rejection triggers warning log', () async {
      final logger = TestLogger();
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        deviceId: 'test-device',
        storageMode: StorageMode.memory,
        giveConsent: true,
        enableSDKLogs: true,
        logger: logger,
        sbs: {
          'c': {
            'ew': ['allowed_event']
          }
        },
      );
      final sdk = await Countly.init(cfg);
      addTearDown(() async {
        await Countly.disposeAll();
      });

      await sdk.events.record(key: 'not_allowed');

      expect(logger.logs.any((log) => log.contains('not in whitelist')), true);
    });
  });

  group('Debugging - Truncation Warnings', () {
    test('long key truncation triggers warning', () async {
      final logger = TestLogger();
      final sdk = await _createInstance(logger: logger);

      final longKey = 'x' * 200;
      await sdk.events.record(key: longKey);

      expect(logger.logs.any((log) => log.contains('warning') && log.contains('truncating')), true);
    });

    test('long value truncation triggers warning', () async {
      final logger = TestLogger();
      final sdk = await _createInstance(logger: logger);

      final longValue = 'y' * 500;
      await sdk.events.record(key: 'test', segmentation: {'val': longValue});

      expect(logger.logs.any((log) => log.contains('warning') && log.contains('truncating')), true);
    });
  });
}

class _CustomFormattingLogger implements SdkLogger {
  final List<String> logs;
  _CustomFormattingLogger(this.logs);

  @override
  bool isEnabled(LogLevel level) => true;

  @override
  void log(LogLevel level, String message, {Object? error, StackTrace? stack}) {
    logs.add('CUSTOM: [$level] $message');
  }
}
