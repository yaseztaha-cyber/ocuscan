// Camera Setup Help: lighting, distance, glasses, position, movement,
// background + front/rear guidance. Small diagram headers, calm tone,
// fully localized. No giant text blocks.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/localization/app_strings.dart';
import '../../main.dart';
import '../widgets/common.dart';

class CameraHelpScreen extends StatelessWidget {
  const CameraHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(context.watch<AppState>().lang);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(s.camHelpTitle)),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        _HelpRow(
            icon: Icons.wb_sunny_outlined,
            title: s.camHelpLightTitle,
            body: s.camHelpLightBody,
            t: t),
        _HelpRow(
            icon: Icons.straighten_outlined,
            title: s.camHelpDistanceTitle,
            body: s.camHelpDistanceBody,
            t: t),
        _HelpRow(
            icon: Icons.remove_red_eye_outlined,
            title: s.camHelpGlassesTitle,
            body: s.camHelpGlassesBody,
            t: t),
        _HelpRow(
            icon: Icons.center_focus_strong,
            title: s.camHelpPositionTitle,
            body: s.camHelpPositionBody,
            t: t),
        _HelpRow(
            icon: Icons.front_hand_outlined,
            title: s.camHelpMovementTitle,
            body: s.camHelpMovementBody,
            t: t),
        _HelpRow(
            icon: Icons.wallpaper_outlined,
            title: s.camHelpBackgroundTitle,
            body: s.camHelpBackgroundBody,
            t: t),
        SectionTitle(s.camHelpFrontTitle),
        Text(s.camHelpFrontBody, style: t.bodyMedium),
        SectionTitle(s.camHelpRearTitle),
        Text(s.camHelpRearBody, style: t.bodyMedium),
        SectionTitle(s.camHelpWhichTitle),
        Text(s.camHelpWhichBody, style: t.bodyMedium),
        const SizedBox(height: 16),
        FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.back)),
      ]),
    );
  }
}

class CameraPermissionRationaleCard extends StatelessWidget {
  final VoidCallback onContinue;
  final VoidCallback onHelp;
  const CameraPermissionRationaleCard(
      {super.key, required this.onContinue, required this.onHelp});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(context.watch<AppState>().lang);
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.videocam_outlined,
                    color: Color(0xFF0A5E5D)),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(s.camRationaleTitle,
                        style: t.titleMedium)),
              ]),
              const SizedBox(height: 8),
              Text(s.camRationaleBody, style: t.bodyMedium),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton(
                    onPressed: onContinue,
                    child: Text(s.camRationaleContinue)),
                OutlinedButton(
                    onPressed: onHelp, child: Text(s.cameraHelpBtn)),
              ]),
            ]),
      ),
    );
  }
}

class _HelpRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final TextTheme t;
  const _HelpRow(
      {required this.icon,
      required this.title,
      required this.body,
      required this.t});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFEDF5F4),
            border:
                Border.all(color: const Color(0xFF0E7C7B)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF0A5E5D), size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.titleMedium),
                const SizedBox(height: 2),
                Text(body, style: t.bodyMedium),
              ]),
        ),
      ]),
    );
  }
}
