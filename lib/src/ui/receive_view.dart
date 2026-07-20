import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../model/transfer_models.dart';
import 'app_theme.dart';
import 'shared_widgets.dart';

class ReceiveView extends StatelessWidget {
  const ReceiveView({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      eyebrow: 'Secure transfer',
      title: 'Receive files',
      description: 'Enter the code from the sending device.',
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            children: [
              CodeCard(controller: controller, receiveMode: true),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: controller.isBusy || controller.code.length < 6
                      ? null
                      : controller.startReceive,
                  icon: const Icon(Icons.south_west_rounded),
                  label: Text(
                    controller.isBusy
                        ? 'Transfer in progress'
                        : 'Receive securely',
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TransferPanel(controller: controller),
              if (controller.receivedFiles.isNotEmpty) ...[
                const SizedBox(height: 14),
                _ReceivedFiles(controller: controller),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceivedFiles extends StatelessWidget {
  const _ReceivedFiles({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Received files',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            for (final file in controller.receivedFiles)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F3ED),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.insert_drive_file_outlined,
                      color: CrocColors.forestBright,
                    ),
                    const SizedBox(width: 12),
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
                      tooltip: 'Save a copy',
                      onPressed: () async {
                        final saved = await controller.saveFile(file);
                        if (context.mounted && saved) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('File saved')),
                          );
                        }
                      },
                      icon: const Icon(Icons.download_rounded),
                    ),
                    IconButton(
                      tooltip: 'Share',
                      onPressed: () => controller.shareFile(file),
                      icon: const Icon(Icons.ios_share_rounded),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
