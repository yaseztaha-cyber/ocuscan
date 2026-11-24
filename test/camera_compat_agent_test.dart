// Pure-logic tests for the camera-compat agent surface:
// compatSummaryText (Compat Lab copy-summary builder) + new AppStrings keys.
import 'package:flutter_test/flutter_test.dart';
import 'package:ocuscan/core/localization/app_strings.dart';
import 'package:ocuscan/features/vision/vision_engine_manager.dart';
import 'package:ocuscan/ui/screens/dev/compat_lab_screen.dart';

DeviceVisionProfile _profile() => const DeviceVisionProfile(
      androidApi: 34,
      manufacturer: '',
      model: 'Pixel 7',
      frontCamera: true,
      rearCamera: true,
      sensorOrientations: [90, 270],
      cameraAnalysis: true,
      mlKit: true,
      bundledModel: false,
      fallbackModel: false,
      selectedEngine: 'dartMlKit',
      maxReliableResolution: '640x480',
      tested: true,
    );

Map<String, CapabilityState> _caps() => capabilityStates(
      const VisionHealthSnapshot(
          framesProcessed: 3, cameraUp: true),
      hasFrontCamera: true,
      hasRearCamera: true,
    );

String _summary({
  String? lastError,
  String? maxResolution = '640x480',
}) =>
    compatSummaryText(
      model: 'Pixel 7',
      os: 'Android 14 (SDK 34)',
      health: EngineClassification.ready.name,
      hasFrontCamera: true,
      hasRearCamera: true,
      capabilities: _caps(),
      profile: _profile(),
      engine: 'dartMlKit',
      latencyMs: 42.6,
      rotationDeg: 90,
      sensorOrientations: const [90, 270],
      framesProcessed: 3,
      framesReceived: 5,
      stage: 'firstFrame',
      lastError: lastError,
      maxResolution: maxResolution,
    );

void main() {
  test('summary carries device line, health, lenses, engine and counters',
      () {
    final text = _summary();
    expect(text, contains('Pixel 7 • Android 14 (SDK 34)'));
    expect(text, contains('health: ready'));
    expect(text, contains('front=YES rear=YES'));
    expect(text, contains('engine: dartMlKit'));
    expect(text, contains('43 ms / frame'));
    expect(text, contains('last=90° sensors=90/270'));
    expect(text, contains('3 analyzed / 5 received'));
    expect(text, contains('stage: firstFrame'));
  });

  test('summary lists every capability state from the lab map', () {
    final caps = _caps();
    final text = _summary();
    for (final e in caps.entries) {
      expect(text, contains('${e.key}: ${e.value.name}'));
    }
  });

  test('summary mirrors the on-screen profile card entries', () {
    final profile = _profile();
    final text = _summary();
    for (final e in profile.toJson().entries) {
      expect(text, contains('${e.key}: ${e.value}'));
    }
  });

  test('stage line appends last error only when present', () {
    expect(_summary(), contains('stage: firstFrame\n'));
    expect(_summary(lastError: 'detectorFail'),
        contains('stage: firstFrame / detectorFail'));
  });

  test('detection block carries tier, faces, quality and throughput', () {
    final text = compatSummaryText(
      model: 'CPH2121',
      os: 'Android 12 (SDK 31)',
      health: EngineClassification.degraded.name,
      hasFrontCamera: true,
      hasRearCamera: true,
      capabilities: _caps(),
      profile: _profile(),
      engine: 'dartMlKit',
      latencyMs: 275.0,
      rotationDeg: 270,
      sensorOrientations: const [90, 270],
      framesProcessed: 95,
      framesReceived: 622,
      stage: 'processing',
      lastError: null,
      maxResolution: '720x480',
      detectorTier: 'accurate',
      mlGeneration: 2,
      facesDetected: 90,
      locksAchieved: 3,
      quality: 'good',
      hitRate: 'medium/nv21: 394/572 (68.9%)',
      throughputRatio: 95 / 622,
      arrivalFps: 22.5,
      processingFps: 3.6,
      meanLatencyMs: 260.0,
      sensorFrame: '720x480',
      mlInput: '240x360 rot0 bitmap',
    );
    expect(text, contains('health: degraded'));
    expect(text, contains('detector: accurate (generation 2)'));
    expect(text, contains('faces: 90 detected / 3 locks'));
    expect(text, contains('quality: good'));
    expect(text, contains('hitRate: medium/nv21: 394/572 (68.9%)'));
    expect(text, contains('throughput: 15.3% (3.6 / 22.5 fps)'));
    expect(text, contains('sensorFrame: 720x480 mlInput: 240x360 rot0 bitmap'));
    expect(text, contains('(mean 260 ms)'));
  });

  test('detection block degrades honestly when nothing measured yet', () {
    final text = _summary();
    expect(text, contains('detector: unknown (generation 0)'));
    expect(text, contains('throughput: unknown yet'));
  });

  test('maxResolution line is omitted when null or empty', () {
    expect(_summary(maxResolution: null), isNot(contains('maxResolution')));
    expect(_summary(maxResolution: ''), isNot(contains('maxResolution')));
    expect(_summary(maxResolution: '640x480'),
        contains('maxResolution: 640x480'));
  });

  test('new rationale + compat strings exist in EN and AR', () {
    const en = AppStrings('en');
    const ar = AppStrings('ar');
    // Pre-rationale: why + on-device + deleted-by-default, each ≤2 sentences.
    expect(en.camRationaleTitle, isNotEmpty);
    expect(ar.camRationaleTitle, isNotEmpty);
    expect(en.camRationaleBody, contains('on-device'));
    expect(en.camRationaleBody, contains('deleted by default'));
    expect(ar.camRationaleBody, contains('الجهاز'));
    expect(ar.camRationaleBody, contains('تُحذف'));
    expect(en.camRationaleContinue, 'Continue');
    expect(ar.camRationaleContinue, 'متابعة');
    // Compat copy button + confirmation.
    expect(en.compatCopy, 'Copy summary');
    expect(ar.compatCopy, isNotEmpty);
    expect(en.compatCopied, isNotEmpty);
    expect(ar.compatCopied, isNotEmpty);
    expect(en.compatCopyFailed, isNotEmpty);
    expect(ar.compatCopyFailed, isNotEmpty);
  });
}
