// Bilingual strings (English + Modern Standard Arabic with Egyptian-friendly
// health wording). Medical terms keep the English term in parentheses on
// detail screens. No color-only meaning; categories always have text+icon.
// v0.4: full consumer + vision + research coverage.

class AppStrings {
  final String lang; // 'en' | 'ar'
  const AppStrings(this.lang);
  bool get isAr => lang == 'ar';

  static const supported = ['en', 'ar'];

  /// Bidi-isolate a Latin/digit run inside Arabic text (U+2066..U+2069)
  /// so mixed-direction strings ("3 m", "85.6 mm", profile names) cannot
  /// reorder or detach. No-op in English.
  String _iso(String v) => isAr ? '\u2066$v\u2069' : v;

  String get appName => 'OcuScan';
  String get tagline => isAr
      ? 'افحص نظرك وعلامات العين والوجه الظاهرة بهاتفك.'
      : 'Check your vision and screen observable eye and facial signs.';
  String get startScreening => isAr ? 'ابدأ الفحص' : 'Start screening';
  String get visionTests => isAr ? 'اختبارات النظر' : 'Vision tests';
  String get lastScreening => isAr ? 'آخر فحص' : 'Last screening';
  String get viewDetails => isAr ? 'عرض التفاصيل' : 'View details';
  String get home => isAr ? 'الرئيسية' : 'Home';
  String get screening => isAr ? 'الفحص' : 'Screening';
  String get vision => isAr ? 'النظر' : 'Vision';
  String get history => isAr ? 'السجل' : 'History';
  String get learn => isAr ? 'تعلّم' : 'Learn';
  String get settings => isAr ? 'الإعدادات' : 'Settings';

  String get welcomeTitle =>
      isAr ? 'أهلاً بك في OcuScan' : 'Welcome to OcuScan';
  String get welcomeBody => isAr
      ? 'افحص علامات العين والوجه الظاهرة واختبر وظائف النظر الأساسية باستخدام هاتفك الذكي.'
      : 'Screen visible eye and facial signs and test basic visual function using your smartphone.';
  String get welcomeStepLine => isAr
      ? 'الخطوة 1 من 2: افهم ما يفعله التطبيق'
      : 'Step 1 of 2: understand what the app does';

  String categoryLabel(String code) {
    switch (code) {
      case 'possible_finding':
        return isAr
            ? 'تم رصد علامة محتملة تستحق المتابعة'
            : 'Possible finding detected';
      case 'unable_to_assess':
        return isAr ? 'تعذّر التقييم بشكل موثوق' : 'Unable to assess reliably';
      default:
        return isAr
            ? 'لا توجد علامة واضحة في هذا الفحص'
            : 'No obvious abnormality observed in this screening';
    }
  }

  String get disclaimer => isAr
      ? 'هذا فحص استرشادي للتوعية وليس تشخيصاً. لا يحدد التطبيق سبب أي علامة ولا يغني عن فحص العين أو الرعاية الطبية.'
      : 'This is a screening observation, not a diagnosis. OcuScan cannot determine the cause of a finding and does not replace an eye examination or medical care.';

  String get prototypeLabel => isAr
      ? 'نموذج أولي للفحص والتوعية — ليس جهازاً تشخيصياً.'
      : 'Educational/research screening prototype — not a diagnostic medical device.';

  String get emergencyTitle =>
      isAr ? 'أعراض تستدعي رعاية عاجلة' : 'Symptoms needing urgent care';
  String get emergencyBody => isAr
      ? 'لا تعتمد على OcuScan في هذه الحالات. اطلب الرعاية الطارئة فوراً.'
      : 'Do not rely on OcuScan for this situation. Seek emergency care promptly.';

  String get deleteData => isAr ? 'حذف جميع البيانات' : 'Delete all data';
  String get exportResults => isAr ? 'تصدير النتائج' : 'Export results';

  String get references => isAr ? 'المراجع' : 'References';
  String get methodology => isAr ? 'المنهجية' : 'Methodology';
  String get retinalInfo =>
      isAr ? 'تصوير الشبكية المستقبلي' : 'Future Retinal Imaging';
  String get colorCalibration =>
      isAr ? 'حالة معايرة الألوان' : 'Color Calibration Status';
  String get evidence => isAr ? 'الدليل' : 'Evidence';
  String get about => isAr ? 'عن التطبيق' : 'About';
  String get createdBy => isAr ? 'إعداد وتطوير' : 'Created and developed by';

  // ---------- Eye-positioning guidance (EyeTracker states) ----------
  // Specific actionable instruction per state — never a vague "adjust".
  String eyeGuideTitle(String key) {
    switch (key) {
      case 'faceNotFound':
        return isAr ? 'أظهر وجهك' : 'Find your face';
      case 'multipleFaces':
        return isAr ? 'وجه واحد فقط' : 'One face only';
      case 'faceTooSmall':
        return isAr ? 'اقترب قليلاً' : 'Move a little closer';
      case 'faceTooLarge':
        return isAr ? 'ابتعد قليلاً' : 'Move slightly farther away';
      case 'faceAngleInvalid':
        return isAr ? 'اجعل وجهك مستوياً' : 'Keep your face level';
      case 'leftEyeUnavailable':
        return isAr ? 'العين اليسرى غير ظاهرة' : 'Left eye not visible';
      case 'rightEyeUnavailable':
        return isAr ? 'العين اليمنى غير ظاهرة' : 'Right eye not visible';
      case 'bothEyesUnavailable':
        return isAr ? 'العينان غير ظاهرتين' : 'Eyes not visible';
      case 'imageTooDark':
        return isAr ? 'الإضاءة ضعيفة' : 'Too dark';
      case 'imageTooBright':
        return isAr ? 'إضاءة قوية أو انعكاس' : 'Too bright / reflections';
      case 'imageTooBlurry':
        return isAr ? 'الصورة غير واضحة' : 'Image not sharp';
      case 'trackingUnstable':
        return isAr ? 'اثبت لحظة' : 'Hold still a moment';
      default:
        return isAr ? 'تم تثبيت العينين' : 'Eyes locked';
    }
  }

  String eyeGuideBody(String key) {
    switch (key) {
      case 'faceNotFound':
        return isAr
            ? 'وجّه الكاميرا الأمامية نحو وجهك ووسّطه داخل الدليل.'
            : 'Point the front camera at your face and center it inside the guide.';
      case 'multipleFaces':
        return isAr
            ? 'ظهر أكثر من وجه. تأكد من وجود شخص واحد فقط أمام الكاميرا.'
            : 'Multiple faces detected. Please make sure only one person is in front of the camera.';
      case 'faceTooSmall':
        return isAr
            ? 'قرّب الهاتف قليلاً حتى يملأ وجهك الدليل.'
            : 'Move the phone a little closer until your face fills the guide.';
      case 'faceTooLarge':
        return isAr
            ? 'أبعد الهاتف قليلاً حتى يظهر وجهك كاملاً داخل الدليل.'
            : 'Move the phone slightly farther away until your whole face fits inside the guide.';
      case 'faceAngleInvalid':
        return isAr
            ? 'اجعل وجهك مستوياً مع الهاتف دون إمالة الرأس.'
            : 'Keep your face level with the phone without tilting your head.';
      case 'leftEyeUnavailable':
        return isAr
            ? 'أدر وجهك قليلاً نحو المنتصف حتى تظهر العين اليسرى.'
            : 'Turn your face slightly toward the center until the left eye appears.';
      case 'rightEyeUnavailable':
        return isAr
            ? 'وسّط وجهك داخل الدليل حتى تظهر العين اليمنى.'
            : 'Center your face inside the guide until the right eye appears.';
      case 'bothEyesUnavailable':
        return isAr
            ? 'تأكد من ظهور العينين معاً: انزع ما يغطيهما ووسّط وجهك.'
            : 'Make sure both eyes are visible together: remove anything covering them and center your face.';
      case 'imageTooDark':
        return isAr
            ? 'انتقل إلى مكان أكثر إضاءة وواجه مصدر الضوء.'
            : 'Move to a brighter area and face the light source.';
      case 'imageTooBright':
        return isAr
            ? 'خفف الإضاءة القوية أو انعكاس النظارة عن عينيك.'
            : 'Reduce strong light or reflections on your glasses.';
      case 'imageTooBlurry':
        return isAr
            ? 'ثبت الهاتف وامسح العدسة الأمامية بلطف.'
            : 'Hold the phone steady and gently wipe the front lens.';
      case 'trackingUnstable':
        return isAr
            ? 'تم رصد العينين — اثبت دون حركة لحظة لإتمام التثبيت.'
            : 'Eyes spotted — hold still a moment to finish locking on.';
      default:
        return isAr
            ? 'تم تحديد العينين بثبات. يمكنك المتابعة.'
            : 'Both eyes are steadily located. You can continue.';
    }
  }

  String get eyeStageFace => isAr ? 'الوجه' : 'Face';
  String get eyeStagePosition => isAr ? 'الوضع' : 'Position';
  String get eyeStageEyes => isAr ? 'العينان' : 'Eyes';
  String get eyeStageStabilize => isAr ? 'التثبيت' : 'Stabilize';
  String get eyeStageReady => isAr ? 'جاهز' : 'Ready';
  String stabilizingProgress(int done, int total) => isAr
      ? 'تثبيت التتبع… $done من $total'
      : 'Stabilizing tracking… $done of $total';
  String get keepEyesInGuide =>
      isAr ? 'أبقِ عينيك داخل الدليل' : 'Keep your eyes inside the guide';

  // ---------- Shared widgets ----------
  String get badgePossibleFinding => isAr ? 'علامة محتملة' : 'Possible finding';
  String get badgeUnable => isAr ? 'تعذّر التقييم' : 'Unable to assess';
  String get badgeNoFinding => isAr ? 'لا علامة واضحة' : 'No obvious finding';
  String get resultObservationLabel => isAr ? 'الملاحظة' : 'OBSERVATION';
  String get resultConfidenceLabel => isAr ? 'الثقة' : 'Confidence';
  String qualityConfidence(String quality, String confidence) => isAr
      ? 'الجودة: $quality • الثقة: $confidence'
      : 'Quality: $quality  •  Confidence: $confidence';
  String get evidenceButton => isAr ? 'الدليل' : 'Evidence';
  String get noEvidenceEntry => isAr
      ? 'لا يوجد مدخل دليل لهذا الاختبار بعد.'
      : 'No evidence entry for this test yet.';
  String get checkMark => '✓';

  // ---------- Common actions ----------
  String get back => isAr ? 'رجوع' : 'Back';
  String get continueBtn => isAr ? 'متابعة' : 'Continue';
  String get finish => isAr ? 'إنهاء' : 'Finish';
  String get cancel => isAr ? 'إلغاء' : 'Cancel';
  String get retry => isAr ? 'إعادة المحاولة' : 'Retry';
  String get loading => isAr ? 'جارٍ التحميل…' : 'Loading…';
  String get close => isAr ? 'إغلاق' : 'Close';

  // ---------- Screening stages ----------
  String get stagePosition => isAr ? 'الوضع' : 'Position';
  String get stageEyes => isAr ? 'العينان' : 'Eyes';
  String get stageMovement => isAr ? 'الحركة' : 'Movement';
  String get stageMeasurements => isAr ? 'القياسات' : 'Measurements';
  String get stageSummary => isAr ? 'الملخص' : 'Summary';
  String get screeningTitle =>
      isAr ? 'فحص العين والوجه' : 'Eye & face screening';
  String stepOf(int step, int total, String name) =>
      isAr ? 'الخطوة $step من $total — $name' : 'Step $step of $total — $name';
  String get screeningSafetyNote => isAr
      ? 'فحص استرشادي فقط — وليس تشخيصاً. لا يحدد OcuScan سبب أي علامة.'
      : 'Screening only — not a diagnosis. OcuScan cannot determine the cause of any finding.';

  // ---------- Camera permission dialog ----------
  String get cameraUnavailableTitle =>
      isAr ? 'الكاميرا غير متاحة' : 'Camera unavailable';
  String get cameraBlockedBody => isAr
      ? 'يحتاج OcuScan إلى الكاميرا للفحص. الوصول إلى الكاميرا محظور — افتح إعدادات النظام للسماح به. بدون الوصول تُسجَّل نتائج «تعذّر التقييم» بدل التخمين.'
      : 'OcuScan needs camera access for screening. Camera access is blocked — open system settings to allow it. Without access, tests report “unable to assess” instead of guessing.';
  String cameraDeniedBody(String detail) => isAr
      ? 'يحتاج OcuScan إلى الكاميرا للفحص. $detail'
      : 'OcuScan needs camera access for screening. $detail';
  String get cameraDeniedDefault => isAr
      ? 'يرجى السماح بالوصول إلى الكاميرا للمتابعة.'
      : 'Please allow camera access to continue.';
  String get notNow => isAr ? 'ليس الآن' : 'Not now';
  String get openSettings => isAr ? 'افتح الإعدادات' : 'Open settings';

  // ---------- Vision Lab ----------
  // UI chrome is localized. Persisted measurement records (test names,
  // finding labels, limitations) stay canonical English so history rows
  // are locale-independent; result banners show the recorded text.
  String get visionLabTitle => isAr ? 'مختبر النظر' : 'Vision Lab';
  String get visionTabDistance => isAr ? 'البعد' : 'Distance';
  String get visionTabNear => isAr ? 'القرب' : 'Near';
  String get visionTabColor => isAr ? 'الألوان' : 'Color';
  String get visionTabContrast => isAr ? 'التباين' : 'Contrast';
  String get visionTabCentral => isAr ? 'المركز' : 'Central';
  String get visionTabPeripheral => isAr ? 'المحيط' : 'Peripheral';
  String get visionTabCover => isAr ? 'التغطية' : 'Cover';
  String get visionCatalogTitle =>
      isAr ? 'اختبارات مختبر النظر' : 'Vision Lab tests';
  String get visionCatalogBody => isAr
      ? 'حدة البعد — وضوح البعد • ~دقيقتان • معايرة 3 م\n\n'
            'حدة القرب — نظر القرب • ~دقيقة • مسافة 40 سم\n\n'
            'الألوان — تمييز الألوان • ~دقيقتان • سطوع كامل وبدون فلاتر\n\n'
            'التباين — نظر التباين المنخفض • ~دقيقتان • ظروف مسجلة\n\n'
            'النظر المركزي — فحص التشوه • ~دقيقتان • شبكة لكل عين\n\n'
            'المجال المحيطي — الوعي الجانبي • ~3 دقائق • يلزم التثبيت\n\n'
            'محاذاة العين — اختبار التغطية الموجه • ~دقيقتان • تتبع الكاميرا\n\n'
            'الحالة: قياسات فحص مع معالجة التكرارية — وليست وصفات طبية أبداً.'
      : 'Distance acuity — clarity at distance • ~2 min • 3 m calibration\n\n'
            'Near acuity — near vision • ~1 min • 40 cm hold\n\n'
            'Color — color discrimination • ~2 min • brightness + filters off\n\n'
            'Contrast — low-contrast vision • ~2 min • recorded conditions\n\n'
            'Central vision — distortion check • ~2 min • per-eye grid\n\n'
            'Peripheral field — side awareness • ~3 min • fixation required\n\n'
            'Eye alignment — guided cover test • ~2 min • camera tracking\n\n'
            'Status: screening measurements with repeatability handling — never prescriptions.';
  String get testCatalogTooltip => isAr ? 'كتالوج الاختبارات' : 'Test catalog';
  String get eyeRight => isAr ? 'اليمنى' : 'right';
  String get eyeLeft => isAr ? 'اليسرى' : 'left';
  String get eyeBoth => isAr ? 'كلتاهما' : 'both';
  String get eyeRightLabel => isAr ? 'العين اليمنى' : 'Right eye';
  String get eyeLeftLabel => isAr ? 'العين اليسرى' : 'Left eye';
  String get eyeBothLabel => isAr ? 'كلتا العينين' : 'Both eyes';
  String eyeName(String code) {
    switch (code) {
      case 'right':
        return eyeRight;
      case 'left':
        return eyeLeft;
      default:
        return eyeBoth;
    }
  }

