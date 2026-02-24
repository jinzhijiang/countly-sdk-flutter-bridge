import 'package:countly_flutter_lite/countly.dart';
import 'package:countly_sdk_dart_core/src/networking.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:http/http.dart' as http;

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

  bool hasError(String containing) => logs.any((l) => l.startsWith('[error]') && l.contains(containing));
  bool hasWarning(String containing) => logs.any((l) => l.startsWith('[warning]') && l.contains(containing));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Toast Display - enableVisualWarnings=true', () {
    testWidgets('Toast shown when recording event with empty key', (WidgetTester tester) async {
      // Build a minimal app with overlay support for toast display
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Test App')),
          ),
        ),
      );

      final network = FakeNetworkClient('https://example.com');
      final logger = TestLogger();
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'test-device',
        giveConsent: true,
        enableSDKLogs: true,
        enableVisualWarnings: true, // Enable visual warnings
        logLevel: LogLevel.verbose,
        logger: logger,
      );
      final sdk = await Countly.init(cfg);

      // Trigger an error by recording an event with empty key
      await sdk.events.record(key: '');

      // Wait for toast to appear
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify the error was logged
      expect(logger.hasError('events.record called with empty key'), isTrue);

      // Look for toast in widget tree - toast displays with '[Countly] ' prefix
      final countlyTextFinder = find.textContaining('[Countly]');
      expect(countlyTextFinder, findsWidgets, reason: 'Toast should be displayed for error');

      // Clean up
      await Countly.disposeAll();
    });

    testWidgets('Toast shown when starting view with empty name', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Test App')),
          ),
        ),
      );

      final network = FakeNetworkClient('https://example.com');
      final logger = TestLogger();
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'test-device',
        giveConsent: true,
        enableSDKLogs: true,
        enableVisualWarnings: true,
        logLevel: LogLevel.verbose,
        logger: logger,
        sbs: {'vt': true}, // Enable view tracking
      );
      final sdk = await Countly.init(cfg);

      // Trigger an error by starting a view with empty name
      await sdk.views.startAutoStoppedView('');

      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify the error was logged
      expect(logger.hasError('views.startAutoStoppedView called with empty viewName'), isTrue);

      // Look for toast in widget tree
      final countlyTextFinder = find.textContaining('[Countly]');
      expect(countlyTextFinder, findsWidgets, reason: 'Toast should be displayed for error');

      await Countly.disposeAll();
    });

    testWidgets('Toast shown for warning when event dropped due to missing consent', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Test App')),
          ),
        ),
      );

      final network = FakeNetworkClient('https://example.com');
      final logger = TestLogger();
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'test-device',
        giveConsent: false, // No consent - will trigger warning
        enableSDKLogs: true,
        enableVisualWarnings: true,
        logLevel: LogLevel.verbose,
        logger: logger,
      );
      final sdk = await Countly.init(cfg);

      // Try to record an event without consent - should log warning
      await sdk.events.record(key: 'test_event');

      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify the warning was logged
      expect(logger.hasWarning('dropped: missing consent'), isTrue);

      // Look for toast in widget tree (warnings also show toasts)
      final countlyTextFinder = find.textContaining('[Countly]');
      expect(countlyTextFinder, findsWidgets, reason: 'Toast should be displayed for warning');

      await Countly.disposeAll();
    });

    testWidgets('Toast displayed at top center with red background', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Test App')),
          ),
        ),
      );

      final network = FakeNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'test-device',
        giveConsent: true,
        enableSDKLogs: true,
        enableVisualWarnings: true,
        logLevel: LogLevel.verbose,
      );
      final sdk = await Countly.init(cfg);

      // Trigger an error
      await sdk.events.record(key: '');

      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));

      // Find the toast container and verify it has red background
      final containerFinder = find.byWidgetPredicate((widget) {
        if (widget is Container && widget.decoration is BoxDecoration) {
          final decoration = widget.decoration as BoxDecoration;
          return decoration.color == Colors.redAccent;
        }
        return false;
      });

      expect(containerFinder, findsWidgets, reason: 'Toast should have red/redAccent background');

      // Verify toast is aligned to top
      final alignFinder = find.byWidgetPredicate((widget) {
        if (widget is Align) {
          return widget.alignment == Alignment.topCenter;
        }
        return false;
      });

      expect(alignFinder, findsWidgets, reason: 'Toast should be aligned to top center');

      await Countly.disposeAll();
    });

    testWidgets('Toast disappears after 3 seconds', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Test App')),
          ),
        ),
      );

      final network = FakeNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'test-device',
        giveConsent: true,
        enableSDKLogs: true,
        enableVisualWarnings: true,
        logLevel: LogLevel.verbose,
      );
      final sdk = await Countly.init(cfg);

      // Trigger an error
      await sdk.events.record(key: '');

      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify toast is visible
      expect(find.textContaining('[Countly]'), findsWidgets);

      // Wait for toast to disappear (3 seconds + buffer)
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      // Toast should be gone
      expect(find.textContaining('[Countly]'), findsNothing, reason: 'Toast should disappear after 3 seconds');

      await Countly.disposeAll();
    });

    testWidgets('Multiple errors show multiple toasts', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Test App')),
          ),
        ),
      );

      final network = FakeNetworkClient('https://example.com');
      final logger = TestLogger();
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'test-device',
        giveConsent: true,
        enableSDKLogs: true,
        enableVisualWarnings: true,
        logLevel: LogLevel.verbose,
        logger: logger,
        sbs: {'vt': true}, // Enable view tracking
      );
      final sdk = await Countly.init(cfg);

      // Trigger multiple errors in quick succession
      await sdk.events.record(key: '');
      await sdk.views.startAutoStoppedView('');

      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify both errors were logged
      expect(logger.hasError('events.record called with empty key'), isTrue);
      expect(logger.hasError('views.startAutoStoppedView called with empty viewName'), isTrue);

      // Should have multiple toasts (or queued toasts)
      final countlyTextFinder = find.textContaining('[Countly]');
      expect(countlyTextFinder, findsWidgets);

      await Countly.disposeAll();
    });
  });

  group('Toast Display - enableVisualWarnings=false (default)', () {
    testWidgets('No toast shown when recording event with empty key', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Test App')),
          ),
        ),
      );

      final network = FakeNetworkClient('https://example.com');
      final logger = TestLogger();
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'test-device',
        giveConsent: true,
        enableSDKLogs: true,
        enableVisualWarnings: false, // Explicitly disabled
        logLevel: LogLevel.verbose,
        logger: logger,
      );
      final sdk = await Countly.init(cfg);

      await sdk.events.record(key: '');

      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));

      // Error should still be logged
      expect(logger.hasError('events.record called with empty key'), isTrue);

      // But no toast should be shown
      final countlyTextFinder = find.textContaining('[Countly]');
      expect(countlyTextFinder, findsNothing, reason: 'Toast should NOT be displayed when enableVisualWarnings=false');

      await Countly.disposeAll();
    });

    testWidgets('No toast shown when starting view with empty name (default)', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Test App')),
          ),
        ),
      );

      final network = FakeNetworkClient('https://example.com');
      final logger = TestLogger();
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'test-device',
        giveConsent: true,
        enableSDKLogs: true,
        // enableVisualWarnings not set - defaults to false
        logLevel: LogLevel.verbose,
        logger: logger,
        sbs: {'vt': true},
      );
      final sdk = await Countly.init(cfg);

      await sdk.views.startAutoStoppedView('');

      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));

      // Error should be logged
      expect(logger.hasError('views.startAutoStoppedView called with empty viewName'), isTrue);

      // No toast
      final countlyTextFinder = find.textContaining('[Countly]');
      expect(countlyTextFinder, findsNothing,
          reason: 'Toast should NOT be displayed when enableVisualWarnings defaults to false');

      await Countly.disposeAll();
    });

    testWidgets('No toast for warning when enableVisualWarnings is false', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Test App')),
          ),
        ),
      );

      final network = FakeNetworkClient('https://example.com');
      final logger = TestLogger();
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'test-device',
        giveConsent: false, // No consent - will trigger warning
        enableSDKLogs: true,
        enableVisualWarnings: false,
        logLevel: LogLevel.verbose,
        logger: logger,
      );
      final sdk = await Countly.init(cfg);

      await sdk.events.record(key: 'test_event');

      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));

      // Warning should be logged
      expect(logger.hasWarning('dropped: missing consent'), isTrue);

      // No toast
      final countlyTextFinder = find.textContaining('[Countly]');
      expect(countlyTextFinder, findsNothing,
          reason: 'Toast should NOT be displayed for warning when enableVisualWarnings=false');

      await Countly.disposeAll();
    });

    testWidgets('Multiple errors logged but no toasts when default (false)', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Test App')),
          ),
        ),
      );

      final network = FakeNetworkClient('https://example.com');
      final logger = TestLogger();
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'test-device',
        giveConsent: true,
        enableSDKLogs: true,
        // enableVisualWarnings defaults to false
        logLevel: LogLevel.verbose,
        logger: logger,
        sbs: {'vt': true},
      );
      final sdk = await Countly.init(cfg);

      await sdk.events.record(key: '');
      await sdk.views.startAutoStoppedView('');

      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));

      // Both errors should be logged
      expect(logger.hasError('events.record called with empty key'), isTrue);
      expect(logger.hasError('views.startAutoStoppedView called with empty viewName'), isTrue);

      // But no toasts
      final countlyTextFinder = find.textContaining('[Countly]');
      expect(countlyTextFinder, findsNothing, reason: 'No toasts should appear when enableVisualWarnings=false');

      await Countly.disposeAll();
    });
  });
}
