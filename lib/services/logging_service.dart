import 'dart:collection';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Very small logging helper to reduce noisy repeated prints during startup
/// - debug(): rate-limited in debug builds
/// - info()/error(): always printed (but still obey kDebugMode for debug formatting)
class LoggingService {
  static final LoggingService _instance = LoggingService._internal();
  factory LoggingService() => _instance;
  LoggingService._internal();

  // Map of message key -> last logged timestamp (ms)
  final Map<String, int> _lastLogged = HashMap();

  void debug(String message, {int throttleMs = 3000, bool force = false}) {
    if (!kDebugMode && !force) return; // Only debug in debug builds unless forced

    final key = _shortKey(message);
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _lastLogged[key] ?? 0;
    if (force || now - last >= throttleMs) {
      _lastLogged[key] = now;
      developer.log(message, name: 'RoadAid.debug', level: 800);
      // Also print for logcat visibility in debug mode
      // keep a simple print as fallback
      // ignore: avoid_print
      print(message);
    }
  }

  void info(String message) {
    developer.log(message, name: 'RoadAid.info', level: 800);
    // ignore: avoid_print
    print(message);
  }

  void error(String message) {
    developer.log(message, name: 'RoadAid.error', level: 1000);
    // ignore: avoid_print
    print(message);
  }

  String _shortKey(String message) {
    // Shorten long messages used as keys: use first 120 chars
    if (message.length <= 120) return message;
    return message.substring(0, 120);
  }
}
