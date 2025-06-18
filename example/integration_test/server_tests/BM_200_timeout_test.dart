import 'dart:io';

import 'package:countly_flutter_np/countly_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('BM_200_timeoutDelay', (WidgetTester tester) async {
    List<Map<String, List<String>>> requestArray = <Map<String, List<String>>>[];
    createServer(requestArray, delay: 31);
    CountlyConfig config = CountlyConfig("http://0.0.0.0:8080", APP_KEY).enableManualSessionHandling().setLoggingEnabled(true);
    await Countly.initWithConfig(config);

    Countly.instance.sessions.beginSession();
    await Future.delayed(const Duration(seconds: 5));

    List<String> requestList = await getRequestQueue();
    List<String> eventList = await getEventQueue();
    expect(requestList.isNotEmpty, true);
    expect(requestList.length, 1);
    expect(eventList.isNotEmpty, true);
    expect(eventList.length, 1);

    Countly.instance.attemptToSendStoredRequests();

    await Future.delayed(const Duration(seconds: 90));
    requestList = await getRequestQueue();
    eventList = await getEventQueue();

    expect(requestList.length, 2);
    expect(eventList.isEmpty, true);
    expect(requestList[0], contains("begin_session"));

    if (Platform.isAndroid) {
      expect(requestArray.length, 5);
      expect(requestArray[0]['method'], contains("sc"));
      expect(requestArray[1]['begin_session'], ['1']);
      expect(requestArray[2]['hc'], isNotNull);
      expect(requestArray[3]['begin_session'], ['1']);
      expect(requestArray[4]['method'], contains("sc"));
    } else if (Platform.isIOS) {
      expect(requestArray.length, 4);
      int beginSessions = 0, scCount = 0, hcCount = 0;
      for (final req in requestArray) {
        if (req.containsKey('begin_session')) beginSessions++;
        if (req.containsKey('method') && req['method']!.contains('sc')) scCount++;
        if (req.containsKey('hc')) hcCount++;
      }
      expect(beginSessions, equals(2));
      expect(scCount, equals(1));
      expect(hcCount, equals(1));
    }
  });
}
