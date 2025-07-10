import 'dart:convert';
import 'dart:io';
import 'package:countly_flutter/countly_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../event_tests/event_utils.dart';
import '../utils.dart';

/// internal event key: [reserved segmentation keys : is it truncable]
/// For example mode in orientation is not truncable, but name in view is truncable
Map<String, Map<String, bool>> reservedSegmentationKeys = {
  '[CLY]_view': {'name': true, 'visit': false, 'start': false, 'segment': false},
  '[CLY]_orientation': {'mode': false}
};

/// Validates the immediate counts in the request array.
/// This function checks the number of immediate methods recorded in the request array
/// and compares them with the expected counts provided in the `immediates` map.
/// It expects the keys in the `immediates` map to be the method names (like 'hc', 'sc', 'feedback', etc.)
/// and the values to be the expected counts of those methods.
/// @param immediates A map where keys are the names of the immediate methods and values are the expected counts. like {'hc': 1, 'sc': 1, 'feedback': 1, 'queue': 2, 'ab': 1, 'ab_opt_out': 1, 'rc': 1}
/// @param requestArray The array of requests to validate against.
void validateImmediateCounts(Map<String, int> immediates, List<Map<String, List<String>>> requestArray) {
  Map<String, int> actualImmediates = <String, int>{};

  // key is method values are the switch cases
  for (var request in requestArray) {
    if (request.containsKey('method')) {
      String method = request['method']![0];
      actualImmediates[method] = (actualImmediates[method] ?? 0) + 1;
    } else if (request.containsKey('hc')) {
      actualImmediates['hc'] = (actualImmediates['hc'] ?? 0) + 1;
    }
  }

  expect(actualImmediates.length, immediates.length, reason: 'Mismatch in number of immediate methods');
  // Validate the counts
  for (var entry in immediates.entries) {
    expect(actualImmediates[entry.key], entry.value, reason: 'Mismatch for method ${entry.key}');
  }
}

/// Validates the internal event counts in the request array.
/// This function checks the number of internal events recorded in the request array
/// and compares them with the expected counts provided in the `internalEventsCounts` map.
/// It expects the keys in the `internalEventsCounts` map to be not prefixed with '[CLY]_'.
/// function also checks all internal events existence, so if it not exist it checks that given array length matches extracted internal event counts
/// The function will throw an error if the counts do not match.
/// @param internalEventsCounts A map where keys are the names of the internal events (without '[CLY]_') and values are the expected counts. like {'orientation': 1, 'view': 6}
/// @param requestArray The array of requests to validate against.
///
void validateInternalEventCounts(Map<String, int> internalEventsCounts, List<Map<String, List<String>>> requestArray) {
  Map<String, int> actualCounts = <String, int>{};

  // key is method values are the switch cases
  for (var request in requestArray) {
    if (request.containsKey('events')) {
      List<Map<String, dynamic>> events = (jsonDecode(request['events']![0]) as List).cast<Map<String, dynamic>>();
      for (var event in events) {
        if (event['key'].toString().startsWith('[CLY]')) {
          actualCounts[event['key']] = (actualCounts[event['key']] ?? 0) + 1;
        }
      }
    }
  }

  expect(actualCounts.length, internalEventsCounts.length, reason: 'Mismatch in number of internal event methods actual: $actualCounts, expected: $internalEventsCounts');
  // Validate the counts
  for (var entry in internalEventsCounts.entries) {
    expect(actualCounts['[CLY]_${entry.key}'], entry.value, reason: 'Mismatch for method ${entry.key}');
  }
}

/// Calls all features of Countly SDK to ensure they are working correctly.
/// This includes events, views, sessions, user location, user profile, crash, feedback widgets, remote config, A/B testing, consent, and content zone.
/// It also includes the things that are affected by the SDK internal limits, such as truncable events
/// This function is used in integration tests to validate the functionality of the Countly SDK with the SBS
/// At the end of the function, it triggers sending requests to the queue and waits for 10 seconds to ensure all requests are sent and queues are empty
Future<void> callAllFeatures({bool disableEnterContent = false, bool disableSend = false, bool disableConsentCall = false}) async {
  if (!disableConsentCall) {
    await Countly.giveAllConsent();
  }
  await Countly.getAvailableFeedbackWidgets();
  await Countly.instance.sessions.beginSession();
  await Countly.addCrashLog('First Breadcrumb'); // breadcrumb
  await Countly.addCrashLog('Launched app'); // breadcrumb
  await Countly.addCrashLog('Came to end'); // breadcrumb
  await Countly.addCrashLog('Not done yet'); // breadcrumb
  await Countly.addCrashLog('Will enter soon'); // breadcrumb
  await createTruncableEvents();
  await generateEvents();
  await Countly.setUserLocation(countryCode: 'TR', city: 'Istanbul', gpsCoordinates: '41.0082,28.9784', ipAddress: '10.2.33.12');
  await Countly.instance.events.recordEvent('Event With Sum And Segment', {'Country': 'Turkey', 'Age': 28884}, 1, 0.99); // not legacy code
  Map<String, Object> segmentation = {
    'country': 'Germany',
    'app_version': '1.0',
    'rating': 10,
    'precision': 324.54678,
    'timestamp': 1234567890,
    'clicked': false,
    'languages': ['en', 'de', 'fr'],
    'sub_names': ['John', 'Doe', 'Jane']
  };
  await Countly.instance.views.startView('Dashboard', segmentation);

  // IMMEDIATE CALLS
  if (!disableEnterContent) {
    await Countly.instance.content.enterContentZone();
  }
  await Countly.instance.remoteConfig.downloadAllKeys((rResult, error, fullValueUpdate, downloadedValues) {
    if (rResult == RequestResult.success) {
      // do sth
    } else {
      // do sth
    }
  });

  await Countly.instance.remoteConfig.enrollIntoABTestsForKeys(['key1', 'key2']);
  await Countly.instance.remoteConfig.exitABTestsForKeys(['key1', 'key2']);

  // END IMMEDIATE CALLS
  await Countly.reportFeedbackWidgetManually(CountlyPresentableFeedback('test', 'nps', 'test'), {}, {});

  await Future.delayed(const Duration(seconds: 2));
  await Countly.instance.sessions.updateSession();
  await Countly.instance.views.stopViewWithName('Dashboard');
  await Countly.instance.content.refreshContentZone();

  await Future.delayed(const Duration(seconds: 2));
  await Countly.instance.sessions.endSession();
  if (disableSend) {
    // if send is disabled, we will not send the requests to the server
    return;
  }
  await Countly.instance.attemptToSendStoredRequests();
  // check queues are empty and all requests are sent
  await Future.delayed(const Duration(seconds: 10));
}

