import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../config/typography.dart';
import '../data/repositories/pair_repository.dart';
import '../models/pair.dart';
import '../services/auth_service.dart';
import 'pair_invite_screen.dart';

class PairStatusScreen extends StatelessWidget {
  const PairStatusScreen({super.key});

  Future<void> _showLeaveDialog(BuildContext context) async {
    bool copyToLocal = false;
    final pairRepo = context.read<PairRepository>();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: context.appTheme.bgCard,
          title: Text(
            'ペアをやめる',
            style: GoogleFonts.inter(color: context.appTheme.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '退出すると共有データは見られません。必要ならコピーを作成できます',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: context.appTheme.textMuted.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: copyToLocal,
                onChanged: (value) => setState(() => copyToLocal = value ?? false),
                title: Text(
                  '自分用にコピーを作成する',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: context.appTheme.textPrimary,
                  ),
                ),
                activeColor: AppColors.accentBlue,
                checkColor: Colors.white,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'キャンセル',
                style: GoogleFonts.inter(color: AppColors.accentBlue),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await pairRepo.leavePair(copyToLocal: copyToLocal);
              },
              child: Text(
                '退出する',
                style: GoogleFonts.inter(color: AppColors.accentRed),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberRow(String label, Color color, Color textColor) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: textColor,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService.instance.isSupported) {
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
          title: Text('ペア状況', style: AppTextStyles.screenTitle(context)),
          centerTitle: true,
        ),
        body: Center(
          child: Text(
            'ペア機能はモバイル版で利用できます',
            style: GoogleFonts.inter(color: context.appTheme.textMuted),
          ),
        ),
      );
    }

    final uid = AuthService.instance.currentUser?.uid;
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
        title: Text('ペア状況', style: AppTextStyles.screenTitle(context)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: StreamBuilder<Pair?>(
          stream: context.read<PairRepository>().watchPair(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(
                child: Text(
                  'ペアが設定されていません',
                  style: GoogleFonts.inter(color: context.appTheme.textMuted),
                ),
              );
            }
            final pair = snapshot.data;
            if (pair == null) {
              return Center(
                child: Text(
                  'ペアが設定されていません',
                  style: GoogleFonts.inter(color: context.appTheme.textMuted),
                ),
              );
            }

            final members = pair.memberUids;
            final selfLabel = '自分';
            final otherLabel = members.length > 1 ? '相手' : '未参加';

            final memberTextColor = context.appTheme.textPrimary;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.appTheme.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: context.cardElevationShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'メンバー',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: context.appTheme.textMuted.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildMemberRow(
                        selfLabel,
                        AppColors.accentBlue,
                        memberTextColor,
                      ),
                      const SizedBox(height: 6),
                      _buildMemberRow(
                        otherLabel,
                        members.length > 1 ? AppColors.accentGreen : context.appTheme.textMuted,
                        memberTextColor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.appTheme.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: context.cardElevationShadow,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Plus状態',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: context.appTheme.textPrimary.withValues(alpha: 0.9),
                        ),
                      ),
                      Text(
                        pair.plusActive ? 'Plus共有中' : 'Plusなし',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: pair.plusActive
                              ? AppColors.accentGreen
                              : context.appTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PairInviteScreen()),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: context.appTheme.textMuted.withValues(alpha: 0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      '招待コードを再発行',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.appTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => _showLeaveDialog(context),
                    child: Text(
                      'ペアをやめる',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.accentRed,
                      ),
                    ),
                  ),
                ),
                if (uid != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      'あなたのID: ${uid.substring(0, 6)}...',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: context.appTheme.textMuted.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
