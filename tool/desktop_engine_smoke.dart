import 'package:croc/src/model/transfer_models.dart';
import 'package:croc/src/services/croc_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'transfers through the desktop engine',
    () async {
      const helper = 'build/linux/x64/debug/bundle/crocbridge-helper';
      const relay = RelaySettings(
        address: '127.0.0.1:9009',
        ports: '9009,9010,9011,9012,9013',
        password: 'pass123',
      );
      final sender = DesktopCrocEngine(helperPath: helper);
      final receiver = DesktopCrocEngine(helperPath: helper);
      final senderEvents = <String>[];
      final receiverEvents = <String>[];
      sender.events.listen((event) => senderEvents.add(event.type));
      receiver.events.listen((event) => receiverEvents.add(event.type));

      final receiving = receiver.receive(
        code: '4826-dart-desktop-smoke',
        stagingDirectory: '/tmp/opencode/croc-dart-smoke',
        relay: relay,
      );
      await Future<void>.delayed(const Duration(seconds: 2));
      await Future.wait([
        receiving,
        sender.send(
          code: '4826-dart-desktop-smoke',
          paths: const ['third_party/crocgui-LICENSE'],
          relay: relay,
        ),
      ]);

      expect(senderEvents, contains('complete'));
      expect(receiverEvents, containsAll(['received', 'complete']));
    },
    timeout: const Timeout(Duration(seconds: 20)),
  );
}
