import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';

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
  static const Color _borderLight = Color(0xFFE5E7EB);
  static const Color _iconBgBlue = Color(0xFFEFF6FF);
  static const Color _iconBgGreen = Color(0xFFF0FDF4);
  static const Color _iconBgOrange = Color(0xFFFFF7ED);
  static const Color _iconBgPink = Color(0xFFFCE7F3);
  static const Color _accentPink = Color(0xFFEC4899);
  static const Color _trialBgStart = Color(0xFFEFF6FF);
  static const Color _trialBgEnd = Color(0xFFDBEAFE);
  static const Color _heroIconBgStart = Color(0xFFFEF3C7);
  static const Color _heroIconBgEnd = Color(0xFFFDE68A);

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<AppState>().isPremium;

    return Scaffold(
      backgroundColor: _screenBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              _buildHeroSection(),
              _buildFeaturesSection(),
              if (!isPremium) ...[
                _buildPlanSection(),
                _buildTrialInfo(),
                _buildCtaButton(),
                _buildFooter(),
              ] else ...[
                _buildSubscribedSection(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 加入中セクション
  Widget _buildSubscribedSection() {
    // TODO: 実際のサブスク情報はRevenueCat等から取得
    // 仮データ（開発者モード用）
    // ignore: dead_code を避けるためDateTime.now()を使用
    final isYearlyPlan = DateTime.now().millisecondsSinceEpoch % 2 == 0
        ? false  // 偶数秒: 月額プラン表示（アップグレードカードあり）
        : true;  // 奇数秒: 年額プラン表示
    final renewalDate = DateTime.now().add(const Duration(days: 30));
    final renewalDateStr =
        '${renewalDate.year}/${renewalDate.month.toString().padLeft(2, '0')}/${renewalDate.day.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // 加入中ステータスカード
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _accentGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _accentGreen.withValues(alpha: 0.25),
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
                    color: _accentGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    size: 28,
                    color: _accentGreen,
                  ),
                ),
                const SizedBox(height: 16),

                // タイトル
                Text(
                  'Plus に加入中',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _accentGreen,
                  ),
                ),
                const SizedBox(height: 16),

                // プラン情報
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        label: '現在のプラン',
                        value: isYearlyPlan ? '年額プラン（¥3,600/年）' : '月額プラン（¥400/月）',
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
            _buildUpgradeCard(),
          ],

          // サブスクリプション管理リンク
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _openSubscriptionManagement,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _borderLight),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.settings_outlined,
                        size: 20,
                        color: _textSecondary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'サブスクリプションを管理',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: _textMuted,
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
            color: _textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _textPrimary,
          ),
        ),
      ],
    );
  }

  /// 年額プランへのアップグレードカード
  Widget _buildUpgradeCard() {
    return GestureDetector(
      onTap: _handleUpgradeToYearly,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _accentGold.withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _accentGold.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
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
                          color: _textPrimary,
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
                  const SizedBox(height: 4),
                  Text(
                    '3ヶ月分おトク（¥3,600/年）',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: _accentGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // 矢印
            const Icon(
              Icons.chevron_right,
              size: 22,
              color: _textMuted,
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
    // TODO: App Store / Google Play のサブスクリプション管理画面を開く
    // iOS: App Store → アカウント → サブスクリプション
    // Android: Google Play → 支払いと定期購入 → 定期購入
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('サブスクリプション管理画面を開きます'),
        backgroundColor: _accentBlue,
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
                  color: _accentGold.withValues(alpha: 0.2),
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
    const iconBgCyan = Color(0xFFECFEFF);
    const accentCyan = Color(0xFF06B6D4);

    final features = [
      _FeatureItem(
        icon: Icons.event_note_outlined,
        iconBgColor: iconBgCyan,
        iconColor: accentCyan,
        title: '将来の支出を\n先取り登録',
        desc: '支出計画をよりスマートに',
      ),
      _FeatureItem(
        icon: Icons.date_range_outlined,
        iconBgColor: _iconBgBlue,
        iconColor: _accentBlue,
        title: '今週どれくらい\n使える？',
        desc: '週単位で予算を把握',
      ),
      _FeatureItem(
        icon: Icons.pie_chart_outline,
        iconBgColor: _iconBgGreen,
        iconColor: _accentGreen,
        title: 'カテゴリ別\n支出割合',
        desc: 'どこにお金を使ってる？',
      ),
      _FeatureItem(
        icon: Icons.show_chart,
        iconBgColor: _iconBgOrange,
        iconColor: _accentGold,
        title: '支出ペース\nグラフ',
        desc: '予算のペースを可視化',
      ),
      _FeatureItem(
        icon: Icons.tune_outlined,
        iconBgColor: _iconBgPink,
        iconColor: _accentPink,
        title: 'カテゴリに\n予算を設定',
        desc: '使いすぎを事前に防ぐ',
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
            color: Colors.black.withValues(alpha: 0.06),
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
            price: '¥3,600 / 年',
            originalPrice: '¥4,800',
            savings: '3ヶ月分おトク',
            showBadge: true,
          ),
          const SizedBox(height: 10),

          // Monthly Plan
          _buildPlanCard(
            type: PlanType.monthly,
            name: '月額プラン',
            price: '¥400 / 月',
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
                                color: _textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Text(
                          price,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: _textSecondary,
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
                    color: Colors.black.withValues(alpha: 0.06),
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
                color: _accentBlue.withValues(alpha: 0.3),
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
