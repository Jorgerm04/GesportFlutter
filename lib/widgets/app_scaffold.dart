import 'package:flutter/material.dart';
import 'package:gesport/utils/app_theme.dart';

// ─── AppScaffold ────────────────────────────────────────────────────────────
class AppScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  const AppScaffold({
    super.key, required this.title, required this.body,
    this.actions, this.floatingActionButton,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: AppBar(
      title: Text(title, style: const TextStyle(color: Colors.white)),
      backgroundColor: Colors.transparent, elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: actions,
    ),
    floatingActionButton: floatingActionButton,
    body: Container(
      height: double.infinity, width: double.infinity,
      decoration: AppTheme.backgroundDecoration,
      child: SafeArea(child: body),
    ),
  );
}
