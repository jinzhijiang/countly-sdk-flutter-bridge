import 'package:countly_sdk_dart_core/countly_sdk_dart_core.dart';
// ignore: implementation_imports
import 'package:countly_sdk_dart_core/src/migration/legacy_native_types.dart';
import 'package:flutter/services.dart';

class FlutterLegacyMigrationAdapter implements CountlyLegacyMigrationAdapter {
  const FlutterLegacyMigrationAdapter();

  static const MethodChannel _channel = MethodChannel('countly_flutter_lite/migration');

  @override
  Future<void> clearAndroidLegacyData() async {
    try {
      await _channel.invokeMethod('clearAndroidLegacyData');
    } catch (_) {}
  }

  @override
  Future<void> clearIOSLegacyData() async {
    try {
      await _channel.invokeMethod('clearIOSLegacyData');
    } catch (_) {}
  }

  @override
  Future<LegacyNativeData?> fetchLegacyData() async {
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>?>('getLegacyData');
      if (raw == null || raw.isEmpty) return null;
      final androidMap = raw['android'];
      final iosMap = raw['ios'];
      final android = androidMap is Map ? LegacyAndroidData.fromMap(androidMap) : null;
      final ios = iosMap is Map ? LegacyIOSData.fromMap(iosMap) : null;
      final data = LegacyNativeData(android: android, ios: ios);
      return data.hasAny ? data : null;
    } catch (_) {
      return null;
    }
  }
}