  String get calibStatusLabel => isAr ? 'حالة المعايرة' : 'Calibration status';
  String get calibDistanceLabel => isAr ? 'المسافة' : 'Distance';
  String get calibScreenLabel => isAr ? 'الشاشة' : 'Screen';
  String get calibLightingLabel => isAr ? 'الإضاءة' : 'Lighting';
  String get calibEyeLabel => isAr ? 'العين' : 'Eye';
  String calibStatusLine(String status) =>
      isAr ? 'حالة المعايرة: $status' : 'Calibration status: $status';
  String calibDistanceLine(String v) => isAr ? 'المسافة: $v' : 'Distance: $v';
  String calibScreenLine(String v) => isAr ? 'الشاشة: $v' : 'Screen: $v';
  String calibLightingLine(String v) => isAr ? 'الإضاءة: $v' : 'Lighting: $v';
  String calibEyeLine(String v) => isAr ? 'العين: $v' : 'Eye: $v';

  String get distanceBanner => isAr
      ? 'غطِّ عيناً واحدة في كل مرة. أمسك الهاتف على بعد 3 م (نحو 10 أقدام). سطوع كامل وبدون تكبير. هذا قياس فحص وليس وصفة.'
      : 'Cover one eye at a time. Hold the phone at 3 m (about 10 ft). Full brightness, no zoom. This is a screening measurement, not a prescription.';
  String get distanceCheckDist => isAr
      ? 'وضعت الهاتف على مسافة 3 م (شريط قياس/خطوات/مساعِد)'
      : 'Phone placed at 3 m (tape / steps / helper)';
  String get distanceCheckBright => isAr
      ? 'السطوع كامل ووضع الليل والفلاتر متوقفة'
      : 'Full brightness, night mode and filters OFF';
  String get distanceChecklist => isAr
      ? 'وضعت الهاتف على بعد 3 م وضبطت السطوع الكامل'
      : 'I placed the phone at 3 m and set full brightness';
  String get distanceUncalibratedWarn => isAr
      ? 'بدون مسافة معايَرة تُوسم النتائج بأنها غير موثوقة.'
      : 'Without calibrated distance, results are marked unreliable.';
  String get distanceCalibOn =>
      isAr ? 'تمت المعايرة بقائمة المشغّل' : 'Calibrated by operator checklist';
  String get distanceCalibOff => isAr
      ? 'غير معايَرة — النتائج موسومة بعدم الموثوقية'
      : 'Uncalibrated — results marked unreliable';
  String get distanceDistValue =>
      isAr ? '3 م (بتحقق المشغّل)' : '3 m (operator-verified)';
  String get distanceScreenValue => isAr
      ? 'سطوع كامل وبدون تكبير (حجم النص ثابت)'
      : 'Full brightness, no zoom (text scaling locked)';
  String visionDisplayMeasured(double dpi) => isAr
      ? 'الشاشة مقاسة: ${dpi.toStringAsFixed(0)} نقطة/بوصة (أحجام حروف حقيقية)'
      : 'Display measured: ${dpi.toStringAsFixed(0)} dpi (true letter sizes)';
  String get visionDisplayUncalibrated => isAr
      ? 'الشاشة غير مقاسة: أحجام الحروف تقريبية'
      : 'Display unmeasured: letter sizes approximate';
  String get cardCalTitle => isAr ? 'معايرة البطاقة' : 'Card calibration';
  String get cardCalBody => isAr
      ? 'ضع بطاقة بنكية قياسية (عرضها 85.6 مم) على الشاشة. اسحب حتى يطابق المربع عرض البطاقة تماماً ثم اعتمد المعايرة — تصبح أحجام الحروف حقيقية دون الحاجة لبيانات الشاشة.'
      : 'Hold a standard bank card (85.6 mm wide) against the screen. Drag until the box exactly matches the card width, then use the calibration — letter sizes become true with no display data needed.';
  String get cardCalUse =>
      isAr ? 'اعتماد هذه المعايرة' : 'Use this calibration';
  String get cardCalClear => isAr ? 'مسح المعايرة' : 'Clear calibration';
  String get cardCalibratedNote => isAr
      ? 'معايَرة بالبطاقة (مرجع 85.6 مم)'
      : 'Card-calibrated (85.6 mm reference)';
  String cardCalBoxLine(double px) => isAr
      ? 'عرض المربع: ${_iso(px.toStringAsFixed(0))} بكسل'
      : 'Box width: ${px.toStringAsFixed(0)} px';
  String get distanceLightValue => isAr
      ? 'إضاءة داخلية متساوية؛ سجّل الظروف'
      : 'Even indoor light; record conditions';
  String get iSeeIt => isAr ? 'أراها / صحيح' : 'I see it / correct';
  String get tumblingHint => isAr
      ? 'إلى أين تشير أطراف الحرف؟ اختر الاتجاه.'
      : 'Which way do the limbs point? Pick the direction.';
  String get visionBeyondDisplay => isAr
      ? 'هذا المستوى أدق من قدرة هذه الشاشة — يُسجَّل تعذّر التقييم بدل التخمين.'
      : 'This level is finer than this display can render — recorded as unable instead of guessing.';
  String get unsureWrong => isAr ? 'غير متأكد / خطأ' : 'Unsure / wrong';
  String levelLine(String label, int pos, int total, int correct) => isAr
      ? 'المستوى $label • العنصر ${pos + 1}/$total • الصحيح حتى الآن: $correct'
      : 'Level $label • item ${pos + 1}/$total • correct so far: $correct';
  String coverEyeLine(String eye) => isAr
      ? 'غطِّ العين $eye وتابع على بعد 3 م.'
      : 'Cover the $eye eye and continue at 3 m.';

  String get nearBanner => isAr
      ? 'أمسك الهاتف على بعد 40 سم (نحو مسافة المرفق). اختبر كل عين على حدة. لا تستنتج وصفة نظارة.'
      : 'Hold the phone at 40 cm (about elbow distance). Test each eye separately. Do not infer a glasses prescription.';
  String get nearTooSmall => isAr ? 'صغير جداً — أكبر' : 'Too small — larger';
  String get nearCanRead => isAr ? 'أستطيع قراءته' : 'I can read this';
  String get nearDistValue =>
      isAr ? 'مسافة إمساك ~40 سم' : '~40 cm hold distance';
  String get nearLightValue => isAr ? 'ضوء قراءة جيد' : 'Good reading light';
  String get nearStatusValue => isAr
      ? 'بإشراف المشغّل — لا يستطيع الجهاز التحقق من مسافة الإمساك'
      : 'Operator-maintained — device cannot verify hold distance';

  String get colorBanner => isAr
      ? 'عطّل الوضع الليلي وفلاتر الضوء الأزرق وتصحيح الألوان. اضبط السطوع الكامل — إعدادات الجهاز تؤثر في النتائج. لوحات مُولَّدة؛ لا تُستخدم لوحات محمية بحقوق.'
      : 'Disable night mode, blue-light filters, and color correction. Set full brightness — device settings influence results. Generated plates; no copyrighted plates used.';
  String get colorDistValue =>
      isAr ? 'مسافة مشاهدة مريحة' : 'Comfortable viewing distance';
  String get colorScreenValue => isAr
      ? 'سطوع كامل؛ الوضع الليلي والفلاتر وتصحيح الألوان متوقفة'
      : 'Full brightness; night mode, filters, and color correction OFF';
  String get colorLightValue => isAr
      ? 'ضوء داخلي محايد؛ تحقق من حالة معايرة الألوان'
      : 'Neutral indoor light; check Color Calibration Status';
  String get colorEyeValue => isAr ? 'كلتاهما (فحص)' : 'both (screening)';
  String get colorStatusValue => isAr
      ? 'بتحقق المشغّل — مخرجات الشاشة تختلف بين الأجهزة'
      : 'Operator-verified — display output varies by device';
  String plateLine(int n, String axis) =>
      isAr ? 'اللوحة $n/12 — المحور: $axis' : 'Plate $n/12 — axis: $axis';
  String get colorCheckNight =>
      isAr ? 'الوضع الليلي متوقف' : 'Night mode is OFF';
  String get colorCheckFilters => isAr
      ? 'فلاتر الضوء الأزرق وتصحيح الألوان متوقفة'
      : 'Blue-light filters and color correction OFF';
  String get colorPrompt => isAr
      ? 'ما الرقم الذي تراه؟ (أدخل «؟» إذا لم يبرز شيء.)'
      : 'What digit do you see? (Enter “?” if nothing stands out.)';
  String get colorHint => isAr ? 'رقم أو ؟' : 'digit or ?';
  String get nextPlate => isAr ? 'اللوحة التالية' : 'Next plate';

  String get contrastBanner => isAr
      ? 'سجّل السطوع والمسافة (~1 م) والإضاءة المحيطة. تظهر أنماط باهتة مع انخفاض التباين.'
      : 'Record brightness, distance (~1 m), and ambient light. Faint patterns appear as contrast drops.';
  String get contrastDistValue =>
      isAr ? 'مسافة مشاهدة ~1 م' : '~1 m viewing distance';
  String get contrastScreenValue =>
      isAr ? 'سطوع مسجل وبدون تكبير' : 'Recorded brightness, no zoom';
  String get contrastLightValue => isAr
      ? 'إضاءة محيطة مستقرة (مسجلة مع النتيجة)'
      : 'Stable ambient light (recorded with result)';
  String get contrastEyeValue =>
      isAr ? 'أي منهما (مسجلة)' : 'either (recorded)';
  String get contrastBrightnessLabel =>
      isAr ? 'سطوع الشاشة أثناء الاختبار' : 'Screen brightness during test';
  String get centralGridCenter =>
      isAr ? 'الخلية المركزية: انظر هنا' : 'Center cell: look here';
  String centralGridCell(int i, bool marked) => isAr
      ? 'خلية الشبكة $i من 49، ${marked ? 'محددة' : 'غير محددة'}'
      : 'Grid cell $i of 49, ${marked ? 'marked' : 'unmarked'}';
  String trialCountLine(int i, int n) =>
      isAr ? 'المحاولة $i من $n' : 'Trial $i of $n';
  String get periphArmFlash => isAr
      ? 'بدء الوميض (تلقائي بعد لحظات)'
      : 'Start flash (auto after a moment)';
  String periphDotNote(String size) =>
      isAr ? 'حجم النقطة: $size' : 'Dot size: $size';
  String get coverDwellSkip => isAr ? 'تخطَّ الانتظار' : 'Skip wait';
  String coverDwellLine(int seconds) => isAr
      ? 'اثبت على هذه الوضعية… بقي $seconds ثوانٍ.'
      : 'Hold this position… $seconds s left.';
  String get contrastStatusValue => isAr
      ? 'مرتبط بالظروف — لا معايير للشاشات غير المعايَرة'
      : 'Condition-bound — no norms for uncalibrated displays';
  String contrastLine(double pct, int step, int total) => isAr
      ? 'التباين ${pct.toStringAsFixed(0)}% — الخطوة $step/$total'
      : 'Contrast ${pct.toStringAsFixed(0)}% — step $step/$total';
  String get contrastSee => isAr ? 'أراه' : 'I see it';
  String get contrastCannotSee => isAr ? 'لا أرى' : 'Cannot see';

  String get centralBanner => isAr
      ? 'غطِّ عيناً واحدة. حدّق في النقطة المركزية على بعد 30 سم. هل تبدو أي خطوط منحنية أو مفقودة أو ضبابية أو مشوهة؟ انقر المربعات التي تبدو خاطئة. فحص فقط — وليس تشخيص تنكس بقعي.'
      : 'Cover one eye. Stare at the center dot at 30 cm. Do any lines look bent, missing, blurred, or distorted? Tap squares that look wrong. Screening only — not an AMD diagnosis.';
  String get centralDistValue =>
      isAr ? 'مسافة تثبيت 30 سم' : '30 cm fixation distance';
  String get centralGlassesCheck => isAr
      ? 'أرتدي النظارة/العدسات أثناء الاختبار'
      : 'Wearing glasses/contacts for this test';
  String get centralGlassesOn =>
      isAr ? 'بالنظارة/العدسات' : 'with glasses/contacts';
  String get centralGlassesOff =>
      isAr ? 'بدون نظارة/عدسات' : 'without glasses/contacts';
  String get centralScreenValue => isAr
      ? 'سطوع كامل والشبكة ظاهرة كاملة'
      : 'Full brightness, grid fully visible';
  String get centralLightValue =>
      isAr ? 'ضوء داخلي متساوٍ' : 'Even indoor light';
  String get centralStatusValue => isAr
      ? 'بروتوكول لكل عين بإشراف المشغّل'
      : 'Operator-maintained per-eye protocol';
  String get submitGrid => isAr ? 'إرسال الشبكة' : 'Submit grid';

  String get peripheralBanner => isAr
      ? 'حدّق في الصليب المركزي. اضغط «رأيتها» عندما تومض نقطة عند الحافة. كل عين على حدة. ليس تشخيص زرق أبداً.'
      : 'Stare at the center cross. Press “I saw it” when a dot flashes at the edge. Each eye separately. Never a glaucoma diagnosis.';
  String get peripheralDistValue =>
      isAr ? 'مشاهدة مريحة بطول الذراع' : 'Comfortable arm’s-length viewing';
  String get peripheralScreenValue => isAr
      ? 'سطوع كامل؛ يتطلب الاختبار تثبيتاً مركزياً على الصليب'
      : 'Full brightness; Test requires central fixation on the cross';
  String get peripheralLightValue =>
      isAr ? 'تُفضَّل غرفة مظلمة هادئة' : 'Dark quiet room preferred';
  String get peripheralStatusValue => isAr
      ? 'تجربة فحص — ليست بديلاً عن محيط العين'
      : 'Screening experiment — not a perimeter replacement';
  String trialLine(int n, String region, String eye) => isAr
      ? 'المحاولة $n — المنطقة: $region (العين $eye)'
      : 'Trial $n — region: $region ($eye eye)';
  String get flashDot => isAr ? 'أومض النقطة' : 'Flash dot';
  String get sawIt => isAr ? 'رأيتها' : 'I saw it';
  String get missedNext =>
      isAr ? 'فاتتني / المنطقة التالية' : 'Missed / next region';

  String get coverBanner => isAr
      ? 'ادمج مع تتبع الكاميرا. سجّل الحركة عند تغيير العين المغطاة. يعرض الحركة المرصودة فقط — وليس تشخيص مرض تلقائياً أبداً.'
      : 'Combine with camera tracking. Record movement when changing which eye is covered. Shows observed movement only — never an automatic disease diagnosis.';
  String get coverDistValue => isAr
      ? 'واجه الكاميرا بالمسافة الموجهة'
      : 'Face the camera at guided distance';
  String get coverScreenValue =>
      isAr ? 'هدف التثبيت ظاهر' : 'Fixation target visible';
  String get coverLightValue =>
      isAr ? 'ضوء أمامي متساوٍ للتتبع' : 'Even frontal light for tracking';
  String get coverEyeValue =>
      isAr ? 'كلتاهما (تسلسل تغطية)' : 'both (cover sequence)';
  String get coverStatusValue => isAr
      ? 'معتمد على التتبع — فقدان تثبيت النظر يُبطل المحاولة'
      : 'Tracking-dependent — loss of gaze lock invalidates the trial';
  String coverStepLine(int n, String phase) =>
      isAr ? 'الخطوة $n/5: $phase' : 'Step $n/5: $phase';
  String get coverAskMovement => isAr
      ? 'هل تحركت العين المكشوفة عند تغطية الأخرى؟'
      : 'Did the uncovered eye move when the other was covered?';
  String get coverNoMovement => isAr ? 'لا حركة' : 'No movement';
  String get coverSmallShift => isAr ? 'انزياح بسيط' : 'Small shift';
  String get coverClearMovement => isAr ? 'حركة واضحة' : 'Clear movement';
  String get coverSave => isAr ? 'حفظ في السجل' : 'Save to history';
  String get coverSaved => isAr ? 'حُفظ في السجل.' : 'Saved to history.';
  String get coverRefractiveNote => isAr
      ? 'فحص انكساري تجريبي: النتائج المتوافقة مع احتمال خطأ انكساري للبعد هي محفزات إحالة فقط — وليست وصفة أبداً.'
      : 'Experimental refractive screen: results consistent with possible distance refractive error are referral prompts only — never a prescription.';
  String coverPhase(String code) {
    switch (code) {
      case 'center':
        return isAr ? 'انظر إلى النقطة المركزية' : 'Look at center dot';
      case 'coverL':
        return isAr ? 'غطِّ العين اليسرى (10 ث)' : 'Cover LEFT eye (10s)';
      case 'uncover1':
        return isAr ? 'اكشف — لاحظ' : 'Uncover — observe';
      case 'coverR':
        return isAr ? 'غطِّ العين اليمنى (10 ث)' : 'Cover RIGHT eye (10s)';
      default:
        return isAr ? 'اكشف — لاحظ' : 'Uncover — observe';
    }
  }

