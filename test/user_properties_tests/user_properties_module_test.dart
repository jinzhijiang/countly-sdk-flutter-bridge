import 'dart:convert';

import 'package:countly_flutter_lite/countly.dart';
import 'package:countly_sdk_dart_core/src/networking.dart';
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

Future<CountlyInstance> _createInstance({
  bool giveConsent = true,
  bool startWithUnknownConsent = false,
  Map<String, dynamic>? userProperties,
  TestLogger? logger,
  FakeNetworkClient? networkClient,
  Map<String, dynamic>? sbs,
}) async {
  final log = logger ?? TestLogger();
  final client = networkClient ?? FakeNetworkClient('https://example.com');
  final cfg = CountlyConfig(
    appKey: 'app-key',
    serverUrl: 'https://example.com',
    deviceId: 'test-device',
    storageMode: StorageMode.memory,
    startWithUnknownConsent: startWithUnknownConsent,
    giveConsent: giveConsent,
    enableSDKLogs: true,
    logLevel: LogLevel.verbose,
    logger: log,
    userProperties: userProperties,
    networkClientOverride: client,
    sbs: sbs ?? {},
  );
  final inst = await Countly.init(cfg);
  addTearDown(() async {
    await Countly.disposeAll();
  });
  return inst;
}

void main() {
  group('User Properties - Named Properties', () {
    test('setProperties with named property "name"', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.users.setProperties({'name': 'John Doe'});
      await sdk.processEventsAndRequests();

      final userReq = network.sent.firstWhere((r) => r.containsKey('user_details'));
      expect(userReq['user_details']['name'], 'John Doe');
    });

    test('setProperties with all named properties', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.users.setProperties({
        'name': 'Jane Smith',
        'username': 'janesmith',
        'email': 'jane@example.com',
        'organization': 'Acme Corp',
        'phone': '+1234567890',
        'picture': 'https://example.com/avatar.jpg',
        'gender': 'F',
        'byear': 1990,
      });
      await sdk.processEventsAndRequests();

      final userReq = network.sent.firstWhere((r) => r.containsKey('user_details'));
      final ud = userReq['user_details'];
      expect(ud['name'], 'Jane Smith');
      expect(ud['username'], 'janesmith');
      expect(ud['email'], 'jane@example.com');
      expect(ud['organization'], 'Acme Corp');
      expect(ud['phone'], '+1234567890');
      expect(ud['picture'], 'https://example.com/avatar.jpg');
      expect(ud['gender'], 'F');
      expect(ud['byear'], 1990);
    });

    test('named properties are stored at top level of user_details', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.users.setProperties({'name': 'Test', 'email': 'test@test.com'});
      await sdk.processEventsAndRequests();

      final userReq = network.sent.firstWhere((r) => r.containsKey('user_details'));
      final ud = userReq['user_details'];

      // Named properties should NOT be under 'custom'
      expect(ud['name'], 'Test');
      expect(ud['email'], 'test@test.com');
      expect(ud['custom']?['name'], isNull);
      expect(ud['custom']?['email'], isNull);
    });
  });

  group('User Properties - Custom Properties', () {
    test('custom properties are stored under "custom" key', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.users.setProperties({
        'tier': 'premium',
        'signup_date': '2024-01-15',
        'points': 500,
      });
      await sdk.processEventsAndRequests();

      final userReq = network.sent.firstWhere((r) => r.containsKey('user_details'));
      final ud = userReq['user_details'];

      expect(ud['custom']['tier'], 'premium');
      expect(ud['custom']['signup_date'], '2024-01-15');
      expect(ud['custom']['points'], 500);
    });

    test('mixed named and custom properties are separated correctly', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.users.setProperties({
        'name': 'Alice', // named
        'email': 'alice@example.com', // named
        'tier': 'gold', // custom
        'referral_code': 'ABC123', // custom
      });
      await sdk.processEventsAndRequests();

      final userReq = network.sent.firstWhere((r) => r.containsKey('user_details'));
      final ud = userReq['user_details'];

      // Named at top level
      expect(ud['name'], 'Alice');
      expect(ud['email'], 'alice@example.com');

      // Custom under 'custom'
      expect(ud['custom']['tier'], 'gold');
      expect(ud['custom']['referral_code'], 'ABC123');

      // Named should NOT be in custom
      expect(ud['custom'].containsKey('name'), false);
      expect(ud['custom'].containsKey('email'), false);
    });
  });

  group('User Properties - Array Operations', () {
    test('pushToArray adds values to array property', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      sdk.users.pushToArray('tags', ['vip', 'early_adopter']);
      await sdk.processEventsAndRequests();

      final userReq = network.sent.firstWhere((r) => r.containsKey('user_details'));
      final custom = userReq['user_details']['custom'];

      expect(custom['tags'], isA<Map>());
      expect(custom['tags']['\$push'], ['vip', 'early_adopter']);
    });

    test('addToSet adds unique values to array property', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      sdk.users.addToSet('categories', ['electronics', 'books']);
      await sdk.processEventsAndRequests();

      final userReq = network.sent.firstWhere((r) => r.containsKey('user_details'));
      final custom = userReq['user_details']['custom'];

      expect(custom['categories'], isA<Map>());
      expect(custom['categories']['\$addToSet'], ['electronics', 'books']);
    });

    test('pullFromArray removes values from array property', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      sdk.users.pullFromArray('unwanted_tags', ['spam', 'test']);
      await sdk.processEventsAndRequests();

      final userReq = network.sent.firstWhere((r) => r.containsKey('user_details'));
      final custom = userReq['user_details']['custom'];

      expect(custom['unwanted_tags'], isA<Map>());
      expect(custom['unwanted_tags']['\$pull'], ['spam', 'test']);
    });
  });

  group('User Properties - Cache Behavior', () {
    test('multiple setProperties calls merge into cache', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.users.setProperties({'name': 'First'});
      await sdk.users.setProperties({'email': 'first@example.com'});
      await sdk.users.setProperties({'tier': 'bronze'});

      await sdk.processEventsAndRequests();

      // All properties should be in a single request (or the last batch)
      final userReqs = network.sent.where((r) => r.containsKey('user_details')).toList();

      // Check that all properties were sent
      bool foundName = false;
      bool foundEmail = false;
      bool foundTier = false;

      for (final req in userReqs) {
        final ud = req['user_details'];
        if (ud['name'] == 'First') foundName = true;
        if (ud['email'] == 'first@example.com') foundEmail = true;
        if (ud['custom']?['tier'] == 'bronze') foundTier = true;
      }

      expect(foundName, true);
      expect(foundEmail, true);
      expect(foundTier, true);
    });

    test('later setProperties overwrites same keys', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.users.setProperties({'name': 'Original'});
      await sdk.users.setProperties({'name': 'Updated'});

      await sdk.processEventsAndRequests();

      final userReqs = network.sent.where((r) => r.containsKey('user_details')).toList();
      final lastReq = userReqs.last;
      expect(lastReq['user_details']['name'], 'Updated');
    });

    test('cache is flushed when event is recorded', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.users.setProperties({'name': 'CacheFlushTest'});
      await sdk.events.record(key: 'test_event');

      await sdk.processEventsAndRequests();

      // User details should be sent before events
      final userIdx = network.sent.indexWhere((r) => r.containsKey('user_details'));
      final eventsIdx = network.sent.indexWhere((r) => r.containsKey('events'));

      expect(userIdx, isNot(-1));
      expect(eventsIdx, isNot(-1));
      expect(userIdx, lessThan(eventsIdx));
    });

    test('cache is flushed when limit is reached', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(
        networkClient: network,
        sbs: {
          'c': {'upcl': 3}
        }, // Low limit
      );

      // Set enough properties to exceed limit
      await sdk.users.setProperties({'p1': 'v1'});
      await sdk.users.setProperties({'p1': 'v2'});
      await sdk.users.setProperties({'p1': 'v3'});
      await sdk.users.setProperties({'p1': 'v1'});
      await sdk.users.setProperties({'p2': 'v2'});
      final userReqs = sdk.debugRequestQueueSnapshot.where((r) => r.containsKey('user_details')).toList();
      expect(userReqs.length, 0);

      await sdk.users.setProperties({'p3': 'v3'}); // This should trigger flush

      final userReqs2 = sdk.debugRequestQueueSnapshot.where((r) => r.containsKey('user_details')).toList();
      expect(userReqs2.length, 1);
    });
  });

  group('User Properties - Init Time Properties', () {
    test('user properties provided at init are recorded', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(
        networkClient: network,
        userProperties: {
          'name': 'InitUser',
          'email': 'init@example.com',
          'subscription': 'annual',
        },
      );

      // Init properties are queued after initial processEventsAndRequests, so we need to process again
      await sdk.processEventsAndRequests();

      final userReqs = network.sent.where((r) => r.containsKey('user_details')).toList();
      expect(userReqs.length, greaterThan(0));

      // Find the init properties
      bool foundInitProps = false;
      for (final req in userReqs) {
        final ud = req['user_details'];
        if (ud['name'] == 'InitUser') {
          foundInitProps = true;
          expect(ud['email'], 'init@example.com');
          expect(ud['custom']['subscription'], 'annual');
        }
      }
      expect(foundInitProps, true);
    });

    test('init properties require consent', () async {
      final network = FakeNetworkClient('https://example.com');
      await _createInstance(
        networkClient: network,
        giveConsent: false,
        startWithUnknownConsent: false,
        userProperties: {
          'name': 'NoConsentUser',
        },
      );

      await Future.delayed(const Duration(milliseconds: 100));

      // No user_details should be sent without consent
      final userReqsWithName = network.sent.where((r) {
        if (r.containsKey('user_details')) {
          return r['user_details']?['name'] == 'NoConsentUser';
        }
        return false;
      }).toList();

      expect(userReqsWithName.length, 0);
    });
  });

  group('User Properties - Consent Handling', () {
    test('setProperties dropped without consent', () async {
      final logger = TestLogger();
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(giveConsent: false, startWithUnknownConsent: false, logger: logger, networkClient: network);

      await sdk.users.setProperties({'name': 'NoConsent'});
      await sdk.processEventsAndRequests();

      final userReqs = network.sent.where((r) => r.containsKey('user_details')).toList();
      expect(userReqs.length, 0);
      expect(logger.logs.any((log) => log.contains('warning') && log.contains('consent')), true);
    });

    test('setProperties works with consent given', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network, giveConsent: true);

      await sdk.users.setProperties({'name': 'WithConsent'});
      await sdk.processEventsAndRequests();

      final userReqs = network.sent.where((r) => r.containsKey('user_details')).toList();
      expect(userReqs.any((r) => r['user_details']['name'] == 'WithConsent'), true);
    });
  });

  group('User Properties - Value Truncation', () {
    test('long string values are truncated', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      final longValue = 'x' * 500;
      await sdk.users.setProperties({'bio': longValue});
      await sdk.processEventsAndRequests();

      final userReq = network.sent.firstWhere((r) => r.containsKey('user_details'));
      final bio = userReq['user_details']['custom']['bio'] as String;
      expect(bio.length, 256);
    });

    test('picture URL has higher length limit (4096)', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      final longUrl = 'https://example.com/${'x' * 5000}';
      await sdk.users.setProperties({'picture': longUrl});
      await sdk.processEventsAndRequests();

      final userReq = network.sent.firstWhere((r) => r.containsKey('user_details'));
      final picture = userReq['user_details']['picture'] as String;

      // Picture should not be truncated at 256, it has 4096 limit
      expect(picture.length, greaterThan(256));
      expect(picture.length, lessThanOrEqualTo(4096));
    });

    test('long custom property keys are truncated', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      final longKey = 'k' * 200;
      await sdk.users.setProperties({longKey: 'value'});
      await sdk.processEventsAndRequests();

      final userReq = network.sent.firstWhere((r) => r.containsKey('user_details'));
      final custom = userReq['user_details']['custom'] as Map<String, dynamic>;

      // Find the truncated key
      final foundKey = custom.keys.firstWhere((k) => k.startsWith('kkk'), orElse: () => '');
      expect(foundKey.length, 128);
    });
  });

  group('User Properties - SBS Filtering', () {
    test('properties in blacklist are dropped', () async {
      final logger = TestLogger();
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(
        logger: logger,
        networkClient: network,
        sbs: {
          'c': {
            'upb': ['secret_field', 'internal_id']
          }
        },
      );

      await sdk.users.setProperties({
        'name': 'Visible',
        'secret_field': 'hidden_value',
        'internal_id': '12345',
      });
      await sdk.processEventsAndRequests();

      final userReq = network.sent.firstWhere((r) => r.containsKey('user_details'));
      final ud = userReq['user_details'];

      expect(ud['name'], 'Visible');
      expect(ud['custom']?.containsKey('secret_field'), isNot(true));
      expect(ud['custom']?.containsKey('internal_id'), isNot(true));
      expect(logger.logs.any((log) => log.contains('blacklisted')), true);
    });

    test('properties not in whitelist are dropped when whitelist is set', () async {
      final logger = TestLogger();
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(
        logger: logger,
        networkClient: network,
        sbs: {
          'c': {
            'upw': ['name', 'email', 'tier']
          }
        },
      );

      await sdk.users.setProperties({
        'name': 'Allowed',
        'email': 'allowed@example.com',
        'tier': 'gold',
        'blocked_field': 'should_not_appear',
      });
      await sdk.processEventsAndRequests();

      final userReq = network.sent.firstWhere((r) => r.containsKey('user_details'));
      final ud = userReq['user_details'];

      expect(ud['name'], 'Allowed');
      expect(ud['email'], 'allowed@example.com');
      expect(ud['custom']['tier'], 'gold');
      expect(ud['custom']?.containsKey('blocked_field'), isNot(true));
    });

    test('tracking disabled via SBS blocks all user properties', () async {
      final logger = TestLogger();
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(
        logger: logger,
        networkClient: network,
        sbs: {
          'c': {'tracking': false}
        },
      );

      await sdk.users.setProperties({'name': 'Blocked'});
      await sdk.processEventsAndRequests();

      final userReqs = network.sent.where((r) => r.containsKey('user_details')).toList();
      expect(userReqs.length, 0);

      expect(logger.logs.any((log) => log.contains('Tracking disabled')), true);
    });
  });

  group('User Properties - Event Queue Flush on setProperties', () {
    test('setProperties flushes event queue first', () async {
      final sdk = await _createInstance();

      // Record events first
      await sdk.events.record(key: 'event_before_up');

      // Set user properties - should bundle events
      await sdk.users.setProperties({'name': 'AfterEvents'});

      expect(sdk.debugRequestQueueSnapshot.where((r) => r.containsKey('events')), isNotEmpty);
    });
  });

  group('User Properties - Request Structure', () {
    test('user_details request has correct structure', () async {
      final network = FakeNetworkClient('https://example.com');
      final sdk = await _createInstance(networkClient: network);

      await sdk.users.setProperties({'name': 'StructureTest', 'custom_prop': 'value'});
      await sdk.processEventsAndRequests();

      final userReq = network.sent.firstWhere((r) => r.containsKey('user_details'));

      expect(userReq['app_key'], 'app-key');
      expect(userReq['device_id'], 'test-device');
      expect(userReq['sdk_version'], isNotNull);
      expect(userReq['sdk_name'], isNotNull);
      expect(userReq['user_details'], isA<Map<String, dynamic>>());
    });
  });

  group('User Properties - Disposed Instance', () {
    test('setProperties ignored after dispose', () async {
      final logger = TestLogger();
      final cfg = CountlyConfig(
        appKey: 'app-key',
        serverUrl: 'https://example.com',
        deviceId: 'test-device',
        storageMode: StorageMode.memory,
        giveConsent: true,
        enableSDKLogs: true,
        logger: logger,
      );
      final sdk = await Countly.init(cfg);

      await sdk.dispose(flush: false);
      await sdk.users.setProperties({'name': 'AfterDispose'});

      expect(logger.logs.any((log) => log.contains('disposed')), true);
    });
  });
}
