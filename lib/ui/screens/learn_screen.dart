import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/evidence/evidence_repository.dart';
import '../../core/localization/app_strings.dart';
import '../../core/validation/analyzer_registry.dart';
import '../../main.dart';
import '../widgets/common.dart';
import '../widgets/evidence_sheet.dart';

/// Learn: finding articles (each with tier badge + Evidence button),
/// the screening catalog by implementation status, general education
/// articles, and links to References / Methodology.
class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});
  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  EvidenceRepository? repo;
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
      appBar: AppBar(
        title: Text(s.learnTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: s.learnReferencesBtn,
            onPressed: () =>
                Navigator.pushNamed(context, '/references'),
          ),
          IconButton(
            icon: const Icon(Icons.architecture_outlined),
            tooltip: s.learnMethodologyBtn,
            onPressed: () =>
                Navigator.pushNamed(context, '/methodology'),
          ),
        ],
      ),
      body: repo == null
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 8),
              Text(s.loadingEvidence),
            ]))
          : ListView(padding: const EdgeInsets.all(16), children: [
              SafetyBanner(text: s.learnIntro),
              SectionTitle(s.learnMeasuresTitle),
              for (final e in _measured())
                _findingCard(e, t, s),
              SectionTitle(s.learnCatalogTitle),
              Text(s.learnCatalogBody),
              const SizedBox(height: 8),
              for (final st in [
                'CURRENT',
                'EXPERIMENTAL',
                'FUTURE',
                'NOT_SUITABLE_FOR_CURRENT_HARDWARE'
              ])
                _statusGroup(st, t, s),
              SectionTitle(s.learnEducationTitle),
              for (final a in _articles) _articleCard(a, t),
              SectionTitle(s.learnTracksTitle),
              Text(s.learnTracksBody, style: t.bodySmall),
              const SizedBox(height: 8),
              for (final tr in researchTracks) _trackCard(tr, t, s),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, '/references'),
                icon: const Icon(Icons.menu_book_outlined),
                label: Text(s.learnReferencesBtn),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, '/capabilities'),
                icon: const Icon(Icons.biotech_outlined),
                label: Text(s.capHomeTitle),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, '/methodology'),
                icon: const Icon(Icons.architecture_outlined),
                label: Text(s.learnMethodologyBtn),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, '/retinal-info'),
                icon: const Icon(Icons.remove_red_eye_outlined),
                label: Text(s.learnRetinalBtn),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, '/color-calibration'),
                icon: const Icon(Icons.palette_outlined),
                label: Text(s.learnCalibrationBtn),
              ),
            ]),
    );
  }

  List<EvidenceEntry> _measured() => repo!.all
      .where((e) =>
          e.implementationStatus == 'CURRENT' ||
          e.implementationStatus == 'EXPERIMENTAL')
      .toList();

  Widget _findingCard(EvidenceEntry e, TextTheme t, AppStrings s) {
    // Arabic term + English medical term side by side (§26); the
    // description stays canonical English to preserve exact meaning.
    final title = s.isAr && e.nameAr.isNotEmpty
        ? '${e.nameAr}\n${e.name.isEmpty ? e.finding : e.name}'
        : (e.name.isEmpty ? e.finding : e.name);
    return Card(
        child: ExpansionTile(
      title: Text(title, style: t.titleMedium),
      subtitle: Text(
          s.tierStatusLine(e.nameAr.isNotEmpty ? e.nameAr : e.name,
              e.evidenceTier, e.implementationStatus,
              s.shortStatus(e.implementationStatus)),
          style: t.bodySmall),
      children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.description),
              // F10: hardware/calibration requirements ride with the
              // finding so lighting artifacts are not misread as findings.
              if (e.screeningMethod.isNotEmpty ||
                  e.requiredHardware.isNotEmpty) ...[
                SectionTitle(s.findingRequiresTitle),
                if (e.screeningMethod.isNotEmpty) Text(e.screeningMethod),
                for (final h in e.requiredHardware) Text('• $h'),
              ],
              SectionTitle(s.findingAssocTitle),
              for (final a in e.possibleAssociations) Text('• $a'),
              SectionTitle(s.findingNotMeanTitle),
              Text(s.findingNotMeanBody),
              if (e.cannotConclude.isNotEmpty) ...[
                const SizedBox(height: 4),
                for (final x in e.cannotConclude)
                  Text(s.cannotConcludeLine(x)),
              ],
              SectionTitle(s.findingLimitTitle),
              for (final l in e.limitations) Text('• $l'),
              SectionTitle(s.findingActionTitle),
              Text(e.action),
              if (e.emergencySigns.isNotEmpty) ...[
                SectionTitle(s.findingEmergencyTitle),
                for (final w in e.emergencySigns) Text('• $w'),
              ],
              const SizedBox(height: 8),
              EvidenceButton(evidenceId: e.id),
            ])),
      ],
    ));
  }

  Widget _statusGroup(String status, TextTheme t, AppStrings s) {
    final items = repo!.all
        .where((e) => e.implementationStatus == status)
        .toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Card(
      child: ExpansionTile(
        title: Text(s.longStatus(status)),
        subtitle:
            Text(s.targetsCount(items.length), style: t.bodySmall),
        children: [
          for (final e in items)
            ListTile(
              title: Text(e.name.isEmpty ? e.finding : e.name),
              subtitle: Text(s.tierCategoryLine(
                  e.evidenceTier, e.category)),
              trailing: const NavChevron(),
              onTap: () =>
                  showEvidenceSheet(context, e, repo!),
            ),
        ],
      ),
    );
  }

  /// Capability-catalog card: research direction with protocol, hardware,
  /// status and tier. Never a measurement, never a diagnosis, no evidence
  /// button (no curated entry exists by design).
  Widget _trackCard(ResearchTrack tr, TextTheme t, AppStrings s) {
    final ar = s.isAr;
    return Card(
      child: ExpansionTile(
        title: Text(ar ? tr.titleAr : tr.titleEn,
            style: t.titleMedium),
        subtitle: Text(
            '${ar ? tr.categoryAr : tr.categoryEn} • ${tr.status} • ${s.tierLabel(tr.tier)}',
            style: t.bodySmall),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ar ? tr.summaryAr : tr.summaryEn),
                  const SizedBox(height: 8),
                  Text(
                      '${s.trackHardwareLabel}: ${ar ? tr.hardwareAr : tr.hardwareEn}',
                      style: t.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                      '${s.trackProtocolLabel}: ${ar ? tr.protocolAr : tr.protocolEn}',
                      style: t.bodySmall),
                ]),
          ),
        ],
      ),
    );
  }

  Widget _articleCard(_Article a, TextTheme t) {    return Card(
      child: ExpansionTile(
        title: Text(a.title, style: t.titleMedium),
        subtitle: Text(a.ar, style: t.bodySmall),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.body),
                  const SizedBox(height: 8),
                  if (a.evidenceId != null)
                    EvidenceButton(evidenceId: a.evidenceId!),
                ]),
          ),
        ],
      ),
    );
  }
}

