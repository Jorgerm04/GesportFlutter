import 'package:flutter/material.dart';

// ─── InfoChip ─────────────────────────────────────────────────────────────────
class InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const InfoChip({super.key, required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 12, color: color),
    const SizedBox(width: 4),
    Text(label, style: TextStyle(color: color, fontSize: 11)),
  ]);
}