  // ---------- Welcome ----------
  String get canTitle =>
      isAr ? 'ما يستطيع OcuScan فعله' : 'What OcuScan CAN do';
  List<String> get canItems => isAr
      ? [
          'قياس ميزات بصرية مختارة',
          'تحليل حركة العين/الوجه',
          'إجراء اختبارات بأسلوب حدة البصر',
          'إجراء اختبارات الألوان والتباين',
          'تحديد علامات ظاهرة معينة للفحص',
          'تتبع التغيرات عبر الزمن',
        ]
      : [
          'Measure selected visual features',
          'Analyze eye/facial movement',
          'Perform visual-acuity-style tests',
          'Perform color and contrast tests',
          'Identify certain observable abnormalities for screening',
          'Track changes over time',
        ];
  String get cannotTitle =>
      isAr ? 'ما لا يستطيع OcuScan فعله' : 'What OcuScan CANNOT do';
  List<String> get cannotItems => isAr
      ? [
          'تشخيص الأمراض',
          'الاستغناء عن فحص العين',
          'الاستغناء عن الفحوص المخبرية',
          'فحص الشبكية بكاميرا أمامية عادية',
          'تحديد سبب أي علامة غير طبيعية',
          'ضمان خلوك من أي مرض',
        ]
      : [
          'Diagnose diseases',
          'Replace an eye examination',
          'Replace laboratory tests',
          'Examine the retina using a normal front camera',
          'Determine the cause of an abnormal finding',
          'Guarantee that you have no disease',
        ];

  // ---------- Consent ----------
  String get consentTitle => isAr ? 'الموافقة والسلامة' : 'Consent & safety';
  String get consentHeading =>
      isAr ? 'قبل أول فحص لك' : 'Before your first screening';
  String get consentBanner => isAr
      ? 'OcuScan نموذج أولي للفحص والتوعية. لا يشخص الأمراض ولا يغني عن فحص العين ولا يحدد سبب أي علامة. تعمل معالجة الكاميرا على هذا الجهاز. لا تُرفع الصور الخام ولا تُخزَّن افتراضياً — تُحفظ القياسات فقط، وفقط إذا أبقيت السجل مفعّلاً.'
      : 'OcuScan is an educational/research screening prototype. It does not diagnose disease, '
            'does not replace an eye examination, and cannot determine the cause of any finding. '
            'Camera processing runs on this device. Raw images are NOT uploaded or stored by default — only measurements are saved, and only if you keep history on.';
  String get consentPrivacyTitle =>
      isAr ? 'الخصوصية افتراضياً' : 'Privacy default';
  String get consentPrivacyBody => isAr
      ? 'الكاميرا ← معالجة على الجهاز ← قياسات ← نتيجة ← تُحذف الصورة الخام.'
      : 'Camera → on-device processing → measurements → result → raw image deleted.';
  String get consentEmergencyTitle =>
      isAr ? 'أعراض طارئة' : 'Emergency symptoms';
  String get consentEmergencyBody => isAr
      ? 'فقدان النظر المفاجئ أو ألم العين الشديد أو الإصابة أو التعرض الكيميائي أو الضعف المفاجئ في الوجه أو صعوبة الكلام أو الصداع الشديد المفاجئ تستدعي رعاية طارئة — لا تعتمد على OcuScan في هذه الحالات.'
      : 'Sudden vision loss, severe eye pain or injury, chemical exposure, sudden facial weakness, '
            'trouble speaking, or sudden severe headache need emergency care — do not rely on OcuScan for these.';
  String get consentCheckbox => isAr
      ? 'أفهم أن هذه أداة فحص وليست تشخيصاً، وأوافق على المتابعة.'
      : 'I understand this is a screening tool, not a diagnosis, and I agree to continue.';
  String get consentContinue =>
      isAr ? 'فهمت — متابعة' : 'I understand — continue';
  String get consentReviewEmergency => isAr
      ? 'راجع إرشادات الأعراض العاجلة أولاً'
      : 'Review urgent-symptom guidance first';

  // ---------- Home ----------
  String get urgentSymptoms => isAr ? 'أعراض عاجلة' : 'Urgent symptoms';
  String get lastScreeningTitle => isAr ? 'آخر فحص' : 'Last screening';
  String get noScreeningsYet => isAr ? 'لا فحوصات بعد.' : 'No screenings yet.';
  String get firstRunTitle =>
      isAr ? 'فحصك الأول في ٣ خطوات' : 'Your first screening in 3 steps';
  List<String> get firstRunSteps => isAr
      ? [
          'اقبل الكاميرا عند الطلب — تبقى المعالجة على هذا الهاتف.',
          'أكمل الفحص الموجَّه: إضاءة جيدة، هاتف بمستوى العين، وجه ثابت.',
          'راجع السجل والتقرير، وأعد الفحص عند الحاجة.',
        ]
      : [
          'Allow the camera when asked — processing stays on this phone.',
          'Complete the guided screening: good light, phone at eye level, steady face.',
          'Review history and the report, and repeat when needed.',
        ];
  String get firstRunCameraHelp =>
      isAr ? 'إعداد الكاميرا أولاً' : 'Set up the camera first';
  String researchStatus(bool on) => isAr
      ? (on
            ? 'حالة البحث — وضع البحث: مفعّل (قياسات فقط، محلياً)'
            : 'حالة البحث — وضع البحث: متوقف')
      : (on
            ? 'Research status — Research mode: ON (measurements only, local)'
            : 'Research status — Research mode: OFF');
  String homeSummaryLine(String date, int tests, int findings, int unable) =>
      isAr
      ? '${_iso(date)} • ${_iso('$tests')} اختبارات • ${_iso('$findings')} علامة محتملة • ${_iso('$unable')} تعذّر تقييم'
      : '$date • $tests tests • $findings possible finding(s) • $unable unable-to-assess';
  String get cameraUnavailableFlow => isAr
      ? 'الكاميرا غير متاحة — سيُسجَّل تعذّر التقييم بدل التخمين.'
      : 'Camera unavailable — flow reports unable-to-assess.';
  String cameraIssue(String error) => isAr
      ? 'مشكلة في الكاميرا: $error. سيُسجَّل تعذّر التقييم بدل التخمين.'
      : 'Camera issue: $error. The flow will report unable-to-assess rather than guess.';
  String get cameraPermissionError => isAr
      ? 'الكاميرا غير متاحة. تحقق من الأذونات أو توفر الجهاز.'
      : 'Camera unavailable. Please check permissions or device availability.';

  // Stage: Position
  String get positionTitle => isAr
      ? 'ضع وجهك داخل الدليل. أبقِ الهاتف بمستوى العين تقريباً.'
      : 'Position your face inside the guide. Keep the phone at approximately eye level.';
  String get positionCheckLighting => isAr ? 'إضاءة جيدة' : 'Good lighting';
  String get positionCheckEyes =>
      isAr ? 'العينان ظاهرتان' : 'Both eyes visible';
  String get positionCheckCentered =>
      isAr ? 'الوجه في المنتصف' : 'Face centered';
  String get positionCheckSharp => isAr ? 'صورة واضحة' : 'Image sharp';
  String get positionHint => isAr
      ? 'انتقل إلى غرفة جيدة الإضاءة. ضع وجهك داخل الدليل. المسافة: 30–40 سم تقريباً لخطوات الوجه.'
      : 'Move to a well-lit room. Place your face inside the guide. Distance: approximately 30–40 cm for face steps.';
  String positionNextStep(String item) =>
      isAr ? 'أصلح أولاً: $item' : 'Fix first: $item';
  String eyeTryingLine(int seconds) => isAr
      ? 'نحاول تثبيت العينين… ($seconds ث). ابقَ ثابتاً.'
      : 'Trying to lock onto your eyes… ($seconds s). Hold still.';

  // Stage: Eyes (staged positioning)
  String get eyesHint => isAr
      ? 'اتبع التعليمات حتى يتم تثبيت العينين، ثم تابع.'
      : 'Follow the guidance until the eyes lock on, then continue.';
  String get chipLighting => isAr ? 'الإضاءة' : 'Lighting';
  String get chipPosition => isAr ? 'وضع الوجه' : 'Face position';
  String get chipEyes => isAr ? 'العينان' : 'Eyes';
  String get chipGood => isAr ? 'جيدة' : 'GOOD';
  String get chipCheck => isAr ? 'تحقق' : 'CHECK';
  String get chipReady => isAr ? 'جاهز' : 'READY';
  String get chipAdjust => isAr ? 'اضبط' : 'ADJUST';
  String get chipVisible => isAr ? 'ظاهرتان' : 'VISIBLE';
  String get chipHidden => isAr ? 'مخفيتان' : 'HIDDEN';
  String get startingCamera =>
      isAr ? 'جارٍ تشغيل الكاميرا…' : 'Starting camera…';
  String faceLiveLine(double yaw, bool centered) => isAr
      ? 'تم رصد الوجه • الانحراف ${yaw.toStringAsFixed(1)}° • في المنتصف: ${centered ? 'نعم' : 'لا'}'
      : 'Face detected • yaw ${yaw.toStringAsFixed(1)}° • centered: $centered';
  String get noFaceYet => isAr
      ? 'لم يُرصد وجه بعد — وسّط وجهك في الدليل.'
      : 'No face detected yet — center your face in the guide.';
  String get lockOn =>
      isAr ? 'تم التثبيت — يمكنك المتابعة' : 'Locked on — you can continue';
  String get needLockToContinue => isAr
      ? 'أكمل تثبيت العينين للمتابعة بقياس موثوق.'
      : 'Finish eye lock-on to continue with a reliable measurement.';
  String get manualPositionTitle => isAr
      ? 'تعذّر التثبيت التلقائي على هذا الهاتف'
      : 'Automatic lock is unavailable on this phone';
  String get manualPositionBody => isAr
      ? 'الكاميرا تعمل لكن تعذّر تثبيت العينين تلقائياً. يمكنك المتابعة يدوياً: وسّط وجهك في الدليل ثم أكّد. ستعمل اختبارات النظر والقياسات المتاحة، بينما ستُظهر القياسات المعتمدة على التثبيت «تعذّر تقييم» بدل التخمين.'
      : 'The camera works but automatic eye lock is unavailable. You can still continue manually: center your face in the guide, then confirm. Vision tests and available measurements will run; lock-dependent measures will report unable-to-assess instead of guessing.';
  String get manualPositionConfirm => isAr
      ? 'وجهي في الوضع الصحيح — متابعة'
      : 'My face is positioned — continue';
  String get manualPositionNote => isAr
      ? 'تم استخدام التثبيت اليدوي في هذا الفحص (بدون تثبيت تلقائي للعين).'
      : 'Manual positioning was used for this screening (no automatic eye lock).';
  String get escapeTitle => isAr
      ? 'التثبيت التلقائي متعذر — اختر طريقة المتابعة'
      : 'Automatic lock is stuck — choose how to continue';
  String get escapeBody => isAr
      ? 'المتابعة اليدوية تُبقي القياسات الزمنية لكن القياسات المعتمدة على التثبيت ستتعذر. اللقطة الثابتة تفقد القياسات الزمنية لكنها قد تعطي قياسات ألوان أدق. في الحالتين: لا تخمين.'
      : 'Manual continue keeps temporal measurements, but lock-dependent measures will be unable. A still snapshot loses temporal measures but may give better color measurements. Either way: no guessing.';
  String get escapeManual => isAr ? 'متابعة يدوية' : 'Continue manually';
  String get escapeSnapshot =>
      isAr ? 'التقاط صورة ثابتة بدلاً' : 'Take a still instead';

  // Stage: Movement
  String get movementTitle => isAr
      ? 'انظر للأمام مباشرة. ثم: ثبات محايد • ارفع الحاجبين • أغلق العينين بقوة • ابتسم • انفخ خديك.'
      : 'Look straight ahead. Then: neutral hold • raise both eyebrows • close both eyes tightly • smile • puff your cheeks.';
  String get movementHint => isAr
      ? 'أبقِ الكاميرا مستوية والوجه في المنتصف وبمسافة متقاربة وإضاءة مضبوطة. اثبت على كل تعبير ~3 ثوانٍ للمقارنة الزمنية.'
      : 'Keep the camera level, face centered, similar distance, controlled lighting. Hold each expression ~3 seconds for temporal comparison.';
  String get sampleNeutral => isAr ? 'عيّنة محايدة' : 'Sample neutral';
  String get sampleBrow => isAr ? 'عيّنة رفع الحاجبين' : 'Sample brow raise';
  String get sampleEyesClosed =>
      isAr ? 'عيّنة إغلاق العينين' : 'Sample eyes closed';
  String get sampleSmile => isAr ? 'عيّنة ابتسامة' : 'Sample smile';
  String get sampleCheek => isAr ? 'عيّنة نفخ الخدين' : 'Sample cheek puff';
  String samplesRecorded(int n, double yaw) => isAr
      ? 'العينات المسجلة: $n. انحراف الرأس الآن: ${yaw.toStringAsFixed(1)}°.'
      : 'Samples: $n recorded. Head yaw now: ${yaw.toStringAsFixed(1)}°.';
  String get movementSafety => isAr
      ? 'الضعف المفاجئ في الوجه مع تغيرات الكلام أو ضعف الذراع أو تغيرات النظر يستدعي رعاية طارئة — لا تعتمد على الكاميرا في ذلك.'
      : 'Sudden facial weakness with speech changes, arm weakness, or vision changes needs emergency care — do not rely on the camera for this.';
  String sampledSidesSnack(String key, double left, double right, double yaw) =>
      isAr
      ? 'تم تسجيل $key: العين اليسرى ${left.toStringAsFixed(0)}٪ • اليمنى ${right.toStringAsFixed(0)}٪ • الانحراف ${yaw.toStringAsFixed(1)}°.'
      : 'Sampled $key: left ${left.toStringAsFixed(0)}% • right ${right.toStringAsFixed(0)}% • yaw ${yaw.toStringAsFixed(1)}°.';
  String sampleRejectedKey(String key) => isAr
      ? 'تعذّر تسجيل $key: لا يوجد وجه مثبت بقياسات طازجة للعينين.'
      : 'Sample $key rejected: no positioned face with fresh eye measurements.';
  String get movementMeasuredNote => isAr
      ? 'تسجل كل عينة انفتاح العين اليسرى/اليمنى وانحراف الرأس والتوقيت. إزاحة الحاجبين/الفم/الخدين غير متتبعة بعد.'
      : 'Each sample records left/right eye openness, head yaw, and timing. Brow/mouth/cheek displacement is not tracked yet.';
  String expressionSampleLine(
    String key,
    double left,
    double right,
    double yaw,
  ) => isAr
      ? '$key: اليسرى ${left.toStringAsFixed(0)}٪ • اليمنى ${right.toStringAsFixed(0)}٪ • الانحراف ${yaw.toStringAsFixed(1)}°'
      : '$key: L ${left.toStringAsFixed(0)}% • R ${right.toStringAsFixed(0)}% • yaw ${yaw.toStringAsFixed(1)}°';
  String movementMissing(String keys) => isAr
      ? 'المطلوب: رفع الحاجبين • ابتسامة • نفخ الخدين. المفقود: $keys.'
      : 'Needed: brow raise • smile • cheek puff. Missing: $keys.';

