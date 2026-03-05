import 'package:flutter/material.dart';
import 'package:gesport/utils/app_theme.dart';

// ─── ConfirmDialog ────────────────────────────────────────────────────────────
class ConfirmDialog extends StatelessWidget {
  final String title, content, confirmLabel;
  final Color confirmColor;
  const ConfirmDialog({
    super.key, required this.title, required this.content,
    this.confirmLabel = 'Confirmar', this.confirmColor = Colors.redAccent,
  });

  static Future<bool> show(
    BuildContext context, {
    required String title, required String content,
    String confirmLabel = 'Confirmar', Color confirmColor = Colors.redAccent,
  }) async => await showDialog<bool>(
    context: context,
    builder: (_) => ConfirmDialog(
      title: title, content: content,
      confirmLabel: confirmLabel, confirmColor: confirmColor,
    ),
  ) ?? false;

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AppTheme.bg1,
    title:   Text(title,   style: const TextStyle(color: Colors.white)),
    content: Text(content, style: const TextStyle(color: Colors.white70)),
    actions: [
      TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar')),
      TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel, style: TextStyle(color: confirmColor))),
    ],
  );
}
