// Capability detail (§42–43): what is measured, hardware, status,
// possible association + explicit non-diagnosis note, evidence tier +
// study/modality/limits + live references. Associations never upgrade
// into diagnoses; FUTURE entries show no curated precedent honestly.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/evidence/evidence_repository.dart';
import '../../core/localization/app_strings.dart';
import '../../features/catalog/detection_catalog.dart';
import '../../main.dart';
import '../widgets/common.dart';

class CapabilityDetailScreen extends StatefulWidget {
  final CapabilityEntry entry;
  const CapabilityDetailScreen({super.key, required this.entry});

  @override
  State<CapabilityDetailScreen> createState() =>
      _CapabilityDetailScreenState();
}

class _CapabilityDetailScreenState extends State<CapabilityDetailScreen> {
  EvidenceRepository? repo;

  @override
  void initState() {
    super.initState();
    EvidenceRepository.load().then((r) {
      if (mounted) setState(() => repo = r);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = AppStrings(context.watch<AppState>().lang);
    final e = widget.entry;
    final ar = s.isAr;
    Widget section(String h, String v) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(h,
                  style: t.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6)),
              const SizedBox(height: 2),
              Text(v, style: t.bodyMedium),
            ]));
    return Scaffold(
      appBar: AppBar(
          title: Text(ar && e.nameAr.isNotEmpty ? e.nameAr : e.name)),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Row(children: [
          Expanded(
            child: Text(ar && e.nameAr.isNotEmpty ? e.nameAr : e.name,
                style: t.headlineSmall),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF0E7C7B)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(e.implementationStatus,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ]),
        if (ar && e.nameAr.isNotEmpty && e.nameAr != e.name) ...[
          const SizedBox(height: 2),
          Text(e.name, style: t.bodySmall),
        ],
        section(s.capWhatMeasured, e.observableFinding),
        section(s.capHardware, e.hardwareRequired.join(' • ')),
        section(s.capStatus,
            s.capStatusLine(e.implementationStatus, e.validationStatus)),
        section(s.capValidation,
            '${e.validationStatus} • ${e.clinicalStatus}'),
        section(s.capMeaning, e.conditionOrAssociation),
        section(s.capCannot, s.findingNotMeanBody),
        section(s.capEvidence,
            '${s.tierLabel(e.evidenceStatus)} • ${s.capModality}: ${e.modality}'),
        SectionTitle(s.detailCannotTell),
        for (final l in e.limitations) Text('• $l'),
        SectionTitle(s.capReferences),
        if (e.references.isEmpty)
          Text(s.capNoRefs, style: t.bodyMedium)
        else if (repo == null)
          const Center(child: CircularProgressIndicator())
        else
          for (final id in e.references)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                          repo!.reference(id)?.citation ??
                              id,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                          s.usedForLine(
                              repo!.reference(id)?.usedFor ??
                                  ''),
                          style: t.bodySmall),
                    ]),
              ),
            ),
        const SizedBox(height: 10),
        SafetyBanner(text: s.evidenceSheetSafety),
      ]),
    );
  }
}
