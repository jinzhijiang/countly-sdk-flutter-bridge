import 'package:countly_flutter/countly_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../utils.dart';
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('BM_201B_backoffDelay_requests', (WidgetTester tester) async {
    List<Map<String, List<String>>> requestArray = <Map<String, List<String>>>[];
    createServer(requestArray, delay: 9);
    // Initialize the SDK
    CountlyConfig config = CountlyConfig("http://0.0.0.0:8080", APP_KEY).enableManualSessionHandling().setLoggingEnabled(true).setMaxRequestQueueSize(5);
    await Countly.initWithConfig(config); // generates 0.begin_session

    Countly.instance.sessions.beginSession(); // this should be sent to the server
    await Future.delayed(const Duration(seconds: 2));
    Countly.instance.sessions.updateSession(); // this should be sent to the server
    await Future.delayed(const Duration(seconds: 2));
    Countly.instance.sessions.endSession(); // this should be backed off

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
      if(i >= 4) {
        // wait for requests to be sent
        break;
      }
    }

    expect(requestList.length, 0);
  });
}
