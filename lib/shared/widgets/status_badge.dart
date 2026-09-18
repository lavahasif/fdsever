import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class StatusBadge extends StatelessWidget {
  final bool isActive;
  final String activeLabel;
  final String inactiveLabel;

  const StatusBadge({
    super.key,
    required this.isActive,
    this.activeLabel = 'Online',
    this.inactiveLabel = 'Offline',
  });

  @override
  Widget build(BuildContext context) {
    if (isActive) {
      return ShadBadge(
        backgroundColor: const Color(0xFF15803D), // emerald-700
        foregroundColor: Colors.white,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 6),
              decoration: const BoxDecoration(
                color: Color(0xFF4ADE80),
                shape: BoxShape.circle,
              ),
            ),
            Text(activeLabel, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          ],
        ),
      );
    }

    return ShadBadge.secondary(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 6),
            decoration: const BoxDecoration(
              color: Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          Text(inactiveLabel, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
        ],
      ),
    );
  }
}
