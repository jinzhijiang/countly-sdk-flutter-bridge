import 'dart:io';

import 'package:countly_flutter/countly_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../utils.dart';
import 'sbs_utils.dart';

///This test calls all features possible
///It is base test, tries to show how features working without SBS and defaults
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('SBS_200D_test', (WidgetTester tester) async {
    List<Map<String, List<String>>> requestArray = <Map<String, List<String>>>[];
    createServerWithConfig(requestArray, {
      'v': 1,
      't': 1750748806695,
      'c': {'st': false, 'cet': false, 'vt': false, 'eqs': 5, 'lt': false, 'crt': false, 'bom_at': 5, 'bom_d': 30, 'bom_rqp': 0.01, 'bom_ra': 1}
    });
    // Initialize the SDK
    CountlyConfig config = CountlyConfig('http://0.0.0.0:8080', APP_KEY).enableManualSessionHandling().setLoggingEnabled(true);
    await Countly.initWithConfig(config);

    await callAllFeatures();

    List<String> RQ = await getRequestQueue();
    List<String> EQ = await getEventQueue();
    expect(RQ.length, 0);
    expect(EQ.length, 0);
    validateRequestCounts({'events': Platform.isIOS ? 2 : 1, 'location': 1, 'crash': 0, 'begin_session': 0, 'consent': 0, 'end_session': 0, 'session_duration': 0, 'apm': 2, 'user_details': Platform.isIOS ? 2 : 1}, requestArray);
    validateInternalEventCounts({'nps': 1}, requestArray);
    validateImmediateCounts({'hc': 1, 'sc': 1, 'feedback': 1, 'queue': 2, 'ab': 1, 'ab_opt_out': 1, 'rc': 1}, requestArray);

    expect(await getServerConfig(), {
      'v': 1,
      't': 1750748806695,
      'c': {'st': false, 'cet': false, 'vt': false, 'eqs': 5, 'lt': false, 'crt': false, 'bom_at': 5, 'bom_d': 30, 'bom_rqp': 0.01, 'bom_ra': 1}
    });
  });
}
