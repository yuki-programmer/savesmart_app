import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'config/theme.dart';

void main() {
  runApp(const SaveSmartApp());
}

class SaveSmartApp extends StatelessWidget {
  const SaveSmartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SaveSmart',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.bgPrimary,
        textTheme: GoogleFonts.plusJakartaSansTextTheme(),
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accentGreen,
        ),
      ),
      home: const Scaffold(
        body: Center(
          child: Text(
            'SaveSmart',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
