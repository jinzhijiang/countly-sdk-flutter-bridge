import 'dart:convert';
import 'dart:io';

import 'package:countly_flutter_lite/countly_flutter_lite.dart';
import 'package:countly_sdk_dart_core/src/networking.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeResponseSuccess extends http.Response {
  FakeResponseSuccess({String body = '{"result":"Success"}', int status = 200}) : super(body, status);
}

class CapturingNetworkClient extends NetworkClient {
  final List<Map<String, dynamic>> sent = [];

  CapturingNetworkClient(String baseUrl) : super(baseUrl);

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

class FailingNetworkClient extends NetworkClient {
  FailingNetworkClient(String baseUrl) : super(baseUrl);

  @override
  Future<http.Response> makeRequest(Map<String, dynamic> data, String endPoint) async {
    throw const SocketException('Simulated network failure');
  }

  @override
  Future<http.Response> makeSelectiveRequest(Map<String, dynamic> data) async {
    throw const SocketException('Simulated network failure');
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('view recovery restores persisted active view', (WidgetTester tester) async {
    const instanceKey = 'it_view_recovery';
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('${instanceKey}_COUNTLY_ACTIVE_VIEW');
    await prefs.setString(
      '${instanceKey}_COUNTLY_ACTIVE_VIEW',
      jsonEncode({
        'n': 'RecoveredFromPrefs',
        'ts': DateTime.now().subtract(const Duration(seconds: 3)).millisecondsSinceEpoch,
        'd': 3500,
        's': {'source': 'integration_test', 'name': 'fake_name'},
      }),
    );

    final network = FailingNetworkClient('https://example.com');
    final cfg = CountlyConfig(appKey: 'it-app-key', serverUrl: 'https://example.com', deviceId: 'it-device', networkClientOverride: network, giveConsent: true, enableSDKLogs: true);

    final sdk = await Countly.init(cfg, instanceKey: instanceKey);

    final requests = sdk.debugRequestQueueSnapshot;
    final eventsRequest = requests.firstWhere((r) => r.containsKey('events'));
    final eventsJson = eventsRequest['events'] as String;
    final events = (jsonDecode(eventsJson) as List<dynamic>).cast<Map<String, dynamic>>();
    final recovered = events.firstWhere((e) => e['key'] == '[CLY]_view' && e['segmentation']['recovered'] == 1);

    expect(recovered['segmentation']['name'], 'RecoveredFromPrefs');
    expect(recovered['segmentation']['visit'], 1);
    expect(recovered['segmentation']['recovered'], 1);
    expect(recovered['segmentation']['source'], 'integration_test');

    expect(prefs.getString('${instanceKey}_COUNTLY_ACTIVE_VIEW'), isNull, reason: 'Recovered active view key should be cleared from persistent storage');

    await Countly.disposeAll();
  });

  testWidgets('background lifecycle triggers processing of queued requests', (WidgetTester tester) async {
    const instanceKey = 'it_lifecycle_bg';
    final network = CapturingNetworkClient('https://example.com');
    final cfg = CountlyConfig(appKey: 'it-app-key-bg', serverUrl: 'https://example.com', deviceId: 'it-device-bg', networkClientOverride: network, giveConsent: true, enableSDKLogs: true);

    final sdk = await Countly.init(cfg, instanceKey: instanceKey);

    network.sent.clear();
    await sdk.events.record(key: 'bg_flush_event');

    WidgetsBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(milliseconds: 300));

    final hasEventsRequest = network.sent.any((r) {
      if (!r.containsKey('events')) return false;
      final events = jsonDecode(r['events'] as String) as List<dynamic>;
      return events.any((e) => e is Map && e['key'] == 'bg_flush_event');
    });

    expect(hasEventsRequest, isTrue, reason: 'Going to background should trigger processEventsAndRequests and send queued events');

    await Countly.disposeAll();
  });
}
