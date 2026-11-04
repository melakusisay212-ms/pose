import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// A tiny log that survives app crashes: every line is written to disk
/// immediately. After a crash, reopening the app shows the last lines, so we
/// can see which step was running when it died.
class Breadcrumbs {
  Breadcrumbs._();

  static final Breadcrumbs instance = Breadcrumbs._();

  static const int _keepLines = 60;

  final Stopwatch _clock = Stopwatch()..start();
  File? _file;
  String? _initProblem;

  /// Call once at startup. Never throws: a broken log must not stop the app.
  Future<void> init() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/breadcrumbs.txt');
      final history = file.existsSync() ? file.readAsLinesSync() : <String>[];
      final kept = history.length <= _keepLines
          ? history
          : history.sublist(history.length - _keepLines);
      final joined = kept.isEmpty ? '' : '${kept.join('\n')}\n';
      file.writeAsStringSync('$joined=== new run ===\n', flush: true);
      _file = file;
      add('app started');
    } on Object catch (error) {
      _initProblem = '$error';
    }
  }

  /// Writes one line and flushes it to disk straight away.
  void add(String message) {
    final file = _file;
    if (file == null) return;
    try {
      file.writeAsStringSync(
        '${_clock.elapsedMilliseconds} ms  $message\n',
        mode: FileMode.append,
        flush: true,
      );
    } on Object catch (_) {
      // Nothing useful to do if the disk write fails.
    }
  }

  /// The last [count] lines, across runs, oldest first.
  List<String> recentLines(int count) {
    final file = _file;
    if (file == null) {
      final problem = _initProblem;
      return <String>[
        problem == null ? 'Log not available.' : 'Log not available: $problem',
      ];
    }
    try {
      final lines = file.readAsLinesSync();
      return lines.length <= count
          ? lines
          : lines.sublist(lines.length - count);
    } on Object catch (error) {
      return <String>['Could not read log: $error'];
    }
  }

  void clear() {
    final file = _file;
    if (file == null) return;
    try {
      file.writeAsStringSync('', flush: true);
    } on Object catch (_) {
      // Ignore.
    }
    add('log cleared');
  }
}
