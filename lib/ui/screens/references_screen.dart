import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/evidence/evidence_repository.dart';
import '../../core/localization/app_strings.dart';
import '../../main.dart';
import '../widgets/common.dart';

/// Complete visible References page: every external source actually used by
/// medical evidence, wording, algorithms, methodology, vision tests, facial
/// analysis, retinal research, safety, privacy, and regulatory guidance.
/// Full bibliographic information where available — never bare URLs.
class ReferencesScreen extends StatefulWidget {
  const ReferencesScreen({super.key});
  @override
  State<ReferencesScreen> createState() => _ReferencesScreenState();
}

class _ReferencesScreenState extends State<ReferencesScreen> {
  EvidenceRepository? repo;
  String filter = 'All';
  String query = '';

  static const filters = [
    'All',
    'Ophthalmology',
    'Vision testing',
    'Facial analysis',
    'Neurology',
    'Retinal imaging',
    'AI safety',
    'Privacy',
    'Regulatory',
  ];

  static const _filterToCategory = {
    'Ophthalmology': 'ophthalmology',
    'Vision testing': 'vision_testing',
    'Facial analysis': 'facial_analysis',
    'Neurology': 'neurology',
    'Retinal imaging': 'retinal_imaging',
    'AI safety': 'ai_safety',
    'Privacy': 'privacy',
    'Regulatory': 'regulatory',
  };

  @override
  void initState() {
    super.initState();
    EvidenceRepository.load().then((r) {
      if (mounted) setState(() => repo = r);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = AppStrings(context.watch<AppState>().lang);
    return Scaffold(
      appBar: AppBar(title: Text(s.referencesTitle)),
      body: repo == null
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 8),
              Text(s.loadingEvidence),
            ]))
          : ListView(padding: const EdgeInsets.all(16), children: [
              SafetyBanner(text: s.referencesBanner),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.referencesVsTitle,
                            style: t.titleMedium),
                        const SizedBox(height: 4),
                        Text(s.referencesVsBody),
                      ]),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: InputDecoration(
                  labelText: s.referencesSearch,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) =>
                    setState(() => query = v.toLowerCase()),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final f in filters)
                    ChoiceChip(
                      label: Text(s.refFilterLabel(f)),
                      selected: filter == f,
                      onSelected: (_) =>
                          setState(() => filter = f),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                  s.dbLine(repo!.dbVersion, repo!.lastReviewed,
                      repo!.references.length),
                  style: t.bodySmall),
              const SizedBox(height: 8),
              if (_visible().isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(s.referencesEmpty, style: t.bodyMedium),
                ),
              for (final r in _visible())
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(s.refCategory(r.category),
                              style: t.bodySmall),
                          const SizedBox(height: 2),
                          Text(r.citation, style: t.titleMedium),
                          if (r.doi.isNotEmpty) Text('DOI: ${r.doi}'),
                          if (r.pmid.isNotEmpty)
                            Text('PMID: ${r.pmid}'),
                          if (r.url.isNotEmpty)
                            SelectableText(r.url,
                                style: t.bodySmall?.copyWith(
                                    color:
                                        const Color(0xFF0A5E5D))),
                          if (r.evidenceSummary.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(r.evidenceSummary),
                          ],
                          const SizedBox(height: 4),
                          Text(s.usedForLine(r.usedFor),
                              style: t.bodySmall),
                          Text(s.evidenceTypeLine(r.studyType),
                              style: t.bodySmall),
                          // F5/F8: overviews must never look like trials.
                          // Peer-review badge + verbatim access date.
                          Text(
                              r.isPeerReviewed
                                  ? s.refPeerBadge
                                  : s.refOverviewBadge,
                              style: t.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w700)),
                          if (r.accessDate.isNotEmpty)
                            Text(s.refAccessDate(r.accessDate),
                                style: t.bodySmall),
                          Text(
                              s.citedByLine(repo!
                                  .entriesForReference(r.id)
                                  .length),
                              style: t.bodySmall),
                        ]),
                  ),
                ),
            ]),
    );
  }

  List<EvidenceReference> _visible() {
    // Canonical filter codes map to categories; display labels are
    // localized separately, so filtering works in every language.
    String catFor(String f) => _filterToCategory[f] ?? '';

    return repo!.references.where((r) {
      if (filter != 'All' && r.category != catFor(filter)) {
        return false;
      }
      if (query.isNotEmpty) {
        final hay =
            '${r.authors} ${r.title} ${r.journal}'.toLowerCase();
        if (!hay.contains(query)) return false;
      }
      return true;
    }).toList();
  }
}
