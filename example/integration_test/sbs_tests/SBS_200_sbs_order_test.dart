import 'dart:convert';
import 'dart:io';

import 'package:countly_flutter/countly_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../utils.dart';
import 'sbs_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('SBS_200_sbs_order', (WidgetTester tester) async {
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
            'c': {
              'ecz': false,
              'crt': true,
              'vt': false,
              'st': true,
              'cet': true,
              'cr': false,
              'log': true,
              'tracking': true,
              'networking': true,
              'ebs': 10,
              'czi': 30,
              'dort': 0,
              'lkl': 128,
              'lvs': 256,
              'lsv': 100,
              'lbc': 100,
              'scui': 4,
              'ltlpt': 30,
              'ltl': 200,
              'lt': false,
              'rcz': true,
              'bom': true,
              'bom_d': 60,
              'bom_at': 10,
              'bom_rqp': 0.5,
              'bom_ra': 24
            }
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
      't': 1750748806687,
      'c': {
        'ecz': false,
        'crt': true,
        'vt': true,
        'st': true,
        'cet': true,
        'cr': false,
        'log': true,
        'tracking': true,
        'networking': true,
        'sui': 60,
        'ebs': 10,
        'czi': 30,
        'dort': 0,
        'lkl': 128,
        'lvs': 256,
        'lsv': 100,
        'lbc': 100,
        'scui': 4,
        'ltlpt': 30,
        'ltl': 200,
        'lt': false,
        'rcz': false,
        'bom': true,
        'bom_d': 60,
        'bom_at': 10,
        'bom_rqp': 0.5,
        'bom_ra': 24
      }
    });

    const String providedSBS = '''
{
  "v": 1,
  "t": 1750748806688,
  "c": {
    "ecz": false,
    "crt": true,
    "vt": true,
    "st": true,
    "cet": true,
    "cr": false,
    "log": true,
    "tracking": true,
    "networking": true,
    "sui": 60,
    "ebs": 10,
    "czi": 30,
    "dort": 0,
    "lkl": 128,
    "lvs": 256,
    "lsv": 100,
    "lbc": 100,
    "scui": 4,
    "ltlpt": 30,
    "ltl": 200,
    "lt": false,
    "rcz": false,
    "bom": true,
    "bom_d": 60,
    "bom_at": 10,
    "bom_rqp": 0.5,
    "bom_ra": 24
  }
}
''';

    // Initialize the SDK
    CountlyConfig config = CountlyConfig('http://0.0.0.0:8080', APP_KEY).enableManualSessionHandling().setLoggingEnabled(true);
    config.setSDKBehaviorSettings(providedSBS);
    config.setMaxRequestQueueSize(5);
    config.setEventQueueSizeToSend(5);
    config.setUpdateSessionTimerDelay(30);
    await Countly.initWithConfig(config);

    // EQ and RQ is overridden by dev provided config from defaults to 5
    // EQ RQ is 5 always but timer delay overridden to 60 by provided SBS
    // rcz and vt disabled by server given config
    // and at last timestamp is 1750748806695

    await callAllFeatures();

    print(requestArray);
    expect(await getServerConfig(), {
      'v': 1,
      't': 1750748806695,
      'c': {
        'ecz': false,
        'crt': true,
        'vt': false,
        'st': true,
        'cet': true,
        'cr': false,
        'log': true,
        'tracking': true,
        'networking': true,
        'sui': 60,
        'ebs': 10,
        'czi': 30,
        'dort': 0,
        'lkl': 128,
        'lvs': 256,
        'lsv': 100,
        'lbc': 100,
        'scui': 4,
        'ltlpt': 30,
        'ltl': 200,
        'lt': false,
        'rcz': true,
        'bom': true,
        'bom_d': 60,
        'bom_at': 10,
        'bom_rqp': 0.5,
        'bom_ra': 24
      }
    });

    validateRequestCounts({'events': 8, 'location': 1, 'crash': 2, 'begin_session': 1, 'end_session': 1, 'session_duration': 2, 'apm': 2, 'user_details': 1}, requestArray);
    validateInternalEventCounts({'orientation': 1}, requestArray);
    validateImmediateCounts({'hc': 1, 'sc': 1, 'feedback': 1, 'queue': 2, 'ab': 1, 'ab_opt_out': 1, 'rc': 1}, requestArray);
  });
}
