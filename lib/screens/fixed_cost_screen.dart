import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/fixed_cost.dart';
import '../models/fixed_cost_category.dart';
import '../services/app_state.dart';
import '../utils/formatters.dart';
import '../widgets/fixed_cost/category_edit_sheet.dart';

class FixedCostScreen extends StatefulWidget {
  const FixedCostScreen({super.key});

  @override
  State<FixedCostScreen> createState() => _FixedCostScreenState();
}

class _FixedCostScreenState extends State<FixedCostScreen> {
  final _memoController = TextEditingController();

  // 選択中のカテゴリID（nullは「その他」扱い）
  int? _selectedCategoryId;

  // 金額状態（1000円単位 + 100円単位）
  int _amount1000 = 0; // 0〜300 (0円〜300,000円)
  int _amount100 = 0; // 0〜9 (0円〜900円)

  // ホイールコントローラー
  late FixedExtentScrollController _controller1000;
  late FixedExtentScrollController _controller100;

  int get _totalAmount => _amount1000 * 1000 + _amount100 * 100;

  // 金額>0 のみで保存可能（カテゴリ選択は任意）
  bool get _canSave => _totalAmount > 0;

  @override
  void initState() {
    super.initState();
    _controller1000 = FixedExtentScrollController(initialItem: _amount1000);
    _controller100 = FixedExtentScrollController(initialItem: _amount100);
  }

  @override
  void dispose() {
    _memoController.dispose();
    _controller1000.dispose();
    _controller100.dispose();
    super.dispose();
  }

  void _setPresetAmount(int amount) {
    final new1000 = amount ~/ 1000;
    final new100 = (amount % 1000) ~/ 100;

    setState(() {
      _amount1000 = new1000.clamp(0, 300);
      _amount100 = new100.clamp(0, 9);
    });

    // ホイール位置を同期
    _controller1000.animateToItem(
      _amount1000,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    _controller100.animateToItem(
      _amount100,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
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
      amount: _totalAmount,
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
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close,
            color: AppColors.textSecondary.withOpacity(0.8),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '固定費を登録',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary.withOpacity(0.9),
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
                    : AppColors.textMuted.withOpacity(0.4),
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

              // 金額表示
              Center(
                child: Text(
                  '¥${formatNumber(_totalAmount)}',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentBlue,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // プリセットボタン
              _buildPresetChips(),

              const SizedBox(height: 16),

              // 2つのホイールピッカー
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // 1000円単位ホイール
                    Expanded(
                      flex: 2,
                      child: _buildWheel(
                        controller: _controller1000,
                        itemCount: 301, // 0〜300
                        selectedIndex: _amount1000,
                        formatValue: (index) => '${index * 1000}',
                        suffix: '',
                        onChanged: (index) {
                          setState(() => _amount1000 = index);
                        },
                      ),
                    ),
                    // 区切り
                    Text(
                      '+',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w300,
                        color: AppColors.textMuted.withOpacity(0.5),
                      ),
                    ),
                    // 100円単位ホイール
                    Expanded(
                      flex: 1,
                      child: _buildWheel(
                        controller: _controller100,
                        itemCount: 10, // 0〜9
                        selectedIndex: _amount100,
                        formatValue: (index) => '${index * 100}',
                        suffix: '',
                        onChanged: (index) {
                          setState(() => _amount100 = index);
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // ホイール説明
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: Text(
                    '左: 1,000円単位　右: 100円単位',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textMuted.withOpacity(0.6),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // メモ入力カード
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _buildInputRow(
                  label: 'メモ',
                  child: TextField(
                    controller: _memoController,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: '任意',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 16,
                        color: AppColors.textMuted.withOpacity(0.5),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
                  color: AppColors.textSecondary.withOpacity(0.8),
                ),
              ),
              GestureDetector(
                onTap: _showCategoryEditSheet,
                child: Text(
                  '編集',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.accentBlue.withOpacity(0.8),
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
              ? AppColors.accentBlue.withOpacity(0.1)
              : AppColors.bgPrimary,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppColors.accentBlue.withOpacity(0.3)
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
                : AppColors.textSecondary.withOpacity(0.8),
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
              ? AppColors.textMuted.withOpacity(0.1)
              : AppColors.bgPrimary,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppColors.textMuted.withOpacity(0.3)
                : Colors.transparent,
          ),
        ),
        child: Text(
          'その他',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? AppColors.textSecondary
                : AppColors.textMuted.withOpacity(0.7),
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
                color: AppColors.textSecondary.withOpacity(0.8),
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
          final isSelected = _totalAmount == amount;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _setPresetAmount(amount),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.accentBlue.withOpacity(0.1)
                      : AppColors.bgPrimary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.accentBlue.withOpacity(0.3)
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
                        : AppColors.textSecondary.withOpacity(0.8),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWheel({
    required FixedExtentScrollController controller,
    required int itemCount,
    required int selectedIndex,
    required String Function(int) formatValue,
    required String suffix,
    required Function(int) onChanged,
  }) {
    return SizedBox(
      height: 180,
      child: Stack(
        children: [
          // 中央ハイライト
          Center(
            child: Container(
              height: 44,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: AppColors.accentBlueLight.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          // ホイール
          ListWheelScrollView.useDelegate(
            controller: controller,
            itemExtent: 44,
            perspective: 0.005,
            diameterRatio: 1.5,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: onChanged,
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: itemCount,
              builder: (context, index) {
                final isSelected = index == selectedIndex;
                return Center(
                  child: Text(
                    '¥${formatValue(index)}$suffix',
                    style: isSelected
                        ? GoogleFonts.ibmPlexSans(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          )
                        : GoogleFonts.ibmPlexSans(
                            fontSize: 16,
                            fontWeight: FontWeight.normal,
                            color: AppColors.textMuted,
                          ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

}

