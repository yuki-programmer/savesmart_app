import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/fixed_cost_category.dart';
import '../../services/app_state.dart';

/// 固定費カテゴリ編集用 BottomSheet
class FixedCostCategoryEditSheet extends StatefulWidget {
  final VoidCallback onCategoryChanged;

  const FixedCostCategoryEditSheet({
    super.key,
    required this.onCategoryChanged,
  });

  @override
  State<FixedCostCategoryEditSheet> createState() =>
      _FixedCostCategoryEditSheetState();
}

class _FixedCostCategoryEditSheetState
    extends State<FixedCostCategoryEditSheet> {
  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final categories = appState.fixedCostCategories;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ハンドルバー
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ヘッダー
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '固定費カテゴリを編集',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(
                      Icons.close,
                      size: 22,
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // カテゴリ一覧
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // 新規追加ボタン
                    _buildAddCategoryRow(),
                    const Divider(height: 1),

                    // カテゴリ一覧
                    ...categories.map((category) => Column(
                          children: [
                            _buildCategoryRow(category),
                            const Divider(height: 1),
                          ],
                        )),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAddCategoryRow() {
    return InkWell(
      onTap: () => _showAddCategoryDialog(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 20,
              color: AppColors.accentBlue.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 12),
            Text(
              '新規追加',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.accentBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryRow(FixedCostCategory category) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              category.name,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          // 名称変更
          IconButton(
            onPressed: () => _showRenameCategoryDialog(category),
            icon: Icon(
              Icons.edit_outlined,
              size: 20,
              color: AppColors.textSecondary.withValues(alpha: 0.6),
            ),
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
          ),
          const SizedBox(width: 4),
          // 削除
          IconButton(
            onPressed: () => _deleteCategory(category),
            icon: Icon(
              Icons.delete_outline,
              size: 20,
              color: AppColors.textSecondary.withValues(alpha: 0.6),
            ),
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddCategoryDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'カテゴリを追加',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'カテゴリ名',
            hintStyle: GoogleFonts.inter(
              color: AppColors.textMuted.withValues(alpha: 0.5),
            ),
          ),
          style: GoogleFonts.inter(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'キャンセル',
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.of(context).pop(name);
              }
            },
            child: Text(
              '追加',
              style: GoogleFonts.inter(
                color: AppColors.accentBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      await context.read<AppState>().addFixedCostCategory(result);
      widget.onCategoryChanged();
    }
  }

  Future<void> _showRenameCategoryDialog(FixedCostCategory category) async {
    final controller = TextEditingController(text: category.name);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'カテゴリ名を変更',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'カテゴリ名',
            hintStyle: GoogleFonts.inter(
              color: AppColors.textMuted.withValues(alpha: 0.5),
            ),
          ),
          style: GoogleFonts.inter(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'キャンセル',
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.of(context).pop(name);
              }
            },
            child: Text(
              '変更',
              style: GoogleFonts.inter(
                color: AppColors.accentBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      await context.read<AppState>().renameFixedCostCategory(category.id!, result);
      widget.onCategoryChanged();
    }
  }

  Future<void> _deleteCategory(FixedCostCategory category) async {
    final success = await context.read<AppState>().deleteFixedCostCategory(category.id!);

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'この固定費カテゴリは使用中のため削除できません',
            style: GoogleFonts.inter(fontSize: 14),
          ),
          backgroundColor: AppColors.textSecondary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } else if (mounted) {
      widget.onCategoryChanged();
    }
  }
}

/// FixedCostCategoryEditSheetを表示するヘルパー関数
void showFixedCostCategoryEditSheet(
  BuildContext context, {
  required VoidCallback onCategoryChanged,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => FixedCostCategoryEditSheet(
      onCategoryChanged: onCategoryChanged,
    ),
  );
}
