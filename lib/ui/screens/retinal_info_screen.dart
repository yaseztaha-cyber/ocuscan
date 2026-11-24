import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/localization/app_strings.dart';
import '../../main.dart';
import '../widgets/common.dart';
import '../widgets/evidence_sheet.dart';

/// Future Retinal Imaging information page: why the current phone cannot do
/// this, what an attachment would require, and the research status.
/// Labeled throughout as future research hardware.
class RetinalInfoScreen extends StatelessWidget {
  const RetinalInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(context.watch<AppState>().lang);
    return Scaffold(
      appBar: AppBar(title: Text(s.retinalInfo)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SafetyBanner(text: s.retinalBanner),
        SectionTitle(s.retinalWhyTitle),
        Text(s.retinalWhyBody),
        SectionTitle(s.retinalRequireTitle),
        Text(s.retinalRequireBody),
        SectionTitle(s.retinalSafetyTitle),
        Text(s.retinalSafetyBody),
        SectionTitle(s.retinalStatusTitle),
        Text(s.retinalStatusBody),
        const SizedBox(height: 8),
        const EvidenceButton(evidenceId: 'retinal_future'),
        SectionTitle(s.retinalRoadmapTitle),
        Text(s.retinalRoadmapBody),
      ]),
    );
  }
}
