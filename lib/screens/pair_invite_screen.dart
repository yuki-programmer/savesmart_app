import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';
import '../config/typography.dart';
import '../data/repositories/invite_repository.dart';
import '../models/pair_invite.dart';

class PairInviteScreen extends StatefulWidget {
  final PairInvite? initialInvite;

  const PairInviteScreen({super.key, this.initialInvite});

  @override
  State<PairInviteScreen> createState() => _PairInviteScreenState();
}

class _PairInviteScreenState extends State<PairInviteScreen> {
  PairInvite? _invite;
  bool _isLoading = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _invite = widget.initialInvite;
    if (_invite == null) {
      _generateInvite();
    } else {
      _startTicker();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  String _remainingText() {
    final invite = _invite;
    if (invite == null) return '読み込み中';
    final remaining = invite.expiresAt.difference(DateTime.now());
    if (remaining.isNegative) return '期限切れ';
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    if (hours > 0) {
      return '残り $hours時間${minutes.toString().padLeft(2, '0')}分';
    }
    return '残り ${minutes}分';
  }

  Future<void> _generateInvite() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final inviteRepo = context.read<InviteRepository>();
      final invite = await inviteRepo.createInvite();
      if (!mounted) return;
      setState(() => _invite = invite);
      _startTicker();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('招待コードの発行に失敗しました', style: GoogleFonts.inter()),
          backgroundColor: AppColors.accentRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _copyCode() async {
    final invite = _invite;
    if (invite == null) return;
    await Clipboard.setData(ClipboardData(text: invite.code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('招待コードをコピーしました', style: GoogleFonts.inter()),
        backgroundColor: AppColors.accentBlue,
      ),
    );
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
        title: Text('招待コード', style: AppTextStyles.screenTitle(context)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: context.appTheme.bgCard,
                borderRadius: BorderRadius.circular(12),
                boxShadow: context.cardElevationShadow,
              ),
              child: Column(
                children: [
                  Text(
                    _invite?.code ?? '------',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                      color: context.appTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _remainingText(),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: context.appTheme.textMuted.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _copyCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentBlue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'コピー',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _generateInvite,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: context.appTheme.textMuted.withValues(alpha: 0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      '再発行',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.appTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'コードは24時間で無効になります。1回使われると失効します。',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: context.appTheme.textMuted.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
