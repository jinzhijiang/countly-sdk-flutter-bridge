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
    List<Map<String, List<String>>> requestArray = <Map<String, List<String>>>[];
    createServer(requestArray, customHandler: (request, queryParams, response) async {
      Map<String, Object> responseJson = {'result': 'Success'};
      if (queryParams.containsKey('method') && queryParams['method']!.first == 'feedback') {
        responseJson = {'result': []};
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
    expect(true, requestArray.any((item) => item.containsKey('events')));
    expect(true, requestArray.any((item) => item.containsKey('location'))); //x2
    expect(true, requestArray.any((item) => item.containsKey('crash'))); //x2
    expect(true, requestArray.any((item) => item.containsKey('begin_session')));
    expect(true, requestArray.any((item) => item.containsKey('end_session')));
    expect(true, requestArray.any((item) => item.containsKey('session_duration') && !item.containsKey('end_session')));
    expect(true, requestArray.any((item) => item.containsKey('session_duration') && item.containsKey('end_session')));
    expect(true, requestArray.any((item) => item.containsKey('apm'))); //x2
    expect(true, requestArray.any((item) => item.containsKey('user_details'))); //x2

    validateInternalEventCounts({'orientation': 1, 'view': 6}, requestArray);
    validateImmediateCounts({'hc': 1, 'sc': 1, 'feedback': 1, 'queue': 2, 'ab': 1, 'ab_opt_out': 1, 'rc': 1}, requestArray);
  });
}
