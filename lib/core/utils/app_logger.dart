import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Debug-only logging and tracing.
///
/// Logging is OFF unless the app is a debug build started with
/// `--dart-define=APP_LOGS=true` (the "The Audit (debug + logs)" launch
/// configuration in .vscode/launch.json does this). A plain `flutter run`
/// shows no app logs, and release/profile builds compile the logging out
/// entirely because [AppLogger.enabled] is a compile-time constant.
/// Output goes to `dart:developer` (filterable by tag in DevTools' Logging
/// view) and to the console.
///
/// Usage, one logger per class:
/// ```dart
/// static final _log = AppLogger('PreFieldDao');
///
/// _log.d('Loading sessions');
/// final id = await _log.trace('createFieldSession', () => ...);
/// _log.e('Save failed', error, stackTrace);
/// ```
///
/// Never log passwords, tokens or other secrets; mask emails with
/// [AppLogger.mask].
class AppLogger {
  /// True only for debug builds run with `--dart-define=APP_LOGS=true`.
  static const bool enabled = kDebugMode && bool.fromEnvironment('APP_LOGS');

  final String tag;

  const AppLogger(this.tag);

  /// Fine-grained steps (method entry, loop details).
  void t(String message) => _log(LogLevel.trace, message);

  /// Developer-useful detail (loaded counts, chosen branches).
  void d(String message) => _log(LogLevel.debug, message);

  /// Notable events (session created, user logged in).
  void i(String message) => _log(LogLevel.info, message);

  /// Recoverable problems (permission denied, fallback used).
  void w(String message, [Object? error, StackTrace? stackTrace]) =>
      _log(LogLevel.warning, message, error, stackTrace);

  /// Failures.
  void e(String message, [Object? error, StackTrace? stackTrace]) =>
      _log(LogLevel.error, message, error, stackTrace);

  /// Runs [action], logging start, finish with duration, or failure. Also
  /// records a timeline event so it shows up in DevTools' Performance view.
  /// In non-debug builds it just runs [action].
  Future<T> trace<T>(String operation, Future<T> Function() action) async {
    if (!enabled) return action();

    final name = '$tag.$operation';
    final watch = Stopwatch()..start();
    final task = developer.TimelineTask()..start(name);
    _log(LogLevel.trace, '→ $operation');
    try {
      final result = await action();
      _log(LogLevel.trace, '← $operation (${watch.elapsedMilliseconds} ms)');
      return result;
    } catch (error, stackTrace) {
      _log(
        LogLevel.error,
        '✗ $operation failed after ${watch.elapsedMilliseconds} ms',
        error,
        stackTrace,
      );
      rethrow;
    } finally {
      task.finish();
    }
  }

  /// Synchronous version of [trace].
  T traceSync<T>(String operation, T Function() action) {
    if (!enabled) return action();

    final watch = Stopwatch()..start();
    _log(LogLevel.trace, '→ $operation');
    try {
      final result = developer.Timeline.timeSync('$tag.$operation', action);
      _log(LogLevel.trace, '← $operation (${watch.elapsedMilliseconds} ms)');
      return result;
    } catch (error, stackTrace) {
      _log(LogLevel.error, '✗ $operation failed', error, stackTrace);
      rethrow;
    }
  }

  /// `shruti@example.com` -> `sh***@example.com`.
  static String mask(String? email) {
    if (email == null || email.isEmpty) return '<none>';
    final at = email.indexOf('@');
    if (at <= 2) return '***${at >= 0 ? email.substring(at) : ''}';
    return '${email.substring(0, 2)}***${email.substring(at)}';
  }

  void _log(
    LogLevel level,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    if (!enabled) return;

    final time = DateTime.now().toIso8601String().substring(11, 23);
    developer.log(
      message,
      time: DateTime.now(),
      level: level.value,
      name: tag,
      error: error,
      stackTrace: stackTrace,
    );
    // Console copy so logs show in `flutter run` / IDE debug console too.
    debugPrint('$time ${level.label} [$tag] $message');
    if (error != null)
      debugPrint('$time ${level.label} [$tag]   error: $error');
    if (stackTrace != null && level == LogLevel.error) {
      debugPrintStack(stackTrace: stackTrace, maxFrames: 8);
    }
  }
}

enum LogLevel {
  // Values follow package:logging, which DevTools understands.
  trace(300, 'TRACE'),
  debug(500, 'DEBUG'),
  info(800, 'INFO '),
  warning(900, 'WARN '),
  error(1000, 'ERROR');

  final int value;
  final String label;

  const LogLevel(this.value, this.label);
}

/// Logs every Cubit creation, state change, error and close (debug only).
class AppBlocObserver extends BlocObserver {
  static const _log = AppLogger('Bloc');

  @override
  void onCreate(BlocBase<dynamic> bloc) {
    super.onCreate(bloc);
    _log.t('created ${bloc.runtimeType}');
  }

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    _log.d(
      '${bloc.runtimeType}: ${_summary(change.currentState)} → '
      '${_summary(change.nextState)}',
    );
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    _log.e('${bloc.runtimeType} error', error, stackTrace);
    super.onError(bloc, error, stackTrace);
  }

  @override
  void onClose(BlocBase<dynamic> bloc) {
    super.onClose(bloc);
    _log.t('closed ${bloc.runtimeType}');
  }

  /// States can be large (lists of records); keep each log line short.
  static String _summary(Object? state) {
    final text = state.toString();
    return text.length <= 200 ? text : '${text.substring(0, 200)}…';
  }
}

/// Logs every screen push / pop / replace (debug only).
class AppRouteLogger extends NavigatorObserver {
  static const _log = AppLogger('Navigation');

  static String _name(Route<dynamic>? route) =>
      route?.settings.name ?? route?.runtimeType.toString() ?? '<none>';

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _log.i('push ${_name(route)} (from ${_name(previousRoute)})');

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _log.i('pop ${_name(route)} (back to ${_name(previousRoute)})');

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _log.i('replace ${_name(oldRoute)} with ${_name(newRoute)}');

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _log.d('remove ${_name(route)}');
}
