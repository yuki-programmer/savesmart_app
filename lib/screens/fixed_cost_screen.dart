import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/fixed_cost.dart';
import '../models/fixed_cost_category.dart';
import '../services/app_state.dart';
import '../utils/formatters.dart';
import '../widgets/fixed_cost/category_edit_sheet.dart';
import '../widgets/amount_text_field.dart';

class FixedCostScreen extends StatefulWidget {
  const FixedCostScreen({super.key});

  @override
  State<FixedCostScreen> createState() => _FixedCostScreenState();
}

class _FixedCostScreenState extends State<FixedCostScreen> {
  final _memoController = TextEditingController();

  // 選択中のカテゴリID（nullは「その他」扱い）
  int? _selectedCategoryId;

  // 金額
  int _amount = 0;

  // 金額>0 のみで保存可能（カテゴリ選択は任意）
  bool get _canSave => _amount > 0;

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  void _setPresetAmount(int amount) {
    setState(() {
      _amount = amount;
    });
  }

  Future<void> _save() async {
    if (!_canSave) return;

    final appState = context.read<AppState>();

    // カテゴリ名のスナップショットを取得
    String? categoryNameSnapshot;
    if (_selectedCategoryId != null) {
      categoryNameSnapshot = appState.getFixedCostCategoryName(_selectedCategoryId);
    }

    final fixedCost = FixedCost(
      categoryId: _selectedCategoryId,
      categoryNameSnapshot: categoryNameSnapshot,
      amount: _amount,
      memo: _memoController.text.trim().isEmpty
          ? null
          : _memoController.text.trim(),
      createdAt: DateTime.now(),
    );

    final success = await appState.addFixedCost(fixedCost);

    if (mounted) {
      if (success) {
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '保存に失敗しました',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: AppColors.accentRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  void _showCategoryEditSheet() {
    showFixedCostCategoryEditSheet(
      context,
      onCategoryChanged: () {
        setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final categories = appState.fixedCostCategories;

    return Scaffold(
      backgroundColor: context.appTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: context.appTheme.bgCard,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close,
            color: context.appTheme.textSecondary.withValues(alpha: 0.8),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '固定費を登録',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: context.appTheme.textPrimary.withValues(alpha: 0.9),
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _canSave ? _save : null,
            child: Text(
              '保存',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _canSave
                    ? AppColors.accentBlue
                    : context.appTheme.textMuted.withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // 固定費カテゴリセクション
              _buildCategorySection(categories),

              const SizedBox(height: 24),

              // プリセットボタン
              _buildPresetChips(),

              const SizedBox(height: 16),

              // 金額入力
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.appTheme.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: context.cardElevationShadow,
                ),
                child: Column(
                  children: [
                    AmountTextField(
                      initialValue: _amount,
                      fontSize: 36,
                      accentColor: AppColors.accentBlue,
                      onChanged: (value) {
                        setState(() {
                          _amount = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'タップして金額を入力',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: context.appTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // メモ入力カード
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: context.appTheme.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: context.cardElevationShadow,
                ),
                child: _buildInputRow(
                  label: 'メモ',
                  child: TextField(
                    controller: _memoController,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: context.appTheme.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: '任意',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 16,
                        color: context.appTheme.textMuted.withValues(alpha: 0.5),
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySection(List<FixedCostCategory> categories) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: context.cardElevationShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー行
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '固定費カテゴリ',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: context.appTheme.textSecondary.withValues(alpha: 0.8),
                ),
              ),
              GestureDetector(
                onTap: _showCategoryEditSheet,
                child: Text(
                  '編集',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: context.appTheme.textSecondary.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // カテゴリチップ一覧
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...categories.map((category) => _buildCategoryChip(category)),
              // 「その他」チップ（categoryId=null）
              _buildOtherChip(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(FixedCostCategory category) {
    final isSelected = _selectedCategoryId == category.id;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategoryId = category.id;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentBlue.withValues(alpha: 0.1)
              : context.appTheme.bgPrimary,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppColors.accentBlue.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Text(
          category.name,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? AppColors.accentBlue
                : context.appTheme.textSecondary.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }

  Widget _buildOtherChip() {
    final isSelected = _selectedCategoryId == null;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategoryId = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? context.appTheme.textMuted.withValues(alpha: 0.1)
              : context.appTheme.bgPrimary,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? context.appTheme.textMuted.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Text(
          'その他',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? context.appTheme.textSecondary
                : context.appTheme.textMuted.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  Widget _buildInputRow({required String label, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: context.appTheme.textSecondary.withValues(alpha: 0.8),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildPresetChips() {
    final presets = [1000, 5000, 10000, 50000, 100000];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: presets.map((amount) {
          final isSelected = _amount == amount;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _setPresetAmount(amount),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.accentBlue.withValues(alpha: 0.1)
                      : context.appTheme.bgPrimary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.accentBlue.withValues(alpha: 0.3)
                        : Colors.transparent,
                  ),
                ),
                child: Text(
                  formatNumber(amount),
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? AppColors.accentBlue
                        : context.appTheme.textSecondary.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

}
