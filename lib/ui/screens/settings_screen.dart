import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../main.dart';
import '../../core/data/settings_repository.dart';
import '../../core/data/history_repository.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/dev_strings.dart';
import '../../core/validation/export.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int? _dataCount;

  // NOTE: the data count loads only after the profile section finishes
  // its own database read (onLoaded). Firing both reads concurrently
  // contends on the database lock; sequential keeps startup clean.

  Future<void> _loadDataCount() async {
    try {
      final profileId = context.read<AppState>().profileId;
      final summary = await context
          .read<HistoryRepository>()
          .summary(profileId: profileId);
      if (mounted) setState(() => _dataCount = summary.total);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsRepository>();
    final app = context.watch<AppState>();
    final t = AppStrings(app.lang);
    return Scaffold(
      appBar: AppBar(title: Text(t.settingsTitle)),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        SectionTitle(t.settingsPrivacy),
        SwitchListTile(value: s.storeRawImages, onChanged: (v) async { await s.setStoreRawImages(v); setState(() {}); },
          title: Text(t.settingsRawImages), subtitle: Text(t.settingsRawImagesSub)),
        // No cloud-upload toggle: there is no backend and no upload code
        // path, so a switch would be a dead promise (deployment audit).
        // A static row states the offline truth instead. The repository
        // getter stays for stored-value compatibility.
        ListTile(
          leading: const Icon(Icons.cloud_off_outlined),
          title: Text(t.settingsNoCloud),
          subtitle: Text(t.settingsCloudSub)),
        SwitchListTile(value: s.historyEnabled, onChanged: (v) async { await s.setHistory(v); setState(() {}); },
          title: Text(t.settingsHistory)),
        SectionTitle(t.settingsData),
        if (_dataCount != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(t.settingsLocalDataLine(_dataCount!),
                style: Theme.of(context).textTheme.bodySmall),
          ),
        OutlinedButton.icon(onPressed: () async {
          List<ProfileStats> stats = const [];
          try {
            stats = await context.read<HistoryRepository>().profileStats();
          } catch (_) {}
          final ok = await showDialog<bool>(
            // ignore: use_build_context_synchronously
            context: context,
            builder: (dctx) => AlertDialog(
              title: Text(t.settingsDeleteTitle),
              content: SingleChildScrollView(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(t.settingsDeleteBody),
                      const SizedBox(height: 8),
                      for (final p in stats)
                        Text(
                            t.settingsDeleteProfileLine(p.name, p.total,
                                _dayPart(p.first), _dayPart(p.latest)),
                            style: Theme.of(dctx).textTheme.bodySmall),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(dctx, false);
                          Navigator.pushNamed(context, '/report');
                        },
                        child: Text(t.settingsDeletePreview),
                      ),
                    ]),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dctx, false),
                    child: Text(t.cancel)),
                FilledButton(
                    onPressed: () => Navigator.pop(dctx, true),
                    child: Text(t.settingsDeleteData)),
              ],
            ),
          );
          if (ok != true || !context.mounted) return;
          await context.read<HistoryRepository>().clearAll();
          // Delete-all also removes local research captures.
          try {
            final base = await researchBaseDir();
            final dir = Directory('$base/research_captures');
            if (await dir.exists()) await dir.delete(recursive: true);
          } catch (_) {}
          await _loadDataCount();
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.settingsDeletedSnack)));
        }, icon: const Icon(Icons.delete_outline), label: Text(t.settingsDeleteData)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
            onPressed: () =>
                Navigator.pushNamed(context, '/report'),
            icon: const Icon(Icons.ios_share),
            label: Text(t.settingsExport)),
        SectionTitle(t.profilesTitle),
        Text(t.profilesBody, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        _ProfileSection(onLoaded: _loadDataCount),
        SectionTitle(t.settingsA11y),
        // Bilingual row title (readable in both languages); the segmented
        // control below carries explicit selection state (EN/AR).
        ListTile(title: const Text('Language / اللغة'),
          trailing: SegmentedButton<String>(segments: const [
            ButtonSegment(value: 'en', label: Text('EN')), ButtonSegment(value: 'ar', label: Text('عربي')),
          ], selected: {app.lang}, onSelectionChanged: (v) async { app.setLang(v.first); await s.setLanguage(v.first); })),
        ListTile(title: Text(t.settingsTextSize),
          trailing: DropdownButton<double>(value: s.textScale,
            items: const [1.0, 1.15, 1.3].map((d) => DropdownMenuItem(value: d, child: Text('${(d * 100).toInt()}%'))).toList(),
            onChanged: (v) async { if (v != null) { await s.setTextScale(v); setState(() {}); } })),
        SwitchListTile(value: s.highContrast, onChanged: (v) async { await s.setHighContrast(v); setState(() {}); }, title: Text(t.settingsHighContrast)),
        SectionTitle(t.settingsTestSetup),
        ListTile(title: Text(t.settingsDistance),
          subtitle: Text(t.settingsDistanceValue(s.testDistanceCm)),
          trailing: DropdownButton<double>(value: s.testDistanceCm,
            items: const [200.0, 300.0, 400.0].map((d) => DropdownMenuItem(value: d, child: Text('${d.toInt()} cm'))).toList(),
            onChanged: (v) async { if (v != null) { await s.setTestDistance(v); setState(() {}); } })),
        const SizedBox(height: 8),
        SafetyBanner(text: t.settingsRawNeverNote),
        SectionTitle(t.settingsResearchHidden),
        SwitchListTile(
          value: s.researchMode,
          onChanged: (v) async {
            if (v) {
              final strings = DevStrings.of(context);
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text(t.settingsEnableResearchTitle),
                  content: SingleChildScrollView(
                      child: Text(strings.researchConsent)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(t.cancel)),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(t.settingsEnableResearchBtn)),
                  ],
                ));
              if (ok != true) return;
            } else {
              // Disabling research mode also disables research captures.
              await s.setSaveResearchCaptures(false);
            }
            await s.setResearchMode(v);
            setState(() {});
          },
          title: Text(t.settingsResearchMode),
          subtitle: Text(t.settingsResearchModeSub),
        ),
        if (s.researchMode) ...[
          SwitchListTile(
            value: s.saveResearchCaptures,
            onChanged: (v) async {
              if (v && !s.researchCaptureAcknowledged) {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text(t.settingsSaveCaptureTitle),
                    content: Text(t.settingsSaveCaptureBody),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(t.cancel)),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(t.settingsAllowLocalSaves)),
                    ],
                  ));
                if (ok != true) return;
                await s.setResearchCaptureAcknowledged(true);
              }
              await s.setSaveResearchCaptures(v);
              setState(() {});
            },
            title: Text(t.settingsSaveCaptures),
            subtitle: Text(t.settingsSaveCapturesSub),
          ),
          ListTile(
            leading: const Icon(Icons.science_outlined),
            title: Text(t.settingsOpenResearch),
            trailing: const NavChevron(),
            onTap: () => Navigator.pushNamed(context, '/dev'),
          ),
        ],
        SectionTitle(t.settingsLearnMore),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(t.settingsAbout),
          trailing: const NavChevron(),
          onTap: () => Navigator.pushNamed(context, '/about'),
        ),
        ListTile(
          leading: const Icon(Icons.menu_book_outlined),
          title: Text(t.references),
          trailing: const NavChevron(),
          onTap: () => Navigator.pushNamed(context, '/references'),
        ),
        ListTile(
          leading: const Icon(Icons.architecture_outlined),
          title: Text(t.methodology),
          trailing: const NavChevron(),
          onTap: () => Navigator.pushNamed(context, '/methodology'),
        ),
      ]),
    );
  }
}

