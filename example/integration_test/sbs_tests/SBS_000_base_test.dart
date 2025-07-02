import 'dart:convert';
import 'dart:io';

import 'package:countly_flutter/countly_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../utils.dart';
import 'sbs_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('SBS_000_base', (WidgetTester tester) async {
    int serverDelay = 0;
    List<Map<String, List<String>>> requestArray = <Map<String, List<String>>>[];
    createServer(requestArray, customHandler: (request, queryParams, response) async {
      Map<String, Object> responseJson = {'result': 'Success'};
      if (queryParams.containsKey('method') && queryParams['method']!.first == 'feedback') {
        responseJson = {'result': []};
      }

      if (serverDelay > 0 && !queryParams.containsKey('events')) {
        // this orientation check for avoiding delay on backoff check
        // to validate end session sent after 60 seconds
        await Future.delayed(Duration(seconds: serverDelay));
      }

      response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..headers.set('Access-Control-Allow-Origin', '*')
        ..write(jsonEncode(responseJson));
    });
    // Initialize the SDK
    CountlyConfig config = CountlyConfig('http://0.0.0.0:8080', APP_KEY).enableManualSessionHandling().setLoggingEnabled(true);
    await Countly.initWithConfig(config);

    await callAllFeatures();

    print(requestArray);
    List<String> RQ = await getRequestQueue();
    List<String> EQ = await getEventQueue();
    expect(RQ.length, 0);
    expect(EQ.length, 0);
    validateRequestCounts({'events': 2, 'location': 1, 'crash': 2, 'begin_session': 1, 'end_session': 1, 'session_duration': 2, 'apm': 2, 'user_details': 1}, requestArray);
    validateInternalEventCounts({'orientation': 1, 'view': 6}, requestArray);
    validateImmediateCounts({'hc': 1, 'sc': 1, 'feedback': 1, 'queue': 2, 'ab': 1, 'ab_opt_out': 1, 'rc': 1}, requestArray);

    await Countly.instance.content.exitContentZone();
    requestArray.clear();

    serverDelay = 11;

    await Countly.instance.sessions.beginSession();
    await Countly.instance.sessions.endSession(); // this will be backed off for 60 seconds
    await Countly.instance.attemptToSendStoredRequests();

    validateRequestCounts({'begin_session': 1}, requestArray);
    await Countly.instance.attemptToSendStoredRequests(); // this will not take effect
    expect(requestArray.length, 1);

    await Future.delayed(const Duration(seconds: 75));
    validateRequestCounts({'begin_session': 1, 'end_session': 1}, requestArray);
  });
}
