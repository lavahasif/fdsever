import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../network_scanner/providers/scanner_provider.dart';
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

  IconData _getFileIcon(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'apk':
        return LucideIcons.package;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'webp':
      case 'svg':
        return LucideIcons.image;
      case 'pdf':
      case 'doc':
      case 'docx':
      case 'txt':
      case 'md':
        return LucideIcons.fileText;
      case 'zip':
      case 'rar':
      case 'tar':
      case 'gz':
      case '7z':
        return LucideIcons.archive;
      case 'mp4':
      case 'mkv':
      case 'avi':
      case 'mov':
        return LucideIcons.video;
      case 'mp3':
      case 'wav':
      case 'ogg':
      case 'flac':
        return LucideIcons.music;
      case 'dart':
      case 'js':
      case 'ts':
      case 'json':
      case 'html':
      case 'css':
        return LucideIcons.code;
      default:
        return LucideIcons.file;
    }
  }

  Color _getFileColor(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'apk':
        return const Color(0xFFEC4899);
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'webp':
        return const Color(0xFF8B5CF6);
      case 'pdf':
        return const Color(0xFFEF4444);
      case 'zip':
      case 'rar':
      case '7z':
        return const Color(0xFFF59E0B);
      case 'mp4':
      case 'mkv':
        return const Color(0xFF06B6D4);
      case 'dart':
      case 'js':
      case 'ts':
      case 'json':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  int _calculateTotalBytes(List selectedFiles) {
    int total = 0;
    for (final f in selectedFiles) {
      total += (f.size as int);
    }
    return total;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final transferProvider = context.watch<FileTransferProvider>();
    final scannerProvider = context.watch<ScannerProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Screen Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.uploadCloud, color: Color(0xFF3B82F6), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'File Transfer & Remote Uploader',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.3),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Upload and stream local files over Wi-Fi to any FDServer endpoint without cloud dependencies.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // Target Destination Card
          ShadCard(
            title: Row(
              children: [
                const Icon(LucideIcons.radio, size: 16),
                const SizedBox(width: 8),
                const Text('Target Receiver Endpoint'),
                const Spacer(),
                if (scannerProvider.primaryIp.isNotEmpty)
                  InkWell(
                    onTap: () {
                      _ipController.text = scannerProvider.primaryIp;
                      transferProvider.setDestinationIp(scannerProvider.primaryIp);
                      ShadToaster.of(context).show(
                        ShadToast(
                          title: const Text('Target Updated'),
                          description: Text('Filled local IP: ${scannerProvider.primaryIp}'),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.sparkles, size: 12, color: Colors.blue.shade400),
                          const SizedBox(width: 4),
                          Text(
                            'Use Local IP (${scannerProvider.primaryIp})',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue.shade400,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            description: const Text('Configure remote IP address and listening port for file receiving.'),
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 500;
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF18181B) : const Color(0xFFF4F4F5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.trash2, size: 16, color: Colors.grey),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Delete Local File After Upload',
                                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  Text(
                                    'Automatically remove local file once verified by remote server.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                                    ),
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
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Interactive Dropzone / Upload Target Box
          InkWell(
            onTap: () => transferProvider.pickFiles(),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF18181B) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFD4D4D8),
                  style: BorderStyle.solid,
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.uploadCloud, color: Color(0xFF3B82F6), size: 36),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Choose Files to Transfer',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap anywhere in this area to browse and pick documents, APKs, images, or archives.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ShadButton(
                    onPressed: () => transferProvider.pickFiles(),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.folderOpen, size: 15),
                        SizedBox(width: 8),
                        Text('Browse Storage'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Selected Files Card Stack
          if (transferProvider.selectedFiles.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('Selected Files',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${transferProvider.selectedFiles.length} file(s) • ${_formatBytes(_calculateTotalBytes(transferProvider.selectedFiles))}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    ShadButton(
                      size: ShadButtonSize.sm,
                      onPressed: transferProvider.isUploading ? null : () => transferProvider.uploadAll(),
                      backgroundColor: const Color(0xFF3B82F6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (transferProvider.isUploading)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          else
                            const Icon(LucideIcons.upload, size: 14),
                          const SizedBox(width: 6),
                          Text(transferProvider.isUploading ? 'Uploading...' : 'Upload All'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ShadButton.outline(
                      size: ShadButtonSize.sm,
                      onPressed: () => transferProvider.clearFiles(),
                      child: const Icon(LucideIcons.trash2, size: 14),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // File Items List
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: transferProvider.selectedFiles.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final file = transferProvider.selectedFiles[index];
                final icon = _getFileIcon(file.name);
                final color = _getFileColor(file.name);
                final ext = file.name.split('.').last.toUpperCase();

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF18181B) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              file.name,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    ext,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  file.formattedSize,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(LucideIcons.x, size: 16),
                        color: Colors.grey,
                        onPressed: () => transferProvider.removeFile(index),
                        splashRadius: 18,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],

          // Upload Status Card / Bar
          if (transferProvider.uploadStatus != 'No file chosen' || transferProvider.isUploading) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: transferProvider.isUploading
                    ? const Color(0xFF3B82F6).withValues(alpha: 0.1)
                    : (isDark ? const Color(0xFF18181B) : const Color(0xFFF4F4F5)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: transferProvider.isUploading
                      ? const Color(0xFF3B82F6).withValues(alpha: 0.3)
                      : (isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7)),
                ),
              ),
              child: Row(
                children: [
                  if (transferProvider.isUploading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(LucideIcons.info, size: 16, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      transferProvider.uploadStatus,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
