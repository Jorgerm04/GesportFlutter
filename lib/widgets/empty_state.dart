import 'package:flutter/material.dart';

// ─── EmptyState ───────────────────────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? subtitle;
  const EmptyState({super.key, required this.icon, required this.text, this.subtitle});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 28),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.03),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(children: [
      Icon(icon, color: Colors.white24, size: 36),
      const SizedBox(height: 10),
      Text(text, style: const TextStyle(color: Colors.white38, fontSize: 14)),
      if (subtitle != null) ...[
        const SizedBox(height: 4),
        Text(subtitle!, style: const TextStyle(color: Colors.white24, fontSize: 12)),
      ],
    ]),
  );
}
