import 'package:countly_flutter/countly_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../utils.dart';
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('BM_200_timeoutDelay', (WidgetTester tester) async {
    List<Map<String, List<String>>> requestArray = <Map<String, List<String>>>[];
    createServer(requestArray, delay: 30);
    // Initialize the SDK
    CountlyConfig config = CountlyConfig("http://0.0.0.0:8080", APP_KEY).enableManualSessionHandling().setLoggingEnabled(true);
    await Countly.initWithConfig(config); // generates 0.begin_session

    Countly.instance.sessions.beginSession();
    await Future.delayed(const Duration(seconds: 5));

    // Get request and event queues from native side
    List<String> requestList = await getRequestQueue(); // List of strings
    List<String> eventList = await getEventQueue(); // List of json objects
    expect(requestList.isNotEmpty, true);
    expect(requestList.length, 1);
    expect(eventList.isNotEmpty, true);
    expect(eventList.length, 1);

    // check the queues are not empty
    await Future.delayed(const Duration(seconds: 90));
    print(requestArray);
    requestList = await getRequestQueue(); // List of strings
    eventList = await getEventQueue(); // List of json objects

    expect(requestList.length, 2);
    expect(eventList.isEmpty, true);
    expect(requestList[0], contains("begin_session"));

    // request array should contain 5 requests: 2 sc, hc and 2 begin_session
    expect(requestArray.length, 5);
    expect(requestArray[0]['method'], contains("sc"));
    expect(requestArray[1]['begin_session'], ['1']);
    expect(requestArray[2]['hc'], isNotNull);
    expect(requestArray[3]['begin_session'], ['1']);
    expect(requestArray[4]['method'], contains("sc"));
  });
}
