/// This class holds content features specific configurations to be used with CountlyConfig class and serves as an interface.
/// You can chain multiple configurations.
import '../content_builder.dart';

class CountlyConfigContent {
  /// private variables.
  ContentCallback? _contentCallback;
  int? _zoneTimerInterval;

  /// getters
  ContentCallback? get contentCallback => _contentCallback;
  int? get zoneTimerInterval => _zoneTimerInterval;

  /// setters / methods

  ///  This is an experimental feature and it can have breaking changes
  //   Register global completion blocks to be executed on content.
  CountlyConfigContent setGlobalContentCallback(ContentCallback callback) {
    _contentCallback = callback;
    return this;
  }

  /// This is an experimental feature and it can have breaking changes
  /// Set the interval for the automatic content update calls
  ///
  /// zoneTimerIntervalSeconds in seconds
  CountlyConfigContent setZoneTimerInterval(int interval) {
    _zoneTimerInterval = interval;
    return this;
  }
}
