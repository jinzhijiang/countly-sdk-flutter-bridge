import 'dart:convert';

import 'package:countly_flutter_lite/countly.dart';
import 'package:countly_sdk_dart_core/src/constants.dart';
import 'package:countly_sdk_dart_core/src/migration/legacy_native_types.dart';
import 'package:countly_sdk_dart_core/src/logging/logging_helper.dart';
import 'package:countly_sdk_dart_core/src/migration/migration.dart';
import 'package:countly_sdk_dart_core/src/storage/storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// A simple SdkLogger that captures all logs for testing purposes.
class CapturingSdkLogger implements SdkLogger {
  final List<String> logs = [];

  @override
  bool isEnabled(LogLevel level) => true;

  @override
  void log(LogLevel level, String message, {Object? error, StackTrace? stack}) {
    logs.add('[${level.name}] $message');
  }

  bool hasLogContaining(String substring) => logs.any((l) => l.contains(substring));
}

/// Test logger that wraps InstanceLogger and captures logs.
class TestLogger extends InstanceLogger {
  final CapturingSdkLogger capturer;

  TestLogger._internal(this.capturer)
      : super(capturer,
            enabled: true,
            enableVisualWarnings: false,
            warningPresenter: const NoOpWarningPresenter(),
            instanceKey: 'test');

  factory TestLogger() {
    final capturer = CapturingSdkLogger();
    return TestLogger._internal(capturer);
  }

  List<String> get logs => capturer.logs;

  bool hasLogContaining(String substring) => capturer.hasLogContaining(substring);
}

/// Android legacy storage keys (matching CountlyStore.java)
class AndroidLegacyKeys {
  static const requestQueue = 'CONNECTIONS';
  static const eventQueue = 'EVENTS';
  static const deviceId = 'ly.count.android.api.DeviceId.id';
  static const deviceIdType = 'ly.count.android.api.DeviceId.type';
  static const remoteConfig = 'REMOTE_CONFIG';
  static const serverConfig = 'SERVER_CONFIG';
  static const schemaVersion = 'SCHEMA_VERSION';
  static const delimiter = ':::';
}

/// iOS legacy storage keys (matching CountlyPersistency.m)
class IOSLegacyKeys {
  static const deviceId = 'kCountlyStoredDeviceIDKey';
  static const nsuuid = 'kCountlyStoredNSUUIDKey';
  static const isCustomDeviceId = 'kCountlyIsCustomDeviceIDKey';
  static const remoteConfig = 'kCountlyRemoteConfigKey';
  static const serverConfig = 'kCountlyServerConfigPersistencyKey';
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

class FakeLegacyNativeBridge implements CountlyLegacyMigrationAdapter {
  final LegacyNativeData? data;

  FakeLegacyNativeBridge(this.data);

  @override
  Future<LegacyNativeData?> fetchLegacyData() async => data;

  @override
  Future<void> clearAndroidLegacyData() async {}

