// Trends over time: same test across visits for the active profile.
// Measurements display as recorded text with a conservative
// comparability chip per consecutive pair. No charts, no invented
// precision, no disease-progression language.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/data/history_repository.dart';
import '../../core/localization/app_strings.dart';
import '../../core/models/screening_result.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/trend_logic.dart';
import '../../main.dart';
import '../widgets/common.dart';

class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key});
  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  List<String> _tests = [];
  String? _selected;
  List<ScreeningResult> _rows = [];
  bool _loading = true;
  String _profile = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profileId = context.read<AppState>().profileId;
      final repo = context.read<HistoryRepository>();
      final tests = await repo.testNames(profileId: profileId);
      String? sel = _selected;
      if (sel == null || !tests.contains(sel)) {
        sel = tests.isEmpty ? null : tests.first;
      }
      List<ScreeningResult> rows = [];
      if (sel != null) {
        final all = await repo.all(limit: 500, profileId: profileId);
        rows = all.where((r) => r.testName == sel).toList();
      }
      if (!mounted) return;
      setState(() {
        _tests = tests;
        _selected = sel;
        _rows = rows;
        _profile = profileId;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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
      appBar: AppBar(title: Text(s.trendsTitle)),
      body: _loading
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 8),
              Text(s.loadingEvidence),
            ]))
          : ListView(padding: const EdgeInsets.all(20), children: [
              Text(s.trendsBody, style: t.bodyMedium),
              const SizedBox(height: 6),
              SafetyBanner(text: s.trendsChangeNote),
              const SizedBox(height: 12),
              if (_tests.isEmpty)
                Text(s.trendsNoData, style: t.headlineSmall)
              else ...[
                DropdownButtonFormField<String>(
                  initialValue: _selected,
                  decoration: InputDecoration(
                      labelText: s.trendsPickTest,
                      border: const OutlineInputBorder()),
                  items: [
                    for (final n in _tests)
                      DropdownMenuItem(value: n, child: Text(n)),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _selected = v;
                      _loading = true;
                    });
                    _load();
                  },
                ),
                const SizedBox(height: 8),
                Text(s.trendsCountLine(_rows.length),
                    style: t.bodySmall),
                const SizedBox(height: 8),
                if (_rows.length == 1) ...[
                  Text(s.trendsSingleNote, style: t.bodySmall),
                  const SizedBox(height: 8),
                ],
                for (var i = 0; i < _rows.length; i++)
                  _TrendRow(
                    row: _rows[i],
                    previous:
                        i + 1 < _rows.length ? _rows[i + 1] : null,
                    s: s,
                    t: t,
                  ),
              ],
            ]),
    );
  }
}

class _TrendRow extends StatelessWidget {
  final ScreeningResult row;
  final ScreeningResult? previous;
  final AppStrings s;
  final TextTheme t;
  const _TrendRow(
      {required this.row,
      required this.previous,
      required this.s,
      required this.t});

  @override
  Widget build(BuildContext context) {
    final reason =
        previous == null ? null : comparabilityReason(row, previous!);
    final ok = reason == null;
    final color = row.finding == ResultCategory.possibleFinding
        ? AppTheme.amber
        : (row.finding == ResultCategory.unableToAssess
            ? AppTheme.slate
            : AppTheme.tealDark);
    final icon = row.finding == ResultCategory.possibleFinding
        ? Icons.visibility_outlined
        : (row.finding == ResultCategory.unableToAssess
            ? Icons.help_outline
            : Icons.check_circle_outline);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      row.timestamp
                          .toLocal()
                          .toString()
                          .substring(0, 16),
                      style: t.titleMedium),
                ),
              ]),
              const SizedBox(height: 4),
              Text(row.measurement, style: t.bodyMedium),
              const SizedBox(height: 4),
              Text(
                  '${row.imageQuality.name} • ${row.confidence.name}',
                  style: t.bodySmall),
              if (row.hardware.isEmpty &&
                  row.deviceLabel.isEmpty &&
                  row.algorithmVersion.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(s.traceLegacyRow, style: t.bodySmall),
                ),
              if (previous != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: ok
                        ? AppTheme.tealTint
                        : AppTheme.amberTint,
                    border: Border.all(
                        color:
                            ok ? AppTheme.tealDark : AppTheme.amber),
                    borderRadius:
                        BorderRadius.circular(OcuRadii.pill),
                  ),
                    child: Text(
                        ok
                            ? s.trendsComparable
                            : '${s.trendsCaution} — ${s.trendsReason(reason)}',
                      style: TextStyle(
                          color: ok
                              ? AppTheme.tealDark
                              : AppTheme.amber,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ]),
      ),
    );
  }
}
