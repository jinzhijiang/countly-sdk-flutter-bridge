import 'dart:io';

import 'package:countly_flutter_lite/countly_flutter_lite.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:countly_sdk_dart_core/src/networking.dart';
import '../../../../test/helper/helper.dart' as helper;
import 'package:http/http.dart' as http;

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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Test metric information reflects platform', (WidgetTester tester) async {
    final network = FakeNetworkClient('https://example.com');
    final cfg = CountlyConfig(
      appKey: 'app-key',
      serverUrl: 'https://example.com',
      networkClientOverride: network,
      deviceId: 'test-device',
      giveConsent: true,
      enableSDKLogs: true,
    );
    final sdk = await Countly.init(cfg);

    final metricsReq = sdk.debugRequestQueueSnapshot.singleWhere((r) => r.containsKey('metrics'));

    expect(metricsReq, helper.metricsRequest);
    final metrics = metricsReq['metrics'] as Map<String, dynamic>;
    expect(metrics['_os'], Platform.isAndroid ? 'Android' : 'iOS');
    expect(metrics['_device_type'], 'mobile');
  });
}
