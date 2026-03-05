import 'package:flutter/material.dart';

// ─── SheetHandle ──────────────────────────────────────────────────────────────
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: 40, height: 4,
    decoration: BoxDecoration(
      color: Colors.white24, borderRadius: BorderRadius.circular(2)),
  );
}
