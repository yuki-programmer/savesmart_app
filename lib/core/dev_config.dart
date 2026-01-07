import 'package:flutter/foundation.dart';

/// 開発者機能のゲート設定
///
/// DEV_TOOLS を dart-define から読み取り、
/// Release ビルドでは一切の開発者機能を無効化する。
///
/// 実行コマンド:
/// ```
/// flutter run --dart-define=DEV_TOOLS=true
/// ```
class DevConfig {
  DevConfig._();

  /// dart-define で DEV_TOOLS=true が指定されているか
  static const bool devToolsEnabled =
      bool.fromEnvironment('DEV_TOOLS', defaultValue: false);

  /// 開発者ツールを表示できるか
  /// - Release ビルドでは常に false
  /// - Debug/Profile でも DEV_TOOLS=true が必要
  static bool get canShowDevTools => !kReleaseMode && devToolsEnabled;
}
