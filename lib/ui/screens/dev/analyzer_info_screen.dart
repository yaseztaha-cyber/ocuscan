// Analyzer transparency cards: input, features, output, quality
// requirements, failure conditions, known limitations, version.
// Experimental modules carry a prominent badge.

import 'package:flutter/material.dart';
import '../../../core/localization/dev_strings.dart';
import '../../../core/validation/analyzer_registry.dart';
import '../../widgets/common.dart';

class AnalyzerInfoScreen extends StatelessWidget {
  const AnalyzerInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appLang =
        Localizations.localeOf(context).languageCode == 'ar' ? 'ar' : 'en';
    final s = DevStrings(appLang);
    return Scaffold(
      appBar: AppBar(title: Text(s.analyzerInfo)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SafetyBanner(text: s.analyzerCardBanner),
        const SizedBox(height: 8),
        for (final a in AnalyzerRegistry.all)
          Card(
            child: ExpansionTile(
              title: Text('${a.title} ${a.version}'),
              subtitle: Text(a.key,
                  style: Theme.of(context).textTheme.bodySmall),
              trailing: a.experimental
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          border: Border.all(
                              color: const Color(0xFF9A6B00)),
                          borderRadius: BorderRadius.circular(12)),
                      child: Text(s.expBadge,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: const Color(0xFF9A6B00),
                                  fontWeight: FontWeight.w800)),
                    )
                  : null,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (a.experimental)
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: 8),
                            child: Text('⚠ ${s.experimentalBadge}',
                                style: const TextStyle(
                                    color: Color(0xFF9A6B00),
                                    fontWeight: FontWeight.w700)),
                          ),
                        _kv('Input', a.input, context),
                        _kv('Features', a.features, context),
                        _kv('Output', a.output, context),
                        _kv('Version', a.versionLabel, context),
                        _kv('Decision threshold', a.thresholdBasis, context),
                        _kv(
                            'Training data',
                            'Not applicable — deterministic measurement algorithm; no ML training dataset. '
                            'Face detection uses the device on-device detector; OcuScan adds no trained disease model.',
                            context),
                        _kv(
                            'Validation',
                            a.experimental
                                ? 'No OcuScan validation completed — experimental.'
                                : 'OcuScan validation: repeatability and failure analysis via the research workspace; no clinical validation.',
                            context),
                        _kv(
                            'Clinical status',
                            a.experimental
                                ? 'Research / Experimental — not clinically validated.'
                                : 'Research screening prototype — not clinically validated.',
                            context),
                        const SectionTitle('Quality requirements'),
                        for (final q in a.qualityRequirements)
                          Text('• $q'),
                        const SectionTitle('Failure conditions'),
                        for (final q in a.failureConditions)
                          Text('• $q'),
                        const SectionTitle('Known limitations'),
                        for (final q in a.knownLimitations)
                          Text('• $q'),
                      ]),
                ),
              ],
            ),
          ),
      ]),
    );
  }

  Widget _kv(String k, String v, BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.bodyMedium,
            children: [
              TextSpan(
                  text: '$k: ',
                  style:
                      const TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: v),
            ],
          ),
        ),
      );
}
