import 'package:countly_flutter_lite/countly_flutter_lite.dart';
import 'package:countly_sdk_dart_core/src/networking.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import '../../../../test/helper/helper.dart' as helper;

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

  group('View Tracking', () {
    testWidgets('starting and ending a view records a [CLY]_view event', (WidgetTester tester) async {
      final network = FakeNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'test-device',
        giveConsent: true,
        enableSDKLogs: true,
        storageMode: StorageMode.memory,
        sbs: {
          'c': {'vt': true}
        },
      );
      final sdk = await Countly.init(cfg);

      await sdk.views.startAutoStoppedView('HomePage');
      expect(sdk.debugActiveViewName, 'HomePage');

      // Wait a bit so duration > 0
      await Future.delayed(const Duration(milliseconds: 100));

      await sdk.views.endActiveView();
      expect(sdk.debugActiveViewName, isNull);

      // View event should be in event queue
      final viewEvents = sdk.debugEventQueueSnapshot.where((e) => e['key'] == '[CLY]_view').toList();
      expect(viewEvents, isNotEmpty, reason: 'View event should be recorded');

      final viewEvt = viewEvents.first;
      expect(viewEvt['segmentation']['name'], 'HomePage');
      expect(viewEvt['segmentation']['visit'], 1);
      expect(viewEvt['dur'], isA<double>());
      expect(viewEvt['dur'], greaterThanOrEqualTo(0));
    });

    testWidgets('starting a new view auto-stops the previous one', (WidgetTester tester) async {
      final network = FakeNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'test-device',
        giveConsent: true,
        enableSDKLogs: true,
        storageMode: StorageMode.memory,
        sbs: {
          'c': {'vt': true}
        },
      );
      final sdk = await Countly.init(cfg);

      await sdk.views.startAutoStoppedView('FirstView');
      expect(sdk.debugActiveViewName, 'FirstView');

      await Future.delayed(const Duration(milliseconds: 50));

      // Starting second view should auto-stop first
      await sdk.views.startAutoStoppedView('SecondView');
      expect(sdk.debugActiveViewName, 'SecondView');

      // First view event should be in event queue
      final viewEvents = sdk.debugEventQueueSnapshot.where((e) => e['key'] == '[CLY]_view').toList();
      expect(viewEvents.length, 1, reason: 'Only ended view should produce event');
      expect(viewEvents.first['segmentation']['name'], 'FirstView');
    });

    testWidgets('view with empty name is rejected', (WidgetTester tester) async {
      final network = FakeNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'test-device',
        giveConsent: true,
        enableSDKLogs: true,
        storageMode: StorageMode.memory,
        sbs: {
          'c': {'vt': true}
        },
      );
      final sdk = await Countly.init(cfg);

      await sdk.views.startAutoStoppedView('');

      expect(sdk.debugActiveViewName, isNull, reason: 'Empty view name should be rejected');
      expect(sdk.debugEventQueueLength, 0);
    });

    testWidgets('view is not tracked when view tracking SBS is disabled', (WidgetTester tester) async {
      final network = FakeNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'test-device',
        giveConsent: true,
        enableSDKLogs: true,
        storageMode: StorageMode.memory,
        sbs: {
          'c': {'vt': false}
        },
      );
      final sdk = await Countly.init(cfg);

      await sdk.views.startAutoStoppedView('ShouldNotTrack');

      expect(sdk.debugActiveViewName, isNull, reason: 'View should not be tracked when SBS vt is false');
    });

    testWidgets('view event is sent to server on flush', (WidgetTester tester) async {
      final network = FakeNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'test-device',
        giveConsent: true,
        enableSDKLogs: true,
        storageMode: StorageMode.memory,
        sbs: {
          'c': {'vt': true}
        },
      );
      final sdk = await Countly.init(cfg);

      await sdk.views.startAutoStoppedView('Dashboard');
      await Future.delayed(const Duration(milliseconds: 50));
      await sdk.views.endActiveView();

      await sdk.processEventsAndRequests();

      final eventRequests = network.sent.where((r) => r.containsKey('events')).toList();
      expect(eventRequests, isNotEmpty);

      final allEvents = eventRequests.expand((r) => helper.deconstructEventsRequest(r)).toList();
      final viewEvent = allEvents.firstWhere((e) => e['key'] == '[CLY]_view', orElse: () => {});
      expect(viewEvent, isNotEmpty, reason: '[CLY]_view event should be sent to server');
      expect(viewEvent['segmentation']['name'], 'Dashboard');
    });

    testWidgets('active view is ended on dispose', (WidgetTester tester) async {
      final network = FakeNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'test-device',
        giveConsent: true,
        enableSDKLogs: true,
        storageMode: StorageMode.memory,
        sbs: {
          'c': {'vt': true}
        },
      );
      final sdk = await Countly.init(cfg);

      await sdk.views.startAutoStoppedView('ActiveOnDispose');
      expect(sdk.debugActiveViewName, 'ActiveOnDispose');

      await Countly.disposeAll();

      // View event should have been sent during dispose flush
      final eventRequests = network.sent.where((r) => r.containsKey('events')).toList();
      final allEvents = eventRequests.expand((r) => helper.deconstructEventsRequest(r)).toList();
      final viewEvent = allEvents.firstWhere((e) => e['key'] == '[CLY]_view', orElse: () => {});
      expect(viewEvent, isNotEmpty, reason: 'Active view should be ended and sent on dispose');
      expect(viewEvent['segmentation']['name'], 'ActiveOnDispose');
    });
  });
}
