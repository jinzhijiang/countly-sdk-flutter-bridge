import 'dart:convert';

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

  testWidgets('Migration does not re-populate legacy values on next core init', (WidgetTester tester) async {
    const markerEventKey = 'Old reinit marker event';
    final oldConfig = CountlyConfig('https://old.com', 'old-app-reinit').setLoggingEnabled(true).setDeviceId('old-device-reinit');
    await Countly.initWithConfig(oldConfig);

    Countly.instance.userProfile.setProperty('specialReinitProperty', 'value');
    Countly.instance.sessions.beginSession();
    Countly.recordEvent({'key': markerEventKey, 'count': 1});

    final firstNetwork = FakeNetworkClient('https://example.com');
    final firstCfg = C.CountlyConfig(
      appKey: 'new-app-first-init',
      serverUrl: 'https://example.com',
      networkClientOverride: firstNetwork,
      deviceId: 'new-device-first-init',
      giveConsent: true,
      enableSDKLogs: true,
    );
    final firstSdk = await C.Countly.init(firstCfg);
    await firstSdk.processEventsAndRequests();

    await C.Countly.disposeAll();

    final secondNetwork = FakeNetworkClient('https://example.com');
    final secondCfg = C.CountlyConfig(
      appKey: 'new-app-second-init',
      serverUrl: 'https://example.com',
      networkClientOverride: secondNetwork,
      deviceId: 'new-device-second-init',
      giveConsent: true,
      enableSDKLogs: true,
    );
    final secondSdk = await C.Countly.init(secondCfg);
    await secondSdk.processEventsAndRequests();

    bool secondRunContainsMarker = false;
    for (final req in secondNetwork.sent) {
      expect(req['device_id'], 'old-device-reinit');
      final rawEvents = req['events'];
      if (rawEvents == null) continue;
      final events = _decodeEvents(rawEvents);
      if (events.any((e) => e['key'] == markerEventKey)) {
        secondRunContainsMarker = true;
        break;
      }
    }

    expect(
      secondRunContainsMarker,
      isFalse,
      reason: 'Second init should not re-send migrated marker event',
    );
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
