// Research-validation UI strings (English + Modern Standard Arabic with
// Egyptian-friendly health wording). Research tools never emit diagnoses;
// these strings describe measurements, conditions, and statistics only.

import 'package:flutter/widgets.dart';

class DevStrings {
  final String lang; // 'en' | 'ar'
  const DevStrings(this.lang);
  bool get isAr => lang == 'ar';

  /// Locale-aware accessor for widgets.
  static DevStrings of(BuildContext context) => DevStrings(
    Localizations.localeOf(context).languageCode == 'ar' ? 'ar' : 'en',
  );

  String get researchValidation =>
      isAr ? 'التحقق البحثي' : 'Research Validation';
  String get researchTools => isAr ? 'أدوات البحث' : 'Research tools';
  String get internalOnly => isAr
      ? 'داخلي فقط — لا توجد أرقام أداء غير موثقة تظهر للمستخدمين.'
      : 'Internal only. No unvalidated performance numbers are shown to users.';
  String get measurementEvaluation => isAr
      ? 'تقييم قياسات — وليس تحققاً سريرياً.'
      : 'Measurement evaluation — not clinical validation.';
  String get enableResearch =>
      isAr ? 'تفعيل وضع البحث' : 'Enable research mode';
  String get researchGateBody => isAr
      ? 'وضع البحث أداة هندسية لقياس ثبات القياسات وفشلها. لا ينتج تشخيصاً ولا يغيّر تجربة المستخدم العادية. فعّله فقط إذا كنت تجمع بيانات قياس موثقة.'
      : 'Research mode is an engineering tool for measuring stability and failure. It produces no diagnosis and does not change the normal user experience. Enable it only to collect documented measurement data.';
  String get iUnderstand => isAr ? 'أفهم — تفعيل' : 'I understand — enable';
  String get overview => isAr ? 'نظرة عامة' : 'Overview';
  String get experiments => isAr ? 'التجارب' : 'Experiments';
  String get devices => isAr ? 'الأجهزة' : 'Devices';
  String get lighting => isAr ? 'الإضاءة' : 'Lighting';
  String get subjects => isAr ? 'الرموز البحثية' : 'Subjects / Test IDs';
  String get measurements => isAr ? 'القياسات' : 'Measurements';
  String get repeatability => isAr ? 'التكرارية' : 'Repeatability';
  String get comparison => isAr ? 'المقارنة' : 'Comparison';
  String get failures => isAr ? 'تحليل الفشل' : 'Failure Analysis';
  String get export => isAr ? 'تصدير' : 'Export';
  String get newExperiment => isAr ? 'تجربة جديدة' : 'New experiment';
  String get recordTrial => isAr ? 'تسجيل محاولة' : 'Record trial';
  String get runGuidedTrial =>
      isAr ? 'محاولة موجهة بالكاميرا' : 'Guided camera trial';
  String get manualEntry => isAr ? 'إدخال يدوي' : 'Manual entry';
  String get referenceEntry => isAr ? 'إدخال مرجعي' : 'Reference entry';
  String get saveResearchCapture =>
      isAr ? 'حفظ لقطة بحثية' : 'Save research capture';
  String get saveResearchCaptureBody => isAr
      ? 'بحثي فقط، ويُخزن محلياً على هذا الجهاز، وقابل للحذف، ولا يُصدَّر أبداً ولا يُرفع. الصور لا تغادر الهاتف.'
      : 'Research-only, stored locally on this device, deletable, and never exported or uploaded. Images never leave this phone.';
  String get insufficientData => isAr
      ? 'بيانات غير كافية لتفسير إحصائي موثوق.'
      : 'Insufficient data for reliable statistical interpretation.';
  String get experimentReport => isAr ? 'تقرير التجربة' : 'Experiment report';
  String get showTracking => isAr ? 'إظهار التتبع' : 'Show Tracking';
  String get analyzerInfo => isAr ? 'بطاقة الخوارزمية' : 'Analyzer card';
  String get experimentalBadge =>
      isAr ? 'تجريبي — غير متحقق منه' : 'Experimental — not validated';
  String get noDataYet => isAr
      ? 'لا توجد بيانات بعد — القيم تظهر فقط من تجارب حقيقية مسجلة هنا.'
      : 'No data yet — values appear only from real trials recorded here.';
  String get configuredVsClinical => isAr
      ? 'مسافة الاختبار المضبوطة هنا ليست مسافة سريرية معيارية ما لم تدعم الأدلة ذلك.'
      : 'A configured test distance is not a clinically standardized distance unless evidence supports it.';
  String get deleteExperiment =>
      isAr ? 'حذف التجربة ومحاولاتها' : 'Delete experiment and its trials';
  String get exportCsv => isAr ? 'تصدير CSV' : 'Export CSV';
  String get exportJson => isAr ? 'تصدير JSON' : 'Export JSON';
  String get unableRate => isAr ? 'معدل تعذر التقييم' : 'Unable-to-assess rate';
  String get repeatScreening => isAr ? 'إعادة الفحص' : 'Repeat Screening';
  String get nTrials => isAr ? 'عدد المحاولات' : 'Trials';

