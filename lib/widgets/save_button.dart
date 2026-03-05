import 'package:flutter/material.dart';
import 'package:gesport/utils/app_theme.dart';

// ─── SaveButton ───────────────────────────────────────────────────────────────
class SaveButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;
  const SaveButton({super.key, required this.label, this.isLoading = false, this.onPressed});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity, height: 52,
    child: ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: isLoading
          ? const CircularProgressIndicator(color: Colors.white)
          : Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)),
    ),
  );
}
