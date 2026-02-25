import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/theme.dart';
import '../config/typography.dart';
import '../data/repositories/invite_repository.dart';
import '../data/repositories/pair_repository.dart';
import '../data/repositories/user_repository.dart';
import '../models/pair_invite.dart';
import '../services/auth_service.dart';
import 'pair_invite_screen.dart';
import 'pair_status_screen.dart';

class PairStartScreen extends StatefulWidget {
  const PairStartScreen({super.key});

  @override
  State<PairStartScreen> createState() => _PairStartScreenState();
}

class _PairStartScreenState extends State<PairStartScreen> {
  bool _isLoading = false;

  Future<void> _startPair() async {
    if (_isLoading) return;
    if (!AuthService.instance.isSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ペア機能はモバイル版で利用できます', style: GoogleFonts.inter()),
          backgroundColor: AppColors.accentRed,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await AuthService.instance.ensureSignedInAnonymously();
      final userRepo = context.read<UserRepository>();
      final me = await userRepo.getMe();
      if (!mounted) return;
      if (me.pairId != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PairStatusScreen()),
        );
        return;
      }

      final pairRepo = context.read<PairRepository>();
      await pairRepo.createPair();
      final inviteRepo = context.read<InviteRepository>();
      final PairInvite invite = await inviteRepo.createInvite();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => PairInviteScreen(initialInvite: invite)),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final message = e.code == 'operation-not-allowed'
          ? '匿名認証が無効です（Firebaseコンソールで有効化してください）'
          : '認証に失敗しました';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: GoogleFonts.inter()),
          backgroundColor: AppColors.accentRed,
        ),
      );
    } on FirebaseException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Firestoreの権限設定を確認してください', style: GoogleFonts.inter()),
          backgroundColor: AppColors.accentRed,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ペア作成に失敗しました', style: GoogleFonts.inter()),
          backgroundColor: AppColors.accentRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: context.appTheme.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: context.appTheme.bgCard,
              borderRadius: BorderRadius.circular(8),
              boxShadow: context.cardElevationShadow,
            ),
            child: Icon(
              Icons.chevron_left,
              color: context.appTheme.textSecondary.withValues(alpha: 0.8),
              size: 18,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('ペアをはじめる', style: AppTextStyles.screenTitle(context)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '家計簿を2人で共有できます。',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: context.appTheme.textPrimary.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'ペア機能の利用には認証が必要です。',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: context.appTheme.textMuted.withValues(alpha: 0.7),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _startPair,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentBlue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        '認証してペアを開始',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
