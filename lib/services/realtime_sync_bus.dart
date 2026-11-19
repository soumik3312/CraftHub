import 'dart:async';

/// In-process fan-out for authenticated server change events.
class RealtimeSyncBus {
  RealtimeSyncBus._();

  static final StreamController<Map<String, dynamic>> _controller =
      StreamController<Map<String, dynamic>>.broadcast();

  static Stream<Map<String, dynamic>> get events => _controller.stream;

  static void emit(dynamic raw) {
    if (raw is! Map) return;
    _controller.add(Map<String, dynamic>.from(raw));
  }
}
