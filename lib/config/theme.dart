import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ---------------------------------------------------------------------------
// アクセント色（全テーマ共通・固定）
// ---------------------------------------------------------------------------
class AppColors {
  static const bgPrimary = Color(0xFFF8F9FC); // ライトデフォルト（後方互換用）
  static const bgCard = Color(0xFFFFFFFF); // ライトデフォルト（後方互換用）
  static const accentGreen = Color(0xFF10B981);
  static const accentGreenLight = Color(0xFFD1FAE5);
  static const accentGreenDark = Color(0xFF059669);
  static const accentBlue = Color(0xFF5B7BEA);
  static const accentBlueLight = Color(0xFFDBEAFE);
  static const accentPurple = Color(0xFF8B5CF6);
  static const accentPurpleLight = Color(0xFFEDE9FE);
  static const accentOrange = Color(0xFFF59E0B);
  static const accentOrangeLight = Color(0xFFFEF3C7);
  static const accentRed = Color(0xFFE05555);
  static const accentRedLight = Color(0xFFFEE2E2);
  static const textPrimary = Color(0xFF1A1A2E); // ライトデフォルト（後方互換用）
  static const textSecondary = Color(0xFF64748B); // ライトデフォルト（後方互換用）
  static const textMuted = Color(0xFF94A3B8); // ライトデフォルト（後方互換用）
  static const borderSubtle = Color(0x0F000000); // ライトデフォルト（後方互換用）

  /// カテゴリ表示用カラーパレット（円グラフ・リスト等で使用）
  static const List<Color> categoryColors = [
    Color(0xFF2196F3), // blue
    Color(0xFF4CAF50), // green
    Color(0xFFFFC107), // amber
    Color(0xFFFF5722), // deep orange
    Color(0xFF9C27B0), // purple
    Color(0xFF607D8B), // blue grey
    Color(0xFF00BCD4), // cyan
    Color(0xFFE91E63), // pink
  ];
}

// ---------------------------------------------------------------------------
// 背景色パターン（ライトモード時のみ有効）
// ---------------------------------------------------------------------------
enum ColorPattern {
  white, // 白
  pink, // ピンク
  navy, // ネイビー
  darkGreen, // 濃い緑
}

extension ColorPatternInfo on ColorPattern {
  Color get bgColor {
    switch (this) {
      case ColorPattern.white:
        return Colors.white;
      case ColorPattern.pink:
        return const Color(0xFFF3C3D7);
      case ColorPattern.navy:
        return const Color(0xFFC8D1FF);
      case ColorPattern.darkGreen:
        return const Color(0xFFC7E9D6);
    }
  }

  String get label {
    switch (this) {
      case ColorPattern.white:
        return '白';
      case ColorPattern.pink:
        return 'ピンク';
      case ColorPattern.navy:
        return 'ネイビー';
      case ColorPattern.darkGreen:
        return 'ミント';
    }
  }

  /// SharedPreferences 保存用キー文字列
  String get key {
    switch (this) {
      case ColorPattern.white:
        return 'white';
      case ColorPattern.pink:
        return 'pink';
      case ColorPattern.navy:
        return 'navy';
      case ColorPattern.darkGreen:
        return 'darkGreen';
    }
  }

  static ColorPattern fromKey(String key) {
    switch (key) {
      case 'white':
        return ColorPattern.white;
      case 'pink':
        return ColorPattern.pink;
      case 'navy':
        return ColorPattern.navy;
      case 'darkGreen':
        return ColorPattern.darkGreen;
      case 'crimson':
        return ColorPattern.pink;
      default:
        return ColorPattern.pink;
    }
  }
}

// ---------------------------------------------------------------------------
// テーマカラーセット（ThemeExtension で ThemeData に添付）
// ---------------------------------------------------------------------------
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  final Color bgPrimary;
  final Color bgCard;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color borderSubtle;

  const AppThemeColors({
    required this.bgPrimary,
    required this.bgCard,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.borderSubtle,
  });

  @override
  AppThemeColors copyWith({
    Color? bgPrimary,
    Color? bgCard,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? borderSubtle,
  }) {
    return AppThemeColors(
      bgPrimary: bgPrimary ?? this.bgPrimary,
      bgCard: bgCard ?? this.bgCard,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      borderSubtle: borderSubtle ?? this.borderSubtle,
    );
  }

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) return this;
    return AppThemeColors(
      bgPrimary: Color.lerp(bgPrimary, other.bgPrimary, t)!,
      bgCard: Color.lerp(bgCard, other.bgCard, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
    );
  }

  // ライトモード色セット
  static AppThemeColors light(ColorPattern pattern) {
    return AppThemeColors(
      bgPrimary: pattern.bgColor,
      bgCard: const Color(0xFFFFFFFF),
      textPrimary: const Color(0xFF1A1A2E),
      textSecondary: const Color(0xFF4B5563),
      textMuted: const Color(0xFF6B7280),
      borderSubtle: const Color(0x0F000000),
    );
  }

  // ダークモード色セット
  static const AppThemeColors dark = AppThemeColors(
    bgPrimary: Color(0xFF1A1A2E),
    bgCard: Color(0xFF24243A),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFE2E8F0),
    textMuted: Color(0xFFCBD5E1),
    borderSubtle: Color(0x14FFFFFF),
  );
}

// ---------------------------------------------------------------------------
// ThemeData 生成ヘルパー
// ---------------------------------------------------------------------------
class AppTheme {
  static ThemeData build(
      {required bool isDark, ColorPattern pattern = ColorPattern.pink}) {
    final colors =
        isDark ? AppThemeColors.dark : AppThemeColors.light(pattern);

    return ThemeData(
      scaffoldBackgroundColor: colors.bgPrimary,
      textTheme: GoogleFonts.interTextTheme(),
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accentGreen,
        brightness: isDark ? Brightness.dark : Brightness.light,
      ),
      extensions: [colors],
    );
  }
}

// ---------------------------------------------------------------------------
// BuildContext ヘルパー
// ---------------------------------------------------------------------------
extension BuildContextTheme on BuildContext {
  AppThemeColors get appTheme =>
      Theme.of(this).extension<AppThemeColors>()!;

  bool get _isDarkMode => Theme.of(this).brightness == Brightness.dark;
  bool get _isWhiteBackground => appTheme.bgPrimary.value == Colors.white.value;

  List<BoxShadow> get cardElevationShadow {
    if (_isDarkMode || !_isWhiteBackground) {
      return const [];
    }
    return const [
      BoxShadow(
        color: Color(0x2E000000), // opacity: 0.18
        blurRadius: 16,
        offset: Offset(0, 4),
        spreadRadius: 0,
      ),
    ];
  }
}
