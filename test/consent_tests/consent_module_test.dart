import 'package:countly_flutter_lite/countly_flutter_lite.dart';
import 'package:countly_sdk_dart_core/src/networking.dart';
import '../helper/helper.dart' as helper;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

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

class MemoryBackedStorage {
  final Map<String, String> backing;
  MemoryBackedStorage(this.backing);

  CustomStorageMethods toMethods() {
    return CustomStorageMethods(
      read: (key) async => backing[key],
      write: (key, value) async => backing[key] = value,
      remove: (key) async => backing.remove(key),
      keys: () async => backing.keys.toList(),
    );
  }
}

Future<CountlyInstance> _createInstance({
  bool giveConsent = false,
  bool startWithUnknownConsent = false,
  FakeNetworkClient? networkClient,
  Map<String, String>? storageBacking,
  StorageMode storageMode = StorageMode.memory,
  Map<String, dynamic>? deviceMetricOverrides,
}) async {
  final client = networkClient ?? FakeNetworkClient('https://example.com');
  final cfg = CountlyConfig(
    appKey: 'app-key',
    serverUrl: 'https://example.com',
    deviceId: 'test-device',
    storageMode: storageMode,
    storageMethods: storageBacking != null ? MemoryBackedStorage(storageBacking).toMethods() : null,
    startWithUnknownConsent: startWithUnknownConsent,
    giveConsent: giveConsent,
    deviceMetricOverrides: deviceMetricOverrides != null ? Map<String, dynamic>.from(deviceMetricOverrides) : {},
    networkClientOverride: client,
  );
  final inst = await Countly.init(cfg);
  addTearDown(() async {
    await Countly.disposeAll();
  });
  return inst;
}

