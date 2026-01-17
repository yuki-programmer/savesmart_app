import 'package:flutter/material.dart';

/// Home画面のデザイン定数
class HomeConstants {
  // ========================================
  // 配色
  // ========================================

  /// 画面背景色（ニュアンス白）
  static const Color screenBackground = Color(0xFFF7F7F5);

  /// カード背景色
  static const Color cardBackground = Colors.white;

  /// 夜モード背景色（ダークネイビー）
  static const Color nightCardBackground = Color(0xFF1E2340);

  /// 朝グラデーション
  static const List<Color> morningGradient = [
    Color(0xFFFFF9F0), // トップ（ほんのり暖色）
    Color(0xFFFFFBF5), // 中間
    Colors.white,      // ボトム
  ];

  /// テキストカラー
  static const Color primaryText = Color(0xFF1A1A1A);
  static const Color secondaryText = Color(0xFF666666);
  static const Color tertiaryText = Color(0xFF999999);

  /// 夜モードテキストカラー
  static const Color nightPrimaryText = Colors.white;
  static const Color nightSecondaryText = Color(0xFFB8C5D6); // opacity 75%相当
  static const Color nightTertiaryText = Color(0xFF8A96AB);  // opacity 60%相当
  static const Color nightDivider = Color(0xFF2D3454);       // opacity 20%相当

  // ========================================
  // 影（統一）
  // ========================================

  /// 標準カードの影（控えめ）
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0A000000), // opacity: 0.04
      blurRadius: 8,
      offset: Offset(0, 2),
      spreadRadius: 0,
    ),
  ];

  /// ヒーローカードの影（少し強め）
  static const List<BoxShadow> heroCardShadow = [
    BoxShadow(
      color: Color(0x14000000), // opacity: 0.08
      blurRadius: 12,
      offset: Offset(0, 3),
      spreadRadius: 0,
    ),
  ];

  /// 夜モードカードの影
  static const List<BoxShadow> nightCardShadow = [
    BoxShadow(
      color: Color(0x1F000000), // opacity: 0.12
      blurRadius: 12,
      offset: Offset(0, 3),
      spreadRadius: 0,
    ),
  ];

  // ========================================
  // サイズ・余白
  // ========================================

  /// カード角丸
  static const double heroCardRadius = 16.0;
  static const double standardCardRadius = 12.0;

  /// カードパディング
  static const double heroCardPadding = 24.0;
  static const double standardCardPadding = 16.0;

  /// カード間マージン
  static const double cardSpacing = 16.0;

  /// 画面左右マージン
  static const double screenHorizontalMargin = 16.0;

  // ========================================
  // フォントサイズ
  // ========================================

  /// ヒーローカード
  static const double heroAmountSize = 48.0;     // 今日使えるお金
  static const double heroAmountSizeNight = 42.0; // 夜モード時
  static const double heroLabelSize = 14.0;      // ラベル
  static const double heroSubtextSize = 13.0;    // 明日の予測

  /// サマリーカード
  static const double summaryTitleSize = 13.0;   // 「今月の状況」
  static const double summaryMainSize = 24.0;    // 残り金額
  static const double summaryMetricSize = 14.0;  // 収入/出費
  static const double summaryLabelSize = 12.0;   // メトリックラベル

  /// 共通
  static const double bodyTextSize = 14.0;
  static const double captionTextSize = 12.0;
}
