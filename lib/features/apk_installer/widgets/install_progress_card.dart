import 'package:flutter/material.dart';
import '../../../core/services/apk_install_service.dart';

class InstallProgressCard extends StatelessWidget {
  final ApkInstallEvent event;
  const InstallProgressCard({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (event.status) {
      ApkInstallStatus.pending    => (Icons.hourglass_empty_rounded, Colors.grey),
      ApkInstallStatus.installing => (Icons.downloading_rounded,     Colors.blue),
      ApkInstallStatus.success    => (Icons.check_circle_rounded,    Colors.green),
      ApkInstallStatus.failed     => (Icons.error_rounded,           Colors.red),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF18181b),
        border: Border.all(color: const Color(0xFF27272a)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.apkName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if (event.message != null)
                  Text(event.message!,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF71717a)),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatTime(event.timestamp),
            style: const TextStyle(fontSize: 10, color: Color(0xFF52525b)),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, "0")}:${dt.minute.toString().padLeft(2, "0")}:${dt.second.toString().padLeft(2, "0")}';
}
