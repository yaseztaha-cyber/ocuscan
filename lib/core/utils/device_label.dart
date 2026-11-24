// Best-effort local device label for result provenance. Never throws:
// unknown platforms, missing plugins (tests), and permission issues all
// yield an empty label ("not recorded") rather than invented data.
import 'package:device_info_plus/device_info_plus.dart';

Future<String> localDeviceLabel() async {
  try {
    final info = await DeviceInfoPlugin().androidInfo;
    return '${info.manufacturer} ${info.model}'.trim();
  } catch (_) {
    return '';
  }
}
