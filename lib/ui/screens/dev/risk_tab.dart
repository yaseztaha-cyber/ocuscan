// Research-only Risk tab (/dev): renders the bundled risk register
// (assets/risk_management.json) as a reviewable table. Documentation
// layer — structured thinking, never a certification claim. Asset load
// failure shows an honest error, never invented rows.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/localization/dev_strings.dart';
import '../../widgets/common.dart';

class RiskTab extends StatefulWidget {
  const RiskTab({super.key});
  @override
  State<RiskTab> createState() => _RiskTabState();
}

class _RiskTabState extends State<RiskTab> {
  List<Map<String, dynamic>> risks = [];
  String? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw =
          await rootBundle.loadString('assets/risk_management.json');
      final doc = json.decode(raw) as Map<String, dynamic>;
      risks = (doc['risks'] as List).cast<Map<String, dynamic>>();
      if (mounted) setState(() => loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = DevStrings.of(context);
    final t = Theme.of(context).textTheme;
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return ListView(padding: const EdgeInsets.all(16), children: [
        SafetyBanner(text: 'Risk register failed to load: $error'),
      ]);
    }
    Widget row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 110,
              child: Text(k,
                  style: t.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w700))),
          Expanded(child: Text(v, style: t.bodySmall)),
        ]));
    return ListView(padding: const EdgeInsets.all(16), children: [
      SafetyBanner(text: s.riskExplainer),
      const SizedBox(height: 8),
      for (final r in risks)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${r['feature']} — ${r['hazard']}',
                      style: t.titleMedium),
                  const SizedBox(height: 6),
                  row('cause', '${r['cause']}'),
                  row('harm', '${r['possible_harm']}'),
                  row('severity', '${r['severity']}'),
                  row('probability', '${r['probability']}'),
                  row('level', '${r['risk_level']}'),
                  row('mitigation', '${r['mitigation']}'),
                  row('residual', '${r['residual_risk']}'),
                  row('verification', '${r['verification']}'),
                ]),
          ),
        ),
    ]);
  }
}
