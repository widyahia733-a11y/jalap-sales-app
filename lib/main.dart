import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/app_constants.dart';
import 'core/utils/offline_sync_service.dart';
import 'features/auth/presentation/pages/login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: AppConstants.supabaseAnonKey,
    );
  } catch (error) {
    debugPrint('خطأ أثناء تهيئة Supabase: $error');
  }

  // تهيئة محرك التخزين المحلي وطابور المزامنة (Offline-First Architecture)
  await OfflineSyncService.instance.initialize();

  runApp(const JalapSalesApp());
}

/// تطبيق "جلب الميداني" (Jalap Sales App) بالهوية البصرية الملكية
class JalapSalesApp extends StatelessWidget {
  const JalapSalesApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme royalColorScheme = ColorScheme.fromSeed(
      seedColor: AppConstants.deepNavyBlue,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppConstants.deepNavyBlue,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFDCE3EF),
      onPrimaryContainer: AppConstants.deepNavyBlue,
      secondary: AppConstants.royalGold,
      onSecondary: AppConstants.deepNavyBlue,
      secondaryContainer: AppConstants.softRoyalGold,
      onSecondaryContainer: AppConstants.deepNavyBlue,
      surface: Colors.white,
      background: AppConstants.cleanLightGrey,
    );

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: royalColorScheme,
        scaffoldBackgroundColor: AppConstants.cleanLightGrey,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: AppConstants.deepNavyBlue,
          foregroundColor: Colors.white,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppConstants.deepNavyBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppConstants.royalGold,
          foregroundColor: AppConstants.deepNavyBlue,
        ),
        cardTheme: CardTheme(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      home: const LoginPage(),
    );
  }
}