  // Stage: Measurements
  String get measureCoverTitle => isAr
      ? 'انظر إلى النقطة المركزية. غطِّ عينك اليسرى. اكشفها. غطِّ اليمنى. اكشفها.'
      : 'Look at the center dot. Cover your left eye. Uncover. Cover your right eye. Uncover.';
  String get measureCoverHint => isAr
      ? 'أبقِ رأسك ثابتاً واتبع التعليمات الظاهرة. تُعرض ثقة التتبع قبل النتائج.'
      : 'Keep your head still and follow the on-screen prompts. Tracking confidence is shown before results.';
  String get measureCoverPractice => isAr
      ? 'تمرين تدريبي فقط: لا يتتبع الهاتف حركة العين هنا. تخطَّ إن أردت — لن يؤثر على النتائج.'
      : 'Practice only: the phone does not track eye movement here. Skip if you like — it will not affect results.';
  String get measureCoverSkip =>
      isAr ? 'تخطَّ تمرين التغطية' : 'Skip cover exercise';
  String get measureCaptureTitle => isAr
      ? 'التقط صورة ثابتة واضحة لتحليل البكسل (الاحمرار والحدة والتعرض).'
      : 'Capture a sharp still for pixel analysis (redness, sharpness, exposure).';
  String get captureAndCheck =>
      isAr ? 'التقط وافحص الجودة' : 'Capture & check quality';
  String get analyzing => isAr ? 'جارٍ التحليل…' : 'Analyzing…';
  String qualityScore(String level, double score) => isAr
      ? 'الجودة: $level (الدرجة ${score.toStringAsFixed(0)}/100)'
      : 'Quality: $level (score ${score.toStringAsFixed(0)}/100)';
  String get lowQualityBanner => isAr
      ? 'تعذّر الحصول على صورة موثوقة. حسّن الإضاءة وضع الهاتف بمستوى العين وحافظ على ثبات وجهك.'
      : 'We couldn\'t obtain a reliable image. Please improve the lighting, move the phone to eye level, and keep your face still.';
  String get lowAckLabel => isAr
      ? 'فهمت — معظم النتائج ستتعذر. المتابعة على أي حال.'
      : 'I understand — most results will be unable. Continue anyway.';
  String get lowAckHint => isAr
      ? 'زر المتابعة معطّل حتى تؤشر على الإقرار أعلاه — الجودة المنخفضة تعني أن معظم النتائج ستتعذر.'
      : 'Continue is disabled until you check the acknowledgment above — low quality means most results will be unable.';
  String get pupilInfoTitle => isAr
      ? 'يستخدم اختبار الحدقة إضاءة غرفة مستقرة ومريحة فقط. لا يُستخدم الفلاش.'
      : 'Pupil test uses stable, comfortable room light only. No flash is used.';
  String get pupilDisabledNote => isAr
      ? 'تبقى وحدة الاستجابة الضوئية معطلة ما لم يتوفر محفز آمن مضبوط. تُسجَّل تعذّر التقييم بدل التخمين.'
      : 'The light-response module stays disabled unless a controlled safe stimulus is available. It reports unable-to-assess rather than guessing.';
  String get surfaceCaptureTitle => isAr
      ? 'يحتاج تحليل السطح لقطة قريبة واضحة بعينين مفتوحتين.'
      : 'Surface analysis needs a sharp close-up with eyes open.';
  String eyelidPitchRefusal(double pitchDeg) => isAr
      ? 'كانت الرأس مائلة للأعلى/للأسفل أثناء القياس (الميل ${pitchDeg.toStringAsFixed(1)}°). يلزم التقاط مباشر بمستوى العين.'
      : 'Head was tilted up/down during measurement (pitch ${pitchDeg.toStringAsFixed(1)}°). Straight-on capture is required.';
  String get eyelidLevelGuidance => isAr
      ? 'حافظ على رأسك مستوياً مع الهاتف وانظر للأمام مباشرة.'
      : 'Keep your head level with the phone and look straight ahead.';
  String get captureCloseUp => isAr ? 'التقط لقطة قريبة' : 'Capture close-up';
  String stillExposureLine(
    double sharp,
    double bright,
    int width,
    int height,
  ) => isAr
      ? 'الحدة ${sharp.toStringAsFixed(1)} • السطوع ${bright.toStringAsFixed(0)} • الأبعاد $width×$height'
      : 'Sharpness ${sharp.toStringAsFixed(1)} • brightness ${bright.toStringAsFixed(0)} • size $width×$height';
  String captureAttemptLine(
    int index,
    int total,
    int width,
    int height,
    String source,
  ) => isAr
      ? 'المحاولة $index من $total • $width×$height • $source'
      : 'Capture $index of $total • $width×$height • $source';
  String captureDeltaLine(double scoreDelta, int resolved, int introduced) =>
      isAr
      ? 'التغير ${scoreDelta >= 0 ? '+' : ''}${scoreDelta.toStringAsFixed(0)} نقطة • تم إصلاح $resolved • جديد $introduced'
      : 'Change ${scoreDelta >= 0 ? '+' : ''}${scoreDelta.toStringAsFixed(0)} points • fixed $resolved • new $introduced';
  String eyeRegionStatsLine(double left, double right, double confidence) =>
      isAr
      ? 'احمرار منطقة العين: اليسرى ${left.toStringAsFixed(3)} • اليمنى ${right.toStringAsFixed(3)} • ثقة اللون ${confidence.toStringAsFixed(2)}'
      : 'Eye-region redness L ${left.toStringAsFixed(3)} • R ${right.toStringAsFixed(3)} • color confidence ${confidence.toStringAsFixed(2)}';
  String get eyeRegionsUnavailable => isAr
      ? 'لون منطقة العين غير متاح: لم تُكتشف معالم العينين.'
      : 'Eye-region color unavailable: eye landmarks were not detected.';

  // Stage: Summary
  String get summaryTitle => isAr ? 'ملخص الفحص' : 'Screening summary';
  String get summaryNote => isAr
      ? 'هذه ملاحظات فحص. لا تثبت تشخيصاً.'
      : 'These are screening observations. They do not establish a diagnosis.';
  String get summaryRepeat => isAr
      ? 'أعد الفحص عند الحاجة واطلب تقييماً متخصصاً عند المناسب — خاصة للتغيرات الجديدة أو المستمرة أو المقلقة.'
      : 'Repeat the screening if necessary and seek professional evaluation when appropriate — especially for new, persistent, or worrying changes.';
  String get summaryMeasuredTitle =>
      isAr ? 'ما تم قياسه فعلاً' : 'What was actually measured';
  String summaryCountLine(int measured, int unable) => isAr
      ? '$measured قياسات • $unable تعذّر تقييمها — مرر للأسفل لرؤية الكل.'
      : '$measured measured • $unable unable-to-assess — scroll to see all.';
  String get summaryUnableTitle =>
      isAr ? 'تعذّر تقييمه — والسبب' : 'Could not be assessed — why';
  String get summaryViewHistory => isAr ? 'عرض السجل' : 'View history';
  String get summaryShareReport => isAr ? 'مشاركة التقرير' : 'Share report';
  String get summaryNewScreening => isAr ? 'فحص جديد' : 'New screening';
  String get summaryFindingAlert => isAr
      ? 'رُصدت علامة تستحق المتابعة. راجع إرشادات الأعراض العاجلة، ولا تعتمد على هذا الفحص وحده.'
      : 'A finding worth following up was observed. Review the urgent-symptom guidance, and do not rely on this screening alone.';
  String reportCoversLine(int n, String from, String to) => isAr
      ? 'يغطي $n اختبارات • من $from إلى $to'
      : 'Covers $n tests • $from → $to';

  // ---------- History ----------
  // Section chrome is localized; stored record content stays canonical
  // English (locale-independent rows).
  String get historyTitle => isAr ? 'سجل الفحوصات' : 'Screening history';
  String get historyEmptyTitle =>
      isAr ? 'لا قياسات بعد.' : 'No measurements yet.';
  String get historyEmptyBody => isAr
      ? 'أجرِ فحصاً أو اختبار نظر. تُخزَّن القياسات فقط — تُحذف الصور الخام افتراضياً.'
      : 'Run a screening or vision test. Only measurements are stored — raw images are deleted by default.';
  String get historyTimelineNote => isAr
      ? 'تُوصف التغيرات بين الفحوصات بأنها «تغير ملاحَظ بين الفحوصات» — وليست تطوراً مرضياً أبداً.'
      : 'Changes between screenings are described as “change observed between screenings” — never as disease progression.';
  String get historyFilterAll => isAr ? 'الكل' : 'All';
  String get historyFilterFindings =>
      isAr ? 'علامات محتملة' : 'Possible findings';
  String get historyFilterUnable => isAr ? 'تعذّر التقييم' : 'Unable to assess';
  String get historySearchHint =>
      isAr ? 'ابحث في القياسات…' : 'Search measurements…';
  String get historyTestAll => isAr ? 'كل الاختبارات' : 'All tests';
  String get reportCopy => isAr ? 'نسخ التقرير' : 'Copy report';
  String get reportCopied =>
      isAr ? 'تم نسخ التقرير إلى الحافظة.' : 'Report copied to clipboard.';
  String get trendsSingleNote => isAr
      ? 'يوجد قياس واحد فقط حتى الآن. كرر نفس الاختبار لمقارنة الفحوصات عبر الزمن.'
      : 'Only one measurement so far. Repeat the same test to compare screenings over time.';
  String get detailTest => isAr ? 'الاختبار' : 'TEST';
  String analyzerLine(String version, String when) =>
      isAr ? 'الخوارزمية $version • $when' : 'Analyzer $version • $when';
  String get detailMeasured => isAr ? 'ما تم قياسه' : 'What we measured';
  String get detailResult => isAr ? 'النتيجة' : 'Result';
  String get detailQuality => isAr ? 'الجودة' : 'Quality';
  String detailQualityLine(String q, String c) => isAr
      ? 'جودة الصورة: $q • الثقة: $c'
      : 'Image quality: $q • Confidence: $c';
  String get detailMayMean => isAr ? 'ما قد يعنيه ذلك' : 'What this may mean';
  String get detailNoAssoc => isAr
      ? 'لا ارتباطات محددة مسجلة لهذه النتيجة.'
      : 'No specific associations recorded for this outcome.';
  String get detailCannotTell =>
      isAr ? 'ما لا يمكن استنتاجه' : 'What it cannot tell';
  String get detailWhyFlagged =>
      isAr ? 'لماذا تم وضع علامة؟' : 'Why was this flagged?';
  String get detailWhenPro => isAr
      ? 'متى تفكر في تقييم متخصص'
      : 'When to consider professional assessment';
  String get detailReferences => isAr ? 'المراجع' : 'References';
  String get learnWhyFinding =>
      isAr ? 'تعلّم لماذا تهم هذه العلامة' : 'Learn why this finding matters';
  String get detailTraceTitle => isAr
      ? 'لماذا هذه النتيجة؟ — سلسلة التتبع'
      : 'Why this result? — traceability';
  String traceAnalyzerLine(String v) =>
      isAr ? 'الخوارزمية: $v' : 'Analyzer: $v';
  String traceEvidenceDbLine(String v) =>
      isAr ? 'قاعدة الأدلة: $v' : 'Evidence DB: $v';
  String traceHardwareLine(String v) => isAr ? 'العتاد: $v' : 'Hardware: $v';
  String traceDeviceLine(String v) => isAr ? 'الجهاز: $v' : 'Device: $v';
  String traceAppLine(String v) =>
      isAr ? 'إصدار التطبيق: $v' : 'App version: $v';
  String traceModelLine(String v) => isAr ? 'النموذج: $v' : 'Model: $v';
  String traceEngineLine(String v) => isAr ? 'محرك المعالجة: $v' : 'Engine: $v';
  String get traceUnrecorded =>
      isAr ? 'غير مسجلة في هذا الصف' : 'not recorded on this row';
  String get traceLegacyRow => isAr
      ? 'سُجّل بإصدار أقدم من التطبيق — الجهاز وإصدار الخوارزمية مجهولان؛ عامِله بحذر أكبر عند المقارنة.'
      : 'Recorded by an older app version — device and analyzer version unknown; treat as less comparable.';
  String get detailNoEvidence => isAr
      ? 'لا يوجد مدخل دليل مرتبط بهذا الاختبار بعد.'
      : 'No evidence entry linked to this test yet.';
  String get findingRequiresTitle =>
      isAr ? 'يتطلب القياس' : 'Measurement requires';
  String get detailSafety => isAr
      ? 'هذه ملاحظة فحص وليست تشخيصاً. لا يستطيع OcuScan تحديد السبب.'
      : 'This is a screening observation, not a diagnosis. OcuScan cannot determine the cause.';
  String evidenceTierLine(String label) =>
      isAr ? 'الدليل: $label' : 'Evidence: $label';
  String tierLabel(String tier) {
    switch (tier) {
      case 'A':
        return isAr ? 'بحث راسخ' : 'Established research';
      case 'B':
        return isAr
            ? 'مدعوم بحثياً، بتحقق محدود'
            : 'Research-supported, limited validation';
      default:
        return isAr ? 'تجريبي' : 'Experimental';
    }
  }

  String monthName(int m) {
    if (isAr) {
      const names = [
        'يناير',
        'فبراير',
        'مارس',
        'أبريل',
        'مايو',
        'يونيو',
        'يوليو',
        'أغسطس',
        'سبتمبر',
        'أكتوبر',
        'نوفمبر',
        'ديسمبر',
      ];
      return (m >= 1 && m <= 12) ? names[m - 1] : '';
    }
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return (m >= 1 && m <= 12) ? names[m - 1] : '';
  }

  // ---------- Learn ----------
  // Finding names show Arabic term + English medical term (evidence DB
  // carries nameAr); descriptions stay canonical English to preserve
  // exact scientific meaning.
  String get learnTitle => isAr ? 'تعلّم' : 'Learn';
  String get learnIntro => isAr
      ? 'كل اختبار يقيس شيئاً محدداً وله حدود. المحتوى التعليمي من قاعدة معرفة محلية منتقاة — لا يُولَّد لحظياً أبداً.'
      : 'Each test measures something specific and has limits. Educational content comes from a curated local knowledge base — never generated on the fly.';
  String get learnMeasuresTitle =>
      isAr ? 'ما يقيسه OcuScan' : 'What OcuScan measures';
  String get learnCatalogTitle => isAr ? 'كتالوج الفحص' : 'Screening catalog';
  String get learnCatalogBody => isAr
      ? 'كل هدف مصنف حسب حالة التنفيذ — ولا يُعرض أبداً كحالات مشخصة.'
      : 'Every target is classified by build status — never presented as diagnosed conditions.';
  String get learnEducationTitle => isAr ? 'تثقيف عام' : 'General education';
  String targetsCount(int n) => isAr ? '$n أهداف' : '$n targets';
  String tierStatusLine(
    String ar,
    String tier,
    String impl,
    String shortStatus,
  ) => isAr
      ? '$ar • الدرجة $tier • $shortStatus'
      : '$ar • Tier $tier • $shortStatus';
  String tierCategoryLine(String tier, String category) =>
      isAr ? 'الدرجة $tier • $category' : 'Tier $tier • $category';
  String shortStatus(String s) {
    switch (s) {
      case 'CURRENT':
        return isAr ? 'متاح' : 'available';
      case 'EXPERIMENTAL':
        return isAr
            ? 'تجريبي — غير متحقق سريرياً'
            : 'Experimental — not clinically validated';
      case 'FUTURE':
        return isAr ? 'بحث مستقبلي' : 'future research';
      default:
        return isAr
            ? 'غير مناسب للعتاد الحالي'
            : 'not suitable for current hardware';
    }
  }

