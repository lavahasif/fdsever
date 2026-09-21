import 'package:flutter/material.dart';

class CategoryTabItem {
  final String title;
  final IconData icon;
  final String? badgeText;
  final bool showActiveDot;

  const CategoryTabItem({
    required this.title,
    required this.icon,
    this.badgeText,
    this.showActiveDot = false,
  });
}

class CategorySegmentedBar extends StatelessWidget {
  final List<CategoryTabItem> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const CategorySegmentedBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : const Color(0xFFFAFAFA),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF09090B) : const Color(0xFFF4F4F5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(tabs.length, (index) {
              final tab = tabs[index];
              final isSelected = selectedIndex == index;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Material(
                  color: isSelected
                      ? (isDark ? const Color(0xFF27272A) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  elevation: isSelected ? 1 : 0,
                  shadowColor: Colors.black26,
                  child: InkWell(
                    onTap: () => onTabSelected(index),
                    borderRadius: BorderRadius.circular(7),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            tab.icon,
                            size: 16,
                            color: isSelected
                                ? (isDark ? Colors.white : Colors.black87)
                                : (isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A)),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            tab.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected
                                  ? (isDark ? Colors.white : Colors.black87)
                                  : (isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A)),
                            ),
                          ),
                          if (tab.showActiveDot) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFF22C55E),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                          if (tab.badgeText != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE4E4E7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                tab.badgeText!,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                          ],
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
    );
  }
}
