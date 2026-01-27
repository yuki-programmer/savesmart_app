import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Firebase Remote Config サービス
/// アプリの設定をリモートで管理し、アプリ更新なしで変更可能
class RemoteConfigService {
  RemoteConfigService._();
  static final RemoteConfigService _instance = RemoteConfigService._();
  static RemoteConfigService get instance => _instance;

  late final FirebaseRemoteConfig _remoteConfig;
  bool _initialized = false;

  // === Config Keys ===
  static const String keyMaintenanceMode = 'maintenance_mode';
  static const String keyMaintenanceMessage = 'maintenance_message';
  static const String keyMinAppVersion = 'min_app_version';
  static const String keyPremiumMonthlyPrice = 'premium_monthly_price';
  static const String keyPremiumYearlyPrice = 'premium_yearly_price';
  static const String keyShowNewFeatureBanner = 'show_new_feature_banner';
  static const String keyNewFeatureMessage = 'new_feature_message';

  // === Default Values ===
  static const Map<String, dynamic> _defaults = {
    keyMaintenanceMode: false,
    keyMaintenanceMessage: 'メンテナンス中です。しばらくお待ちください。',
    keyMinAppVersion: '1.0.0',
    keyPremiumMonthlyPrice: 400,
    keyPremiumYearlyPrice: 3600,
    keyShowNewFeatureBanner: false,
    keyNewFeatureMessage: '',
  };

  /// 初期化
  Future<void> initialize() async {
    if (_initialized) return;

    _remoteConfig = FirebaseRemoteConfig.instance;

    // フェッチ設定（開発中は短く、本番は長めに）
    await _remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(minutes: 1),
      minimumFetchInterval: kDebugMode
          ? const Duration(minutes: 5)
          : const Duration(hours: 12),
    ));

    // デフォルト値を設定
    await _remoteConfig.setDefaults(_defaults);

    // 値をフェッチしてアクティベート
    try {
      await _remoteConfig.fetchAndActivate();
      debugPrint('RemoteConfig: fetched and activated');
    } catch (e) {
      debugPrint('RemoteConfig: fetch failed, using defaults: $e');
    }

    _initialized = true;
  }

  /// 手動でフェッチ＆アクティベート
  Future<bool> fetchAndActivate() async {
    try {
      return await _remoteConfig.fetchAndActivate();
    } catch (e) {
      debugPrint('RemoteConfig: manual fetch failed: $e');
      return false;
    }
  }

  // === Getters ===

  /// メンテナンスモードかどうか
  bool get isMaintenanceMode => _remoteConfig.getBool(keyMaintenanceMode);

  /// メンテナンスメッセージ
  String get maintenanceMessage => _remoteConfig.getString(keyMaintenanceMessage);

  /// 最低アプリバージョン
  String get minAppVersion => _remoteConfig.getString(keyMinAppVersion);

  /// プレミアム月額価格（円）
  int get premiumMonthlyPrice => _remoteConfig.getInt(keyPremiumMonthlyPrice);

  /// プレミアム年額価格（円）
  int get premiumYearlyPrice => _remoteConfig.getInt(keyPremiumYearlyPrice);

  /// 新機能バナーを表示するか
  bool get showNewFeatureBanner => _remoteConfig.getBool(keyShowNewFeatureBanner);

  /// 新機能メッセージ
  String get newFeatureMessage => _remoteConfig.getString(keyNewFeatureMessage);
}
