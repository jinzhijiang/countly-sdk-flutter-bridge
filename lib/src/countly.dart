import 'package:countly_sdk_dart_core/countly_sdk_dart_core.dart' as core;

import 'flutter_environment.dart';

class Countly {
  static const sdkName = 'countly-sdk-flutter-lite';
  static const sdkVersion = '26.1.0';

  static core.CountlyInstance? get defaultInstance => core.Countly.defaultInstance;

  static core.CountlyInstance? instance(String instanceKey) => core.Countly.instance(instanceKey);

  static Future<core.CountlyInstance> init(core.CountlyConfig config, {String instanceKey = 'default'}) {
    final flutterConfig = config.copyWith(storageMode: config.storageMode ?? core.StorageMode.persistent, platformEnvironment: buildFlutterPlatformEnvironment(), sdkNameOverride: sdkName, sdkVersionOverride: sdkVersion);
    return core.Countly.init(flutterConfig, instanceKey: instanceKey);
  }

  static Future<void> disposeInstance(String instanceKey) => core.Countly.disposeInstance(instanceKey);

  static Future<void> disposeAll() => core.Countly.disposeAll();
}
