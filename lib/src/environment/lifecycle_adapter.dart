import 'package:countly_sdk_dart_core/countly_sdk_dart_core.dart';
import 'package:flutter/widgets.dart';

class FlutterLifecycleAdapter implements CountlyLifecycleAdapter {
  const FlutterLifecycleAdapter();

  @override
  CountlyDisposeCallback listen({void Function()? onBackground, void Function()? onForeground}) {
    final binding = WidgetsBinding.instance;
    final observer = _CountlyLifecycleObserver(onBackground, onForeground);
    binding.addObserver(observer);
    return () => binding.removeObserver(observer);
  }
}

class _CountlyLifecycleObserver extends WidgetsBindingObserver {
  final void Function()? onBackground;
  final void Function()? onForeground;

  _CountlyLifecycleObserver(this.onBackground, this.onForeground);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        onBackground?.call();
        break;
      case AppLifecycleState.resumed:
        onForeground?.call();
        break;
    }
  }
}
