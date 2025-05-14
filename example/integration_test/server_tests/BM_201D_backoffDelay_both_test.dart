import 'package:countly_flutter/countly_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../utils.dart';
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('BM_201D_backoffDelay_both', (WidgetTester tester) async {
    List<Map<String, List<String>>> requestArray = <Map<String, List<String>>>[];
    createServer(requestArray, delay: 9);
  
    // Initialize the SDK
    CountlyConfig config = CountlyConfig("http://0.0.0.0:8080", APP_KEY).enableManualSessionHandling().setLoggingEnabled(true).setMaxRequestQueueSize(5);
    await Countly.initWithConfig(config); 

    addRequest({
      "azd": "begin_session",
      "timestamp": "1747083600000",
      "app_key": APP_KEY,
      "device_id": "1234567890",
    });

    addRequest({
      "yuz": "ttf",
      "timestamp": "1747083600000",
      "app_key": APP_KEY,
      "device_id": "1234567890",
    });

    addRequest({
      "hgj": "sss",
      "timestamp": "1747083600000",
      "app_key": APP_KEY,
      "device_id": "1234567890",
    });

    addRequest({
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
      await Future.delayed(const Duration(seconds: 9));
      requestList = await getRequestQueue(); // List of strings
      i++;
      if(i >= 6) { // why 6 lifetime? because of the health check and server config requests
        // wait for requests to be sent
        break;
      }
    }

    expect(requestList.length, 0);
  });
}
