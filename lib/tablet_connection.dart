import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Connection is a hardware fact, separate from pen proximity or observed input.
class TabletConnection extends ChangeNotifier {
  static const methods = MethodChannel('novi/tablets');
  static const events = EventChannel('novi/tablets/events');
  StreamSubscription<dynamic>? _subscription;
  bool available = false;
  Set<String> deviceIds = {};
  bool penObserved = false;
  bool get connected => deviceIds.isNotEmpty;
  bool get showHand => connected || penObserved;
  String get description => connected
      ? '${deviceIds.length} tablet(s) connected'
      : penObserved
      ? 'Pen observed · hardware identity unavailable'
      : available
      ? 'No tablet connected'
      : 'Tablet detection unavailable';
  Future<void> start() async {
    if (defaultTargetPlatform != TargetPlatform.macOS) return;
    _subscription = events.receiveBroadcastStream().listen(
      (value) => apply(value),
      onError: (_) {
        available = false;
        notifyListeners();
      },
    );
    try {
      apply(await methods.invokeMethod<dynamic>('getState'));
    } on PlatformException {
      available = false;
      notifyListeners();
    } on MissingPluginException {
      available = false;
      notifyListeners();
    }
  }

  void apply(dynamic value) {
    if (value is! Map) return;
    final wasConnected = connected;
    available = value['available'] == true;
    deviceIds = ((value['devices'] as List?) ?? [])
        .map((d) => d.toString())
        .toSet();
    if (wasConnected && !connected) penObserved = false;
    notifyListeners();
  }

  void observePen() {
    if (!penObserved) {
      penObserved = true;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
