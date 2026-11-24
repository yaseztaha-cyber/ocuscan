import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../main.dart';
import '../../core/localization/app_strings.dart';
import '../../core/data/history_repository.dart';
import '../../core/data/settings_repository.dart';
import '../widgets/common.dart';

/// Home: editorial clinical dashboard. Clear primary action, latest
/// screening, Vision Lab entry, how-it-works, research status. Generous
/// whitespace — no card-stuffed layout.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _lastDate;
  int _testCount = 0;
  int _findingCount = 0;
  int _unableCount = 0;
  bool _loaded = false;
  String _loadedProfile = '';
  String _profileName = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final h = context.read<HistoryRepository>();
    final profileId = context.read<AppState>().profileId;
    _loadedProfile = profileId;
    try {
      final summary = await h.summary(profileId: profileId);
      final profs = await h.profiles();
      final match = profs.where((p) => p['id'] == profileId).toList();
      _profileName = match.isEmpty
          ? profileId
          : (match.first['name'] ?? profileId);
      if (!summary.isEmpty) {
        _lastDate =
            summary.latest?.toLocal().toString().substring(0, 10);
        _testCount = summary.total;
        _findingCount = summary.possibleFindings;
        _unableCount = summary.unableToAssess;
      }
    } catch (_) {
      _lastDate = null;
    }
    if (mounted) setState(() => _loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final settings = context.watch<SettingsRepository>();
    final s = AppStrings(app.lang);
    final t = Theme.of(context).textTheme;
    // Reload when the active profile changed elsewhere (e.g. Settings).
    if (app.profileId != _loadedProfile) {
      _loaded = false;
      _load();
    }
    final tabs = [s.home, s.screening, s.vision, s.history, s.learn, s.settings];
    return Scaffold(
      appBar: AppBar(
        title: Text(s.appName),
        actions: [
          IconButton(icon: const Icon(Icons.warning_amber_outlined), tooltip: s.urgentSymptoms,
            onPressed: () => Navigator.pushNamed(context, '/emergency')),
          IconButton(icon: const Icon(Icons.settings_outlined), tooltip: s.settings, onPressed: () => Navigator.pushNamed(context, '/settings')),
          IconButton(icon: const Icon(Icons.info_outline), tooltip: s.about, onPressed: () => Navigator.pushNamed(context, '/about')),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 20), children: [
        Text(s.homeKicker,
            style: t.labelLarge?.copyWith(
                color: const Color(0xFF0A5E5D),
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2)),
        Text(s.homeSubKicker, style: t.displaySmall),
        const SizedBox(height: 4),
        Text(s.prototypeLabel, style: t.bodySmall),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/settings'),
          icon: const Icon(Icons.person_outline),
          label: Text(
              '${s.profileLine(s.profileName(
                  _loadedProfile.isEmpty ? 'self' : _loadedProfile,
                  _profileName.isEmpty ? 'Self' : _profileName))} • ${s.profileChangeBtn}'),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/screening'),
          icon: const Icon(Icons.center_focus_strong),
          label: Text(s.startScreening),
        ),
        const SizedBox(height: 28),
        _SectionHead(title: s.homeLatestTitle, t: t),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_loaded)
                    Text(s.loading, style: t.bodyMedium)
                  else if (_lastDate == null) ...[
                    Text(s.firstRunTitle,
                        style: t.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    for (var i = 0; i < s.firstRunSteps.length; i++)
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                            '${i + 1}. ${s.firstRunSteps[i]}',
                            style: t.bodyMedium),
                      ),
                    const SizedBox(height: 10),
                    // Layout: wrapping CTAs keep unequal heights and
                    // long Arabic labels from overflowing on narrow
                    // screens at large text scales.
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      FilledButton(
                        onPressed: () => Navigator.pushNamed(
                            context, '/screening'),
                        child: Text(s.startScreening),
                      ),
                      OutlinedButton(
                        onPressed: () => Navigator.pushNamed(
                            context, '/camera-help'),
                        child: Text(s.firstRunCameraHelp),
                      ),
                    ]),
                  ] else ...[
                    Text(_lastDate!,
                        style: t.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                        '${s.homeTestsLine(_testCount)} • ${s.homeFindingsLine(_findingCount)}',
                        style: t.bodyMedium),
                    if (_unableCount > 0)
                      Text(s.homeSummaryLine(_lastDate!, _testCount,
                          _findingCount, _unableCount),
                          style: t.bodySmall),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/history'),
                      icon: const Icon(Icons.arrow_forward_outlined,
                          size: 18),
                      label: Text(s.viewDetails),
                      style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerLeft),
                    ),
                  ],
                ]),
          ),
        ),
        const SizedBox(height: 28),
        _SectionHead(title: s.homeVisionTitle, t: t),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF5F4),
                  border: Border.all(
                      color: const Color(0xFF0E7C7B)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.visibility_outlined,
                    color: Color(0xFF0A5E5D), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.homeVisionBody, style: t.titleMedium),
                      const SizedBox(height: 6),
                      TextButton.icon(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/vision'),
                        icon: const Icon(Icons.arrow_forward_outlined,
                            size: 18),
                        label: Text(s.homeVisionOpen),
                        style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            padding: EdgeInsets.zero,
                            alignment: Alignment.centerLeft),
                      ),
                    ]),
              ),
            ]),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF5F4),
                  border: Border.all(
                      color: const Color(0xFF0E7C7B)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.biotech_outlined,
                    color: Color(0xFF0A5E5D), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.capHomeTitle, style: t.titleMedium),
                      const SizedBox(height: 2),
                      Text(s.capHomeBody, style: t.bodySmall),
                      const SizedBox(height: 6),
                      TextButton.icon(
                        onPressed: () => Navigator.pushNamed(
                            context, '/capabilities'),
                        icon: const Icon(Icons.arrow_forward_outlined,
                            size: 18),
                        label: Text(s.capHomeOpen),
                        style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            padding: EdgeInsets.zero,
                            alignment: Alignment.centerLeft),
                      ),
                    ]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 28),
        _SectionHead(title: s.homeLearnTitle, t: t),        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF5F4),
                  border: Border.all(
                      color: const Color(0xFF0E7C7B)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.school_outlined,
                    color: Color(0xFF0A5E5D), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.homeLearnBody, style: t.titleMedium),
                      const SizedBox(height: 6),
                      TextButton.icon(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/learn'),
                        icon: const Icon(Icons.arrow_forward_outlined,
                            size: 18),
                        label: Text(s.homeLearnOpen),
                        style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            padding: EdgeInsets.zero,
                            alignment: Alignment.centerLeft),
                      ),
                    ]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 28),
        _SectionHead(title: s.homeHowTitle, t: t),
        const SizedBox(height: 8),
        Text(s.homeHowBody, style: t.bodyMedium),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/methodology'),
          icon: const Icon(Icons.architecture_outlined),
          label: Text(s.homeHowOpen),
        ),
        const SizedBox(height: 28),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              const Icon(Icons.science_outlined,
                  color: Color(0xFF0A5E5D)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  s.researchStatus(settings.researchMode),
                  style: t.bodyMedium,
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        SafetyBanner(text: s.disclaimer),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (i) {
          if (i == 0) return;
          const routes = ['/home', '/screening', '/vision', '/history', '/learn', '/settings'];
          Navigator.pushNamed(context, routes[i]);
        },
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), label: tabs[0]),
          NavigationDestination(icon: const Icon(Icons.center_focus_strong), label: tabs[1]),
          NavigationDestination(icon: const Icon(Icons.visibility_outlined), label: tabs[2]),
          NavigationDestination(icon: const Icon(Icons.history), label: tabs[3]),
          NavigationDestination(icon: const Icon(Icons.school_outlined), label: tabs[4]),
          NavigationDestination(icon: const Icon(Icons.settings_outlined), label: tabs[5]),
        ],
      ),
    );
  }
}

class _SectionHead extends StatelessWidget {
  final String title;
  final TextTheme t;
  const _SectionHead({required this.title, required this.t});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 3, height: 20, color: const Color(0xFF0E7C7B)),
      const SizedBox(width: 10),
      Text(title,
          style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
    ]);
  }
}
