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
      child: Align(
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
            if (files.isEmpty)
              InkWell(
                onTap: controller.pickFiles,
                borderRadius: BorderRadius.circular(16),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Row(
                    children: [
                      _PickerIcon(),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Choose files',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Select one or several files',
                              style: TextStyle(
                                color: CrocColors.muted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.add_rounded, color: CrocColors.forest),
                    ],
                  ),
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${files.length} selected · ${formatBytes(controller.selectedBytes)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Add files',
                    onPressed: controller.isBusy ? null : controller.pickFiles,
                    icon: const Icon(Icons.add_rounded),
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
}

class _PickerIcon extends StatelessWidget {
  const _PickerIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F0E9),
        borderRadius: BorderRadius.circular(13),
      ),
      child: const Icon(Icons.attach_file_rounded, size: 21),
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
