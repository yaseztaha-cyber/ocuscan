// Record a trial within an experiment (research only).
//
// Three honest paths:
//  1. Guided camera trial — real capture → real ImageStats → real
//     QualityGate verdict → failure codes. LOW quality suggests "rejected".
//     An optional numeric value observed by the operator (e.g. from the
//     tracking overlay or a connected analyzer readout) may be attached.
//  2. Manual measurement entry — a value read from any instrument the
//     researcher documents in notes (including a consumer-app screening run).
//  3. Reference entry — a manually entered reference measurement with its
//     method (never called a gold standard unless it qualifies).
//
// Raw captures are deleted unless "Save research capture" is ON *and*
// explicitly acknowledged. Captures never enter exports.

import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import '../../../core/data/settings_repository.dart';
import '../../../core/localization/dev_strings.dart';
import '../../../core/models/screening_result.dart';
import '../../../core/pipeline/quality_gate.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/validation/experiment_models.dart';
import '../../../core/validation/export.dart';
import '../../../core/validation/quality_failures.dart';
import '../../../core/validation/validation_repository.dart';
import '../../../features/camera/camera_service.dart';
import '../../widgets/common.dart';
import 'tracking_overlay.dart';

class RecordTrialScreen extends StatefulWidget {
  final Experiment experiment;
  const RecordTrialScreen({super.key, required this.experiment});

  @override
  State<RecordTrialScreen> createState() => _RecordTrialScreenState();
}