  String longStatus(String s) {
    switch (s) {
      case 'CURRENT':
        return isAr
            ? 'حالي — متاح في هذه النسخة'
            : 'CURRENT — available in this build';
      case 'EXPERIMENTAL':
        return isAr
            ? 'تجريبي — غير متحقق سريرياً'
            : 'EXPERIMENTAL — not clinically validated';
      case 'FUTURE':
        return isAr ? 'مستقبلي — غير منفذ' : 'FUTURE — not implemented';
      default:
        return isAr
            ? 'غير مناسب للعتاد الحالي'
            : 'NOT SUITABLE FOR CURRENT HARDWARE';
    }
  }

  String get findingAssocTitle =>
      isAr ? 'ارتباطات محتملة' : 'Possible associations';
  String get findingNotMeanTitle =>
      isAr ? 'ما لا يعنيه ذلك' : 'What it does NOT mean';
  String get findingNotMeanBody => isAr
      ? 'علامة الفحص ليست تشخيصاً ولا تحدد سبباً.'
      : 'A screening finding is not a diagnosis and does not identify a cause.';
  String cannotConcludeLine(String x) =>
      isAr ? '• لا يمكن استنتاج: $x' : '• Cannot conclude: $x';
  String get findingLimitTitle => isAr ? 'المحددات' : 'Limitations';
  String get findingActionTitle =>
      isAr ? 'الخطوة التالية الموصى بها' : 'Recommended next step';
  String get findingEmergencyTitle =>
      isAr ? 'علامات تحذيرية طارئة' : 'Emergency warning signs';
  String get learnReferencesBtn => isAr ? 'المراجع' : 'References';
  String get learnMethodologyBtn => isAr ? 'المنهجية' : 'Methodology';
  String get learnRetinalBtn =>
      isAr ? 'تصوير الشبكية المستقبلي' : 'Future Retinal Imaging';
  String get learnCalibrationBtn =>
      isAr ? 'حالة معايرة الألوان' : 'Color Calibration Status';

  // ---------- References ----------
  String get referencesTitle => isAr ? 'المراجع' : 'References';
  String get referencesBanner => isAr
      ? 'تُقدَّم المراجع كمصادر علمية وتقنية للنموذج الأولي البحثي ولا تعني اعتماداً سريرياً لـ OcuScan.'
      : 'References are provided as scientific and technical sources for the research prototype and do not imply clinical endorsement of OcuScan.';
  String get referencesVsTitle => isAr
      ? 'الدليل المنشور مقابل دليل OcuScan'
      : 'Published evidence vs OcuScan evidence';
  String get referencesVsBody => isAr
      ? 'الدراسة المنشورة: أُنتجت بالعتاد والسكان والمنهجية المذكورة؛ والأرقام تخص تلك الدراسة. OcuScan: غير متحقق سريرياً بعد. لا تعامل الأداء المنشور أبداً كأداء OcuScan.'
      : 'Published study: produced with the listed hardware, population, and methods; numbers belong to that study. '
            'OcuScan: not yet clinically validated. Never treat published performance as OcuScan performance.';
  String get referencesSearch => isAr
      ? 'ابحث بالمؤلفين أو العنوان أو المجلة'
      : 'Search authors, title, journal';
  String get referencesFilterAll => isAr ? 'الكل' : 'All';
  String dbLine(String v, String reviewed, int n) => isAr
      ? 'قاعدة الأدلة الإصدار $v • روجعت $reviewed • $n مصادر'
      : 'Evidence DB v$v • reviewed $reviewed • $n sources';
  String usedForLine(String v) => isAr ? 'يُستخدم في: $v' : 'Used for: $v';
  String citedByLine(int n) => isAr
      ? 'مُستشهَد به في $n من مداخل الأدلة'
      : 'Cited by $n evidence entr${n == 1 ? 'y' : 'ies'}';
  String evidenceTypeLine(String v) =>
      isAr ? 'نوع الدليل: $v' : 'Evidence type: $v';
  String get referencesEmpty =>
      isAr ? 'جرّب مصطلح بحث آخر.' : 'Try another search term.';
  String refAccessDate(String d) => isAr ? 'تاريخ الوصول: $d' : 'Accessed: $d';
  String get refPeerBadge => isAr ? 'مراجَع من الأقران' : 'Peer-reviewed';
  String get refOverviewBadge => isAr
      ? 'نظرة عامة/إرشادات — ليست تجربة سريرية'
      : 'Overview/guidance — not a clinical trial';
  String refCategory(String code) {
    const en = {
      'ophthalmology': 'Ophthalmology',
      'vision_testing': 'Vision testing',
      'facial_analysis': 'Facial analysis',
      'neurology': 'Neurology',
      'retinal_imaging': 'Retinal imaging',
      'ai_safety': 'AI safety',
      'privacy': 'Privacy',
      'regulatory': 'Regulatory',
    };
    const ar = {
      'ophthalmology': 'طب العيون',
      'vision_testing': 'اختبارات النظر',
      'facial_analysis': 'تحليل الوجه',
      'neurology': 'الأعصاب',
      'retinal_imaging': 'تصوير الشبكية',
      'ai_safety': 'سلامة الذكاء الاصطناعي',
      'privacy': 'الخصوصية',
      'regulatory': 'التنظيمات',
    };
    final map = isAr ? ar : en;
    return map[code] ?? code;
  }

  /// Filter chip labels (canonical codes underneath).
  String refFilterLabel(String filter) {
    switch (filter) {
      case 'All':
        return referencesFilterAll;
      case 'Ophthalmology':
        return refCategory('ophthalmology');
      case 'Vision testing':
        return refCategory('vision_testing');
      case 'Facial analysis':
        return refCategory('facial_analysis');
      case 'Neurology':
        return refCategory('neurology');
      case 'Retinal imaging':
        return refCategory('retinal_imaging');
      case 'AI safety':
        return refCategory('ai_safety');
      case 'Privacy':
        return refCategory('privacy');
      case 'Regulatory':
        return refCategory('regulatory');
      default:
        return filter;
    }
  }

  // ---------- About ----------
  String get aboutSafetyBanner => isAr
      ? 'OcuScan ليس بديلاً عن الرعاية الطبية المتخصصة. نموذج أولي للفحص والتوعية — وليس جهازاً تشخيصياً.'
      : 'OcuScan is not a replacement for professional medical care. Educational/research screening prototype — not a diagnostic medical device.';
  List<String> get pipelineStages => isAr
      ? ['الكاميرا', 'بوابة الجودة', 'الخوارزمية', 'النتيجة']
      : ['Camera', 'QualityGate', 'Analyzer', 'Result'];
  String get pipelineCaption => isAr
      ? 'الجودة المنخفضة تمنع التحليل — الرفض نتيجة مصممة.'
      : 'Low quality vetoes analysis — refusal is a designed outcome.';

  // ---------- Emergency ----------
  String get emergencyCheckTitle => isAr ? 'فحص السلامة' : 'Safety check';
  String get emergencyWhenNot =>
      isAr ? 'متى لا تعتمد على OcuScan' : 'When not to rely on OcuScan';
  String get emergencyIntro => isAr
      ? 'OcuScan ليس أداة استبعاد طارئة. إذا عانيت أي عرض مفاجئ أدناه فلا تفحص — اطلب رعاية متخصصة أو طارئة.'
      : 'OcuScan is not an emergency exclusion tool. If you experience any sudden symptom below, '
            'do not screen — seek urgent professional or emergency care.';
  String get emergencyIfSudden =>
      isAr ? 'إذا عانيت فجأة:' : 'If you experience sudden:';
  List<String> get emergencySymptoms => isAr
      ? [
          'فقدان مفاجئ للنظر أو تغير مفاجئ فيه',
          'ألم شديد في العين',
          'ضعف مفاجئ في الوجه',
          'صعوبة مفاجئة في الكلام',
          'صداع شديد مفاجئ',
          'ازدواج نظر شديد جديد',
          'إصابة شديدة في العين أو رضّة',
          'تعرض العين لمواد كيميائية',
        ]
      : [
          'Sudden vision loss or sudden vision change',
          'Severe eye pain',
          'Sudden facial weakness',
          'Sudden trouble speaking',
          'Sudden severe headache',
          'New severe double vision',
          'Severe eye injury or trauma',
          'Chemical exposure to the eye',
        ];
  String get emergencyDoNotRely => isAr
      ? 'لا تعتمد على OcuScan في هذه الحالة.'
      : 'Do not rely on OcuScan for this situation.';
  String get emergencySeekCare => isAr
      ? 'اطلب الرعاية الطارئة فوراً (رقم الطوارئ المحلي أو أقرب قسم طوارئ). '
            'عند التعرض الكيميائي: اشطف بماء نظيف إذا نُصح بذلك محلياً واطلب الرعاية فوراً. '
            'هذا التطبيق لا يشخص الحالة الطارئة.'
      : 'Seek emergency care promptly (local emergency number or nearest emergency department). '
            'For chemical exposure: rinse with clean water if advised locally and seek care immediately. '
            'This app does not diagnose the emergency condition.';
  String get emergencyNoSymptom => isAr
      ? 'لم يُحدد عرض عاجل. يمكنك المتابعة إلى الفحص أو مراجعة «تعلّم» للاطلاع على المحددات.'
      : 'No urgent symptom selected. You may continue with screening, or review Learn for limitations.';

  // ---------- Home dashboard ----------
  String get homeKicker => isAr ? 'أوكوسكان' : 'OCUSCAN';
  String get homeSubKicker =>
      isAr ? 'فحص العين والنظر' : 'Eye + Vision Screening';
  String get homeLatestTitle => isAr ? 'آخر فحص لك' : 'Your latest screening';
  String homeTestsLine(int n) => isAr ? '$n اختبارات' : '$n tests';
  String homeFindingsLine(int n) => isAr
      ? (n == 0 ? 'لا علامات تستحق المتابعة' : '$n علامات تستحق المتابعة')
      : (n == 0 ? 'No findings to follow up' : '$n findings to follow up');
  String get homeVisionTitle => isAr ? 'مختبر النظر' : 'Vision Lab';
  String get homeVisionBody =>
      isAr ? 'اختبر وظيفتك البصرية' : 'Test your visual function';
  String get homeVisionOpen => isAr ? 'افتح مختبر النظر' : 'Open Vision Lab';
  String get homeHowTitle => isAr ? 'كيف يعمل OcuScan' : 'How OcuScan works';
  String get homeHowBody => isAr
      ? 'شرح قصير: كاميرا ← فحص جودة ← قياس ← نتيجة مع حدود معلنة.'
      : 'A short explanation: camera → quality check → measurement → result with stated limits.';
  String get homeHowOpen => isAr ? 'اقرأ المنهجية' : 'Read the methodology';
  String get homeLearnTitle => isAr ? 'تعلّم' : 'LEARN';
  String get homeLearnBody =>
      isAr ? 'افهم ما تقيسه الاختبارات' : 'Understand what the tests measure';
  String get homeLearnOpen => isAr ? 'افتح التعلّم' : 'Open Learn';
  String get pillCamera => isAr ? 'الكاميرا' : 'CAMERA';
  String get pillLighting => isAr ? 'الإضاءة' : 'LIGHTING';
  String get pillFace => isAr ? 'الوجه' : 'FACE';
  String get pillEyes => isAr ? 'العينان' : 'EYES';
  String get pillLock => isAr ? 'التثبيت' : 'LOCK';
  String get pillAnalysis => isAr ? 'التحليل' : 'ANALYSIS';
  String get homeRecentTitle => isAr ? 'الأخيرة' : 'Recent';

  // ---------- Capability explorer (§41-42) ----------
  String get capabilitiesTitle =>
      isAr ? 'ماذا يستطيع OcuScan فحصه؟' : 'What can OcuScan screen?';
  String get capabilitiesBody => isAr
      ? 'دليل القدرات: ما يُقاس، وبأي عتاد، وبأي حالة — وليست قائمة أمراض.'
      : 'Capability directory: what is measured, with what hardware, at what status — never a disease list.';
  String get capabilitiesSearch =>
      isAr ? 'ابحث في القدرات' : 'Search capabilities';
  String get capabilitiesFilterAll => isAr ? 'الكل' : 'All';
  String capFilterLabel(String f) {
    switch (f) {
      case 'All':
        return capabilitiesFilterAll;
      case 'Available':
        return isAr ? 'متاح الآن' : 'Available now';
      case 'Face':
        return refCategory('facial_analysis');
      case 'Eye':
        return isAr ? 'العين' : 'Eye';
      case 'Vision':
        return refCategory('vision_testing');
      case 'Retina':
        return refCategory('retinal_imaging');
      case 'Experimental':
        return isAr ? 'تجريبي' : 'Experimental';
      case 'Future':
        return isAr ? 'مستقبلي' : 'Future';
      default:
        return f;
    }
  }

  String capabilitiesCount(int n) => isAr ? '$n قدرة' : '$n capabilities';
  String get capabilitiesEmpty => isAr
      ? 'لا قدرات مطابقة. جرّب مصطلحاً آخر.'
      : 'No matching capabilities. Try another term.';
  String get capWhatMeasured => isAr ? 'ما يُقاس' : 'What is measured';
  String get capHardware => isAr ? 'العتاد المطلوب' : 'Required hardware';
  String get capStatus => isAr ? 'الحالة الحالية' : 'Current status';
  String get capMeaning => isAr ? 'ماذا تعني النتيجة' : 'What the result means';
  String get capCannot => isAr ? 'ما لا تخبرك به' : 'What it cannot tell you';
  String get capEvidence => isAr ? 'الدليل' : 'Evidence';
  String get capValidation => isAr ? 'حالة التحقق' : 'Validation status';
  String get capModality => isAr ? 'الوسيلة' : 'Modality';
  String get capRisk => isAr ? 'مستوى الخطر' : 'Risk level';
  String get capReferences => isAr ? 'المراجع' : 'References';
  String get capNoRefs => isAr
      ? 'لا سوابق منشورة منتقاة لهذا الاتجاه بعد.'
      : 'No curated published precedent for this direction yet.';
  String capStatusLine(String impl, String valid) =>
      isAr ? '$impl • التحقق: $valid' : '$impl • validation: $valid';
  String get capHomeTitle =>
      isAr ? 'ماذا يستطيع OcuScan فحصه؟' : 'What can OcuScan screen?';
  String get capHomeBody => isAr
      ? 'استعرض القدرات والأدلة والحدود قبل الفحص.'
      : 'Browse capabilities, evidence, and limits before screening.';
  String get capHomeOpen => isAr ? 'افتح الدليل' : 'Open directory';

  // ---------- Person profiles (local-only labels) ----------
  String get profileSelf => isAr ? 'نفسي' : 'Self';
  String get profilesTitle => isAr ? 'الأشخاص' : 'People';
  String get profilesBody => isAr
      ? 'تابع القياسات لعدة أشخاص (مثال: طفلان). الأسماء تسميات محلية فقط — ليست هويات ولا تُرفع أبداً.'
      : 'Track measurements for more than one person (e.g. two children). Names are local labels only — never identities, never uploaded.';
  String get profileNameHint =>
      isAr ? 'الاسم (مثال: ليلى)' : 'Name (e.g. Layla)';
  String get profileAdd => isAr ? 'إضافة شخص' : 'Add person';
  String get profileDelete => isAr ? 'حذف' : 'Delete';
  String get profileDeleteTitle => isAr ? 'حذف الشخص؟' : 'Delete person?';
  String profileDeleteBody(String name) => isAr
      ? 'سيؤدي هذا إلى حذف $name وجميع قياساته المحلية. لا يمكن التراجع.'
      : 'This deletes $name and all of their local measurements. This cannot be undone.';
  String profileName(String id, String stored) =>
      id == 'self' ? profileSelf : stored;
  String profileLine(String name) =>
      isAr ? 'الملف: ${_iso(name)}' : 'Profile: $name';
  String get profileChangeBtn => isAr ? 'تغيير الشخص' : 'Change person';
  String get profileRename => isAr ? 'إعادة تسمية' : 'Rename';
  String profileMeasurements(int n) => isAr ? '$n قياسات' : '$n measurements';

