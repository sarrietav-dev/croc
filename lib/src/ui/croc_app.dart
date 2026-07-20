import 'package:flutter/material.dart';

import '../app_controller.dart';
import 'app_theme.dart';
import 'home_shell.dart';

class CrocApp extends StatelessWidget {
  const CrocApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Croc',
      debugShowCheckedModeBanner: false,
      theme: buildCrocTheme(),
      home: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (!controller.initialized) {
            return const _LaunchScreen();
          }
          return HomeShell(controller: controller);
        },
      ),
    );
  }
}

class _LaunchScreen extends StatelessWidget {
  const _LaunchScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: CrocColors.forest,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CrocMark(size: 72, inverted: true),
            SizedBox(height: 24),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: CrocColors.lime,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CrocMark extends StatelessWidget {
  const CrocMark({super.key, this.size = 44, this.inverted = false});

  final double size;
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: inverted ? CrocColors.lime : CrocColors.forest,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(
        Icons.arrow_outward_rounded,
        size: size * 0.55,
        color: inverted ? CrocColors.forest : CrocColors.lime,
      ),
    );
  }
}
