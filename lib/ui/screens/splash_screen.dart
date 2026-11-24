import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/data/settings_repository.dart';
import '../../core/localization/app_strings.dart';
import '../../main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // O1: first launch follows the system locale (Arabic-first users no
    // longer start in English); an explicit choice always wins.
    try {
      final sys = WidgetsBinding
          .instance.platformDispatcher.locale.languageCode;
      final settings = context.read<SettingsRepository>();
      final app = context.read<AppState>();
      if (!settings.hasLanguagePreference && sys == 'ar') {
        app.setLang('ar');
      }
    } catch (_) {}
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      final s = context.read<SettingsRepository>();
      Navigator.pushReplacementNamed(context, s.consentGiven ? '/home' : '/welcome');
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = AppStrings(context.watch<AppState>().lang);
    return Scaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF0A5E5D), borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.remove_red_eye_outlined, color: Colors.white, size: 38),
          ),
          const SizedBox(height: 18),
          Text('OcuScan', style: t.displaySmall),
          const SizedBox(height: 6),
          Text(s.appVersionLine(kOcuScanVersion), style: t.bodySmall),
          const SizedBox(height: 2),
          Text(s.splashTagline, style: t.bodySmall),
          const SizedBox(height: 6),
          Text(s.splashPrototype, style: t.bodySmall),
          const SizedBox(height: 14),
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ]),
      ),
    );
  }
}
