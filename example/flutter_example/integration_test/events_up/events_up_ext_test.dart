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

  group('Events - Extended', () {
    testWidgets('event on disposed instance is silently ignored', (WidgetTester tester) async {
      final network = FakeNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'test-device',
        giveConsent: true,
        enableSDKLogs: true,
        storageMode: StorageMode.memory,
      );
      final sdk = await Countly.init(cfg);
      await Countly.disposeAll();

      // Should not throw
      await sdk.events.record(key: 'post_dispose');
      // Event queue should remain empty (disposed instance ignores calls)
      expect(sdk.debugEventQueueLength, 0, reason: 'Disposed instance should not accept events');
    });

    testWidgets('event with dur parameter is recorded correctly', (WidgetTester tester) async {
      final network = FakeNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'test-device',
        giveConsent: true,
        enableSDKLogs: true,
        storageMode: StorageMode.memory,
      );
      final sdk = await Countly.init(cfg);

      await sdk.events.record(key: 'timed_event', dur: 5.5);

      expect(sdk.debugEventQueueLength, 1, reason: 'Should have 1 event in queue');
      final evt = sdk.debugEventQueueSnapshot.first;
      expect(evt['key'], 'timed_event', reason: 'Event key must match');
      expect(evt['dur'], 5.5);
      expect(evt['count'], 1, reason: 'Default count should be 1');
      expect(evt['timestamp'], isA<int>(), reason: 'Event must have timestamp');
    });

    testWidgets('event without count defaults to 1', (WidgetTester tester) async {
      final network = FakeNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'test-device',
        giveConsent: true,
        enableSDKLogs: true,
        storageMode: StorageMode.memory,
      );
      final sdk = await Countly.init(cfg);

      await sdk.events.record(key: 'evt');

      expect(sdk.debugEventQueueLength, 1);
      final evt = sdk.debugEventQueueSnapshot.first;
      expect(evt['key'], 'evt');
      expect(evt['count'], 1, reason: 'Default count should be 1');
      expect(evt.containsKey('sum'), isFalse, reason: 'sum should not be present when not provided');
      expect(evt.containsKey('dur'), isFalse, reason: 'dur should not be present when not provided');
    });

    testWidgets('segmentation key and value truncation with default limits', (WidgetTester tester) async {
      final network = FakeNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'test-device',
        giveConsent: true,
        enableSDKLogs: true,
        storageMode: StorageMode.memory,
      );
      final sdk = await Countly.init(cfg);

      final longKey = 'k' * 200; // exceeds default 128
      final longValue = 'v' * 300; // exceeds default 256
      await sdk.events.record(key: 'evt', segmentation: {longKey: longValue});

      final seg = sdk.debugEventQueueSnapshot.first['segmentation'] as Map<String, dynamic>;
      // Key should be truncated to 128 chars
      final keys = seg.keys.toList();
      expect(keys.first.length, 128, reason: 'Segmentation key should be truncated to default lkl=128');
      // Value should be truncated to 256 chars
      expect((seg.values.first as String).length, 256, reason: 'Segmentation value should be truncated to default lvs=256');
    });
  });

  group('Users - Extended', () {
    testWidgets('all 8 named properties are at top level', (WidgetTester tester) async {
      final network = FakeNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'test-device',
        giveConsent: true,
        enableSDKLogs: true,
        storageMode: StorageMode.memory,
      );
      final sdk = await Countly.init(cfg);

      await sdk.users.setProperties({
        'name': 'Alice',
        'username': 'alice99',
        'email': 'alice@test.com',
        'organization': 'Acme',
        'phone': '+1234567890',
        'picture': 'https://img.example.com/alice.png',
        'gender': 'F',
        'byear': '1990',
      });
      await sdk.processEventsAndRequests();

      final userReqs = network.sent.where((r) => r.containsKey('user_details')).toList();
      expect(userReqs, isNotEmpty);

      final details = userReqs.last['user_details'] as Map<String, dynamic>;
      expect(details['name'], 'Alice');
      expect(details['username'], 'alice99');
      expect(details['email'], 'alice@test.com');
      expect(details['organization'], 'Acme');
      expect(details['phone'], '+1234567890');
      expect(details['picture'], 'https://img.example.com/alice.png');
      expect(details['gender'], 'F');
      expect(details['byear'], '1990');
      // None should be under 'custom'
      expect(details.containsKey('custom'), isFalse, reason: 'Named properties should not be under custom');
    });

    testWidgets('pushToArray sends \$push operator', (WidgetTester tester) async {
      final network = FakeNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'test-device',
        giveConsent: true,
        enableSDKLogs: true,
        storageMode: StorageMode.memory,
      );
      final sdk = await Countly.init(cfg);

      await sdk.users.pushToArray('tags', ['vip', 'beta']);
      await sdk.processEventsAndRequests();

      final userReqs = network.sent.where((r) => r.containsKey('user_details')).toList();
      expect(userReqs, isNotEmpty);

      final custom = (userReqs.last['user_details'] as Map<String, dynamic>)['custom'] as Map<String, dynamic>;
      expect(custom['tags'], isA<Map>());
      expect(custom['tags']['\$push'], ['vip', 'beta']);
    });

    testWidgets('addToSet sends \$addToSet operator', (WidgetTester tester) async {
      final network = FakeNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'test-device',
        giveConsent: true,
        enableSDKLogs: true,
        storageMode: StorageMode.memory,
      );
      final sdk = await Countly.init(cfg);

      await sdk.users.addToSet('interests', ['music']);
      await sdk.processEventsAndRequests();

      final userReqs = network.sent.where((r) => r.containsKey('user_details')).toList();
      expect(userReqs, isNotEmpty);

      final custom = (userReqs.last['user_details'] as Map<String, dynamic>)['custom'] as Map<String, dynamic>;
      expect(custom['interests']['\$addToSet'], ['music']);
    });

    testWidgets('pullFromArray sends \$pull operator', (WidgetTester tester) async {
      final network = FakeNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'test-device',
        giveConsent: true,
        enableSDKLogs: true,
        storageMode: StorageMode.memory,
      );
      final sdk = await Countly.init(cfg);

      await sdk.users.pullFromArray('tags', ['old_tag']);
      await sdk.processEventsAndRequests();

      final userReqs = network.sent.where((r) => r.containsKey('user_details')).toList();
      expect(userReqs, isNotEmpty);

      final custom = (userReqs.last['user_details'] as Map<String, dynamic>)['custom'] as Map<String, dynamic>;
      expect(custom['tags']['\$pull'], ['old_tag']);
    });

    testWidgets('user properties cache limit triggers early flush', (WidgetTester tester) async {
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
          'c': {'upcl': 3}
        },
      );
      final sdk = await Countly.init(cfg);

      // Set 4 properties - should trigger early flush at limit=3
      await sdk.users.setProperties({
        'prop_a': 'a',
        'prop_b': 'b',
        'prop_c': 'c',
        'prop_d': 'd',
      });

      // A user_details request should have been auto-enqueued
      final rqSnapshot = sdk.debugRequestQueueSnapshot;
      final userDetailReqs = rqSnapshot.where((r) => r.containsKey('user_details')).toList();
      expect(userDetailReqs, isNotEmpty, reason: 'User properties should be auto-enqueued when cache limit is reached');
      // Verify the auto-flushed request contains our properties
      final details = userDetailReqs.last['user_details'] as Map<String, dynamic>;
      expect(details.containsKey('custom'), isTrue, reason: 'Auto-flushed request should have custom properties');
      final custom = details['custom'] as Map<String, dynamic>;
      expect(custom.length, greaterThanOrEqualTo(3), reason: 'At least 3 of the 4 properties should be in the flushed batch');
    });

    testWidgets('picture field has 4096-char limit instead of lvs', (WidgetTester tester) async {
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
          'c': {'lvs': 10}
        }, // small value limit
      );
      final sdk = await Countly.init(cfg);

      final longUrl = 'https://img.example.com/' + ('x' * 300); // 326 chars, exceeds lvs=10
      await sdk.users.setProperties({
        'picture': longUrl,
        'name': 'A_long_name_value_here', // 21 chars, exceeds lvs=10
      });
      await sdk.processEventsAndRequests();

      final userReqs = network.sent.where((r) => r.containsKey('user_details')).toList();
      expect(userReqs, isNotEmpty);

      final details = userReqs.last['user_details'] as Map<String, dynamic>;
      // picture has 4096 limit, so 326 chars should NOT be truncated
      expect(details['picture'], longUrl, reason: 'Picture field uses 4096 limit, not lvs');
      // name should be truncated to lvs=10
      expect((details['name'] as String).length, 10, reason: 'Name should be truncated to lvs=10');
    });
  });

  group('Consent - Idempotency', () {
    testWidgets('giveConsent called twice is idempotent', (WidgetTester tester) async {
      final network = FakeNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'test-device',
        giveConsent: true,
        enableSDKLogs: true,
        storageMode: StorageMode.memory,
      );
      final sdk = await Countly.init(cfg);

      final rqBefore = sdk.debugRequestQueueLength;
      await sdk.consents.giveConsent();
      expect(sdk.debugRequestQueueLength, rqBefore, reason: 'No duplicate consent request for already-granted consent');
    });

    testWidgets('consent affects view tracking cross-module', (WidgetTester tester) async {
      final network = FakeNetworkClient('https://example.com');
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        networkClientOverride: network,
        deviceId: 'test-device',
        giveConsent: false,
        enableSDKLogs: true,
        storageMode: StorageMode.memory,
        sbs: {
          'c': {'vt': true}
        },
      );
      final sdk = await Countly.init(cfg);

      // Without consent, views should not track
      await sdk.views.startAutoStoppedView('NoConsentView');
      expect(sdk.debugActiveViewName, isNull, reason: 'View should not be tracked without consent');

      // Give consent
      await sdk.consents.giveConsent();

      // Now views should work
      await sdk.views.startAutoStoppedView('ConsentedView');
      expect(sdk.debugActiveViewName, 'ConsentedView');
    });
  });
}
