import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../shared/widgets/category_segmented_bar.dart';
import '../../apk_installer/providers/apk_installer_provider.dart';
import '../../apk_installer/screens/apk_installer_screen.dart';
import '../../file_transfer/providers/file_transfer_provider.dart';
import '../../file_transfer/screens/file_transfer_screen.dart';
import '../../whatsapp/screens/whatsapp_screen.dart';

class SharingHubScreen extends StatefulWidget {
  final int initialSubIndex;

  const SharingHubScreen({super.key, this.initialSubIndex = 0});

  @override
  State<SharingHubScreen> createState() => _SharingHubScreenState();
}

class _SharingHubScreenState extends State<SharingHubScreen> {
  late int _selectedSubIndex;

  @override
  void initState() {
    super.initState();
    _selectedSubIndex = widget.initialSubIndex;
  }

  @override
  void didUpdateWidget(covariant SharingHubScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSubIndex != widget.initialSubIndex) {
      _selectedSubIndex = widget.initialSubIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileTransfer = context.watch<FileTransferProvider>();
    final apkInstaller = Provider.of<ApkInstallerProvider?>(context);

    final tabs = [
      CategoryTabItem(
        title: 'File Transfer',
        icon: LucideIcons.uploadCloud,
        showActiveDot: fileTransfer.isUploading,
        badgeText: fileTransfer.selectedFiles.isNotEmpty ? '${fileTransfer.selectedFiles.length}' : null,
      ),
      CategoryTabItem(
        title: 'APK Manager',
        icon: LucideIcons.package,
        showActiveDot: apkInstaller?.isProcessing ?? false,
        badgeText: (apkInstaller?.log.isNotEmpty ?? false) ? '${apkInstaller!.log.length}' : null,
      ),
      const CategoryTabItem(
        title: 'WhatsApp Direct',
        icon: LucideIcons.messageSquare,
      ),
    ];

    Widget body;
    switch (_selectedSubIndex) {
      case 1:
        body = const ApkInstallerScreen();
        break;
      case 2:
        body = const WhatsAppScreen();
        break;
      case 0:
      default:
        body = const FileTransferScreen();
        break;
    }

    return Column(
      children: [
        CategorySegmentedBar(
          tabs: tabs,
          selectedIndex: _selectedSubIndex,
          onTabSelected: (idx) => setState(() => _selectedSubIndex = idx),
        ),
        Expanded(child: body),
      ],
    );
  }
}
