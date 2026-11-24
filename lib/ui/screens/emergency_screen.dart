import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/localization/app_strings.dart';
import '../../main.dart';
import '../widgets/common.dart';

// Separate symptom safety screen — camera screening is never the only
// route to emergency advice.
class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});
  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  final Set<String> selected = {};

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(context.watch<AppState>().lang);
    final urgent = selected.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(s.emergencyCheckTitle)),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text(s.emergencyWhenNot,
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(s.emergencyIntro),
        SectionTitle(s.emergencyIfSudden),
        for (final sym in s.emergencySymptoms)
          CheckboxListTile(
            value: selected.contains(sym),
            onChanged: (v) => setState(() => v == true ? selected.add(sym) : selected.remove(sym)),
            title: Text(sym), controlAffinity: ListTileControlAffinity.leading,
          ),
        const SizedBox(height: 8),
        if (urgent)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF0A5E5D), width: 2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.emergencyDoNotRely,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              const SizedBox(height: 6),
              Text(s.emergencySeekCare),
            ]),
          )
        else
          SafetyBanner(text: s.emergencyNoSymptom),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(s.back)),
      ]),
    );
  }
}
