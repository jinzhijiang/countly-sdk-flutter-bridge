#!/bin/bash

### Syncs all SDK versions from sdk_versions.txt ###

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config/sdk_versions.txt"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Config file not found: $CONFIG_FILE"
    exit 1
fi

FLUTTER_SDK_VERSION=$(grep "^flutter_sdk_version=" "$CONFIG_FILE" | cut -d '=' -f2)
ANDROID_SDK_VERSION=$(grep "^android_sdk_version=" "$CONFIG_FILE" | cut -d '=' -f2)
IOS_SDK_VERSION=$(grep "^ios_sdk_version=" "$CONFIG_FILE" | cut -d '=' -f2)
WEB_SDK_VERSION=$(grep "^web_sdk_version=" "$CONFIG_FILE" | cut -d '=' -f2)

if [ -z "$FLUTTER_SDK_VERSION" ]; then
    echo "❌ flutter_sdk_version not found in $CONFIG_FILE"; exit 1
fi
if [ -z "$ANDROID_SDK_VERSION" ]; then
    echo "❌ android_sdk_version not found in $CONFIG_FILE"; exit 1
fi
if [ -z "$IOS_SDK_VERSION" ]; then
    echo "❌ ios_sdk_version not found in $CONFIG_FILE"; exit 1
fi
if [ -z "$WEB_SDK_VERSION" ]; then
    echo "❌ web_sdk_version not found in $CONFIG_FILE"; exit 1
fi

echo "📦 Syncing SDK versions from $CONFIG_FILE"
echo "   Flutter: $FLUTTER_SDK_VERSION"
echo "   Android: $ANDROID_SDK_VERSION"
echo "   iOS:     $IOS_SDK_VERSION"
echo "   Web:     $WEB_SDK_VERSION"
echo ""

# ---- Flutter: pubspec.yaml ----
PUBSPEC="$ROOT_DIR/pubspec.yaml"
if [ -f "$PUBSPEC" ]; then
    sed -i '' "s|^version: .*|version: $FLUTTER_SDK_VERSION|" "$PUBSPEC"
    echo "✅ Flutter → pubspec.yaml"
fi

# ---- Flutter: countly_flutter.podspec ----
PODSPEC="$ROOT_DIR/ios/countly_flutter.podspec"
if [ -f "$PODSPEC" ]; then
    sed -i '' "s|s.version = '.*'|s.version = '$FLUTTER_SDK_VERSION'|" "$PODSPEC"
    echo "✅ Flutter → ios/countly_flutter.podspec"
fi

# ---- Flutter: CountlyFlutterPlugin.java ----
JAVA_PLUGIN="$ROOT_DIR/android/src/main/java/ly/count/dart/countly_flutter/CountlyFlutterPlugin.java"
if [ -f "$JAVA_PLUGIN" ]; then
    sed -i '' "s|COUNTLY_FLUTTER_SDK_VERSION_STRING = \".*\"|COUNTLY_FLUTTER_SDK_VERSION_STRING = \"$FLUTTER_SDK_VERSION\"|" "$JAVA_PLUGIN"
    echo "✅ Flutter → CountlyFlutterPlugin.java"
fi

# ---- Flutter: CountlyFlutterPlugin.m ----
OBJ_PLUGIN="$ROOT_DIR/ios/Classes/CountlyFlutterPlugin.m"
if [ -f "$OBJ_PLUGIN" ]; then
    sed -i '' "s|kCountlyFlutterSDKVersion = @\".*\"|kCountlyFlutterSDKVersion = @\"$FLUTTER_SDK_VERSION\"|" "$OBJ_PLUGIN"
    echo "✅ Flutter → ios/Classes/CountlyFlutterPlugin.m"
fi

# ---- Flutter: plugin_config.dart (SDK_VERSION_STRING) ----
PLUGIN_CONFIG="$ROOT_DIR/lib/src/web/plugin_config.dart"
if [ ! -f "$PLUGIN_CONFIG" ]; then
    echo "❌ Plugin config not found: $PLUGIN_CONFIG"; exit 1
fi
sed -i '' "s|static const String SDK_VERSION_STRING = '.*'|static const String SDK_VERSION_STRING = '$FLUTTER_SDK_VERSION'|" "$PLUGIN_CONFIG"
echo "✅ Flutter → plugin_config.dart"

