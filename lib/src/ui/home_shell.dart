import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_controller.dart';
import 'app_theme.dart';
import 'croc_app.dart';
import 'receive_view.dart';
import 'send_view.dart';
import 'settings_view.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.controller});

  final AppController controller;

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.north_east_rounded),
      selectedIcon: Icon(Icons.north_east_rounded),
      label: 'Send',
    ),
    NavigationDestination(
      icon: Icon(Icons.south_west_rounded),
      selectedIcon: Icon(Icons.south_west_rounded),
      label: 'Receive',
    ),
    NavigationDestination(
      icon: Icon(Icons.tune_rounded),
      selectedIcon: Icon(Icons.tune_rounded),
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 720;
    final compactNavigation = width < 1100;
    final content = IndexedStack(
      index: controller.destination,
      children: [
        SendView(controller: controller),
        ReceiveView(controller: controller),
        SettingsView(controller: controller),
      ],
    );

    if (desktop) {
      return Scaffold(
        body: Row(
          children: [
            _DesktopNavigation(
              key: const Key('desktop-navigation'),
              controller: controller,
              compact: compactNavigation,
            ),
            Expanded(child: content),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: CrocColors.cream,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        title: const Row(
          children: [
            CrocMark(size: 38),
            SizedBox(width: 12),
            Text(
              'croc',
              style: TextStyle(
                color: CrocColors.ink,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 18),
            child: _SecureBadge(compact: true),
          ),
        ],
      ),
      body: content,
      bottomNavigationBar: NavigationBar(
        selectedIndex: controller.destination,
        onDestinationSelected: controller.setDestination,
        destinations: _destinations,
      ),
    );
  }
}

class _DesktopNavigation extends StatelessWidget {
  const _DesktopNavigation({
    super.key,
    required this.controller,
    required this.compact,
  });

  final AppController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 88 : 248,
      color: CrocColors.forest,
      padding: EdgeInsets.fromLTRB(
        compact ? 14 : 22,
        28,
        compact ? 14 : 22,
        24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: compact
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              const CrocMark(size: 44, inverted: true),
              if (!compact) ...[
                const SizedBox(width: 14),
                const Text(
                  'croc',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 48),
          _RailItem(
            selected: controller.destination == 0,
            icon: Icons.north_east_rounded,
            label: 'Send files',
            compact: compact,
            onTap: () => controller.setDestination(0),
          ),
          const SizedBox(height: 8),
          _RailItem(
            selected: controller.destination == 1,
            icon: Icons.south_west_rounded,
            label: 'Receive files',
            compact: compact,
            onTap: () => controller.setDestination(1),
          ),
          const SizedBox(height: 8),
          _RailItem(
            selected: controller.destination == 2,
            icon: Icons.tune_rounded,
            label: 'Settings',
            compact: compact,
            onTap: () => controller.setDestination(2),
          ),
          const Spacer(),
          _SecureBadge(compact: compact),
          if (!compact) ...[
            const SizedBox(height: 16),
            Text(
              kIsWeb
                  ? 'Use a bridge you trust. HTTPS protects files in transit to it.'
                  : 'Your files stay encrypted from this device to the other one.',
              style: const TextStyle(
                color: Color(0xFFAFC4B9),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.selected,
    required this.icon,
    required this.label,
    required this.compact,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: compact ? label : '',
      child: Material(
        color: selected ? CrocColors.lime : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 15,
              vertical: 14,
            ),
            child: Row(
              mainAxisAlignment: compact
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  color: selected ? CrocColors.forest : Colors.white,
                  size: 21,
                ),
                if (!compact) ...[
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? CrocColors.forest : Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SecureBadge extends StatelessWidget {
  const _SecureBadge({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: 8),
      decoration: BoxDecoration(
        color: compact ? const Color(0xFFE5E9E2) : const Color(0xFF224A3C),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 15,
            color: compact ? CrocColors.forest : CrocColors.lime,
          ),
          if (!compact) ...[
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                kIsWeb ? 'Secure web bridge' : 'End-to-end encrypted',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
