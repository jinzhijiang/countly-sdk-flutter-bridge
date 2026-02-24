import 'package:countly_sdk_dart_core/countly_sdk_dart_core.dart';

import 'environment/lifecycle_adapter.dart';
import 'environment/migration_adapter.dart';
import 'environment/storage_adapter.dart';
import 'environment/warning_presenter.dart';

CountlyPlatformEnvironment buildFlutterPlatformEnvironment() {
  return CountlyPlatformEnvironment(
    lifecycleAdapter: const FlutterLifecycleAdapter(),
    metricsAdapter: const CoreMetricsAdapter(),
    warningPresenter: const FlutterWarningPresenter(),
    legacyMigrationAdapter: const FlutterLegacyMigrationAdapter(),
    storageAdapter: SharedPreferencesStorageAdapter(),
  );
}