  // ---------- Trends over time ----------
  String get trendsTitle => isAr ? 'الاتجاهات عبر الزمن' : 'Trends over time';
  String get trendsBody => isAr
      ? 'قارن نفس الاختبار عبر الزيارات. تُعرض القياسات كنصوص مسجلة — بدون رسوم مخترعة للدقة.'
      : 'Compare the same test across visits. Measurements show as recorded text — no invented precision charts.';
  String get trendsPickTest => isAr ? 'اختر الاختبار' : 'Pick a test';
  String get trendsNoData => isAr
      ? 'لا قياسات لهذا الاختبار بعد.'
      : 'No measurements for this test yet.';
  String trendsCountLine(int n) => isAr ? '$n قياسات' : '$n measurements';
  String get trendsComparable =>
      isAr ? 'ظروف قابلة للمقارنة' : 'Comparable conditions';
  String get trendsCaution => isAr
      ? 'ظروف مختلفة — قارن بحذر'
      : 'Different conditions — compare cautiously';
  String get trendsChangeNote => isAr
      ? 'التغيرات الموصوفة هي تغيرات ملاحَظ بين الفحوصات — وليست تطوراً مرضياً أبداً.'
      : 'Described changes are observed changes between screenings — never disease progression.';
  String trendsReason(String code) {
    switch (code) {
      case 'quality':
        return isAr ? 'جودة صورة مختلفة' : 'Different image quality';
      case 'calibration':
        return isAr ? 'حالة معايرة مختلفة' : 'Different calibration state';
      case 'eye':
        return isAr
            ? 'عين مختلفة (أو غير مسماة)'
            : 'Different (or unnamed) eye';
      case 'setup':
        return isAr
            ? 'جهاز أو عتاد أو إصدار خوارزمية مختلف'
            : 'Different device, hardware, or analyzer version';
      default:
        return isAr ? 'ظروف مختلفة' : 'Different conditions';
    }
  }

  // ---------- Doctor report (human-readable summary to share) ----------
  String get reportTitle =>
      isAr ? 'ملخص الفحص للمشاركة' : 'Screening summary report';
  String reportGenerated(String date) =>
      isAr ? 'أُنشئ: $date' : 'Generated: $date';
  String reportProfile(String name) => isAr ? 'الملف: $name' : 'Profile: $name';
  String reportVersions(String app, String evidence) => isAr
      ? 'إصدار التطبيق: $app • قاعدة الأدلة: $evidence'
      : 'App version: $app • Evidence DB: $evidence';
  String get reportEmpty =>
      isAr ? 'لا قياسات لمشاركتها بعد.' : 'No measurements to share yet.';
  String reportLoadFailed(String detail) => isAr
      ? 'تعذّر بناء التقرير: $detail. أعد المحاولة — بياناتك محفوظة ولم تُفقد.'
      : 'Could not build the report: $detail. Retry — your data is stored, not lost.';
  String get reportShare => isAr ? 'مشاركة التقرير' : 'Share report';
  String get reportLatestTitle =>
      isAr ? 'أحدث نتيجة لكل اختبار' : 'Latest result per test';
  String reportUnableTitle(int n) =>
      isAr ? 'تعذّر التقييم ($n)' : 'Unable to assess ($n)';
  String reportRowDate(String date) => isAr ? 'التاريخ: $date' : 'Date: $date';
  String get reportFooterNote => isAr
      ? 'هذا ملخص ملاحظات فحص — وليس تشخيصاً. أحضره معك عند التقييم المتخصص مع ذكر ظروف كل اختبار.'
      : 'This is a screening-observation summary — not a diagnosis. Bring it to a professional evaluation along with each test\u2019s conditions.';
  String reportTraceLine(
    String hardware,
    String device,
    String algorithm,
    String evidence, {
    String model = '',
    String engine = '',
  }) {
    String v(String x) => x.isEmpty ? traceUnrecorded : x;
    // Model/engine append only when recorded (§9 trace); old rows keep
    // the original four-field line instead of invented blanks.
    final extra = (model.isEmpty && engine.isEmpty)
        ? ''
        : (isAr
              ? ' • النموذج ${v(model)} • المحرك ${v(engine)}'
              : ' • model ${v(model)} • engine ${v(engine)}');
    return isAr
        ? 'التتبع: العتاد ${v(hardware)} • الجهاز ${v(device)} • الخوارزمية ${v(algorithm)} • الأدلة ${v(evidence)}$extra'
        : 'Trace: hardware ${v(hardware)} • device ${v(device)} • analyzer ${v(algorithm)} • evidence ${v(evidence)}$extra';
  }

  String get homeResearchNote =>
      isAr ? 'قياسات فقط، محلياً' : 'measurements only, local';
  String get loadingEvidence =>
      isAr ? 'جارٍ تحميل الأدلة…' : 'Loading evidence…';
  String get fontCredit => isAr
      ? 'الخط: Tajawal (رخصة SIL المفتوحة للخطوط) — يعمل دون اتصال.'
      : 'Typeface: Tajawal (SIL Open Font License) — works offline.';

  // ---------- Camera pipeline UI (v0.3.3) ----------
  // ML detector health (MlHealth state machine: healthy/degraded/down).
  // Canonical codes stay English; labels are localized. A broken
  // detector never reads as "no face".
  String get mlHealthHealthy => isAr ? 'الكاشف سليم' : 'Detector healthy';
  String get mlHealthDegraded => isAr ? 'الكاشف متدهور' : 'Detector degraded';
  String get mlHealthDown => isAr ? 'الكاشف متوقف' : 'Detector down';
  String mlHealthLabel(String state) {
    switch (state) {
      case 'degraded':
        return mlHealthDegraded;
      case 'down':
        return mlHealthDown;
      default:
        return mlHealthHealthy;
    }
  }

  String mlHealthDetailLine(int errors, int processed) => isAr
      ? 'أخطاء متتالية: $errors • معالَجة: $processed'
      : 'Consecutive errors: $errors • processed: $processed';
  // Staged truth: camera started ≠ face detected ≠ eyes detected ≠ locked.
  String get camStepPermission => isAr ? 'الإذن' : 'Permission';
  String get camStepCamera => isAr ? 'الكاميرا' : 'Camera';
  String get camStepPreview => isAr ? 'المعاينة' : 'Preview';
  String get camStepEyeDetection => isAr ? 'رصد العين' : 'Eye detection';
  String get camSourceLabel => isAr ? 'الكاميرا' : 'Camera';
  String get camSourceFront => isAr ? 'أمامية' : 'Front';
  String get camSourceRear => isAr ? 'خلفية' : 'Rear';
  String get camSourceBest => isAr ? 'الأنسب للاختبار' : 'Best for this test';
  String camRecommended(String reason) => isAr
      ? 'موصى بها لهذا الاختبار: $reason'
      : 'Recommended for this test: $reason';
  String get switchingCamera =>
      isAr ? 'جارٍ تبديل الكاميرا…' : 'Switching camera…';
  String get preparingCamera =>
      isAr ? 'جارٍ تجهيز الكاميرا' : 'Preparing camera';
  String get cameraReady => isAr ? 'الكاميرا جاهزة' : 'Camera ready';
  String get streamTimeoutTitle =>
      isAr ? 'تعذّر بدء بث الكاميرا.' : 'We couldn\'t start the camera stream.';
  String get streamTimeoutBody => isAr
      ? 'بدأت الكاميرا لكن لم تصل أول لقطة. قد يكون ذلك إذناً معلقاً أو كاميرا مشغولة بتطبيق آخر.'
      : 'The camera started but no first frame arrived. This can be a pending permission or a camera held by another app.';
  String get retryAnalysis => isAr ? 'إعادة المحاولة' : 'Retry';
  String get permissionPanelTitle =>
      isAr ? 'إذن الكاميرا مطلوب' : 'Camera permission needed';
  String get permissionPanelBody => isAr
      ? 'لا يستطيع OcuScan رؤية عينيك دون إذن الكاميرا. امنح الإذن للمتابعة، أو افتح إعدادات النظام إذا كان الوصول محظوراً.'
      : 'OcuScan cannot see your eyes without camera access. Grant permission to continue, or open system settings if access was blocked.';
  String get retryPermission => isAr ? 'إعادة طلب الإذن' : 'Retry permission';
  String watchdogFramesLine(int n) =>
      isAr ? 'اللقطات المستلمة: $n' : 'Frames received: $n';
  String get watchdogRetryNote => isAr
      ? 'ستجرب إعادة المحاولة إعداداً بديلاً للكاميرا.'
      : 'Retrying tries an alternate camera configuration.';
  String get streamStalledBody => isAr
      ? 'تصل اللقطات لكن تعذّر تحليل أي منها بعد. التفاصيل التقنية أدناه تحدد السبب الدقيق.'
      : 'Frames are arriving but none could be analyzed yet. The technical details below name the exact cause.';
  String get exportErrorsBtn => isAr ? 'تصدير الأخطاء' : 'Export errors';
  String get errorsExported => isAr
      ? 'تم تصدير تقرير الأخطاء — شاركه مع المطوّر.'
      : 'Error report exported — share it with the developer.';
  String get exportFailed => isAr ? 'تعذّر التصدير.' : 'Export failed.';
  String get exportErrorsShareText => isAr
      ? 'تقرير أخطاء OcuScan للتشخيص (بدون صور وبدون هوية).'
      : 'OcuScan error report for diagnosis (no images, no identity).';
  String get techDetails => isAr ? 'التفاصيل التقنية' : 'Technical details';
  String techStageLine(String v) => isAr ? 'المرحلة: $v' : 'Stage: $v';
  String techFramesLine(int rx, int ok) => isAr
      ? 'اللقطات: $rx مستلمة • $ok محللة'
      : 'Frames: $rx received • $ok analyzed';
  String techFormatLine(
    String fmt,
    int planes,
    int stride,
    int rot,
    int w,
    int h,
    String lens,
  ) => isAr
      ? 'اللقطة: $fmt • $w×$h • $planes مستويات • خطوة $stride • دوران $rot° • بايت [$lens]'
      : 'Frame: $fmt • ${w}x$h • $planes planes • stride $stride • rotation $rot° • bytes [$lens]';
  String techErrorLine(String e) => isAr ? 'آخر خطأ: $e' : 'Last error: $e';
  String get techErrorNone =>
      isAr ? 'آخر خطأ: لا يوجد مسجل' : 'Last error: none recorded';
  String get restartCameraBtn =>
      isAr ? 'إعادة تشغيل الكاميرا' : 'Restart camera';
  String get cameraHelpBtn => isAr ? 'مساعدة الكاميرا' : 'Camera help';
  String get camRationaleTitle => isAr
      ? 'يحتاج OcuScan إلى الكاميرا لرؤية عينيك أثناء الفحص.'
      : 'OcuScan needs camera access to see your eyes for screening.';
  String get camRationaleBody => isAr
      ? 'يعمل التحليل على الجهاز نفسه. تُحذف الصور الأصلية افتراضياً.'
      : 'Analysis runs on-device. Raw images are deleted by default.';
  String get camRationaleContinue => isAr ? 'متابعة' : 'Continue';
  String get compatCopy => isAr ? 'نسخ الملخص' : 'Copy summary';
  String get compatCopied => isAr ? 'تم نسخ الملخص.' : 'Summary copied.';
  String get compatCopyFailed => isAr
      ? 'تعذّر نسخ الملخص على هذا الجهاز.'
      : 'Could not copy the summary on this device.';
  String get analysisTroubleTitle =>
      isAr ? 'التحليل غير متاح' : 'Analysis unavailable';
  String get analysisTroubleBody => isAr
      ? 'فشل الرصد التلقائي للعين على هذا الهاتف. المعاينة تعمل — أعد المحاولة، أو استخدم لقطة ثابتة بدلاً من ذلك.'
      : 'Automatic eye detection failed on this phone. The camera preview still works — retry, or use a still capture instead.';
  String get recoveryTitle => isAr
      ? 'نواجه صعوبة في تحديد عينيك.'
      : 'We\'re having trouble locating your eyes.';
  String get recoveryAutoNote => isAr
      ? 'أُعيد تشغيل التتبع تلقائياً — واصل الثبات.'
      : 'Tracking restarted automatically — keep holding still.';
  String get recoveryTryAgain => isAr ? 'حاول مجدداً' : 'Try again';
  String get switchCameraBtn => isAr ? 'تبديل الكاميرا' : 'Switch camera';
  String get recoveryImproveLight => isAr ? 'حسّن الإضاءة' : 'Improve lighting';
  String get recoveryReposition => isAr ? 'أعد وضع الهاتف' : 'Reposition phone';
  // The button routes to a still capture (not onward), so the label
  // names the still — "continue" was a behavior mismatch (audit).
  String get recoveryContinueUnable =>
      isAr ? 'التقط لقطة ثابتة بدلاً من ذلك' : 'Take a still instead';
  String get recoveryContinueNote => isAr
      ? 'ستُسجَّل القياسات التي تحتاج تثبيت العين كتعذّر تقييم.'
      : 'Measurements needing eye lock will record as unable-to-assess.';
  String lockCountLine(int done, int total) => isAr
      ? 'تم رصد العينين — اثبت: $done من $total'
      : 'Eyes detected — hold still: $done of $total';
  String get lockInterrupted => isAr
      ? 'انقطع التثبيت — أعد الثبات'
      : 'Lock interrupted — hold still again';
  String get rearAssistTitle => isAr ? 'الكاميرا الخلفية' : 'REAR CAMERA';
  String get rearAssistBody => isAr
      ? 'ضع الهاتف على سطح ثابت أو اطلب مساعدة شخص. تحرك ببطء حتى يتحول مؤشر وضع العين إلى الأخضر.'
      : 'Place the phone on a stable surface or have someone assist you. Move slowly until the eye-position indicator turns green.';
  String get rearMirrorNote => isAr
      ? 'لا يمكنك رؤية الشاشة وأنت تواجه الكاميرا: قف أمام مرآة أو اطلب من مساعد قراءة التعليمات الكبيرة بصوت عالٍ.'
      : 'You cannot see the screen while facing the camera: stand before a mirror or have a helper read the large instructions aloud.';
  String get rearHelperNote => isAr
      ? 'الفحص الذاتي بالكاميرا الخلفية أصعب وليس مكافئاً — الأفضل أن يمسك شخص آخر الهاتف.'
      : 'Self-testing with the rear camera is harder and not equivalent — best if someone else holds the phone.';
  String get rearTooFar => isAr ? 'بعيد جداً' : 'TOO FAR';
  String get rearTooClose => isAr ? 'قريب جداً' : 'TOO CLOSE';
  String get rearGood => isAr ? 'الوضع جيد' : 'POSITION GOOD';
  String get rearMoveCloser => isAr ? 'اقترب ←' : 'Move closer →';
  String get rearMoveAway => isAr ? '→ ابتعد' : '← Move away';
  String get rearMoveLeft => isAr ? 'تحرك يساراً' : 'Move left';
  String get rearMoveRight => isAr ? 'تحرك يميناً' : 'Move right';
  String get rearMoveUp => isAr ? 'تحرك لأعلى' : 'Move up';
  String get rearMoveDown => isAr ? 'تحرك لأسفل' : 'Move down';
  String get rearNoFace =>
      isAr ? 'لا وجه في الإطار بعد' : 'No face in frame yet';

