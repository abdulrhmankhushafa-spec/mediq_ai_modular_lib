import 'package:flutter/material.dart';
import '../controllers/app_controller.dart';
import '../core/theme/app_theme.dart';
import '../screens/splash/splash_screen.dart';

class MediqAiApp extends StatelessWidget {
  const MediqAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appController,
      builder: (context, _) {
        final isDark = appController.isDarkMode;
        return MaterialApp(
          title: 'MEDIQ AI',
          debugShowCheckedModeBanner: false,
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(appController.fontScale),
              ),
              child: child!,
            ),
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}
