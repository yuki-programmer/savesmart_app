import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'config/theme.dart';
import 'screens/home_screen.dart';
import 'screens/add_screen.dart';
import 'screens/analytics_screen.dart';
import 'widgets/bottom_nav.dart';
import 'widgets/scheduled_expense_confirmation_dialog.dart';
import 'services/app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Windows/Linux/macOSデスクトップではFFI初期化が必要
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
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
  }

  Future<void> _checkOverdueScheduledExpenses() async {
    if (_hasCheckedOverdueExpenses) return;
    _hasCheckedOverdueExpenses = true;

    // AppStateの初期化完了を待つ
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    await ScheduledExpenseConfirmationDialog.showIfNeeded(context);
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
