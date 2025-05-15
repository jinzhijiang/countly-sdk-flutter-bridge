import 'dart:convert';
import 'dart:io';

import 'package:countly_flutter/countly_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../utils.dart';
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('BM_203_doubleBackoffScenario', (WidgetTester tester) async {
    List<Map<String, List<String>>> requestArray = <Map<String, List<String>>>[];
    List<int> delays = [2,9,5,7,1,0,9,9,9];
    int i = 0;
    createServer(requestArray, delay: 1, customHandler: (request, response) async {
      if(request.uri.query.contains("DELAY_REQUEST")) {
        await Future.delayed(Duration(seconds: delays[i]));
        i++;
      }

      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..headers.set('Access-Control-Allow-Origin', '*')
        ..write(jsonEncode({'result': 'Success'}));

      return; // Explicitly return to satisfy the Future<void> type
    });
  
    // Initialize the SDK
    CountlyConfig config = CountlyConfig("http://0.0.0.0:8080", APP_KEY).enableManualSessionHandling().setLoggingEnabled(true).setMaxRequestQueueSize(10);
    await Countly.initWithConfig(config); 

    addDirectRequest({
      "azd": "DELAY_REQUEST",
    });

        addDirectRequest({
      "azd": "DELAY_REQUEST",
    });

        addDirectRequest({
      "azd": "DELAY_REQUEST",
    });

        addDirectRequest({
      "azd": "DELAY_REQUEST",
    });
        addDirectRequest({
      "azd": "DELAY_REQUEST",
    });
            addDirectRequest({
      "azd": "DELAY_REQUEST",
    });
            addDirectRequest({
      "azd": "DELAY_REQUEST",
    });
            addDirectRequest({
      "azd": "DELAY_REQUEST",
    });
            addDirectRequest({
      "azd": "DELAY_REQUEST",
    });

    // Get request and event queues from native side
    List<String> requestList = await getRequestQueue(); // List of strings
    List<String> eventList = await getEventQueue(); // List of json objects

    // Some logs for debugging
    // wait until request times out, the begin session should be in the request queue
    // and never able to sent to the server
    var x = 0;
    printQueues(requestList, eventList);
    while (requestList.isNotEmpty) {
      await Future.delayed(const Duration(seconds: 9));
      requestList = await getRequestQueue(); // List of strings
      x++;
      if(x >= 10) { 
        // wait for requests to be sent
        break;
      }
    }

    expect(requestList.length, 0);
  });
}
