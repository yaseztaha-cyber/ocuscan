import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/data/settings_repository.dart';
import '../../core/localization/app_strings.dart';
import '../../main.dart';
import '../widgets/common.dart';

class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});
  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool understood = false;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = AppStrings(context.watch<AppState>().lang);
    return Scaffold(
      appBar: AppBar(title: Text(s.consentTitle)),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text(s.consentHeading, style: t.headlineSmall),
        const SizedBox(height: 8),
        SafetyBanner(text: s.consentBanner),
        SectionTitle(s.consentPrivacyTitle),
        Text(s.consentPrivacyBody, style: t.bodyMedium),
        SectionTitle(s.consentEmergencyTitle),
        Text(s.consentEmergencyBody, style: t.bodyMedium),
        const SizedBox(height: 12),
        CheckboxListTile(
          value: understood,
          onChanged: (v) => setState(() => understood = v ?? false),
          title: Text(s.consentCheckbox),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: understood
              ? () async {
                  await context.read<SettingsRepository>().setConsent(true);
                  if (context.mounted) Navigator.pushReplacementNamed(context, '/home');
                }
              : null,
          child: Text(s.consentContinue),
        ),
        TextButton(
          onPressed: () => Navigator.pushNamed(context, '/emergency'),
          child: Text(s.consentReviewEmergency),
        ),
      ]),
    );
  }
}
