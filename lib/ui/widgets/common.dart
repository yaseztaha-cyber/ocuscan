import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/evidence/evidence_repository.dart';
import '../../core/localization/app_strings.dart';
import '../../core/models/screening_result.dart';
import '../../main.dart';
import 'evidence_sheet.dart' show showEvidenceSheet;

/// Distinctive screening-result layout: status rail + observation first,
/// quality/confidence as labeled chips, evidence action. Icon + text
/// (never color alone); calm clinical styling.
class ResultCard extends StatelessWidget {
  final ScreeningResult result;
  final VoidCallback? onTap;
  final String? evidenceId;
  final bool showEvidence;
  const ResultCard(
      {super.key,
      required this.result,
      this.onTap,
      this.evidenceId,
      this.showEvidence = false});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = AppStrings(context.watch<AppState>().lang);
    IconData icon;
    Color color;
    Color tint;
    String badge;
    switch (result.finding) {
      case ResultCategory.possibleFinding:
        icon = Icons.visibility_outlined;
        color = const Color(0xFF9A6B00);
        tint = const Color(0xFFFBF3DF);
        badge = s.badgePossibleFinding;
        break;
      case ResultCategory.unableToAssess:
        icon = Icons.help_outline;
        color = const Color(0xFF334242);
        tint = const Color(0xFFEFF3F2);
        badge = s.badgeUnable;
        break;
      default:
        icon = Icons.check_circle_outline;
        color = const Color(0xFF0A5E5D);
        tint = const Color(0xFFEDF5F4);
        badge = s.badgeNoFinding;
    }
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 6,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadiusDirectional.only(
                  topStart: Radius.circular(10),
                  bottomStart: Radius.circular(10),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: tint,
                            border: Border.all(color: color),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(icon, color: color, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(result.testName,
                                style: t.titleMedium)),
                      ]),
                      const SizedBox(height: 10),
                      Text(s.resultObservationLabel,
                          style: t.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6)),
                      const SizedBox(height: 2),
                      Text(result.findingLabel, style: t.bodyLarge),
                      const SizedBox(height: 4),
                      Text(result.measurement, style: t.bodySmall),
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        _MetaChip(
                            label:
                                '${s.detailQuality}: ${result.imageQuality.name}'),
                        _MetaChip(
                            label:
                                '${s.resultConfidenceLabel}: ${result.confidence.name}'),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            border: Border.all(color: color),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(badge,
                              style: TextStyle(
                                  color: color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ]),
                      if (showEvidence && evidenceId != null) ...[
                        const SizedBox(height: 8),
                        _InlineEvidenceButton(
                            evidenceId: evidenceId!),
                      ],
                    ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  const _MetaChip({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF3F2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: const TextStyle(
              color: Color(0xFF334242),
              fontSize: 12,
              fontWeight: FontWeight.w700)),
    );
  }
}

class SafetyBanner extends StatelessWidget {  final String text;
  const SafetyBanner({super.key, required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF5F4),
        border: Border.all(color: const Color(0xFF0E7C7B)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline, color: Color(0xFF0A5E5D)),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
      ]),
    );
  }
}

/// CameraX native preview texture, corrected for display. CameraX emits
/// sensor-orientation (landscape) buffers and Flutter's Texture widget
/// ignores the SurfaceTexture transform matrix, so raw display shows a
/// sideways, stretched image ("bad preview quality"). RotatedBox
/// restores upright (quarterTurns = rotation/90, matching the overlay
/// mapper's convention); front previews mirror to the selfie convention
/// the overlay assumes. [rotationDeg] is the compensated per-frame
/// rotation (same value the overlay maps with), NOT the raw sensor
/// orientation. One shared widget so all five preview sites agree.
class NativePreviewTexture extends StatelessWidget {
  final int textureId;
  final int rotationDeg;
  final bool mirrored;
  const NativePreviewTexture({
    super.key,
    required this.textureId,
    required this.rotationDeg,
    required this.mirrored,
  });

  @override
  Widget build(BuildContext context) {
    final r = ((rotationDeg % 360) + 360) % 360;
    final turns = (r ~/ 90) % 4;
    Widget w = Texture(textureId: textureId);
    if (turns != 0) w = RotatedBox(quarterTurns: turns, child: w);
    if (mirrored) {
      w = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..scaleByDouble(-1.0, 1.0, 1.0, 1.0),
        child: w,
      );
    }
    return SizedBox.expand(child: w);
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

/// Navigation chevron that mirrors in RTL (unlike a hardcoded
/// chevron_right). Use for all forward-navigation trailing icons.
class NavChevron extends StatelessWidget {
  const NavChevron({super.key});
  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Icon(rtl ? Icons.chevron_left : Icons.chevron_right);
  }
}

class GuideChecklist extends StatelessWidget {  final Map<String, bool> items;
  const GuideChecklist({super.key, required this.items});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items.entries.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Icon(e.value ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: e.value ? const Color(0xFF0A5E5D) : const Color(0xFF3F4E4E), size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(e.key, style: t.bodyMedium)),
              Text(e.value ? '✓' : '…', style: t.bodyMedium),
            ]),
          )).toList(),
        ),
      ),
    );
  }
}

/// Small inline Evidence button for result cards. Resolves the entry from
/// the curated database and opens the structured evidence sheet.
class _InlineEvidenceButton extends StatelessWidget {
  final String evidenceId;
  const _InlineEvidenceButton({required this.evidenceId});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(context.watch<AppState>().lang);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: OutlinedButton.icon(
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
        label: Text(s.evidenceButton),
      ),
    );
  }
}
