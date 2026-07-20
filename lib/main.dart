import 'package:flutter/material.dart';

import 'src/app_controller.dart';
import 'src/ui/croc_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController();
  runApp(CrocApp(controller: controller));
  controller.initialize();
}
