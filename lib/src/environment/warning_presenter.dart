import 'dart:collection';

import 'package:countly_sdk_dart_core/countly_sdk_dart_core.dart';
import 'package:flutter/material.dart';

class FlutterWarningPresenter implements CountlyWarningPresenter {
  const FlutterWarningPresenter();

  static final Queue<String> _pendingToasts = Queue<String>();
  static bool _willShow = false;
  static const int _maxQueue = 20;

  @override
  bool get isAvailable => true;

  @override
  void showWarning(String message) {
    if (_pendingToasts.length >= _maxQueue) {
      _pendingToasts.removeFirst();
    }

    final overlay = _locateOverlay();

    if (overlay == null) {
      _pendingToasts.add(message);
      _scheduleDrain();
      return;
    }

    _insertToast(overlay, message);
  }

  static void _insertToast(OverlayState overlay, String message) {
    final entry = OverlayEntry(builder: (_) => _SdkToastWidget(message: message));
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3)).then((_) {
      try {
        entry.remove();
      } catch (_) {}
    });
  }

  static void _scheduleDrain() {
    if (_willShow) return;
    _willShow = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _willShow = false;
      _drainQueue();
    });
  }

  static void _drainQueue() {
    if (_pendingToasts.isEmpty) return;
    final overlay = _locateOverlay();
    if (overlay == null) {
      _scheduleDrain();
      return;
    }
    while (_pendingToasts.isNotEmpty) {
      _insertToast(overlay, _pendingToasts.removeFirst());
    }
  }

  static OverlayState? _locateOverlay() {
    final root = WidgetsBinding.instance.renderViewElement;
    if (root == null) {
      return null;
    }
    OverlayState? found;
    void visit(Element e) {
      if (found != null) return;
      if (e.widget is Overlay) {
        final state = (e as StatefulElement).state;
        if (state is OverlayState) {
          found = state;
          return;
        }
      }
      e.visitChildren(visit);
    }

    root.visitChildren(visit);
    return found;
  }
}

class _SdkToastWidget extends StatelessWidget {
  final String message;
  const _SdkToastWidget({required this.message});

  @override
  Widget build(BuildContext context) {
    String text = message;
    if (text.startsWith('!!!!!')) {
      text = text.replaceFirst('!!!!!', '').trim();
    }

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: true,
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))], border: Border.all(color: Colors.white.withOpacity(0.9), width: 1)),
              child: DefaultTextStyle(style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, height: 1.2), child: Text('[Countly] $text', maxLines: 5, overflow: TextOverflow.ellipsis)),
            ),
          ),
        ),
      ),
    );
  }
}
