import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../main.dart';
import '../../core/localization/app_strings.dart';
import '../widgets/common.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().lang;
    final s = AppStrings(lang);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(actions: [
        TextButton(
          onPressed: () => context.read<AppState>().setLang(lang == 'en' ? 'ar' : 'en'),
          child: Text(lang == 'en' ? 'العربية' : 'English'),
        ),
      ]),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text(s.welcomeStepLine, style: t.labelLarge),
        const SizedBox(height: 4),
        Text(s.welcomeTitle, style: t.displaySmall),
        const SizedBox(height: 8),
        Text(s.welcomeBody, style: t.bodyLarge),
        SectionTitle(s.canTitle),
        for (final b in s.canItems) _Bullet(b),
        SectionTitle(s.cannotTitle),
        for (final b in s.cannotItems) _Bullet(b),
        const SizedBox(height: 12),
        SafetyBanner(text: '${s.disclaimer}\n\n${s.prototypeLabel}'),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => Navigator.pushNamed(context, '/consent'),
          child: Text(s.continueBtn),
        ),
        TextButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/emergency'),
          icon: const Icon(Icons.warning_amber_outlined),
          label: Text(s.urgentSymptoms),
        ),
      ]),
    );
  }
}

/// Direction-safe bullet: ListTile leading anchors the marker in both
/// LTR and RTL (a Row with a raw '•' drifts in RTL).
class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);
  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.fiber_manual_record, size: 10),
      title: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
