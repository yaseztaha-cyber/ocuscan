// Anonymous research device metadata (v0.2).
//
// Records the INSTRUMENT (manufacturer, model, OS, camera, resolution,
// screen size), never the person. No names, no identity, no biometrics.
// All fields are nullable: whatever the platform cannot provide stays empty
// rather than guessed.

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'experiment_models.dart';

/// Collect a device snapshot for a research session.
/// [deviceLabel] is the researcher's anonymous label (Device A, B, C...).
/// [camera]/[resolution]/[orientation]/screen size document the instrument
/// configuration used for the session.
Future<DeviceProfile> collectDeviceProfile({
  required String deviceLabel,
  String? camera,
  String? resolution,
  String? orientation,
  int? screenWidthPx,
  int? screenHeightPx,
}) async {
  String? manufacturer, model, osVersion;
  try {
    final plugin = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final a = await plugin.androidInfo;
      manufacturer = a.manufacturer;
      model = a.model;
      osVersion = 'Android ${a.version.release} (SDK ${a.version.sdkInt})';
    } else if (Platform.isIOS) {
      final i = await plugin.iosInfo;
      manufacturer = 'Apple';
      model = i.model;
      osVersion = '${i.systemName} ${i.systemVersion}';
    } else {
      osVersion = Platform.operatingSystemVersion;
    }
  } catch (_) {
    try {
      osVersion = Platform.operatingSystemVersion;
    } catch (_) {}
  }
  return DeviceProfile(
    deviceLabel: deviceLabel,
    manufacturer: manufacturer,
    model: model,
    osVersion: osVersion,
    runtimeVersion: Platform.version.split(' ').first,
    camera: camera,
    resolution: resolution,
    orientation: orientation,
    screenWidthPx: screenWidthPx,
    screenHeightPx: screenHeightPx,
  );
}
