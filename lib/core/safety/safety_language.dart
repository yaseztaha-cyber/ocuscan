// Safety language guardrails.
// The app MUST NEVER emit diagnostic certainty. This file centralizes:
//  - banned phrases (diagnostic claims, false reassurance, fake approvals)
//  - approved category labels
//  - the mandatory disclaimer
// Automated tests assert that UI strings + evidence DB avoid banned phrases.

class SafetyLanguage {
  /// Phrases that must never appear in user-facing output (case-insensitive).
  static const List<String> bannedPhrases = [
    'you have glaucoma',
    'you have bell',
    "bell's palsy",
    'bells palsy',
    'you have cataract',
    'you have liver disease',
    'you are healthy',
    'no disease detected',
    'you have strabismus',
    'you have macular degeneration',
    'your glasses prescription is',
    'fda approved',
    'clinically certified',
    'doctor approved',
    'hospital validated',
    'medical-grade',
    '98% accurate',
    '99% accurate',
    '100% accurate',
    'i think you have',
    'you have jaundice',
    'you have dry-eye disease',
    'you have dry eye disease',
    'disease risk',
    'health score',
    'eye health score',
    'you have diabetes',
    'you are disease-free',
    'disease-free',
    'probability of disease',
    // F4: finding+verb forms — "X detected / X finding" reads as a
    // diagnosis even without "you have". Bare nouns are NOT banned (they
    // appear in legitimate cannot-diagnose sentences).
    'cataract detected',
    'pterygium detected',
    'glaucoma detected',
    'retinopathy detected',
    'ptosis detected',
    'disease score',
    'تم تشخيص',
    'خالٍ من الأمراض',
    'درجة صحية',
  ];

  /// Mandatory notice shown with every "no obvious abnormality" result.
  /// Enforced by code via [ensureNoFindingNotice] — a normal screening
  /// result must never imply the user is healthy.
  static const String noFindingNotice =
      'No obvious abnormality was observed in this screening. '
      'This does not rule out conditions that cannot be assessed by this test.';

  /// Returns [limitations] with the no-finding notice appended unless a
  /// rule-out statement is already present. Callers displaying normal
  /// results must pass limitations through this helper.
  static List<String> ensureNoFindingNotice(List<String> limitations) {
    final has = limitations.any((l) {
      final s = l.toLowerCase();
      return s.contains('does not exclude') ||
          s.contains('does not rule out');
    });
    if (has) return limitations;
    return [...limitations, noFindingNotice];
  }

  static const String screeningDisclaimer =
      'This is a screening observation, not a diagnosis. '
      'OcuScan cannot determine the cause of a finding and does not replace '
      'an eye examination or medical care.';

  static const String researchPrototypeLabel =
      'Educational/research screening prototype — not a diagnostic medical device.';

  static const Map<String, String> categoryLabels = {
    'no_obvious_abnormality': 'No obvious abnormality observed in this screening',
    'possible_finding': 'Possible finding detected',
    'unable_to_assess': 'Unable to assess reliably',
  };

  /// Returns true if [text] contains any banned phrase.
  static bool containsBannedPhrase(String text) {
    final lower = text.toLowerCase();
    return bannedPhrases.any(lower.contains);
  }

  /// Throws in debug / fails tests if banned language is detected.
  static void assertSafe(String text, {String context = ''}) {
    assert(!containsBannedPhrase(text),
        'Banned medical/regulatory phrase in $context: "$text"');
  }
}
