import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  static final AuthService instance = AuthService._internal();
  final FirebaseAuth? _auth;

  AuthService._internal() : _auth = _isSupportedPlatform ? FirebaseAuth.instance : null;

  static bool get _isSupportedPlatform {
    if (kIsWeb) return true;
    return Platform.isAndroid || Platform.isIOS;
  }

  bool get isSupported => _isSupportedPlatform;

  User? get currentUser => _auth?.currentUser;

  String get currentUid {
    if (_auth == null) {
      throw UnsupportedError('FirebaseAuth is not supported on this platform.');
    }
    final user = _auth!.currentUser;
    if (user == null) {
      throw StateError('User is not authenticated.');
    }
    return user.uid;
  }

  /// 共有機能利用時に呼ぶ。未認証なら匿名サインイン。
  Future<User> ensureSignedInAnonymously() async {
    if (_auth == null) {
      throw UnsupportedError('FirebaseAuth is not supported on this platform.');
    }
    final user = _auth!.currentUser;
    if (user != null) return user;
    final result = await _auth!.signInAnonymously();
    return result.user!;
  }
}
