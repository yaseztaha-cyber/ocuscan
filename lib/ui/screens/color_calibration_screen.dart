import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/localization/app_strings.dart';
import '../../main.dart';
import '../widgets/common.dart';

/// Color Calibration Status screen for scleral-yellowing, eye-redness, and
/// color-vision modules (RGB/HSV/Lab are device-dependent without
/// calibration). Operator-verified checklist — the app claims no sensor
/// readings it cannot actually measure.
class ColorCalibrationScreen extends StatefulWidget {
  const ColorCalibrationScreen({super.key});
  @override
  State<ColorCalibrationScreen> createState() =>
      _ColorCalibrationScreenState();
}

class _ColorCalibrationScreenState extends State<ColorCalibrationScreen> {
  bool neutralLight = false;
  bool noColoredLamps = false;
  bool fullBrightness = false;
  bool nightModeOff = false;
  bool noColorFilters = false;

  String get status {
    final checks = [
      neutralLight,
      noColoredLamps,
      fullBrightness,
      nightModeOff,
      noColorFilters
    ];
    final passed = checks.where((c) => c).length;
    if (passed == checks.length) return 'acceptable';
    if (passed >= 3) return 'uncertain';
    return 'failed';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = AppStrings(context.watch<AppState>().lang);
    return Scaffold(
      appBar: AppBar(title: Text(s.colorCalibration)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SafetyBanner(text: s.calibBanner),
        const SizedBox(height: 8),
        Text(s.calibVerifyHint,
            style: t.bodyMedium),
        CheckboxListTile(
            value: neutralLight,
            onChanged: (v) =>
                setState(() => neutralLight = v ?? false),
            title: Text(s.calibCheckNeutral),
            controlAffinity: ListTileControlAffinity.leading),
        CheckboxListTile(
            value: noColoredLamps,
            onChanged: (v) =>
                setState(() => noColoredLamps = v ?? false),
            title: Text(s.calibCheckNoColored),
            controlAffinity: ListTileControlAffinity.leading),
        CheckboxListTile(
            value: fullBrightness,
            onChanged: (v) =>
                setState(() => fullBrightness = v ?? false),
            title: Text(s.calibCheckBrightness),
            controlAffinity: ListTileControlAffinity.leading),
        CheckboxListTile(
            value: nightModeOff,
            onChanged: (v) =>
                setState(() => nightModeOff = v ?? false),
            title: Text(s.calibCheckNightMode),
            controlAffinity: ListTileControlAffinity.leading),
        CheckboxListTile(
            value: noColorFilters,
            onChanged: (v) =>
                setState(() => noColorFilters = v ?? false),
            title: Text(s.calibCheckNoFilters),
            controlAffinity: ListTileControlAffinity.leading),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.calibStatusTitle(status),
                      style: t.headlineSmall),
                  const SizedBox(height: 4),
                  Text(s.calibMeaning(status)),
                ]),
          ),
        ),
        if (status == 'failed') ...[
          const SizedBox(height: 8),
          SafetyBanner(text: s.calibFailedBanner),
        ],
      ]),
    );
  }
}
