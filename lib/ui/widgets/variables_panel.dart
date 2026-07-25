import 'package:flutter/material.dart';

import 'animated_variable_row.dart';
import 'panel_shell.dart';

/// Panneau listant les variables et leur valeur courante.
///
/// Extrait de `main_screen.dart` lors du découpage.
class VariablesPanel extends StatelessWidget {
  final Map<String, dynamic> variables;

  const VariablesPanel({super.key, required this.variables});

  @override
  Widget build(BuildContext context) {
    return PanelShell(
      title: 'Variables',
      icon: Icons.memory,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            // Les deux libellés sont `Flexible` + ellipsis : le panneau
            // Variables peut être redimensionné très étroit (split-view), et
            // un Row rigide déborderait alors de quelques pixels.
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'NOM',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'VALEUR',
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: variables.entries
                  .map((e) => AnimatedVariableRow(name: e.key, value: e.value))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
