import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

enum AppDiagnosticsLevel { info, warning, error }

class AppDiagnosticsConfig {
  const AppDiagnosticsConfig({
    required this.enabled,
    required this.maxEntries,
    required this.mirrorToConsole,
  });

  factory AppDiagnosticsConfig.fromEnvironment() {
    return AppDiagnosticsConfig(
      enabled: !kReleaseMode ||
          const bool.fromEnvironment(
            'BLIPS_DIAGNOSTICS',
            defaultValue: false,
          ),
      maxEntries: const int.fromEnvironment(
        'BLIPS_DIAGNOSTICS_MAX_ENTRIES',
        defaultValue: 200,
      ),
      mirrorToConsole: const bool.fromEnvironment(
        'BLIPS_DIAGNOSTICS_CONSOLE',
        defaultValue: false,
      ),
    );
  }

  final bool enabled;
  final int maxEntries;
  final bool mirrorToConsole;
}

class AppDiagnosticEvent {
  const AppDiagnosticEvent({
    required this.timestamp,
    required this.scope,
    required this.action,
    required this.stage,
    required this.level,
    required this.data,
    this.surface,
    this.message,
  });

  final DateTime timestamp;
  final String scope;
  final String action;
  final String stage;
  final String? surface;
  final AppDiagnosticsLevel level;
  final String? message;
  final Map<String, Object?> data;

  String get line {
    final timestampLabel =
        timestamp.toIso8601String().replaceFirst('T', ' ').substring(11, 23);
    final surfaceLabel = surface == null ? '' : ' surface=$surface';
    final messageLabel =
        message == null || message!.isEmpty ? '' : ' message="$message"';
    final dataLabel = data.isEmpty
        ? ''
        : ' data=${data.entries.map((entry) => '${entry.key}=${entry.value}').join(',')}';
    return '$timestampLabel [DIAG/${level.name.toUpperCase()}] '
        '$scope.$action.$stage$surfaceLabel$messageLabel$dataLabel';
  }
}

class AppDiagnosticsSpan {
  AppDiagnosticsSpan._({
    required AppDiagnosticsController controller,
    required String scope,
    required String action,
    required String? surface,
    required Map<String, Object?> data,
    required AppDiagnosticsLevel level,
    String? message,
  })  : _controller = controller,
        _scope = scope,
        _action = action,
        _surface = surface,
        _baseData = Map<String, Object?>.unmodifiable(data) {
    _stopwatch.start();
    _controller.record(
      scope: _scope,
      action: _action,
      stage: 'start',
      surface: _surface,
      level: level,
      message: message,
      data: _baseData,
    );
  }

  final AppDiagnosticsController _controller;
  final String _scope;
  final String _action;
  final String? _surface;
  final Map<String, Object?> _baseData;
  final Stopwatch _stopwatch = Stopwatch();

  void step(
    String stage, {
    String? message,
    AppDiagnosticsLevel level = AppDiagnosticsLevel.info,
    Map<String, Object?> data = const <String, Object?>{},
  }) {
    _controller.record(
      scope: _scope,
      action: _action,
      stage: stage,
      surface: _surface,
      level: level,
      message: message,
      data: _combineData(data),
    );
  }

  void success({
    String stage = 'success',
    String? message,
    Map<String, Object?> data = const <String, Object?>{},
  }) {
    _controller.record(
      scope: _scope,
      action: _action,
      stage: stage,
      surface: _surface,
      level: AppDiagnosticsLevel.info,
      message: message,
      data: _combineData(data),
    );
  }

  void failure(
    Object error, {
    StackTrace? stackTrace,
    String stage = 'failure',
    String? message,
    Map<String, Object?> data = const <String, Object?>{},
  }) {
    _controller.record(
      scope: _scope,
      action: _action,
      stage: stage,
      surface: _surface,
      level: AppDiagnosticsLevel.error,
      message: message,
      data: _combineData(<String, Object?>{
        ...data,
        ...diagnosticsDataForError(error),
      }),
      error: error,
      stackTrace: stackTrace,
    );
  }

  Map<String, Object?> _combineData(Map<String, Object?> data) {
    return <String, Object?>{
      ..._baseData,
      'elapsedMs': _stopwatch.elapsedMilliseconds,
      ...data,
    };
  }
}

class AppDiagnosticsController {
  AppDiagnosticsController(this.config);

  final AppDiagnosticsConfig config;
  final ListQueue<AppDiagnosticEvent> _events = ListQueue<AppDiagnosticEvent>();

  bool get isEnabled => config.enabled;

  List<AppDiagnosticEvent> get events =>
      _events.toList(growable: false).reversed.toList(growable: false);

  AppDiagnosticEvent? get latest => _events.isEmpty ? null : _events.last;

  int get count => _events.length;

  AppDiagnosticsSpan startSpan({
    required String scope,
    required String action,
    String? surface,
    String? message,
    AppDiagnosticsLevel level = AppDiagnosticsLevel.info,
    Map<String, Object?> data = const <String, Object?>{},
  }) {
    return AppDiagnosticsSpan._(
      controller: this,
      scope: scope,
      action: action,
      surface: surface,
      data: data,
      level: level,
      message: message,
    );
  }

  void record({
    required String scope,
    required String action,
    required String stage,
    String? surface,
    AppDiagnosticsLevel level = AppDiagnosticsLevel.info,
    String? message,
    Map<String, Object?> data = const <String, Object?>{},
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!config.enabled) return;

    final event = AppDiagnosticEvent(
      timestamp: DateTime.now(),
      scope: scope,
      action: action,
      stage: stage,
      surface: surface,
      level: level,
      message: message,
      data: Map<String, Object?>.unmodifiable(data),
    );

    _events.addLast(event);
    while (_events.length > config.maxEntries) {
      _events.removeFirst();
    }

    if (config.mirrorToConsole) {
      debugPrint(event.line);
      if (error != null) {
        debugPrint('  error=$error');
      }
      if (stackTrace != null && level == AppDiagnosticsLevel.error) {
        debugPrint(
          '  stack=${stackTrace.toString().split('\n').take(5).join(' | ')}',
        );
      }
    }
  }

  String exportText({int limit = 80}) {
    return events.take(limit).map((event) => event.line).join('\n');
  }

  void clear() {
    if (_events.isEmpty) return;
    _events.clear();
  }
}

Map<String, Object?> diagnosticsDataForError(Object error) {
  if (error is DioException) {
    return <String, Object?>{
      'errorType': error.runtimeType.toString(),
      'dioType': error.type.name,
      'statusCode': error.response?.statusCode,
      'path': error.requestOptions.path,
      'method': error.requestOptions.method,
      'requestMode': error.requestOptions.extra['requestMode'],
      'message': error.message,
    };
  }

  return <String, Object?>{
    'errorType': error.runtimeType.toString(),
    'message': error.toString(),
  };
}

final appDiagnosticsConfigProvider = Provider<AppDiagnosticsConfig>((ref) {
  return AppDiagnosticsConfig.fromEnvironment();
});

final appDiagnosticsProvider = Provider<AppDiagnosticsController>((ref) {
  return AppDiagnosticsController(ref.watch(appDiagnosticsConfigProvider));
});
