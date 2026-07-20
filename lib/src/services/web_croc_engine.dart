import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

import '../model/transfer_models.dart';
import 'croc_engine.dart';

class WebCrocEngine implements CrocEngine {
  WebCrocEngine({http.Client? client}) : _client = client ?? http.Client();

  static const _configuredBaseUrl = String.fromEnvironment(
    'CROC_WEB_BRIDGE_URL',
  );
  final http.Client _client;
  final _events = StreamController<CrocEvent>.broadcast();
  final Map<String, List<_WebFile>> _selectedFiles = {};
  String? _activeTransferId;

  @override
  Stream<CrocEvent> get events => _events.stream;

  @override
  Future<String> generateCode() async {
    final random = Random.secure();
    final bytes = List.generate(8, (_) => random.nextInt(256));
    final encoded = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return List.generate(
      4,
      (index) => encoded.substring(index * 4, index * 4 + 4),
    ).join('-');
  }

  @override
  Future<List<SelectedFile>> pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return const [];
    return result.files
        .map((file) {
          if (file.bytes == null) {
            throw PlatformException(
              code: 'file-unavailable',
              message: 'The browser could not read one of the selected files.',
            );
          }
          final id =
              '${DateTime.now().microsecondsSinceEpoch}-${_selectedFiles.length}';
          _selectedFiles[id] = [_WebFile(name: file.name, bytes: file.bytes!)];
          return SelectedFile(name: file.name, path: id, size: file.size);
        })
        .toList(growable: false);
  }

  @override
  Future<List<SelectedFile>> pickFolder() async {
    final input = web.document.createElement('input') as web.HTMLInputElement
      ..type = 'file'
      ..multiple = true
      ..setAttribute('webkitdirectory', '');
    final files = await _openInput(input);
    if (files == null || files.length == 0) return const [];

    final picked = <_WebFile>[];
    for (var index = 0; index < files.length; index++) {
      final file = files.item(index)!;
      final buffer = await file.arrayBuffer().toDart;
      picked.add(
        _WebFile(
          name: file.webkitRelativePath.isEmpty
              ? file.name
              : file.webkitRelativePath,
          bytes: buffer.toDart.asUint8List(),
        ),
      );
    }
    final id = '${DateTime.now().microsecondsSinceEpoch}-folder';
    _selectedFiles[id] = picked;
    final rootName = picked.first.name.split('/').first;
    return [
      SelectedFile(
        name: rootName,
        path: id,
        size: picked.fold(0, (sum, file) => sum + file.bytes.length),
      ),
    ];
  }

  @override
  Future<SelectedFile> createTextFile(
    String text, {
    required String name,
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(text));
    final id = '${DateTime.now().microsecondsSinceEpoch}-text';
    _selectedFiles[id] = [_WebFile(name: name, bytes: bytes)];
    return SelectedFile(name: name, path: id, size: bytes.length);
  }

  @override
  Future<void> send({
    required String code,
    required List<String> paths,
    required RelaySettings relay,
  }) async {
    final request = http.MultipartRequest('POST', _uri('/api/transfers/send'))
      ..fields.addAll({
        'code': code,
        'relayAddress': relay.address,
        'relayPorts': relay.ports,
        'relayPassword': relay.password,
      });
    final relativePaths = <String>[];
    for (final path in paths) {
      final files = _selectedFiles[path];
      if (files == null) {
        throw PlatformException(
          code: 'file-unavailable',
          message: 'A selected file is no longer available. Select it again.',
        );
      }
      for (final file in files) {
        relativePaths.add(file.name);
        request.files.add(
          http.MultipartFile.fromBytes(
            'files',
            file.bytes,
            filename: file.name.split('/').last,
          ),
        );
      }
    }
    request.fields['relativePaths'] = jsonEncode(relativePaths);
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    await _startEventStream(response);
  }

  @override
  Future<void> receive({
    required String code,
    required String stagingDirectory,
    required RelaySettings relay,
  }) async {
    final response = await _client.post(
      _uri('/api/transfers/receive'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'code': code,
        'relay': {
          'address': relay.address,
          'ports': relay.ports,
          'password': relay.password,
        },
      }),
    );
    await _startEventStream(response);
  }

  @override
  Future<void> cancel() async {
    final id = _activeTransferId;
    if (id == null) return;
    final response = await _client.delete(_uri('/api/transfers/$id'));
    if (response.statusCode != 204) _throwResponse(response);
  }

  @override
  Future<bool> saveFile(ReceivedFile file) async {
    final response = await _client.get(_uri(file.path));
    if (response.statusCode != 200) _throwResponse(response);
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Download ${file.name}',
      fileName: file.name,
      bytes: response.bodyBytes,
    );
    return path != null;
  }

  @override
  Future<void> shareFile(ReceivedFile file) async {
    await saveFile(file);
  }

  Future<void> _startEventStream(http.Response response) async {
    if (response.statusCode != 202) _throwResponse(response);
    final payload = jsonDecode(response.body) as Map<String, Object?>;
    final id = payload['id']! as String;
    _activeTransferId = id;
    var terminal = false;
    try {
      final request = http.Request('GET', _uri('/api/transfers/$id/events'));
      final stream = await _client.send(request);
      if (stream.statusCode != 200) {
        final body = await stream.stream.bytesToString();
        throw PlatformException(code: 'bridge-error', message: body.trim());
      }
      await for (final line
          in stream.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (line.isEmpty) continue;
        final event = CrocEvent.fromEncoded(line);
        terminal |= event.type == 'complete' || event.type == 'failed';
        _events.add(event);
      }
      if (!terminal) {
        throw PlatformException(
          code: 'bridge-disconnected',
          message: 'The web transfer bridge disconnected unexpectedly.',
        );
      }
    } finally {
      _activeTransferId = null;
    }
  }

  Uri _uri(String path) {
    if (_configuredBaseUrl.isEmpty) return Uri.base.resolve(path);
    return Uri.parse(
      '${_configuredBaseUrl.replaceFirst(RegExp(r'/$'), '')}$path',
    );
  }

  Never _throwResponse(http.Response response) {
    throw PlatformException(
      code: 'bridge-error',
      message: response.body.trim().isEmpty
          ? 'The web transfer bridge returned HTTP ${response.statusCode}.'
          : response.body.trim(),
    );
  }

  Future<web.FileList?> _openInput(web.HTMLInputElement input) async {
    final completer = Completer<web.FileList?>();
    late final StreamSubscription<web.Event> changeSubscription;
    late final StreamSubscription<web.Event> focusSubscription;
    changeSubscription = input.onChange.listen((_) {
      if (!completer.isCompleted) completer.complete(input.files);
    });
    focusSubscription = web.EventStreamProvider<web.Event>('focus')
        .forTarget(web.window)
        .listen((_) {
          Timer(const Duration(milliseconds: 300), () {
            if (!completer.isCompleted) completer.complete(input.files);
          });
        });
    input.click();
    final result = await completer.future;
    await changeSubscription.cancel();
    await focusSubscription.cancel();
    return result;
  }
}

class _WebFile {
  const _WebFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}
