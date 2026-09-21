import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../notes/providers/notes_provider.dart';
import '../../network_scanner/providers/scanner_provider.dart';
import '../../tutorials/providers/tutorials_provider.dart';
import '../../web_server/providers/web_server_provider.dart';

class DashboardScreen extends StatelessWidget {
  final ValueChanged<int> onNavigate;

  const DashboardScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final serverProvider = context.watch<WebServerProvider>();
    final scannerProvider = context.watch<ScannerProvider>();
    final notesProvider = context.watch<NotesProvider>();
    final tutsProvider = context.watch<TutorialsProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner
          ShadCard(
            title: const Text('FDServer Network & Server Center', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            description: Text(
              serverProvider.isRunning
                  ? 'Local server is active and listening on ${serverProvider.serverUrl}'
                  : 'Web server is currently stopped. Choose an action below or configure your local network.',
            ),
            footer: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                ShadButton(
                  onPressed: () => serverProvider.toggleServer(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(serverProvider.isRunning ? LucideIcons.square : LucideIcons.play, size: 16),
                      const SizedBox(width: 8),
                      Text(serverProvider.isRunning ? 'Stop Server' : 'Start Server'),
                    ],
                  ),
                ),
                ShadButton.outline(
                  onPressed: () => onNavigate(1), // Web Server tab
                  child: const Text('Open Web Controller'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Overview Cards Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 600 ? 2 : 1);
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.4,
                children: [
                  // Server Status Card
                  _buildStatCard(
                    context,
                    title: 'Web Server',
                    value: serverProvider.isRunning ? 'Online' : 'Offline',
                    subtext: 'Port: ${serverProvider.port}',
                    icon: LucideIcons.server,
                    color: serverProvider.isRunning ? Colors.green : Colors.grey,
                    onTap: () => onNavigate(1),
                  ),

                  // Network Discovery Card
                  _buildStatCard(
                    context,
                    title: 'Local IP',
                    value: scannerProvider.primaryIp,
                    subtext: '${scannerProvider.interfaces.length} interface(s)',
                    icon: LucideIcons.network,
                    color: Colors.blue,
                    onTap: () => onNavigate(2),
                  ),

                  // Notes Card
                  _buildStatCard(
                    context,
                    title: 'Saved Notes',
                    value: notesProvider.notes.length.toString(),
                    subtext: 'Local Knowledge Base',
                    icon: LucideIcons.notebookPen,
                    color: Colors.purple,
                    onTap: () => onNavigate(4),
                  ),

                  // Tutorials Card
                  _buildStatCard(
                    context,
                    title: 'Tutorials',
                    value: tutsProvider.tutorials.length.toString(),
                    subtext: '${tutsProvider.categories.length - 1} categories',
                    icon: LucideIcons.bookOpen,
                    color: Colors.amber,
                    onTap: () => onNavigate(5),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Quick Access Tools
          const Text('Quick Access Tools', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildToolButton(
                icon: LucideIcons.radar,
                label: 'Port Scanner',
                onPressed: () => onNavigate(2),
              ),
              _buildToolButton(
                icon: LucideIcons.messageSquare,
                label: 'WhatsApp Direct',
                onPressed: () => onNavigate(3),
              ),
              _buildToolButton(
                icon: LucideIcons.radio,
                label: 'Realtime WebSocket',
                onPressed: () => onNavigate(6),
              ),
              _buildToolButton(
                icon: LucideIcons.uploadCloud,
                label: 'File Uploader',
                onPressed: () => onNavigate(7),
              ),
              _buildToolButton(
                icon: LucideIcons.settings,
                label: 'App Settings',
                onPressed: () => onNavigate(8),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Server Live Activity Log preview
          if (serverProvider.logs.isNotEmpty) ...[
            const Text('Recent Server Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ShadCard(
              padding: const EdgeInsets.all(12),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: serverProvider.logs.take(5).length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final log = serverProvider.logs[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        ShadBadge(
                          backgroundColor: log.statusCode < 400 ? Colors.green.shade800 : Colors.red.shade800,
                          child: Text('${log.statusCode}', style: const TextStyle(fontSize: 11)),
                        ),
                        const SizedBox(width: 12),
                        Text(log.method, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            log.path,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          log.clientIp,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ShadCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                Icon(icon, size: 20, color: color),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text(subtext, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ShadButton.outline(
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}