  // ---------- Camera help screen ----------
  String get camHelpTitle =>
      isAr ? 'مساعدة إعداد الكاميرا' : 'Camera Setup Help';
  String get camHelpLightTitle => isAr ? 'الإضاءة' : 'Lighting';
  String get camHelpLightBody => isAr
      ? 'استخدم إضاءة داخلية متساوية وواجه مصدر الضوء. تجنب الإضاءة الخلفية القوية.'
      : 'Use even indoor lighting and face the light source. Avoid strong backlight.';
  String get camHelpDistanceTitle => isAr ? 'المسافة' : 'Distance';
  String get camHelpDistanceBody => isAr
      ? 'تحرك حتى يشير الدليل إلى الوضع الصحيح — قريباً جداً أو بعيداً جداً يفشل التحديد.'
      : 'Move until the guide indicates correct position — too close or too far fails localization.';
  String get camHelpGlassesTitle => isAr ? 'النظارات' : 'Glasses';
  String get camHelpGlassesBody => isAr
      ? 'قلل الانعكاسات القوية على العدسات؛ أمل رأسك قليلاً بعيداً عن مصدر الضوء.'
      : 'Reduce strong reflections on lenses; tilt your head slightly away from the light source.';
  String get camHelpPositionTitle => isAr ? 'الوضع' : 'Position';
  String get camHelpPositionBody => isAr
      ? 'أبقِ الهاتف بمستوى العين ووسّط وجهك داخل الدليل.'
      : 'Keep the phone at eye level and center your face inside the guide.';
  String get camHelpMovementTitle => isAr ? 'الحركة' : 'Movement';
  String get camHelpMovementBody => isAr
      ? 'اثبت لحظة أثناء التثبيت؛ الحركة المفاجئة تقطع التتبع.'
      : 'Hold still briefly during lock-on; sudden motion breaks tracking.';
  String get camHelpBackgroundTitle => isAr ? 'الخلفية' : 'Background';
  String get camHelpBackgroundBody => isAr
      ? 'تجنب الإضاءة الخلفية القوية والنوافذ الساطعة خلفك.'
      : 'Avoid strong backlight and bright windows behind you.';
  String get camHelpFrontTitle =>
      isAr ? 'لماذا الكاميرا الأمامية؟' : 'Why use the front camera?';
  String get camHelpFrontBody => isAr
      ? 'تتيح لك الكاميرا الأمامية رؤية نفسك أثناء ضبط وجهك وعينيك.'
      : 'The front camera lets you see yourself while positioning your face and eyes.';
  String get camHelpRearTitle =>
      isAr ? 'لماذا الكاميرا الخلفية؟' : 'Why use the rear camera?';
  String get camHelpRearBody => isAr
      ? 'قد توفر كاميرات بعض الهواتف الخلفية صوراً أكثر تفصيلاً. يعتمد ذلك على جهازك.'
      : 'Some phones have higher-quality rear cameras that may provide more detailed images. This depends on your device.';
  String get camHelpWhichTitle =>
      isAr ? 'أي واحدة أستخدم؟' : 'Which one should I use?';
  String get camHelpWhichBody => isAr
      ? 'قد يوصي OcuScan بكاميرا بناءً على متطلبات الاختبار الحالي.'
      : 'OcuScan may recommend a camera based on the requirements of the current test.';

  // ---------- Snapshot fallback scan (consumer-facing) ----------
  String get snapTitle => isAr ? 'فحص باللقطة' : 'SNAPSHOT SCAN';
  String get snapBody => isAr
      ? 'التحليل الحي غير متاح هنا. وجّه الكاميرا نحو وجهك والتقط لقطة ثابتة — سنرصد الوجه والعينين منها.'
      : 'Live analysis is unavailable here. Point the camera at your face and capture a still — we will detect the face and eyes from it.';
  String get snapCapture => isAr ? 'التقط' : 'Capture';
  String get snapRetake => isAr ? 'إعادة الالتقاط' : 'Retake';
  String get snapUse => isAr ? 'استخدم هذه اللقطة' : 'Use this capture';
  String get snapBack => isAr ? 'عودة للتحليل الحي' : 'Back to live analysis';
  String get useSnapshotScan =>
      isAr ? 'استخدام فحص اللقطة' : 'Use snapshot scan';
  String get snapProcessing => isAr ? 'جارٍ المعالجة…' : 'Processing…';
  String get snapNativeUnsupported => isAr
      ? 'الالتقاط الثابت غير متاح مع محرك الكاميرا الحالي — التحليل الحي يعمل بشكل طبيعي.'
      : 'Still capture is unavailable with the current camera engine — live analysis works normally.';
  String get snapNoFace => isAr
      ? 'لم يُرصد وجه في اللقطة — أعد التوجيه والتقط مجدداً.'
      : 'No face in this still — re-aim and capture again.';
  String get snapFaceOk =>
      isAr ? 'تم رصد الوجه في اللقطة.' : 'Face detected in the still.';
  String get snapModeBanner => isAr
      ? 'وضع اللقطة الثابتة: القياسات الزمنية (الحركة والرمش والاستجابة الضوئية) غير متاحة من صورة واحدة.'
      : 'Still-image mode: temporal measurements (movement, blink, light response) are unavailable from a single image.';

  // ---------- Retinal info ----------
  String get retinalBanner => isAr
      ? 'عتاد بحثي مستقبلي. لا يستطيع OcuScan فحص الشبكية بكاميراته الحالية. لا يعمل أي تحليل شبكي على صور السيلفي — يرفضها مصدر الشبكية بالتصميم.'
      : 'Future research hardware. OcuScan cannot examine the retina with its current cameras. No retinal analysis runs on selfie images — the retinal source rejects them by design.';
  String get retinalWhyTitle => isAr
      ? 'لماذا لا تصور الهواتف العادية الشبكية'
      : 'Why normal phones cannot image the retina';
  String get retinalWhyBody => isAr
      ? 'تبطن الشبكية مؤخرة العين. يتطلب تصويرها إضاءة محورية عبر الحدقة ومحاذاة دقيقة وبصريات تركز على القاع — لا يوفر أيٌّ منها كاميرا الهاتف الأمامية أو الخلفية. تُظهر السيلفي ظاهر العين فقط.'
      : 'The retina lines the back of the eye. Photographing it needs coaxial illumination through the pupil, precise alignment, and optics that focus on the fundus — none of which a front or rear phone camera provides. A selfie shows the outside of the eye only.';
  String get retinalRequireTitle =>
      isAr ? 'ما يتطلبه ملحق بصري' : 'What an attachment would require';
  String get retinalRequireBody => isAr
      ? '• مكونات بصرية محاذية لكاميرا الهاتف\n'
            '• إضاءة مضبوطة وآمنة للعين\n'
            '• إرشاد ثابت للمحاذاة والتركيز\n'
            '• بوابة جودة للصور الشبكية (قبول / رفض)\n'
            '• محلل شبكي متحقق منه بشكل منفصل'
      : '• Optical components aligned to the phone camera\n'
            '• Controlled, eye-safe illumination\n'
            '• Stable alignment and focus guidance\n'
            '• A retinal image quality gate (accept / reject)\n'
            '• A separately validated retinal analyzer';
  String get retinalSafetyTitle => isAr ? 'السلامة' : 'Safety';
  String get retinalSafetyBody => isAr
      ? 'يجب أن تكون إضاءة الشبكية آمنة للعين ومحدودة زمنياً. لا اختبار ذاتي بضوء ساطع. يحتاج أي ملحق مستقبلي مراجعة سلامة خاصة قبل الاستخدام.'
      : 'Retinal illumination must be eye-safe and time-limited. No bright-light self-testing. Any future attachment needs its own safety review before use.';
  String get retinalStatusTitle => isAr ? 'حالة البحث' : 'Research status';
  String get retinalStatusBody => isAr
      ? 'غير منفذ. تحفز أعمال قاع العين بالهواتف المنشورة (ملحقات متخصصة) هذا المسار لكنها تخص تلك الدراسات — انظر الدليل. لا يبلغ OcuScan عن اكتشافات شبكية.'
      : 'Not implemented. Published smartphone-fundus work (specialized attachments) motivates the track but belongs to those studies — see evidence. OcuScan reports no retinal findings.';
  String get retinalRoadmapTitle => isAr ? 'خارطة الطريق' : 'Roadmap';
  String get retinalRoadmapBody => isAr
      ? 'المرحلة أ — الهاتف الحالي: علامات ظاهرة + اختبارات نظر.\n'
            'المرحلة ب — رؤية حاسوبية متقدمة: فيديو زمني ومحللات متخصصة.\n'
            'المرحلة ج — ملحق بصري: تصوير الشبكية.\n'
            'المرحلة د — تعاون سريري: بعد الأخلاقيات وبيانات المرجع والتحقق.\n'
            'المرحلة هـ — نشر منظم محتمل: بعد مراجعة تنظيمية متخصصة.\n\n'
            'المراحل اللاحقة لم تتحقق.'
      : 'Phase A — Current smartphone: observable signs + visual tests.\n'
            'Phase B — Advanced computer vision: temporal video, specialized analyzers.\n'
            'Phase C — Optical attachment: retinal imaging.\n'
            'Phase D — Clinical collaboration: after ethics, reference data, validation.\n'
            'Phase E — Potential regulated deployment: after professional regulatory review.\n\n'
            'Later phases are not achieved.';

  // ---------- Color calibration ----------
  String get calibBanner => isAr
      ? 'لا ترى كاميرات الهواتف الألوان بالتساوي: تختلف قيم RGB بين الأجهزة والإضاءة وإعدادات الشاشة. '
            'تحلل وحدات الألوان (اصفرار الصلبة والاحمرار والنظر اللوني) إحصاءات RGB/HSV/Lab التي لا تُقارَن إلا في ظروف مضبوطة. '
            'لا تستنتج معنى سريرياً من قيم RGB الخام دون معايرة.'
      : 'Phone cameras do not see color equally: RGB values differ between devices, lighting, and display settings. '
            'Color modules (scleral yellowing, redness, color vision) analyze RGB/HSV/Lab statistics that are only comparable under controlled conditions. '
            'Do not infer clinical meaning from raw RGB values without calibration.';
  String get calibVerifyHint => isAr
      ? 'تحقق من كل شرط ثم اقرأ الحالة.'
      : 'Verify each condition, then read the status.';
  String get calibCheckNeutral => isAr
      ? 'إضاءة بيضاء محايدة (بدون صبغة دافئة/صفراء)'
      : 'Neutral white lighting (no warm/yellow cast)';
  String get calibCheckNoColored => isAr
      ? 'لا مصابيح ملونة أو شرائط LED في الغرفة'
      : 'No colored lamps or LED strips in the room';
  String get calibCheckBrightness =>
      isAr ? 'سطوع الشاشة على الحد الأقصى' : 'Screen brightness at maximum';
  String get calibCheckNightMode => isAr
      ? 'الوضع الليلي / فلتر الضوء الأزرق متوقف'
      : 'Night mode / blue-light filter OFF';
  String get calibCheckNoFilters => isAr
      ? 'لا فلاتر ألوان لسهولة الوصول أو تصحيح'
      : 'No accessibility color filters or correction';
  String calibStatusTitle(String status) => isAr
      ? 'المعايرة ${status.toUpperCase()}'
      : 'Calibration ${status.toUpperCase()}';
  String calibMeaning(String s) {
    switch (s) {
      case 'acceptable':
        return isAr
            ? 'تم التحقق من كل الشروط. المقارنات اللونية صالحة لجلسة الالتقاط هذه فقط — أعد الفحص إذا تغيرت الإضاءة أو الجهاز.'
            : 'All conditions verified. Color comparisons are valid only for this capture session — repeat the check if lighting or device changes.';
      case 'uncertain':
        return isAr
            ? 'بعض الشروط غير متحقق منها. تعامل مع اكتشافات الألوان بحذر إضافي وفضّل الإعادة في ظروف متحقق منها بالكامل.'
            : 'Some conditions unverified. Treat color findings with extra caution and prefer repeating under fully verified conditions.';
      default:
        return isAr
            ? 'شروط كثيرة غير متحقق منها. لا تستخدم نتائج الألوان من هذه الجلسة.'
            : 'Too many conditions unverified. Do not use color-based results from this session.';
    }
  }

  String get calibFailedBanner => isAr
      ? 'تعذّر التقييم بشكل موثوق. لا يمكن الوثوق باكتشافات الألوان من هذه اللقطة — أصلح الظروف أعلاه وأعد.'
      : 'Unable to assess reliably. Color-based findings from this capture cannot be trusted — fix the conditions above and repeat.';

  // ---------- Evidence sheet ----------
  String get evidenceSheetWhy =>
      isAr ? 'لماذا يُدرَج هذا الاختبار؟' : 'Why is this test included?';
  String evidenceHardware(List<String> hw) => isAr
      ? 'العتاد المطلوب: ${hw.join('; ')}'
      : 'Required hardware: ${hw.join('; ')}';
  String get evidenceSheetResearch =>
      isAr ? 'ما البحث الداعم له؟' : 'What research supports it?';
  String get evidenceSheetNoRefs =>
      isAr ? 'لا مراجع داعمة مسجلة.' : 'No supporting references recorded.';
  String get evidenceSheetLimits =>
      isAr ? 'ما المحددات؟' : 'What are the limitations?';
  String get evidenceSheetSafety => isAr
      ? 'المراجع مصادر علمية وتقنية للنموذج الأولي البحثي ولا تعني اعتماداً سريرياً لـ OcuScan.'
      : 'References are scientific and technical sources for the research prototype and do not imply clinical endorsement of OcuScan.';
  String tierBadge(String tier) {
    switch (tier) {
      case 'A':
        return isAr ? 'الدرجة A — راسخ' : 'Tier A — established';
      case 'B':
        return isAr ? 'الدرجة B — محدود' : 'Tier B — limited';
      case 'C':
        return isAr ? 'الدرجة C — تجريبي' : 'Tier C — experimental';
      default:
        return isAr ? 'الدرجة $tier' : 'Tier $tier';
    }
  }

  String evidenceStatusLine(String status) {
    switch (status) {
      case 'CURRENT':
        return isAr
            ? 'الحالة: متاح في هذه النسخة'
            : 'Status: available in this build';
      case 'EXPERIMENTAL':
        return isAr
            ? 'الحالة: وحدة بحثية تجريبية — غير متحقق منها سريرياً.'
            : 'Status: Experimental research module — not clinically validated.';
      case 'FUTURE':
        return isAr
            ? 'الحالة: بحث مستقبلي — غير منفذ.'
            : 'Status: future research — not implemented.';
      case 'NOT_SUITABLE_FOR_CURRENT_HARDWARE':
        return isAr
            ? 'الحالة: غير مناسب للعتاد الحالي.'
            : 'Status: not suitable for current hardware.';
      default:
        return isAr ? 'الحالة: $status' : 'Status: $status';
    }
  }

  // ---------- Splash ----------
  String appVersionLine(String v) =>
      isAr ? 'إصدار التطبيق: $v' : 'App version: $v';
  String get splashTagline =>
      isAr ? 'فحص موجَّه وقابل للقياس' : 'Guided, measurable screening';
  String get splashPrototype => isAr
      ? 'نموذج بحثي أولي — ليس جهازاً تشخيصياً'
      : 'Research prototype — not a diagnostic device';

