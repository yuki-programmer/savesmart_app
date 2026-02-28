import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'remote_config_service.dart';

class ReceiptVerificationResult {
  final bool active;
  final DateTime? expiresAt;
  final String? subscriptionType;
  final String? productId;
  final String? rawStatus;
  final String? error;

  const ReceiptVerificationResult({
    required this.active,
    this.expiresAt,
    this.subscriptionType,
    this.productId,
    this.rawStatus,
    this.error,
  });
}

class ReceiptVerificationService {
  ReceiptVerificationService._();
  static final ReceiptVerificationService instance =
      ReceiptVerificationService._();

  String get _verifyUrl =>
      RemoteConfigService.instance.purchaseVerifyUrl.trim();

  bool get isConfigured => _verifyUrl.isNotEmpty;

  Future<ReceiptVerificationResult> verifyPurchase({
    required String platform,
    required String productId,
    required String verificationData,
    required String verificationSource,
    String? transactionId,
    String? subscriptionType,
  }) async {
    if (!isConfigured) {
      return const ReceiptVerificationResult(
        active: false,
        error: 'Verification endpoint not configured.',
      );
    }

    final uri = Uri.parse(_verifyUrl);
    final payload = <String, dynamic>{
      'platform': platform,
      'productId': productId,
      'verificationData': verificationData,
      'verificationSource': verificationSource,
      if (transactionId != null) 'transactionId': transactionId,
      if (subscriptionType != null) 'subscriptionType': subscriptionType,
    };

    String? idToken;
    try {
      var user = AuthService.instance.currentUser;
      if (user == null && AuthService.instance.isSupported) {
        user = await AuthService.instance.ensureSignedInAnonymously();
      }
      if (user != null) {
        idToken = await user.getIdToken();
      }
    } catch (_) {
      // Optional: proceed without auth token
    }

    try {
      final response = await http.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json',
          if (idToken != null) 'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return ReceiptVerificationResult(
          active: false,
          error: 'Verification failed: ${response.statusCode}',
        );
      }

      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        return const ReceiptVerificationResult(
          active: false,
          error: 'Invalid verification response.',
        );
      }

      final active = _parseActive(body);
      final expiresAt = _parseExpiresAt(body);
      final subscriptionType =
          (body['subscriptionType'] as String?)?.trim().isNotEmpty == true
              ? body['subscriptionType'] as String
              : null;
      final productId =
          (body['productId'] as String?)?.trim().isNotEmpty == true
              ? body['productId'] as String
              : null;
      final rawStatus = body['status']?.toString();

      return ReceiptVerificationResult(
        active: active,
        expiresAt: expiresAt,
        subscriptionType: subscriptionType,
        productId: productId,
        rawStatus: rawStatus,
      );
    } catch (e) {
      debugPrint('ReceiptVerification: error $e');
      return ReceiptVerificationResult(
        active: false,
        error: e.toString(),
      );
    }
  }

  bool _parseActive(Map<String, dynamic> body) {
    final activeValue = body['active'];
    if (activeValue is bool) return activeValue;

    final isActiveValue = body['isActive'];
    if (isActiveValue is bool) return isActiveValue;

    final status = body['status'];
    if (status is String) {
      return status.toLowerCase() == 'active';
    }

    return false;
  }

  DateTime? _parseExpiresAt(Map<String, dynamic> body) {
    final candidates = [
      body['expiresAt'],
      body['expiryDate'],
      body['expirationDate'],
      body['expires_date'],
      body['expires_date_ms'],
    ];

    for (final candidate in candidates) {
      if (candidate == null) continue;
      if (candidate is int) {
        return DateTime.fromMillisecondsSinceEpoch(candidate);
      }
      if (candidate is String) {
        final ms = int.tryParse(candidate);
        if (ms != null) {
          return DateTime.fromMillisecondsSinceEpoch(ms);
        }
        final parsed = DateTime.tryParse(candidate);
        if (parsed != null) return parsed.toUtc();
      }
    }
    return null;
  }
}
