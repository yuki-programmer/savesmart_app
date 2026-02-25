import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/theme.dart';
import '../config/typography.dart';
import '../data/repositories/invite_repository.dart';
import '../services/auth_service.dart';
import 'pair_status_screen.dart';

class PairJoinScreen extends StatefulWidget {
  const PairJoinScreen({super.key});

  @override
  State<PairJoinScreen> createState() => _PairJoinScreenState();
}

class _PairJoinScreenState extends State<PairJoinScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _join() async {
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
    final code = _controller.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await AuthService.instance.ensureSignedInAnonymously();
      final inviteRepo = context.read<InviteRepository>();
      await inviteRepo.acceptInvite(code);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PairStatusScreen()),
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
          content: Text('コードが無効か期限切れです', style: GoogleFonts.inter()),
          backgroundColor: AppColors.accentRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        title: Text('招待コードを入力', style: AppTextStyles.screenTitle(context)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.characters,
              maxLength: 8,
              decoration: InputDecoration(
                filled: true,
                fillColor: context.appTheme.bgCard,
                hintText: '例: 4D7K9P',
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              style: GoogleFonts.ibmPlexSans(
                fontSize: 18,
                letterSpacing: 3,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _join,
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
                        '参加する',
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
