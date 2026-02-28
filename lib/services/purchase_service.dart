import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'receipt_verification_service.dart';
import 'remote_config_service.dart';

class PurchaseConfirmation {
  final String productId;
  final String subscriptionType;
  final String signature;
  final DateTime? purchasedAt;

  const PurchaseConfirmation({
    required this.productId,
    required this.subscriptionType,
    required this.signature,
    required this.purchasedAt,
  });

  factory PurchaseConfirmation.fromPurchaseDetails(
    PurchaseDetails details, {
    required String subscriptionType,
  }) {
    String signature = details.purchaseID ?? '';
    if (signature.isEmpty) {
      signature = details.transactionDate ?? '';
    }
    if (signature.isEmpty) {
      signature = details.verificationData.serverVerificationData;
    }
    if (signature.isEmpty) {
      signature = details.verificationData.localVerificationData;
    }

    DateTime? purchasedAt;
    final transactionDate = details.transactionDate;
    if (transactionDate != null) {
      final millis = int.tryParse(transactionDate);
      if (millis != null) {
        purchasedAt = DateTime.fromMillisecondsSinceEpoch(millis);
      }
    }

    return PurchaseConfirmation(
      productId: details.productID,
      subscriptionType: subscriptionType,
      signature: signature,
      purchasedAt: purchasedAt,
    );
  }
}

/// アプリ内購入を管理するサービス
class PurchaseService {
  static final PurchaseService _instance = PurchaseService._internal();
  static PurchaseService get instance => _instance;
  PurchaseService._internal();

  // 商品ID（App Store Connectで登録する必要あり）
  static const String monthlyProductId = 'savesmart_premium_monthly';
  static const String yearlyProductId = 'savesmart_premium_yearly';
  static const Set<String> _productIds = {monthlyProductId, yearlyProductId};

  // SharedPreferences キー
  static const String _premiumStatusKey = 'is_premium';
  static const String _subscriptionTypeKey = 'subscription_type';
  static const String _premiumExpiryKey = 'premium_expiry';
  static const String _lastVerifiedAtKey = 'premium_last_verified_at';
  static const String _lastReceiptKey = 'premium_last_receipt';
  static const String _lastReceiptProductIdKey = 'premium_last_product_id';
  static const String _lastReceiptPlatformKey = 'premium_last_platform';
  static const String _lastReceiptSourceKey = 'premium_last_receipt_source';
  static const String _lastReceiptTransactionIdKey =
      'premium_last_transaction_id';

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // 購入可能な商品リスト
  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  // 購入状態
  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;

  bool _isPremium = false;
  bool get isPremium => _isPremium && !_isExpired();

  String? _subscriptionType; // 'monthly' or 'yearly'
  String? get subscriptionType => _subscriptionType;

  DateTime? _premiumExpiry;
  DateTime? get premiumExpiry => _premiumExpiry;

  DateTime? _lastVerifiedAt;
  DateTime? get lastVerifiedAt => _lastVerifiedAt;

  String? _lastReceipt;
  String? _lastReceiptProductId;
  String? _lastReceiptPlatform;
  String? _lastReceiptSource;
  String? _lastReceiptTransactionId;

  // 購入処理中フラグ
  bool _isPurchasing = false;
  bool get isPurchasing => _isPurchasing;

  // 状態変更通知用コールバック
  VoidCallback? onPurchaseUpdated;
  void Function(PurchaseConfirmation confirmation)? onPurchaseConfirmed;

  /// 初期化
  Future<void> initialize() async {
    // デスクトップでは無効化
    if (!Platform.isIOS && !Platform.isAndroid) {
      debugPrint('PurchaseService: Not supported on this platform');
      await _loadCachedStatus();
      return;
    }

    _isAvailable = await _inAppPurchase.isAvailable();
    if (!_isAvailable) {
      debugPrint('PurchaseService: Store not available');
      await _loadCachedStatus();
      return;
    }

    // 購入ストリームを購読
    _subscription = _inAppPurchase.purchaseStream.listen(
      _onPurchaseUpdated,
      onDone: _onPurchaseStreamDone,
      onError: _onPurchaseStreamError,
    );

    // 商品情報を取得
    await _loadProducts();

    // キャッシュされた購入状態を読み込み
    await _loadCachedStatus();

    // 可能なら検証を再実行（期限切れ反映）
    await _refreshVerificationIfNeeded();

    debugPrint('PurchaseService: Initialized, isPremium=$_isPremium');
  }

