import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/evidence/evidence_repository.dart';
import '../../core/localization/app_strings.dart';
import '../../main.dart';
import 'common.dart';

/// Inline evidence linking: every Learn article and screening result offers
/// an Evidence button opening this structured sheet:
/// why included → supporting research → hardware → limitations → references.
/// All text comes from the curated database; nothing is generated.
class EvidenceButton extends StatelessWidget {
  final String evidenceId;
  final String? label;
  const EvidenceButton({super.key, required this.evidenceId, this.label});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(context.watch<AppState>().lang);
    return OutlinedButton.icon(
      onPressed: () async {
        final repo = await EvidenceRepository.load();
        final entry = repo.lookup(evidenceId);
        if (!context.mounted) return;
        if (entry == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.noEvidenceEntry)),
          );
          return;
        }
        showEvidenceSheet(context, entry, repo);
      },
      icon: const Icon(Icons.menu_book_outlined, size: 18),
      label: Text(label ?? s.evidenceButton),
    );
  }
}

void showEvidenceSheet(
    BuildContext context, EvidenceEntry entry, EvidenceRepository repo) {
  final s = AppStrings(context.read<AppState>().lang);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      builder: (_, c) => ListView(
          controller: c,
          padding: const EdgeInsets.all(20),
          children: [
            Row(children: [
              Expanded(
                child: Text(entry.name.isEmpty ? entry.finding : entry.name,
                    style: Theme.of(context).textTheme.headlineSmall),
              ),
              _tierBadge(entry.evidenceTier, s),
            ]),
            const SizedBox(height: 4),
            Text(s.evidenceStatusLine(entry.implementationStatus),
                style: Theme.of(context).textTheme.bodySmall),
            SectionTitle(s.evidenceSheetWhy),
            Text(entry.screeningMethod.isEmpty
                ? entry.description
                : entry.screeningMethod),
            if (entry.requiredHardware.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                  s.evidenceHardware(entry.requiredHardware),
                  style: Theme.of(context).textTheme.bodySmall),
            ],
            SectionTitle(s.evidenceSheetResearch),
            if (entry.referenceIds.isEmpty)
              Text(s.evidenceSheetNoRefs),
            for (final id in entry.referenceIds)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _referenceCard(repo.reference(id), id, s),
              ),
            SectionTitle(s.evidenceSheetLimits),
            for (final l in entry.limitations) Text('• $l'),
            if (entry.cannotConclude.isNotEmpty) ...[
              SectionTitle(s.detailCannotTell),
              for (final x in entry.cannotConclude) Text('• $x'),
            ],
            const SizedBox(height: 10),
            SafetyBanner(text: s.evidenceSheetSafety),
          ]),
    ),
  );
}

Widget _tierBadge(String tier, AppStrings s) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFF0E7C7B)),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(s.tierBadge(tier),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
  );
}

Widget _referenceCard(EvidenceReference? ref, String id, AppStrings s) {
  if (ref == null) return Text('• $id');
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ref.citation,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            if (ref.evidenceSummary.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(ref.evidenceSummary),
            ],
            const SizedBox(height: 4),
            Text(s.usedForLine(ref.usedFor),
                style: const TextStyle(fontSize: 13)),
          ]),
    ),
  );
}
