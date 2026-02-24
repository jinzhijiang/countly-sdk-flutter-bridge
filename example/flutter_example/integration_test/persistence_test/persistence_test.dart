import 'dart:io';

import 'package:countly_flutter_lite/countly_flutter_lite.dart';
import 'package:countly_sdk_dart_core/src/networking.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

class FailingNetworkClient extends NetworkClient {
  FailingNetworkClient(String baseUrl) : super(baseUrl);

  @override
  Future<http.Response> makeRequest(Map<String, dynamic> data, String endPoint) async {
    // Simulate network failure to force request queuing
    throw const SocketException('Simulated network failure');
  }

  @override
  Future<http.Response> makeSelectiveRequest(Map<String, dynamic> data) async {
    throw const SocketException('Simulated network failure');
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Test events are persisted across instances', (WidgetTester tester) async {
    const instanceKey = 'persistence_test_instance';

    final network1 = FailingNetworkClient('https://example.com');
    final cfg1 = CountlyConfig(
      appKey: 'app-key-persistence',
      serverUrl: 'https://example.com',
      deviceId: 'test-device-persistence',
      networkClientOverride: network1,
      giveConsent: true,
      enableSDKLogs: true,
    );

    final sdk1 = await Countly.init(cfg1, instanceKey: instanceKey);

    final eventKey = 'persistent_event_${DateTime.now().millisecondsSinceEpoch}';
    sdk1.events.record(key: eventKey, count: 1);

    await sdk1.processEventsAndRequests();

    expect(sdk1.debugRequestQueueLength, greaterThan(0));
    final snapshot1 = sdk1.debugRequestQueueSnapshot;
    expect(snapshot1.any((r) => r.toString().contains(eventKey)), true);

    // DISPOSE FIRST INSTANCE TO SIMULATE APP RESTART
    await Countly.disposeAll();

    final network2 = FailingNetworkClient('https://example.com');
    final cfg2 = CountlyConfig(
      appKey: 'app-key-persistence',
      serverUrl: 'https://example.com',
      deviceId: 'test-device-persistence',
      networkClientOverride: network2,
      giveConsent: true,
      enableSDKLogs: true,
    );

    final sdk2 = await Countly.init(cfg2, instanceKey: instanceKey);

    expect(sdk2.debugRequestQueueLength, greaterThan(0), reason: 'Queue should be loaded from storage');

    final snapshot2 = sdk2.debugRequestQueueSnapshot;
    final hasPersistedEvent = snapshot2.any((r) => r.toString().contains(eventKey));
    expect(hasPersistedEvent, true, reason: 'The specific event should be present in the restored queue');

    // DISPOSE SECOND INSTANCE AND START WITH DIFFERENT INSTANCE KEY
    await Countly.disposeAll();

    final network3 = FailingNetworkClient('https://example.com');
    final cfg3 = CountlyConfig(
      appKey: 'app-key-persistence',
      serverUrl: 'https://example.com',
      deviceId: 'test-device-persistence',
      networkClientOverride: network3,
      giveConsent: true,
      enableSDKLogs: true,
    );

    final sdk3 = await Countly.init(cfg3, instanceKey: 'new_instance_key');
    print(sdk3.debugRequestQueueSnapshot);
    expect(sdk3.debugRequestQueueLength, 3, reason: 'Queue should not be loaded when app key changes');
    // consent, location and metrics requests:
    expect(sdk3.debugRequestQueueSnapshot[0]['consent'], isNotEmpty);
    expect(sdk3.debugRequestQueueSnapshot[1]['location'], '');
    expect(sdk3.debugRequestQueueSnapshot[2]['metrics'], isNotEmpty);

    Countly.disposeAll();
  });
}
