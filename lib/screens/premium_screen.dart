import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../config/typography.dart';
import '../services/app_state.dart';
import '../services/purchase_service.dart';

/// プラン種別
enum PlanType { monthly, yearly }

/// Premium提案画面
class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  PlanType _selectedPlan = PlanType.yearly;

  // カラー定義
  static const Color _accentBlue = Color(0xFF3B82F6);
  static const Color _accentBlueDark = Color(0xFF2563EB);
  static const Color _accentGold = Color(0xFFF59E0B);
  static const Color _accentGoldDark = Color(0xFFD97706);
  static const Color _accentGreen = Color(0xFF22C55E);
  static const Color _iconBgBlue = Color(0xFFEFF6FF);
  static const Color _iconBgGreen = Color(0xFFF0FDF4);
  static const Color _iconBgOrange = Color(0xFFFFF7ED);
  static const Color _iconBgPink = Color(0xFFFCE7F3);
  static const Color _accentPink = Color(0xFFEC4899);
  static const Color _trialBgStart = Color(0xFFEFF6FF);
  static const Color _trialBgEnd = Color(0xFFDBEAFE);
  static const Color _heroIconBgStart = Color(0xFFFEF3C7);
  static const Color _heroIconBgEnd = Color(0xFFFDE68A);

  Color get _textPrimaryColor => context.appTheme.textPrimary.withValues(alpha: 0.95);
  Color get _textSecondaryColor => context.appTheme.textSecondary.withValues(alpha: 0.9);
  Color get _textMutedColor => context.appTheme.textMuted.withValues(alpha: 0.85);
  Color get _borderColor => context.appTheme.borderSubtle.withValues(alpha: 0.9);

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<AppState>().isPremium;
    final purchaseService = PurchaseService.instance;
    final monthlyProduct = purchaseService.monthlyProduct;
    final yearlyProduct = purchaseService.yearlyProduct;
    final savingsMonths = _calculateSavingsMonths(
      monthlyProduct: monthlyProduct,
      yearlyProduct: yearlyProduct,
    );
    final hasStorePrices = monthlyProduct != null && yearlyProduct != null;
    final savingsText = hasStorePrices
        ? _formatSavingsText(savingsMonths)
        : '2ヶ月分おトク';
    final upgradeSavingsText = hasStorePrices
        ? _formatSavingsText(savingsMonths)
        : '2ヶ月分おトク（¥3,000/年）';

    return Scaffold(
      backgroundColor: context.appTheme.bgPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              _buildHeroSection(),
              _buildFeaturesSection(),
              if (!isPremium) ...[
                _buildPlanSection(
                  monthlyProduct: monthlyProduct,
                  yearlyProduct: yearlyProduct,
                  savingsText: savingsText,
                  showBadge: hasStorePrices ? savingsMonths > 0 : true,
                ),
                _buildTrialInfo(),
                _buildCtaButton(),
                _buildFooter(),
              ] else ...[
                _buildSubscribedSection(
                  monthlyProduct: monthlyProduct,
                  yearlyProduct: yearlyProduct,
                  upgradeSavingsText: upgradeSavingsText,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 加入中セクション
  Widget _buildSubscribedSection({
    required ProductDetails? monthlyProduct,
    required ProductDetails? yearlyProduct,
    required String? upgradeSavingsText,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusBg = isDark ? const Color(0xFF1E2F25) : _iconBgGreen;
    final statusBorder =
        isDark ? const Color(0xFF2E5A40) : _accentGreen.withValues(alpha: 0.25);
    final statusIconBg =
        isDark ? const Color(0xFF234131) : _accentGreen.withValues(alpha: 0.15);
    final statusAccent = isDark ? const Color(0xFF7FD09B) : _accentGreen;
    // TODO: 実際のサブスク情報はRevenueCat等から取得
    // 仮データ（開発者モード用）
    // ignore: dead_code を避けるためDateTime.now()を使用
    final isYearlyPlan = DateTime.now().millisecondsSinceEpoch % 2 == 0
        ? false  // 偶数秒: 月額プラン表示（アップグレードカードあり）
        : true;  // 奇数秒: 年額プラン表示
    final renewalDate = DateTime.now().add(const Duration(days: 30));
    final renewalDateStr =
        '${renewalDate.year}/${renewalDate.month.toString().padLeft(2, '0')}/${renewalDate.day.toString().padLeft(2, '0')}';
    final monthlyPrice = _planPriceText(
      type: PlanType.monthly,
      product: monthlyProduct,
      compact: true,
    );
    final yearlyPrice = _planPriceText(
      type: PlanType.yearly,
      product: yearlyProduct,
      compact: true,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // 加入中ステータスカード
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: statusBorder,
                width: 1,
              ),
            ),
            child: Column(
              children: [
                // チェックアイコン
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: statusIconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.check_circle,
                    size: 28,
                    color: statusAccent,
                  ),
                ),
                const SizedBox(height: 16),

                // タイトル
                Text(
                  'Plus に加入中',
                  style: AppTextStyles.sectionTitle(context).copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: statusAccent,
                  ),
                ),
                const SizedBox(height: 16),

                // プラン情報
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.appTheme.bgCard,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        label: '現在のプラン',
                        value: isYearlyPlan
                            ? '年額プラン（$yearlyPrice）'
                            : '月額プラン（$monthlyPrice）',
                      ),
                      const SizedBox(height: 10),
                      _buildInfoRow(
                        label: '次回更新日',
                        value: renewalDateStr,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 月額→年額へのアップグレードカード（月額プランの場合のみ）
          if (!isYearlyPlan) ...[
            const SizedBox(height: 16),
            _buildUpgradeCard(upgradeSavingsText: upgradeSavingsText),
          ],

          // サブスクリプション管理リンク
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _openSubscriptionManagement,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: context.appTheme.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _borderColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.settings_outlined,
                        size: 20,
                        color: _textSecondaryColor,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'サブスクリプションを管理',
                        style: AppTextStyles.body(context, weight: FontWeight.w500).copyWith(
                          color: _textPrimaryColor,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: _textMutedColor,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// プラン情報の行
  Widget _buildInfoRow({required String label, required String value}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: _textSecondaryColor,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _textPrimaryColor,
          ),
        ),
      ],
    );
  }

  /// 年額プランへのアップグレードカード
  Widget _buildUpgradeCard({required String? upgradeSavingsText}) {
    return GestureDetector(
      onTap: _handleUpgradeToYearly,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.appTheme.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _accentGold.withValues(alpha: 0.3), width: 1.5),
          boxShadow: context.cardElevationShadow,
        ),
        child: Row(
          children: [
            // アイコン
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_heroIconBgStart, _heroIconBgEnd],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_upward_rounded,
                size: 24,
                color: _accentGoldDark,
              ),
            ),
            const SizedBox(width: 14),

            // テキスト
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '年額プランに変更',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _textPrimaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_accentGold, _accentGoldDark],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'おすすめ',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (upgradeSavingsText != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      upgradeSavingsText,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: _accentGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // 矢印
            Icon(
              Icons.chevron_right,
              size: 22,
              color: _textMutedColor,
            ),
          ],
        ),
      ),
    );
  }

  /// 年額プランへのアップグレード処理
  void _handleUpgradeToYearly() {
    // TODO: RevenueCat / StoreKit 連携
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('年額プランへの変更処理を開始します'),
        backgroundColor: _accentGold,
      ),
    );
  }

  /// サブスクリプション管理画面を開く
  void _openSubscriptionManagement() {
    final url = Platform.isIOS
        ? 'https://apps.apple.com/account/subscriptions'
        : 'https://play.google.com/store/account/subscriptions';
    _openUrl(url);
  }

  /// ヘッダー（戻るボタン）
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: 24,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.appTheme.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _borderColor),
            ),
            child: Icon(
              Icons.chevron_left,
              size: 24,
              color: _textPrimaryColor,
            ),
          ),
        ),
      ),
    );
  }

  /// Heroセクション
  Widget _buildHeroSection() {
    return Padding(
      padding: const EdgeInsets.only(
        left: 24,
        right: 24,
        bottom: 32,
      ),
      child: Column(
        children: [
          // Hero Icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_heroIconBgStart, _heroIconBgEnd],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: context.cardElevationShadow,
            ),
            child: const Icon(
              Icons.star_rounded,
              size: 36,
              color: _accentGoldDark,
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            'SaveSmart Plus',
            style: AppTextStyles.pageTitle(context).copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: _textPrimaryColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),

          // Subtitle
          Text(
            'あなたの支出をもっと深く理解して\n賢いお金の使い方を見つけよう',
            textAlign: TextAlign.center,
            style: AppTextStyles.sub(context).copyWith(
              fontSize: 15,
              color: _textSecondaryColor,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  /// 機能カードセクション（横スクロール）
  Widget _buildFeaturesSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconBgCyan = isDark ? const Color(0xFF1E3B3F) : const Color(0xFFECFEFF);
    const accentCyan = Color(0xFF06B6D4);
    final iconBgBlue = isDark ? const Color(0xFF22324C) : _iconBgBlue;
    final iconBgOrange = isDark ? const Color(0xFF3B2A1D) : _iconBgOrange;
    final iconBgGreen = isDark ? const Color(0xFF203529) : _iconBgGreen;
    final iconBgPink = isDark ? const Color(0xFF3B2330) : _iconBgPink;

    final features = [
      _FeatureItem(
        icon: Icons.date_range_outlined,
        iconBgColor: iconBgBlue,
        iconColor: _accentBlue,
        title: '今週どれくらい\n使える？',
        desc: '週単位で予算を把握',
      ),
      _FeatureItem(
        icon: Icons.event_note_outlined,
        iconBgColor: iconBgCyan,
        iconColor: accentCyan,
        title: '将来の支出を\n先取り登録',
        desc: '支出計画をよりスマートに',
      ),
      _FeatureItem(
        icon: Icons.show_chart,
        iconBgColor: iconBgOrange,
        iconColor: _accentGold,
        title: '支出ペース\nグラフ',
        desc: '予算のペースを可視化',
      ),
      _FeatureItem(
        icon: Icons.speed,
        iconBgColor: iconBgGreen,
        iconColor: _accentGreen,
        title: '1日あたりの\n支出ペース',
        desc: '日々の消費を可視化',
      ),
      _FeatureItem(
        icon: Icons.flash_on_outlined,
        iconBgColor: iconBgPink,
        iconColor: _accentPink,
        title: 'クイック登録\n無制限',
        desc: 'よく使う支出を\nすぐ記録',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: SizedBox(
        height: 160,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: features.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            return _buildFeatureCard(features[index]);
          },
        ),
      ),
    );
  }

  Widget _buildFeatureCard(_FeatureItem item) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: context.cardElevationShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Container
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: item.iconBgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              item.icon,
              size: 22,
              color: item.iconColor,
            ),
          ),
          const SizedBox(height: 10),

          // Title
          Text(
            item.title,
            style: AppTextStyles.label(context, weight: FontWeight.w600).copyWith(
              color: _textPrimaryColor,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),

          // Description
          Text(
            item.desc,
            style: AppTextStyles.caption(context).copyWith(
              color: _textMutedColor,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// プラン選択セクション
  Widget _buildPlanSection({
    required ProductDetails? monthlyProduct,
    required ProductDetails? yearlyProduct,
    required String? savingsText,
    required bool showBadge,
  }) {
    final yearlyPrice = _planPriceText(
      type: PlanType.yearly,
      product: yearlyProduct,
    );
    final monthlyPrice = _planPriceText(
      type: PlanType.monthly,
      product: monthlyProduct,
    );
    final showOriginalPrice = monthlyProduct == null || yearlyProduct == null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Label
          Text(
            'プランを選択',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _textSecondaryColor,
            ),
          ),
          const SizedBox(height: 12),

          // Yearly Plan (with badge)
          _buildPlanCard(
            type: PlanType.yearly,
            name: '年額プラン',
            price: yearlyPrice,
            originalPrice: showOriginalPrice ? '¥3,600' : null,
            savings: savingsText,
            showBadge: showBadge,
          ),
          const SizedBox(height: 10),

          // Monthly Plan
          _buildPlanCard(
            type: PlanType.monthly,
            name: '月額プラン',
            price: monthlyPrice,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required PlanType type,
    required String name,
    required String price,
    String? originalPrice,
    String? savings,
    bool showBadge = false,
  }) {
    final isSelected = _selectedPlan == type;

    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = type),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFF8FAFF) : context.appTheme.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? _accentBlue : _borderColor,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                // Radio Button
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? _accentBlue : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? _accentBlue : _borderColor,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: context.appTheme.bgCard,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),

                // Plan Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (originalPrice != null) ...[
                        // アンカー効果: 元の価格を赤線で消す
                        Row(
                          children: [
                            Text(
                              originalPrice,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.red.shade400,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: Colors.red.shade400,
                                decorationThickness: 2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              price,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _textPrimaryColor,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Text(
                          price,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: _textSecondaryColor,
                          ),
                        ),
                      ],
                      if (savings != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          savings,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _accentGreen,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Badge
          if (showBadge)
            Positioned(
              top: -10,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_accentGold, _accentGoldDark],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'おすすめ',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// トライアル情報カード
  Widget _buildTrialInfo() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trialBgStart = isDark ? const Color(0xFF1E2C3D) : _trialBgStart;
    final trialBgEnd = isDark ? const Color(0xFF223552) : _trialBgEnd;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [trialBgStart, trialBgEnd],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: context.appTheme.bgCard,
                borderRadius: BorderRadius.circular(12),
                boxShadow: context.cardElevationShadow,
              ),
              child: const Icon(
                Icons.schedule,
                size: 22,
                color: _accentBlue,
              ),
            ),
            const SizedBox(width: 12),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '7日間無料でお試し',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '無料期間中はいつでもキャンセル可能',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: _textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// CTAボタン
  Widget _buildCtaButton() {
    return Padding(
      padding: const EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: 16,
      ),
      child: GestureDetector(
        onTap: _handleSubscribe,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_accentBlue, _accentBlueDark],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: context.cardElevationShadow,
          ),
          child: Center(
            child: Text(
              '無料トライアルを開始',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubscribe() async {
    final purchaseService = PurchaseService.instance;

    // ストアが利用可能か確認
    if (!purchaseService.isAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ストアに接続できません'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // 選択されたプランに応じて購入処理を実行
    final success = _selectedPlan == PlanType.yearly
        ? await purchaseService.purchaseYearly()
        : await purchaseService.purchaseMonthly();

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('購入処理を開始できませんでした'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleRestore() async {
    final purchaseService = PurchaseService.instance;

    if (!purchaseService.isAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ストアに接続できません'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    await purchaseService.restorePurchases();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('購入履歴を復元しています...'),
          backgroundColor: _accentBlue,
        ),
      );
    }
  }

  /// フッター
  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Text(
            'トライアル終了後、選択したプランで自動更新されます。\nいつでもキャンセルできます。',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: _textMutedColor,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          // 購入を復元ボタン
          GestureDetector(
            onTap: _handleRestore,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              decoration: BoxDecoration(
                border: Border.all(color: _borderColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '購入を復元',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _textSecondaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => _openUrl(
                  'https://yuki-programmer.github.io/savesmart_app/terms.html',
                ),
                child: Text(
                  '利用規約',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: _textSecondaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () => _openUrl(
                  'https://yuki-programmer.github.io/savesmart_app/privacy.html',
                ),
                child: Text(
                  'プライバシーポリシー',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: _textSecondaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('リンクを開けませんでした'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _planPriceText({
    required PlanType type,
    required ProductDetails? product,
    bool compact = false,
  }) {
    final separator = compact ? '/' : ' / ';
    final suffix = type == PlanType.yearly ? '年' : '月';
    if (product != null) {
      return '${product.price}$separator$suffix';
    }
    if (type == PlanType.yearly) {
      return compact ? '¥3,000/年' : '¥3,000 / 年';
    }
    return compact ? '¥300/月' : '¥300 / 月';
  }

  int _calculateSavingsMonths({
    required ProductDetails? monthlyProduct,
    required ProductDetails? yearlyProduct,
  }) {
    if (monthlyProduct == null || yearlyProduct == null) {
      return 0;
    }
    final monthlyPrice = monthlyProduct.rawPrice;
    final yearlyPrice = yearlyProduct.rawPrice;
    if (monthlyPrice <= 0) {
      return 0;
    }
    final savings = (monthlyPrice * 12) - yearlyPrice;
    if (savings <= 0) {
      return 0;
    }
    final months = (savings / monthlyPrice).round();
    return months < 1 ? 0 : months;
  }

  String? _formatSavingsText(int savingsMonths) {
    if (savingsMonths <= 0) {
      return null;
    }
    return '約$savingsMonthsヶ月分おトク';
  }
}

/// 機能カードのデータモデル
class _FeatureItem {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String desc;

  _FeatureItem({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.desc,
  });
}
