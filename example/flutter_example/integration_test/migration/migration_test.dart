import 'dart:convert';
import 'dart:io' show Platform;

import 'package:countly_flutter_np/countly_config.dart';
import 'package:countly_flutter_np/countly_flutter.dart';
import 'package:countly_flutter_lite/countly_flutter_lite.dart' as C;
import 'package:countly_sdk_dart_core/src/networking.dart' as N;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

class FakeResponseSuccess extends http.Response {
  FakeResponseSuccess({String body = '{"result":"Success"}', int status = 200}) : super(body, status);
}

class FakeNetworkClient extends N.NetworkClient {
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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await C.Countly.disposeAll();
  });

  testWidgets('Test SDK migrates data from flutter SDK', (WidgetTester tester) async {
    final oldConfig = CountlyConfig('https://old.com', 'old-app-key').setLoggingEnabled(true).setDeviceId('old-device-id');
    await Countly.initWithConfig(oldConfig);

    Countly.instance.userProfile.setProperty('specialProperty', 'value');
    Countly.instance.sessions.beginSession();
    Countly.recordEvent({'key': 'Old event', 'count': 1});

    final network = FakeNetworkClient('https://example.com');
    final cfg = C.CountlyConfig(
      appKey: 'app-key',
      serverUrl: 'https://example.com',
      networkClientOverride: network,
      deviceId: 'test-device',
      giveConsent: true,
      enableSDKLogs: true,
    );
    final sdk = await C.Countly.init(cfg);

    await sdk.processEventsAndRequests();

    expect(network.sent.length, greaterThanOrEqualTo(3));
    bool sawLegacyBeginSession = false;
    bool sawLegacyUserDetails = false;

    bool sawNewSdkRequest = false;
    bool sawMigratedOldEventUnderLegacyAppKey = false;
    for (final req in network.sent) {
      if (req['app_key'] == 'old-app-key') {
        if (req['begin_session'] == 1 || req['begin_session'] == '1') {
          sawLegacyBeginSession = true;
          expect(req['device_id'], 'old-device-id');
          expect(req['sdk_name'], Platform.isAndroid ? 'dart-flutterbnp-android' : 'dart-flutterbnp-ios');
          expect(req['sdk_version'], '25.4.3');
          expect(req['av'], '0.0.1');
        }

        final userDetails = req['user_details'];
        if (userDetails is Map && userDetails['custom'] is Map) {
          final custom = userDetails['custom'] as Map;
          if (custom['specialProperty'] == 'value') {
            sawLegacyUserDetails = true;
          }
        }
      }

      if (req['app_key'] == 'app-key') {
        sawNewSdkRequest = true;
        expect(req['device_id'], 'old-device-id');
        expect(req['sdk_name'], 'countly_sdk_flutter_lite');
        expect(req['sdk_version'], '26.1.0');
        expect(req['av'], '1.0.0');
      }

      final rawEvents = req['events'];
      if (rawEvents == null) continue;
      final events = _decodeEvents(rawEvents);
      final containsOldEvent = events.any((e) => e['key'] == 'Old event' && e['count'] == 1);
      if (containsOldEvent && req['app_key'] == 'old-app-key') {
        sawMigratedOldEventUnderLegacyAppKey = true;
      }
    }

    expect(sawLegacyBeginSession, isTrue);
    expect(sawLegacyUserDetails, isTrue);
    expect(sawNewSdkRequest, isTrue);
    expect(sawMigratedOldEventUnderLegacyAppKey, isTrue);
  });
}

List<Map<String, dynamic>> _decodeEvents(dynamic raw) {
  if (raw == null) {
    return const <Map<String, dynamic>>[];
  }
  if (raw is String) {
    final decoded = json.decode(raw) as List<dynamic>;
    return decoded.cast<Map<String, dynamic>>();
  }
  if (raw is List) {
    return raw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }
  return const <Map<String, dynamic>>[];
}
