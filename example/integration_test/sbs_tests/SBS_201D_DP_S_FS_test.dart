import 'dart:convert';
import 'dart:io';

import 'package:countly_flutter/countly_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../utils.dart';
import 'sbs_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('SBS_201D_DP_S_FS_test', (WidgetTester tester) async {
    List<Map<String, List<String>>> requestArray = <Map<String, List<String>>>[];
    createServer(requestArray, customHandler: (request, queryParams, response) async {
      Map<String, Object> responseJson = {'result': 'Success'};
      if (queryParams.containsKey('method')) {
        if (queryParams['method']!.first == 'feedback') {
          responseJson = {'result': []};
        } else if (queryParams['method']!.first == 'sc') {
          responseJson = {
            'v': 1,
            't': 1750748806695,
            'c': {'crt': false, 'vt': false, 'st': true, 'cr': false, 'cet': false, 'log': true, 'dort': 21, 'lkl': 67, 'lvs': 79, 'lsv': 90, 'lbc': 88, 'ltlpt': 34, 'ltl': 250, 'rcz': true, 'bom': true}
          };
        }
      }
      response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..headers.set('Access-Control-Allow-Origin', '*')
        ..write(jsonEncode(responseJson));
    });

    setServerConfig({
      'v': 1,
      't': 1750748806695,
      'c': {'crt': false, 'vt': false, 'st': true, 'cr': false, 'cet': true, 'log': false, 'dort': 12, 'lkl': 120, 'lvs': 255, 'lsv': 99, 'lbc': 99, 'ltlpt': 29, 'ltl': 199, 'rcz': true, 'bom': true}
    });
    // Initialize the SDK
    CountlyConfig config = CountlyConfig('http://0.0.0.0:8080', APP_KEY).enableManualSessionHandling().setLoggingEnabled(true);
    config.setMaxRequestQueueSize(5).setEventQueueSizeToSend(5).disableBackoffMechanism().setRequiresConsent(true).disableLocation().setRequestDropAgeHours(5).setUpdateSessionTimerDelay(75);
    config.content.setZoneTimerInterval(17);
    config.sdkInternalLimits.setMaxBreadcrumbCount(1).setMaxKeyLength(3).setMaxSegmentationValues(3).setMaxValueSize(5).setMaxStackTraceLineLength(300).setMaxStackTraceLinesPerThread(2);

    await Countly.initWithConfig(config);
    await Future.delayed(const Duration(seconds: 2));

    await callAllFeatures();

    expect(await getServerConfig(), {
      'v': 1,
      't': 1750748806695,
      'c': {'crt': false, 'vt': false, 'st': true, 'cr': false, 'cet': false, 'log': true, 'dort': 21, 'lkl': 67, 'lvs': 79, 'lsv': 90, 'lbc': 88, 'ltlpt': 34, 'ltl': 250, 'rcz': true, 'bom': true}
    });

    validateRequestCounts({'events': 1, 'location': 3, 'crash': 0, 'begin_session': 1, 'end_session': 1, 'session_duration': 2, 'apm': 2, 'user_details': 1, 'consent': 0}, requestArray);
    validateInternalEventCounts({'orientation': 1}, requestArray);
    validateImmediateCounts({'hc': 1, 'sc': 1, 'feedback': 1, 'queue': 2, 'ab': 1, 'ab_opt_out': 1, 'rc': 1}, requestArray);
  });
}
