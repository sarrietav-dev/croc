import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../model/transfer_models.dart';

abstract interface class CrocEngine {
  Stream<CrocEvent> get events;

  Future<String> generateCode();

  Future<void> send({
    required String code,
    required List<String> paths,
    required RelaySettings relay,
  });

  Future<void> receive({
    required String code,
    required String stagingDirectory,
    required RelaySettings relay,
  });

  Future<void> cancel();

  Future<List<SelectedFile>> pickFiles();

  Future<List<SelectedFile>> pickFolder();

  Future<SelectedFile> createTextFile(String text, {required String name});

  Future<bool> saveFile(ReceivedFile file);

  Future<void> shareFile(ReceivedFile file);
}

class NativeCrocEngine implements CrocEngine {
  static const _control = MethodChannel('dev.sarrietav.croc/control');
  static const _eventChannel = EventChannel('dev.sarrietav.croc/events');

  late final Stream<CrocEvent> _events = _eventChannel
      .receiveBroadcastStream()
      .cast<String>()
      .map(CrocEvent.fromEncoded);

  @override
  Stream<CrocEvent> get events => _events;

  @override
  Future<String> generateCode() async {
    return (await _control.invokeMethod<String>('generateCode'))!;
  }

  @override
  Future<void> send({
    required String code,
    required List<String> paths,
    required RelaySettings relay,
  }) {
    return _control.invokeMethod<void>('startSend', {
      'code': code,
      'paths': jsonEncode(paths),
      ..._relayArguments(relay),
    });
  }

  @override
  Future<void> receive({
    required String code,
    required String stagingDirectory,
    required RelaySettings relay,
  }) {
    return _control.invokeMethod<void>('startReceive', {
      'code': code,
      'stagingDirectory': stagingDirectory,
      ..._relayArguments(relay),
    });
  }

  @override
  Future<void> cancel() => _control.invokeMethod<void>('cancel');

  @override
  Future<List<SelectedFile>> pickFiles() async {
    final files =
        await _control.invokeListMethod<Object?>('pickFiles') ?? const [];
    return files
        .cast<Map<Object?, Object?>>()
        .map(
          (file) => SelectedFile(
            name: file['name']! as String,
            path: file['path']! as String,
            size: (file['size']! as num).toInt(),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<SelectedFile>> pickFolder() async {
    final files =
        await _control.invokeListMethod<Object?>('pickFolder') ?? const [];
    return files
        .cast<Map<Object?, Object?>>()
        .map(_selectedFileFromMap)
        .toList(growable: false);
  }

  @override
  Future<SelectedFile> createTextFile(
    String text, {
    required String name,
  }) async {
    final file = await _control.invokeMapMethod<Object?, Object?>(
      'createTextFile',
      {'text': text, 'name': name},
    );
    if (file == null) {
      throw PlatformException(
        code: 'text_file_failed',
        message: 'Unable to prepare the text for transfer.',
      );
    }
    return _selectedFileFromMap(file);
  }

  @override
  Future<bool> saveFile(ReceivedFile file) async {
    return await _control.invokeMethod<bool>('saveFile', {
          'path': file.path,
          'name': file.name,
        }) ??
        false;
  }

  @override
  Future<void> shareFile(ReceivedFile file) {
    return _control.invokeMethod<void>('shareFile', {
      'path': file.path,
      'name': file.name,
    });
  }

  Map<String, String> _relayArguments(RelaySettings relay) => {
    'relayAddress': relay.address,
    'relayPorts': relay.ports,
    'relayPassword': relay.password,
  };

  SelectedFile _selectedFileFromMap(Map<Object?, Object?> file) => SelectedFile(
    name: file['name']! as String,
    path: file['path']! as String,
    size: (file['size']! as num).toInt(),
  );
}

class CrocEvent {
  const CrocEvent({
    required this.type,
    this.stage,
    this.name,
    this.done = 0,
    this.total = 0,
    this.fileIndex = 0,
    this.fileCount = 0,
    this.files = const [],
    this.message,
    this.wasCanceled = false,
  });

  factory CrocEvent.fromEncoded(String encoded) {
    final json = jsonDecode(encoded) as Map<String, Object?>;
    final files = (json['files'] as List<Object?>? ?? const [])
        .cast<Map<Object?, Object?>>()
        .map((file) => ReceivedFile.fromJson(file.cast<String, Object?>()))
        .toList(growable: false);
    return CrocEvent(
      type: json['type']! as String,
      stage: json['stage'] as String?,
      name: json['name'] as String?,
      done: (json['done'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
      fileIndex: (json['fileIndex'] as num?)?.toInt() ?? 0,
      fileCount: (json['fileCount'] as num?)?.toInt() ?? 0,
      files: files,
      message: json['message'] as String?,
      wasCanceled: json['wasCanceled'] as bool? ?? false,
    );
  }

  final String type;
  final String? stage;
  final String? name;
  final int done;
  final int total;
  final int fileIndex;
  final int fileCount;
  final List<ReceivedFile> files;
  final String? message;
  final bool wasCanceled;
}