class _Article {
  final String title;
  final String ar;
  final String body;
  final String? evidenceId;
  const _Article(this.title, this.ar, this.body, [this.evidenceId]);
}

const _articles = [
  _Article(
    'Measurement bias in health AI',
    'التحيز في قياسات الذكاء الاصطناعي الصحي',
    'Models trained mostly on one population, device, or lighting condition often perform worse elsewhere — and averages can hide that some groups were never evaluated. '
    'OcuScan labels unevaluated groups "Not evaluated" instead of assuming equal performance, and records device and lighting with measurements so differences can be investigated rather than hidden.',
  ),
  _Article(
    'Validation: how tests earn trust',
    'التحقق: كيف تكتسب الاختبارات الثقة',
    'A measurement becomes trustworthy in stages: engineering checks that the code runs correctly, repeatability checks that it gives stable answers, device comparisons across phones, agreement against independent reference measurements, and only then clinical validation with ethics, population, and analysis. '
    'OcuScan today has completed engineering verification; every other stage is pending and labeled as such — never borrowed from published studies of other systems.',
    'visual_acuity',
  ),
  _Article(
    'Eye anatomy basics',
    'أساسيات تشريح العين',
    'The visible eye has three readable parts for a phone: the white sclera, the colored iris with the dark pupil opening, and the eyelids framing them. '
    'Behind them sit the lens, the vitreous body, and the retina — none visible to a normal camera, which is why OcuScan never claims interior-eye findings. '
    'Tears keep the surface clear; redness, growths, or cloudiness visible on the surface are described conservatively, never graded, never assigned a cause.',
    'ocular_surface_growth',
  ),
  _Article(
    'Contrast and peripheral vision',
    'التباين والرؤية المحيطية',
    'Contrast sensitivity is the faintest pattern you can still see, measured by an adaptive staircase that hovers around your threshold. '
    'Peripheral awareness is tested by flashing dots at the edges while you fixate the center; missed flashes, false alarms, and reaction times are all recorded. '
    'Neither test replaces clinical instruments — both are condition-bound screening measurements.',
    'contrast_sensitivity',
  ),
  _Article(
    'Eye alignment and the cover test',
    'محاذاة العينين واختبار التغطية',
    'The cover test watches one eye while the other is covered: movement on uncover suggests misalignment worth professional assessment. '
    'The phone version is observer-reported and approximate — it records what you saw, it does not track gaze itself in this build. '
    'Persistent double vision or a constant eye turn needs prompt professional evaluation, especially in children.',
    'eye_alignment',
  ),
  _Article(
    'How the eye works',
    'كيف تعمل العين',
    'Light enters through the cornea and pupil, is focused by the lens onto the retina, and the optic nerve carries the signal to the brain. '
    'OcuScan only observes the outside of the eye and screen-based visual function — it cannot see the retina, lens interior, or optic nerve.',
    'retinal_future',
  ),
  _Article(
    'How vision testing works',
    'كيف تعمل اختبارات النظر',
    'Vision tests present controlled stimuli (letters, colors, faint patterns, grids) and record responses under stated conditions. '
    'Distance, brightness, lighting, and which eye is tested all change results — Vision Lab records these conditions with every test.',
    'visual_acuity',
  ),
  _Article(
    'What OcuScan cannot measure',
    'ما لا يستطيع OcuScan قياسه',
    'Intraocular pressure, refraction values, blood values, retinal state, nerve function, and disease causes are all outside what this phone hardware can measure. '
    'Systemic catalog items remain future research and never infer laboratory values from faces.',
    'systemic_phenotypes',
  ),
  _Article(
    'Why image quality matters',
    'لماذا جودة الصورة مهمة',
    'Blur, bad exposure, wrong distance, and head rotation change measurements more than most real findings do. '
    'QualityGate rejects unreliable captures so they never become confident results — an unable-to-assess outcome is a successful safety outcome.',
    'facial_asymmetry',
  ),
  _Article(
    'Why lighting matters',
    'لماذا الإضاءة مهمة',
    'Pupils react to light, and cameras reinterpret color under different lamps. '
    'Compare measurements only across similar lighting, verify color calibration status, and expect higher failure rates in poor light.',
    'scleral_color',
  ),
  _Article(
    'Why different phones matter',
    'لماذا تختلف الهواتف',
    'Sensors, lenses, auto-exposure, white balance, and screens differ between models, so RGB values and thresholds are not automatically transferable. '
    'Research mode compares devices explicitly instead of assuming equivalence.',
    'pupil_asymmetry',
  ),
  _Article(
    'Why screening is not diagnosis',
    'لماذا الفحص ليس تشخيصاً',
    'Screening observes; diagnosis concludes after examination, history, instruments, and often laboratory or imaging tests. '
    'Many findings have multiple causes, and many conditions are invisible from outside — a normal screen never means healthy, and a flag never names a disease.',
    'central_vision',
  ),
  _Article(
    'Pupil findings',
    'نتائج الحدقة',
    'OcuScan reports relative left/right pupil-size differences averaged over multiple frames — never millimeters without calibration. '
    'Unequal pupils have many causes including normal variation, and the app cannot determine which applies.',
    'pupil_asymmetry',
  ),
  _Article(
    'Facial movement findings',
    'نتائج حركة الوجه',
    'Guided expressions (neutral, smile, brow raise, eye closure, cheek puff) are compared left/right with landmark-quality checks. '
    'Research into expression analysis exists but is heterogeneous — OcuScan reports movement patterns, never neurological conditions.',
    'facial_neuro_research',
  ),
  _Article(
    'Ocular-surface findings',
    'نتائج سطح العين',
    'Close-up appearance (growth patterns, redness distribution, cloudiness cues) is described conservatively at phone resolution. '
    'Severity is not graded, causes are not assigned, and anterior-segment disease models from the literature required specialized training data OcuScan does not have.',
    'ocular_surface_growth',
  ),
  _Article(
    'Vision tests',
    'اختبارات النظر',
    'Distance/near acuity, color, contrast, central grid, peripheral field, cover test, and experimental refractive screening each state their distance, screen, lighting, eye, and calibration status. '
    'Results are screening measurements with repeatability handling — never prescriptions.',
    'visual_acuity',
  ),
  _Article(
    'Retinal imaging',
    'تصوير الشبكية',
    'The retina needs coaxial illumination and fundus optics that phones lack. Retinal screening is a future-hardware track; selfie images are rejected for it by design.',
    'retinal_future',
  ),
  _Article(
    'Privacy',
    'الخصوصية',
    'Camera → on-device processing → measurements → result → raw image deleted. Research captures are off by default, local-only, deletable, and never exported. '
    'No facial recognition, no identity profiles, no advertising use, no automatic uploads.',
    'blink_pattern',
  ),
  _Article(
    'AI in medicine',
    'الذكاء الاصطناعي في الطب',
    'Health AI must be transparent, explainable, accountable, and equitable, with human oversight — per WHO guidance. '
    'OcuScan follows this by using small deterministic analyzers, publishing limitations and evidence, refusing uncertain inputs, and keeping all processing on the device.',
    'facial_neuro_research',
  ),
  _Article(
    'Evidence and References',
    'الأدلة والمراجع',
    'Every medical statement links to a curated evidence entry with tier, status, and full references. '
    'Published numbers belong to their studies — OcuScan itself is not clinically validated. Open the References page for complete sources.',
    'visual_acuity',
  ),
];
