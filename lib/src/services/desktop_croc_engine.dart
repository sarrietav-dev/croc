import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

import '../model/transfer_models.dart';
import 'croc_engine.dart';

class DesktopCrocEngine implements CrocEngine {
  DesktopCrocEngine({String? helperPath}) : _configuredHelperPath = helperPath;

  final String? _configuredHelperPath;
  final _events = StreamController<CrocEvent>.broadcast();
  Process? _process;

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
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null) return const [];
    return result.files
        .where((file) => file.path != null)
        .map(
          (file) =>
              SelectedFile(name: file.name, path: file.path!, size: file.size),
        )
        .toList(growable: false);
  }

  @override
  Future<void> send({
    required String code,
    required List<String> paths,
    required RelaySettings relay,
  }) => _run({
    'method': 'send',
    'code': code,
    'paths': paths,
    ..._relayArguments(relay),
  });

  @override
  Future<void> receive({
    required String code,
    required String stagingDirectory,
    required RelaySettings relay,
  }) => _run({
    'method': 'receive',
    'code': code,
    'stagingDirectory': stagingDirectory,
    ..._relayArguments(relay),
  });

  @override
  Future<void> cancel() async {
    final process = _process;
    if (process == null) return;
    process.stdin.writeln(jsonEncode({'method': 'cancel'}));
    await process.stdin.flush();
  }

  @override
  Future<bool> saveFile(ReceivedFile file) async {
    final bytes = await File(file.path).readAsBytes();
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save ${file.name}',
      fileName: file.name,
      bytes: bytes,
    );
    return path != null;
  }

  @override
  Future<void> shareFile(ReceivedFile file) async {
    if (Platform.isWindows) {
      await Process.start('explorer.exe', ['/select,${file.path}']);
      return;
    }
    if (Platform.isLinux) {
      await Process.start('xdg-open', [File(file.path).parent.path]);
      return;
    }
    throw PlatformException(
      code: 'unsupported-platform',
      message: 'Opening received files is not supported on this platform.',
    );
  }

  Future<void> _run(Map<String, Object?> request) async {
    if (_process != null) {
      throw PlatformException(
        code: 'transfer-active',
        message: 'A transfer is already active.',
      );
    }

    Process process;
    try {
      process = await Process.start(_helperPath, const []);
    } on ProcessException catch (error) {
      throw PlatformException(
        code: 'helper-unavailable',
        message:
            'The desktop transfer engine could not start. Rebuild or reinstall Croc. ${error.message}',
      );
    }

    _process = process;
    final errors = process.stderr.transform(utf8.decoder).join('\n');
    final output = _consumeEvents(process.stdout);
    try {
      process.stdin.writeln(jsonEncode(request));
      await process.stdin.flush();
      final exitCode = await process.exitCode;
      final sawTerminalEvent = await output;
      final errorOutput = (await errors).trim();
      if (exitCode != 0 || !sawTerminalEvent) {
        throw PlatformException(
          code: 'helper-failed',
          message: errorOutput.isEmpty
              ? 'The desktop transfer engine stopped unexpectedly.'
              : errorOutput,
        );
      }
    } finally {
      await process.stdin.close();
      if (identical(_process, process)) _process = null;
    }
  }

  Future<bool> _consumeEvents(Stream<List<int>> output) async {
    var sawTerminalEvent = false;
    await for (final line
        in output.transform(utf8.decoder).transform(const LineSplitter())) {
      try {
        final event = CrocEvent.fromEncoded(line);
        sawTerminalEvent |= event.type == 'failed' || event.type == 'complete';
        _events.add(event);
      } on FormatException {
        // The protocol ignores any unexpected output from native dependencies.
      }
    }
    return sawTerminalEvent;
  }

  String get _helperPath =>
      _configuredHelperPath ??
      '${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}'
          'crocbridge-helper${Platform.isWindows ? '.exe' : ''}';

  Map<String, String> _relayArguments(RelaySettings relay) => {
    'relayAddress': relay.address,
    'relayPorts': relay.ports,
    'relayPassword': relay.password,
  };
}
