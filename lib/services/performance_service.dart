import 'dart:io';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/widgets.dart';

/// Firebase Performance Monitoring サービス
/// 画面遷移やカスタム処理のパフォーマンスを計測
class PerformanceService {
  PerformanceService._();
  static final PerformanceService _instance = PerformanceService._();
  static PerformanceService get instance => _instance;

  FirebasePerformance? _performance;
  bool _enabled = false;

  // アクティブなトレース（画面ごと）
  final Map<String, Trace> _activeTraces = {};

  /// 初期化
  Future<void> initialize() async {
    // デスクトップでは無効
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      debugPrint('PerformanceService: disabled on desktop');
      return;
    }

    _performance = FirebasePerformance.instance;
    _enabled = true;

    // データ収集を有効化（デバッグモードでも計測）
    await _performance?.setPerformanceCollectionEnabled(true);

    debugPrint('PerformanceService: initialized');
  }

  /// 画面表示開始をトレース
  /// 画面のinitStateで呼び出す
  void startScreenTrace(String screenName) {
    if (!_enabled) return;

    final traceName = 'screen_$screenName';

    // 既存のトレースがあれば停止
    if (_activeTraces.containsKey(traceName)) {
      _activeTraces[traceName]?.stop();
      _activeTraces.remove(traceName);
    }

    final trace = _performance?.newTrace(traceName);
    trace?.start();
    _activeTraces[traceName] = trace!;

    debugPrint('PerformanceService: started trace $traceName');
  }

  /// 画面表示完了をマーク
  /// 画面の初回描画完了後に呼び出す
  void stopScreenTrace(String screenName) {
    if (!_enabled) return;

    final traceName = 'screen_$screenName';
    final trace = _activeTraces[traceName];

    if (trace != null) {
      trace.stop();
      _activeTraces.remove(traceName);
      debugPrint('PerformanceService: stopped trace $traceName');
    }
  }

  /// カスタムトレースを開始
  /// 任意の処理の計測に使用
  Trace? startCustomTrace(String name) {
    if (!_enabled) return null;

    final trace = _performance?.newTrace(name);
    trace?.start();
    return trace;
  }

  /// カスタムトレースを停止
  void stopCustomTrace(Trace? trace) {
    trace?.stop();
  }

  /// カスタム属性を追加（トレースに付加情報を追加）
  void setTraceAttribute(Trace? trace, String key, String value) {
    trace?.putAttribute(key, value);
  }

  /// カスタムメトリクスを追加（数値データ）
  void setTraceMetric(Trace? trace, String name, int value) {
    trace?.setMetric(name, value);
  }

  /// HTTPリクエストのメトリクス（自動計測だが、手動でも可能）
  HttpMetric? startHttpMetric(String url, HttpMethod method) {
    if (!_enabled) return null;
    return _performance?.newHttpMetric(url, method);
  }
}

/// 画面トレース用のMixin
/// StatefulWidgetで使用して画面表示時間を自動計測
mixin ScreenTraceMixin<T extends StatefulWidget> on State<T> {
  String get screenTraceName;

  @override
  void initState() {
    super.initState();
    PerformanceService.instance.startScreenTrace(screenTraceName);

    // 初回フレーム描画後にトレース終了
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PerformanceService.instance.stopScreenTrace(screenTraceName);
    });
  }
}
