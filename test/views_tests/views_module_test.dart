import 'dart:convert';

import 'package:countly_flutter_lite/countly.dart';
import 'package:countly_sdk_dart_core/src/constants.dart';
import 'package:countly_sdk_dart_core/src/networking.dart';
import '../helper/helper.dart' as helper;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class TestLogger implements SdkLogger {
  final List<String> logs = [];
  @override
  bool isEnabled(LogLevel level) => true;
  @override
  void log(LogLevel level, String message, {Object? error, StackTrace? stack}) {
    logs.add('[${level.name}] $message');
  }
}

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
    return CustomStorageMethods(read: (key) async => backing[key], write: (key, value) async => backing[key] = value, remove: (key) async => backing.remove(key), keys: () async => backing.keys.toList());
  }
}

Future<void> _setLifecycleState(AppLifecycleState state) async {
  final binding = WidgetsBinding.instance;
  binding.handleAppLifecycleStateChanged(state);
  await Future<void>.delayed(Duration.zero);
}

Future<CountlyInstance> _createInstance({bool giveConsent = true, bool startWithUnknownConsent = false, TestLogger? logger, FakeNetworkClient? networkClient, Map<String, String>? storageBacking, StorageMode storageMode = StorageMode.memory, Map<String, dynamic>? sbs}) async {
  final log = logger ?? TestLogger();
  final client = networkClient ?? FakeNetworkClient('https://example.com');
  final cfg = CountlyConfig(
    appKey: 'app-key',
    serverUrl: 'https://example.com',
    deviceId: 'test-device',
    storageMode: storageMode,
    storageMethods: storageBacking != null ? MemoryBackedStorage(storageBacking).toMethods() : null,
    startWithUnknownConsent: startWithUnknownConsent,
    giveConsent: giveConsent,
    enableSDKLogs: true,
    logLevel: LogLevel.verbose,
    logger: log,
    networkClientOverride: client,
    sbs: sbs ?? {},
  );
  final inst = await Countly.init(cfg, instanceKey: 'views');
  addTearDown(() async {
    await Countly.disposeAll();
  });
  return inst;
}

