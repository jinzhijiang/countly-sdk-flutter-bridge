import 'package:countly_flutter_lite/countly_flutter_lite.dart' as C;
import 'package:countly_sdk_dart_core/src/networking.dart' as N;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:io' show Platform;
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

  testWidgets('Migration with no old event and no old request data', (WidgetTester tester) async {
    final network = FakeNetworkClient('https://example.com');
    final cfg = C.CountlyConfig(
      appKey: 'fresh-app-no-legacy',
      serverUrl: 'https://example.com',
      networkClientOverride: network,
      deviceId: 'fresh-device-no-legacy',
      giveConsent: true,
      enableSDKLogs: true,
    );

    final sdk = await C.Countly.init(cfg);
    await sdk.processEventsAndRequests();

    expect(network.sent, isNotEmpty);
    expect(
        network.sent
            .any((r) => r['sdk_name'] == (Platform.isAndroid ? 'dart-flutterbnp-android' : 'dart-flutterbnp-ios')),
        isFalse,
        reason: 'No legacy sdk payload should be present');
    expect(network.sent.every((r) => r['app_key'] == 'fresh-app-no-legacy'), isTrue,
        reason: 'All requests should belong to new SDK app key');
  });
}
