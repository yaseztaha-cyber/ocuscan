// Universal Compatibility Lab (/compat-lab, from /dev).
//
// Verification center for the broad-Android-compatibility architecture
// (§19): capability states per area, engine classification, selected
// engine, latency, device profile, and engine controls. Everything
// shown is observed runtime state — never claimed, never guessed.
// Unmeasured areas read NOT MEASURED, not PASS.
//
// Medical-safety: infrastructure diagnostics only, no health claims.

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/localization/dev_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/camera/camera_service.dart';
import '../../../features/vision/vision_engine_manager.dart';
import '../../../main.dart';

/// Pure plain-text capability summary for the Compat Lab "Copy summary"
/// button. Built only from the screen's existing data fields (device
/// identity line, health, lens presence, capability map, engine, latency,
/// rotation, frame counters, stage, and the [DeviceVisionProfile] that
/// the on-screen card already renders via `profile.toJson()` entries).
/// No [BuildContext], no clipboard — the widget wires those thinly.
String compatSummaryText({
  required String model,
  required String os,
  required String health,
  required bool hasFrontCamera,
  required bool hasRearCamera,
  required Map<String, CapabilityState> capabilities,
  required DeviceVisionProfile profile,
  required String engine,
  required double latencyMs,
  required int rotationDeg,
  required List<int> sensorOrientations,
  required int framesProcessed,
  required int framesReceived,
  required String stage,
  required String? lastError,
  required String? maxResolution,
  // Detection summary (v0.7.15): the copy-pasted summary previously
  // carried no detection facts at all — no tier, no faces/locks, no
  // quality, no throughput. All default to unknown/zero so older
  // callers and tests keep compiling and passing unchanged.
  String detectorTier = 'unknown',
  int mlGeneration = 0,
  int facesDetected = 0,
  int locksAchieved = 0,
  String quality = 'unknown',
  String hitRate = 'none yet',
  double throughputRatio = -1,
  double arrivalFps = 0,
  double processingFps = 0,
  double meanLatencyMs = 0,
  String sensorFrame = '',
  String mlInput = '',
}) {
  final buf = StringBuffer();
  buf.writeln('OcuScan compatibility summary');
  buf.writeln('$model • $os');
  buf.writeln('health: $health');
  buf.writeln(
    'camera: front=${hasFrontCamera ? 'YES' : 'NO'} rear=${hasRearCamera ? 'YES' : 'NO'}',
  );
  for (final e in capabilities.entries) {
    buf.writeln('${e.key}: ${e.value.name}');
  }
  buf.writeln('engine: $engine');
  buf.writeln(
    'latency: ${latencyMs.toStringAsFixed(0)} ms / frame '
    '(mean ${meanLatencyMs.toStringAsFixed(0)} ms)',
  );
  buf.writeln(
    'rotation: last=$rotationDeg° sensors=${sensorOrientations.join('/')}',
  );
  buf.writeln('frames: $framesProcessed analyzed / $framesReceived received');
  buf.writeln('stage: $stage${lastError == null ? '' : ' / $lastError'}');
  if (maxResolution != null && maxResolution.isNotEmpty) {
    buf.writeln('maxResolution: $maxResolution');
  }
  buf.writeln('--- detection ---');
  buf.writeln('detector: $detectorTier (generation $mlGeneration)');
  buf.writeln('faces: $facesDetected detected / $locksAchieved locks');
  buf.writeln('quality: $quality');
  buf.writeln('hitRate: $hitRate');
  buf.writeln(
    throughputRatio < 0
        ? 'throughput: unknown yet'
        : 'throughput: ${(throughputRatio * 100).toStringAsFixed(1)}% '
              '(${processingFps.toStringAsFixed(1)} / '
              '${arrivalFps.toStringAsFixed(1)} fps)',
  );
  if (sensorFrame.isNotEmpty || mlInput.isNotEmpty) {
    buf.writeln(
      'sensorFrame: ${sensorFrame.isEmpty ? '?' : sensorFrame} '
      'mlInput: ${mlInput.isEmpty ? '?' : mlInput}',
    );
  }
  buf.writeln('--- device profile ---');
  for (final e in profile.toJson().entries) {
    buf.writeln('${e.key}: ${e.value}');
  }
  return buf.toString().trim();
}

class CompatLabScreen extends StatefulWidget {
  const CompatLabScreen({super.key});
  @override
  State<CompatLabScreen> createState() => _CompatLabScreenState();
}

class _CompatLabScreenState extends State<CompatLabScreen> {
  String _model = 'unknown';
  String _manufacturer = '';
  String _os = 'unknown';
  int _api = 0;

  @override
  void initState() {
    super.initState();
    _loadDevice();
  }

