import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../providers/file_transfer_provider.dart';

class FileTransferScreen extends StatefulWidget {
  const FileTransferScreen({super.key});

  @override
  State<FileTransferScreen> createState() => _FileTransferScreenState();
}

class _FileTransferScreenState extends State<FileTransferScreen> {
  late final TextEditingController _ipController;
  late final TextEditingController _portController;

  @override
  void initState() {
    super.initState();
    final provider = context.read<FileTransferProvider>();
    _ipController = TextEditingController(text: provider.destinationIp);
    _portController = TextEditingController(text: provider.destinationPort.toString());
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transferProvider = context.watch<FileTransferProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text('File Transfer & Remote Uploader',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(
            'Upload local files to any remote FDServer instance or HTTP receiver endpoint.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),

          const SizedBox(height: 18),

          // Destination Configuration Card
          ShadCard(
            title: const Text('Target Destination'),
            description: const Text('Configure remote IP address and listening port for file receiving.'),
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 450;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isWide)
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Receiver Host IP',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 6),
                                  ShadInput(
                                    controller: _ipController,
                                    placeholder: const Text('192.168.1.50'),
                                    onChanged: (val) => transferProvider.setDestinationIp(val.trim()),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Port',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 6),
                                  ShadInput(
                                    controller: _portController,
                                    placeholder: const Text('8081'),
                                    keyboardType: TextInputType.number,
                                    onChanged: (val) {
                                      final p = int.tryParse(val.trim());
                                      if (p != null) transferProvider.setDestinationPort(p);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      else ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Receiver Host IP',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 6),
                            ShadInput(
                              controller: _ipController,
                              placeholder: const Text('192.168.1.50'),
                              onChanged: (val) => transferProvider.setDestinationIp(val.trim()),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Port',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 6),
                            ShadInput(
                              controller: _portController,
                              placeholder: const Text('8081'),
                              keyboardType: TextInputType.number,
                              onChanged: (val) {
                                final p = int.tryParse(val.trim());
                                if (p != null) transferProvider.setDestinationPort(p);
                              },
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Delete Local File After Upload',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                const SizedBox(height: 2),
                                Text(
                                  'Automatically remove local file once upload is verified by the remote server.',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          ShadSwitch(
                            value: transferProvider.deleteAfterUpload,
                            onChanged: (val) => transferProvider.setDeleteAfterUpload(val),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 20),

          // File Picker & Action Bar (using Wrap to prevent overflow on mobile)
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ShadButton(
                onPressed: () => transferProvider.pickFiles(),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.filePlus, size: 15),
                    SizedBox(width: 8),
                    Text('Choose Files'),
                  ],
                ),
              ),
              if (transferProvider.selectedFiles.isNotEmpty) ...[
                ShadButton(
                  onPressed: transferProvider.isUploading
                      ? null
                      : () => transferProvider.uploadAll(),
                  backgroundColor: Colors.blue.shade700,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (transferProvider.isUploading)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      else
                        const Icon(LucideIcons.upload, size: 15),
                      const SizedBox(width: 8),
                      Text('Upload ${transferProvider.selectedFiles.length} File(s)'),
                    ],
                  ),
                ),
                ShadButton.outline(
                  size: ShadButtonSize.sm,
                  onPressed: () => transferProvider.clearFiles(),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.trash2, size: 13),
                      SizedBox(width: 6),
                      Text('Clear All', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ],
          ),

          if (transferProvider.uploadStatus.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(transferProvider.uploadStatus,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
          ],

          const SizedBox(height: 18),

          // Selected Files List
          if (transferProvider.selectedFiles.isEmpty)
            ShadCard(
              padding: const EdgeInsets.all(28),
              child: const Center(
                child: Column(
                  children: [
                    Icon(LucideIcons.cloudUpload, size: 36, color: Colors.grey),
                    SizedBox(height: 10),
                    Text('No files selected',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    SizedBox(height: 4),
                    Text('Click "Choose Files" to select documents, APKs, or images.',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: transferProvider.selectedFiles.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final file = transferProvider.selectedFiles[index];
                return ShadCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(LucideIcons.file, size: 18, color: Colors.blue),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(file.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(file.formattedSize,
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ShadButton.ghost(
                        size: ShadButtonSize.sm,
                        onPressed: () => transferProvider.removeFile(index),
                        child: const Icon(LucideIcons.x, size: 15),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
