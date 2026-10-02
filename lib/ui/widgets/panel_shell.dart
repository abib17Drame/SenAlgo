import 'package:flutter/material.dart';

import '../theme.dart';

/// Cadre commun aux panneaux de l'application (éditeur, console, variables) :
/// bordure arrondie et barre de titre avec icône et actions.
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
      margin: EdgeInsets.all(MediaQuery.sizeOf(context).width < 800 ? 12 : 8),
      decoration: BoxDecoration(
        color: SenAlgoTheme.surfaceBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SenAlgoTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: SenAlgoTheme.border)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: SenAlgoTheme.neonCyan),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
