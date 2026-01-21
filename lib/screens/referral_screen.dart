import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../config/theme.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  static const _codeLength = 16;
  static const _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  final _codeController = TextEditingController();
  String? _referralCode;
  bool _loading = true;
  bool _submitting = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _initReferralData();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _initReferralData() async {
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) {
        await auth.signInAnonymously();
      }
      final user = auth.currentUser;
      if (user == null) return;

      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final snapshot = await userRef.get();
      if (snapshot.exists) {
        final data = snapshot.data();
        final code = data?['referralCode'] as String?;
        if (code != null && code.isNotEmpty) {
          setState(() {
            _referralCode = code;
            _loading = false;
          });
          return;
        }
      }

      final newCode = await _registerReferralCode(userRef);
      if (!mounted) return;
      setState(() {
        _referralCode = newCode;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _statusMessage = '紹介コードの作成に失敗しました。時間をおいて再度お試しください。';
      });
    }
  }

  Future<String> _registerReferralCode(DocumentReference<Map<String, dynamic>> userRef) async {
    final firestore = FirebaseFirestore.instance;
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = _generateCode();
      try {
        return await firestore.runTransaction((transaction) async {
          final codeRef = firestore.collection('referral_codes').doc(code);
          final codeSnapshot = await transaction.get(codeRef);
          if (codeSnapshot.exists) {
            throw StateError('Code already exists');
          }
          transaction.set(codeRef, {
            'ownerUid': userRef.id,
            'createdAt': FieldValue.serverTimestamp(),
            'disabled': false,
          });
          transaction.set(userRef, {
            'createdAt': FieldValue.serverTimestamp(),
            'referralCode': code,
          }, SetOptions(merge: true));
          return code;
        });
      } catch (_) {
        if (attempt == 4) rethrow;
      }
    }
    throw StateError('Failed to generate referral code');
  }

  String _generateCode() {
    final random = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < _codeLength; i++) {
      buffer.write(_codeChars[random.nextInt(_codeChars.length)]);
    }
    return buffer.toString();
  }

  Future<void> _applyReferralCode() async {
    if (_submitting) return;
    final raw = _codeController.text.trim().toUpperCase();
    final code = raw.replaceAll(RegExp(r'[^A-Z0-9]'), '');

    if (code.isEmpty) {
      _showMessage('紹介コードを入力してください。');
      return;
    }

    if (_referralCode != null && code == _referralCode) {
      _showMessage('自分の紹介コードは使えません。');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage('ログイン状態を確認できませんでした。');
      return;
    }

    setState(() {
      _submitting = true;
    });

    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(user.uid);
    final codeRef = firestore.collection('referral_codes').doc(code);

    try {
      await firestore.runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userRef);
        final userData = userSnapshot.data();
        if (userData != null && userData['referredBy'] != null) {
          throw StateError('already_applied');
        }

        final codeSnapshot = await transaction.get(codeRef);
        if (!codeSnapshot.exists) {
          throw StateError('invalid_code');
        }
        final ownerUid = codeSnapshot.data()?['ownerUid'] as String?;
        if (ownerUid == null || ownerUid == user.uid) {
          throw StateError('invalid_owner');
        }

        final referralId = '${ownerUid}_${user.uid}';
        final referralRef = firestore.collection('referrals').doc(referralId);
        final referralSnapshot = await transaction.get(referralRef);
        if (referralSnapshot.exists) {
          throw StateError('duplicate_referral');
        }

        transaction.set(referralRef, {
          'referrerUid': ownerUid,
          'referredUid': user.uid,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.set(userRef, {
          'referredBy': ownerUid,
          'referredByCode': code,
          'referredAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      if (!mounted) return;
      setState(() {
        _submitting = false;
        _codeController.text = code;
        _statusMessage = '紹介コードを適用しました。条件達成後に反映されます。';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
      });
      switch (error.toString()) {
        case 'StateError: already_applied':
          _showMessage('紹介コードはすでに適用済みです。');
          break;
        case 'StateError: invalid_code':
          _showMessage('紹介コードが見つかりませんでした。');
          break;
        case 'StateError: invalid_owner':
          _showMessage('この紹介コードは利用できません。');
          break;
        case 'StateError: duplicate_referral':
          _showMessage('この紹介はすでに記録されています。');
          break;
        default:
          _showMessage('紹介コードの適用に失敗しました。');
      }
    }
  }

  void _showMessage(String message) {
    setState(() {
      _statusMessage = message;
    });
  }

  Future<void> _copyCode() async {
    final code = _referralCode;
    if (code == null) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    _showMessage('紹介コードをコピーしました。');
  }

  Future<void> _shareCode() async {
    final code = _referralCode;
    if (code == null) return;
    final message = 'SaveSmartの紹介コードです。アプリ内で入力すると無料期間が14日になります。\n紹介コード: $code';
    await Share.share(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Icon(
              Icons.chevron_left,
              color: AppColors.textSecondary.withOpacity(0.8),
              size: 18,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '友達紹介',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary.withOpacity(0.9),
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '紹介した方はPlusが7日延長！\n'
            '紹介された方は無料トライアルが7日→14日！',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary.withOpacity(0.9),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          _buildCodeCard(),
          const SizedBox(height: 20),
          _buildInputCard(),
          if (_statusMessage != null) ...[
            const SizedBox(height: 16),
            _buildStatusCard(_statusMessage!),
          ],
          const SizedBox(height: 12),
          _buildInfoCard(),
        ],
      ),
    );
  }

  Widget _buildCodeCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'あなたの紹介コード',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.accentBlueLight.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.accentBlue.withOpacity(0.2),
              ),
            ),
            child: _loading
                ? Text(
                    '読み込み中...',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  )
                : Text(
                    _referralCode ?? '---',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: AppColors.textPrimary,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _copyCode,
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('コピー'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _shareCode,
                  icon: const Icon(Icons.share_outlined, size: 16),
                  label: const Text('シェア'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentBlue,
                    side: BorderSide(color: AppColors.accentBlue.withOpacity(0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '紹介コードを入力',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
              LengthLimitingTextInputFormatter(20),
            ],
            decoration: InputDecoration(
              hintText: '例: 7F3K... (英数字)',
              hintStyle: GoogleFonts.ibmPlexSans(
                color: AppColors.textMuted,
                fontSize: 14,
              ),
              filled: true,
              fillColor: AppColors.bgPrimary,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.borderSubtle.withOpacity(0.4)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.borderSubtle.withOpacity(0.4)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.accentBlue, width: 1.4),
              ),
            ),
            style: GoogleFonts.ibmPlexSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _applyReferralCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              child: Text(_submitting ? '適用中...' : '紹介コードを適用'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String message) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.accentBlueLight.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accentBlue.withOpacity(0.2)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.accentBlue.withOpacity(0.8), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '紹介の条件',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '・初期設定完了（給料日 + 今月の予算）\n'
            '・初回支出登録を1回完了',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '条件達成の翌日に反映されます。',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
