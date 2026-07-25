import 'package:flutter/material.dart';

import '../../state/execution_provider.dart';
import '../theme.dart';

/// Pastille colorée indiquant l'état de l'exécution, et libellés associés.
///
/// Extrait de `main_screen.dart` lors du découpage. La couleur était
/// auparavant déterminée par deux `switch` identiques, l'un pour la pastille
/// et l'autre pour le texte : ils sont réunis dans [couleurPour].
class ExecutionStatusDot extends StatelessWidget {
  final ExecutionStatus status;

  const ExecutionStatusDot({super.key, required this.status});

  /// Couleur associée à [status], commune à la pastille et au message.
  static Color couleurPour(ExecutionStatus status) {
    switch (status) {
      case ExecutionStatus.idle:
        return Colors.grey;
      case ExecutionStatus.running:
        return SenAlgoTheme.neonGreen;
      case ExecutionStatus.stepping:
        return SenAlgoTheme.neonCyan;
      case ExecutionStatus.waitingForInput:
        return SenAlgoTheme.neonYellow;
      case ExecutionStatus.error:
        return Colors.red;
      case ExecutionStatus.finished:
        return SenAlgoTheme.neonCyan;
      case ExecutionStatus.stopped:
        return Colors.orangeAccent;
    }
  }

  /// Message décrivant [state], affiché dans la barre du bas.
  static String messagePour(ExecutionState state) {
    switch (state.status) {
      case ExecutionStatus.idle:
        return "Prêt";
      case ExecutionStatus.running:
        return "Exécution en cours...";
      case ExecutionStatus.stepping:
        final base = "Ligne ${state.currentLine ?? ''}";
        return state.explanation != null ? "$base : ${state.explanation}" : base;
      case ExecutionStatus.waitingForInput:
        return "En attente de saisie...";
      case ExecutionStatus.error:
        return "Erreur: ${state.errorMessage}";
      case ExecutionStatus.finished:
        return "Terminé avec succès";
      case ExecutionStatus.stopped:
        return "Débogage arrêté";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(shape: BoxShape.circle, color: couleurPour(status)),
    );
  }
}
