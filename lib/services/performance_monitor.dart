import 'package:flutter/foundation.dart';

/// パフォーマンス計測サービス
/// DEV_TOOLS=true の場合のみ有効
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  final Map<String, List<int>> _measurements = {};
  final Map<String, Stopwatch> _activeTimers = {};
  bool _enabled = false;

  /// 計測を有効化
  void enable() => _enabled = true;

  /// 計測を無効化
  void disable() => _enabled = false;

  bool get isEnabled => _enabled;

  /// 計測開始
  void startTimer(String name) {
    if (!_enabled) return;
    _activeTimers[name] = Stopwatch()..start();
  }

  /// 計測終了して記録
  int? stopTimer(String name) {
    if (!_enabled) return null;
    final timer = _activeTimers.remove(name);
    if (timer == null) return null;

    timer.stop();
    final elapsed = timer.elapsedMilliseconds;

    _measurements.putIfAbsent(name, () => []);
    _measurements[name]!.add(elapsed);

    // デバッグ出力
    if (kDebugMode) {
      debugPrint('⏱️ [$name] ${elapsed}ms');
    }

    return elapsed;
  }

  /// 同期処理の計測
  T measure<T>(String name, T Function() action) {
    if (!_enabled) return action();

    startTimer(name);
    final result = action();
    stopTimer(name);
    return result;
  }

  /// 非同期処理の計測
  Future<T> measureAsync<T>(String name, Future<T> Function() action) async {
    if (!_enabled) return action();

    startTimer(name);
    final result = await action();
    stopTimer(name);
    return result;
  }

  /// 特定の計測の統計を取得
  Map<String, dynamic>? getStats(String name) {
    final measurements = _measurements[name];
    if (measurements == null || measurements.isEmpty) return null;

    final sorted = List<int>.from(measurements)..sort();
    final count = sorted.length;
    final sum = sorted.fold(0, (a, b) => a + b);
    final avg = sum / count;
    final min = sorted.first;
    final max = sorted.last;
    final median = count.isOdd
        ? sorted[count ~/ 2]
        : (sorted[count ~/ 2 - 1] + sorted[count ~/ 2]) / 2;

    return {
      'name': name,
      'count': count,
      'avg': avg.round(),
      'min': min,
      'max': max,
      'median': median.round(),
      'total': sum,
    };
  }

  /// 全計測の統計を取得
  List<Map<String, dynamic>> getAllStats() {
    return _measurements.keys
        .map((name) => getStats(name))
        .whereType<Map<String, dynamic>>()
        .toList()
      ..sort((a, b) => (b['total'] as int).compareTo(a['total'] as int));
  }

  /// 計測データをリセット
  void reset() {
    _measurements.clear();
    _activeTimers.clear();
  }

  /// レポートを文字列で取得
  String getReport() {
    final stats = getAllStats();
    if (stats.isEmpty) return '計測データなし';

    final buffer = StringBuffer();
    buffer.writeln('=== パフォーマンスレポート ===');
    buffer.writeln('');

    for (final stat in stats) {
      buffer.writeln('📊 ${stat['name']}');
      buffer.writeln('   回数: ${stat['count']}回');
      buffer.writeln('   平均: ${stat['avg']}ms');
      buffer.writeln('   最小: ${stat['min']}ms / 最大: ${stat['max']}ms');
      buffer.writeln('   中央値: ${stat['median']}ms');
      buffer.writeln('   合計: ${stat['total']}ms');
      buffer.writeln('');
    }

    return buffer.toString();
  }
}

/// グローバルインスタンス
final perfMonitor = PerformanceMonitor();
