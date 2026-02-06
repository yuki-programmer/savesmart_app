import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/quick_entry.dart';
import '../screens/premium_screen.dart';
import '../services/app_state.dart';
import '../utils/formatters.dart';
import '../widgets/quick_entry/quick_entry_edit_modal.dart';

/// クイック登録管理画面
/// よく使う支出のショートカットを編集・削除できる画面
class QuickEntryManageScreen extends StatelessWidget {
  const QuickEntryManageScreen({super.key});

  static const int _freeQuickEntryLimit = 2;
  static const String _limitMessage =
      'クイック登録は2枠までです。Plusプランで無制限に追加できます';

  @override
  Widget build(BuildContext context) {
    final quickEntries = context.watch<AppState>().quickEntries;

    return Scaffold(
      backgroundColor: context.appTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: context.appTheme.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.appTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'クイック登録を管理',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: context.appTheme.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 説明文
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Text(
              'よく使う支出のショートカットです。ここでは編集や削除が行えます。',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: context.appTheme.textSecondary,
              ),
            ),
          ),
          // リスト
          Expanded(
            child: quickEntries.isEmpty
                ? _buildEmptyState(context)
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: quickEntries.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final entry = quickEntries[index];
                      return _QuickEntryListItem(
                        entry: entry,
                        onEdit: () => _showEditModal(context, entry),
                        onDelete: () => _showDeleteConfirmation(context, entry),
                      );
                    },
                  ),
          ),
        ],
      ),
      // 追加ボタン（FAB）
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _handleAddTap(context, quickEntries.length),
        backgroundColor: AppColors.accentBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          '新規追加',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  /// 空の状態
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_outline,
            size: 48,
            color: context.appTheme.textMuted.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'クイック登録がありません',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: context.appTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '下のボタンから追加してください',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: context.appTheme.textMuted,
            ),
          ),
          const SizedBox(height: 80), // FABの分のスペース
        ],
      ),
    );
  }

  /// 編集モーダルを表示
  void _showEditModal(BuildContext context, QuickEntry? entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QuickEntryEditModal(entry: entry),
    );
  }

  Future<void> _handleAddTap(
    BuildContext context,
    int currentCount,
  ) async {
    final appState = context.read<AppState>();
    if (!appState.isPremium && currentCount >= _freeQuickEntryLimit) {
      await _showUpgradePrompt(context);
      return;
    }

    _showEditModal(context, null);
  }

  Future<void> _showUpgradePrompt(BuildContext context) async {
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'クイック登録の上限',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Text(
          _limitMessage,
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              '今はしない',
              style: GoogleFonts.inter(),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Plusを見る',
              style: GoogleFonts.inter(color: AppColors.accentBlue),
            ),
          ),
        ],
      ),
    );

    if (shouldOpen == true && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PremiumScreen()),
      );
    }
  }

  /// 削除確認ダイアログを表示
  Future<void> _showDeleteConfirmation(
      BuildContext context, QuickEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.appTheme.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'クイック登録を削除しますか？',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: context.appTheme.textPrimary,
          ),
        ),
        content: Text(
          'この操作は元に戻せません。なお、このショートカットを削除しても、これまでの支出履歴は消えません。',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: context.appTheme.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'キャンセル',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: context.appTheme.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              '削除',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.accentRed,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final appState = context.read<AppState>();
      await appState.deleteQuickEntry(entry.id!);
    }
  }
}

/// クイック登録リストアイテム
class _QuickEntryListItem extends StatelessWidget {
  final QuickEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _QuickEntryListItem({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final gradeData = _getGradeData(entry.grade);
    final color = gradeData['color'] as Color;
    final lightColor = gradeData['lightColor'] as Color;
    final label = gradeData['label'] as String;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          // 左側: 内容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // タイトル
                Text(
                  entry.title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.appTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                // カテゴリ・金額・支出タイプ
                Row(
                  children: [
                    // カテゴリ
                    Text(
                      entry.category,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: context.appTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 1,
                      height: 12,
                      color: context.appTheme.textMuted.withValues(alpha: 0.3),
                    ),
                    const SizedBox(width: 8),
                    // 金額
                    Text(
                      '¥${formatNumber(entry.amount)}',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.appTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // 支出タイプ
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: lightColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 右側: 3点メニュー
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_horiz,
              color: context.appTheme.textSecondary.withValues(alpha: 0.6),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  onEdit();
                  break;
                case 'delete':
                  onDelete();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: context.appTheme.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '編集',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: context.appTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: AppColors.accentRed,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '削除',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.accentRed,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getGradeData(String grade) {
    final grades = [
      {
        'value': 'saving',
        'label': '節約',
        'color': AppColors.accentGreen,
        'lightColor': AppColors.accentGreenLight,
      },
      {
        'value': 'standard',
        'label': '標準',
        'color': AppColors.accentBlue,
        'lightColor': AppColors.accentBlueLight,
      },
      {
        'value': 'reward',
        'label': 'ご褒美',
        'color': AppColors.accentOrange,
        'lightColor': AppColors.accentOrangeLight,
      },
    ];
    return grades.firstWhere(
      (g) => g['value'] == grade,
      orElse: () => grades[1],
    );
  }
}
