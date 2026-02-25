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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await Countly.disposeAll();
  });

  group('CountlyConfig - Validation', () {
    testWidgets('empty appKey throws ArgumentError', (WidgetTester tester) async {
      expect(
        () => CountlyConfig(appKey: '', serverUrl: 'https://example.com'),
        throwsA(isA<ArgumentError>()),
      );
    });

    testWidgets('whitespace-only appKey throws ArgumentError', (WidgetTester tester) async {
      expect(
        () => CountlyConfig(appKey: '   ', serverUrl: 'https://example.com'),
        throwsA(isA<ArgumentError>()),
      );
    });

    testWidgets('empty serverUrl throws ArgumentError', (WidgetTester tester) async {
      expect(
        () => CountlyConfig(appKey: 'key', serverUrl: ''),
        throwsA(isA<ArgumentError>()),
      );
    });

    testWidgets('serverUrl without http scheme throws ArgumentError', (WidgetTester tester) async {
      expect(
        () => CountlyConfig(appKey: 'key', serverUrl: 'ftp://bad.com'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => CountlyConfig(appKey: 'key', serverUrl: 'just-a-domain.com'),
        throwsA(isA<ArgumentError>()),
      );
    });

    testWidgets('custom header with empty name throws ArgumentError', (WidgetTester tester) async {
      expect(
        () => CountlyConfig(
          appKey: 'key',
          serverUrl: 'https://example.com',
          customRequestHeaders: {'': 'val'},
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    testWidgets('custom header with empty value throws ArgumentError', (WidgetTester tester) async {
      expect(
        () => CountlyConfig(
          appKey: 'key',
          serverUrl: 'https://example.com',
          customRequestHeaders: {'X-Key': '  '},
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('CountlyConfig - Normalization', () {
    testWidgets('trailing slashes are stripped from serverUrl', (WidgetTester tester) async {
      final cfg = CountlyConfig(appKey: 'key', serverUrl: 'https://example.com///');
      expect(cfg.serverUrl, 'https://example.com');
    });

    testWidgets('appKey is trimmed', (WidgetTester tester) async {
      final cfg = CountlyConfig(appKey: '  my-key  ', serverUrl: 'https://example.com');
      expect(cfg.appKey, 'my-key');
    });
  });

  group('CountlyConfig - Init with userProperties', () {
    testWidgets('userProperties from config are sent on init', (WidgetTester tester) async {
      final network = FakeNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'test-device',
        giveConsent: true,
        enableSDKLogs: true,
        userProperties: {'name': 'InitUser', 'tier': 'free'},
      );
      final sdk = await Countly.init(cfg);

      await sdk.processEventsAndRequests();

      final userReqs = network.sent.where((r) => r.containsKey('user_details')).toList();
      expect(userReqs, isNotEmpty, reason: 'Config userProperties should produce a user_details request');

      final details = userReqs.first['user_details'] as Map<String, dynamic>;
      expect(details['name'], 'InitUser');
      expect(details['custom']?['tier'], 'free');
    });
  });

  group('CountlyConfig - Device Metric Overrides', () {
    testWidgets('deviceMetricOverrides are applied to metrics request', (WidgetTester tester) async {
      final network = FakeNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'test-device',
        giveConsent: true,
        enableSDKLogs: true,
        deviceMetricOverrides: {'_os': 'CustomOS', '_device': 'TestDevice'},
      );
      final sdk = await Countly.init(cfg);

      // Metrics request is enqueued during init
      final metricsReqs = sdk.debugRequestQueueSnapshot.where((r) => r.containsKey('metrics')).toList();
      expect(metricsReqs, isNotEmpty);

      final metrics = metricsReqs.first['metrics'] as Map<String, dynamic>;
      expect(metrics['_os'], 'CustomOS');
      expect(metrics['_device'], 'TestDevice');
    });
  });
}
