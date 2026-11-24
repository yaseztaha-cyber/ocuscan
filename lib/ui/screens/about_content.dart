// About page content (English + Arabic). Single source of truth so tests
// can verify every section ships in both languages. No team members beyond
// the credited creator; no institutions, grants, or approvals claimed.
import '../../core/config/app_version.dart';

class AboutSection {
  final String titleEn;
  final String titleAr;
  final String bodyEn;
  final String bodyAr;
  const AboutSection(this.titleEn, this.titleAr, this.bodyEn, this.bodyAr);
}

const String creatorName = 'Yassen Taha Hussainy Elnasher';
const String creatorAffiliation = 'G11 — STEM Gharbiya';

const List<AboutSection> aboutSections = [
  AboutSection(
    'What is OcuScan?',
    'ما هو OcuScan؟',
    'OcuScan is a privacy-first smartphone-based ocular, facial, and visual-function screening research platform. '
    'It measures observable characteristics, runs structured visual-function tests, flags possible abnormalities for screening, '
    'communicates uncertainty, explains limitations, and collects structured research measurements for validation.',
    'OcuScan منصة بحثية للفحص الاستكشافي للعين والوجه والوظائف البصرية عبر الهاتف الذكي، مع الحفاظ على الخصوصية. '
    'يقيس العلامات الظاهرة، ويجري اختبارات منظمة للوظائف البصرية، ويرصد العلامات المحتملة للفحص، ويوضح عدم اليقين والقيود، ويجمع قياسات بحثية منظمة للتحقق.',
  ),
  AboutSection(
    'How does it work?',
    'كيف يعمل؟',
    'Camera → QualityGate → specialized analyzer → measurement → uncertainty → screening finding. '
    'A separate Vision Lab runs visual-function tests, and a guarded research workspace records experiments, trials, repeatability, and failure analysis.',
    'الكاميرا ← بوابة الجودة ← محلل متخصص ← قياس ← تقدير عدم اليقين ← نتيجة فحص. '
    'ويشغّل مختبر النظر اختبارات الوظائف البصرية، بينما تسجل مساحة بحثية محمية التجارب والمحاولات والتكرارية وتحليل الفشل.',
  ),
  AboutSection(
    'Technology',
    'التقنية',
    'Flutter application (Android-first, iOS runner preserved) with on-device computer vision: face detection, landmarks, eye localization, '
    'pupil measurement, movement tracking, segmentation, and RGB/HSV/Lab color analysis. Core screening works offline.',
    'تطبيق Flutter (الأندرويد أولاً مع الحفاظ على نسخة iOS) ورؤية حاسوبية على الجهاز: كشف الوجه والمعالم وتحديد العين وقياس الحدقة '
    'وتتبع الحركة والتجزئة وتحليل الألوان. يعمل الفحص الأساسي دون اتصال.',
  ),
  AboutSection(
    'Computer Vision',
    'الرؤية الحاسوبية',
    'Facial landmarks locate eyes and brows; eye regions feed pupil and eyelid estimators; frame sequences feed blink and movement analyzers; '
    'scleral masks feed color analyzers. Every stage records quality, and low quality vetoes the result instead of guessing.',
    'تحدد معالم الوجه العينين والحاجبين، وتغذي مناطق العين مقدّرات الحدقة والجفن، وتغذي تسلسلات الإطارات محللات الرمش والحركة، '
    'وتغذي أقنعة الصلبة محللات الألوان. تسجل كل مرحلة الجودة، والجودة المنخفضة تلغي النتيجة بدلاً من التخمين.',
  ),
  AboutSection(
    'Vision Lab',
    'مختبر النظر',
    'Distance and near acuity with randomized optotypes, generated color plates, contrast ladder, Amsler-style grid, peripheral screening, '
    'guided cover test, and experimental refractive screening — each stating distance, screen, lighting, eye, and calibration status.',
    'حدة الإبصار للبعيد والقريب بمحفزات عشوائية، ولوحات ألوان مولّدة، وسلم تباين، وشبكة بأسلوب آمسلر، وفحص المجال المحيطي، '
    'واختبار التغطية الموجه، وفحص انكساري تجريبي — كل اختبار يوضح المسافة والشاشة والإضاءة والعين وحالة المعايرة.',
  ),
  AboutSection(
    'Medical Evidence',
    'الأدلة الطبية',
    'Every finding links to a curated evidence entry with tier (A/B/C), implementation status, limitations, and full references. '
    'Tiers: A — established measurement/screening evidence; B — research-supported but limited; C — experimental. Published numbers belong to their studies, never to OcuScan.',
    'كل نتيجة مرتبطة بمدخل أدلة منظم يتضمن المستوى والحالة والقيود والمراجع الكاملة. '
    'المستويات: A — أدلة قياس راسخة؛ B — أدلة بحثية محدودة؛ C — تجريبي. الأرقام المنشورة تخص دراساتها وليست أداء OcuScan.',
  ),
  AboutSection(
    'Privacy',
    'الخصوصية',
    'Camera → on-device processing → measurements → result → raw image deleted. Research captures are off by default, local-only, deletable, '
    'and never exported or uploaded. No facial recognition, no identity profiles, no advertising use, no sale of biometric data. Delete all data anytime in Settings.',
    'الكاميرا ← معالجة على الجهاز ← قياسات ← نتيجة ← حذف الصورة الخام. لقطات البحث متوقفة افتراضياً ومحلية فقط وقابلة للحذف ولا تُصدَّر ولا تُرفع. '
    'لا تعرف على الوجوه ولا ملفات هوية ولا إعلانات ولا بيع للبيانات. احذف كل البيانات من الإعدادات في أي وقت.',
  ),
  AboutSection(
    'Safety',
    'السلامة',
    'Three result states only: no obvious abnormality, possible finding, unable to assess. No diagnoses, no aggregate wellness scores, no disease-risk percentages, '
    'no prescriptions. Normal results always state they do not rule out untestable conditions. Emergency symptoms route to urgent care, never to the camera.',
    'ثلاث نتائج فقط: لا علامة واضحة، علامة محتملة، تعذر التقييم. لا تشخيص ولا درجات صحة ولا نسب مخاطر ولا وصفات. '
    'النتائج الطبيعية توضح دائماً أنها لا تستبعد الحالات غير القابلة للاختبار. الأعراض الطارئة تُحال للرعاية العاجلة وليس للكاميرا.',
  ),
  AboutSection(
    'Limitations',
    'القيود',
    'A camera image can be inadequate; many diseases are invisible from outside; findings have multiple causes; screening is not diagnosis. '
    'Professional examination may involve instruments, history, acuity, slit-lamp examination, fundoscopy, laboratory tests, or other investigations. '
    'Performance varies across skin tones, eye colors, ages, glasses, devices, and lighting — unevaluated groups are labeled “Not evaluated”, never assumed equal.',
    'قد تكون صورة الكاميرا غير كافية؛ وكثير من الأمراض لا تُرى من الخارج؛ وللعلامات أسباب متعددة؛ والفحص ليس تشخيصاً. '
    'قد يشمل الفحص المهني أدوات وسوابق وحدة إبصار وفحص المصباح الشقي وقاع العين وتحاليل مخبرية. '
    'يختلف الأداء باختلاف البشرة ولون العين والعمر والنظارات والأجهزة والإضاءة — والمجموعات غير المقيّمة توصف بأنها غير مقيّمة ولا تُفترض متساوية.',
  ),
  AboutSection(
    'Research & Validation',
    'البحث والتحقق',
    'Experiments, trials, device profiles, reference labels, repeatability, failure analysis, device comparison, and CSV/JSON export — all local-first. '
    'Verification (the software runs), measurement validation (the numbers are stable), clinical validation, and regulatory clearance are four different things; OcuScan claims only the research infrastructure for the first two.',
    'تجارب ومحاولات وملفات أجهزة وتسميات مرجعية وتكرارية وتحليل فشل ومقارنة أجهزة وتصدير — كلها محلية أولاً. '
    'التحقق البرمجي والتحقق من القياس والتحقق السريري والترخيص التنظيمي أربعة أمور مختلفة؛ ويدّعي OcuScan بنية البحث للأولين فقط.',
  ),
  AboutSection(
    'Future Retinal Imaging',
    'تصوير الشبكية المستقبلي',
    'Normal phone cameras cannot image the retina. A future optical attachment with controlled illumination, alignment, and its own quality gate would be required. '
    'Selfie images are rejected for retinal analysis by design. See the Future Retinal Imaging page.',
    'لا تستطيع كاميرات الهاتف العادية تصوير الشبكية. يتطلب الأمر ملحقاً بصرياً مستقبلياً بإضاءة مضبوطة ومحاذاة وبوابة جودة خاصة. '
    'صور السيلفي مرفوضة لتحليل الشبكية بالتصميم. راجع صفحة تصوير الشبكية المستقبلي.',
  ),
  AboutSection(
    'References',
    'المراجع',
    'Complete sources live on the References page with full bibliographic information, filters, and a published-vs-OcuScan comparison note. '
    'References do not imply clinical endorsement of OcuScan.',
    'المصادر الكاملة في صفحة المراجع بمعلومات ببليوغرافية كاملة وفلاتر وملاحظة مقارنة بين المنشور وأداء OcuScan. '
    'المراجع لا تعني تأييداً سريرياً للتطبيق.',
  ),
  AboutSection(
    'Version',
    'الإصدار',
    'OcuScan $kOcuScanVersion • Evidence DB v1.0 (reviewed 2026-09-25). Educational/research screening prototype — not a diagnostic medical device.',
    'OcuScan $kOcuScanVersion • قاعدة الأدلة v1.0 (رُوجعت 2026-09-25). نموذج أولي للفحص والتوعية — ليس جهازاً تشخيصياً.',
  ),
];
