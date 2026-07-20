import 'dart:async';

import 'package:croc/src/app_controller.dart';
import 'package:croc/src/model/transfer_models.dart';
import 'package:croc/src/services/croc_engine.dart';
import 'package:croc/src/services/desktop_croc_engine.dart';
import 'package:croc/src/ui/croc_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('moves between the primary transfer flows', (tester) async {
    setTestWindowSize(tester, const Size(560, 900));
    final controller = AppController(engine: FakeCrocEngine());
    await controller.initialize();

    await tester.pumpWidget(CrocApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Send files'), findsOneWidget);
    expect(find.text('Send securely'), findsOneWidget);
    expect(find.text('File'), findsOneWidget);
    expect(find.text('Folder'), findsOneWidget);
    expect(find.text('Text'), findsOneWidget);
    expect(find.text('Paste'), findsOneWidget);

    await tester.tap(find.text('Receive'));
    await tester.pumpAndSettle();

    expect(find.text('Receive files'), findsOneWidget);
    expect(find.text('Receive securely'), findsOneWidget);
  });

  testWidgets('adds typed text to the selected transfer entries', (
    tester,
  ) async {
    setTestWindowSize(tester, const Size(560, 900));
    final controller = AppController(engine: FakeCrocEngine());
    await controller.initialize();
    await tester.pumpWidget(CrocApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Text'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Hello from Croc');
    await tester.tap(find.text('Add text'));
    await tester.pumpAndSettle();

    expect(find.text('text.txt'), findsOneWidget);
    expect(controller.selectedFiles.single.size, 15);
  });

  testWidgets('shows a QR code for the generated transfer code', (
    tester,
  ) async {
    setTestWindowSize(tester, const Size(560, 900));
    final controller = AppController(engine: FakeCrocEngine());
    await controller.initialize();

    await tester.pumpWidget(CrocApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show QR'));
    await tester.pumpAndSettle();

    expect(find.text('Scan transfer code'), findsOneWidget);
    expect(find.text('quiet-forest-river'), findsWidgets);
    expect(
      find.bySemanticsLabel('QR code for quiet-forest-river'),
      findsOneWidget,
    );
  });

  testWidgets('adapts navigation and workspace across window sizes', (
    tester,
  ) async {
    final controller = AppController(engine: FakeCrocEngine());
    await controller.initialize();

    setTestWindowSize(tester, const Size(560, 900));
    await tester.pumpWidget(CrocApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byKey(const Key('desktop-navigation')), findsNothing);

    tester.view.physicalSize = const Size(900, 720);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byKey(const Key('desktop-navigation')), findsOneWidget);
    expect(find.byKey(const Key('send-workspace-wide')), findsNothing);

    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('send-workspace-wide')), findsOneWidget);
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

  test('desktop engine generates transferable codes locally', () async {
    final code = await DesktopCrocEngine().generateCode();

    expect(code, matches(RegExp(r'^[0-9a-f]{4}(-[0-9a-f]{4}){3}$')));
  });
}

void setTestWindowSize(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
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
  Future<List<SelectedFile>> pickFolder() async => const [];

  @override
  Future<SelectedFile> createTextFile(
    String text, {
    required String name,
  }) async =>
      SelectedFile(name: name, path: 'memory://$name', size: text.length);

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
