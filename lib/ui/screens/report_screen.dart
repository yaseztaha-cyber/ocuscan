// Shareable screening summary (human-readable doctor report).
// Builds from the active profile's latest row per test; previews the
// exact text before sharing via the system sheet. Nothing is uploaded
// by the app itself.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/data/history_repository.dart';
import '../../core/evidence/evidence_repository.dart';
import '../../core/localization/app_strings.dart';
import '../../features/report/clinical_report.dart';
import '../../main.dart';
import '../widgets/common.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  String? _text;
  String? _coverage;
  String? _error;
  bool _loading = true;
  String _profile = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final app = context.read<AppState>();
    final targetProfile = app.profileId;
    setState(() {
      _loading = true;
      _error = null;
      // Record the profile being loaded NOW: build() re-invokes _load
      // only when the profile differs from the last load, so a
      // persistently failing load must not re-trigger itself forever
      // (infinite DB hammering with a flickering spinner).
      _profile = targetProfile;
    });
    try {
      final repo = context.read<HistoryRepository>();
      final s = AppStrings(app.lang);
      final rows =
          await repo.all(limit: 500, profileId: app.profileId);
      final profs = await repo.profiles();
      final match =
          profs.where((p) => p['id'] == app.profileId).toList();
      final name = match.isEmpty
          ? app.profileId
          : s.profileName(app.profileId, match.first['name']!);
      String evidenceVersion = '';
      try {
        evidenceVersion = (await EvidenceRepository.load()).dbVersion;
      } catch (_) {}
      final latest = latestPerTest(rows);
      final coverage = reportCoverage(latest);
      if (!mounted) return;
      setState(() {
        _profile = app.profileId;
        _coverage = coverage.count == 0
            ? null
            : s.reportCoversLine(
                coverage.count,
                coverage.from!
                    .toLocal()
                    .toString()
                    .substring(0, 10),
                coverage.to!.toLocal().toString().substring(0, 10));
        _text = latest.isEmpty
            ? null
            : buildClinicalReport(
                s: s,
                profileName: name,
                generatedAt: DateTime.now()
                    .toLocal()
                    .toString()
                    .substring(0, 16),
                appVersion: kOcuScanVersion,
                evidenceVersion: evidenceVersion,
                latestRows: latest,
              );
        _loading = false;
      });
    } catch (e) {
      // A load failure must never masquerade as "no measurements":
      // name it with a retry instead of the empty state (audit).
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.runtimeType.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = AppStrings(app.lang);
    final t = Theme.of(context).textTheme;
    if (app.profileId != _profile && !_loading) {
      _loading = true;
      _load();
    }
    return Scaffold(
      appBar: AppBar(title: Text(s.reportTitle)),
      body: _loading
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 8),
              Text(s.loadingEvidence),
            ]))
            : ListView(padding: const EdgeInsets.all(20), children: [
              SafetyBanner(text: s.disclaimer),
              const SizedBox(height: 10),
              if (_error != null) ...[
                Text(s.reportLoadFailed(_error!),
                    style: t.titleMedium),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_outlined),
                  label: Text(s.retryAnalysis),
                ),
              ] else if (_text == null)
                Text(s.reportEmpty, style: t.headlineSmall)
              else ...[
                if (_coverage != null) ...[
                  Text(_coverage!, style: t.bodySmall),
                  const SizedBox(height: 8),
                ],
                SelectableText(_text!, style: t.bodyMedium),
                const SizedBox(height: 16),
                // Share-sheet only: a Copy button here would place the
                // full PHI report on the system clipboard, readable by
                // any background app/keyboard. The SelectableText above
                // still lets the user select+copy explicitly — their
                // choice, not the app's. (Compat Lab's copy stays: its
                // summary carries no health data.)
                FilledButton.icon(
                  onPressed: () => SharePlus.instance.share(
                      ShareParams(
                          text: _text!, subject: s.reportTitle)),
                  icon: const Icon(Icons.ios_share),
                  label: Text(s.reportShare),
                ),
              ],
            ]),
    );
  }
}
