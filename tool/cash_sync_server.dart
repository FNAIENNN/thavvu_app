import 'dart:convert';
import 'dart:io';

const _defaultPort = 8787;
const _storeFileName = '.thavvu_cash_sync_store.json';

Future<void> main(List<String> args) async {
  final port = _portFromArgs(args);
  final file = File(_storeFileName);
  final store = await _readStore(file);
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);

  stdout.writeln('Thavvu cash sync server running at http://localhost:$port');
  stdout.writeln('Store file: ${file.absolute.path}');

  await for (final request in server) {
    await _handleRequest(request, store, file);
  }
}

Future<void> _handleRequest(
  HttpRequest request,
  Map<String, String> store,
  File file,
) async {
  _setCorsHeaders(request.response);

  if (request.method == 'OPTIONS') {
    request.response
      ..statusCode = HttpStatus.noContent
      ..close();
    return;
  }

  final segments = request.uri.pathSegments;
  if (segments.length != 2 || segments.first != 'store') {
    request.response
      ..statusCode = HttpStatus.notFound
      ..write('Not found')
      ..close();
    return;
  }

  final key = segments[1];
  switch (request.method) {
    case 'GET':
      final value = store[key];
      if (value == null) {
        request.response.statusCode = HttpStatus.notFound;
      } else {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType =
              ContentType('application', 'json', charset: 'utf-8')
          ..write(value);
      }
      break;
    case 'PUT':
      final value = await utf8.decoder.bind(request).join();
      store[key] = value;
      await _writeStore(file, store);
      request.response.statusCode = HttpStatus.noContent;
      break;
    case 'DELETE':
      store.remove(key);
      await _writeStore(file, store);
      request.response.statusCode = HttpStatus.noContent;
      break;
    default:
      request.response.statusCode = HttpStatus.methodNotAllowed;
  }

  await request.response.close();
}

void _setCorsHeaders(HttpResponse response) {
  response.headers
    ..set('Access-Control-Allow-Origin', '*')
    ..set('Access-Control-Allow-Methods', 'GET, PUT, DELETE, OPTIONS')
    ..set('Access-Control-Allow-Headers', 'Content-Type');
}

Future<Map<String, String>> _readStore(File file) async {
  if (!await file.exists()) return <String, String>{};

  final decoded = jsonDecode(await file.readAsString());
  if (decoded is! Map) return <String, String>{};

  return decoded.map(
    (key, value) => MapEntry(key.toString(), value.toString()),
  );
}

Future<void> _writeStore(File file, Map<String, String> store) async {
  const encoder = JsonEncoder.withIndent('  ');
  await file.writeAsString(encoder.convert(store));
}

int _portFromArgs(List<String> args) {
  final index = args.indexOf('--port');
  if (index == -1 || index + 1 >= args.length) return _defaultPort;
  return int.tryParse(args[index + 1]) ?? _defaultPort;
}
