import 'package:countly_sdk_dart_core/countly_sdk_dart_core.dart' hide Countly;

import 'countly.dart';

class CountlyFlutter {
  static Future<CountlyInstance> init(CountlyConfig config, {String instanceKey = 'default'}) => Countly.init(config, instanceKey: instanceKey);
}
