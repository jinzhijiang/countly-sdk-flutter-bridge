import 'package:countly_flutter/countly_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../utils.dart';
import 'sbs_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('SBS_200A_test', (WidgetTester tester) async {
    List<Map<String, List<String>>> requestArray = <Map<String, List<String>>>[];
    createServerWithConfig(requestArray, {
      'v': 1,
      't': 1750748806695,
      'c': {'lkl': 5, 'lvs': 5, 'lsv': 5, 'lbc': 5, 'ltlpt': 5, 'ltl': 5, 'rcz': false, 'ecz': true, 'czi': 16, 'bom': false}
    });

    // Initialize the SDK
    CountlyConfig config = CountlyConfig('http://0.0.0.0:8080', APP_KEY).enableManualSessionHandling().setLoggingEnabled(true);

    await Countly.initWithConfig(config);
    await Future.delayed(const Duration(seconds: 2));

    await callAllFeatures(disableEnterContent: true);

    validateRequestCounts({'events': 2, 'location': 1, 'crash': 2, 'begin_session': 1, 'end_session': 1, 'session_duration': 2, 'apm': 2, 'user_details': 1, 'consent': 0}, requestArray);
    validateInternalEventCounts({'orientation': 1, 'view': 6}, requestArray);
    // enter content zone is not called, but a content zone request is sent it is because server config is set cz to true
    validateImmediateCounts({'hc': 1, 'sc': 1, 'feedback': 1, 'queue': 2, 'ab': 1, 'ab_opt_out': 1, 'rc': 1}, requestArray);

    // VALIDATE INTERNAL LIMITS

    await Countly.instance.content.refreshContentZone(); // this will not affect because refresh disabled
    validateImmediateCounts({'hc': 1, 'sc': 1, 'feedback': 1, 'queue': 2, 'ab': 1, 'ab_opt_out': 1, 'rc': 1}, requestArray);

    await Countly.instance.content.exitContentZone();
    requestArray.clear();

    sbsServerDelay = 11;

    await Countly.instance.sessions.beginSession();
    await Countly.instance.sessions.endSession(); // this will not be backed off because backoff disabled
    await Future.delayed(const Duration(seconds: 10)); // wait for sdk to process and get the result from server

    await Countly.instance.attemptToSendStoredRequests(); // this will take affect and trigger sending the requests
    await Future.delayed(const Duration(seconds: 2));

    validateRequestCounts({'begin_session': 1, 'end_session': 1}, requestArray);
    expect(await getServerConfig(), {
      'v': 1,
      't': 1750748806695,
      'c': {'lkl': 5, 'lvs': 5, 'lsv': 5, 'lbc': 5, 'ltlpt': 5, 'ltl': 5, 'rcz': false, 'ecz': true, 'czi': 16, 'bom': false}
    });
  });
}
