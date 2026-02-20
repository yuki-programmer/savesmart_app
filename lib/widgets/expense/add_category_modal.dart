import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/typography.dart';
import '../../config/category_icons.dart';
import '../../services/app_state.dart';

/// カテゴリ追加モーダルを表示
void showAddCategoryModal(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _AddCategoryModalContent(),
  );
}

class _AddCategoryModalContent extends StatefulWidget {
  const _AddCategoryModalContent();

  @override
  State<_AddCategoryModalContent> createState() => _AddCategoryModalContentState();
}

class _AddCategoryModalContentState extends State<_AddCategoryModalContent> {
  final _controller = TextEditingController();
  String? _selectedIcon;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: context.appTheme.bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'カテゴリを追加',
              style: AppTextStyles.sectionTitle(context).copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'カテゴリ名を入力',
                hintStyle: AppTextStyles.sub(context).copyWith(
                  color: context.appTheme.textMuted,
                ),
                filled: true,
                fillColor: context.appTheme.bgPrimary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // アイコン選択
            Text(
              'アイコン（任意）',
              style: AppTextStyles.label(context, weight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            _buildIconGrid(),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: context.appTheme.bgPrimary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'キャンセル',
                          style: AppTextStyles.body(context, weight: FontWeight.w600).copyWith(
                            color: context.appTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      if (_controller.text.isNotEmpty) {
                        await context
                            .read<AppState>()
                            .addCategory(_controller.text, icon: _selectedIcon);
                        if (!context.mounted) return;
                        Navigator.pop(context);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.accentGreen,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '追加',
                          style: AppTextStyles.body(context, weight: FontWeight.w700).copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconGrid() {
    final icons = CategoryIcons.allIcons;
    return SizedBox(
      height: 120,
      child: GridView.builder(
        scrollDirection: Axis.horizontal,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
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
                borderRadius: BorderRadius.circular(10),
                border: isSelected
                    ? Border.all(color: AppColors.accentBlue, width: 2)
                    : null,
              ),
              child: Center(
                child: Icon(
                  item.icon,
                  size: 24,
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
}
