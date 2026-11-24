import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/localization/app_strings.dart';
import '../../main.dart';
import 'about_content.dart';
import '../widgets/common.dart';

/// About OcuScan: creator credit, architecture, privacy, safety, research
/// methodology, limitations. No fabricated team, institutions, grants,
/// certifications, trials, or partnerships.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().lang;
    final ar = lang == 'ar';
    final s = AppStrings(lang);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'عن OcuScan' : 'About OcuScan')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text('OcuScan', style: t.displaySmall),
        const SizedBox(height: 4),
        Text(
            ar
                ? 'منصة بحثية للفحص الاستكشافي للعين والوجه والنظر عبر الهاتف الذكي'
                : 'Smartphone Eye, Facial & Vision Screening Research Platform',
            style: t.titleMedium),
        const SizedBox(height: 4),
        Text(s.appVersionLine(kOcuScanVersion), style: t.bodySmall),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ar ? 'إعداد وتطوير' : 'Created and developed by',
                      style: t.bodySmall),
                  Text(creatorName,
                      style: t.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  Text(creatorAffiliation, style: t.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                      ar
                          ? 'مجالات المشروع: الرؤية الحاسوبية، تقنية الصحة المحمولة، فحص العيون، اختبارات الوظائف البصرية، سلامة الذكاء الاصطناعي، التحقق من البحوث الطبية، الحوسبة المحافظة على الخصوصية.'
                          : 'Project focus: Computer Vision, Mobile Health Technology, Ophthalmic Screening, Visual Function Testing, AI Safety, Medical Research Validation, Privacy-Preserving Computing.',
                      style: t.bodySmall),
                ]),
          ),
        ),
        for (int i = 0; i < aboutSections.length; i++) ...[
          _SectionHeader(
            icon: _sectionIcon(i),
            title: ar ? aboutSections[i].titleAr : aboutSections[i].titleEn,
          ),
          if (i == 1) ...[
            const SizedBox(height: 8),
            const _PipelineDiagram(),
            const SizedBox(height: 4),
          ],
          Text(ar ? aboutSections[i].bodyAr : aboutSections[i].bodyEn),
        ],
        const SizedBox(height: 12),
        SafetyBanner(text: s.aboutSafetyBanner),
        const SizedBox(height: 12),
        Text(s.fontCredit, style: t.bodySmall),
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
              Navigator.pushNamed(context, '/methodology'),
          icon: const Icon(Icons.architecture_outlined),
          label: Text(s.learnMethodologyBtn),
        ),
      ]),
    );
  }
}

IconData _sectionIcon(int i) {
  const icons = [
    Icons.info_outline, // What is OcuScan?
    Icons.account_tree_outlined, // How it works
    Icons.smartphone_outlined, // Technology
    Icons.face_retouching_natural_outlined, // Computer vision
    Icons.visibility_outlined, // Vision Lab
    Icons.menu_book_outlined, // Evidence
    Icons.lock_outline, // Privacy
    Icons.verified_user_outlined, // Safety
    Icons.warning_amber_outlined, // Limitations
    Icons.science_outlined, // Research
    Icons.remove_red_eye_outlined, // Retinal
    Icons.library_books_outlined, // References
    Icons.info_outline, // Version
  ];
  return icons[i % icons.length];
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFEDF5F4),
            border: Border.all(color: const Color(0xFF0E7C7B)),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 19, color: const Color(0xFF0A5E5D)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}

/// Minimal architecture visualization: the honest pipeline, drawn —
// Camera → QualityGate → Analyzer → Result — with a veto branch.
class _PipelineDiagram extends StatelessWidget {
  const _PipelineDiagram();

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(context.watch<AppState>().lang);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final stages = s.pipelineStages;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF5F4),
        border: Border.all(color: const Color(0xFFE2E8E6)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: [
        Row(
          children: [
            for (var i = 0; i < stages.length; i++) ...[
              Expanded(child: _stageBox(stages[i], i == 1)),
              if (i < stages.length - 1)
                Icon(rtl ? Icons.arrow_back : Icons.arrow_forward,
                    size: 16, color: const Color(0xFF0A5E5D)),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          s.pipelineCaption,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Color(0xFF334242)),
        ),
      ]),
    );
  }

  Widget _stageBox(String label, bool highlight) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFF0A5E5D) : Colors.white,
        border: Border.all(color: const Color(0xFF0E7C7B)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: highlight ? Colors.white : const Color(0xFF0A5E5D))),
    );
  }
}
