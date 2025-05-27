import 'package:countly_flutter/countly_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../utils.dart';
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('BM_201C_backoffDelay_oldRequests', (WidgetTester tester) async {
    List<Map<String, List<String>>> requestArray = <Map<String, List<String>>>[];
    createServer(requestArray, delay: 11);
  
    // Initialize the SDK
    CountlyConfig config = CountlyConfig("http://0.0.0.0:8080", APP_KEY).enableManualSessionHandling().setLoggingEnabled(true);
    await Countly.initWithConfig(config); 

    storeRequest({
      "azd": "begin_session",
      "timestamp": "1747083600000",
      "app_key": APP_KEY,
      "device_id": "1234567890",
    });

    storeRequest({
      "yuz": "ttf",
      "timestamp": "1747083600000",
      "app_key": APP_KEY,
      "device_id": "1234567890",
    });

    storeRequest({
      "hgj": "sss",
      "timestamp": "1747083600000",
      "app_key": APP_KEY,
      "device_id": "1234567890",
    });

    storeRequest({
      "ffg": "aaa",
      "timestamp": "1747083600000",
      "app_key": APP_KEY,
      "device_id": "1234567890",
    });

    Countly.instance.sessions.beginSession();

    // Get request and event queues from native side
    List<String> requestList = await getRequestQueue(); // List of strings
    List<String> eventList = await getEventQueue(); // List of json objects

    // Some logs for debugging
    // wait until request times out, the begin session should be in the request queue
    // and never able to sent to the server
    var i = 0;
    printQueues(requestList, eventList);
    while (requestList.isNotEmpty) {
      await Future.delayed(const Duration(seconds: 11));
      requestList = await getRequestQueue(); // List of strings
      i++;
      if(i >= 5) { // why 5 lifetime? because of the health check and server config requests
        // wait for requests to be sent
        break;
      }
    }

    expect(requestList.length, 1);
    expect(requestList[0], contains("begin_session"));
    // why? because last two response is above timeout limits
    // and we are not able to send only the begin session request
    // because the others are older than the 12 hours
  });
}