  /// 商品情報を取得
  Future<void> _loadProducts() async {
    final response = await _inAppPurchase.queryProductDetails(_productIds);

    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('PurchaseService: Products not found: ${response.notFoundIDs}');
    }

    _products = response.productDetails;
    debugPrint('PurchaseService: Loaded ${_products.length} products');
  }

  /// キャッシュされた購入状態を読み込み
  Future<void> _loadCachedStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _isPremium = prefs.getBool(_premiumStatusKey) ?? false;
    _subscriptionType = prefs.getString(_subscriptionTypeKey);
    final expiryMs = prefs.getInt(_premiumExpiryKey);
    if (expiryMs != null) {
      _premiumExpiry = DateTime.fromMillisecondsSinceEpoch(expiryMs);
      if (_isExpired()) {
        _isPremium = false;
        _subscriptionType = null;
      }
    }
    final lastVerifiedMs = prefs.getInt(_lastVerifiedAtKey);
    if (lastVerifiedMs != null) {
      _lastVerifiedAt = DateTime.fromMillisecondsSinceEpoch(lastVerifiedMs);
    }
    _lastReceipt = prefs.getString(_lastReceiptKey);
    _lastReceiptProductId = prefs.getString(_lastReceiptProductIdKey);
    _lastReceiptPlatform = prefs.getString(_lastReceiptPlatformKey);
    _lastReceiptSource = prefs.getString(_lastReceiptSourceKey);
    _lastReceiptTransactionId = prefs.getString(_lastReceiptTransactionIdKey);
  }

  /// 購入状態をキャッシュに保存
  Future<void> _savePurchaseStatus({
    required bool isPremium,
    String? subscriptionType,
    DateTime? premiumExpiry,
    DateTime? lastVerifiedAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumStatusKey, isPremium);
    if (subscriptionType != null) {
      await prefs.setString(_subscriptionTypeKey, subscriptionType);
    } else {
      await prefs.remove(_subscriptionTypeKey);
    }
    if (premiumExpiry != null) {
      await prefs.setInt(
        _premiumExpiryKey,
        premiumExpiry.millisecondsSinceEpoch,
      );
    } else {
      await prefs.remove(_premiumExpiryKey);
    }
    if (lastVerifiedAt != null) {
      await prefs.setInt(
        _lastVerifiedAtKey,
        lastVerifiedAt.millisecondsSinceEpoch,
      );
    }

    _isPremium = isPremium;
    _subscriptionType = subscriptionType;
    _premiumExpiry = premiumExpiry;
    _lastVerifiedAt = lastVerifiedAt;
    onPurchaseUpdated?.call();
  }

  /// 月額プランを購入
  Future<bool> purchaseMonthly() async {
    return _purchase(monthlyProductId);
  }

  /// 年額プランを購入
  Future<bool> purchaseYearly() async {
    return _purchase(yearlyProductId);
  }

  /// 購入処理
  Future<bool> _purchase(String productId) async {
    if (_isPurchasing) {
      debugPrint('PurchaseService: Already purchasing');
      return false;
    }

    final product = _products.firstWhere(
      (p) => p.id == productId,
      orElse: () => throw Exception('Product not found: $productId'),
    );

    _isPurchasing = true;
    onPurchaseUpdated?.call();

    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      final success = await _inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );
      if (!success) {
        _isPurchasing = false;
        onPurchaseUpdated?.call();
      }
      return success;
    } catch (e) {
      debugPrint('PurchaseService: Purchase error: $e');
      _isPurchasing = false;
      onPurchaseUpdated?.call();
      return false;
    }
  }

  /// 購入を復元
  Future<void> restorePurchases() async {
    if (!_isAvailable) {
      debugPrint('PurchaseService: Store not available for restore');
      return;
    }

    _isPurchasing = true;
    onPurchaseUpdated?.call();

    try {
      await _inAppPurchase.restorePurchases();
    } catch (e) {
      debugPrint('PurchaseService: Restore error: $e');
      _isPurchasing = false;
      onPurchaseUpdated?.call();
    }
  }

  /// 購入ストリームのハンドラ
  void _onPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchaseDetails in purchaseDetailsList) {
      _handlePurchase(purchaseDetails);
    }
  }

  /// 個別の購入を処理
  Future<void> _handlePurchase(PurchaseDetails purchaseDetails) async {
    debugPrint(
      'PurchaseService: Purchase update - '
      'productID=${purchaseDetails.productID}, '
      'status=${purchaseDetails.status}',
    );

    switch (purchaseDetails.status) {
      case PurchaseStatus.pending:
        // 処理中
        _isPurchasing = true;
        onPurchaseUpdated?.call();
        break;

      case PurchaseStatus.purchased:
        // 購入成功または復元成功
        final subscriptionType = purchaseDetails.productID == monthlyProductId
            ? 'monthly'
            : 'yearly';
        final verified = await _verifyAndApply(
          purchaseDetails: purchaseDetails,
          subscriptionType: subscriptionType,
        );
        if (!verified) {
          debugPrint('PurchaseService: Verification skipped or failed');
        }

        onPurchaseConfirmed?.call(
          PurchaseConfirmation.fromPurchaseDetails(
            purchaseDetails,
            subscriptionType: subscriptionType,
          ),
        );

        _isPurchasing = false;

        // トランザクションを完了
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }

        onPurchaseUpdated?.call();
        break;

      case PurchaseStatus.restored:
        // 復元成功（状態のみ復元）
        final subscriptionType = purchaseDetails.productID == monthlyProductId
            ? 'monthly'
            : 'yearly';
        final verified = await _verifyAndApply(
          purchaseDetails: purchaseDetails,
          subscriptionType: subscriptionType,
        );
        if (!verified) {
          debugPrint('PurchaseService: Verification skipped or failed');
        }

        _isPurchasing = false;

        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }

        onPurchaseUpdated?.call();
        break;

      case PurchaseStatus.error:
        // エラー
        debugPrint('PurchaseService: Error: ${purchaseDetails.error}');
        _isPurchasing = false;
        onPurchaseUpdated?.call();

        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
        break;

      case PurchaseStatus.canceled:
        // キャンセル
        _isPurchasing = false;
        onPurchaseUpdated?.call();

        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
        break;
    }
  }

  void _onPurchaseStreamDone() {
    _subscription?.cancel();
  }

  void _onPurchaseStreamError(Object error) {
    debugPrint('PurchaseService: Stream error: $error');
  }

  bool _isExpired() {
    if (_premiumExpiry == null) return false;
    return _premiumExpiry!.isBefore(DateTime.now());
  }

  Future<bool> _verifyAndApply({
    required PurchaseDetails purchaseDetails,
    required String subscriptionType,
  }) async {
    final verificationData = purchaseDetails.verificationData;
    final payload = verificationData.serverVerificationData.isNotEmpty
        ? verificationData.serverVerificationData
        : verificationData.localVerificationData;
    final source = verificationData.source;

    if (payload.isEmpty) {
      debugPrint('PurchaseService: No verification data available, skip verify');
      return _applyFallbackEntitlement(subscriptionType);
    }

    await _cacheLastReceipt(
      payload: payload,
      productId: purchaseDetails.productID,
      platform: _platformName(),
      source: source,
      transactionId: purchaseDetails.purchaseID,
    );

    final verifier = ReceiptVerificationService.instance;
    if (!verifier.isConfigured) {
      debugPrint('PurchaseService: Verification endpoint not configured, skip');
      return _applyFallbackEntitlement(subscriptionType);
    }

    final result = await verifier.verifyPurchase(
      platform: _platformName(),
      productId: purchaseDetails.productID,
      verificationData: payload,
      verificationSource: source,
      transactionId: purchaseDetails.purchaseID,
      subscriptionType: subscriptionType,
    );

    if (result.active) {
      await _savePurchaseStatus(
        isPremium: true,
        subscriptionType: result.subscriptionType ?? subscriptionType,
        premiumExpiry: result.expiresAt,
        lastVerifiedAt: DateTime.now(),
      );
      return true;
    }

    if (RemoteConfigService.instance.purchaseVerifyStrict) {
      await _savePurchaseStatus(
        isPremium: false,
        subscriptionType: null,
        premiumExpiry: result.expiresAt,
        lastVerifiedAt: DateTime.now(),
      );
      return false;
    }

    return _applyFallbackEntitlement(subscriptionType);
  }

  Future<bool> _applyFallbackEntitlement(String subscriptionType) async {
    await _savePurchaseStatus(
      isPremium: true,
      subscriptionType: subscriptionType,
      premiumExpiry: null,
      lastVerifiedAt: _lastVerifiedAt,
    );
    return true;
  }

  Future<void> _cacheLastReceipt({
    required String payload,
    required String productId,
    required String platform,
    required String source,
    String? transactionId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastReceiptKey, payload);
    await prefs.setString(_lastReceiptProductIdKey, productId);
    await prefs.setString(_lastReceiptPlatformKey, platform);
    await prefs.setString(_lastReceiptSourceKey, source);
    if (transactionId != null) {
      await prefs.setString(_lastReceiptTransactionIdKey, transactionId);
    }

    _lastReceipt = payload;
    _lastReceiptProductId = productId;
    _lastReceiptPlatform = platform;
    _lastReceiptSource = source;
    _lastReceiptTransactionId = transactionId;
  }

  Future<void> _refreshVerificationIfNeeded() async {
    final verifier = ReceiptVerificationService.instance;
    if (!verifier.isConfigured) return;

    if (_lastReceipt == null ||
        _lastReceiptProductId == null ||
        _lastReceiptPlatform == null ||
        _lastReceiptSource == null) {
      return;
    }

    final cacheHours = RemoteConfigService.instance.purchaseVerifyCacheHours;
    if (_lastVerifiedAt != null) {
      final nextCheck =
          _lastVerifiedAt!.add(Duration(hours: cacheHours));
      if (DateTime.now().isBefore(nextCheck)) {
        return;
      }
    }

    final result = await verifier.verifyPurchase(
      platform: _lastReceiptPlatform!,
      productId: _lastReceiptProductId!,
      verificationData: _lastReceipt!,
      verificationSource: _lastReceiptSource!,
      transactionId: _lastReceiptTransactionId,
      subscriptionType: _subscriptionType,
    );

    if (result.active) {
      await _savePurchaseStatus(
        isPremium: true,
        subscriptionType: result.subscriptionType ?? _subscriptionType,
        premiumExpiry: result.expiresAt,
        lastVerifiedAt: DateTime.now(),
      );
    } else if (result.error == null) {
      await _savePurchaseStatus(
        isPremium: false,
        subscriptionType: null,
        premiumExpiry: result.expiresAt,
        lastVerifiedAt: DateTime.now(),
      );
    }
  }

  String _platformName() {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'unknown';
  }

  /// 月額商品を取得
  ProductDetails? get monthlyProduct {
    try {
      return _products.firstWhere((p) => p.id == monthlyProductId);
    } catch (_) {
      return null;
    }
  }

  /// 年額商品を取得
  ProductDetails? get yearlyProduct {
    try {
      return _products.firstWhere((p) => p.id == yearlyProductId);
    } catch (_) {
      return null;
    }
  }

  /// リソースを解放
  void dispose() {
    _subscription?.cancel();
  }
}
