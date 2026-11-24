import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/localization/app_strings.dart';
import 'core/data/settings_repository.dart';
import 'main.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/screens/welcome_screen.dart';
import 'ui/screens/consent_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/screening/screening_flow.dart';
import 'ui/screens/vision/vision_lab_screen.dart';
import 'ui/screens/history_screen.dart';
import 'ui/screens/learn_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/about_screen.dart';
import 'ui/screens/emergency_screen.dart';
import 'ui/screens/dev_dashboard.dart';
import 'ui/screens/dev/compat_lab_screen.dart';
import 'ui/screens/dev/eye_debug_screen.dart';
import 'ui/screens/dev/face_test_screen.dart';
import 'ui/screens/dev/ml_test_screen.dart';
import 'ui/screens/dev/vision_core_screen.dart';
import 'ui/screens/camera_help_screen.dart';
import 'ui/screens/capabilities_screen.dart';
import 'ui/screens/report_screen.dart';
import 'ui/screens/trends_screen.dart';
import 'ui/screens/references_screen.dart';
import 'ui/screens/methodology_screen.dart';
import 'ui/screens/retinal_info_screen.dart';
import 'ui/screens/color_calibration_screen.dart';

class OcuScanApp extends StatelessWidget {
  const OcuScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final settings = context.watch<SettingsRepository>();
    final strings = AppStrings(appState.lang);
    return MaterialApp(
      title: 'OcuScan',
      debugShowCheckedModeBanner: false,
      locale: Locale(appState.lang),
      // Declare both locales so Material scaffolding (Directionality,
      // dialogs, pickers) follows the selected language instead of
      // silently falling back to English/LTR.
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(highContrast: settings.highContrast, textScale: settings.textScale),
      // O5: multiply the in-app scale by the SYSTEM scale (clamped) instead
      // of overriding it — low-vision users keep their large text. Vision
      // Lab test letters stay locked by their own subtree override.
      builder: (ctx, child) {
        final sysScale =
            MediaQuery.of(ctx).textScaler.scale(14) / 14;
        final combined =
            (settings.textScale * sysScale).clamp(1.0, 1.6);
        return MediaQuery(
          data: MediaQuery.of(ctx)
              .copyWith(textScaler: TextScaler.linear(combined)),
          child: Directionality(
            textDirection:
                strings.isAr ? TextDirection.rtl : TextDirection.ltr,
            child: child!,
          ),
        );
      },
      initialRoute: '/',
      routes: {
        '/': (_) => const SplashScreen(),
        '/welcome': (_) => const WelcomeScreen(),
        '/consent': (_) => const ConsentScreen(),
        '/home': (_) => const HomeScreen(),
        '/screening': (_) => const ScreeningFlow(),
        '/vision': (_) => const VisionLabScreen(),
        '/history': (_) => const HistoryScreen(),
        '/trends': (_) => const TrendsScreen(),
        '/capabilities': (_) => const CapabilitiesScreen(),
        '/report': (_) => const ReportScreen(),
        '/learn': (_) => const LearnScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/about': (_) => const AboutScreen(),
        '/emergency': (_) => const EmergencyScreen(),
        '/dev': (_) => const DevDashboard(),
        '/eye-debug': (_) => const EyeDebugScreen(),
        '/face-test': (_) => const FaceTestScreen(),
        '/ml-test': (_) => const MlTestScreen(),
        '/vision-core': (_) => const VisionCoreScreen(),
        // Phase-12 alias: the universal face diagnostic center.
        '/face-diagnostic': (_) => const MlTestScreen(),
        '/compat-lab': (_) => const CompatLabScreen(),
        '/camera-help': (_) => const CameraHelpScreen(),
        '/references': (_) => const ReferencesScreen(),
        '/methodology': (_) => const MethodologyScreen(),
        '/retinal-info': (_) => const RetinalInfoScreen(),
        '/color-calibration': (_) => const ColorCalibrationScreen(),
      },
    );
  }
}