  @override
  Future<void> clearIOSLegacyData() async {}
}

StorageFacade createTestStorage(Map<String, String> backing) {
  final config = CountlyConfig(
    appKey: 'test',
    serverUrl: 'https://test.com',
    storageMethods: MemoryBackedStorage(backing).toMethods(),
  );
  return StorageFacade(config, '');
}

void main() {
  group('Migration disabled', () {
    test('does nothing when migration is disabled', () async {
      final backing = <String, String>{
        AndroidLegacyKeys.deviceId: 'android-device-123',
      };
      final storage = createTestStorage(backing);
      final logger = TestLogger();
      final migration = MigrationService(storage, enabled: false, L: logger);

      await migration.migrateIfNeeded();

      // Android legacy key should still exist
      expect(backing[AndroidLegacyKeys.deviceId], 'android-device-123');
      // New key should not exist
      expect(backing[StorageSubKeys.deviceId], isNull);
      expect(logger.hasLogContaining('disabled'), isTrue);
    });
  });

  group('Migration skipped when new data exists', () {
    test('skips migration if new SDK device ID already exists', () async {
      final backing = <String, String>{
        StorageSubKeys.deviceId: 'existing-new-id',
        AndroidLegacyKeys.deviceId: 'android-device-123',
      };
      final storage = createTestStorage(backing);
      final logger = TestLogger();
      final migration = MigrationService(storage, enabled: true, L: logger);

      await migration.migrateIfNeeded();

      // New device ID unchanged
      expect(backing[StorageSubKeys.deviceId], 'existing-new-id');
      // Android legacy data should NOT be cleaned up (migration was skipped)
      expect(backing[AndroidLegacyKeys.deviceId], 'android-device-123');
      expect(logger.hasLogContaining('already present'), isTrue);
    });
  });

  group('Android migration', () {
    test('migrates device ID from Android legacy key', () async {
      final backing = <String, String>{
        AndroidLegacyKeys.deviceId: 'android-device-abc',
      };
      final storage = createTestStorage(backing);
      final logger = TestLogger();
      final migration = MigrationService(storage, enabled: true, L: logger);

      await migration.migrateIfNeeded();

      expect(backing[StorageSubKeys.deviceId], 'android-device-abc');
      // Legacy key should be cleaned up
      expect(backing[AndroidLegacyKeys.deviceId], isNull);
      expect(logger.hasLogContaining('migration(Android): completed successfully'), isTrue);
    });

    test('migrates device ID type DEVELOPER_SUPPLIED as provided', () async {
      final backing = <String, String>{
        AndroidLegacyKeys.deviceId: 'custom-id',
        AndroidLegacyKeys.deviceIdType: 'DEVELOPER_SUPPLIED',
      };
      final storage = createTestStorage(backing);
      final migration = MigrationService(storage, enabled: true);

      await migration.migrateIfNeeded();

      expect(backing[StorageSubKeys.deviceId], 'custom-id');
      expect(backing[StorageSubKeys.deviceIdType], DeviceIdType.provided.toString());
    });

    test('migrates request queue with multiple items', () async {
      final requests = ['request1=value1', 'request2=value2', 'request3=value3'];
      final backing = <String, String>{
        AndroidLegacyKeys.deviceId: 'device-123',
        AndroidLegacyKeys.requestQueue: requests.join(AndroidLegacyKeys.delimiter),
      };
      final storage = createTestStorage(backing);
      final logger = TestLogger();
      final migration = MigrationService(storage, enabled: true, L: logger);

      await migration.migrateIfNeeded();

      final migratedRq = backing[StorageSubKeys.requestQueue];
      expect(migratedRq, isNotNull);
      final decoded = jsonDecode(migratedRq!) as List;
      expect(decoded.length, 3);
      expect(decoded[0], 'request1=value1');
      expect(decoded[1], 'request2=value2');
      expect(decoded[2], 'request3=value3');
      // Legacy key cleaned up
      expect(backing[AndroidLegacyKeys.requestQueue], isNull);
    });

    test('handles empty request queue', () async {
      final backing = <String, String>{
        AndroidLegacyKeys.deviceId: 'device-123',
        AndroidLegacyKeys.requestQueue: '',
      };
      final storage = createTestStorage(backing);
      final migration = MigrationService(storage, enabled: true);

      await migration.migrateIfNeeded();

      // No request queue should be written
      expect(backing[StorageSubKeys.requestQueue], isNull);
    });

    test('migrates event queue with valid JSON events', () async {
      final event1 = jsonEncode({'key': 'event1', 'count': 1, 'timestamp': 12345});
      final event2 = jsonEncode({
        'key': 'event2',
        'count': 2,
        'segmentation': {'a': 'b'}
      });
      final backing = <String, String>{
        AndroidLegacyKeys.deviceId: 'device-123',
        AndroidLegacyKeys.eventQueue: '$event1${AndroidLegacyKeys.delimiter}$event2',
      };
      final storage = createTestStorage(backing);
      final migration = MigrationService(storage, enabled: true);

      await migration.migrateIfNeeded();

      final migratedEq = backing[StorageSubKeys.eventQueue];
      expect(migratedEq, isNotNull);
      final decoded = jsonDecode(migratedEq!) as List;
      expect(decoded.length, 2);
      expect(decoded[0]['key'], 'event1');
      expect(decoded[1]['key'], 'event2');
      expect(decoded[1]['segmentation'], {'a': 'b'});
    });

    test('migrates event queue as legacy request when legacy request envelope exists', () async {
      final legacyBeginSession =
          'app_key=old-app-key&device_id=old-device-id&sdk_version=25.4.3&sdk_name=dart-flutterbnp-android&av=0.0.1&begin_session=1';
      final event1 = jsonEncode({'key': 'event1', 'count': 1});
      final event2 = jsonEncode({'key': 'event2', 'count': 2});
      final backing = <String, String>{
        AndroidLegacyKeys.deviceId: 'old-device-id',
        AndroidLegacyKeys.requestQueue: legacyBeginSession,
        AndroidLegacyKeys.eventQueue: '$event1${AndroidLegacyKeys.delimiter}$event2',
      };
      final storage = createTestStorage(backing);
      final migration = MigrationService(storage, enabled: true);

      await migration.migrateIfNeeded();

      final migratedRq = backing[StorageSubKeys.requestQueue];
      expect(migratedRq, isNotNull);
      final decodedRq = jsonDecode(migratedRq!) as List;
      expect(decodedRq.length, 2);
      expect(decodedRq.first, legacyBeginSession);

      final wrappedEventsReq = decodedRq.last as Map<String, dynamic>;
      expect(wrappedEventsReq['app_key'], 'old-app-key');
      expect(wrappedEventsReq['device_id'], 'old-device-id');
      expect(wrappedEventsReq['sdk_version'], '25.4.3');
      expect(wrappedEventsReq['sdk_name'], 'dart-flutterbnp-android');
      expect(wrappedEventsReq['av'], '0.0.1');
      final wrappedEvents = (wrappedEventsReq['events'] as List).cast<Map<String, dynamic>>();
      expect(wrappedEvents.length, 2);
      expect(wrappedEvents[0]['key'], 'event1');
      expect(wrappedEvents[1]['key'], 'event2');

      // Event queue should not be used when wrapping to legacy request queue is possible.
      expect(backing[StorageSubKeys.eventQueue], isNull);
    });

    test('skips invalid JSON in event queue but continues with valid ones', () async {
      final validEvent = jsonEncode({'key': 'valid_event', 'count': 1});
      final invalidEvent = 'not valid json {{{';
      final backing = <String, String>{
        AndroidLegacyKeys.deviceId: 'device-123',
        AndroidLegacyKeys.eventQueue: '$validEvent${AndroidLegacyKeys.delimiter}$invalidEvent',
      };
      final storage = createTestStorage(backing);
      final logger = TestLogger();
      final migration = MigrationService(storage, enabled: true, L: logger);

      await migration.migrateIfNeeded();

      final migratedEq = backing[StorageSubKeys.eventQueue];
      expect(migratedEq, isNotNull);
      final decoded = jsonDecode(migratedEq!) as List;
      expect(decoded.length, 1);
      expect(decoded[0]['key'], 'valid_event');
      expect(logger.hasLogContaining('failed to parse event'), isTrue);
    });

    test('handles trailing and leading delimiters in request queue', () async {
      final backing = <String, String>{
        AndroidLegacyKeys.deviceId: 'device-123',
        AndroidLegacyKeys.requestQueue: ':::request1:::request2:::',
      };
      final storage = createTestStorage(backing);
      final migration = MigrationService(storage, enabled: true);

      await migration.migrateIfNeeded();

      final migratedRq = backing[StorageSubKeys.requestQueue];
      final decoded = jsonDecode(migratedRq!) as List;
      expect(decoded.length, 2);
      expect(decoded[0], 'request1');
      expect(decoded[1], 'request2');
    });

    test('cleans up all Android legacy keys after migration', () async {
      final backing = <String, String>{
        AndroidLegacyKeys.deviceId: 'device-123',
        AndroidLegacyKeys.deviceIdType: 'SDK_GENERATED',
        AndroidLegacyKeys.requestQueue: 'req1:::req2',
        AndroidLegacyKeys.eventQueue: '{"key":"e1"}',
        AndroidLegacyKeys.remoteConfig: '{"key":"value"}',
        AndroidLegacyKeys.serverConfig: '{"config":true}',
        AndroidLegacyKeys.schemaVersion: '2',
      };
      final storage = createTestStorage(backing);
      final migration = MigrationService(storage, enabled: true);

      await migration.migrateIfNeeded();

      expect(backing[AndroidLegacyKeys.deviceId], isNull);
      expect(backing[AndroidLegacyKeys.deviceIdType], isNull);
      expect(backing[AndroidLegacyKeys.requestQueue], isNull);
      expect(backing[AndroidLegacyKeys.eventQueue], isNull);
      expect(backing[AndroidLegacyKeys.remoteConfig], isNull);
      expect(backing[AndroidLegacyKeys.serverConfig], isNull);
      expect(backing[AndroidLegacyKeys.schemaVersion], isNull);
    });
  });

  group('iOS migration', () {
    test('migrates device ID from iOS kCountlyStoredDeviceIDKey', () async {
      final backing = <String, String>{
        IOSLegacyKeys.deviceId: 'ios-device-xyz',
      };
      final storage = createTestStorage(backing);
      final logger = TestLogger();
      final migration = MigrationService(storage, enabled: true, L: logger);

      await migration.migrateIfNeeded();

      expect(backing[StorageSubKeys.deviceId], 'ios-device-xyz');
      // Default type when isCustomDeviceId is not set should be generated
      expect(backing[StorageSubKeys.deviceIdType], DeviceIdType.generated.toString());
      expect(logger.hasLogContaining('migration(iOS): completed successfully'), isTrue);
    });

    test('migrates custom device ID with isCustomDeviceId = 1', () async {
      final backing = <String, String>{
        IOSLegacyKeys.deviceId: 'custom-ios-id',
        IOSLegacyKeys.isCustomDeviceId: '1',
      };
      final storage = createTestStorage(backing);
      final migration = MigrationService(storage, enabled: true);

      await migration.migrateIfNeeded();

      expect(backing[StorageSubKeys.deviceId], 'custom-ios-id');
      expect(backing[StorageSubKeys.deviceIdType], DeviceIdType.provided.toString());
    });

    test('migrates custom device ID with isCustomDeviceId = true', () async {
      final backing = <String, String>{
        IOSLegacyKeys.deviceId: 'custom-ios-id',
        IOSLegacyKeys.isCustomDeviceId: 'true',
      };
      final storage = createTestStorage(backing);
      final migration = MigrationService(storage, enabled: true);

      await migration.migrateIfNeeded();

      expect(backing[StorageSubKeys.deviceIdType], DeviceIdType.provided.toString());
    });

    test('cleans up iOS legacy keys after migration', () async {
      final backing = <String, String>{
        IOSLegacyKeys.deviceId: 'ios-device',
        IOSLegacyKeys.nsuuid: 'ios-uuid',
        IOSLegacyKeys.isCustomDeviceId: '0',
        IOSLegacyKeys.remoteConfig: '{}',
        IOSLegacyKeys.serverConfig: '{}',
      };
      final storage = createTestStorage(backing);
      final migration = MigrationService(storage, enabled: true);

      await migration.migrateIfNeeded();

      expect(backing[IOSLegacyKeys.deviceId], isNull);
      expect(backing[IOSLegacyKeys.nsuuid], isNull);
      expect(backing[IOSLegacyKeys.isCustomDeviceId], isNull);
      expect(backing[IOSLegacyKeys.remoteConfig], isNull);
      expect(backing[IOSLegacyKeys.serverConfig], isNull);
    });

    test('does nothing when no iOS data exists', () async {
      final backing = <String, String>{};
      final storage = createTestStorage(backing);
      final logger = TestLogger();
      final migration = MigrationService(storage, enabled: true, L: logger);

      await migration.migrateIfNeeded();

      expect(backing[StorageSubKeys.deviceId], isNull);
      expect(logger.hasLogContaining('no legacy iOS data found'), isTrue);
    });

    test('recorded events are migrated to event queue when no legacy requests exist', () async {
      final backing = <String, String>{};
      final storage = createTestStorage(backing);
      final nativeBridge = FakeLegacyNativeBridge(
        LegacyNativeData(
          ios: LegacyIOSData(
            deviceId: 'ios-device',
            recordedEvents: [
              {'key': 'old_event_only', 'count': 1}
            ],
            legacyAppKey: 'old-app-only-events',
          ),
        ),
      );

      final migration = MigrationService(storage, enabled: true, nativeBridge: nativeBridge);
      await migration.migrateIfNeeded();

      final migratedRq = backing[StorageSubKeys.requestQueue];
      final migratedEq = backing[StorageSubKeys.eventQueue];

      expect(migratedRq, isNull);
      expect(migratedEq, isNotNull);
      final decodedEq = jsonDecode(migratedEq!) as List<dynamic>;
      expect(decodedEq.length, 1);
      expect((decodedEq.first as Map<String, dynamic>)['key'], 'old_event_only');
    });

    test('recorded events are wrapped with legacy app key when legacy requests exist', () async {
      final backing = <String, String>{};
      final storage = createTestStorage(backing);
      final nativeBridge = FakeLegacyNativeBridge(
        LegacyNativeData(
          ios: LegacyIOSData(
            deviceId: 'ios-device',
            queuedRequests: ['app_key=old-app-only-events&device_id=old-only-events-device&begin_session=1'],
            recordedEvents: [
              {'key': 'old_event_only', 'count': 1}
            ],
            legacyAppKey: 'old-app-only-events',
          ),
        ),
      );

      final migration = MigrationService(storage, enabled: true, nativeBridge: nativeBridge);
      await migration.migrateIfNeeded();

      final migratedRq = backing[StorageSubKeys.requestQueue];
      final migratedEq = backing[StorageSubKeys.eventQueue];

      expect(migratedEq, isNull);
      expect(migratedRq, isNotNull);

      final decodedRq = jsonDecode(migratedRq!) as List<dynamic>;
      expect(decodedRq.length, 2);

      final wrappedEventsReq = decodedRq.last as Map<String, dynamic>;
      expect(wrappedEventsReq['app_key'], 'old-app-only-events');
      expect(wrappedEventsReq['device_id'], 'old-only-events-device');
      final wrappedEvents = (wrappedEventsReq['events'] as List<dynamic>).cast<Map<String, dynamic>>();
      expect(wrappedEvents.length, 1);
      expect(wrappedEvents.first['key'], 'old_event_only');
    });
  });

  group('Android vs iOS priority', () {
    test('Android migration takes priority over iOS when both exist', () async {
      final backing = <String, String>{
        AndroidLegacyKeys.deviceId: 'android-device',
        AndroidLegacyKeys.deviceIdType: 'DEVELOPER_SUPPLIED',
        IOSLegacyKeys.deviceId: 'ios-device',
        IOSLegacyKeys.isCustomDeviceId: '0',
      };
      final storage = createTestStorage(backing);
      final logger = TestLogger();
      final migration = MigrationService(storage, enabled: true, L: logger);

      await migration.migrateIfNeeded();

      // Android data should be migrated
      expect(backing[StorageSubKeys.deviceId], 'android-device');
      expect(backing[StorageSubKeys.deviceIdType], DeviceIdType.provided.toString());
      // Android keys cleaned up
      expect(backing[AndroidLegacyKeys.deviceId], isNull);
      // iOS keys should still exist (Android migration took priority and returned early)
      expect(backing[IOSLegacyKeys.deviceId], 'ios-device');
    });

    test('iOS migration runs when no Android data exists', () async {
      final backing = <String, String>{
        IOSLegacyKeys.deviceId: 'ios-only-device',
      };
      final storage = createTestStorage(backing);
      final logger = TestLogger();
      final migration = MigrationService(storage, enabled: true, L: logger);

      await migration.migrateIfNeeded();

      expect(backing[StorageSubKeys.deviceId], 'ios-only-device');
      expect(logger.hasLogContaining('migration(Android): no legacy Android data found'), isTrue);
      expect(logger.hasLogContaining('migration(iOS): completed successfully'), isTrue);
    });
  });

  group('Edge cases', () {
    test('handles empty device ID string in Android', () async {
      final backing = <String, String>{
        AndroidLegacyKeys.deviceId: '',
      };
      final storage = createTestStorage(backing);
      final logger = TestLogger();
      final migration = MigrationService(storage, enabled: true, L: logger);

      await migration.migrateIfNeeded();

      // Empty string should be treated as no data
      expect(backing[StorageSubKeys.deviceId], isNull);
      expect(logger.hasLogContaining('no legacy Android data found'), isTrue);
    });

    test('handles empty device ID string in iOS', () async {
      final backing = <String, String>{
        IOSLegacyKeys.deviceId: '',
        IOSLegacyKeys.nsuuid: '',
      };
      final storage = createTestStorage(backing);
      final logger = TestLogger();
      final migration = MigrationService(storage, enabled: true, L: logger);

      await migration.migrateIfNeeded();

      expect(backing[StorageSubKeys.deviceId], isNull);
      expect(logger.hasLogContaining('no legacy iOS data found'), isTrue);
    });

    test('unknown Android device ID type defaults to provided', () async {
      final backing = <String, String>{
        AndroidLegacyKeys.deviceId: 'device-unknown-type',
        AndroidLegacyKeys.deviceIdType: 'UNKNOWN_TYPE_XYZ',
      };
      final storage = createTestStorage(backing);
      final migration = MigrationService(storage, enabled: true);

      await migration.migrateIfNeeded();

      expect(backing[StorageSubKeys.deviceIdType], DeviceIdType.provided.toString());
    });

    test('case insensitive Android device ID type matching', () async {
      final backing = <String, String>{
        AndroidLegacyKeys.deviceId: 'device-123',
        AndroidLegacyKeys.deviceIdType: 'developer_supplied', // lowercase
      };
      final storage = createTestStorage(backing);
      final migration = MigrationService(storage, enabled: true);

      await migration.migrateIfNeeded();

      expect(backing[StorageSubKeys.deviceIdType], DeviceIdType.provided.toString());
    });

    test('iOS isCustomDeviceId = 0 means generated', () async {
      final backing = <String, String>{
        IOSLegacyKeys.deviceId: 'device-id',
        IOSLegacyKeys.isCustomDeviceId: '0',
      };
      final storage = createTestStorage(backing);
      final migration = MigrationService(storage, enabled: true);

      await migration.migrateIfNeeded();

      expect(backing[StorageSubKeys.deviceIdType], DeviceIdType.generated.toString());
    });

    test('iOS isCustomDeviceId = false string means generated', () async {
      final backing = <String, String>{
        IOSLegacyKeys.deviceId: 'device-id',
        IOSLegacyKeys.isCustomDeviceId: 'false',
      };
      final storage = createTestStorage(backing);
      final migration = MigrationService(storage, enabled: true);

      await migration.migrateIfNeeded();

      expect(backing[StorageSubKeys.deviceIdType], DeviceIdType.generated.toString());
    });
  });
}
