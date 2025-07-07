import 'dart:convert';

import 'package:countly_flutter/countly_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../../event_tests/event_utils.dart';
import '../../utils.dart';

/// Test records an event with a key and segmentation values that exceeds the maximum key length set by the SDK's internal limits server SBS limit.
/// - Key length limit is 3 and value size is 5 on DP
/// - Only key length in P is 8
/// - The event is recorded with the key truncated to 8 #P
/// - Values in segmentation are truncated to 5 characters #DP
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('SBS_201B_DP_P_test', (WidgetTester tester) async {
    List<Map<String, List<String>>> requestArray = <Map<String, List<String>>>[];
    createServer(requestArray);

    // Initialize the SDK
    CountlyConfig config = CountlyConfig('http://0.0.0.0:8080', APP_KEY).enableManualSessionHandling().setLoggingEnabled(true);
    config.setSDKBehaviorSettings('{"v":1,"t":1750748806695,"c":{"lkl":8}}');
    config.sdkInternalLimits.setMaxKeyLength(3).setMaxValueSize(5);

    await Countly.initWithConfig(config);
    await Future.delayed(const Duration(seconds: 2));

    await Countly.instance.events.recordEvent('ThisWillCLIPPED_BY_FS', {'no1': 'valueCLIPPED_BY_DP', 'no2': 'valueCLIPPED_BY_DP', 'no3': 'valueCLIPPED_BY_DP'});
    List<String> rq = await getRequestQueue();
    List<String> eq = await getEventQueue();
    expect(rq.length, 0);
    expect(eq.length, 1);

    validateEvent(event: jsonDecode(eq.first), key: 'ThisWill', segmentation: {'no1': 'value', 'no2': 'value', 'no3': 'value'});

    expect(await getServerConfig(), {
      'v': 1,
      't': 1750748806695,
      'c': {'lkl': 8}
    });
  });
}
