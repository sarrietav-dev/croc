import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../model/transfer_models.dart';
import 'croc_engine.dart';

class WebCrocEngine implements CrocEngine {
  WebCrocEngine({http.Client? client}) : _client = client ?? http.Client();

  static const _configuredBaseUrl = String.fromEnvironment(
    'CROC_WEB_BRIDGE_URL',
  );
  final http.Client _client;
  final _events = StreamController<CrocEvent>.broadcast();
  final Map<String, PlatformFile> _selectedFiles = {};
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
          _selectedFiles[id] = file;
          return SelectedFile(name: file.name, path: id, size: file.size);
        })
        .toList(growable: false);
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
    for (final path in paths) {
      final file = _selectedFiles[path];
      if (file?.bytes == null) {
        throw PlatformException(
          code: 'file-unavailable',
          message: 'A selected file is no longer available. Select it again.',
        );
      }
      request.files.add(
        http.MultipartFile.fromBytes(
          'files',
          file!.bytes!,
          filename: file.name,
        ),
      );
    }
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
}
