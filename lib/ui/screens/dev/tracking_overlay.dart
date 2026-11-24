// Research-only tracking overlay ("Show Tracking").
//
// Displays what the on-device face tracker actually reports for the current
// frame: face presence, head yaw, centering, face fraction, per-eye openness.
// No clinical interpretation is attached to this debugging view.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/dev_strings.dart';
import '../../../features/camera/camera_service.dart';

class TrackingOverlay extends StatelessWidget {
  const TrackingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final cam = context.watch<CameraService>();
    final s = DevStrings.of(context);
    final f = cam.lastFrame;
    final t = Theme.of(context).textTheme;
    if (f == null) {
      return Card(
          child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(s.trackerNoFrame),
      ));
    }
    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Expanded(child: Text(k, style: t.bodyMedium)),
            Text(v,
                style:
                    t.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          ]),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.trackerStateTitle,
              style: t.titleMedium),
          const SizedBox(height: 6),
          row('face found', f.faceFound ? 'yes' : 'no'),
          row('head yaw', '${f.yawDeg.toStringAsFixed(1)}°'),
          row('centered', f.centered ? 'yes' : 'no'),
          row('face fraction', f.faceFraction.toStringAsFixed(2)),
          row('both eyes open', f.bothEyesOpen ? 'yes' : 'no'),
          row('left eye openness', f.leftEyeOpenProb.toStringAsFixed(2)),
          row('right eye openness', f.rightEyeOpenProb.toStringAsFixed(2)),
          const SizedBox(height: 6),
          Text(
              'Verify the tracker follows the correct points before trusting any measurement from this frame.',
              style: t.bodySmall),
        ]),
      ),
    );
  }
}
