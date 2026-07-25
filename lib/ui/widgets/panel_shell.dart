import 'package:flutter/material.dart';

import '../theme.dart';

/// Cadre commun aux panneaux de l'application (éditeur, console, variables) :
/// bordure arrondie, ombre, et une barre de titre avec icône et actions.
///
/// Extrait de `main_screen.dart` lors du découpage.
class PanelShell extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> actions;
  final Widget child;

  const PanelShell({
    super.key,
    required this.title,
    required this.icon,
    this.actions = const [],
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: SenAlgoTheme.surfaceBg.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: SenAlgoTheme.neonCyan),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (actions.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: actions,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