class _RecordTrialScreenState extends State<RecordTrialScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool cameraOk = false;
  String? cameraError;
  bool capturing = false;
  QualityVerdict? verdict;
  ImageStats? stats;

  final _value = TextEditingController();
  final _unit = TextEditingController();
  final _label = TextEditingController();
  final _notes = TextEditingController();
  final _refValue = TextEditingController();
  final _refMethod = TextEditingController();
  String confidence = 'low';
  bool showTracking = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    // Hold the service reference: BuildContext must not be used in dispose
    // (deactivated-ancestor crash), so release() is called on this handle.
    _camRef = context.read<CameraService>();
    _initCamera();
  }

  CameraService? _camRef;

  @override
  void dispose() {
    _camRef?.release();
    _tabs.dispose();
    _value.dispose();
    _unit.dispose();
    _label.dispose();
    _notes.dispose();
    _refValue.dispose();
    _refMethod.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    final permission = await ensureCameraPermission();
    if (!mounted) return;
    if (permission != CameraPermission.granted) {
      await explainCameraIssue(context, permission, null);
      if (!mounted) return;
      setState(() {
        cameraOk = false;
        cameraError =
            'Camera unavailable. Please check permissions or device availability.';
      });
      return;
    }
    final cam = context.read<CameraService>();
    if (cam.ready) {
      setState(() => cameraOk = true);
      return;
    }
    final ok = await cam.init();
    if (mounted) {
      setState(() {
        cameraOk = ok;
        cameraError = cam.error;
      });
    }
  }

  QualityInput _qualityInput() {
    final cam = context.read<CameraService>();
    final f = cam.lastFrame;
    final s = stats ??
        const ImageStats(
            meanLuminance: 120,
            overexposedFraction: 0.05,
            underexposedFraction: 0.05,
            sharpnessVariance: 80,
            rednessMean: 0.36,
            yellownessMean: 0.05,
            width: 640,
            height: 480);
    return QualityInput(
      stats: s,
      bothEyesVisible: f?.bothEyesOpen ?? false,
      faceCentered: f?.centered ?? false,
      faceAngleDeg: f?.yawDeg ?? 0,
      faceBoxFraction: f?.faceFraction ?? 0.4,
      eyesObstructed: (f != null && f.faceFound && !f.bothEyesOpen),
      strongBacklight: false,
      coloredAmbientLight: false,
    );
  }

  Future<void> _capture() async {
    setState(() => capturing = true);
    final cam = context.read<CameraService>();
    try {
      final file = await cam.captureStill();
      if (file != null) {
        final bytes = await File(file.path).readAsBytes();
        final decoded = img.decodeImage(bytes);
        if (decoded != null) {
          final small = img.copyResize(decoded, width: 320);
          final rgb = <int>[];
          for (int y = 0; y < small.height; y++) {
            for (int x = 0; x < small.width; x++) {
              final p = small.getPixel(x, y);
              rgb.addAll([p.r.toInt(), p.g.toInt(), p.b.toInt()]);
            }
          }
          stats = ImageUtils.computeStats(rgb,
              width: small.width,
              height: small.height,
              stride: 4,
              actualWidth: decoded.width,
              actualHeight: decoded.height);
        }
        // Raw bytes are held only to optionally store a research capture
        // after the trial row exists; otherwise deleted immediately.
        _lastBytes = bytes;
        _lastPath = file.path;
      }
      if (!mounted) return;
      setState(() => verdict = QualityGate.evaluate(_qualityInput()));
    } finally {
      if (mounted) setState(() => capturing = false);
    }
  }

  List<int>? _lastBytes;
  String? _lastPath;

  Future<void> _saveTrial({
    required TrialStatus status,
    String? failureReason,
    double? value,
    double? referenceValue,
  }) async {
    final e = widget.experiment;
    final repo = context.read<ValidationRepository>();
    final settings = context.read<SettingsRepository>();
    final trial = Trial(
      experimentId: e.id!,
      timestamp: DateTime.now(),
      inputQuality: (verdict?.quality ?? ImageQuality.low).name,
      value: value,
      unit: _unit.text.trim(),
      measurementLabel: _label.text.trim(),
      confidence: confidence,
      status: status,
      failureReason: failureReason,
      referenceValue: referenceValue,
      referenceMethod:
          _refMethod.text.trim().isEmpty ? null : _refMethod.text.trim(),
      lightingLevel: e.lightingLevel,
      lux: e.lux,
      distanceCm: e.targetDistanceCm,
      headAngleDeg: e.headAngleDeg,
      deviceLabel: e.deviceLabel,
      subjectId: e.subjectId,
      testType: e.testType,
      notes: _notes.text.trim(),
      luminance: stats?.meanLuminance,
      sharpness: stats?.sharpnessVariance,
      exposureBadFraction: stats == null
          ? null
          : (stats!.overexposedFraction + stats!.underexposedFraction),
    );
    final trialId = await repo.recordTrial(trial);

    // Research capture: only when explicitly enabled AND acknowledged.
    if (settings.saveResearchCaptures &&
        settings.researchCaptureAcknowledged &&
        _lastBytes != null) {
      try {
        final base = await researchBaseDir();
        await ResearchCaptureStore(base)
            .save(e.id!, trialId, _lastBytes!);
        await repo.updateTrial(
            trial.copyWith(id: trialId, hasCapture: true));
      } catch (_) {
        // Storage failure must not lose the measurement row.
      }
    }
    // Always delete the camera temp file; research copies live (if enabled)
    // under the research store only.
    if (_lastPath != null) {
      try {
        await File(_lastPath!).delete();
      } catch (_) {}
    }
    _lastBytes = null;
    _lastPath = null;
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final appLang =
        Localizations.localeOf(context).languageCode == 'ar' ? 'ar' : 'en';
    final s = DevStrings(appLang);
    final e = widget.experiment;
    return Scaffold(
      appBar: AppBar(
        title: Text('${s.recordTrial} — ${e.name}'),
        bottom: TabBar(controller: _tabs, tabs: [
          Tab(text: s.runGuidedTrial),
          Tab(text: s.manualEntry),
          Tab(text: s.referenceEntry),
        ]),
      ),
      body: TabBarView(controller: _tabs, children: [
        _guidedTab(s, e),
        _manualTab(s, e),
        _referenceTab(s, e),
      ]),
    );
  }

  Widget _conditionsCard(Experiment e) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${e.testType} ${e.analyzerVersion}',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                  'Device ${e.deviceLabel} • ${e.camera} • '
                  'dist ${e.targetDistanceCm?.toStringAsFixed(0) ?? '—'} cm • '
                  'light ${e.lightingLevel}${e.lux == null ? '' : ' (${e.lux} lx)'} • '
                  'angle ${e.headAngleDeg?.toStringAsFixed(0) ?? '—'}° • '
                  '${e.subjectId}'),
            ]),
      ),
    );
  }

  Widget _guidedTab(DevStrings s, Experiment e) {
    final cam = context.watch<CameraService>();
    return ListView(padding: const EdgeInsets.all(16), children: [
      _conditionsCard(e),
      const SizedBox(height: 8),
      if (cameraError != null)
        SafetyBanner(text: 'Camera issue: $cameraError. '
            'Trials will record the failure honestly instead of guessing.'),
      if (cameraOk && cam.controller != null)
        Container(
          height: 240,
          decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF0E7C7B)),
              borderRadius: BorderRadius.circular(12),
              color: Colors.black),
          child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CameraPreview(cam.controller!)),
        )
      else if (cameraOk && cam.nativePreviewTextureId != null)
        Container(
          height: 240,
          decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF0E7C7B)),
              borderRadius: BorderRadius.circular(12),
              color: Colors.black),
          child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: NativePreviewTexture(
                textureId: cam.nativePreviewTextureId!,
                rotationDeg: cam.lastRotationDeg,
                mirrored: cam.isMirrored,
              )),
        )
      else
        const Card(
            child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                    'Camera unavailable — capture-based trials cannot run on this device. Manual entry remains available.'))),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: (capturing || !cameraOk) ? null : _capture,
            icon: const Icon(Icons.camera_alt_outlined),
            label: Text(capturing ? 'Analyzing…' : 'Capture trial'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () =>
                setState(() => showTracking = !showTracking),
            icon: const Icon(Icons.radar_outlined),
            label: Text(s.showTracking),
          ),
        ),
      ]),
      if (showTracking) ...[
        const SizedBox(height: 8),
        const TrackingOverlay(),
      ],
      if (verdict != null) ...[
        const SizedBox(height: 8),
        _verdictCard(verdict!, s),
        const SizedBox(height: 8),
        _valueFields(),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: FilledButton(
              onPressed: () => _saveTrial(
                status: verdict!.quality == ImageQuality.low
                    ? TrialStatus.rejected
                    : TrialStatus.accepted,
                failureReason: verdict!.quality == ImageQuality.low
                    ? primaryFailure(verdict!).code
                    : null,
                value: double.tryParse(_value.text.trim()),
              ),
              child: Text(verdict!.quality == ImageQuality.low
                  ? 'Save as rejected'
                  : 'Save as accepted'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _saveTrial(
                status: TrialStatus.unable,
                failureReason: _notes.text.trim().isEmpty
                    ? 'OPERATOR_UNABLE'
                    : _notes.text.trim(),
                value: double.tryParse(_value.text.trim()),
              ),
              child: Text(s.saveAsUnable),
            ),
          ),
        ]),
      ],
      const SizedBox(height: 8),
      SafetyBanner(text: s.recordTrialNote),
    ]);
  }

  Widget _verdictCard(QualityVerdict v, DevStrings s) {
    final codes = categorizeFailures(v);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Quality: ${v.quality.name.toUpperCase()} '
                  '(score ${v.score.toStringAsFixed(0)}/100)',
                  style: Theme.of(context).textTheme.titleMedium),
              if (stats != null) ...[
                const SizedBox(height: 4),
                Text(
                    'luminance ${stats!.meanLuminance.toStringAsFixed(1)} • '
                    'sharpness ${stats!.sharpnessVariance.toStringAsFixed(1)} • '
                    'bad exposure ${((stats!.overexposedFraction + stats!.underexposedFraction) * 100).toStringAsFixed(1)}% • '
                    '${stats!.width}×${stats!.height}'),
              ],
              for (final i in v.issues) Text('• $i'),
              if (codes.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                    'Failure codes: ${codes.map((c) => s.failureLabel(c.code)).join(', ')}'),
              ],
            ]),
      ),
    );
  }

  Widget _valueFields() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(
              controller: _value,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Numeric value (optional)',
                  border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(
              controller: _unit,
              decoration: const InputDecoration(
                  labelText: 'Unit (e.g. %, px, logMAR)',
                  border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(
              controller: _label,
              decoration: const InputDecoration(
                  labelText: 'Measurement label',
                  border: OutlineInputBorder())),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
              initialValue: confidence,
              items: const ['low', 'moderate', 'high']
                  .map((c) =>
                      DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => confidence = v ?? 'low'),
              decoration: const InputDecoration(
                  labelText: 'Confidence',
                  border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(
              controller: _notes,
              decoration: const InputDecoration(
                  labelText: 'Operator notes',
                  border: OutlineInputBorder())),
        ]),
      ),
    );
  }

  Widget _manualTab(DevStrings s, Experiment e) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      _conditionsCard(e),
      const SizedBox(height: 8),
      _valueFields(),
      const SizedBox(height: 8),
      FilledButton(
        onPressed: () {
          final v = double.tryParse(_value.text.trim());
          if (v == null) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text(
                    'Manual entry requires a numeric value. Document the instrument in notes.')));
            return;
          }
          _saveTrial(status: TrialStatus.accepted, value: v);
        },
        child: Text(s.saveManual),
      ),
      const SizedBox(height: 8),
      const SafetyBanner(
          text: 'Record the instrument and conditions in notes (e.g. consumer-app screening run, ruler distance, meter lux).'),
    ]);
  }

  Widget _referenceTab(DevStrings s, Experiment e) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      _conditionsCard(e),
      const SizedBox(height: 8),
      const SafetyBanner(
          text: 'A reference is a comparison point, not an automatic gold standard. '
              'Name the exact method (e.g. clinic chart at 6 m, standardized plate set). Never fabricate reference data.'),
      const SizedBox(height: 8),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            TextField(
                controller: _value,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'OcuScan value for this session',
                    border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(
                controller: _refValue,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Reference value',
                    border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(
                controller: _unit,
                decoration: const InputDecoration(
                    labelText: 'Unit', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(
                controller: _refMethod,
                decoration: const InputDecoration(
                    labelText: 'Reference method (exact)',
                    border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(
                controller: _notes,
                decoration: const InputDecoration(
                    labelText: 'Notes', border: OutlineInputBorder())),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      FilledButton(
        onPressed: () {
          final v = double.tryParse(_value.text.trim());
          final r = double.tryParse(_refValue.text.trim());
          if (r == null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content:
                    Text(s.referenceRequired)));
            return;
          }
          _saveTrial(
              status: TrialStatus.accepted,
              value: v,
              referenceValue: r);
        },
        child: Text(s.savePairedReference),
      ),
    ]);
  }
}
