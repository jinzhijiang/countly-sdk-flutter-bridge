import 'dart:convert';

import 'package:countly_flutter_np/countly_config.dart';
import 'package:countly_flutter_np/countly_flutter.dart';
import 'package:countly_flutter_lite/countly.dart' as C;
import 'package:countly_sdk_dart_core/src/networking.dart' as N;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

class FakeResponseSuccess extends http.Response {
  FakeResponseSuccess({String body = '{"result":"Success"}', int status = 200}) : super(body, status);
}

class FakeNetworkClient extends N.NetworkClient {
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
    await C.Countly.disposeAll();
  });

  testWidgets('Migration with only old event data (no old requests)', (WidgetTester tester) async {
    final oldConfig = CountlyConfig('https://old.com', 'old-app-only-events')
        .setLoggingEnabled(true)
        .enableManualSessionHandling()
        .setDeviceId('old-only-events-device');
    await Countly.initWithConfig(oldConfig);

    Countly.recordEvent({'key': 'old_event_only', 'count': 1});

    final network = FakeNetworkClient('https://example.com');
    final cfg = C.CountlyConfig(
      appKey: 'new-app-only-events',
      serverUrl: 'https://example.com',
      networkClientOverride: network,
      deviceId: 'new-device-only-events',
      giveConsent: true,
      enableSDKLogs: true,
    );
    final sdk = await C.Countly.init(cfg);
    await sdk.processEventsAndRequests();
    Map<String, dynamic>? migratedOldEventReq;
    for (final req in network.sent) {
      final rawEvents = req['events'];
      if (rawEvents == null) continue;
      final events = _decodeEvents(rawEvents);
      if (events.any((e) => e['key'] == 'old_event_only')) {
        migratedOldEventReq = req;
        break;
      }
    }

    expect(migratedOldEventReq, isNotNull, reason: 'Expected migrated event to be sent');
    expect(migratedOldEventReq!['app_key'], equals('new-app-only-events'));
    expect(migratedOldEventReq['sdk_name'], 'countly_sdk_flutter_lite');
    expect(migratedOldEventReq['sdk_version'], '26.1.0');
  });
}

List<Map<String, dynamic>> _decodeEvents(dynamic raw) {
  if (raw is String) {
    final decoded = json.decode(raw) as List<dynamic>;
    return decoded.cast<Map<String, dynamic>>();
  }
  return (raw as List).cast<Map<String, dynamic>>();
}
