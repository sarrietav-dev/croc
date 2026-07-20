import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../model/transfer_models.dart';
import 'app_theme.dart';
import 'qr_code_flow.dart';

class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.child,
  });

  final String eyebrow;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            MediaQuery.sizeOf(context).width < 600 ? 20 : 48,
            24,
            MediaQuery.sizeOf(context).width < 600 ? 20 : 48,
            64,
          ),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow.toUpperCase(),
                      style: const TextStyle(
                        color: CrocColors.forestBright,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 580),
                      child: Text(
                        description,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: CrocColors.muted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class CodeCard extends StatefulWidget {
  const CodeCard({
    super.key,
    required this.controller,
    required this.receiveMode,
  });

  final AppController controller;
  final bool receiveMode;

  @override
  State<CodeCard> createState() => _CodeCardState();
}

class _CodeCardState extends State<CodeCard> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.controller.code);
  }

  @override
  void didUpdateWidget(CodeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_textController.text != widget.controller.code) {
      _textController.value = TextEditingValue(
        text: widget.controller.code,
        selection: TextSelection.collapsed(
          offset: widget.controller.code.length,
        ),
      );
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.receiveMode ? 'Enter code' : 'Transfer code',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _textController,
              enabled: !widget.controller.isBusy,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.none,
              onChanged: widget.controller.setCode,
              style: const TextStyle(
                color: CrocColors.ink,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
              decoration: InputDecoration(hintText: 'correct-horse-battery'),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: widget.receiveMode
                  ? _receiveActions(context)
                  : _sendActions(context),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _receiveActions(BuildContext context) => [
    if (cameraQrScanningSupported)
      TextButton.icon(
        onPressed: widget.controller.isBusy
            ? null
            : () async {
                final code = await scanTransferQrCode(context);
                if (code != null) widget.controller.setCode(code);
              },
        icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
        label: const Text('Scan QR'),
      ),
    TextButton.icon(
      onPressed: widget.controller.isBusy
          ? null
          : () async {
              final data = await Clipboard.getData(Clipboard.kTextPlain);
              if (data?.text case final text?) {
                widget.controller.setCode(text);
              }
            },
      icon: const Icon(Icons.content_paste_rounded, size: 18),
      label: const Text('Paste code'),
    ),
  ];

  List<Widget> _sendActions(BuildContext context) => [
    TextButton.icon(
      onPressed: widget.controller.isBusy
          ? null
          : () => showTransferQrCode(context, widget.controller.code),
      icon: const Icon(Icons.qr_code_2_rounded, size: 18),
      label: const Text('Show QR'),
    ),
    TextButton.icon(
      onPressed: widget.controller.isBusy ? null : widget.controller.copyCode,
      icon: const Icon(Icons.copy_rounded, size: 18),
      label: const Text('Copy code'),
    ),
    TextButton.icon(
      onPressed: widget.controller.isBusy
          ? null
          : widget.controller.regenerateCode,
      icon: const Icon(Icons.refresh_rounded, size: 18),
      label: const Text('New code'),
    ),
  ];
}

class TransferPanel extends StatelessWidget {
  const TransferPanel({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final phase = controller.phase;
    if (phase == TransferPhase.idle) return const SizedBox.shrink();

    final failed = phase == TransferPhase.failed;
    final complete = phase == TransferPhase.completed;
    final canceled = phase == TransferPhase.canceled;
    final icon = complete
        ? Icons.check_rounded
        : failed
        ? Icons.priority_high_rounded
        : canceled
        ? Icons.close_rounded
        : Icons.sync_rounded;
    final accent = complete
        ? CrocColors.forestBright
        : failed
        ? CrocColors.coral
        : CrocColors.forest;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      child: Card(
        key: ValueKey(phase),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: accent, size: 21),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          controller.status,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (controller.progress.fileName.isNotEmpty)
                          Text(
                            '${controller.progress.fileName} · ${controller.progress.fileIndex + 1} of ${controller.progress.fileCount}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (controller.isBusy) ...[
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    minHeight: 9,
                    value: phase == TransferPhase.transferring
                        ? controller.progress.fraction
                        : null,
                    backgroundColor: const Color(0xFFE4E9E3),
                    color: CrocColors.forestBright,
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      phase == TransferPhase.transferring
                          ? '${formatBytes(controller.progress.bytesDone)} of ${formatBytes(controller.progress.bytesTotal)}'
                          : 'Establishing a secure connection',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: controller.cancel,
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ],
              if (failed) ...[
                const SizedBox(height: 12),
                Text(
                  controller.errorMessage ??
                      'Please check the code and relay settings.',
                ),
              ],
              if (complete || failed || canceled) ...[
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: controller.resetTransfer,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Start another transfer'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class PrivacyNote extends StatelessWidget {
  const PrivacyNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFE7EBE4),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: CrocColors.forest, size: 21),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'The relay connects both devices, but your files are encrypted before they leave this device.',
              style: TextStyle(
                color: CrocColors.forest,
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
