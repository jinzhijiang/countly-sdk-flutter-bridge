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

  testWidgets('Non-default core instance skips migration', (WidgetTester tester) async {
    final oldConfig = CountlyConfig('https://old.com', 'old-app-secondary')
        .setLoggingEnabled(true)
        .setDeviceId('old-device-secondary');
    await Countly.initWithConfig(oldConfig);
    Countly.instance.sessions.beginSession();
    Countly.recordEvent({'key': 'old_secondary_event', 'count': 1});

    final network = FakeNetworkClient('https://example.com');
    final cfg = C.CountlyConfig(
      appKey: 'new-app-secondary',
      serverUrl: 'https://example.com',
      networkClientOverride: network,
      deviceId: 'new-device-secondary',
      giveConsent: true,
      enableSDKLogs: true,
    );

    final sdk = await C.Countly.init(cfg, instanceKey: 'secondary');
    await sdk.processEventsAndRequests();

    expect(sdk.deviceId, 'new-device-secondary', reason: 'No migration expected for non-default instance');
    expect(network.sent.any((r) => r['sdk_name'] == 'dart-flutterbnp-android'), isFalse,
        reason: 'No legacy payload should be sent from non-default instance');
    expect(network.sent.any((r) => r['app_key'] == 'old-app-secondary'), isFalse,
        reason: 'Legacy app key should not appear in non-default instance run');
  });
}
