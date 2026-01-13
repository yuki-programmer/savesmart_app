import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/quick_entry.dart';
import '../../services/app_state.dart';
import '../../utils/formatters.dart';
import '../wheel_picker.dart';

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
  late TextEditingController _titleController;
  String? _selectedCategory;
  int _amount = 0;
  int _unit = 100;
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
    _selectedCategory = widget.entry?.category;
    _amount = widget.entry?.amount ?? 0;
    _selectedGrade = widget.entry?.grade ?? 'standard';

    // 初期金額に基づいて単位を設定
    if (_amount > 0) {
      if (_amount >= 10000) {
        _unit = 10000;
      } else if (_amount >= 1000) {
        _unit = 1000;
      } else if (_amount >= 100) {
        _unit = 100;
      } else {
        _unit = 10;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  bool get _canSave =>
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
      decoration: const BoxDecoration(
        color: AppColors.bgPrimary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                    color: AppColors.textMuted.withOpacity(0.3),
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
                    color: AppColors.textPrimary,
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
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: '空欄ならカテゴリ名を使用',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textMuted.withOpacity(0.7),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
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
                  color: AppColors.textPrimary,
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
                  color: AppColors.textPrimary,
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
                      setState(() {
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
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? _selectedGradeData['color'] as Color
                              : Colors.black.withOpacity(0.06),
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
                              : AppColors.textSecondary,
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
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '¥${formatNumber(_amount)}',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: _amount > 0
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildUnitSelector(),
              const SizedBox(height: 4),
              SizedBox(
                height: 100,
                child: WheelPicker(
                  key: ValueKey('quick_entry_$_unit'),
                  unit: _unit,
                  maxMultiplier: _unit >= 1000 ? 100 : 99,
                  initialValue: _amount,
                  highlightColor: AppColors.bgPrimary,
                  onChanged: (value) {
                    setState(() {
                      _amount = value;
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),

              // 支出タイプ
              Text(
                '支出タイプ',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
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
                          color: isSelected ? lightColor : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? color
                                : Colors.black.withOpacity(0.06),
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
                              color: isSelected ? color : AppColors.textSecondary,
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
                        : AppColors.textMuted.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      _isEditing ? '保存する' : '追加する',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _canSave ? Colors.white : AppColors.textMuted,
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
                        color: AppColors.accentRed.withOpacity(0.8),
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

  Widget _buildUnitSelector() {
    final units = [10, 100, 1000, 10000];
    final labels = ['10円', '100円', '1000円', '1万円'];

    return Center(
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.black.withOpacity(0.04)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(units.length, (index) {
            final unit = units[index];
            final isSelected = _unit == unit;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _unit = unit;
                  _amount = 0;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.bgPrimary : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  labels[index],
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? AppColors.textPrimary : AppColors.textMuted,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_canSave) return;

    final appState = context.read<AppState>();
    final entry = QuickEntry(
      id: widget.entry?.id,
      title: _effectiveTitle,
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
              style: GoogleFonts.inter(color: AppColors.textSecondary),
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
