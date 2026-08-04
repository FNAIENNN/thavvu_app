// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'device_file_picker_models.dart';

Future<PickedDeviceFile?> pickHodMapDeviceFileImpl() async {
  final input = html.FileUploadInputElement()
    ..accept = '.pdf,.jpg,.jpeg,.png,application/pdf,image/jpeg,image/png'
    ..multiple = false;

  input.click();

  final event = await input.onChange.first.timeout(
    const Duration(minutes: 5),
    onTimeout: () => html.Event('timeout'),
  );
  if (event.type == 'timeout' || input.files == null || input.files!.isEmpty) {
    return null;
  }

  final file = input.files!.first;
  final extension = fileExtension(file.name);
  if (!isAllowedHodMapExtension(extension)) {
    return PickedDeviceFile(
      name: file.name,
      extension: extension,
      size: file.size,
      bytes: Uint8List(0),
    );
  }

  final bytes = await _readFileBytes(file);
  return PickedDeviceFile(
    name: file.name,
    extension: extension,
    size: file.size,
    bytes: bytes,
  );
}

Future<Uint8List> _readFileBytes(html.File file) {
  final completer = Completer<Uint8List>();
  final reader = html.FileReader();

  reader.onError.first.then((_) {
    if (!completer.isCompleted) {
      completer.completeError(StateError('Unable to read selected file.'));
    }
  });

  reader.onLoadEnd.first.then((_) {
    if (completer.isCompleted) return;
    final result = reader.result;
    if (result is ByteBuffer) {
      completer.complete(Uint8List.view(result));
    } else if (result is Uint8List) {
      completer.complete(result);
    } else {
      completer.completeError(StateError('Selected file data is empty.'));
    }
  });

  reader.readAsArrayBuffer(file);
  return completer.future;
}