  String get researchConsent => isAr
      ? 'الموافقة على البحث: ما يُجمع هو قياسات رقمية وظروف الاختبار فقط — وليس تشخيصاً. '
            'السبب: التحقق من ثبات القياسات وفشلها. يُخزَّن محلياً على هذا الهاتف فقط. '
            'الحذف: من التجربة أو عبر حذف كل البيانات. لا شيء يغادر الهاتف أبداً — لا رفع ولا مشاركة. '
            'الرموز مثل R001 وأسماء الأجهزة مجهولة المصدر ولا تحدد أي شخص. هذا اختبار بحثي أولي وليس دراسة سريرية.'
      : 'Research consent: what is collected is numeric measurements and test conditions only — never a diagnosis. '
            'Why: to validate measurement stability and failure. Stored locally on this phone only. '
            'Deletion: per experiment or via delete-all-data. Nothing ever leaves the phone — no upload, no sharing. '
            'IDs like R001 and device labels are anonymous and identify no one. This is prototype research testing, not a clinical study.';
  String get evidenceAudit => isAr ? 'تدقيق الأدلة' : 'Evidence Audit';
  String get fairness => isAr ? 'العدالة والمتانة' : 'Fairness & Robustness';
  String get modelsAlgorithms =>
      isAr ? 'النماذج والخوارزميات' : 'Models & Algorithms';
  String get coverageScore => isAr ? 'تغطية الأدلة' : 'Evidence coverage';
  String get notEvaluated => isAr ? 'غير مقيّم' : 'Not evaluated';
  String get eyeDebug => isAr ? 'تشخيص تتبع العين' : 'Eye Tracking Debug';
  String get eyeDebugBody => isAr
      ? 'عرض حي لما يراه المتتبع فعلاً: صندوق الوجه والنقاط والمناطق. غياب العلامات هو التشخيص — لا تخمين هنا.'
      : 'Live view of what the tracker actually reports: face box, points, regions. Absent markers ARE the diagnostic — no guessing here.';
  String get eyeDebugOpen =>
      isAr ? 'فتح تشخيص تتبع العين' : 'Open Eye Tracking Debug';
  String get pipelineTitle => isAr ? 'خط المعالجة' : 'Frame pipeline';
  String get thresholdsTitle =>
      isAr ? 'العتبات والقيم الحية' : 'Thresholds & live values';
  String get frameLogTitle => isAr ? 'سجل اللقطات' : 'Frame log';
  String get captureStillInspect =>
      isAr ? 'التقط لقطة وافحصها' : 'Capture still & inspect';
  String get stillInspectorTitle => isAr
      ? 'فاحص اللقطة (إحداثيات اللقطة)'
      : 'Still inspector (still-space coords)';
  String get stillDeletedNote => isAr
      ? 'تُحذف اللقطة عند مغادرة الشاشة. لا تُخزَّن صور بحثية هنا.'
      : 'The still is deleted when leaving this screen. No research captures stored here.';
  String get noStillYet => isAr ? 'لا لقطة بعد.' : 'No still yet.';
  String get cameraStarting =>
      isAr ? 'جارٍ تشغيل الكاميرا…' : 'Starting camera…';
  String get auditExplainer => isAr
      ? 'مقياس جودة توثيق داخلي — وليس جودة سريرية. يُحسب من بيانات المشروع الحقيقية فقط.'
      : 'An internal documentation-quality metric — never clinical quality. Computed from real project data only.';
  String get unspecified => isAr ? 'غير محدد' : 'Unspecified';

  String fairnessLabel(String key) {
    const en = {
      'skinTone': 'Skin tone (I–VI)',
      'eyeColor': 'Eye color',
      'eyewear': 'Glasses / lenses',
      'ageGroup': 'Age group',
    };
    const ar = {
      'skinTone': 'لون البشرة (I–VI)',
      'eyeColor': 'لون العين',
      'eyewear': 'النظارات / العدسات',
      'ageGroup': 'الفئة العمرية',
    };
    return isAr ? (ar[key] ?? key) : (en[key] ?? key);
  }

