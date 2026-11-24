import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/validation/analyzer_registry.dart';
import '../../core/localization/app_strings.dart';
import '../../main.dart';
import '../widgets/common.dart';
import '../widgets/evidence_sheet.dart';
import '../../core/evidence/evidence_repository.dart';

/// Methodology page: the 8-stage pipeline plus a methodology card per
/// module (input → processing → measurement → decision logic → output →
/// limitations). Engineering thresholds are labeled as such — never as
/// clinical diagnostic thresholds.
class MethodologyScreen extends StatelessWidget {
  const MethodologyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(context.watch<AppState>().lang);
    return Scaffold(
      appBar: AppBar(title: Text(s.methodology)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SafetyBanner(text: s.methodologyBanner),
        const SizedBox(height: 8),
        for (final st in s.methodologySteps)
          Card(
            child: ListTile(
              title: Text(st.$1,
                  style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text(st.$2),
            ),
          ),
        SectionTitle(s.methodologyModulesTitle),
        for (final a in AnalyzerRegistry.all)
          Card(
            child: ExpansionTile(
              title: Text('${a.title} ${a.version}'),
              subtitle: Text(a.key),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        _row(context, s.methodologyRowInput, a.input),
                        _row(context, s.methodologyRowProcessing, a.features),
                        _row(context, s.methodologyRowRequirements,
                            AnalyzerRegistry.requirementsFor(a.key)),
                        _row(context, s.methodologyRowMeasurement,
                            _measurementFor(a)),                        _row(context, s.methodologyRowThreshold,
                            '${a.thresholdBasis} — ${a.output}'),
                        _row(context, s.methodologyRowOutput, a.output),
                        _row(context, s.methodologyRowLimits,
                            a.knownLimitations.join('; ')),
                        const SizedBox(height: 8),
                        Builder(builder: (ctx) {
                          final id = EvidenceRepository
                              .evidenceIdForTestName(a.title);
                          if (id == null) {
                            return const SizedBox.shrink();
                          }
                          return EvidenceButton(evidenceId: id);
                        }),
                      ]),
                ),
              ],
            ),
          ),
      ]),
    );
  }

  String _measurementFor(AnalyzerInfo a) {
    switch (a.key) {
      case 'pupil':
        return 'Relative asymmetry index |L−R| / mean(|L|,|R|) over ≥3 valid frames.';
      case 'facial_asymmetry':
        return 'Per-region left/right movement amplitude and normalized difference.';
      case 'eyelid':
        return 'Relative left/right eyelid-opening difference.';
      case 'eye_alignment':
        return 'Gaze-direction deltas across the cover/uncover sequence.';
      case 'redness':
        return 'Scleral redness metric in RGB/HSV/Lab with distribution.';
      case 'scleral':
        return 'Calibrated scleral yellowness index (valid calibration only).';
      default:
        return a.features;
    }
  }

  Widget _row(BuildContext context, String k, String v) => Padding(
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
