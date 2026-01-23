import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'config/theme.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/add_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/category_budget_screen.dart';
import 'widgets/bottom_nav.dart';
import 'widgets/scheduled_expense_confirmation_dialog.dart';
import 'widgets/category_budget_report_dialog.dart';
import 'services/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Windows/Linux/macOSデスクトップではFFI初期化が必要
  final isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  if (isDesktop) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Crashlyticsはモバイルのみ（デスクトップ非対応）
  if (!isDesktop && !kDebugMode) {
    // Flutterフレームワーク内のエラーをCrashlyticsに送信
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    // 非同期エラーをCrashlyticsに送信
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  runApp(const SaveSmartApp());
}

class SaveSmartApp extends StatelessWidget {
  const SaveSmartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()
        ..loadMainSalaryDay() // 給料日設定を先にロード
        ..loadDefaultExpenseGrade() // デフォルト支出タイプを先にロード
        ..loadCurrencyFormat() // 通貨表示形式を先にロード
        ..loadData()
        ..loadEntitlement()
        ..loadMonthlyAvailableAmount(),
      child: MaterialApp(
        title: 'SaveSmart',
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ja', 'JP'),
          Locale('en', 'US'),
        ],
        locale: const Locale('ja', 'JP'),
        theme: ThemeData(
          scaffoldBackgroundColor: AppColors.bgPrimary,
          textTheme: GoogleFonts.interTextTheme(),
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.accentGreen,
          ),
        ),
        home: const MainScreen(),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _hasCheckedOverdueExpenses = false;
  bool _hasCheckedCategoryBudgetReport = false;

  static const String _keyCategoryBudgetReportShownCycle =
      'category_budget_report_shown_cycle';

  final List<Widget> _screens = const [
    HomeScreen(),
    AddScreen(),
    AnalyticsScreen(),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkOverdueScheduledExpenses();
    _checkCategoryBudgetReport();
  }

  Future<void> _checkOverdueScheduledExpenses() async {
    if (_hasCheckedOverdueExpenses) return;
    _hasCheckedOverdueExpenses = true;

    // AppStateの初期化完了を待つ
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    await ScheduledExpenseConfirmationDialog.showIfNeeded(context);
  }

  /// カテゴリ予算レポートのチェック（サイクル切替時に表示）
  Future<void> _checkCategoryBudgetReport() async {
    if (_hasCheckedCategoryBudgetReport) return;
    _hasCheckedCategoryBudgetReport = true;

    // AppStateの初期化完了を待つ
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    final appState = context.read<AppState>();

    // Premium以外は対象外
    if (!appState.isPremium) return;

    // カテゴリ予算がなければ対象外
    if (appState.categoryBudgets.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final currentCycleKey = appState.financialCycle.getCycleKey(DateTime.now());
    final lastShownCycle = prefs.getString(_keyCategoryBudgetReportShownCycle);

    // 今サイクルで既に表示済みなら対象外
    if (lastShownCycle == currentCycleKey) return;

    // 初回（lastShownCycle == null）は表示しない（前サイクルのデータがない可能性）
    if (lastShownCycle == null) {
      await prefs.setString(_keyCategoryBudgetReportShownCycle, currentCycleKey);
      return;
    }

    // サイクル切替を検出 → レポート表示
    if (!mounted) return;

    final budgetResults = await appState.getPreviousCycleBudgetStatus();
    final continuingBudgets = appState.continuingBudgets;
    final endingBudgets = appState.endingBudgets;

    if (!mounted) return;

    await CategoryBudgetReportDialog.show(
      context,
      budgetResults: budgetResults,
      continuingBudgets: continuingBudgets,
      endingBudgets: endingBudgets,
      currencyFormat: appState.currencyFormat,
      onClose: () async {
        // レポート表示済みとしてマーク
        await prefs.setString(_keyCategoryBudgetReportShownCycle, currentCycleKey);
        // 今月のみ予算を削除
        await appState.deleteOneTimeCategoryBudgets();
      },
      onEdit: () async {
        // レポート表示済みとしてマーク
        await prefs.setString(_keyCategoryBudgetReportShownCycle, currentCycleKey);
        // 今月のみ予算を削除
        await appState.deleteOneTimeCategoryBudgets();
        // 予算編集画面へ遷移
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CategoryBudgetScreen()),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // タブ切り替えリクエストを監視
    final appState = context.watch<AppState>();
    final requestedTab = appState.consumeRequestedTabIndex();
    if (requestedTab != null && requestedTab != _currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _currentIndex = requestedTab;
        });
      });
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNav(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}
