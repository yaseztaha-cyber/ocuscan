// Capability explorer (§41): searchable directory over the master
// medical capability catalog — face/eye/vision/retina/experimental/
// future. Cards show name, what is measured, hardware, status, evidence
// tier. Detail pages follow the §42/§43 structure with live evidence
// references. Never a disease list.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_strings.dart';
import '../../features/catalog/detection_catalog.dart';
import '../../main.dart';
import '../widgets/common.dart';
import 'capability_detail_screen.dart';

class CapabilitiesScreen extends StatefulWidget {
  const CapabilitiesScreen({super.key});
  @override
  State<CapabilitiesScreen> createState() => _CapabilitiesScreenState();
}

class _CapabilitiesScreenState extends State<CapabilitiesScreen> {
  DetectionCatalog? catalog;
  String? error;
  String filter = 'All';
  String query = '';

  static const filters = [
    'All',
    'Available',
    'Face',
    'Eye',
    'Vision',
    'Retina',
    'Experimental',
    'Future',
  ];

  @override
  void initState() {
    super.initState();
    DetectionCatalog.load().then((c) {
      if (mounted) setState(() => catalog = c);
    }).catchError((e) {
      if (mounted) setState(() => error = e.toString());
    });
  }

  List<CapabilityEntry> _visible() {
    final c = catalog;
    if (c == null) return [];
    final q = query.toLowerCase();
    return c.all.where((e) {
      switch (filter) {
        case 'Available':
          if (e.implementationStatus != 'CURRENT') return false;
          break;
        case 'Face':
          if (e.category != 'face') return false;
          break;
        case 'Eye':
          if (e.category != 'eye') return false;
          break;
        case 'Vision':
          if (e.category != 'vision') return false;
          break;
        case 'Retina':
          if (e.category != 'retina') return false;
          break;
        case 'Experimental':
          if (e.implementationStatus != 'EXPERIMENTAL') return false;
          break;
        case 'Future':
          if (e.implementationStatus != 'FUTURE') return false;
          break;
        default:
          break;
      }
      if (q.isNotEmpty) {
        final hay =
            '${e.name} ${e.nameAr} ${e.observableFinding}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = AppStrings(context.watch<AppState>().lang);
    final items = _visible();
    return Scaffold(
      appBar: AppBar(title: Text(s.capabilitiesTitle)),
      body: catalog == null && error == null
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 8),
              Text(s.loadingEvidence),
            ]))
          : ListView(padding: const EdgeInsets.all(16), children: [
              Text(s.capabilitiesBody, style: t.bodyMedium),
              const SizedBox(height: 10),
              if (error != null)
                SafetyBanner(text: 'Capability catalog failed to load.'),
              TextField(
                decoration: InputDecoration(
                  labelText: s.capabilitiesSearch,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) =>
                    setState(() => query = v.toLowerCase()),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final f in filters)
                    ChoiceChip(
                      label: Text(s.capFilterLabel(f)),
                      selected: filter == f,
                      onSelected: (_) =>
                          setState(() => filter = f),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(s.capabilitiesCount(items.length),
                  style: t.bodySmall),
              const SizedBox(height: 8),
              if (catalog != null && items.isEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12),
                  child:
                      Text(s.capabilitiesEmpty, style: t.bodyMedium),
                ),
              for (final e in items)
                Card(
                  child: ListTile(
                    title: Text(s.isAr && e.nameAr.isNotEmpty
                        ? e.nameAr
                        : e.name),
                    subtitle: Text(
                        '${e.observableFinding}\n${e.hardwareRequired.join(' • ')}\n${s.capStatusLine(e.implementationStatus, e.validationStatus)} • ${s.tierLabel(e.evidenceStatus)}',
                        style: t.bodySmall),
                    isThreeLine: true,
                    trailing: const NavChevron(),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                CapabilityDetailScreen(entry: e))),
                  ),
                ),
            ]),
    );
  }
}
