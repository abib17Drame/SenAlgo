import 'package:flutter/material.dart';
import '../theme.dart';

class EmptyPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  const EmptyPanel({super.key, required this.icon, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: SenAlgoTheme.neonCyan.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(20)),
              child: Icon(icon, color: SenAlgoTheme.neonCyan, size: 28),
            ),
            const SizedBox(height: 18),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            Text(description, textAlign: TextAlign.center, style: const TextStyle(color: SenAlgoTheme.muted, fontSize: 13, height: 1.6)),
          ]),
        )),
      ),
    ));
  }
}
