import 'dart:convert';
import 'package:flutter/services.dart';

import '../config/app_version.dart';

/// App + knowledge-base versions recorded on research exports.
class AppInfo {
  static const String ocuscanVersion = kOcuScanVersion;
  static const String evidenceDbVersion = '1.0';
}

/// Full bibliographic reference bundled with the evidence database.
/// Web overviews carry organization + title + URL + access date; peer-reviewed
/// records carry journal + year + DOI/PMID where available.
class EvidenceReference {
  final String id;
  final String authors;
  final String title;
  final String journal;
  final String year;
  final String volume;
  final String issue;
  final String pages;
  final String doi;
  final String pmid;
  final String url;
  final String category;
  final String usedFor;
  final String evidenceSummary;
  final String accessDate;
  final String studyType;

  EvidenceReference({
    required this.id,
    required this.authors,
    required this.title,
    required this.journal,
    required this.year,
    required this.volume,
    required this.issue,
    required this.pages,
    required this.doi,
    required this.pmid,
    required this.url,
    required this.category,
    required this.usedFor,
    required this.evidenceSummary,
    required this.accessDate,
    this.studyType = 'peer_reviewed',
  });

  factory EvidenceReference.fromJson(Map<String, dynamic> j) =>
      EvidenceReference(
        id: (j['id'] ?? '') as String,
        authors: (j['authors'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        journal: (j['journal'] ?? '') as String,
        year: (j['year'] ?? '') as String,
        volume: (j['volume'] ?? '') as String,
        issue: (j['issue'] ?? '') as String,
        pages: (j['pages'] ?? '') as String,
        doi: (j['doi'] ?? '') as String,
        pmid: (j['pmid'] ?? '') as String,
        url: (j['url'] ?? '') as String,
        category: (j['category'] ?? '') as String,
        usedFor: (j['used_for'] ?? '') as String,
        evidenceSummary: (j['evidence_summary'] ?? '') as String,
        accessDate: (j['access_date'] ?? '') as String,
        studyType: (j['study_type'] ?? 'peer_reviewed') as String,
      );

  /// Short display citation, e.g. "Ueno Y, et al. (2024). Title. Journal."
  String get citation {
    final yearPart = year.isEmpty ? '' : ' ($year)';
    final journalPart = journal.isEmpty ? '' : ' $journal.';
    return '$authors$yearPart. $title.$journalPart'.trim();
  }

  bool get isPeerReviewed => studyType == 'peer_reviewed';
}

class EvidenceEntry {
  final String id;
  final String finding;
  final String name;
  final String nameAr;
  final String category;
  final String description;
  final String screeningMethod;
  final List<String> requiredHardware;
  final String evidenceTier; // A | B | C
  final String implementationStatus; // CURRENT | EXPERIMENTAL | FUTURE | NOT_SUITABLE_FOR_CURRENT_HARDWARE
  final List<String> possibleAssociations;
  final List<String> cannotConclude;
  final List<String> limitations;
  final String action;
  final List<String> emergencySigns;
  final List<String> references;
  final List<String> referenceIds;
  final String lastReviewed;

  EvidenceEntry({
    required this.id,
    required this.finding,
    required this.name,
    required this.nameAr,
    required this.category,
    required this.description,
    required this.screeningMethod,
    required this.requiredHardware,
    required this.evidenceTier,
    required this.implementationStatus,
    required this.possibleAssociations,
    required this.cannotConclude,
    required this.limitations,
    required this.action,
    required this.emergencySigns,
    required this.references,
    required this.referenceIds,
    required this.lastReviewed,
  });

  factory EvidenceEntry.fromJson(Map<String, dynamic> j) {
    List<String> strings(dynamic v) =>
        v is List ? v.map((e) => e.toString()).toList() : const [];
    return EvidenceEntry(
      id: ((j['id'] ?? j['finding'] ?? '')) as String,
      finding: (j['finding'] ?? '') as String,
      name: (j['name'] ?? '') as String,
      nameAr: (j['nameAr'] ?? '') as String,
      category: (j['category'] ?? '') as String,
      description: (j['description'] ??
              j['observable_finding'] ??
              '') as String,
      screeningMethod: (j['screening_method'] ?? '') as String,
      requiredHardware: strings(j['required_hardware']),
      evidenceTier: (j['evidence_tier'] ?? 'C') as String,
      implementationStatus:
          (j['implementation_status'] ?? 'EXPERIMENTAL') as String,
      possibleAssociations:
          strings(j['possible_associations']),
      cannotConclude: strings(j['cannot_conclude']),
      limitations: strings(j['limitations']),
      action: (j['action'] ?? j['recommended_action'] ?? '') as String,
      emergencySigns: strings(
          j['emergency_signs'] ?? j['emergency_flags']),
      references: strings(j['references']),
      referenceIds: strings(
          j['reference_ids'] ?? j['references']),
      lastReviewed: (j['last_reviewed'] ?? '') as String,
    );
  }

  bool get isCurrent => implementationStatus == 'CURRENT';
  bool get isExperimental =>
      implementationStatus == 'EXPERIMENTAL' || evidenceTier == 'C';
}

/// Curated, local educational content. The app never invents explanations:
/// findings pull text from here. No generative model overrides it.
class EvidenceRepository {
  final Map<String, EvidenceEntry> _entries;
  final Map<String, EvidenceReference> _references;
  final String dbVersion;
  final String lastReviewed;
  final List<String> changes;

  /// Test-only transport override. Production always uses the asset bundle;
  /// widget tests point this at the same file on disk because the test
  /// environment cannot serve rootBundle assets to the fake-async zone.
  /// The data loaded is identical — only the transport differs.
  static Future<EvidenceRepository> Function()? debugLoaderOverride;

  EvidenceRepository(
    this._entries, {
    Map<String, EvidenceReference>? references,
    this.dbVersion = '1.0',
    this.lastReviewed = '',
    List<String>? changes,
  })  : _references = references ?? {},
        changes = changes ?? const [];

  static Future<EvidenceRepository> load() async {
    final override = debugLoaderOverride;
    if (override != null) return override();
    final raw = await rootBundle.loadString('assets/medical_evidence.json');
    return EvidenceRepository.parse(raw);
  }

  /// Parse from raw JSON text (also used by tests without asset bundle).
  factory EvidenceRepository.parse(String raw) {
    final decoded = json.decode(raw) as Map<String, dynamic>;
    final refs = <String, EvidenceReference>{};
    for (final r
        in ((decoded['references'] ?? []) as List).cast<Map<String, dynamic>>()) {
      final ref = EvidenceReference.fromJson(r);
      refs[ref.id] = ref;
    }
    final map = <String, EvidenceEntry>{};
    for (final e in (decoded['entries'] as List).cast<Map<String, dynamic>>()) {
      final entry = EvidenceEntry.fromJson(e);
      // Resolve reference ids to short display citations.
      final resolved = <String>[
        for (final id in entry.referenceIds)
          if (refs.containsKey(id)) refs[id]!.citation else id
      ];
      map[entry.finding] = EvidenceEntry(
        id: entry.id,
        finding: entry.finding,
        name: entry.name,
        nameAr: entry.nameAr,
        category: entry.category,
        description: entry.description,
        screeningMethod: entry.screeningMethod,
        requiredHardware: entry.requiredHardware,
        evidenceTier: entry.evidenceTier,
        implementationStatus: entry.implementationStatus,
        possibleAssociations: entry.possibleAssociations,
        cannotConclude: entry.cannotConclude,
        limitations: entry.limitations,
        action: entry.action,
        emergencySigns: entry.emergencySigns,
        references: resolved.isEmpty ? entry.references : resolved,
        referenceIds: entry.referenceIds,
        lastReviewed: entry.lastReviewed,
      );
    }
    return EvidenceRepository(
      map,
      references: refs,
      dbVersion: (decoded['dbVersion'] ?? '1.0') as String,
      lastReviewed: (decoded['lastReviewed'] ?? '') as String,
      changes: ((decoded['changes'] ?? []) as List)
          .map((e) => e.toString())
          .toList(),
    );
  }

  /// Synchronous test/placeholder constructor.
  factory EvidenceRepository.fromEntries(List<EvidenceEntry> entries) {
    return EvidenceRepository({for (final e in entries) e.finding: e});
  }

  EvidenceEntry? lookup(String findingKey) => _entries[findingKey];
  List<EvidenceEntry> get all => _entries.values.toList();
  List<EvidenceReference> get references => _references.values.toList();
  EvidenceReference? reference(String id) => _references[id];

  List<EvidenceEntry> entriesForReference(String id) =>
      _entries.values.where((e) => e.referenceIds.contains(id)).toList();

  // ---- Audit helpers (used by the /dev Evidence Audit page + tests) ----

  /// Entries with no resolvable reference.
  List<EvidenceEntry> entriesWithoutReferences() => _entries.values
      .where((e) =>
          e.referenceIds.isEmpty ||
          e.referenceIds.every((id) => !_references.containsKey(id)))
      .toList();

  /// Reference ids cited by no entry.
  List<EvidenceReference> unreferencedReferences() => _references.values
      .where((r) => entriesForReference(r.id).isEmpty)
      .toList();

  /// Duplicate reference ids found in the raw list (parse keeps last).
  static List<String> duplicateIds(List<String> ids) {
    final seen = <String>{};
    final dupes = <String>{};
    for (final id in ids) {
      if (!seen.add(id)) dupes.add(id);
    }
    return dupes.toList()..sort();
  }

  /// Peer-reviewed records missing both DOI and PMID.
  List<EvidenceReference> peerReviewedMissingIdentifiers() => _references.values
      .where((r) => r.isPeerReviewed && r.doi.isEmpty && r.pmid.isEmpty)
      .toList();

  /// Entries whose review date is missing or older than [maxAge].
  List<EvidenceEntry> outdatedEntries({DateTime? now, Duration? maxAge}) {
    final ref = now ?? DateTime.now();
    final age = maxAge ?? const Duration(days: 365);
    return _entries.values.where((e) {
      final d = DateTime.tryParse(e.lastReviewed);
      if (d == null) return true;
      return ref.difference(d) > age;
    }).toList();
  }

  /// Proportion of entries with at least one resolvable reference.
  double coverageScore() {
    if (_entries.isEmpty) return 0;
    final covered =
        _entries.values.length - entriesWithoutReferences().length;
    return covered / _entries.values.length;
  }

  /// Stable test-name → evidence-entry map for inline Evidence buttons.
  /// Covers the 12 camera analyzers plus vision-lab tests.
  static const Map<String, String> evidenceIdForTest = {
    'Facial movement symmetry': 'facial_asymmetry',
    'Eyelid position': 'eyelid_asymmetry',
    'Eye alignment': 'eye_alignment',
    'Pupil symmetry': 'pupil_asymmetry',
    'Pupil light response': 'pupil_response',
    'Ocular surface': 'ocular_surface_growth',
    'Eye redness': 'ocular_redness',
    'Scleral color': 'scleral_color',
    'Corneal clarity': 'corneal_opacity',
    'Lens clarity (experimental)': 'lens_opacity',
    'Blink pattern': 'blink_pattern',
    'Eye movement stability': 'nystagmus',
    'Distance visual acuity': 'visual_acuity',
    'Near visual acuity': 'visual_acuity',
    'Color vision': 'color_vision',
    'Contrast sensitivity': 'contrast_sensitivity',
    'Central vision': 'central_vision',
    'Central vision (Amsler-style)': 'central_vision',
    'Peripheral visual field': 'peripheral_field',
    'Cover test': 'eye_alignment',
    'Refractive screening (experimental)': 'refractive_screening',
  };

  static String? evidenceIdForTestName(String testName) =>
      evidenceIdForTest[testName];
}
