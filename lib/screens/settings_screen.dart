import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../core/dev_config.dart';
import '../services/app_state.dart';
import '../services/database_service.dart';
import '../services/performance_monitor.dart';
import 'category_manage_screen.dart';
import 'premium_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _versionTapCount = 0;
  static const int _tapsToUnlock = 10;

  void _onVersionTap(AppState appState) {
    if (!DevConfig.canShowDevTools) return;
    if (appState.isDevModeUnlocked) return;

    setState(() {
      _versionTapCount++;
    });

    if (_versionTapCount >= _tapsToUnlock) {
      appState.unlockDevMode();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '開発者モードが有効になりました',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: AppColors.accentBlue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } else if (_versionTapCount >= 5) {
      final remaining = _tapsToUnlock - _versionTapCount;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'あと $remaining 回タップで開発者モード',
            style: GoogleFonts.inter(),
          ),
          duration: const Duration(milliseconds: 500),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
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
        title: Text(
          '設定',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: context.appTheme.textPrimary.withValues(alpha: 0.9),
          ),
        ),
        centerTitle: true,
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // 家計設定セクション
              _buildSectionHeader('家計設定'),
              const SizedBox(height: 12),
              _buildFinancialSettingsCard(appState),
              const SizedBox(height: 24),

              // 表示設定セクション
              _buildSectionHeader('表示設定'),
              const SizedBox(height: 12),
              _buildDisplaySettingsCard(appState),
              const SizedBox(height: 24),

              // データ管理セクション
              _buildSectionHeader('データ管理'),
              const SizedBox(height: 12),
              _buildDataManagementCard(appState),
              const SizedBox(height: 24),

              // 有料プランセクション
              _buildPremiumPlanCard(appState),
              const SizedBox(height: 24),

              // アプリ情報セクション
              _buildSectionHeader('アプリ情報'),
              const SizedBox(height: 12),
              _buildInfoCard(appState),
              const SizedBox(height: 24),

              // 開発者セクション（条件付き表示）
              if (DevConfig.canShowDevTools && appState.isDevModeUnlocked) ...[
                _buildSectionHeader('開発者オプション'),
                const SizedBox(height: 12),
                _buildDeveloperSection(appState),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: context.appTheme.textSecondary.withValues(alpha: 0.7),
        height: 1.4,
      ),
    );
  }

  Widget _buildFinancialSettingsCard(AppState appState) {
    return Container(
      decoration: BoxDecoration(
        color: context.appTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: context.cardElevationShadow,
      ),
      child: Column(
        children: [
          // 家計の開始日（給料日）
          GestureDetector(
            onTap: () => _showSalaryDayPicker(appState),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: context.appTheme.bgPrimary,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '家計の開始日',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: context.appTheme.textPrimary.withValues(alpha: 0.9),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '給料日を設定すると、\n予算管理が給料日基準になります',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: context.appTheme.textMuted.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '毎月 ${appState.mainSalaryDay}日',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.accentBlue,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: context.appTheme.textMuted.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // デフォルト支出タイプ
          GestureDetector(
            onTap: () => _showDefaultGradePicker(appState),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: context.appTheme.bgPrimary,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'デフォルト支出タイプ',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: context.appTheme.textPrimary.withValues(alpha: 0.9),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '支出登録時の初期選択タイプ',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: context.appTheme.textMuted.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getGradeColor(appState.defaultExpenseGrade).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _getGradeLabel(appState.defaultExpenseGrade),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _getGradeColor(appState.defaultExpenseGrade),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: context.appTheme.textMuted.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // 通貨表示形式
          GestureDetector(
            onTap: () => _showCurrencyFormatPicker(appState),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: context.appTheme.bgPrimary,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '通貨表示形式',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: context.appTheme.textPrimary.withValues(alpha: 0.9),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '金額の表示形式を選択',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: context.appTheme.textMuted.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        _getCurrencyFormatLabel(appState.currencyFormat),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.accentBlue,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: context.appTheme.textMuted.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // カテゴリ管理
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CategoryManageScreen(),
                ),
              );
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'カテゴリ管理',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: context.appTheme.textPrimary.withValues(alpha: 0.9),
                      height: 1.4,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: context.appTheme.textMuted.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getCurrencyFormatLabel(String format) {
    switch (format) {
      case 'prefix':
        return '¥1,234';
      case 'suffix':
        return '1,234円';
      default:
        return '¥1,234';
    }
  }

  void _showCurrencyFormatPicker(AppState appState) {
    final formats = [
      {'value': 'prefix', 'label': '¥1,234', 'description': '¥記号を先頭に表示'},
      {'value': 'suffix', 'label': '1,234円', 'description': '円を末尾に表示'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: context.appTheme.bgCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ハンドル
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.appTheme.textMuted.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // タイトル
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(
                  '通貨表示形式を選択',
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: context.appTheme.textPrimary,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'アプリ全体の金額表示に適用されます。',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: context.appTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              // 形式選択
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: formats.map((format) {
                    final isSelected = appState.currencyFormat == format['value'];

                    return GestureDetector(
                      onTap: () {
                        appState.setCurrencyFormat(format['value'] as String);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '通貨表示形式を「${format['label']}」に設定しました',
                              style: GoogleFonts.inter(),
                            ),
                            backgroundColor: AppColors.accentBlue,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.accentBlue.withValues(alpha: 0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppColors.accentBlue : context.appTheme.borderSubtle.withValues(alpha: 0.3),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    format['label'] as String,
                                    style: GoogleFonts.ibmPlexSans(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? AppColors.accentBlue : context.appTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    format['description'] as String,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: context.appTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle,
                                size: 22,
                                color: AppColors.accentBlue,
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _getGradeLabel(String grade) {
    switch (grade) {
      case 'saving':
        return '節約';
      case 'standard':
        return '標準';
      case 'reward':
        return 'ご褒美';
      default:
        return '標準';
    }
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'saving':
        return AppColors.accentGreen;
      case 'standard':
        return AppColors.accentBlue;
      case 'reward':
        return AppColors.accentOrange;
      default:
        return AppColors.accentBlue;
    }
  }

  void _showDefaultGradePicker(AppState appState) {
    final grades = [
      {'value': 'saving', 'label': '節約', 'color': AppColors.accentGreen, 'icon': Icons.savings_outlined},
      {'value': 'standard', 'label': '標準', 'color': AppColors.accentBlue, 'icon': Icons.balance_outlined},
      {'value': 'reward', 'label': 'ご褒美', 'color': AppColors.accentOrange, 'icon': Icons.star_outline},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: context.appTheme.bgCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ハンドル
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.appTheme.textMuted.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // タイトル
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(
                  'デフォルト支出タイプを選択',
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: context.appTheme.textPrimary,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  '支出を登録するときに最初に選択されているタイプです。',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: context.appTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              // グレード選択
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: grades.map((grade) {
                    final isSelected = appState.defaultExpenseGrade == grade['value'];
                    final color = grade['color'] as Color;

                    return GestureDetector(
                      onTap: () {
                        appState.setDefaultExpenseGrade(grade['value'] as String);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'デフォルト支出タイプを「${grade['label']}」に設定しました',
                              style: GoogleFonts.inter(),
                            ),
                            backgroundColor: color,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? color : context.appTheme.borderSubtle.withValues(alpha: 0.3),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              grade['icon'] as IconData,
                              size: 22,
                              color: isSelected ? color : context.appTheme.textMuted,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                grade['label'] as String,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  color: isSelected ? color : context.appTheme.textPrimary,
                                ),
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle,
                                size: 22,
                                color: color,
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showSalaryDayPicker(AppState appState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: context.appTheme.bgCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ハンドル
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.appTheme.textMuted.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // タイトル
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(
                  '家計の開始日を選択',
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: context.appTheme.textPrimary,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  '給料日を設定すると、その日から翌給料日前日までが1ヶ月のサイクルになります。',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: context.appTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              // 日付選択グリッド（1〜28日）
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 1.2,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: 28,
                  itemBuilder: (context, index) {
                    final day = index + 1;
                    final isSelected = day == appState.mainSalaryDay;

                    return GestureDetector(
                      onTap: () {
                        appState.setMainSalaryDay(day);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '家計の開始日を毎月$day日に設定しました',
                              style: GoogleFonts.inter(),
                            ),
                            backgroundColor: AppColors.accentGreen,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.accentBlue
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? null
                              : Border.all(
                                  color: context.appTheme.borderSubtle.withValues(alpha: 0.3),
                                ),
                        ),
                        child: Text(
                          '$day',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 14,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : context.appTheme.textPrimary.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisplaySettingsCard(AppState appState) {
    return Container(
      decoration: BoxDecoration(
        color: context.appTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: context.cardElevationShadow,
      ),
      child: Column(
        children: [
          // ダークモード
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: context.appTheme.bgPrimary,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ダークモード',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: context.appTheme.textPrimary.withValues(alpha: 0.9),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '画面の明暗を切り替える',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: context.appTheme.textMuted.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: appState.isDark,
                  onChanged: (value) => appState.setDarkMode(value),
                  activeTrackColor: AppColors.accentBlue,
                ),
              ],
            ),
          ),

          // 背景色パターン（ライトモード時のみ）
          if (!appState.isDark)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '背景色',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: context.appTheme.textPrimary.withValues(alpha: 0.9),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'アプリの背景色を選択',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: context.appTheme.textMuted.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: ColorPattern.values.map((pattern) {
                      final isSelected = appState.colorPattern == pattern;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: () => appState.setColorPattern(pattern),
                          child: Column(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: pattern.bgColor,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.accentBlue
                                        : context.appTheme.borderSubtle,
                                    width: isSelected ? 2.5 : 1,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                pattern.label,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? AppColors.accentBlue
                                      : context.appTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPremiumPlanCard(AppState appState) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF2C2F4A) : const Color(0xFFF3EEFF);
    final cardBorderColor = isDark ? const Color(0xFF5B4B9B) : const Color(0xFFC4B5FD);
    final iconBgColor = isDark ? const Color(0xFF3A2F63) : const Color(0xFFE4D8FF);
    final accentColor = isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PremiumScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cardBorderColor,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.workspace_premium_outlined,
                size: 24,
                color: accentColor,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '有料プランについて',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.appTheme.textPrimary.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Plusプランで全ての機能をアンロック',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: context.appTheme.textSecondary.withValues(alpha: isDark ? 0.9 : 0.8),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: accentColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataManagementCard(AppState appState) {
    return Container(
      decoration: BoxDecoration(
        color: context.appTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: context.cardElevationShadow,
      ),
      child: Column(
        children: [
          // エクスポート
          GestureDetector(
            onTap: () => _handleExport(appState),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: context.appTheme.bgPrimary,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.upload_file_outlined,
                    size: 20,
                    color: AppColors.accentBlue.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'データをエクスポート',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: context.appTheme.textPrimary.withValues(alpha: 0.9),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'バックアップファイルを保存・共有',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: context.appTheme.textMuted.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: context.appTheme.textMuted.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),
          // インポート
          GestureDetector(
            onTap: () => _showImportConfirmDialog(appState),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  Icon(
                    Icons.download_outlined,
                    size: 20,
                    color: AppColors.accentOrange.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'データをインポート',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: context.appTheme.textPrimary.withValues(alpha: 0.9),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'バックアップファイルから復元',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: context.appTheme.textMuted.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: context.appTheme.textMuted.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _handleExport(AppState appState) async {
    final dbService = DatabaseService();
    final success = await dbService.exportDatabase();

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'バックアップファイルを共有しました',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: AppColors.accentGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'エクスポートに失敗しました',
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

  void _showImportConfirmDialog(AppState appState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.accentOrange,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'データの復元',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Text(
          '現在のデータはすべて上書きされます。\nこの操作は取り消せません。\n\n続行しますか？',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: context.appTheme.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'キャンセル',
              style: GoogleFonts.inter(
                color: context.appTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleImport(appState);
            },
            child: Text(
              '復元する',
              style: GoogleFonts.inter(
                color: AppColors.accentOrange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleImport(AppState appState) async {
    final dbService = DatabaseService();
    final success = await dbService.importDatabase();

    if (!mounted) return;

    if (success) {
      // データを再読み込み
      await appState.loadData();
      await appState.loadEntitlement();
      await appState.loadMonthlyAvailableAmount();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'データを復元しました。アプリを再起動してください。',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: AppColors.accentGreen,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          action: SnackBarAction(
            label: '再起動',
            textColor: Colors.white,
            onPressed: () {
              SystemNavigator.pop();
            },
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'インポートに失敗しました。.dbファイルを選択してください。',
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

  Widget _buildInfoCard(AppState appState) {
    return Container(
      decoration: BoxDecoration(
        color: context.appTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: context.cardElevationShadow,
      ),
      child: Column(
        children: [
          // バージョン（タップで開発者モード解放）
          GestureDetector(
            onTap: () => _onVersionTap(appState),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: context.appTheme.bgPrimary,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'バージョン',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: context.appTheme.textPrimary.withValues(alpha: 0.9),
                      height: 1.4,
                    ),
                  ),
                  Text(
                    '1.0.0',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: context.appTheme.textSecondary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // プレミアムステータス
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'プラン',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: context.appTheme.textPrimary.withValues(alpha: 0.9),
                    height: 1.4,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: appState.isPremium
                        ? const Color(0xFFF3EEFF)
                        : context.appTheme.bgPrimary,
                    borderRadius: BorderRadius.circular(6),
                    border: appState.isPremium
                        ? Border.all(color: const Color(0xFFC4B5FD))
                        : null,
                  ),
                  child: Text(
                    appState.isPremium ? 'Plus' : 'Free',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: appState.isPremium
                          ? const Color(0xFF7C3AED)
                          : context.appTheme.textSecondary.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeveloperSection(AppState appState) {
    return Container(
      decoration: BoxDecoration(
        color: context.appTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.accentOrange.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: context.cardElevationShadow,
      ),
      child: Column(
        children: [
          // 警告バナー
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accentOrangeLight.withValues(alpha: 0.7),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: AppColors.accentOrange.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '開発/テスト専用。Releaseでは無効。',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.accentOrange.withValues(alpha: 0.9),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Premium override スイッチ
          SwitchListTile(
            title: Text(
              'Premium override',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: context.appTheme.textPrimary.withValues(alpha: 0.9),
              ),
            ),
            subtitle: Text(
              appState.devPremiumOverride == null
                  ? 'Override: 無効（通常判定）'
                  : appState.devPremiumOverride!
                      ? 'Override: ON（強制Premium）'
                      : 'Override: OFF（強制Free）',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: context.appTheme.textSecondary.withValues(alpha: 0.7),
              ),
            ),
            value: appState.devPremiumOverride ?? false,
            activeTrackColor: AppColors.accentOrange,
            onChanged: (value) {
              appState.setDevPremiumOverride(value);
            },
          ),
          // リセットボタン
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      appState.resetDevPremiumOverride();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Override をリセットしました',
                            style: GoogleFonts.inter(fontSize: 13),
                          ),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: context.appTheme.bgPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Override をリセット',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: context.appTheme.textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // パフォーマンス計測セクション
          const Divider(height: 1),
          SwitchListTile(
            title: Text(
              'パフォーマンス計測',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: context.appTheme.textPrimary.withValues(alpha: 0.9),
              ),
            ),
            subtitle: Text(
              perfMonitor.isEnabled ? '計測中' : '無効',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: context.appTheme.textSecondary.withValues(alpha: 0.7),
              ),
            ),
            value: perfMonitor.isEnabled,
            activeTrackColor: AppColors.accentBlue,
            onChanged: (value) {
              setState(() {
                if (value) {
                  perfMonitor.enable();
                } else {
                  perfMonitor.disable();
                }
              });
            },
          ),
          // 計測結果表示ボタン
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => _showPerformanceReport(context),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.accentBlue.withValues(alpha: 0.1),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      '計測結果を表示',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.accentBlue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      perfMonitor.reset();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '計測データをリセットしました',
                            style: GoogleFonts.inter(fontSize: 13),
                          ),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: context.appTheme.bgPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'リセット',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: context.appTheme.textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPerformanceReport(BuildContext context) {
    final stats = perfMonitor.getAllStats();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'パフォーマンスレポート',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: stats.isEmpty
              ? Text(
                  '計測データがありません。\n計測を有効にしてアプリを操作してください。',
                  style: GoogleFonts.inter(fontSize: 14),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: stats.length,
                  itemBuilder: (context, index) {
                    final stat = stats[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stat['name'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accentBlue,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '回数: ${stat['count']}  平均: ${stat['avg']}ms  最大: ${stat['max']}ms',
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 12,
                              color: context.appTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              final report = perfMonitor.getReport();
              Clipboard.setData(ClipboardData(text: report));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'レポートをコピーしました',
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            },
            child: Text(
              'コピー',
              style: GoogleFonts.inter(color: AppColors.accentBlue),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '閉じる',
              style: GoogleFonts.inter(),
            ),
          ),
        ],
      ),
    );
  }
}
