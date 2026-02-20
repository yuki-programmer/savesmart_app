import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../config/typography.dart';
import '../config/category_icons.dart';
import '../services/app_state.dart';

class CategoryManageScreen extends StatelessWidget {
  const CategoryManageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: context.appTheme.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: context.appTheme.textSecondary.withValues(alpha: 0.8)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'カテゴリ管理',
          style: AppTextStyles.screenTitle(context),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => _showAddDialog(context),
            child: Text(
              '+ 追加',
              style: GoogleFonts.inter(
                color: AppColors.accentBlue.withValues(alpha: 0.9),
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          final categories = appState.categories;

          if (categories.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.category_outlined,
                    size: 56,
                    color: context.appTheme.textMuted.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'カテゴリがありません',
                    style: AppTextStyles.sub(context),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return _buildCategoryCard(context, category, appState);
            },
          );
        },
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, category, AppState appState) {
    final icon = CategoryIcons.getIcon(category.icon);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.appTheme.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.appTheme.borderSubtle.withValues(alpha: 0.5)),
        boxShadow: context.cardElevationShadow,
      ),
      child: Row(
        children: [
          // アイコン表示
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.appTheme.bgPrimary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(
                icon,
                size: 20,
                color: context.appTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              category.name,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: context.appTheme.textPrimary.withValues(alpha: 0.9),
                height: 1.4,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _showEditDialog(context, category),
            child: Container(
              padding: const EdgeInsets.all(6),
              child: const Text(
                '✏️',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _showDeleteDialog(context, category, appState),
            child: Container(
              padding: const EdgeInsets.all(6),
              child: const Text(
                '🗑️',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _CategoryEditDialog(isEdit: false),
    );
  }

  void _showEditDialog(BuildContext context, category) {
    showDialog(
      context: context,
      builder: (context) => _CategoryEditDialog(
        isEdit: true,
        categoryId: category.id,
        initialName: category.name,
        initialIcon: category.icon,
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, category, AppState appState) {
    final expenseCount = appState.getExpenseCountByCategory(category.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          'カテゴリを削除',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        content: Text(
          expenseCount > 0
              ? 'このカテゴリには$expenseCount件の支出があります。削除すると支出も削除されます。'
              : 'このカテゴリを削除しますか？',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: context.appTheme.textSecondary.withValues(alpha: 0.8),
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'キャンセル',
              style: GoogleFonts.inter(
                color: context.appTheme.textSecondary.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final success = await context.read<AppState>().deleteCategory(category.id);
              if (context.mounted) {
                Navigator.pop(context);
                if (!success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('カテゴリの削除に失敗しました', style: GoogleFonts.inter()),
                      backgroundColor: AppColors.accentRed,
                    ),
                  );
                }
              }
            },
            child: Text(
              '削除',
              style: GoogleFonts.inter(
                color: AppColors.accentRed,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// カテゴリ追加/編集ダイアログ（アイコン選択付き）
class _CategoryEditDialog extends StatefulWidget {
  final bool isEdit;
  final int? categoryId;
  final String? initialName;
  final String? initialIcon;

  const _CategoryEditDialog({
    required this.isEdit,
    this.categoryId,
    this.initialName,
    this.initialIcon,
  });

  @override
  State<_CategoryEditDialog> createState() => _CategoryEditDialogState();
}

class _CategoryEditDialogState extends State<_CategoryEditDialog> {
  late TextEditingController _controller;
  String? _selectedIcon;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName ?? '');
    _selectedIcon = widget.initialIcon;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(
        widget.isEdit ? 'カテゴリを編集' : 'カテゴリを追加',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // カテゴリ名入力
            TextField(
              controller: _controller,
              autofocus: true,
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400),
              decoration: InputDecoration(
                hintText: 'カテゴリ名を入力',
                hintStyle: GoogleFonts.inter(
                  color: context.appTheme.textMuted.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
                filled: true,
                fillColor: context.appTheme.bgPrimary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            // アイコン選択ラベル
            Text(
              'アイコン',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: context.appTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            // アイコン選択グリッド
            _buildIconGrid(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'キャンセル',
            style: GoogleFonts.inter(
              color: context.appTheme.textSecondary.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ),
        TextButton(
          onPressed: _save,
          child: Text(
            widget.isEdit ? '保存' : '追加',
            style: GoogleFonts.inter(
              color: widget.isEdit ? AppColors.accentOrange : AppColors.accentBlue,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIconGrid() {
    final icons = CategoryIcons.allIcons;
    return SizedBox(
      height: 160,
      width: 280,
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        itemCount: icons.length,
        itemBuilder: (context, index) {
          final item = icons[index];
          final isSelected = _selectedIcon == item.name;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedIcon = isSelected ? null : item.name;
              });
            },
            child: Container(
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.accentBlue.withValues(alpha: 0.1)
                    : context.appTheme.bgPrimary,
                borderRadius: BorderRadius.circular(8),
                border: isSelected
                    ? Border.all(color: AppColors.accentBlue, width: 2)
                    : null,
              ),
              child: Center(
                child: Icon(
                  item.icon,
                  size: 20,
                  color: isSelected
                      ? AppColors.accentBlue
                      : context.appTheme.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    if (_controller.text.trim().isEmpty) return;

    final appState = context.read<AppState>();
    bool success;

    if (widget.isEdit) {
      success = await appState.updateCategoryNameAndIcon(
        widget.categoryId!,
        _controller.text.trim(),
        icon: _selectedIcon,
      );
    } else {
      success = await appState.addCategory(
        _controller.text.trim(),
        icon: _selectedIcon,
      );
    }

    if (!mounted) return;
    Navigator.pop(context);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEdit ? 'カテゴリの更新に失敗しました' : 'カテゴリの追加に失敗しました',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: AppColors.accentRed,
        ),
      );
    }
  }
}