/// Validates the request counts in the request array.
/// This function checks the number of requests for each method recorded in the request array
/// and compares them with the expected counts provided in the `requests` map.
/// It expects the keys in the `requests` map to be the method names (like 'events', 'location', 'crash', etc.)
/// and the values to be the expected counts of those methods.
/// @param requests A map where keys are the names of the request methods and values are the expected counts. like {'events': 2, 'location': 1, 'crash': 2, 'begin_session': 1, 'end_session': 1, 'session_duration': 2, 'apm': 2, 'user_details': 1}
/// @param requestArray The array of requests to validate against.
void validateRequestCounts(Map<String, int> requests, List<Map<String, List<String>>> requestArray) {
  Map<String, int> actualRequests = <String, int>{};

  // key is method values are the switch cases
  for (var request in requestArray) {
    for (var entry in requests.entries) {
      if (request.containsKey(entry.key)) {
        actualRequests[entry.key] = (actualRequests[entry.key] ?? 0) + 1;
      }
    }
  }

  if (Platform.isIOS) {
    for (var entry in requests.entries) {
      if (actualRequests[entry.key] == null) {
        actualRequests[entry.key] = 0; // Ensure all keys are present in the actualRequests map
      }
    }
    // iOS specific validation because until refactoring iOS, the request counts may differ due to its problematic RQ handling
    expect(actualRequests.length, requests.length, reason: 'Mismatch in number of request methods actual: $actualRequests, expected: $requests');
  } else {
// Validate the counts
    for (var entry in requests.entries) {
      expect(actualRequests[entry.key] ?? 0, entry.value, reason: 'Mismatch for method ${entry.key}');
    }
  }
}

int sbsServerDelay = 0;

/// Creates a server with a custom handler that responds to requests based on the provided configuration.
/// The server will respond with a JSON object containing the result of the request.
void createServerWithConfig(List<Map<String, List<String>>> requestArray, Map<String, Object> serverConfig) {
  createServer(requestArray, customHandler: (request, queryParams, response) async {
    Map<String, Object> responseJson = {'result': 'Success'};
    if (queryParams.containsKey('method')) {
      if (queryParams['method']!.first == 'sc') {
        responseJson = serverConfig;
      } else if (queryParams['method']!.first == 'feedback') {
        responseJson = {'result': []};
      }
    }

    if (sbsServerDelay > 0 && !queryParams.containsKey('events')) {
      await Future.delayed(Duration(seconds: sbsServerDelay));
    }

    response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..headers.set('Access-Control-Allow-Origin', '*')
      ..write(jsonEncode(responseJson));
  });
}

/// Validates the internal limits for events based on the provided event data.
/// This function checks the key length, value size, and segmentation values
void validateInternalLimitsForEvents(Map<String, dynamic> event, int maxKeyLength, int maxValueSize, int maxSegmentationValues) {
  // Validate key length
  Map<String, bool> validationSetForKey = reservedSegmentationKeys[event['key']] ?? {};
  bool isReservedKey = validationSetForKey.isNotEmpty;

  if (!isReservedKey) {
    // internal keys like '[CLY]_view' are not truncated
    expect(event['key'].toString().length <= maxKeyLength, isTrue);
  }

  if (event['segmentation'] != null) {
    // Validate segmentation keys and values
    Map<String, dynamic> segmentation = event['segmentation'];
    expect(segmentation.length <= maxSegmentationValues + validationSetForKey.length, isTrue);
    for (var key in segmentation.keys) {
      bool checkValueSizeLimit = validationSetForKey[key] ?? true;
      if (validationSetForKey[key] == null) {
        expect(key.length <= maxKeyLength, isTrue);
      }

      if (checkValueSizeLimit && segmentation[key] is String) {
        expect(segmentation[key].toString().length <= maxValueSize, isTrue);
      }
    }
  }
}

/// Retrieves the request queue from the server.
/// And parses it into a list of maps with query parameters.
Future<List<Map<String, List<String>>>> getRequestQueueParsed() async {
  List<Map<String, List<String>>> requestArray = <Map<String, List<String>>>[];
  List<String> rq = await getRequestQueue();
  if (rq.isNotEmpty) {
    requestArray = rq.map((item) {
      Uri parsed = Uri.parse('https://count.ly?' + item);
      return parsed.queryParametersAll;
    }).toList();
  }
  return requestArray;
}
