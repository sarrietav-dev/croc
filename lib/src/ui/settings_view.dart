import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../model/transfer_models.dart';
import 'app_theme.dart';
import 'shared_widgets.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key, required this.controller});

  final AppController controller;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late final TextEditingController _address;
  late final TextEditingController _ports;
  late final TextEditingController _password;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final relay = widget.controller.relay;
    _address = TextEditingController(text: relay.address);
    _ports = TextEditingController(text: relay.ports);
    _password = TextEditingController(text: relay.password);
  }

  @override
  void dispose() {
    _address.dispose();
    _ports.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      eyebrow: 'Connection',
      title: 'Relay settings',
      description:
          'The public Croc relay works out of the box. Change these only when using your own relay.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final form = Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8EFE8),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(Icons.hub_outlined, size: 21),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Text(
                          'Croc relay',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: CrocColors.lime,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'TCP',
                          style: TextStyle(
                            color: CrocColors.forest,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _address,
                    enabled: !widget.controller.isBusy,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Relay address',
                      hintText: 'relay.example.com:9009',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _ports,
                    enabled: !widget.controller.isBusy,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Ports',
                      hintText: '9009,9010,9011,9012,9013',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _password,
                    enabled: !widget.controller.isBusy,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Relay password',
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed:
                          widget.controller.isBusy ||
                              _address.text.trim().isEmpty
                          ? null
                          : () async {
                              await widget.controller.saveRelay(
                                RelaySettings(
                                  address: _address.text.trim(),
                                  ports: _ports.text.trim(),
                                  password: _password.text,
                                ),
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Relay settings saved'),
                                  ),
                                );
                              }
                            },
                      child: const Text('Save relay settings'),
                    ),
                  ),
                ],
              ),
            ),
          );
          final note = Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFE7EBE4),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: CrocColors.forest,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'At least two relay ports are required. Both devices must use the same address, ports, and password.',
                    style: TextStyle(
                      color: CrocColors.forest,
                      fontSize: 13,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );

          if (constraints.maxWidth >= 820) {
            return Row(
              key: const Key('settings-workspace-wide'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: form),
                const SizedBox(width: 20),
                Expanded(flex: 4, child: note),
              ],
            );
          }

          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(children: [form, const SizedBox(height: 18), note]),
          );
        },
      ),
    );
  }
}
