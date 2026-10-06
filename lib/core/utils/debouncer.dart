import 'dart:async';

/// Runs an action once typing has paused.
///
/// Each call replaces the pending one, so a burst of keystrokes produces a single
/// callback — with the latest value — [delay] after the last of them.
class Debouncer {
  Debouncer(this.delay);

  final Duration delay;
  Timer? _timer;

  void call(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// Drop whatever is pending (the person submitted, or left the screen).
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  bool get isPending => _timer?.isActive ?? false;
}
