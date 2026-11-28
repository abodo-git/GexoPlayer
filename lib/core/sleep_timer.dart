import 'dart:async';

import 'package:clock/clock.dart';

/// Counts down and calls [onFire] once. Pure Dart; tested with fakeAsync.
class GxSleepTimer {
  final void Function() onFire;
  final void Function()? onTick;
  Timer? _timer;
  DateTime? _end;
  final DateTime Function() _now;

  GxSleepTimer({required this.onFire, this.onTick, DateTime Function()? now})
      : _now = now ?? (() => clock.now());

  bool get active => _timer != null;

  Duration? get remaining {
    if (_end == null) return null;
    final r = _end!.difference(_now());
    return r.isNegative ? Duration.zero : r;
  }

  void start(Duration d) {
    cancel();
    _end = _now().add(d);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (remaining! <= Duration.zero) {
        cancel();
        onFire();
      }
      onTick?.call();
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _end = null;
  }
}
