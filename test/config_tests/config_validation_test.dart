import 'package:countly_flutter_lite/countly_flutter_lite.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CountlyConfig Validation - appKey', () {
    test('throws ArgumentError when appKey is empty', () {
      expect(() => CountlyConfig(appKey: '', serverUrl: 'https://example.com'), throwsA(isA<ArgumentError>().having((e) => e.message, 'message', 'app_key cannot be empty')));
    });

    test('accepts non-empty appKey', () {
      expect(() => CountlyConfig(appKey: 'valid-app-key', serverUrl: 'https://example.com'), returnsNormally);
    });
    test('accepts trimmed appKey', () {
      expect(() => CountlyConfig(appKey: '  valid-app-key  ', serverUrl: 'https://example.com'), returnsNormally);
    });

    test('accepts appKey with whitespace only characters', () {
      // Note: The SDK currently only checks for empty string, not whitespace-only
      expect(() => CountlyConfig(appKey: '   ', serverUrl: 'https://example.com'), throwsA(isA<ArgumentError>().having((e) => e.message, 'message', 'app_key cannot be empty')));
    });
  });

  group('CountlyConfig Validation - serverUrl', () {
    test('throws ArgumentError when serverUrl is empty', () {
      expect(() => CountlyConfig(appKey: 'test-key', serverUrl: ''), throwsA(isA<ArgumentError>().having((e) => e.message, 'message', 'server_url cannot be empty')));
    });

    test('throws ArgumentError when serverUrl does not start with http:// or https://', () {
      expect(() => CountlyConfig(appKey: 'test-key', serverUrl: 'example.com'), throwsA(isA<ArgumentError>().having((e) => e.message, 'message', 'server_url must start with http:// or https://')));
    });

    test('throws ArgumentError for ftp:// protocol', () {
      expect(() => CountlyConfig(appKey: 'test-key', serverUrl: 'ftp://example.com'), throwsA(isA<ArgumentError>().having((e) => e.message, 'message', 'server_url must start with http:// or https://')));
    });

    test('throws ArgumentError for ws:// protocol', () {
      expect(() => CountlyConfig(appKey: 'test-key', serverUrl: 'ws://example.com'), throwsA(isA<ArgumentError>().having((e) => e.message, 'message', 'server_url must start with http:// or https://')));
    });

    test('accepts serverUrl starting with http://', () {
      expect(() => CountlyConfig(appKey: 'test-key', serverUrl: 'http://example.com'), returnsNormally);
    });

    test('accepts serverUrl starting with https://', () {
      expect(() => CountlyConfig(appKey: 'test-key', serverUrl: 'https://example.com'), returnsNormally);
    });

    test('accepts serverUrl with trailing slashes (they get normalized)', () {
      final config = CountlyConfig(appKey: 'test-key', serverUrl: 'https://example.com///');
      expect(config.serverUrl, 'https://example.com');
    });
  });

  group('CountlyConfig Validation - customRequestHeaders', () {
    test('throws ArgumentError when header name is empty', () {
      expect(() => CountlyConfig(appKey: 'test-key', serverUrl: 'https://example.com', customRequestHeaders: {'': 'value'}), throwsA(isA<ArgumentError>().having((e) => e.message, 'message', 'customRequestHeaders contains empty header name')));
    });

    test('throws ArgumentError when header name is whitespace only', () {
      expect(() => CountlyConfig(appKey: 'test-key', serverUrl: 'https://example.com', customRequestHeaders: {'   ': 'value'}), throwsA(isA<ArgumentError>().having((e) => e.message, 'message', 'customRequestHeaders contains empty header name')));
    });

    test('throws ArgumentError when header value is empty', () {
      expect(() => CountlyConfig(appKey: 'test-key', serverUrl: 'https://example.com', customRequestHeaders: {'X-Custom-Header': ''}), throwsA(isA<ArgumentError>().having((e) => e.message, 'message', 'customRequestHeaders header [X-Custom-Header] has empty value')));
    });

    test('throws ArgumentError when header value is whitespace only', () {
      expect(() => CountlyConfig(appKey: 'test-key', serverUrl: 'https://example.com', customRequestHeaders: {'X-Custom-Header': '   '}), throwsA(isA<ArgumentError>().having((e) => e.message, 'message', 'customRequestHeaders header [X-Custom-Header] has empty value')));
    });

    test('accepts valid customRequestHeaders', () {
      expect(() => CountlyConfig(appKey: 'test-key', serverUrl: 'https://example.com', customRequestHeaders: {'X-Custom-Header': 'custom-value', 'Authorization': 'Bearer token123'}), returnsNormally);
    });

    test('accepts null customRequestHeaders', () {
      expect(() => CountlyConfig(appKey: 'test-key', serverUrl: 'https://example.com', customRequestHeaders: null), returnsNormally);
    });

    test('accepts empty customRequestHeaders map', () {
      expect(() => CountlyConfig(appKey: 'test-key', serverUrl: 'https://example.com', customRequestHeaders: {}), returnsNormally);
    });

    test('validates all headers - fails on second invalid header', () {
      expect(() => CountlyConfig(appKey: 'test-key', serverUrl: 'https://example.com', customRequestHeaders: {'Valid-Header': 'valid-value', 'Another-Header': '   '}), throwsA(isA<ArgumentError>().having((e) => e.message, 'message', 'customRequestHeaders header [Another-Header] has empty value')));
    });
  });

  group('CountlyConfig - Combined Validation Scenarios', () {
    test('validates appKey before serverUrl', () {
      // When both are invalid, appKey error should be thrown first
      expect(() => CountlyConfig(appKey: '', serverUrl: ''), throwsA(isA<ArgumentError>().having((e) => e.message, 'message', 'app_key cannot be empty')));
    });

    test('validates serverUrl emptiness before protocol check', () {
      // Empty serverUrl should throw "cannot be empty" not "must start with http"
      expect(() => CountlyConfig(appKey: 'test-key', serverUrl: ''), throwsA(isA<ArgumentError>().having((e) => e.message, 'message', 'server_url cannot be empty')));
    });

    test('validates serverUrl protocol after required params', () {
      expect(() => CountlyConfig(appKey: 'valid-key', serverUrl: 'invalid-url'), throwsA(isA<ArgumentError>().having((e) => e.message, 'message', 'server_url must start with http:// or https://')));
    });

    test('validates customRequestHeaders after serverUrl', () {
      // With valid appKey and serverUrl but invalid headers
      expect(() => CountlyConfig(appKey: 'valid-key', serverUrl: 'https://example.com', customRequestHeaders: {'': 'value'}), throwsA(isA<ArgumentError>().having((e) => e.message, 'message', 'customRequestHeaders contains empty header name')));
    });
  });

  group('CountlyConfig - enableVisualWarnings', () {
    test('defaults to false', () {
      final config = CountlyConfig(appKey: 'test-key', serverUrl: 'https://example.com');
      expect(config.enableVisualWarnings, false);
    });

    test('can be set to true', () {
      final config = CountlyConfig(appKey: 'test-key', serverUrl: 'https://example.com', enableVisualWarnings: true);
      expect(config.enableVisualWarnings, true);
    });

    test('can be explicitly set to false', () {
      final config = CountlyConfig(appKey: 'test-key', serverUrl: 'https://example.com', enableVisualWarnings: false);
      expect(config.enableVisualWarnings, false);
    });
  });

  group('CountlyConfig - storageMode', () {
    test('defaults to null (unspecified)', () {
      final config = CountlyConfig(appKey: 'test-key', serverUrl: 'https://example.com');
      expect(config.storageMode, isNull);
    });

    test('can be explicitly set to memory', () {
      final config = CountlyConfig(appKey: 'test-key', serverUrl: 'https://example.com', storageMode: StorageMode.memory);
      expect(config.storageMode, StorageMode.memory);
    });

    test('can be explicitly set to persistent', () {
      final config = CountlyConfig(appKey: 'test-key', serverUrl: 'https://example.com', storageMode: StorageMode.persistent);
      expect(config.storageMode, StorageMode.persistent);
    });
  });
}