  Future<void> _loadDevice() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      if (!mounted) return;
      setState(() {
        _model = info.model;
        _manufacturer = info.manufacturer;
        _os = 'Android ${info.version.release} (SDK ${info.version.sdkInt})';
        _api = info.version.sdkInt;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final s = DevStrings.of(context);
    final t = Theme.of(context).textTheme;
    final cam = context.watch<CameraService>();
    final snap = cam.healthSnapshot;
    final health = classifyEngineHealth(snap);
    final hasFront = cam.hasFrontCamera;
    final hasRear = cam.hasRearCamera;
    final caps = capabilityStates(
      snap,
      hasFrontCamera: hasFront,
      hasRearCamera: hasRear,
    );
    final profile = DeviceVisionProfile(
      androidApi: _api,
      manufacturer: _manufacturer,
      model: _model,
      frontCamera: hasFront,
      rearCamera: hasRear,
      sensorOrientations: cam.sensorOrientations,
      cameraAnalysis: snap.framesProcessed > 0,
      mlKit: caps['nativeMlKit'] == CapabilityState.supported,
      selectedEngine: cam.displayEngineId.name,
      maxReliableResolution: snap.framesProcessed > 0
          ? cam.lastFrameSizeLabel
          : null,
      tested: snap.framesProcessed > 0,
    );
    final a = AppStrings(s.lang);
    final summary = compatSummaryText(
      model: _model,
      os: _os,
      health: health.name,
      hasFrontCamera: hasFront,
      hasRearCamera: hasRear,
      capabilities: caps,
      profile: profile,
      engine: cam.displayEngineId.name,
      latencyMs: cam.lastLatencyMs,
      rotationDeg: cam.lastRotationDeg,
      sensorOrientations: cam.sensorOrientations,
      framesProcessed: snap.framesProcessed,
      framesReceived: cam.framesReceived,
      stage: cam.stage.name,
      lastError: cam.lastError?.type,
      maxResolution: snap.framesProcessed > 0 ? cam.lastFrameSizeLabel : null,
      detectorTier: cam.detectorTier,
      mlGeneration: cam.mlGeneration,
      facesDetected: cam.facesDetectedTotal,
      locksAchieved: cam.locksAchievedTotal,
      quality: cam.qualityVerdictLabel,
      hitRate: cam.hitRateLine,
      throughputRatio: cam.throughputRatio,
      arrivalFps: cam.arrivalFps,
      processingFps: cam.processingFps,
      meanLatencyMs: cam.meanLatencyMs,
      sensorFrame: cam.lastFrameSizeLabel,
      mlInput: cam.mlInputLabel,
    );
    return Scaffold(
      appBar: AppBar(title: Text(s.compatLabTitle)),
      body: ListView(
        padding: const EdgeInsets.all(OcuSpace.lg),
        children: [
          _StatusHero(
            health: health,
            engine: cam.displayEngineId.name,
            tier: cam.detectorTier,
            throughput: cam.throughputRatio,
            processingFps: cam.processingFps,
            arrivalFps: cam.arrivalFps,
            meanLatencyMs: cam.meanLatencyMs,
            quality: cam.qualityVerdictLabel,
            latencyCaption: s.compatRowLatency,
            throughputCaption: s.compatRowThroughput,
            qualityCaption: s.compatRowQuality,
            s: s,
            t: t,
          ),
          const SizedBox(height: OcuSpace.lg),
          _SectionCard(
            title: s.compatSectionCapabilities,
            children: [
              _Row(
                label: s.compatRowCamera,
                state: caps['camera']!,
                detail:
                    'front=${hasFront ? s.compatYes : s.compatNo} '
                    'rear=${hasRear ? s.compatYes : s.compatNo}',
                s: s,
                t: t,
              ),
              _Row(
                label: s.compatRowNativeMlKit,
                state: caps['nativeMlKit']!,
                detail: cam.lastError == null
                    ? cam.stage.name
                    : '${cam.stage.name} / ${cam.lastError!.type}',
                s: s,
                t: t,
              ),
              _Row(
                label: s.compatRowBundledModel,
                state: caps['bundledModel']!,
                detail: 'no fallback model ships with this build',
                s: s,
                t: t,
              ),
              _Row(
                label: s.compatRowFallbackEngine,
                state: caps['fallbackEngine']!,
                detail: 'slot reserved, unavailable',
                s: s,
                t: t,
              ),
            ],
          ),
          const SizedBox(height: OcuSpace.lg),
          _SectionCard(
            title: s.compatRowDetection,
            children: [
              _Row(
                label: s.compatRowLiveAnalysis,
                state: cam.facesDetectedTotal > 0
                    ? CapabilityState.supported
                    : CapabilityState.unsupported,
                detail:
                    '${cam.facesDetectedTotal} faces / '
                    '${cam.locksAchievedTotal} locks • '
                    '${cam.hitRateLine}',
                s: s,
                t: t,
              ),
              _Row(
                label: s.compatRowRotation,
                state: CapabilityState.supported,
                detail:
                    'last=${cam.lastRotationDeg}° '
                    'sensors=${cam.sensorOrientations.join('/')}',
                s: s,
                t: t,
              ),
              _Row(
                label: s.compatRowCpu,
                state: CapabilityState.supported,
                detail: s.compatNotMeasured,
                s: s,
                t: t,
              ),
              _Row(
                label: s.compatRowEngine,
                state: CapabilityState.supported,
                detail: cam.displayEngineId.name,
                s: s,
                t: t,
              ),
              _Row(
                label: s.compatRowLatency,
                state: CapabilityState.supported,
                detail:
                    '${cam.lastLatencyMs.toStringAsFixed(0)} ms last / '
                    '${cam.meanLatencyMs.toStringAsFixed(0)} ms mean',
                s: s,
                t: t,
              ),
              _Row(
                label: s.compatRowDetection,
                state: cam.facesDetectedTotal > 0
                    ? CapabilityState.supported
                    : CapabilityState.unsupported,
                detail:
                    '${cam.detectorTier} gen${cam.mlGeneration} • '
                    '${cam.facesDetectedTotal} faces / '
                    '${cam.locksAchievedTotal} locks • '
                    '${cam.hitRateLine}',
                s: s,
                t: t,
              ),
              _Row(
                label: s.compatRowThroughput,
                state: cam.throughputRatio < 0
                    ? CapabilityState.unsupported
                    : (cam.throughputRatio < 0.35
                          ? CapabilityState.limited
                          : CapabilityState.supported),
                detail: cam.throughputRatio < 0
                    ? s.compatNotMeasured
                    : '${(cam.throughputRatio * 100).toStringAsFixed(1)}% '
                          '(${cam.processingFps.toStringAsFixed(1)} / '
                          '${cam.arrivalFps.toStringAsFixed(1)} fps)',
                s: s,
                t: t,
              ),
              _Row(
                label: s.compatRowQuality,
                state: cam.qualityVerdictLabel == 'good'
                    ? CapabilityState.supported
                    : (cam.qualityVerdictLabel == 'unknown'
                          ? CapabilityState.unsupported
                          : CapabilityState.limited),
                detail:
                    '${cam.qualityVerdictLabel} '
                    '(lum${cam.lastQuality.meanLuminance.toStringAsFixed(0)} '
                    'blur${cam.lastQuality.blurVariance.toStringAsFixed(1)})',
                s: s,
                t: t,
              ),
              _Row(
                label: s.compatRowMlInput,
                state: cam.mlInputLabel.isEmpty
                    ? CapabilityState.unsupported
                    : CapabilityState.supported,
                detail: cam.mlInputLabel.isEmpty
                    ? s.compatNotMeasured
                    : 'sensor ${cam.lastFrameSizeLabel} → '
                          'ml ${cam.mlInputLabel}',
                s: s,
                t: t,
              ),
            ],
          ),
          const SizedBox(height: OcuSpace.lg),
          Wrap(
            spacing: OcuSpace.sm,
            runSpacing: OcuSpace.sm,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
                onPressed: () => Navigator.pushNamed(context, '/ml-test'),
                icon: const Icon(Icons.science_outlined),
                label: Text(s.mlTestBtn),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 48),
                ),
                onPressed: () => cam.requestEngine(VisionEngineId.nativeMlKit),
                child: Text(s.compatTryNative),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 48),
                ),
                onPressed: () => cam.requestEngine(VisionEngineId.dartMlKit),
                child: Text(s.compatUseDart),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 48),
                ),
                // Copy failure is a real on-device case (no clipboard
                // service): report it instead of crashing or lying.
                onPressed: () async {
                  try {
                    await Clipboard.setData(ClipboardData(text: summary));
                  } catch (_) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(a.compatCopyFailed)));
                    return;
                  }
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(a.compatCopied)));
                },
                icon: const Icon(Icons.copy_outlined, size: 18),
                label: Text(a.compatCopy),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(s.compatProfileTitle, style: t.titleMedium),
          const SizedBox(height: 4),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                profile
                    .toJson()
                    .entries
                    .map((e) => '${e.key}: ${e.value}')
                    .join('\n'),
                style: t.bodySmall?.copyWith(fontFamily: 'monospace'),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text('$_model • $_os', style: t.bodySmall),
          // AppState watch keeps RTL/lang live like every dev screen.
          Builder(
            builder: (context) {
              context.watch<AppState>();
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}

/// Status hero: the lab's instrument headline. Health sentence up top
/// (engine + detector tier beneath), then three live metrics —
/// throughput, mean latency, quality — in one glanceable row. Numbers
/// render in monospace tabular figures; nothing here claims more than
/// the runtime measured (unknown reads '—', never zero).
class _StatusHero extends StatelessWidget {
  final EngineClassification health;
  final String engine;
  final String tier;
  final double throughput;
  final double processingFps;
  final double arrivalFps;
  final double meanLatencyMs;
  final String quality;
  final String latencyCaption;
  final String throughputCaption;
  final String qualityCaption;
  final DevStrings s;
  final TextTheme t;
  const _StatusHero({
    required this.health,
    required this.engine,
    required this.tier,
    required this.throughput,
    required this.processingFps,
    required this.arrivalFps,
    required this.meanLatencyMs,
    required this.quality,
    required this.latencyCaption,
    required this.throughputCaption,
    required this.qualityCaption,
    required this.s,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final (text, color, bg, glyph) = switch (health) {
      EngineClassification.ready => (
        s.compatHealthReady,
        AppTheme.tealDark,
        AppTheme.tealTint,
        Icons.verified_outlined,
      ),
      EngineClassification.degraded => (
        s.compatHealthDegraded,
        AppTheme.amber,
        AppTheme.amberTint,
        Icons.warning_amber_outlined,
      ),
      EngineClassification.unavailable => (
        s.compatHealthUnavailable,
        AppTheme.amber,
        AppTheme.amberTint,
        Icons.cloud_off_outlined,
      ),
    };
    final known = throughput >= 0;
    return Semantics(
      label:
          '${health.name}. $text '
          '$throughputCaption ${known ? '${(throughput * 100).toStringAsFixed(1)} percent' : 'unknown'}. '
          '$qualityCaption $quality.',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(OcuSpace.lg),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(OcuRadii.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(glyph, color: color, size: 28),
                const SizedBox(width: OcuSpace.sm),
                Expanded(
                  child: Text(
                    text,
                    style: t.titleMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: OcuSpace.xs),
            Text(
              '$engine • $tier',
              style: t.bodySmall?.copyWith(color: AppTheme.slate),
            ),
            const SizedBox(height: OcuSpace.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Metric(
                    caption: throughputCaption,
                    value: known
                        ? '${(throughput * 100).toStringAsFixed(1)}%'
                        : '—',
                    sub: known
                        ? '${processingFps.toStringAsFixed(1)} / '
                              '${arrivalFps.toStringAsFixed(1)} fps'
                        : '—',
                    t: t,
                  ),
                ),
                Expanded(
                  child: _Metric(
                    caption: latencyCaption,
                    value: meanLatencyMs > 0
                        ? '${meanLatencyMs.toStringAsFixed(0)} ms'
                        : '—',
                    sub: 'mean',
                    t: t,
                  ),
                ),
                Expanded(
                  child: _Metric(
                    caption: qualityCaption,
                    value: quality,
                    sub: 'last frame',
                    t: t,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String caption;
  final String value;
  final String sub;
  final TextTheme t;
  const _Metric({
    required this.caption,
    required this.value,
    required this.sub,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(caption, style: t.bodySmall?.copyWith(color: AppTheme.slate)),
        Text(
          value,
          style: t.titleLarge?.copyWith(
            fontFamily: 'monospace',
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(sub, style: t.bodySmall?.copyWith(color: AppTheme.slate)),
      ],
    );
  }
}

/// Telemetry section card: white surface on paper, title + hairline +
/// rows. Groups related facts so the lab reads as instruments, not a
/// flat checklist.
class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(OcuSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Divider(height: OcuSpace.lg),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final CapabilityState state;
  final String detail;
  final DevStrings s;
  final TextTheme t;
  const _Row({
    required this.label,
    required this.state,
    required this.detail,
    required this.s,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final (word, color, glyph) = switch (state) {
      CapabilityState.supported => (s.compatPass, AppTheme.tealDark, '✓'),
      CapabilityState.limited => (s.compatLimited, AppTheme.amber, '…'),
      CapabilityState.unsupported => (s.compatFail, AppTheme.slate, '✗'),
    };
    // One screen-reader announcement per row (label + verdict + facts);
    // children excluded so it is never read twice.
    return Semantics(
      label: '$label: $word. $detail',
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: OcuSpace.xs),
            child: Row(
              children: [
                SizedBox(width: 120, child: Text(label, style: t.bodyMedium)),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: OcuSpace.md,
                    vertical: OcuSpace.xs,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: color),
                    borderRadius: BorderRadius.circular(OcuRadii.pill),
                  ),
                  child: Text(
                    '$glyph $word',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: OcuSpace.md),
                Expanded(child: Text(detail, style: t.bodySmall)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