  String fairnessValue(String key, String value) {
    const ar = {
      'none': 'بدون',
      'glasses': 'نظارة',
      'contact_lenses': 'عدسات لاصقة',
      'light': 'فاتح',
      'medium': 'متوسط',
      'dark': 'داكن',
      'child': 'طفل',
      'adult': 'بالغ',
      'older_adult': 'كبير السن',
    };
    if (!isAr) return value;
    return ar[value] ?? value;
  }

  String failureLabel(String code) {
    const en = {
      'LOW_ILLUMINATION': 'Low light',
      'OVEREXPOSURE': 'Overexposure',
      'BLUR': 'Blur',
      'LOW_RESOLUTION': 'Low resolution',
      'BAD_FACE_GEOMETRY': 'Bad face geometry',
      'EYE_NOT_VISIBLE': 'Eye not visible',
      'OTHER': 'Other',
    };
    const ar = {
      'LOW_ILLUMINATION': 'إضاءة منخفضة',
      'OVEREXPOSURE': 'تعرض زائد للضوء',
      'BLUR': 'ضبابية',
      'LOW_RESOLUTION': 'دقة منخفضة',
      'BAD_FACE_GEOMETRY': 'وضعية وجه غير مناسبة',
      'EYE_NOT_VISIBLE': 'العين غير ظاهرة',
      'OTHER': 'أخرى',
    };
    return isAr ? (ar[code] ?? code) : (en[code] ?? code);
  }

  String lightingLabel(String code) {
    const en = {
      'very_low': 'Very low',
      'low': 'Low',
      'moderate': 'Moderate',
      'bright': 'Bright',
      'very_bright': 'Very bright',
      'controlled': 'Controlled',
    };
    const ar = {
      'very_low': 'منخفضة جداً',
      'low': 'منخفضة',
      'moderate': 'متوسطة',
      'bright': 'ساطعة',
      'very_bright': 'ساطعة جداً',
      'controlled': 'مضبوطة',
    };
    return isAr ? (ar[code] ?? code) : (en[code] ?? code);
  }

  String statusLabel(String code) {
    const en = {
      'accepted': 'Accepted',
      'rejected': 'Rejected',
      'unable': 'Unable to assess',
    };
    const ar = {
      'accepted': 'مقبولة',
      'rejected': 'مرفوضة',
      'unable': 'تعذر التقييم',
    };
    return isAr ? (ar[code] ?? code) : (en[code] ?? code);
  }

  // ---------- Research workspace chrome ----------
  String get create => isAr ? 'إنشاء' : 'Create';
  String get cancel => isAr ? 'إلغاء' : 'Cancel';
  String get delete => isAr ? 'حذف' : 'Delete';
  String get allTests => isAr ? 'كل الاختبارات' : 'All tests';
  String get allExperiments => isAr ? 'كل التجارب' : 'All experiments';
  String get recordInstrumentProfile =>
      isAr ? 'تسجيل ملف الجهاز' : 'Record instrument profile';
  String get noAcceptedValues =>
      isAr ? 'لا قيم مقبولة.' : 'No accepted values. ';
  String referenceLabelsLine(int n) => isAr
      ? 'تسميات مرجعية مسجلة: $n (موثقة من الباحث فقط)'
      : 'Reference labels on file: $n (researcher-documented only)';
  String researchCapturesLine(bool on) => isAr
      ? 'لقطات بحثية على هذا الجهاز: ${on ? 'مفعّلة (محلياً فقط)' : 'متوقفة'}'
      : 'Research captures on this device: ${on ? 'enabled (local only)' : 'disabled'}';
  String reviewedLine(String date) => isAr ? 'روجعت $date' : 'reviewed $date';
  String get noValuesYet =>
      isAr ? 'لا قيم مسجلة بعد.' : 'No values recorded yet.';
  String trialTitle(int n) => isAr ? 'المحاولة $n' : 'Trial $n';
  String get experimentNotFound =>
      isAr ? 'التجربة غير موجودة.' : 'Experiment not found.';
  String get saveAsUnable => isAr ? 'حفظ كتعذّر تقييم' : 'Save as unable';
  String get saveManual => isAr ? 'حفظ قياس يدوي' : 'Save manual measurement';
  String get referenceRequired => isAr
      ? 'القيمة المرجعية مطلوبة لهذا الإدخال.'
      : 'A reference value is required for this entry.';
  String get savePairedReference =>
      isAr ? 'حفظ محاولة مرجعية مقترنة' : 'Save paired reference trial';
  String get reportExperiment => isAr ? 'التجربة' : 'Experiment';
  String get reportTest => isAr ? 'الاختبار' : 'Test';
  String get reportDevice => isAr ? 'الجهاز' : 'Device';
  String get reportTrials => isAr ? 'المحاولات' : 'Trials';
  String get reportAccepted => isAr ? 'المقبولة' : 'Accepted';
  String get reportRejected => isAr ? 'المرفوضة' : 'Rejected';
  String get trackerNoFrame => isAr
      ? 'لم ينتج المتتبع لقطة بعد.'
      : 'Tracker has not produced a frame yet.';
  String get trackerStateTitle => isAr
      ? 'حالة المتتبع (عرض تشخيصي بحثي)'
      : 'Tracker state (research debug view)';