void main() {
  // For lifecycle observer registration.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Views Module - Basic startAutoStoppedView', () {
    test('starting a view records view name correctly', () async {
      final sdk = await _createInstance();

      await sdk.views.startAutoStoppedView('HomePage');

      // The view is active, so no view event is recorded yet
      // View event is recorded when view ends
      expect(sdk.debugEventQueueLength, 0, reason: 'Active view should not create event until ended');
      expect(sdk.debugActiveViewName, 'HomePage');
      expect(sdk.debugIsInBackground, false);
      await _setLifecycleState(AppLifecycleState.paused);
      expect(sdk.debugIsInBackground, true);
      await _setLifecycleState(AppLifecycleState.resumed);
      expect(sdk.debugIsInBackground, false);
      expect(sdk.debugActiveViewName, 'HomePage');
      expect(sdk.debugEventQueueLength, 0, reason: 'Active view should not create event until ended');
    });

    test('empty view name is rejected', () async {
      final logger = TestLogger();
      final sdk = await _createInstance(logger: logger);

      sdk.views.startAutoStoppedView('');
      expect(logger.logs.any((log) => log.contains('error') && log.contains('empty')), true, reason: 'Empty view name should trigger error log');
      expect(sdk.debugActiveViewName, isNull, reason: 'No active view should be set for empty name');
    });

    test('starting a new view ends the previous view automatically', () async {
      final sdk = await _createInstance();

      await sdk.views.startAutoStoppedView('FirstView');
      await Future.delayed(const Duration(milliseconds: 50));
      await sdk.views.startAutoStoppedView('SecondView');

      // FirstView should now be ended and in the event queue
      expect(sdk.debugEventQueueLength, 1);
      final viewEvent = sdk.debugEventQueueSnapshot.first;
      expect(viewEvent['key'], '[CLY]_view');
      expect(viewEvent['segmentation']['name'], 'FirstView');
      expect(viewEvent['segmentation']['visit'], 1);
      expect(viewEvent['dur'], inInclusiveRange(0.05, 0.1));
    });

    test('view event has correct structure', () async {
      final sdk = await _createInstance();

      await sdk.views.startAutoStoppedView('TestView');
      await Future.delayed(const Duration(milliseconds: 100));
      await sdk.views.startAutoStoppedView('NextView'); // This ends TestView

      final viewEvent = sdk.debugEventQueueSnapshot.first;
      expect(viewEvent['key'], '[CLY]_view');
      expect(viewEvent['count'], 1);
      expect(viewEvent['dur'], isA<double>());
      expect(viewEvent['dur'], greaterThan(0));
      expect(viewEvent['segmentation']['name'], 'TestView');
      expect(viewEvent['segmentation']['visit'], 1);
      expect(viewEvent['timestamp'], isA<int>());
      expect(viewEvent['hour'], isA<int>());
      expect(viewEvent['dow'], isA<int>());
    });

    test('autostopped view accepts and records segmentation', () async {
      final sdk = await _createInstance();

      await sdk.views.startAutoStoppedView('SegmentedView', segmentation: {'section': 'home', 'step': 1});
      await sdk.views.startAutoStoppedView('NextView');

      final viewEvent = sdk.debugEventQueueSnapshot.first;
      expect(viewEvent['segmentation']['name'], 'SegmentedView');
      expect(viewEvent['segmentation']['visit'], 1);
      expect(viewEvent['segmentation']['section'], 'home');
      expect(viewEvent['segmentation']['step'], 1);
    });

    test('start and end segmentation are merged and end values take precedence', () async {
      final sdk = await _createInstance();

      await sdk.views.startAutoStoppedView('MergedView', segmentation: {'from_start': 'yes', 'shared': 'start'});
      await sdk.views.endActiveView(segmentation: {'from_end': 'yes', 'shared': 'end'});

      final viewEvent = sdk.debugEventQueueSnapshot.first;
      expect(viewEvent['segmentation']['name'], 'MergedView');
      expect(viewEvent['segmentation']['visit'], 1);
      expect(viewEvent['segmentation']['from_start'], 'yes');
      expect(viewEvent['segmentation']['from_end'], 'yes');
      expect(viewEvent['segmentation']['shared'], 'end');
    });

    test('internal view segmentation keys cannot be overridden by user values', () async {
      final sdk = await _createInstance();

      await sdk.views.startAutoStoppedView('InternalKeysView', segmentation: {'name': 'fake', 'visit': 999, 'recovered': 123, 'ok': true});
      await sdk.views.endActiveView(segmentation: {'name': 'fake2', 'visit': 111, 'recovered': 222});

      final viewEvent = sdk.debugEventQueueSnapshot.first;
      expect(viewEvent['segmentation']['name'], 'InternalKeysView');
      expect(viewEvent['segmentation']['visit'], 1);
      expect(viewEvent['segmentation']['recovered'], isNull);
      expect(viewEvent['segmentation']['ok'], true);
    });

    test('view segmentation respects SBS sw filtering', () async {
      final sdk = await _createInstance(
        sbs: {
          'c': {
            'sw': ['allowed'],
          },
        },
      );

      await sdk.views.startAutoStoppedView('FilteredView', segmentation: {'allowed': 'yes', 'blocked': 'no'});
      await sdk.views.endActiveView(segmentation: {'allowed': 'still', 'blocked2': 'no'});

      final viewEvent = sdk.debugEventQueueSnapshot.first;
      final seg = Map<String, dynamic>.from(viewEvent['segmentation'] as Map);
      expect(seg['name'], 'FilteredView');
      expect(seg['visit'], 1);
      expect(seg['allowed'], 'still');
      expect(seg.containsKey('blocked'), false);
      expect(seg.containsKey('blocked2'), false);
    });
  });

  group('Views Module - Duration Calculation', () {
    test('view duration is calculated from start time to end time', () async {
      final sdk = await _createInstance();

      final beforeStart = DateTime.now();
      await sdk.views.startAutoStoppedView('TimedView');
      await Future.delayed(const Duration(milliseconds: 50));
      await sdk.views.startAutoStoppedView('NextView');
      final afterEnd = DateTime.now();

      final viewEvent = sdk.debugEventQueueSnapshot.first;
      final durSeconds = viewEvent['dur'] as double;

      // Duration should be positive and less than total elapsed time
      expect(durSeconds, greaterThanOrEqualTo(0.0), reason: 'Duration must be non-negative');
      final maxPossibleDur = afterEnd.difference(beforeStart).inMilliseconds / 1000.0;
      expect(durSeconds, lessThanOrEqualTo(maxPossibleDur + 0.1), reason: 'Duration should not exceed elapsed time');
    });

    test('duration is in seconds as double', () async {
      final sdk = await _createInstance();

      await sdk.views.startAutoStoppedView('DurationTestView');
      await Future.delayed(const Duration(milliseconds: 150));
      await sdk.views.startAutoStoppedView('EndView');

      final viewEvent = sdk.debugEventQueueSnapshot.first;
      expect(viewEvent['dur'], isA<double>());
    });

    test('zero or negative duration is normalized to 0', () async {
      final sdk = await _createInstance();

      // Start and immediately end (nearly zero duration)
      await sdk.views.startAutoStoppedView('QuickView');
      await sdk.views.startAutoStoppedView('NextView');

      final viewEvent = sdk.debugEventQueueSnapshot.first;
      final dur = viewEvent['dur'] as double;
      expect(dur, greaterThanOrEqualTo(0), reason: 'Duration should never be negative');
    });
  });

  group('Views Module - Multiple View Transitions', () {
    test('multiple view transitions record events in order', () async {
      final sdk = await _createInstance();

      await sdk.views.startAutoStoppedView('View1');
      await sdk.views.startAutoStoppedView('View2');
      await sdk.views.startAutoStoppedView('View3');
      await sdk.views.startAutoStoppedView('View4');

      expect(sdk.debugEventQueueLength, 3, reason: 'Three views should be ended');

      final viewNames = sdk.debugEventQueueSnapshot.map((e) => e['segmentation']['name']).toList();
      expect(viewNames, ['View1', 'View2', 'View3'], reason: 'Views should be in transition order');
    });

    test('each ended view has its own duration', () async {
      final sdk = await _createInstance();

      await sdk.views.startAutoStoppedView('ShortView');
      await Future.delayed(const Duration(milliseconds: 100));
      await sdk.views.startAutoStoppedView('LongerView');
      await Future.delayed(const Duration(milliseconds: 500));
      await sdk.views.startAutoStoppedView('FinalView');

      final events = sdk.debugEventQueueSnapshot;
      final shortViewDur = events[0]['dur'] as double;
      final longerViewDur = events[1]['dur'] as double;

      // Both durations should be non-negative
      expect(shortViewDur, inInclusiveRange(0.1, 0.2));
      expect(longerViewDur, inInclusiveRange(0.5, 0.6));
      // The longer delay view should have greater or equal duration (allowing for timing variance)
      expect(longerViewDur, greaterThanOrEqualTo(shortViewDur * 0.5), reason: 'Longer view should have comparable or greater duration');
    });
  });

  group('Views Module - Consent Handling', () {
    test('views are not tracked without consent', () async {
      final logger = TestLogger();
      final sdk = await _createInstance(giveConsent: false, startWithUnknownConsent: false, logger: logger);

      sdk.views.startAutoStoppedView('NoConsentView');
      sdk.views.startAutoStoppedView('AnotherView');

      expect(sdk.debugEventQueueLength, 0, reason: 'Views should not be tracked without consent');
    });

    test('views are tracked with consent given at init', () async {
      final sdk = await _createInstance(giveConsent: true);

      await sdk.views.startAutoStoppedView('ConsentedView');
      await sdk.views.startAutoStoppedView('NextView');

      expect(sdk.debugEventQueueLength, 1);
      expect(sdk.debugEventQueueSnapshot.first['segmentation']['name'], 'ConsentedView');
    });

    test('views are tracked in unknown consent mode', () async {
      final sdk = await _createInstance(giveConsent: false, startWithUnknownConsent: true);

      await sdk.views.startAutoStoppedView('UnknownConsentView');
      await sdk.views.startAutoStoppedView('NextView');

      expect(sdk.debugEventQueueLength, 1);
      expect(sdk.debugEventQueueSnapshot.first['segmentation']['name'], 'UnknownConsentView');
    });
  });

  group('Views Module - SBS View Tracking Control', () {
    test('view tracking can be disabled via SBS', () async {
      final logger = TestLogger();
      final sdk = await _createInstance(
        logger: logger,
        sbs: {
          'c': {'vt': false},
        },
      );

      sdk.views.startAutoStoppedView('DisabledView');
      sdk.views.startAutoStoppedView('NextView');

      expect(sdk.debugEventQueueLength, 0, reason: 'Views should not be tracked when vt=false');
      expect(logger.logs.isNotEmpty, true);
    });
  });

  group('Views Module - View Name Truncation', () {
    test('long view name is truncated to key length limit', () async {
      final sdk = await _createInstance();

      final longName = 'V' * 200; // Longer than 128 limit
      await sdk.views.startAutoStoppedView(longName);
      await sdk.views.startAutoStoppedView('Short');

      final viewEvent = sdk.debugEventQueueSnapshot.first;
      final recordedName = viewEvent['segmentation']['name'] as String;
      expect(recordedName.length, 128, reason: 'View name should be truncated');
    });
  });

  group('Views Module - View Recovery from Storage', () {
    test('unended view is recovered on next init', () async {
      final backing = <String, String>{};
      final storage = MemoryBackedStorage(backing);

      // Create instance and start a view
      final network1 = FakeNetworkClient('https://example.com');
      final cfg1 = CountlyConfig(appKey: 'app-key', serverUrl: 'https://example.com', deviceId: 'test-device', storageMode: StorageMode.persistent, storageMethods: storage.toMethods(), giveConsent: true, enableSDKLogs: true, networkClientOverride: network1);
      final sdk1 = await Countly.init(cfg1, instanceKey: 'v1');
      sdk1.debugOverrideBehaviorSettings(eventQueueSize: 100);

      await sdk1.views.startAutoStoppedView('RecoverableView');

      // Allow async storage write to complete
      await Future.delayed(const Duration(milliseconds: 5000));

      // Simulate app crash - view data should be persisted
      // Note: dispose() would end the view, so we just check the persisted state before dispose
      expect(backing.containsKey('v1_COUNTLY_ACTIVE_VIEW'), true);
      expect(jsonDecode(backing['v1_COUNTLY_ACTIVE_VIEW']!)['n'], 'RecoverableView');
      expect(jsonDecode(backing['v1_COUNTLY_ACTIVE_VIEW']!)['d'], 0); // less than 15 seconds of heartbeat time
      final ts = jsonDecode(backing['v1_COUNTLY_ACTIVE_VIEW']!)['ts'];
      expect(jsonDecode(backing['v1_COUNTLY_ACTIVE_VIEW']!)['ts'], isA<int>());

      await Future.delayed(const Duration(milliseconds: 10000));

      expect(backing.containsKey('v1_COUNTLY_ACTIVE_VIEW'), true);
      expect(jsonDecode(backing['v1_COUNTLY_ACTIVE_VIEW']!)['n'], 'RecoverableView');
      expect(jsonDecode(backing['v1_COUNTLY_ACTIVE_VIEW']!)['d'], inInclusiveRange(15000, 15100)); // less than 15 seconds of heartbeat time
      expect(jsonDecode(backing['v1_COUNTLY_ACTIVE_VIEW']!)['ts'], ts);

      // Now clean up sdk1 - this will end the view but we've already verified it was persisted
      await sdk1.dispose(flush: false);

      // For the recovery test, manually restore the view data as if app crashed
      backing['v1_COUNTLY_ACTIVE_VIEW'] = jsonEncode({
        'n': 'RecoverableView',
        'ts': DateTime.now().subtract(const Duration(seconds: 15)).millisecondsSinceEpoch,
        'd': 55000, // 55 seconds of heartbeat time
      });

      expect(backing.containsKey('v1_COUNTLY_DART_ID'), true);
      expect(backing['v1_COUNTLY_DART_ID'], 'test-device');
      expect(backing.containsKey('v1_COUNTLY_DART_IDT'), true);
      expect(backing['v1_COUNTLY_DART_IDT'].toString(), '0'); // DeviceIdType.provided

      expect(backing.containsKey('v1_COUNTLY_DART_RQ'), true);
      final rqList = jsonDecode(backing['v1_COUNTLY_DART_RQ']!) as List<dynamic>;
      expect(rqList.length, 3);
      expect(rqList[0]['consent'], isNotNull);
      expect(rqList[1]['location'], isNotNull);
      expect(rqList[2]['metrics'], isNotNull);

      expect(backing.containsKey('v1_COUNTLY_DART_SBS'), true);
      final sbs = jsonDecode(backing['v1_COUNTLY_DART_SBS']!) as Map<String, dynamic>;
      expect(sbs.containsKey('c'), true);

      expect(backing.containsKey('v1_COUNTLY_DART_EQ'), true);
      final eqList = jsonDecode(backing['v1_COUNTLY_DART_EQ']!) as List<dynamic>;
      expect(eqList.length, 1);
      final firstEq = eqList.first as Map<String, dynamic>;
      expect(firstEq['key'], '[CLY]_view');
      expect(firstEq['segmentation']['name'], 'RecoverableView');
      expect((firstEq['dur'] as num).toDouble(), closeTo(15.0, 1.0));

      // Active view
      expect(backing.containsKey('v1_COUNTLY_ACTIVE_VIEW'), true);
      final active = jsonDecode(backing['v1_COUNTLY_ACTIVE_VIEW']!) as Map<String, dynamic>;
      expect(active['n'], 'RecoverableView');
      expect(active['d'], 55000);
      expect(active['ts'], isA<int>());

      // Create new instance - it should recover the view and send it
      final network2 = FakeNetworkClient('https://example.com');
      final cfg2 = CountlyConfig(appKey: 'app-key', serverUrl: 'https://example.com', deviceId: 'test-device', storageMode: StorageMode.persistent, storageMethods: MemoryBackedStorage(backing).toMethods(), giveConsent: true, enableSDKLogs: true, networkClientOverride: network2);
      final sdk2 = await Countly.init(cfg2, instanceKey: 'v1');
      addTearDown(() async {
        await Countly.disposeAll();
      });

      // requests will include timestamp, hour, dow, tz and rr values
      final consentRequest = Map<String, dynamic>.from(helper.trueConsentRequest);
      consentRequest['timestamp'] = isA<int>();
      consentRequest['hour'] = isA<int>();
      consentRequest['dow'] = isA<int>();
      consentRequest['tz'] = isA<int>();
      consentRequest['rr'] = 4;
      final locationRequest = Map<String, dynamic>.from(helper.locationRequest);
      locationRequest['timestamp'] = isA<int>();
      locationRequest['hour'] = isA<int>();
      locationRequest['dow'] = isA<int>();
      locationRequest['tz'] = isA<int>();
      locationRequest['rr'] = 3;
      final metricsRequest = Map<String, dynamic>.from(helper.metricsRequest);
      metricsRequest['timestamp'] = isA<int>();
      metricsRequest['hour'] = isA<int>();
      metricsRequest['dow'] = isA<int>();
      metricsRequest['tz'] = isA<int>();
      metricsRequest['rr'] = 2;

      // data from first instance
      expect(network2.sent[0], equals(consentRequest));
      expect(network2.sent[1], equals(locationRequest));
      expect(network2.sent[2], equals(metricsRequest));

      final events = helper.deconstructEventsRequest(network2.sent.firstWhere((r) => r.containsKey('events')));
      expect(network2.sent[3], contains("events"));
      expect(events.length, equals(2)); // ended view from dispose and recovered view we manually added
      expect(events[0]['segmentation']['name'], equals('RecoverableView'));
      expect(events[0]['segmentation']['recovered'], isNull);
      expect(events[0]['dur'], closeTo(15.0, 1.0));
      expect(events[1]['segmentation']['name'], equals('RecoverableView'));
      expect(events[1]['segmentation']['recovered'], equals(1));
      expect(events[1]['dur'], closeTo(55.0, 1.0));

      expect(network2.sent[4], equals(helper.sdkBehaviorRequest));
      expect(network2.sent[5], equals(helper.healthCheckRequest));

      // eq cleared
      expect(sdk2.debugEventQueueSnapshot, equals([]));

      // all eq requests sent
      expect(sdk2.debugRequestQueueSnapshot.length, equals(3));

      // order
      expect(sdk2.debugRequestQueueSnapshot[0], equals(helper.trueConsentRequest));
      expect(sdk2.debugRequestQueueSnapshot[1], equals(helper.locationRequest));
      expect(sdk2.debugRequestQueueSnapshot[2], equals(helper.metricsRequest));
    });

    test('recovered view preserves user segmentation and protects internal keys', () async {
      final backing = <String, String>{
        'v-recovery-seg_COUNTLY_ACTIVE_VIEW': jsonEncode({
          'n': 'RecoveredWithSeg',
          'ts': DateTime.now().subtract(const Duration(seconds: 5)).millisecondsSinceEpoch,
          'd': 7000,
          's': {'source': 'push', 'name': 'fake_name', 'visit': 999, 'recovered': 999},
        }),
      };

      final network = FakeNetworkClient('https://example.com');
      final cfg = CountlyConfig(appKey: 'app-key', serverUrl: 'https://example.com', deviceId: 'test-device', storageMode: StorageMode.persistent, storageMethods: MemoryBackedStorage(backing).toMethods(), giveConsent: true, enableSDKLogs: true, networkClientOverride: network);

      final sdk = await Countly.init(cfg, instanceKey: 'v-recovery-seg');
      addTearDown(() async {
        await Countly.disposeAll();
      });

      final eventsReq = network.sent.firstWhere((r) => r.containsKey('events'));
      final events = helper.deconstructEventsRequest(eventsReq);
      final recovered = events.firstWhere((e) => e['key'] == '[CLY]_view' && e['segmentation']['recovered'] == 1);

      expect(recovered['segmentation']['name'], 'RecoveredWithSeg');
      expect(recovered['segmentation']['visit'], 1);
      expect(recovered['segmentation']['recovered'], 1);
      expect(recovered['segmentation']['source'], 'push');

      expect(backing.containsKey('v-recovery-seg_COUNTLY_ACTIVE_VIEW'), false, reason: 'Recovered active view state should be cleared after recoverView runs');
      expect(sdk.debugEventQueueSnapshot, equals([]));
    });
  });

  group('Views Module - Dispose Behavior', () {
    test('active view is ended on dispose', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.views.startAutoStoppedView('DisposeTestView');

      await sdk.dispose(flush: true);

      // Check that view event was sent
      final eventsRequests = network.sent.where((r) => r.containsKey('events')).toList();
      expect(eventsRequests.length, 1);

      // Parse events to find the view
      bool foundView = false;
      for (final req in eventsRequests) {
        final eventsJson = req['events'] as String;
        final events = jsonDecode(eventsJson) as List<dynamic>;
        for (final e in events) {
          if (e['key'] == '[CLY]_view' && e['segmentation']['name'] == 'DisposeTestView') {
            foundView = true;
          }
        }
      }
      expect(foundView, true, reason: 'View should be ended and sent on dispose');
    });

    test('views cannot be started after dispose', () async {
      final logger = TestLogger();
      final cfg = CountlyConfig(appKey: 'app-key', serverUrl: 'https://example.com', deviceId: 'test-device', storageMode: StorageMode.memory, giveConsent: true, enableSDKLogs: true, logger: logger);
      final sdk = await Countly.init(cfg, instanceKey: 'dispose-view-${DateTime.now().microsecondsSinceEpoch}');

      await sdk.dispose(flush: false);
      await sdk.views.startAutoStoppedView('AfterDispose');

      expect(logger.logs.any((log) => log.contains('disposed')), true);
      expect(sdk.debugActiveViewName, isNull, reason: 'No view should be active after dispose');
    });
  });

  group('Views Module - Event Queue Integration', () {
    test('view events go to event queue with other events', () async {
      final sdk = await _createInstance();

      await sdk.events.record(key: 'before_view');
      await sdk.views.startAutoStoppedView('TestView');
      await sdk.events.record(key: 'during_view');
      await sdk.views.startAutoStoppedView('NextView'); // Ends TestView
      await sdk.events.record(key: 'after_view');

      final events = sdk.debugEventQueueSnapshot;
      expect(events.length, 4);

      final keys = events.map((e) => e['key']).toList();
      expect(keys[0], 'before_view');
      expect(keys[1], 'during_view');
      expect(keys[2], '[CLY]_view');
      expect(keys[3], 'after_view');
    });

    test('view events are bundled with other events in request', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.events.record(key: 'event1');
      await sdk.views.startAutoStoppedView('View1');
      await sdk.views.startAutoStoppedView('View2');
      await sdk.events.record(key: 'event2');

      await sdk.processEventsAndRequests();

      final eventsReq = network.sent.firstWhere((r) => r.containsKey('events'));
      final eventsJson = eventsReq['events'] as String;
      final events = jsonDecode(eventsJson) as List<dynamic>;

      expect(events.length, 3);
      expect(events.any((e) => e['key'] == 'event1'), true);
      expect(events.any((e) => e['key'] == 'event2'), true);
      expect(events.any((e) => e['key'] == '[CLY]_view'), true);
    });
  });

  group('Views Module - Timestamp Tracking', () {
    test('view event uses start timestamp, not end timestamp', () async {
      final sdk = await _createInstance();

      final beforeStart = DateTime.now();
      await sdk.views.startAutoStoppedView('TimestampView');
      final afterStart = DateTime.now();

      await Future.delayed(const Duration(milliseconds: 100));

      await sdk.views.startAutoStoppedView('NextView');

      final viewEvent = sdk.debugEventQueueSnapshot.first;
      final eventTs = viewEvent['timestamp'] as int;

      expect(eventTs, greaterThanOrEqualTo(beforeStart.millisecondsSinceEpoch));
      expect(eventTs, lessThanOrEqualTo(afterStart.millisecondsSinceEpoch));
    });
  });

  group('Views Module - Unknown Consent Mode Persistence', () {
    test('view state is not persisted in unknown consent mode', () async {
      final backing = <String, String>{};
      final sdk = await _createInstance(giveConsent: false, startWithUnknownConsent: true, storageBacking: backing, storageMode: StorageMode.persistent);

      sdk.views.startAutoStoppedView('UnknownModeView');

      // View state should NOT be persisted in unknown consent mode
      expect(backing.containsKey('COUNTLY_ACTIVE_VIEW'), false, reason: 'View state should not be persisted in unknown consent mode');
    });
  });

  group('Views Module - Extra Coverage', () {
    test('recoverView logs error on invalid stored data', () async {
      final logger = TestLogger();
      // store JSON that has wrong types to force a casting error during recoverView
      final invalid = jsonEncode({'n': 123});
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(logger: logger, storageBacking: {'views_COUNTLY_ACTIVE_VIEW': invalid}, networkClient: network);
      await sdk.views.recoverView();
      expect(logger.logs.any((l) => l.contains('Error recovering view')), true);
      await sdk.dispose();
      await sdk.views.endActiveView();
      sdk.views.testHeartbeatOnce();
      expect(sdk.debugActiveViewName, isNull);
    });

    test('heartbeat lastBeatTime assignment and heartbeat logging', () async {
      final logger = TestLogger();
      final sdk = await _createInstance(logger: logger);
      // Set up active view but leave internal lastBeatTime null so first heartbeat assigns it
      sdk.views.testSetupActiveViewForHeartbeat('HBView');
      await sdk.views.testHeartbeatOnce(); // sets _lastBeatTime
      await Future.delayed(const Duration(milliseconds: 50));
      await sdk.views.testHeartbeatOnce(); // should log a heartbeat
      expect(logger.logs.any((l) => l.contains('Heartbeat view')), true);
    });
  });
}
