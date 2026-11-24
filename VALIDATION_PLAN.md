# OcuScan Validation Plan (v0.5)

No clinical validation is claimed. This plan defines what would count,
in order, before any module moves beyond its current status.

## Levels

1. **Engineering verification** (done in-repo): unit/widget tests (189),
   analyze clean,/contracts, thresholds, unable-paths.
2. **Repeatability**: same device/person/conditions → stable
   measurements (research workspace supports this today).
3. **Device comparison**: front vs rear, lighting levels
   (comparison + devices tabs exist).
4. **Reference comparison**: independent reference labels
   (`reference_labels` table + reference trials exist) — agreement
   metrics only where reference methodology qualifies; never call a
   reference a gold standard unless it is one.
5. **Clinical validation**: ethics, protocol, population, analysis —
   NOT started; required before any status above EXPERIMENTAL.

## Metric rules

- Sensitivity/specificity/PPV/NPV/ROC only with independent reference
  labels; never on unlabelled data.
- Unable-to-assess rate and failure rate always reported alongside any
  accuracy number.
- Calibration curves only for validated probability outputs (none exist
  in consumer UI).
- Results version-pinned (app + analyzer + evidence DB) so history
  never silently changes meaning.

## Current status

All consumer modules: engineering verification only. Research tracks:
no data collected. Nothing here is clinical evidence.