  // ---------- Evidence audit tab ----------
  String auditDbLine(String v, String reviewed, int entries, int refs) => isAr
      ? 'قاعدة البيانات $v • روجعت $reviewed • $entries مدخلاً • $refs مرجعاً'
      : 'DB v$v • reviewed $reviewed • $entries entries • $refs references';
  String get auditUnref =>
      isAr ? 'عبارات طبية بلا مراجع' : 'Unreferenced medical statements';
  String get auditUnused =>
      isAr ? 'مراجع غير مستشهد بها' : 'References cited nowhere';
  String get auditMissingIds =>
      isAr ? 'محكمة بلا DOI/PMID' : 'Peer-reviewed missing DOI/PMID';
  String get auditDupes =>
      isAr ? 'معرفات مرجعية مكررة' : 'Duplicate reference ids';
  String get auditBadUrls => isAr
      ? 'روابط معطوبة (فحص شكلي، دون اتصال)'
      : 'Malformed URLs (format check, offline)';
  String get auditStale => isAr
      ? 'تاريخ مراجعة قديم (>365 يوماً)'
      : 'Outdated review date (>365 days)';
  String get auditLimited => isAr
      ? 'وحدات من الدرجة C مشحونة كحالية'
      : 'Tier-C modules shipped as CURRENT';
  String get auditSecUnref =>
      isAr ? 'مداخل بلا مراجع' : 'Entries without references';
  String get auditSecUnused =>
      isAr ? 'مراجع غير مستشهد بها في أي مكان' : 'References cited nowhere';
  String get auditSecMissingIds => isAr
      ? 'سجلات محكمة بلا DOI/PMID'
      : 'Peer-reviewed records missing DOI/PMID';
  String get auditSecStale =>
      isAr ? 'تاريخ مراجعة قديم' : 'Outdated review date';
  String reviewedOnLine(String d) => isAr ? 'روجع $d' : 'reviewed $d';
  String get auditSecLimited => isAr
      ? 'أدلة الدرجة C مشحونة كحالية'
      : 'Tier-C evidence shipped as CURRENT';
  String get auditOrphans =>
      isAr ? 'قدرات بلا أدلة منتقاة' : 'Capabilities without curated evidence';
  String get auditSecOrphans =>
      isAr ? 'قدرات بلا مراجع' : 'Capabilities without references';
  String get auditOrphansNote => isAr
      ? 'مسارات بحثية مستقبلية بلا سوابق منشورة منتقاة — مقبولة للاتجاهات المستقبلية فقط، وليست للميزات الحالية.'
      : 'Future research tracks without curated published precedent — acceptable for future directions only, never for current features.';
  String get auditLimitedNote => isAr
      ? 'تعمل هذه في النسخة بأدلة تحقق محدودة؛ وتُعرض المحددات داخل التطبيق.'
      : 'These run in the build with limited validation evidence; limitations are shown in-app.';
  String get auditManualTitle =>
      isAr ? 'مطلوب مراجعة يدوية' : 'Manual review required';
  String get auditManualBody => isAr
      ? 'لا يمكن التحقق آلياً مما إذا كان كل استشهاد يدعم الادعاء المرتبط به — تحقق بقراءة المصدر.'
      : 'Whether each citation supports the claim it is attached to cannot be checked automatically — verify by reading the source.';
  String cameraErrorLine(String e) => isAr ? 'الكاميرا: $e' : 'Camera: $e';
  String get noTrialValue =>
      isAr ? 'لا قيمة (مرفوضة/تعذر التقييم)' : 'no value (rejected/unable)';
  String get riskTab => isAr ? 'المخاطر' : 'Risk';
  String get riskExplainer => isAr
      ? 'سجل مخاطر بحثي — تفكير منظم بأسلوب إدارة المخاطر، وليس شهادة اعتماد. كل صف: خطر، سبب، ضرر، شدة، احتمال، تخفيف، خطر متبقٍ، تحقق.'
      : 'Research risk register — structured risk-management-style thinking, not a certification claim. Each row: hazard, cause, harm, severity, probability, mitigation, residual risk, verification.';
  String get camSourceLabel => isAr ? 'الكاميرا' : 'Camera';
  String get camSourceFront => isAr ? 'أمامية' : 'Front';
  String get camSourceRear => isAr ? 'خلفية' : 'Rear';
  String get faceTest => isAr ? 'اختبار رصد الوجه' : 'Face Detection Test';
  String get faceTestBody => isAr
      ? 'الحد الأدنى: كاميرا ← صورة حقيقية ← ML Kit ← عدد الوجوه ← الصندوق. بلا متتبع ولا بوابة جودة ولا تثبيت.'
      : 'Minimum viable path: camera → real image → ML Kit → face count → box. No tracker, no quality gate, no lock.';
  String get faceTestOpen =>
      isAr ? 'فتح اختبار رصد الوجه' : 'Open Face Detection Test';
  String faceCountLine(int n) => isAr ? 'الوجوه: $n' : 'Faces: $n';
  String get faceTestPass => isAr ? 'الرصد: ناجح' : 'Detection: PASS';
  String get faceTestFail => isAr ? 'الرصد: لا وجه' : 'Detection: none yet';
  String get cameraHealthTitle => isAr ? 'صحة الكاميرا' : 'Camera Health';
  String get diagTimelineTitle =>
      isAr ? 'الخط الزمني التشخيصي' : 'Diagnostic timeline';
  String get logcatTitle => isAr ? 'سجلات أندرويد' : 'Android logs';
  String get logcatBody => isAr
      ? 'لجمع السجلات من هاتف حقيقي:\n'
            'adb logcat | findstr /i "camera camerax mlkit face ocuscan"\n'
            'شارك المقطع ذا الصلة فقط — وليس السجل الكامل.'
      : 'To collect logs from a real phone:\n'
            'adb logcat | findstr /i "camera camerax mlkit face ocuscan"\n'
            'Share only the relevant excerpt — never the full log.';
  String get stillFaceTestTitle =>
      isAr ? 'اختبار الوجه من لقطة ثابتة' : 'Still face test';
  String get saveFirstFrame => isAr ? 'حفظ أول لقطة' : 'Save first frame';
  String get firstFrameSaved =>
      isAr ? 'حُفظت اللقطة محلياً.' : 'First frame saved locally.';
  String get testPreviewBtn => isAr ? 'اختبار المعاينة' : 'Test preview';
  String get testFirstFrameBtn => isAr ? 'اختبار أول لقطة' : 'Test first frame';
  String get testStillBtn => isAr ? 'اختبار اللقطة' : 'Test still capture';
  String get testFaceBtn => isAr ? 'اختبار راصد الوجه' : 'Test face detector';
  String get testEyeBtn => isAr ? 'اختبار راصد العين' : 'Test eye detector';
  String get camTestPass => isAr ? 'ناجح' : 'PASS';
  String get camTestFail => isAr ? 'فاشل' : 'FAIL';
  String get camTestIdle => isAr ? 'لم يُختبر' : 'Not tested';
  String get snapshotTitle => isAr ? 'فحص باللقطة' : 'SNAPSHOT SCAN';
  String get snapshotBody => isAr
      ? 'التحليل الحي غير متاح على هذا الجهاز. سنستخدم فحصاً باللقطة الثابتة بدلاً منه.'
      : 'Live analysis isn\'t available on this device. We\'ll use a still-image scan instead.';
  String get snapshotCapture => isAr ? 'التقط' : 'Capture';
  String get snapshotUse => isAr ? 'استخدم هذه اللقطة' : 'Use this capture';
  String get snapshotStillMode => isAr
      ? 'فحص بالصورة الثابتة — القياسات الزمنية (الحركة والرمش والاستجابة) غير متاحة في وضع الصورة الواحدة.'
      : 'Still-image screening — temporal measurements (movement, blink, response) are unavailable in single-image mode.';
  String get frameInspectorTitle => isAr ? 'فاحص اللقطات' : 'Frame inspector';
  String get deviceReportTitle => isAr ? 'تقرير الجهاز' : 'Device report';
  String get cameraCompareTitle =>
      isAr ? 'مقارنة الكاميرات' : 'Camera comparison';
  String get exportDiagnostics =>
      isAr ? 'تصدير تقرير التشخيص' : 'Export diagnostic report';
  String get mlTestBtn => isAr ? 'اختبار ML Kit' : 'ML Kit test';
  String get mlTestTitle =>
      isAr ? 'اختبار كاشف الوجه (ML Kit)' : 'ML Kit face detector test';
  String get mlTestBody => isAr
      ? 'اختبارات معزولة، كل منها بكاشف جديد ويُغلق بعده. A: لقطة ملتقطة عبر fromFilePath. B: الصورة المضمّنة عبر fromFilePath (بدون كاميرا). C: بايتات البث الحي عبر fromBytes (للتنسيقات المثبتة فقط). D: RGBA عبر fromBitmap. E/F: العدسة الأمامية/الخلفية الحية. G: إعادة التشغيل وإعادة الإنشاء ووضع عدم الاتصال. النتائج: PASS / NO FACE / EXCEPTION / SKIPPED.'
      : 'Isolated tests, each on a fresh detector closed afterwards. A: captured still via fromFilePath. B: bundled image via fromFilePath (no camera). C: live bytes via fromBytes (proven packed layouts only). D: RGBA via fromBitmap. E/F: live front/rear lens. G: restart, recreation, offline capability. Outcomes: PASS / NO FACE / EXCEPTION / SKIPPED.';
  String get mlRunAll => isAr ? 'تشغيل الكل' : 'Run all';
  String get mlTestRunning => isAr ? 'جارٍ التشغيل…' : 'Running…';
  String get mlNoResults => isAr ? 'لا نتائج بعد.' : 'No results yet.';
  String get mlExportNote => isAr
      ? 'تُسجَّل النتائج كأحداث DIAG_* وتُصدَّر مع تقرير الأخطاء.'
      : 'Results are logged as DIAG_* events and ride the error export.';
  String get vcTitle => isAr
      ? 'نواة الرؤية (تشخيص مستقل)'
      : 'Vision core (independent diagnostic)';
  String get vcBody => isAr
      ? 'ثلاثة اختبارات مستقلة بالترتيب: A صورة بشرية حقيقية مضمّنة (بدون كاميرا). B لقطة ملتقطة من كاميرا الجهاز. C بث حي من الكاميرا الأمامية عبر محرك CameraX الأصلي. المفردات: FACE_DETECTED / NO_FACE / PROCESSING_ERROR — الخطأ يعني المحرك معطوب، لا أنه لم يجد وجهاً.'
      : 'Three independent tests in order: A real-human bundled face (no camera). B still captured from the device camera. C live front-camera stream through the native CameraX engine. Vocabulary: FACE_DETECTED / NO_FACE / PROCESSING_ERROR — an error means the engine is broken, not that it found no face.';
  String get compatLabBtn => isAr ? 'مختبر التوافق' : 'Compatibility lab';
  String get compatLabTitle =>
      isAr ? 'مختبر التوافق العام' : 'Universal compatibility lab';
  String get compatSectionCapabilities => isAr ? 'القدرات' : 'Capabilities';
  String get compatHealthReady =>
      isAr ? 'جاهز: التحليل يعمل.' : 'READY: analysis is flowing.';
  String get compatHealthDegraded => isAr
      ? 'متدهور: الكاميرا تعمل لكن التحليل متعثر — التفاصيل أدناه.'
      : 'DEGRADED: camera is up but analysis is failing — details below.';
  String get compatHealthUnavailable =>
      isAr ? 'غير متاح: لا كاميرا عاملة.' : 'UNAVAILABLE: no working camera.';
  String get compatRowCamera => isAr ? 'الكاميرا' : 'Camera';
  String get compatRowNativeMlKit => isAr ? 'ML Kit الأصلي' : 'Native ML Kit';
  String get compatRowBundledModel =>
      isAr ? 'النموذج المضمّن' : 'Bundled model';
  String get compatRowFallbackEngine =>
      isAr ? 'محرك الاحتياط' : 'Fallback engine';
  String get compatRowLiveAnalysis => isAr ? 'التحليل الحي' : 'Live analysis';
  String get compatRowRotation => isAr ? 'الدوران' : 'Rotation';
  String get compatRowCpu => isAr ? 'استدلال CPU' : 'CPU inference';
  String get compatRowEngine => isAr ? 'المحرك المختار' : 'Selected engine';
  String get compatRowLatency => isAr ? 'زمن الاستجابة' : 'Latency';
  String get compatRowDetection => isAr ? 'الكشف' : 'Detection';
  String get compatRowThroughput => isAr ? 'معدل المعالجة' : 'Throughput';
  String get compatRowQuality => isAr ? 'الجودة' : 'Quality';
  String get compatRowMlInput => isAr ? 'مدخل ML' : 'ML input';
  String get compatPass => isAr ? 'ناجح' : 'PASS';
  String get compatFail => isAr ? 'فاشل' : 'FAIL';
  String get compatLimited => isAr ? 'محدود' : 'LIMITED';
  String get compatYes => isAr ? 'نعم' : 'YES';
  String get compatNo => isAr ? 'لا' : 'NO';
  String get compatNotMeasured => isAr ? 'لم يُقَس' : 'NOT MEASURED';
  String get compatTryNative =>
      isAr ? 'جرّب المحرك الأصلي' : 'Try native engine';
  String get compatUseDart => isAr ? 'عودة لمسار Dart' : 'Back to Dart path';
  String get compatProfileTitle => isAr ? 'ملف الجهاز' : 'Device profile';
  String get diagnosticsExported =>
      isAr ? 'صُدّر التقرير.' : 'Report exported.';
  String get restartCameraDev =>
      isAr ? 'إعادة تشغيل الكاميرا' : 'Restart camera';
  String get saveDiagnosticFrame =>
      isAr ? 'حفظ لقطة تشخيصية' : 'Save diagnostic frame';
  String get deleteDiagnosticFrame =>
      isAr ? 'حذف اللقطة التشخيصية' : 'Delete diagnostic frame';
  String get diagOriginalFrame => isAr ? 'اللقطة الأصلية' : 'Original frame';
  String get diagMlInputView => isAr
      ? 'مدخل ML (تدرج رمادي، مصحح الدوران)'
      : 'ML input (grayscale, rotation-corrected)';
  String get diagNoFrame =>
      isAr ? 'لا لقطة تشخيصية بعد.' : 'No diagnostic frame yet.';
  String experimentFallbackTitle(int id) =>
      isAr ? 'التجربة $id' : 'Experiment $id';
  String deviceLine(String device, String camera, String dist) => isAr
      ? 'الجهاز $device • $camera • المسافة $dist سم'
      : 'Device $device • $camera • dist $dist cm';
  String lightingLine(String lighting, String lux, String angle, String subj) =>
      isAr
      ? 'الإضاءة $lighting$lux • الزاوية $angle° • $subj'
      : 'Lighting $lighting$lux • angle $angle° • $subj';
  String envLine(String v) => isAr ? 'البيئة: $v' : 'Env: $v';
  String operatorLine(String v) => isAr ? 'المشغّل: $v' : 'Operator: $v';
  String get deleteExperimentBody => isAr
      ? 'يحذف هذا التجربة ومحاولاتها ولقطاتها البحثية المحلية. لا يمكن التراجع.'
      : 'This deletes the experiment, its trials, and its local research captures. This cannot be undone.';
  String get recordTrialNote => isAr
      ? 'المحاولة المرفوضة أو المتعذرة نتيجة بحثية صالحة. لا تُعد الالتقاط حتى تنجح — سجّل ما حدث.'
      : 'A rejected or unable trial is a valid research result. '
            'Do not recapture until it passes — record what happened.';
  String get reportBanner => isAr
      ? 'تقرير التجربة — تقييم قياسات وليس تحققاً سريرياً.'
      : 'EXPERIMENT REPORT — measurement evaluation, not clinical validation.';
  String reportExperimentLine(String v) =>
      isAr ? 'التجربة: $v' : 'Experiment: $v';
  String reportTestLine(String v) => isAr ? 'الاختبار: $v' : 'Test: $v';
  String reportDeviceLine(String v) => isAr ? 'الجهاز: $v' : 'Device: $v';
  String reportTrialsLine(int n) => isAr ? 'المحاولات: $n' : 'Trials: $n';
  String reportAcceptedLine(int n) => isAr ? 'المقبولة: $n' : 'Accepted: $n';
  String reportRejectedLine(int n) => isAr ? 'المرفوضة: $n' : 'Rejected: $n';
  String reportUnableLine(int n, String rate) =>
      isAr ? 'تعذّر التقييم: $n$rate' : 'Unable to assess: $n$rate';
  String reportMeanLine(String v) => isAr ? 'المتوسط: $v' : 'Mean: $v';
  String reportSdLine(String v) => isAr ? 'الانحراف: $v' : 'SD: $v';
  String reportConditionsLine(String v) =>
      isAr ? 'الظروف: $v' : 'Conditions: $v';
  String reportNotesLine(String v) => isAr ? 'الملاحظات: $v' : 'Notes: $v';
  String get expNameLabel => isAr
      ? 'الاسم (مثال: تكرارية الحدقة S1)'
      : 'Name (e.g. Pupil repeatability S1)';
  String get expMeasurementLabel => isAr ? 'القياس' : 'Measurement';
  String get expDeviceLabel =>
      isAr ? 'تسمية الجهاز المجهولة' : 'Anonymous device label';
  String get expCameraLabel => isAr ? 'الكاميرا' : 'Camera';
  String get expDistanceLabel =>
      isAr ? 'مسافة الاختبار المضبوطة' : 'Configured test distance';
  String get expLightingLabel => isAr ? 'مستوى الإضاءة' : 'Lighting level';
  String get expLuxLabel => isAr
      ? 'اللوكس المقاس (مقياس، اختياري)'
      : 'Measured lux (meter, optional)';
  String get expHeadAngleLabel => isAr ? 'خطوة زاوية الرأس' : 'Head-angle step';
  String get expSubjectLabel =>
      isAr ? 'معرف الرمز المجهول' : 'Anonymous subject ID';
  String get expDescLabel =>
      isAr ? 'الوصف (اختياري)' : 'Description (optional)';
  String get analyzerCardBanner => isAr
      ? 'توثق كل بطاقة ما يستهلكه المحلل وما ينتجه وما يتطلبه وما لا يستطيع فعله — مع إصدار الخوارزمية. ترتبط نتائج التحقق بالإصدارات.'
      : 'Each card documents what an analyzer consumes, produces, requires, '
            'and cannot do — with its algorithm version. Validation results bind to versions.';
  String get expBadge => 'EXP';

