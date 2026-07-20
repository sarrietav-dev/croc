import 'dart:async';

import 'package:croc/src/app_controller.dart';
import 'package:croc/src/model/transfer_models.dart';
import 'package:croc/src/services/croc_engine.dart';
import 'package:croc/src/ui/croc_app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('moves between the primary transfer flows', (tester) async {
    final controller = AppController(engine: FakeCrocEngine());
    await controller.initialize();

    await tester.pumpWidget(CrocApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Send files'), findsOneWidget);
    expect(find.text('Send securely'), findsOneWidget);

    await tester.tap(find.text('Receive'));
    await tester.pumpAndSettle();

    expect(find.text('Receive files'), findsOneWidget);
    expect(find.text('Receive securely'), findsOneWidget);
  });

  test('decodes progress events from the native bridge', () {
    final event = CrocEvent.fromEncoded(
      '{"type":"progress","name":"photo.jpg","done":512,"total":1024,'
      '"fileIndex":0,"fileCount":2}',
    );

    expect(event.type, 'progress');
    expect(event.name, 'photo.jpg');
    expect(event.done, 512);
    expect(event.total, 1024);
    expect(event.fileCount, 2);
  });

  test('formats file sizes for transfer summaries', () {
    expect(formatBytes(512), '512 B');
    expect(formatBytes(1536), '1.50 KB');
    expect(formatBytes(5 * 1024 * 1024), '5.00 MB');
  });
}

class FakeCrocEngine implements CrocEngine {
  final _events = StreamController<CrocEvent>.broadcast();

  @override
  Stream<CrocEvent> get events => _events.stream;

  @override
  Future<void> cancel() async {}

  @override
  Future<List<SelectedFile>> pickFiles() async => const [];

  @override
  Future<String> generateCode() async => 'quiet-forest-river';

  @override
  Future<void> receive({
    required String code,
    required String stagingDirectory,
    required RelaySettings relay,
  }) async {}

  @override
  Future<bool> saveFile(ReceivedFile file) async => true;

  @override
  Future<void> shareFile(ReceivedFile file) async {}

  @override
  Future<void> send({
    required String code,
    required List<String> paths,
    required RelaySettings relay,
  }) async {}
}
