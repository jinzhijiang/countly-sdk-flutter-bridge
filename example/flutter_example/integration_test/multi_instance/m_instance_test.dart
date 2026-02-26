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

  group('Multi-Instance', () {
    testWidgets('two instances have separate event queues', (WidgetTester tester) async {
      final networkA = FakeNetworkClient('https://example.com');
      final cfgA = CountlyConfig(
        appKey: 'app-key-A',
        serverUrl: 'https://example.com',
        networkClientOverride: networkA,
        deviceId: 'device-A',
        giveConsent: true,
        enableSDKLogs: true,
      );
      final sdkA = await Countly.init(cfgA, instanceKey: 'instance_a');

      final networkB = FakeNetworkClient('https://example.com');
      final cfgB = CountlyConfig(
        appKey: 'app-key-B',
        serverUrl: 'https://example.com',
        networkClientOverride: networkB,
        deviceId: 'device-B',
        giveConsent: true,
        enableSDKLogs: true,
      );
      final sdkB = await Countly.init(cfgB, instanceKey: 'instance_b');

      await sdkA.events.record(key: 'event_from_A', count: 1);
      await sdkB.events.record(key: 'event_from_B', count: 1);

      // Each instance should have its own event
      expect(sdkA.debugEventQueueLength, 1);
      expect(sdkB.debugEventQueueLength, 1);
      expect(sdkA.debugEventQueueSnapshot.first['key'], 'event_from_A');
      expect(sdkB.debugEventQueueSnapshot.first['key'], 'event_from_B');
    });

    testWidgets('instances use their own network clients', (WidgetTester tester) async {
      final networkA = FakeNetworkClient('https://example.com');
      final cfgA = CountlyConfig(
        appKey: 'app-key-A',
        serverUrl: 'https://example.com',
        networkClientOverride: networkA,
        deviceId: 'device-A',
        giveConsent: true,
        enableSDKLogs: true,
      );
      final sdkA = await Countly.init(cfgA, instanceKey: 'net_a');

      final networkB = FakeNetworkClient('https://example.com');
      final cfgB = CountlyConfig(
        appKey: 'app-key-B',
        serverUrl: 'https://example.com',
        networkClientOverride: networkB,
        deviceId: 'device-B',
        giveConsent: true,
        enableSDKLogs: true,
      );
      final sdkB = await Countly.init(cfgB, instanceKey: 'net_b');

      await sdkA.events.record(key: 'a_only', count: 1);
      await sdkA.processEventsAndRequests();

      await sdkB.events.record(key: 'b_only', count: 1);
      await sdkB.processEventsAndRequests();

      // Verify events went to their respective network clients
      final aSentStr = networkA.sent.map((r) => r.toString()).join();
      final bSentStr = networkB.sent.map((r) => r.toString()).join();

      expect(aSentStr.contains('a_only'), isTrue, reason: 'Instance A event should go to network A');
      expect(bSentStr.contains('b_only'), isTrue, reason: 'Instance B event should go to network B');

      // Cross-check: A should not have B's events
      expect(aSentStr.contains('b_only'), isFalse, reason: 'Instance A should not have B events');
      expect(bSentStr.contains('a_only'), isFalse, reason: 'Instance B should not have A events');
    });

    testWidgets('instances use their own device IDs', (WidgetTester tester) async {
      final networkA = FakeNetworkClient('https://example.com');
      final cfgA = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: networkA,
        deviceId: 'device-alpha',
        giveConsent: true,
        enableSDKLogs: true,
      );
      final sdkA = await Countly.init(cfgA, instanceKey: 'id_a');

      final networkB = FakeNetworkClient('https://example.com');
      final cfgB = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: networkB,
        deviceId: 'device-beta',
        giveConsent: true,
        enableSDKLogs: true,
      );
      final sdkB = await Countly.init(cfgB, instanceKey: 'id_b');

      // All requests from A should use device-alpha
      for (final req in sdkA.debugRequestQueueSnapshot) {
        expect(req['device_id'], 'device-alpha');
      }

      // All requests from B should use device-beta
      for (final req in sdkB.debugRequestQueueSnapshot) {
        expect(req['device_id'], 'device-beta');
      }
    });

    testWidgets('disposing one instance does not affect the other', (WidgetTester tester) async {
      final networkA = FakeNetworkClient('https://example.com');
      final cfgA = CountlyConfig(
        appKey: 'app-key-A',
        serverUrl: 'https://example.com',
        networkClientOverride: networkA,
        deviceId: 'device-A',
        giveConsent: true,
        enableSDKLogs: true,
      );
      final sdkA = await Countly.init(cfgA, instanceKey: 'dispose_a');

      final networkB = FakeNetworkClient('https://example.com');
      final cfgB = CountlyConfig(
        appKey: 'app-key-B',
        serverUrl: 'https://example.com',
        networkClientOverride: networkB,
        deviceId: 'device-B',
        giveConsent: true,
        enableSDKLogs: true,
      );
      final sdkB = await Countly.init(cfgB, instanceKey: 'dispose_b');

      // Dispose only instance A
      await Countly.disposeInstance('dispose_a');

      // Instance B should still work
      await sdkB.events.record(key: 'still_alive', count: 1);
      expect(sdkB.debugEventQueueLength, 1, reason: 'Instance B should still function after A is disposed');
      expect(sdkB.debugEventQueueSnapshot.first['key'], 'still_alive');
    });

    testWidgets('disposeAll disposes all instances', (WidgetTester tester) async {
      final networkA = FakeNetworkClient('https://example.com');
      final cfgA = CountlyConfig(
        appKey: 'app-key-A',
        serverUrl: 'https://example.com',
        networkClientOverride: networkA,
        deviceId: 'device-A',
        giveConsent: true,
        enableSDKLogs: true,
      );
      await Countly.init(cfgA, instanceKey: 'all_a');

      final networkB = FakeNetworkClient('https://example.com');
      final cfgB = CountlyConfig(
        appKey: 'app-key-B',
        serverUrl: 'https://example.com',
        networkClientOverride: networkB,
        deviceId: 'device-B',
        giveConsent: true,
        enableSDKLogs: true,
      );
      await Countly.init(cfgB, instanceKey: 'all_b');

      // Both requests should have been sent during dispose
      await Countly.disposeAll();

      // Network clients should have received requests from flush on dispose
      expect(networkA.sent, isNotEmpty, reason: 'Instance A should flush on dispose');
      expect(networkB.sent, isNotEmpty, reason: 'Instance B should flush on dispose');
    });
  });
}
