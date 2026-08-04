import 'device_file_picker_stub.dart'
    if (dart.library.io) 'device_file_picker_io.dart'
    if (dart.library.html) 'device_file_picker_web.dart';
import 'device_file_picker_models.dart';

export 'device_file_picker_models.dart';

Future<PickedDeviceFile?> pickHodMapDeviceFile() {
  return pickHodMapDeviceFileImpl();
}