  // ---------- Methodology ----------
  // Chrome localized; module registry content (engineering specs, keys,
  // measurements) stays canonical English.
  String get methodologyBanner => isAr
      ? 'يستخدم OcuScan محللات حتمية متخصصة — وليس نموذجاً طبياً واحداً ضخماً معتماً. العتبات أدناه عتبات هندسية أولية وليست عتبات تشخيصية سريرية، ما لم يذكر استشهاد مرجعي خلاف ذلك.'
      : 'OcuScan uses specialized deterministic analyzers — not one giant opaque medical model. Thresholds below are prototype engineering thresholds, not clinical diagnostic thresholds, unless a literature citation states otherwise.';
  String get methodologyModulesTitle =>
      isAr ? 'بطاقات منهجية الوحدات' : 'Module methodology cards';
  String get methodologyRowInput => isAr ? 'المدخل' : 'Input';
  String get methodologyRowProcessing => isAr ? 'المعالجة' : 'Processing';
  String get methodologyRowMeasurement => isAr ? 'القياس' : 'Measurement';
  String get methodologyRowThreshold =>
      isAr ? 'العتبة / منطق القرار' : 'Threshold / decision logic';
  String get methodologyRowRequirements => isAr ? 'المتطلبات' : 'Requirements';
  String get methodologyThresholdNote => isAr
      ? 'عتبة هندسية أولية — وليست عتبة تشخيصية سريرية.'
      : 'Prototype engineering threshold — not a clinical diagnostic threshold.';
  String get methodologyRowOutput => isAr ? 'المخرج' : 'Output';
  String get methodologyRowLimits => isAr ? 'المحددات' : 'Limitations';
  List<(String, String)> get methodologySteps => isAr
      ? [
          (
            '1. الالتقاط',
            'التقاط موجه بالهاتف الذكي بتعليمات ومسافة وإضاءة ثابتة.',
          ),
          (
            '2. ضبط الجودة',
            'تقيس بوابة الجودة السطوع والتعرض والحدة والدقة وهندسة الوجه ورؤية العين. الجودة المنخفضة تمنع التحليل.',
          ),
          (
            '3. استخراج الميزات',
            'معالم على الجهاز ومناطق العين وتقديرات الحدقة ومسارات الحركة وأقنعة التجزئة وإحصاءات اللون — لا تُرسل إلى خادم أبداً.',
          ),
          (
            '4. القياس',
            'قيمة رقمية قابلة للملاحظة (مثل مؤشر عدم التماثل النسبي) محسوبة حتمياً من الميزات.',
          ),
          (
            '5. تقدير عدم اليقين',
            'تقرر الجودة والثقة وعدد اللقطات الصالحة والاتساق بين اللقطات ما إذا كان يجوز الإبلاغ عن نتيجة أصلاً.',
          ),
          (
            '6. التفسير الفحصي',
            'تربط العتبات المتحفظة القياسات بإحدى الحالات الثلاث: لا علامة واضحة أو علامة محتملة أو تعذّر التقييم.',
          ),
          (
            '7. ربط الأدلة',
            'يرتبط كل اكتشاف بمدخل دليل منتقى بدرجته وحالته ومحدداته ومراجعه.',
          ),
          (
            '8. إرشاد المستخدم',
            'خطوات تالية بلغة واضحة: تكرار الظروف ومحفزات التقييم المتخصص وأعلام الطوارئ عند الاقتضاء.',
          ),
        ]
      : [
          (
            '1. Capture',
            'Guided smartphone capture with fixed instructions, distance, and lighting.',
          ),
          (
            '2. Quality Control',
            'QualityGate measures luminance, exposure, sharpness, resolution, face geometry, and eye visibility. Low quality vetoes analysis.',
          ),
          (
            '3. Feature Extraction',
            'On-device landmarks, eye regions, pupil estimates, movement tracks, segmentation masks, and color statistics — never sent to a server.',
          ),
          (
            '4. Measurement',
            'A numeric observable (e.g. relative asymmetry index) computed deterministically from features.',
          ),
          (
            '5. Uncertainty Estimation',
            'Quality, confidence, frame-validity counts, and inter-frame consistency decide whether a result may be reported at all.',
          ),
          (
            '6. Screening Interpretation',
            'Conservative thresholds map measurements to one of three states: no obvious abnormality, possible finding, unable to assess.',
          ),
          (
            '7. Evidence Mapping',
            'Each finding links to a curated evidence entry with tier, status, limitations, and references.',
          ),
          (
            '8. User Guidance',
            'Plain-language next steps: repeat conditions, professional-assessment prompts, and emergency flags where relevant.',
          ),
        ];

  // ---------- Settings ----------
  String get settingsTitle => isAr ? 'الإعدادات' : 'Settings';
  String get settingsPrivacy => isAr ? 'الخصوصية' : 'Privacy';
  String get settingsRawImages =>
      isAr ? 'تخزين الصور الخام' : 'Raw images stored';
  String get settingsRawImagesSub => isAr
      ? 'متوقف افتراضياً. عند التفعيل: تُخزَّن على هذا الجهاز فقط، واشرح الاحتفاظ في «عن التطبيق».'
      : 'OFF by default. If ON: stored on this device only, explain retention in About.';
  String get settingsNoCloud => isAr ? 'لا رفع سحابي' : 'No cloud upload';
  String get settingsCloudSub => isAr
      ? 'يعمل الفحص الأساسي دون اتصال ولا يحتاج الرفع أبداً. لا يوجد خادم يستقبل بياناتك.'
      : 'Core screening works offline and never needs upload. There is no server receiving your data.';
  String get settingsHistory => isAr
      ? 'سجل الفحص (قياسات محلية)'
      : 'Screening history (local measurements)';
  String get settingsData => isAr ? 'البيانات' : 'Data';
  String settingsLocalDataLine(int n) => isAr
      ? 'على هذا الجهاز: $n قياسات محلية. الصور الخام محذوفة افتراضياً.'
      : 'On this device: $n local measurements. Raw images are deleted by default.';
  String get settingsDeleteData =>
      isAr ? 'حذف جميع البيانات' : 'Delete all data';
  String get settingsDeleteTitle =>
      isAr ? 'حذف جميع البيانات؟' : 'Delete all data?';
  String get settingsDeleteBody => isAr
      ? 'سيؤدي هذا إلى حذف جميع القياسات المحلية لجميع الأشخاص ونتائج البحث. لا يمكن التراجع.'
      : 'This deletes all local measurements for every person, plus research results. This cannot be undone.';
  String settingsDeleteProfileLine(
    String name,
    int total,
    String first,
    String latest,
  ) => isAr
      ? '$name: $total قياسات • من $first إلى $latest'
      : '$name: $total measurements • $first → $latest';
  String get settingsDeletePreview =>
      isAr ? 'عاين التقرير أولاً' : 'Preview the report first';
  String get settingsExport => isAr ? 'تصدير النتائج' : 'Export results';
  String get settingsExportNote => isAr
      ? 'التصدير: تُخزَّن القياسات محلياً في قاعدة بيانات التطبيق ويمكن مشاركتها من السجل.'
      : 'Export: measurements are stored locally in the app database and can be shared from History.';
  String get settingsDeletedSnack => isAr
      ? 'تم حذف جميع بيانات الفحص المحلية.'
      : 'All local screening data deleted.';
  String get settingsA11y =>
      isAr ? 'إمكانية الوصول واللغة' : 'Accessibility & language';
  String get settingsLanguage => isAr ? 'اللغة' : 'Language';
  String get settingsEnglish => 'English';
  String get settingsArabic => 'العربية';
  String get settingsTextSize => isAr ? 'حجم النص' : 'Text size';
  String get settingsHighContrast => isAr ? 'تباين عالٍ' : 'High contrast';
  String get settingsTestSetup => isAr ? 'إعداد الاختبار' : 'Test setup';
  String get settingsDistance =>
      isAr ? 'مسافة اختبار البعد' : 'Distance-test distance';
  String settingsDistanceValue(double cm) =>
      isAr ? '${_iso('$cm')} سم' : '${cm.toStringAsFixed(0)} cm';
  String get settingsRawNeverNote => isAr
      ? 'لا تُستخدم صور الوجه الخام أبداً في الإعلانات أو التعرف على الوجوه أو ملفات الهوية، ولا تُباع أو تُشارَك أبداً.'
      : 'Raw face images are never used for advertising, face recognition, or identity profiles, and are never sold or shared.';
  String get settingsResearchHidden => isAr
      ? 'أدوات البحث (مخفية افتراضياً)'
      : 'Research tools (hidden by default)';
  String get settingsResearchMode =>
      isAr ? 'وضع التحقق البحثي' : 'Research validation mode';
  String get settingsResearchModeSub => isAr
      ? 'متوقف افتراضياً. يفتح مساحة العمل البحثية المخفية. بدون تشخيصات.'
      : 'OFF by default. Gates the hidden /dev workspace. No diagnoses.';
  String get settingsEnableResearchTitle =>
      isAr ? 'تفعيل وضع البحث؟' : 'Enable research mode?';
  String get settingsEnableResearchBtn =>
      isAr ? 'فهمت — تفعيل' : 'I understand — enable';
  String get settingsSaveCaptures =>
      isAr ? 'حفظ لقطة بحثية' : 'Save research capture';
  String get settingsSaveCapturesSub => isAr
      ? 'بحثي فقط • محلي فقط • قابل للحذف • لا يُصدَّر أبداً. متوقف افتراضياً.'
      : 'Research-only • local only • deletable • never exported. OFF by default.';
  String get settingsSaveCaptureTitle =>
      isAr ? 'حفظ لقطة بحثية؟' : 'Save research capture?';
  String get settingsSaveCaptureBody => isAr
      ? 'بحثي فقط، ويُخزَّن محلياً على هذا الجهاز، وقابل للحذف، ولا يُصدَّر أو يُرفع أبداً. '
            'الصور لا تغادر هذا الهاتف. تُحذف اللقطات مع التجربة أو مع حذف كل البيانات.'
      : 'Research-only, stored locally on this device, deletable, and never exported or uploaded. '
            'Images never leave this phone. Captures are deleted with the experiment or with delete-all-data.';
  String get settingsAllowLocalSaves =>
      isAr ? 'فهمت — السماح بالحفظ المحلي' : 'I understand — allow local saves';
  String get settingsOpenResearch =>
      isAr ? 'فتح التحقق البحثي' : 'Open research validation';
  String get settingsLearnMore => isAr ? 'اعرف المزيد' : 'Learn more';
  String get settingsAbout => isAr ? 'عن OcuScan' : 'About OcuScan';

  // ---------- Vision Lab v0.4: instruction, calibration, results ----------
  String get beginTest => isAr ? 'ابدأ الاختبار' : 'Begin test';
  String get restartTest => isAr ? 'إعادة الاختبار' : 'Restart test';
  String get introPurpose => isAr ? 'الغرض' : 'Purpose';
  String get introTime => isAr ? 'المدة' : 'Time';
  String get introDistance => isAr ? 'المسافة' : 'Distance';
  String get introEnvironment => isAr ? 'البيئة' : 'Environment';
  String get introEyes => isAr ? 'العيون' : 'Eye configuration';
  String get introCalibration => isAr ? 'المعايرة' : 'Calibration';
  String get visionIndexTitle => isAr ? 'فهرس الاختبارات' : 'Test index';
  String get visionIndexSubtitle => isAr
      ? 'اختبارات منظمة للوظيفة البصرية.'
      : 'Structured tests for visual function.';
  String get visionStatusReady => isAr ? 'جاهز' : 'Ready';
  String get visionStatusDone => isAr ? 'مكتمل' : 'Completed';
  String get visionDuration2min => isAr ? '~دقيقتان' : '~2 min';
  String get visionDuration1min => isAr ? '~دقيقة' : '~1 min';
  String get visionDuration3min => isAr ? '~3 دقائق' : '~3 min';

  String get resTest => isAr ? 'الاختبار' : 'TEST';
  String get resResult => isAr ? 'النتيجة' : 'RESULT';
  String get resConditions => isAr ? 'الظروف' : 'CONDITIONS';
  String get resReliability => isAr ? 'الموثوقية' : 'RELIABILITY';
  String get resLimitation => isAr ? 'المحددات' : 'LIMITATION';
  String get resNextStep => isAr ? 'الخطوة التالية' : 'NEXT STEP';
  String get resSequence =>
      isAr ? 'تسلسل الاستجابات (بحث)' : 'Response sequence (research)';

  String get textScaleWarn => isAr
      ? 'تم رصد تكبير نص النظام — عطّله للحصول على قياس موثوق.'
      : 'System text scaling detected — disable it for a reliable measurement.';
  String get textScaleOk =>
      isAr ? 'تكبير نص النظام متوقف.' : 'System text scaling is off.';

  // Distance staircase
  String get distIntroPurpose => isAr
      ? 'قياس حدة البصر للبعد بسلم تكيفي: تبدأ الحروف كبيرة وتصغر مع الإجابات الصحيحة.'
      : 'Measure distance visual acuity with an adaptive staircase: letters start large and shrink with correct answers.';
  String get distIntroCalib => isAr
      ? 'هاتف على بعد 3 م، سطوع كامل، بدون تكبير، إضاءة متساوية.'
      : 'Phone at 3 m, full brightness, no zoom, even lighting.';
  String staircaseProgress(int trial, int reversals) => isAr
      ? 'المحاولة $trial • الانعكاسات $reversals/6'
      : 'Trial $trial • reversals $reversals/6';
  String eyeSummaryLine(String eye, String label) =>
      isAr ? 'العين $eye: $label' : '$eye eye: $label';
  String get distBothSummaryTitle =>
      isAr ? 'ملخص العينين' : 'Both-eyes summary';

  // Near
  String get nearIntroPurpose => isAr
      ? 'قياس حدة القرب بمسافة إمساك مضبوطة (~40 سم).'
      : 'Measure near acuity at a controlled hold distance (~40 cm).';

  // Color
  String get colorIntroPurpose => isAr
      ? 'تقييم تمييز الألوان بلوحات مولّدة بثلاث درجات صعوبة.'
      : 'Assess color discrimination with generated plates at three difficulty levels.';
  String colorLevelLabel(int level) => isAr
      ? 'المستوى ${['سهل', 'متوسط', 'صعب'][level.clamp(0, 2)]}'
      : ['Easy', 'Medium', 'Hard'][level.clamp(0, 2)];
  String get colorBrightnessWarn => isAr
      ? 'اضبط السطوع الكامل وعطّل الوضع الليلي والفلاتر.'
      : 'Set full brightness and disable night mode and filters.';
  String colorScoreLine(int errors, int total) =>
      isAr ? 'الأخطاء: $errors/$total' : 'Errors: $errors/$total';

  // Contrast
  String get contrastIntroPurpose => isAr
      ? 'تقدير عتبة التباين بإجراء تكيفي حول العتبة.'
      : 'Estimate contrast threshold with an adaptive around-threshold procedure.';

  // Central
  String get centralIntroPurpose => isAr
      ? 'فحص تشوه الرؤية المركزية بشبكة لكل عين (أيمن ثم أيسر).'
      : 'Screen central-vision distortion with a per-eye grid (right, then left).';
  String get centralReset => isAr ? 'مسح العلامات' : 'Clear marks';
  String get centralNextEye =>
      isAr ? 'التالي: اختبر العين اليسرى' : 'Next: test the left eye';

  // Peripheral
  String get peripheralIntroPurpose => isAr
      ? 'فحص الوعي بالمحيط مع تثبيت مركزي ومحفزات عشوائية التوقيت والموقع.'
      : 'Screen peripheral awareness with central fixation and random-timing, random-location stimuli.';
  String get peripheralFixationNote => isAr
      ? 'أبقِ نظرك على الصليب طوال الوقت.'
      : 'Keep looking at the cross the whole time.';
  String reactionLine(int ms) =>
      isAr ? 'زمن الاستجابة: $ms مللي ثانية' : 'Reaction: ${ms}ms';

  // Cover
  String get coverIntroPurpose => isAr
      ? 'اختبار التغطية الموجه: غطِّ واكشف كل عين وسجّل أي حركة.'
      : 'Guided cover test: cover and uncover each eye and record any movement.';

  // ---------- Future research tracks (capability catalog) ----------
  String get learnTracksTitle =>
      isAr ? 'مسارات بحثية مستقبلية' : 'Future research tracks';
  String get learnTracksBody => isAr
      ? 'اتجاهات بحثية ببروتوكولات محددة — ليست ميزات ولا تشخيصات ولا تُقاس في هذه النسخة.'
      : 'Research directions with defined protocols — not features, not diagnoses, not measured in this build.';
  String get trackHardwareLabel => isAr ? 'العتاد' : 'Hardware';
  String get trackProtocolLabel => isAr ? 'البروتوكول' : 'Protocol';

  // ---------- Guided retest ----------
  String get retestButton =>
      isAr ? 'إعادة الاختبار بنفس الإعداد' : 'Retest with same setup';
  String retestBanner(String setup) => isAr
      ? 'إعادة اختبار بنفس الإعداد: $setup'
      : 'Retesting with the same setup: $setup';
  String get retestScreening => isAr ? 'إعادة الفحص' : 'Retest screening';
}
