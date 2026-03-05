import 'package:flutter/material.dart';

// ─── SectionHeader ───────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final int badge;
  const SectionHeader({
    super.key, required this.title, required this.icon,
    required this.color, this.badge = 0,
  });
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 18, color: color),
    const SizedBox(width: 8),
    Text(title, style: const TextStyle(
        color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
    if (badge > 0) ...[
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(badge.toString(), style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    ],
  ]);
}
