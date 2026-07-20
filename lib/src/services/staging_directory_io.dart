import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<String> createPlatformStagingDirectory() async {
  final cache = await getTemporaryDirectory();
  return Directory(
    '${cache.path}/croc-receive-${DateTime.now().millisecondsSinceEpoch}',
  ).path;
}
