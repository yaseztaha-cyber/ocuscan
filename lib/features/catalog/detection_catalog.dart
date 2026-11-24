// Master medical capability catalog (v0.7 §5): face/eye/vision/retina/
// skin/genetic/endocrine entries with hardware, statuses, evidence
// linkage. Loader works on device (asset bundle) and in tests via
// [debugLoaderOverride] (same file, disk transport — test-proven
// pattern, production path untouched).
import 'dart:convert';

import 'package:flutter/services.dart';

class CapabilityEntry {
  final String id;
  final String name;
  final String nameAr;
  final String category;
  final String observableFinding;
  final String conditionOrAssociation;
  final String modality;
  final List<String> hardwareRequired;
  final String implementationStatus;
  final String evidenceStatus;
  final String validationStatus;
  final String riskLevel;
  final String clinicalStatus;
  final List<String> limitations;
  final List<String> failureConditions;
  final List<String> references;

  const CapabilityEntry({
    required this.id,
    required this.name,
    required this.nameAr,
    required this.category,
    required this.observableFinding,
    required this.conditionOrAssociation,
    required this.modality,
    required this.hardwareRequired,
    required this.implementationStatus,
    required this.evidenceStatus,
    required this.validationStatus,
    required this.riskLevel,
    required this.clinicalStatus,
    required this.limitations,
    required this.failureConditions,
    required this.references,
  });

  factory CapabilityEntry.fromJson(Map<String, dynamic> j) {
    List<String> strings(dynamic v) => ((v ?? []) as List)
        .map((e) => e.toString())
        .toList();
    return CapabilityEntry(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      nameAr: (j['name_ar'] ?? '').toString(),
      category: (j['category'] ?? '').toString(),
      observableFinding: (j['observable_finding'] ?? '').toString(),
      conditionOrAssociation:
          (j['condition_or_association'] ?? '').toString(),
      modality: (j['modality'] ?? '').toString(),
      hardwareRequired: strings(j['hardware_required']),
      implementationStatus:
          (j['implementation_status'] ?? '').toString(),
      evidenceStatus: (j['evidence_status'] ?? '').toString(),
      validationStatus: (j['validation_status'] ?? '').toString(),
      riskLevel: (j['risk_level'] ?? '').toString(),
      clinicalStatus: (j['clinical_status'] ?? '').toString(),
      limitations: strings(j['limitations']),
      failureConditions: strings(j['failure_conditions']),
      references: strings(j['references']),
    );
  }
}

class DetectionCatalog {
  final String version;
  final List<CapabilityEntry> all;

  /// Test-only transport override (same file, disk transport).
  static Future<DetectionCatalog> Function()? debugLoaderOverride;

  const DetectionCatalog({required this.version, required this.all});

  static Future<DetectionCatalog> load() async {
    final override = debugLoaderOverride;
    if (override != null) return override();
    final raw =
        await rootBundle.loadString('assets/detection_catalog.json');
    return DetectionCatalog.parse(raw);
  }

  factory DetectionCatalog.parse(String raw) {
    final decoded = json.decode(raw) as Map<String, dynamic>;
    final list = ((decoded['capabilities'] ?? []) as List)
        .cast<Map<String, dynamic>>();
    return DetectionCatalog(
      version: (decoded['version'] ?? '0.7').toString(),
      all: list.map(CapabilityEntry.fromJson).toList(),
    );
  }

  List<CapabilityEntry> byCategory(String category) =>
      all.where((c) => c.category == category).toList();

  List<CapabilityEntry> byStatus(String status) => all
      .where((c) => c.implementationStatus == status)
      .toList();
}
