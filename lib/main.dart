import 'package:flutter/material.dart';
import 'package:pulchowkx_app/pages/main_layout.dart';
import 'package:pulchowkx_app/pages/onboarding_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/services/theme_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';

import 'package:pulchowkx_app/services/analytics_service.dart';
import 'package:pulchowkx_app/services/notification_service.dart';

// Global ThemeProvider instance for easy access
final themeProvider = ThemeProvider();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Failed to initialize Firebase: $e');
  }

  try {
    await Hive.initFlutter();
    await Hive.openBox('api_cache');
  } catch (e) {
    debugPrint('Failed to initialize Hive: $e');
  }

  // Non-blocking analytics
  AnalyticsService.logAppOpen().catchError((e) {
    debugPrint('Failed to log app open: $e');
  });

  // Non-blocking notification init
  NotificationService.initialize().catchError((e) {
    debugPrint('Failed to initialize notifications: $e');
  });
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeProvider,
      builder: (context, child) {
        return MaterialApp(
          title: 'PulchowkX',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          navigatorObservers: [AnalyticsService.observer],
          home: FutureBuilder<bool>(
            future: SharedPreferences.getInstance().then(
              (prefs) => prefs.getBool('has_seen_onboarding') ?? false,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  backgroundColor: Color(0xFFB088F9),
                  body: Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                );
              }
              return snapshot.data == true
                  ? const MainLayout()
                  : const OnboardingPage();
            },
          ),
        );
      },
    );
  }
}
