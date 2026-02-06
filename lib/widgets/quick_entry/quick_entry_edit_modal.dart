import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/quick_entry.dart';
import '../../services/app_state.dart';
import '../../screens/premium_screen.dart';
import '../amount_text_field.dart';

/// クイック登録の追加・編集モーダル
Future<void> showQuickEntryEditModal(
  BuildContext context, {
  QuickEntry? entry, // nullなら新規作成
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => QuickEntryEditModal(entry: entry),
  );
}

class QuickEntryEditModal extends StatefulWidget {
  final QuickEntry? entry;

  const QuickEntryEditModal({super.key, this.entry});

  @override
  State<QuickEntryEditModal> createState() => _QuickEntryEditModalState();
}

class _QuickEntryEditModalState extends State<QuickEntryEditModal> {
  static const int _freeQuickEntryLimit = 2;
  static const String _limitMessage =
      'クイック登録は2枠までです。Plusプランで無制限に追加できます';

  late TextEditingController _titleController;
  int? _selectedCategoryId;
  String? _selectedCategory;
  int _amount = 0;
  String _selectedGrade = 'standard';

  bool get _isEditing => widget.entry != null;

  // グレード定義
  final List<Map<String, dynamic>> _grades = [
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

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.entry?.title ?? '');
    _selectedCategoryId = widget.entry?.categoryId;
    _selectedCategory = widget.entry?.category;
    _amount = widget.entry?.amount ?? 0;
    _selectedGrade = widget.entry?.grade ?? 'standard';
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _selectedCategoryId != null &&
      _selectedCategory != null &&
      _amount > 0;

  /// タイトルを取得（空ならカテゴリ名を使用）
  String get _effectiveTitle =>
      _titleController.text.isNotEmpty ? _titleController.text : _selectedCategory ?? '';

  Map<String, dynamic> get _selectedGradeData =>
      _grades.firstWhere((g) => g['value'] == _selectedGrade);

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<AppState>().categoryNames;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: context.appTheme.bgPrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ハンドル
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.appTheme.textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // タイトル
              Center(
                child: Text(
                  _isEditing ? 'クイック登録を編集' : 'クイック登録を追加',
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: context.appTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // タイトル入力（任意）
              Text(
                'タイトル（任意）',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.appTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: '空欄ならカテゴリ名を使用',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 14,
                    color: context.appTheme.textMuted.withValues(alpha: 0.7),
                  ),
                  filled: true,
                  fillColor: context.appTheme.bgCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: _selectedGradeData['color'] as Color,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: context.appTheme.textPrimary,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),

              // カテゴリ選択
              Text(
                'カテゴリ',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.appTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categories.map((category) {
                  final isSelected = _selectedCategory == category;
                  return GestureDetector(
                    onTap: () {
                      final appState = context.read<AppState>();
                      final categoryObj = appState.categories.firstWhere(
                        (c) => c.name == category,
                        orElse: () => appState.categories.first,
                      );
                      setState(() {
                        _selectedCategoryId = categoryObj.id;
                        _selectedCategory = category;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _selectedGradeData['lightColor'] as Color
                            : context.appTheme.bgCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? _selectedGradeData['color'] as Color
                              : Colors.black.withValues(alpha: 0.06),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        category,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? _selectedGradeData['color'] as Color
                              : context.appTheme.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // 金額入力
              Text(
                '金額',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.appTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: AmountTextField(
                  initialValue: _amount,
                  fontSize: 36,
                  accentColor: _selectedGradeData['color'] as Color,
                  onChanged: (value) {
                    setState(() {
                      _amount = value;
                    });
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'タップして金額を入力',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: context.appTheme.textMuted,
                ),
              ),
              const SizedBox(height: 16),

              // 支出タイプ
              Text(
                '支出タイプ',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.appTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: _grades.map((grade) {
                  final isSelected = _selectedGrade == grade['value'];
                  final color = grade['color'] as Color;
                  final lightColor = grade['lightColor'] as Color;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedGrade = grade['value'] as String;
                        });
                      },
                      child: Container(
                        margin: EdgeInsets.only(
                          right: grade['value'] != 'reward' ? 8 : 0,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? lightColor : context.appTheme.bgCard,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? color
                                : Colors.black.withValues(alpha: 0.06),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            grade['label'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight:
                                  isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected ? color : context.appTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // 保存ボタン
              GestureDetector(
                onTap: _canSave ? _save : null,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _canSave
                        ? _selectedGradeData['color'] as Color
                        : context.appTheme.textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      _isEditing ? '保存する' : '追加する',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _canSave ? Colors.white : context.appTheme.textMuted,
                      ),
                    ),
                  ),
                ),
              ),

              // 削除ボタン（編集時のみ）
              if (_isEditing) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _confirmDelete,
                  child: Center(
                    child: Text(
                      '削除する',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.accentRed.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_canSave) return;

    final appState = context.read<AppState>();
    if (!_isEditing &&
        !appState.isPremium &&
        appState.quickEntries.length >= _freeQuickEntryLimit) {
      await _showUpgradePrompt();
      return;
    }

    final entry = QuickEntry(
      id: widget.entry?.id,
      title: _effectiveTitle,
      categoryId: _selectedCategoryId!,
      category: _selectedCategory!,
      amount: _amount,
      grade: _selectedGrade,
      sortOrder: widget.entry?.sortOrder ?? 0,
    );

    bool success;
    if (_isEditing) {
      success = await appState.updateQuickEntry(entry);
    } else {
      success = await appState.addQuickEntry(entry);
    }

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '保存に失敗しました',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: AppColors.accentRed,
        ),
      );
    }
  }

  Future<void> _showUpgradePrompt() async {
    final rootNavigator = Navigator.of(context, rootNavigator: true);
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

    if (!mounted) return;
    if (shouldOpen == true) {
      Navigator.of(context).pop();
      rootNavigator.push(
        MaterialPageRoute(builder: (_) => const PremiumScreen()),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '削除の確認',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'このクイック登録を削除しますか？',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'キャンセル',
              style: GoogleFonts.inter(color: context.appTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              '削除',
              style: GoogleFonts.inter(color: AppColors.accentRed),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.entry?.id != null && mounted) {
      final appState = context.read<AppState>();
      final success = await appState.deleteQuickEntry(widget.entry!.id!);

      if (!mounted) return;

      if (success) {
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '削除に失敗しました',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: AppColors.accentRed,
          ),
        );
      }
    }
  }
}