/// Day part of an ISO timestamp for delete-preflight lines ('?' when
/// unknown). Pure presentation, never stored.
String _dayPart(String? v) =>
    (v != null && v.length >= 10) ? v.substring(0, 10) : (v ?? '?');

/// Local person profiles: radio selection, add, delete-with-data.
/// Names are on-device labels only — never identities, never uploaded.
class _ProfileSection extends StatefulWidget {
  final void Function()? onLoaded;
  const _ProfileSection({this.onLoaded});
  @override
  State<_ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends State<_ProfileSection> {
  List<Map<String, String>> _profiles = [];
  Map<String, int> _counts = {};
  final TextEditingController _name = TextEditingController();
  final TextEditingController _rename = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _rename.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final repo = context.read<HistoryRepository>();
      final list = await repo.profiles();
      // D6: per-profile counts ride the same load (sequential, no extra
      // lock contention) so misfiled rows are visible at a glance.
      final stats = await repo.profileStats();
      if (mounted) {
        setState(() {
          _profiles = list;
          _counts = {for (final s in stats) s.id: s.total};
        });
      }
    } catch (_) {}
    widget.onLoaded?.call();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = context.watch<SettingsRepository>();
    final t = AppStrings(app.lang);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          RadioGroup<String>(
            groupValue: app.profileId,
            onChanged: (v) async {
              if (v == null) return;
              await s.setActiveProfileId(v);
              app.setProfile(v);
            },
            child: Column(
              children: [
                for (final p in _profiles)
                  RadioListTile<String>(
                    value: p['id']!,
                    title:
                        Text(t.profileName(p['id']!, p['name']!)),
                    subtitle: Text(t.profileMeasurements(
                        _counts[p['id']] ?? 0)),
                    secondary: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: t.profileRename,
                          onPressed: () =>
                              _renameDialog(p['id']!, p['name']!),
                        ),
                        if (p['id'] != 'self')
                          IconButton(
                            icon:
                                const Icon(Icons.delete_outline),
                            tooltip: t.profileDelete,
                            onPressed: () => _confirmDelete(
                                p['id']!, p['name']!),
                          ),
                      ],
                    ),
                    controlAffinity:
                        ListTileControlAffinity.leading,
                    dense: true,
                  ),
              ],
            ),
          ),
          // Layout: stacked on narrow screens so the add button never
          // squeezes the name field (or vice versa) at large text.
          LayoutBuilder(builder: (ctx, constraints) {
            final field = TextField(
              controller: _name,
              decoration: InputDecoration(
                labelText: t.profileNameHint,
                border: const OutlineInputBorder(),
              ),
            );
            final add = FilledButton(
              onPressed: () async {
                final name = _name.text.trim();
                if (name.isEmpty) return;
                final id =
                    'p${DateTime.now().millisecondsSinceEpoch}';
                await context
                    .read<HistoryRepository>()
                    .addProfile(id, name);
                _name.clear();
                await _load();
              },
              child: Text(t.profileAdd),
            );
            if (constraints.maxWidth > 500) {
              return Row(children: [
                Expanded(child: field),
                const SizedBox(width: 8),
                add,
              ]);
            }
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  field,
                  const SizedBox(height: 8),
                  add,
                ]);
          }),
        ]),
      ),
    );
  }

  Future<void> _renameDialog(String id, String current) async {
    final t = AppStrings(context.read<AppState>().lang);
    _rename.text = current;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(t.profileRename),
        content: TextField(
          controller: _rename,
          decoration: InputDecoration(
            labelText: t.profileNameHint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: Text(t.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(dctx, true),
              child: Text(t.profileRename)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<HistoryRepository>().renameProfile(id, _rename.text);
    _rename.clear();
    await _load();
  }

  Future<void> _confirmDelete(String id, String name) async {
    final repo = context.read<HistoryRepository>();
    final settingsRepo = context.read<SettingsRepository>();
    final appState = context.read<AppState>();
    final t = AppStrings(appState.lang);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(t.profileDeleteTitle),
        content: Text(t.profileDeleteBody(
            t.profileName(id, name))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: Text(t.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(dctx, true),
              child: Text(t.profileDelete)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await repo.deleteProfile(id);
    if (appState.profileId == id) {
      await settingsRepo.setActiveProfileId('self');
      appState.setProfile('self');
    }
    await _load();
  }
}
