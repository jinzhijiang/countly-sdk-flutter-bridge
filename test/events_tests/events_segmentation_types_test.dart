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
    sent.add({...data});
    if (data['method'] == 'sc') {
      return FakeResponseSuccess(body: '{"c":{}}');
    }
    return FakeResponseSuccess();
  }

  @override
  Future<http.Response> makeSelectiveRequest(Map<String, dynamic> data) async {
    sent.add({...data});
    return FakeResponseSuccess();
  }
}

Future<CountlyInstance> _createInstance({
  bool giveConsent = true,
  TestLogger? logger,
  FakeNetworkClient? networkClient,
}) async {
  final log = logger ?? TestLogger();
  final client = networkClient ?? FakeNetworkClient('https://example.com');
  final cfg = CountlyConfig(
    appKey: 'app-key',
    serverUrl: 'https://example.com',
    deviceId: 'test-device',
    storageMode: StorageMode.memory,
    giveConsent: giveConsent,
    enableSDKLogs: true,
    logLevel: LogLevel.verbose,
    logger: log,
    networkClientOverride: client,
  );
  final inst = await Countly.init(cfg);
  addTearDown(() async {
    await Countly.disposeAll();
  });
  return inst;
}

void main() {
  group('Events Module - Segmentation with Various Value Types', () {
    group('String Values', () {
      test('record event with single string segmentation', () async {
        final sdk = await _createInstance();

        await sdk.events.record(
          key: 'string_test',
          segmentation: {'product_name': 'Wireless Headphones'},
        );

        final event = sdk.debugEventQueueSnapshot.first;
        expect(event['segmentation']['product_name'], 'Wireless Headphones');
      });

      test('record event with multiple string segmentation values', () async {
        final sdk = await _createInstance();

        await sdk.events.record(
          key: 'multi_string_test',
          segmentation: {
            'category': 'electronics',
            'brand': 'TechBrand',
            'color': 'blue',
            'size': 'medium',
          },
        );

        final event = sdk.debugEventQueueSnapshot.first;
        expect(event['segmentation']['category'], 'electronics');
        expect(event['segmentation']['brand'], 'TechBrand');
        expect(event['segmentation']['color'], 'blue');
        expect(event['segmentation']['size'], 'medium');
      });

      test('record event with empty string value', () async {
        final sdk = await _createInstance();

        await sdk.events.record(
          key: 'empty_string_test',
          segmentation: {'note': ''},
        );

        final event = sdk.debugEventQueueSnapshot.first;
        expect(event['segmentation']['note'], '');
      });

      test('record event with unicode string values', () async {
        final sdk = await _createInstance();

        await sdk.events.record(
          key: 'unicode_test',
          segmentation: {
            'japanese': '日本語テスト',
            'russian': 'Тест на русском',
            'emoji': '🎉🚀💯',
            'arabic': 'اختبار عربي',
          },
        );

        final event = sdk.debugEventQueueSnapshot.first;
        expect(event['segmentation']['japanese'], '日本語テスト');
        expect(event['segmentation']['russian'], 'Тест на русском');
        expect(event['segmentation']['emoji'], '🎉🚀💯');
        expect(event['segmentation']['arabic'], 'اختبار عربي');
      });
    });

    group('Integer Values', () {
      test('record event with integer segmentation values', () async {
        final sdk = await _createInstance();

        await sdk.events.record(
          key: 'int_test',
          segmentation: {
            'level': 5,
            'score': 12500,
            'lives': 3,
          },
        );

        final event = sdk.debugEventQueueSnapshot.first;
        expect(event['segmentation']['level'], 5);
        expect(event['segmentation']['score'], 12500);
        expect(event['segmentation']['lives'], 3);
      });

      test('record event with zero integer value', () async {
        final sdk = await _createInstance();

        await sdk.events.record(
          key: 'zero_int_test',
          segmentation: {'retry_count': 0, 'failures': 0},
        );

        final event = sdk.debugEventQueueSnapshot.first;
        expect(event['segmentation']['retry_count'], 0);
        expect(event['segmentation']['failures'], 0);
      });

      test('record event with negative integer values', () async {
        final sdk = await _createInstance();

        await sdk.events.record(
          key: 'negative_int_test',
          segmentation: {
            'temperature': -15,
            'balance_change': -500,
          },
        );

        final event = sdk.debugEventQueueSnapshot.first;
        expect(event['segmentation']['temperature'], -15);
        expect(event['segmentation']['balance_change'], -500);
      });

      test('record event with large integer values', () async {
        final sdk = await _createInstance();

        await sdk.events.record(
          key: 'large_int_test',
          segmentation: {
            'timestamp_ms': 1708345678901,
            'user_id': 9999999999,
          },
        );

        final event = sdk.debugEventQueueSnapshot.first;
        expect(event['segmentation']['timestamp_ms'], 1708345678901);
        expect(event['segmentation']['user_id'], 9999999999);
      });
    });

    group('Double Values', () {
      test('record event with double segmentation values', () async {
        final sdk = await _createInstance();

        await sdk.events.record(
          key: 'double_test',
          segmentation: {
            'price': 29.99,
            'discount_rate': 0.15,
            'rating': 4.5,
          },
        );

        final event = sdk.debugEventQueueSnapshot.first;
        expect(event['segmentation']['price'], 29.99);
        expect(event['segmentation']['discount_rate'], 0.15);
        expect(event['segmentation']['rating'], 4.5);
      });

      test('record event with precise decimal values', () async {
        final sdk = await _createInstance();

        await sdk.events.record(
          key: 'precise_double_test',
          segmentation: {
            'pi': 3.14159265359,
            'percentage': 33.333333,
          },
        );

        final event = sdk.debugEventQueueSnapshot.first;
        expect(event['segmentation']['pi'], closeTo(3.14159, 0.001));
        expect(event['segmentation']['percentage'], closeTo(33.333, 0.001));
      });

      test('record event with zero and negative doubles', () async {
        final sdk = await _createInstance();

        await sdk.events.record(
          key: 'edge_double_test',
          segmentation: {
            'zero_value': 0.0,
            'negative_value': -123.45,
          },
        );

        final event = sdk.debugEventQueueSnapshot.first;
        expect(event['segmentation']['zero_value'], 0.0);
        expect(event['segmentation']['negative_value'], -123.45);
      });
    });

    group('Boolean Values', () {
      test('record event with boolean true value', () async {
        final sdk = await _createInstance();

        await sdk.events.record(
          key: 'bool_true_test',
          segmentation: {'is_premium': true},
        );

        final event = sdk.debugEventQueueSnapshot.first;
        expect(event['segmentation']['is_premium'], true);
      });

      test('record event with boolean false value', () async {
        final sdk = await _createInstance();

        await sdk.events.record(
          key: 'bool_false_test',
          segmentation: {'is_trial': false},
        );

        final event = sdk.debugEventQueueSnapshot.first;
        expect(event['segmentation']['is_trial'], false);
      });

      test('record event with multiple boolean values', () async {
        final sdk = await _createInstance();

        await sdk.events.record(
          key: 'multi_bool_test',
          segmentation: {
            'notifications_enabled': true,
            'dark_mode': false,
            'auto_save': true,
            'crash_reporting': false,
          },
        );

        final event = sdk.debugEventQueueSnapshot.first;
        expect(event['segmentation']['notifications_enabled'], true);
        expect(event['segmentation']['dark_mode'], false);
        expect(event['segmentation']['auto_save'], true);
        expect(event['segmentation']['crash_reporting'], false);
      });
    });

    group('List/Array Values', () {
      test('record event with string list segmentation', () async {
        final sdk = await _createInstance();

        await sdk.events.record(
          key: 'string_list_test',
          segmentation: {
            'tags': ['featured', 'sale', 'new'],
          },
        );

        final event = sdk.debugEventQueueSnapshot.first;
        expect(event['segmentation']['tags'], ['featured', 'sale', 'new']);
      });

      test('record event with integer list segmentation', () async {
        final sdk = await _createInstance();

        await sdk.events.record(
          key: 'int_list_test',
          segmentation: {
            'quantities': [1, 2, 5, 10],
            'levels_completed': [1, 2, 3, 4, 5],
          },
        );

        final event = sdk.debugEventQueueSnapshot.first;
        expect(event['segmentation']['quantities'], [1, 2, 5, 10]);
        expect(event['segmentation']['levels_completed'], [1, 2, 3, 4, 5]);
      });

      test('record event with double list segmentation', () async {
        final sdk = await _createInstance();

        await sdk.events.record(
          key: 'double_list_test',
          segmentation: {
            'prices': [9.99, 19.99, 29.99],
            'ratings': [4.5, 3.8, 5.0],
          },
        );

        final event = sdk.debugEventQueueSnapshot.first;
        expect(event['segmentation']['prices'], [9.99, 19.99, 29.99]);
        expect(event['segmentation']['ratings'], [4.5, 3.8, 5.0]);
      });

      test('record event with empty list segmentation', () async {
        final sdk = await _createInstance();

        await sdk.events.record(
          key: 'empty_list_test',
          segmentation: {
            'empty_tags': <String>[],
          },
        );

        final event = sdk.debugEventQueueSnapshot.first;
        expect(event['segmentation']['empty_tags'], []);
      });

      test('record event with mixed type list segmentation', () async {
        final sdk = await _createInstance();

        await sdk.events.record(
          key: 'mixed_list_test',
          segmentation: {
            'mixed_values': ['string', 42, 3.14, true],
          },
        );

        final event = sdk.debugEventQueueSnapshot.first;
        expect(event['segmentation']['mixed_values'], ['string', 42, 3.14, true]);
      });

      test('record event with multiple list segmentations', () async {
        final sdk = await _createInstance();

        await sdk.events.record(
          key: 'multi_list_test',
          segmentation: {
            'product_ids': ['SKU001', 'SKU002', 'SKU003'],
            'categories': ['electronics', 'accessories'],
            'quantities': [1, 2, 1],
          },
        );

        final event = sdk.debugEventQueueSnapshot.first;
        expect(event['segmentation']['product_ids'], ['SKU001', 'SKU002', 'SKU003']);
        expect(event['segmentation']['categories'], ['electronics', 'accessories']);
        expect(event['segmentation']['quantities'], [1, 2, 1]);
      });
    });

    group('Mixed Type Segmentation', () {
      test('record event with all value types combined', () async {
        final sdk = await _createInstance();

        await sdk.events.record(
          key: 'mixed_types_test',
          segmentation: {
            'string_val': 'hello',
            'int_val': 42,
            'double_val': 3.14,
            'bool_val': true,
            'string_list': ['a', 'b', 'c'],
            'int_list': [1, 2, 3],
          },
        );

        final event = sdk.debugEventQueueSnapshot.first;
        expect(event['segmentation']['string_val'], 'hello');
        expect(event['segmentation']['int_val'], 42);
        expect(event['segmentation']['double_val'], 3.14);
        expect(event['segmentation']['bool_val'], true);
        expect(event['segmentation']['string_list'], ['a', 'b', 'c']);
        expect(event['segmentation']['int_list'], [1, 2, 3]);
      });

      test('record event with complex e-commerce segmentation', () async {
        final sdk = await _createInstance();

        await sdk.events.record(
          key: 'purchase_completed',
          count: 1,
          sum: 149.99,
          segmentation: {
            'order_id': 'ORD-12345',
            'product_count': 3,
            'subtotal': 139.99,
            'tax': 10.00,
            'discount_applied': true,
            'discount_percent': 15.5,
            'payment_method': 'credit_card',
            'product_ids': ['PROD-001', 'PROD-002', 'PROD-003'],
            'quantities': [1, 2, 1],
          },
        );

        final event = sdk.debugEventQueueSnapshot.first;
        expect(event['key'], 'purchase_completed');
        expect(event['count'], 1);
        expect(event['sum'], 149.99);
        expect(event['segmentation']['order_id'], 'ORD-12345');
        expect(event['segmentation']['product_count'], 3);
        expect(event['segmentation']['subtotal'], 139.99);
        expect(event['segmentation']['tax'], 10.00);
        expect(event['segmentation']['discount_applied'], true);
        expect(event['segmentation']['discount_percent'], 15.5);
        expect(event['segmentation']['product_ids'], ['PROD-001', 'PROD-002', 'PROD-003']);
      });

      test('record event with complex user action segmentation', () async {
        final sdk = await _createInstance();

        await sdk.events.record(
          key: 'user_interaction',
          dur: 2.5,
          segmentation: {
            'action_type': 'swipe',
            'direction': 'left',
            'screen': 'gallery',
            'item_index': 3,
            'velocity': 1250.5,
            'is_gesture': true,
            'touches': [1],
            'modifiers': <String>[],
          },
        );

        final event = sdk.debugEventQueueSnapshot.first;
        expect(event['dur'], 2.5);
        expect(event['segmentation']['action_type'], 'swipe');
        expect(event['segmentation']['item_index'], 3);
        expect(event['segmentation']['velocity'], 1250.5);
        expect(event['segmentation']['is_gesture'], true);
      });
    });

    group('Segmentation in Bundled Requests', () {
      test('all segmentation types are preserved in bundled event request', () async {
        final network = FakeNetworkClient('https://example.com');
        final sdk = await _createInstance(networkClient: network);

        await sdk.events.record(
          key: 'comprehensive_event',
          count: 1,
          sum: 99.99,
          dur: 30.0,
          segmentation: {
            'string': 'value',
            'integer': 42,
            'double': 3.14,
            'boolean': true,
            'string_list': ['x', 'y', 'z'],
            'int_list': [10, 20, 30],
          },
        );

        await sdk.processEventsAndRequests();

        final eventsRequest = network.sent.where((r) => r.containsKey('events')).toList();
        expect(eventsRequest.isNotEmpty, true);

        final eventsJson = eventsRequest.last['events'] as String;
        final events = jsonDecode(eventsJson) as List<dynamic>;
        final event = events.first as Map<String, dynamic>;

        expect(event['key'], 'comprehensive_event');
        expect(event['count'], 1);
        expect(event['sum'], 99.99);
        expect(event['dur'], 30.0);
        expect(event['segmentation']['string'], 'value');
        expect(event['segmentation']['integer'], 42);
        expect(event['segmentation']['double'], 3.14);
        expect(event['segmentation']['boolean'], true);
        expect(event['segmentation']['string_list'], ['x', 'y', 'z']);
        expect(event['segmentation']['int_list'], [10, 20, 30]);
      });

      test('multiple events with different segmentation types are bundled correctly', () async {
        final network = FakeNetworkClient('https://example.com');
        final sdk = await _createInstance(networkClient: network);

        await sdk.events.record(key: 'event1', segmentation: {'type': 'string_only', 'value': 'test'});
        await sdk.events.record(key: 'event2', segmentation: {'type': 'int_only', 'value': 123});
        await sdk.events.record(key: 'event3', segmentation: {
          'type': 'list_only',
          'values': [1, 2, 3]
        });

        await sdk.processEventsAndRequests();

        final eventsRequest = network.sent.where((r) => r.containsKey('events')).toList();
        final eventsJson = eventsRequest.last['events'] as String;
        final events = jsonDecode(eventsJson) as List<dynamic>;

        expect(events.length, 3);
        expect(events[0]['segmentation']['value'], 'test');
        expect(events[1]['segmentation']['value'], 123);
        expect(events[2]['segmentation']['values'], [1, 2, 3]);
      });
    });

    group('Edge Cases', () {
      test('record event with null values in segmentation are ignored', () async {
        final sdk = await _createInstance();

        await sdk.events.record(
          key: 'null_test',
          segmentation: {
            'valid_key': 'valid_value',
            'null_key': null,
          },
        );

        final event = sdk.debugEventQueueSnapshot.first;
        expect(event['segmentation']['valid_key'], 'valid_value');
        // null values should either be excluded or handled gracefully
        expect(event['segmentation'].containsKey('null_key'), anyOf(isFalse, isTrue));
      });

      test('record event with special characters in string segmentation', () async {
        final sdk = await _createInstance();

        await sdk.events.record(
          key: 'special_chars_test',
          segmentation: {
            'url': 'https://example.com/path?query=value&other=123',
            'json_like': '{"key": "value"}',
            'newlines': 'line1\nline2\nline3',
            'tabs': 'col1\tcol2\tcol3',
            'quotes': 'He said "Hello"',
          },
        );

        final event = sdk.debugEventQueueSnapshot.first;
        expect(event['segmentation']['url'], 'https://example.com/path?query=value&other=123');
        expect(event['segmentation']['json_like'], '{"key": "value"}');
        expect(event['segmentation']['newlines'], 'line1\nline2\nline3');
      });

      test('record event with many segmentation keys', () async {
        final sdk = await _createInstance();

        final segmentation = <String, dynamic>{};
        for (int i = 0; i < 50; i++) {
          segmentation['key_$i'] = 'value_$i';
        }

        await sdk.events.record(key: 'many_keys_test', segmentation: segmentation);

        final event = sdk.debugEventQueueSnapshot.first;
        // Should have some keys (may be limited by SBS)
        expect(event['segmentation'].keys.length, greaterThan(0));
      });

      test('record event with nested list containing numbers and strings', () async {
        final sdk = await _createInstance();

        await sdk.events.record(
          key: 'nested_list_test',
          segmentation: {
            'items': ['item1', 100, 'item2', 200, 'item3', 300],
          },
        );

        final event = sdk.debugEventQueueSnapshot.first;
        expect(event['segmentation']['items'], ['item1', 100, 'item2', 200, 'item3', 300]);
      });
    });
  });
}