  // ---------- Categorical agreement (Cohen's kappa) + outcome mix ----------
  // Pure research-validation wording: Trial carries one categorical outcome
  // (status); kappa needs paired reference ratings that this schema has no
  // field for, so the UI shows the observed mix instead of inventing kappa.
  String get categoricalAgreementTitle => isAr
      ? 'الاتفاق الفئوي (كابا كوهين)'
      : 'Categorical agreement (Cohen’s κ)';
  String get outcomeMixTitle => isAr
      ? 'توزيع النتائج (الحالات المرصودة)'
      : 'Outcome mix (observed statuses)';
  String get kappaLabel => isAr ? 'كابا كوهين' : 'Cohen’s κ';
  String get kappaBandTitle => isAr ? 'فئة الاتفاق' : 'Agreement band';
  String get kappaNeedsPairedNote => isAr
      ? 'يتطلب الاتفاق تقييمات مرجعية مقترنة — كل محاولة تحمل نتيجة فئوية واحدة فقط (الحالة: مقبولة / مرفوضة / تعذر التقييم)، والمرجع اليدوي هنا قيمة رقمية بلا فئة مرجعية، لذا لا تُحسب كابا. يُعرض توزيع النتائج المرصودة بدلاً من ذلك.'
      : 'Agreement needs paired reference ratings — each trial carries only one categorical outcome (status: accepted / rejected / unable); the manual reference here is a numeric value with no reference category, so Cohen’s κ is not computed. Showing the observed outcome mix instead.';
  String outcomeMixLine(int accepted, int rejected, int unable, int total) =>
      isAr
      ? 'مقبولة $accepted • مرفوضة $rejected • تعذر التقييم $unable • الإجمالي $total'
      : 'Accepted $accepted • Rejected $rejected • Unable $unable • Total $total';

  String kappaBandLabel(String band) {
    const en = {
      'poor': 'Poor',
      'slight': 'Slight',
      'fair': 'Fair',
      'moderate': 'Moderate',
      'substantial': 'Substantial',
      'almost-perfect': 'Almost perfect',
      'insufficient-data': 'Insufficient data',
    };
    const ar = {
      'poor': 'ضعيف',
      'slight': 'طفيف',
      'fair': 'مقبول',
      'moderate': 'متوسط',
      'substantial': 'كبير',
      'almost-perfect': 'شبه تام',
      'insufficient-data': 'بيانات غير كافية',
    };
    return isAr ? (ar[band] ?? band) : (en[band] ?? band);
  }
}