void main() {
  group('Consent - Default Behavior (Consent Required)', () {
    test('SDK requires consent by default', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.events.record(key: 'no_consent_event');
      sdk.views.startAutoStoppedView('NoConsentView');
      sdk.views.startAutoStoppedView('Next');
      await sdk.users.setProperties({'name': 'NoConsent'});
      await sdk.events.recordMetrics();

      expect(network.sent, equals([helper.sdkBehaviorRequest, helper.healthCheckRequest]));

      expect(sdk.debugEventQueueSnapshot, equals([]));

      expect(sdk.debugRequestQueueSnapshot, equals([helper.falseConsentRequest, helper.locationRequest]));
    });
  });

  group('Consent - Provided at Init', () {
    test('consent at init enables all tracking', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network, giveConsent: true);

      await sdk.events.record(key: 'consent_event');
      await sdk.views.startAutoStoppedView('ConsentView');
      await sdk.views.startAutoStoppedView('Next'); // wont be sent (single view requests)
      await sdk.users.setProperties({'name': 'Consent'});
      await sdk.events.recordMetrics();

      final events =
          helper.deconstructEventsRequest(sdk.debugRequestQueueSnapshot.firstWhere((r) => r.containsKey('events')));

      final up = helper.deconstructUserPropertiesRequest(
          sdk.debugRequestQueueSnapshot.firstWhere((r) => r.containsKey('user_details')));

      // init requests
      expect(network.sent, equals([helper.sdkBehaviorRequest, helper.healthCheckRequest]));

      // eq cleared
      expect(sdk.debugEventQueueSnapshot, equals([]));

      // all eq requests sent
      expect(sdk.debugRequestQueueSnapshot.length, equals(6));

      // order
      expect(sdk.debugRequestQueueSnapshot[0], equals(helper.trueConsentRequest));
      expect(sdk.debugRequestQueueSnapshot[1], equals(helper.locationRequest));
      expect(sdk.debugRequestQueueSnapshot[2], equals(helper.metricsRequest));
      expect(sdk.debugRequestQueueSnapshot[3],
          equals(sdk.debugRequestQueueSnapshot.firstWhere((r) => r.containsKey('events'))));
      expect(events.length, equals(2));
      expect(events[0]['key'], equals('consent_event'));
      expect(events[1]['key'], equals('[CLY]_view'));
      expect(events[1]['segmentation']['name'], equals('ConsentView'));

      expect(sdk.debugRequestQueueSnapshot[4],
          equals(sdk.debugRequestQueueSnapshot.firstWhere((r) => r.containsKey('user_details'))));
      expect(up.length, equals(1));
      expect(up[0]['name'], equals('Consent'));

      expect(sdk.debugRequestQueueSnapshot[5], equals(helper.metricsRequest));
    });
  });

  group('Consent - giveConsent after init', () {
    test('giveConsent enables tracking after init', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.consents.giveConsent();

      await sdk.events.record(key: 'consent_event');
      await sdk.views.startAutoStoppedView('ConsentView');
      await sdk.views.startAutoStoppedView('Next'); // wont be sent (single view requests)
      await sdk.users.setProperties({'name': 'Consent'});
      await sdk.events.recordMetrics();

      final events =
          helper.deconstructEventsRequest(sdk.debugRequestQueueSnapshot.firstWhere((r) => r.containsKey('events')));

      final up = helper.deconstructUserPropertiesRequest(
          sdk.debugRequestQueueSnapshot.firstWhere((r) => r.containsKey('user_details')));

      // init requests
      expect(network.sent, equals([helper.sdkBehaviorRequest, helper.healthCheckRequest]));

      // eq cleared
      expect(sdk.debugEventQueueSnapshot, equals([]));

      // all eq requests sent
      expect(sdk.debugRequestQueueSnapshot.length, equals(7));

      // order
      expect(sdk.debugRequestQueueSnapshot[0], equals(helper.falseConsentRequest));
      expect(sdk.debugRequestQueueSnapshot[1], equals(helper.locationRequest));
      expect(sdk.debugRequestQueueSnapshot[2], equals(helper.trueConsentRequest)); // after giveConsent
      expect(sdk.debugRequestQueueSnapshot[3], equals(helper.metricsRequest));
      expect(sdk.debugRequestQueueSnapshot[4],
          equals(sdk.debugRequestQueueSnapshot.firstWhere((r) => r.containsKey('events'))));
      expect(events.length, equals(2));
      expect(events[0]['key'], equals('consent_event'));
      expect(events[1]['key'], equals('[CLY]_view'));
      expect(events[1]['segmentation']['name'], equals('ConsentView'));

      expect(sdk.debugRequestQueueSnapshot[5],
          equals(sdk.debugRequestQueueSnapshot.firstWhere((r) => r.containsKey('user_details'))));
      expect(up.length, equals(1));
      expect(up[0]['name'], equals('Consent'));

      expect(sdk.debugRequestQueueSnapshot[6], equals(helper.metricsRequest));
    });

    test('giveConsent enables tracking after init and records metrics with override', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network, deviceMetricOverrides: {'_custom_metric': 42});

      await sdk.consents.giveConsent();

      // init requests
      expect(network.sent, equals([helper.sdkBehaviorRequest, helper.healthCheckRequest]));

      // eq cleared
      expect(sdk.debugEventQueueSnapshot, equals([]));

      // all eq requests sent
      expect(sdk.debugRequestQueueSnapshot.length, equals(4));

      final overriddenMetrics = Map<String, dynamic>.from(helper.metricsRequest);
      overriddenMetrics['metrics'] = Map<String, dynamic>.from(overriddenMetrics['metrics'] as Map<String, dynamic>);
      overriddenMetrics['metrics']['_custom_metric'] = 42;

      // order
      expect(sdk.debugRequestQueueSnapshot[0], equals(helper.falseConsentRequest));
      expect(sdk.debugRequestQueueSnapshot[1], equals(helper.locationRequest));
      expect(sdk.debugRequestQueueSnapshot[2], equals(helper.trueConsentRequest)); // after giveConsent
      expect(sdk.debugRequestQueueSnapshot[3], equals(overriddenMetrics));
    });
  });

  group('Consent - revokeConsent Method', () {
    test('revokeConsent disables tracking', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(giveConsent: true, networkClient: network);

      await sdk.consents.revokeConsent();
      await sdk.events.record(key: 'consent_event');
      sdk.views.startAutoStoppedView('ConsentView');
      sdk.views.startAutoStoppedView('Next'); // wont be sent (single view requests)
      await sdk.users.setProperties({'name': 'Consent'});
      await sdk.events.recordMetrics();

      // revokeConsent records false consent, then flushes the entire queue.
      // network.sent includes SBS + healthcheck (direct) + 4 queued requests
      // (trueConsent + location + metrics + falseConsent)
      expect(network.sent.length, 6);
      expect(network.sent[0], equals(helper.sdkBehaviorRequest));
      expect(network.sent[1], equals(helper.healthCheckRequest));
      // Remaining 4 are the queued requests with dynamic metadata added
      expect(network.sent[2]['consent'], helper.trueConsentRequest['consent']);
      expect(network.sent[3]['location'], helper.locationRequest['location']);
      expect(network.sent[4].containsKey('metrics'), true);
      expect(network.sent[5]['consent'], helper.falseConsentRequest['consent']);

      expect(sdk.debugEventQueueSnapshot, equals([]));

      // Queue is empty after flush
      expect(sdk.debugRequestQueueSnapshot, equals([]));
    });
  });

  group('Consent - Edge Cases', () {
    test('multiple giveConsent calls do not cause issues', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.consents.giveConsent();
      await sdk.consents.giveConsent();
      await sdk.consents.giveConsent();

      // init requests
      expect(network.sent, equals([helper.sdkBehaviorRequest, helper.healthCheckRequest]));

      // eq cleared
      expect(sdk.debugEventQueueSnapshot, equals([]));

      // all eq requests sent
      expect(sdk.debugRequestQueueSnapshot.length, equals(4));

      // order
      expect(sdk.debugRequestQueueSnapshot[0], equals(helper.falseConsentRequest));
      expect(sdk.debugRequestQueueSnapshot[1], equals(helper.locationRequest));
      expect(sdk.debugRequestQueueSnapshot[2], equals(helper.trueConsentRequest)); // after giveConsent
      expect(sdk.debugRequestQueueSnapshot[3], equals(helper.metricsRequest));
    });

    test('multiple revokeConsent calls do not cause issues', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(giveConsent: true, networkClient: network);

      await sdk.consents.revokeConsent();
      await sdk.consents.revokeConsent();
      await sdk.consents.revokeConsent();

      // First revokeConsent flushes all queued data, subsequent calls are no-ops
      // network.sent: SBS + healthcheck (direct) + 4 queued requests
      expect(network.sent.length, 6);
      expect(network.sent[0], equals(helper.sdkBehaviorRequest));
      expect(network.sent[1], equals(helper.healthCheckRequest));
      expect(network.sent[2]['consent'], helper.trueConsentRequest['consent']);
      expect(network.sent[3]['location'], helper.locationRequest['location']);
      expect(network.sent[4].containsKey('metrics'), true);
      expect(network.sent[5]['consent'], helper.falseConsentRequest['consent']);

      // eq cleared
      expect(sdk.debugEventQueueSnapshot, equals([]));

      // Queue is empty after flush
      expect(sdk.debugRequestQueueSnapshot.length, equals(0));
    });

    test('consent toggle does not lose data incorrectly', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(giveConsent: true, networkClient: network);

      await sdk.events.record(key: 'first_event');
      await sdk.consents.revokeConsent();
      // revokeConsent sends queued data first, so first_event is bundled and sent
      // Verify first_event was sent via network
      final sentWithEvents = network.sent.where((r) => r.containsKey('events')).toList();
      expect(sentWithEvents.length, 1);
      final events = helper.deconstructEventsRequest(sentWithEvents.first);
      expect(events.any((e) => e['key'] == 'first_event'), true);

      await sdk.consents.giveConsent();
      await sdk.events.record(key: 'second_event');

      // Only second_event remains in event queue
      expect(sdk.debugEventQueueLength, 1);
      expect(sdk.debugEventQueueSnapshot[0]['key'], 'second_event');
    });

    test('disposed instance ignores consent calls', () async {
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        deviceId: 'test-device',
        storageMode: StorageMode.memory,
        giveConsent: true,
        enableSDKLogs: true,
      );
      final sdk = await Countly.init(cfg);

      await sdk.dispose(flush: false);

      await sdk.consents.giveConsent();

      await sdk.consents.revokeConsent();
    });
  });
}
