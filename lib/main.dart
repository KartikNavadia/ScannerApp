import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'utils/app_colors.dart';
import 'scanning_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scanner App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Geist',
        scaffoldBackgroundColor: AppColors.surface,
        colorScheme: .fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          onPrimary: AppColors.onPrimary,
          secondary: AppColors.primaryLight,
          tertiary: AppColors.primaryDark,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
        ),
      ),
      home: const ScanningPage(),
    );
  }
}
