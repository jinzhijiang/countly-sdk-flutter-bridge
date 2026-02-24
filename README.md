# Countly Flutter Lite SDK

This repository contains the non-bridged and lightweight Flutter Lite SDK which can be integrated into mobile application. The Countly Flutter Lite SDK is intended to be used with [Countly Lite](https://countly.com/lite), [Countly Flex](https://countly.com/flex), [Countly Enterprise](https://countly.com/enterprise).

## What is Countly?

[Countly](https://countly.com) is a product analytics solution and innovation enabler that helps teams track product performance and customer journey and behavior across [mobile](https://countly.com/mobile-analytics), [web](https://countly.com/web-analytics), and [desktop](https://countly.com/desktop-analytics) applications.

Track, measure, and take action - all without leaving Countly.

* **Questions or feature requests?** [Join the Countly Community on Discord](https://discord.gg/countly)
* **Looking for the Countly Server?** [Countly Server repository](https://github.com/Countly/countly-server)

## Integrating Countly SDK in your projects

For a detailed description on how to use this SDK [check out our documentation](https://support.count.ly/hc/en-us/articles/).

For an example integration of this SDK, see the [Flutter example app in this repository](https://github.com/Countly/countly-sdk-dart/tree/main/example/flutter_example).

This SDK supports the following features:

* Analytics
* User Profiles
* Views
* Consent management
* Device ID management

## Installation

In the `dependencies:` section of your `pubspec.yaml`, add the following line:

```yaml
dependencies:
  countly_flutter_lite: <latest_version>
```

## Usage

### Initialization

```dart
import 'package:countly_flutter_lite/countly.dart';
import 'package:flutter/widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = CountlyConfig(
    appKey: 'YOUR_APP_KEY',
    serverUrl: 'https://your.server.com',
    giveConsent: true,
    enableSDKLogs: true,
  );

  await Countly.init(config);
  runApp(const MyApp());
}
```

### Configuration Options

```dart
final config = CountlyConfig(
  appKey: 'YOUR_APP_KEY',           // Required: Your Countly app key
  serverUrl: 'https://server.com',   // Required: Your Countly server URL
  deviceId: 'custom-device-id',      // Optional: Custom device ID
  giveConsent: true,                 // Optional: Grant consent at init
  startWithUnknownConsent: false,    // Optional: Start with unknown consent
  enableSDKLogs: true,               // Optional: Enable logging
  logLevel: LogLevel.verbose,        // Optional: Log verbosity
  enableVisualWarnings: false,       // Optional: Show visual warnings
  customRequestHeaders: {            // Optional: Custom HTTP headers
    'X-Custom-Header': 'value',
  },
  deviceMetricOverrides: {           // Optional: Override device metrics
    '_os': 'CustomOS',
  },
  userProperties: {                  // Optional: Initial user properties
    'name': 'John Doe',
    'tier': 'premium',
  },
  disableOldDataMigration: false,    // Optional: Disable legacy migration
);

// storageMode is optional:
// - if omitted, Flutter Lite uses persistent storage
// - if set (e.g. StorageMode.memory), your explicit value is respected

```

### Recording Events

```dart
final sdk = Countly.defaultInstance!;

await sdk.events.record(key: 'button_click');
await sdk.events.record(key: 'item_purchased', count: 3);
await sdk.events.record(key: 'purchase', sum: 29.99);
await sdk.events.record(key: 'video_watched', dur: 120.5);

await sdk.events.record(
  key: 'purchase',
  count: 1,
  sum: 99.99,
  dur: 5.0,
  segmentation: {
    'product_id': 'SKU123',
    'category': 'electronics',
    'tags': ['featured', 'sale'],
  },
);
```

### Recording Views

```dart
final sdk = Countly.defaultInstance!;

await sdk.views.startAutoStoppedView('HomePage');
await sdk.views.startAutoStoppedView('ProductPage', segmentation: {
  'category': 'electronics',
});
await sdk.views.endActiveView(segmentation: {
  'exit': 'back_button',
});
```

### User Profiles

```dart
final sdk = Countly.defaultInstance!;

await sdk.users.setProperties({
  'name': 'John Doe',
  'email': 'john@example.com',
  'username': 'johndoe',
  'phone': '+1234567890',
  'gender': 'M',
  'byear': 1990,
});

await sdk.users.pushToArray('viewed_products', ['SKU123', 'SKU456']);
await sdk.users.addToSet('categories', ['electronics', 'books']);
await sdk.users.pullFromArray('interests', ['outdated']);
```

### Consent Management

```dart
final sdk = Countly.defaultInstance!;

await sdk.consents.giveConsent();
await sdk.consents.revokeConsent();
```

### Device ID Management

```dart
final sdk = Countly.defaultInstance!;

final deviceId = sdk.deviceId;
await sdk.id.changeWithMerge('user_123456');
await sdk.id.changeWithoutMerge('new_anonymous_id');
await sdk.consents.giveConsent();
```

### Multi-Instance Support

```dart
final primary = await Countly.init(config);
final secondary = await Countly.init(config2, instanceKey: 'secondary');

final primaryInstance = Countly.defaultInstance;
final secondaryInstance = Countly.instance('secondary');

await Countly.disposeInstance('secondary');
await Countly.disposeAll();
```

### Custom Logger

```dart
class MyLogger implements SdkLogger {
  @override
  bool isEnabled(LogLevel level) => level.index <= LogLevel.info.index;

  @override
  void log(LogLevel level, String message, {Object? error, StackTrace? stack}) {
    print('[${level.name}] $message');
  }
}

final config = CountlyConfig(
  appKey: 'YOUR_APP_KEY',
  serverUrl: 'https://your.server.com',
  logger: MyLogger(),
  enableSDKLogs: true,
);
```

## Security

Security is very important to us. If you discover any issue regarding security, please disclose the information responsibly by sending an email to <security@countly.com> and **not by creating a GitHub issue**.

## Badges

If you like Countly, [why not use one of our badges](https://countly.com/brand-assets) and give a link back to us so others know about this wonderful platform?

<a href="https://count.ly/f/badge" rel="nofollow"><img style="width:145px;height:60px" src="https://countly.com/badges/dark.svg?v2" alt="Countly - Product Analytics" /></a>

```JS
<a href="https://count.ly/f/badge" rel="nofollow"><img style="width:145px;height:60px" src="https://countly.com/badges/dark.svg" alt="Countly - Product Analytics" /></a>
```

<a href="https://count.ly/f/badge" rel="nofollow"><img style="width:145px;height:60px" src="https://countly.com/badges/light.svg?v2" alt="Countly - Product Analytics" /></a>

```JS
<a href="https://count.ly/f/badge" rel="nofollow"><img style="width:145px;height:60px" src="https://countly.com/badges/light.svg" alt="Countly - Product Analytics" /></a>
```

## How can I help you with your efforts?

Glad you asked! For community support, feature requests, and engaging with the Countly Community, please join us at [our Discord Server](https://discord.gg/countly). We're excited to have you there!

Also, we are on [Twitter](https://twitter.com/gocountly) and [LinkedIn](https://www.linkedin.com/company/countly) if you would like to keep up with Countly related updates.
