import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'model/transfer_models.dart';
import 'services/croc_engine.dart';
import 'services/engine_factory.dart';
import 'services/settings_store.dart';
import 'services/staging_directory.dart';

class AppController extends ChangeNotifier {
  AppController({CrocEngine? engine, SettingsStore? settingsStore})
    : _engine = engine ?? createDefaultCrocEngine(),
      _settingsStore = settingsStore ?? SettingsStore();

  final CrocEngine _engine;
  final SettingsStore _settingsStore;
  StreamSubscription<CrocEvent>? _eventSubscription;

  int destination = 0;
  bool initialized = false;
  bool pickingFiles = false;
  TransferPhase phase = TransferPhase.idle;
  String code = '';
  String status = 'Ready when you are';
  String? errorMessage;
  RelaySettings relay = const RelaySettings();
  TransferProgress progress = const TransferProgress();
  List<SelectedFile> selectedFiles = [];
  List<ReceivedFile> receivedFiles = [];

  bool get isBusy => switch (phase) {
    TransferPhase.preparing ||
    TransferPhase.waiting ||
    TransferPhase.transferring ||
    TransferPhase.canceling => true,
    _ => false,
  };

  int get selectedBytes =>
      selectedFiles.fold(0, (sum, file) => sum + file.size);

  Future<void> initialize() async {
    _eventSubscription = _engine.events.listen(
      _handleEvent,
      onError: (Object error) => _fail(_messageFor(error)),
    );
    try {
      relay = await _settingsStore.load();
      code = await _engine.generateCode();
    } on MissingPluginException {
      code = 'swift-orchid-river';
    }
    initialized = true;
    notifyListeners();
  }

  void setDestination(int value) {
    if (destination == value) return;
    destination = value;
    errorMessage = null;
    notifyListeners();
  }

  void setCode(String value) {
    code = value.trim().replaceAll(' ', '-');
    notifyListeners();
  }

  Future<void> regenerateCode() async {
    if (isBusy) return;
    code = await _engine.generateCode();
    notifyListeners();
  }

  Future<void> copyCode() async {
    await Clipboard.setData(ClipboardData(text: code));
    status = 'Code copied';
    notifyListeners();
  }

  Future<void> pickFiles() async {
    await _pick(_engine.pickFiles);
  }

  Future<void> pickFolder() async {
    await _pick(_engine.pickFolder);
  }

  Future<void> addText(String text) async {
    if (isBusy || pickingFiles || text.isEmpty) return;
    await _addPreparedFile(
      () => _engine.createTextFile(text, name: 'text.txt'),
    );
  }

  Future<void> pasteText() async {
    if (isBusy || pickingFiles) return;
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    if (text == null || text.isEmpty) {
      _fail('The clipboard does not contain text.');
      return;
    }
    await _addPreparedFile(
      () => _engine.createTextFile(text, name: 'clipboard.txt'),
    );
  }

  Future<void> _pick(Future<List<SelectedFile>> Function() picker) async {
    if (isBusy || pickingFiles) return;
    pickingFiles = true;
    notifyListeners();
    try {
      final additions = await picker();
      if (additions.isEmpty) return;
      final byPath = {for (final file in selectedFiles) file.path: file};
      for (final file in additions) {
        byPath[file.path] = file;
      }
      selectedFiles = byPath.values.toList(growable: false);
      status =
          '${selectedFiles.length} file${selectedFiles.length == 1 ? '' : 's'} selected';
    } catch (error) {
      _fail(_messageFor(error));
    } finally {
      pickingFiles = false;
      notifyListeners();
    }
  }

  Future<void> _addPreparedFile(Future<SelectedFile> Function() prepare) async {
    pickingFiles = true;
    notifyListeners();
    try {
      final file = await prepare();
      selectedFiles = [
        ...selectedFiles.where((item) => item.path != file.path),
        file,
      ];
      status =
          '${selectedFiles.length} file${selectedFiles.length == 1 ? '' : 's'} selected';
    } catch (error) {
      _fail(_messageFor(error));
    } finally {
      pickingFiles = false;
      notifyListeners();
    }
  }

  void removeFile(SelectedFile file) {
    if (isBusy) return;
    selectedFiles = selectedFiles
        .where((item) => item.path != file.path)
        .toList();
    notifyListeners();
  }

  Future<void> startSend() async {
    if (isBusy || selectedFiles.isEmpty || code.length < 6) return;
    _begin('Preparing your files');
    try {
      await _engine.send(
        code: code,
        paths: selectedFiles.map((file) => file.path).toList(growable: false),
        relay: relay,
      );
    } catch (error) {
      if (phase != TransferPhase.canceled && phase != TransferPhase.completed) {
        _fail(_messageFor(error));
      }
    }
  }

  Future<void> startReceive() async {
    if (isBusy || code.length < 6) return;
    _begin('Finding the sender');
    receivedFiles = [];
    try {
      await _engine.receive(
        code: code,
        stagingDirectory: await createStagingDirectory(),
        relay: relay,
      );
    } catch (error) {
      if (phase != TransferPhase.canceled && phase != TransferPhase.completed) {
        _fail(_messageFor(error));
      }
    }
  }

  Future<void> cancel() async {
    if (!isBusy) return;
    phase = TransferPhase.canceling;
    status = 'Canceling safely';
    notifyListeners();
    await _engine.cancel();
  }

  Future<bool> saveFile(ReceivedFile file) => _engine.saveFile(file);

  Future<void> shareFile(ReceivedFile file) async {
    await _engine.shareFile(file);
  }

  Future<void> saveRelay(RelaySettings value) async {
    relay = value;
    await _settingsStore.save(value);
    status = 'Relay settings saved';
    notifyListeners();
  }

  void resetTransfer() {
    if (isBusy) return;
    phase = TransferPhase.idle;
    progress = const TransferProgress();
    errorMessage = null;
    status = 'Ready when you are';
    notifyListeners();
  }

  void _begin(String message) {
    phase = TransferPhase.preparing;
    progress = const TransferProgress();
    errorMessage = null;
    status = message;
    notifyListeners();
  }

  void _handleEvent(CrocEvent event) {
    switch (event.type) {
      case 'stage':
        phase = TransferPhase.waiting;
        status = event.stage ?? 'Connecting';
      case 'progress':
        phase = TransferPhase.transferring;
        progress = TransferProgress(
          fileName: event.name ?? '',
          bytesDone: event.done,
          bytesTotal: event.total,
          fileIndex: event.fileIndex,
          fileCount: event.fileCount,
        );
        status = destination == 0 ? 'Sending securely' : 'Receiving securely';
      case 'received':
        receivedFiles = event.files;
      case 'failed':
        if (event.wasCanceled) {
          phase = TransferPhase.canceled;
          status = 'Transfer canceled';
        } else {
          _fail(event.message ?? 'Transfer failed');
        }
      case 'complete':
        phase = TransferPhase.completed;
        status = destination == 0 ? 'Files sent' : 'Files received';
    }
    notifyListeners();
  }

  void _fail(String message) {
    phase = TransferPhase.failed;
    errorMessage = message;
    status = 'Something went wrong';
    notifyListeners();
  }

  String _messageFor(Object error) {
    if (error is PlatformException) {
      return error.message ?? 'Transfer failed';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }
}
