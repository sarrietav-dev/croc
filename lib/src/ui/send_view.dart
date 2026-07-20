import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../model/transfer_models.dart';
import 'app_theme.dart';
import 'shared_widgets.dart';

class SendView extends StatelessWidget {
  const SendView({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      eyebrow: 'Secure transfer',
      title: 'Send files',
      description: 'Select files and share the one-time code.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 820) {
            return Row(
              key: const Key('send-workspace-wide'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 6,
                  child: _FilePickerCard(controller: controller),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      CodeCard(controller: controller, receiveMode: false),
                      const SizedBox(height: 14),
                      _SendAction(controller: controller),
                      const SizedBox(height: 14),
                      TransferPanel(controller: controller),
                    ],
                  ),
                ),
              ],
            );
          }

          return Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                children: [
                  _FilePickerCard(controller: controller),
                  const SizedBox(height: 14),
                  CodeCard(controller: controller, receiveMode: false),
                  const SizedBox(height: 14),
                  _SendAction(controller: controller),
                  const SizedBox(height: 14),
                  TransferPanel(controller: controller),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FilePickerCard extends StatelessWidget {
  const _FilePickerCard({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final files = controller.selectedFiles;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose what to send',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            const Text(
              'Add files, a folder, or a text message',
              style: TextStyle(color: CrocColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth - 10) / 2;
                final enabled = !controller.isBusy && !controller.pickingFiles;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _SourceButton(
                      width: itemWidth,
                      icon: Icons.insert_drive_file_outlined,
                      label: 'File',
                      onPressed: enabled ? controller.pickFiles : null,
                    ),
                    _SourceButton(
                      width: itemWidth,
                      icon: Icons.folder_outlined,
                      label: 'Folder',
                      onPressed: enabled ? controller.pickFolder : null,
                    ),
                    _SourceButton(
                      width: itemWidth,
                      icon: Icons.notes_rounded,
                      label: 'Text',
                      onPressed: enabled
                          ? () => _showTextDialog(context)
                          : null,
                    ),
                    _SourceButton(
                      width: itemWidth,
                      icon: Icons.content_paste_rounded,
                      label: 'Paste',
                      onPressed: enabled ? controller.pasteText : null,
                    ),
                  ],
                );
              },
            ),
            if (files.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${files.length} selected · ${formatBytes(controller.selectedBytes)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...files.map(
                (file) => _SelectedFileRow(file: file, controller: controller),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showTextDialog(BuildContext context) async {
    final text = await showDialog<String>(
      context: context,
      builder: (context) => const _TextDialog(),
    );
    if (text != null && text.isNotEmpty) await controller.addText(text);
  }
}

class _TextDialog extends StatefulWidget {
  const _TextDialog();

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  final textController = TextEditingController();

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Send text'),
      content: TextField(
        controller: textController,
        autofocus: true,
        minLines: 5,
        maxLines: 12,
        decoration: const InputDecoration(
          hintText: 'Type or paste your message',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, textController.text),
          child: const Text('Add text'),
        ),
      ],
    );
  }
}

class _SourceButton extends StatelessWidget {
  const _SourceButton({
    required this.width,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final double width;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        ),
      ),
    );
  }
}

class _SelectedFileRow extends StatelessWidget {
  const _SelectedFileRow({required this.file, required this.controller});

  final SelectedFile file;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6F2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.description_outlined, size: 19),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    formatBytes(file.size),
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Remove',
              onPressed: controller.isBusy
                  ? null
                  : () => controller.removeFile(file),
              icon: const Icon(Icons.close_rounded, size: 19),
            ),
          ],
        ),
      ),
    );
  }
}

class _SendAction extends StatelessWidget {
  const _SendAction({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed:
            controller.isBusy ||
                controller.selectedFiles.isEmpty ||
                controller.code.length < 6
            ? null
            : controller.startSend,
        icon: const Icon(Icons.north_east_rounded),
        label: Text(
          controller.isBusy ? 'Transfer in progress' : 'Send securely',
        ),
      ),
    );
  }
}