# ---- Flutter: no-push-files/pubspec.yaml ----
NP_PUBSPEC="$SCRIPT_DIR/no-push-files/pubspec.yaml"
if [ -f "$NP_PUBSPEC" ]; then
    sed -i '' "s|^version: .*|version: $FLUTTER_SDK_VERSION|" "$NP_PUBSPEC"
    echo "✅ Flutter → no-push-files/pubspec.yaml"
fi

# ---- Flutter: no-push-files/countly_flutter_np.podspec ----
NP_PODSPEC="$SCRIPT_DIR/no-push-files/countly_flutter_np.podspec"
if [ -f "$NP_PODSPEC" ]; then
    sed -i '' "s|s.version = '.*'|s.version = '$FLUTTER_SDK_VERSION'|" "$NP_PODSPEC"
    echo "✅ Flutter → no-push-files/countly_flutter_np.podspec"
fi

# ---- Web: plugin_config.dart (WEB_SDK_VERSION) ----
sed -i '' "s|static const String WEB_SDK_VERSION = '.*'|static const String WEB_SDK_VERSION = '$WEB_SDK_VERSION'|" "$PLUGIN_CONFIG"
echo "✅ Web     → plugin_config.dart"

# ---- Android: build.gradle ----
BUILD_GRADLE="$ROOT_DIR/android/build.gradle"
if [ -f "$BUILD_GRADLE" ]; then
    sed -i '' "s|implementation 'ly.count.android:sdk:.*'|implementation 'ly.count.android:sdk:$ANDROID_SDK_VERSION'|" "$BUILD_GRADLE"
    echo "✅ Android → android/build.gradle"
fi

# ---- Android: no-push-files/build.gradle ----
NP_BUILD_GRADLE="$SCRIPT_DIR/no-push-files/build.gradle"
if [ -f "$NP_BUILD_GRADLE" ]; then
    sed -i '' "s|implementation 'ly.count.android:sdk:.*'|implementation 'ly.count.android:sdk:$ANDROID_SDK_VERSION'|" "$NP_BUILD_GRADLE"
    echo "✅ Android → no-push-files/build.gradle"
fi

# ---- iOS: submodule init & sparse checkout ----
SUBMODULE_PATH="ios/Classes/countly-sdk-ios"
IOS_TAG="${1:-$IOS_SDK_VERSION}"
SPARSE_FILE="$(cd "$SCRIPT_DIR" && pwd)/config/sparse-checkout.list"

echo ""
echo "🔧 Initializing iOS SDK submodule..."
echo "   Tag: $IOS_TAG"
echo "   Path: $SUBMODULE_PATH"
echo ""

cd "$ROOT_DIR" || { echo "❌ Failed to enter root directory."; exit 1; }

git submodule update --init --recursive "$SUBMODULE_PATH"

cd "$SUBMODULE_PATH" || { echo "❌ Failed to enter submodule path."; exit 1; }

echo "📥 Checking out tag $IOS_TAG..."
git fetch --all --tags
git checkout "$IOS_TAG" || { echo "❌ Tag not found: $IOS_TAG"; exit 1; }

if [ ! -f "$SPARSE_FILE" ]; then
    echo "❌ Missing sparse-checkout rules at: $SPARSE_FILE"
    exit 1
fi

echo "🧹 Applying sparse-checkout rules from: $SPARSE_FILE"
git sparse-checkout init --no-cone
cp "$SPARSE_FILE" "$(git rev-parse --git-path info)/sparse-checkout"
git read-tree -mu HEAD

echo "✅ iOS     → submodule checked out at $IOS_TAG"

# ---- Stage all modified files ----
cd "$ROOT_DIR" || { echo "❌ Failed to enter root directory."; exit 1; }

echo ""
echo "📋 Staging changed files..."
git add \
    scripts/config/sdk_versions.txt \
    pubspec.yaml \
    ios/countly_flutter.podspec \
    android/src/main/java/ly/count/dart/countly_flutter/CountlyFlutterPlugin.java \
    ios/Classes/CountlyFlutterPlugin.m \
    lib/src/web/plugin_config.dart \
    scripts/no-push-files/pubspec.yaml \
    scripts/no-push-files/countly_flutter_np.podspec \
    android/build.gradle \
    scripts/no-push-files/build.gradle \
    ios/Classes/countly-sdk-ios
echo "✅ All changed files staged"

# ---- Flutter clean & pub get ----
echo ""
echo "🧹 Running flutter clean..."
flutter clean

echo ""
echo "📦 Running flutter pub get..."
flutter pub get

echo ""
echo "✅ All SDK versions synced, staged, and project refreshed"
