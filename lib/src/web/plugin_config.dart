import 'dart:io';

class CountlyFlutterPluginConfig {
  static const String SDK_VERSION_STRING = '25.4.4';
  static const String SDK_NAME = 'dart-flutterb-web';
  static String WEB_SDK_URL = 'https://cdn.jsdelivr.net/npm/countly-sdk-web@{VERSION}/lib/countly.min.js';

  static String getWebSDKUrl() {
    final config = File('scripts/config/sdk_versions.txt').readAsLinesSync();

    String webVersion = '';

    for (var line in config) {
      line = line.trim();
      if (line.startsWith('web_sdk_version=')) {
        webVersion = line.split('=')[1].trim();
        break;
      }
    }

    final url = WEB_SDK_URL.replaceFirst('{VERSION}', webVersion);
    return url;
  }
}
