import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class NavItem {
  final String title;
  final IconData icon;

  const NavItem({required this.title, required this.icon});
}

class ResponsiveSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  static const List<NavItem> items = [
    NavItem(title: 'Dashboard', icon: LucideIcons.layoutDashboard),
    NavItem(title: 'Web Server', icon: LucideIcons.globe),
    NavItem(title: 'Port Scanner', icon: LucideIcons.radar),
    NavItem(title: 'WhatsApp Direct', icon: LucideIcons.messageSquare),
    NavItem(title: 'Notes & KB', icon: LucideIcons.notebookPen),
    NavItem(title: 'Tutorials', icon: LucideIcons.bookOpen),
    NavItem(title: 'Realtime Hub', icon: LucideIcons.radio),
    NavItem(title: 'File Transfer', icon: LucideIcons.uploadCloud),
    NavItem(title: 'Settings', icon: LucideIcons.settings),
  ];

  const ResponsiveSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : const Color(0xFFFAFAFA),
        border: Border(
          right: BorderSide(
            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: List.generate(items.length, (index) {
                  final item = items[index];
                  final isSelected = selectedIndex == index;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Material(
                      color: isSelected
                          ? (isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: () => onDestinationSelected(index),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              Icon(
                                item.icon,
                                size: 18,
                                color: isSelected
                                    ? (isDark ? Colors.white : Colors.black)
                                    : (isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.title,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    color: isSelected
                                        ? (isDark ? Colors.white : Colors.black)
                                        : (isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'FDServer Suite\nFlutter 3.44 • Shadcn UI',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? const Color(0xFF71717A) : const Color(0xFFA1A1AA),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
