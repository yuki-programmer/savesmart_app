import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
  static const Color _screenBackground = Color(0xFFF7F7F5);
  static const Color _textPrimary = Color(0xFF1A1A1A);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _textMuted = Color(0xFF9CA3AF);
  static const Color _accentBlue = Color(0xFF3B82F6);
  static const Color _accentBlueDark = Color(0xFF2563EB);
  static const Color _accentGold = Color(0xFFF59E0B);
  static const Color _accentGoldDark = Color(0xFFD97706);
  static const Color _accentGreen = Color(0xFF22C55E);
  static const Color _accentPurple = Color(0xFFA855F7);
  static const Color _borderLight = Color(0xFFE5E7EB);
  static const Color _iconBgBlue = Color(0xFFEFF6FF);
  static const Color _iconBgGreen = Color(0xFFF0FDF4);
  static const Color _iconBgOrange = Color(0xFFFFF7ED);
  static const Color _iconBgPurple = Color(0xFFFAF5FF);
  static const Color _trialBgStart = Color(0xFFEFF6FF);
  static const Color _trialBgEnd = Color(0xFFDBEAFE);
  static const Color _heroIconBgStart = Color(0xFFFEF3C7);
  static const Color _heroIconBgEnd = Color(0xFFFDE68A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _screenBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              _buildHeroSection(),
              _buildFeaturesSection(),
              _buildPlanSection(),
              _buildTrialInfo(),
              _buildCtaButton(),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _borderLight),
            ),
            child: const Icon(
              Icons.chevron_left,
              size: 24,
              color: _textPrimary,
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
              boxShadow: [
                BoxShadow(
                  color: _accentGold.withOpacity(0.2),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
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
            style: GoogleFonts.inter(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),

          // Subtitle
          Text(
            'あなたの支出をもっと深く理解して\n賢いお金の使い方を見つけよう',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: _textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  /// 機能カードセクション（横スクロール）
  Widget _buildFeaturesSection() {
    final features = [
      _FeatureItem(
        icon: Icons.pie_chart_outline,
        iconBgColor: _iconBgBlue,
        iconColor: _accentBlue,
        title: 'カテゴリ別\n支出割合',
        desc: 'どこにお金を使ってる？',
      ),
      _FeatureItem(
        icon: Icons.show_chart,
        iconBgColor: _iconBgGreen,
        iconColor: _accentGreen,
        title: '支出ペース\nグラフ',
        desc: '予算のペースを可視化',
      ),
      _FeatureItem(
        icon: Icons.account_balance_wallet_outlined,
        iconBgColor: _iconBgOrange,
        iconColor: _accentGold,
        title: '家計の\n余裕',
        desc: 'あといくら使える？',
      ),
      _FeatureItem(
        icon: Icons.bar_chart,
        iconBgColor: _iconBgPurple,
        iconColor: _accentPurple,
        title: 'カテゴリ\n詳細分析',
        desc: '12ヶ月のトレンド',
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),

          // Description
          Text(
            item.desc,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: _textMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// プラン選択セクション
  Widget _buildPlanSection() {
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
              color: _textSecondary,
            ),
          ),
          const SizedBox(height: 12),

          // Yearly Plan (with badge)
          _buildPlanCard(
            type: PlanType.yearly,
            name: '年額プラン',
            price: '¥3,000 / 年',
            savings: '2ヶ月分おトク',
            showBadge: true,
          ),
          const SizedBox(height: 10),

          // Monthly Plan
          _buildPlanCard(
            type: PlanType.monthly,
            name: '月額プラン',
            price: '¥300 / 月',
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
              color: isSelected ? const Color(0xFFF8FAFF) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? _accentBlue : _borderLight,
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
                      color: isSelected ? _accentBlue : _borderLight,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
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
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        price,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: _textSecondary,
                        ),
                      ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_trialBgStart, _trialBgEnd],
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
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
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '無料期間中はいつでもキャンセル可能',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: _textSecondary,
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
            boxShadow: [
              BoxShadow(
                color: _accentBlue.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
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

  void _handleSubscribe() {
    // TODO: RevenueCat / StoreKit 連携
    // _selectedPlan に応じて購入処理を実行
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _selectedPlan == PlanType.yearly
              ? '年額プランの購入処理を開始します'
              : '月額プランの購入処理を開始します',
        ),
        backgroundColor: _accentBlue,
      ),
    );
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
              color: _textMuted,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => _openUrl('https://example.com/terms'),
                child: Text(
                  '利用規約',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: _textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () => _openUrl('https://example.com/privacy'),
                child: Text(
                  'プライバシーポリシー',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: _textSecondary,
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

  void _openUrl(String url) {
    // TODO: url_launcher パッケージ追加後に実装
    debugPrint('Opening URL: $url');
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
