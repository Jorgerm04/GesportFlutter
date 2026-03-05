import 'package:flutter/material.dart';
import 'package:gesport/utils/app_theme.dart';

// ─── GesportCard ─────────────────────────────────────────────────────────────
class GesportCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;
  final double borderWidth;
  final double borderRadius;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  const GesportCard({
    super.key, required this.child, this.padding, this.borderColor,
    this.borderWidth = 1, this.borderRadius = 16,
    this.backgroundColor, this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(borderRadius),
        border: borderColor != null
            ? Border.all(color: borderColor!, width: borderWidth)
            : null,
      ),
      padding: padding,
      child: child,
    );
    return onTap != null ? GestureDetector(onTap: onTap, child: card) : card;
  }
}
