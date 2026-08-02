import 'package:flutter/material.dart';

import '../../core/analyzer/semantic_analyzer.dart';
import '../theme.dart';

/// Badge d'état affiché au-dessus de l'éditeur et dans la barre du bas.
///
/// Quatre états, par ordre de priorité : erreur de syntaxe (rouge, le
/// programme ne peut pas être lu), erreur sémantique (rouge aussi, il est lu
/// mais refuse de démarrer), avertissements (orange, il démarre mais fait
/// probablement autre chose que prévu), tout va bien (vert).
///
/// Extrait de `main_screen.dart` lors du découpage.
class DiagnosticsBadge extends StatelessWidget {
  /// Message d'erreur de syntaxe, `null` si la syntaxe est correcte.
  final String? error;

  /// Ligne de l'erreur de syntaxe, si elle a pu être déterminée.
  final int? errorLine;

  /// Signalements de l'analyse sémantique, ignorés en présence d'une erreur
  /// de syntaxe : l'arbre est alors incomplet.
  final List<SemanticDiagnostic> warnings;

  /// Appelé au clic, pour amener le curseur sur la ligne concernée.
  final VoidCallback? onTap;

  const DiagnosticsBadge({
    super.key,
    required this.error,
    required this.errorLine,
    required this.warnings,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final erreurs = error == null ? warnings.where((d) => d.estErreur).toList() : const <SemanticDiagnostic>[];
    final aUneErreur = error != null || erreurs.isNotEmpty;
    final aDesAvertissements = !aUneErreur && warnings.isNotEmpty;

    final Color couleur;
    final IconData icone;
    final String texte;
    final String infobulle;

    if (error != null) {
      couleur = Colors.redAccent;
      icone = Icons.error_outline;
      texte = "Ligne ${errorLine ?? '?'} : $error";
      infobulle = error!;
    } else if (erreurs.isNotEmpty) {
      final n = erreurs.length;
      couleur = Colors.redAccent;
      icone = Icons.error_outline;
      texte = n == 1 ? "1 erreur, ${erreurs.first}" : "$n erreurs, ${erreurs.first}";
      // L'infobulle liste tout, erreurs d'abord : les avertissements restants
      // sont utiles à voir, même s'ils ne sont pas ce qui bloque.
      infobulle = [
        ...erreurs.map((d) => '• $d'),
        ...warnings.where((d) => !d.estErreur).map((d) => '◦ $d'),
      ].join('\n');
    } else if (aDesAvertissements) {
      final n = warnings.length;
      couleur = SenAlgoTheme.neonYellow;
      icone = Icons.warning_amber_outlined;
      texte = n == 1 ? "1 avertissement, ${warnings.first}" : "$n avertissements, ${warnings.first}";
      infobulle = warnings.map((a) => '• $a').join('\n');
    } else {
      couleur = SenAlgoTheme.neonGreen.withValues(alpha: 0.7);
      icone = Icons.check_circle_outline;
      texte = "Aucune erreur";
      infobulle = 'Aucune erreur détectée';
    }

    return InkWell(
      onTap: (aUneErreur || aDesAvertissements) ? onTap : null,
      child: Tooltip(
        message: infobulle,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 14, color: couleur),
            const SizedBox(width: 4),
            // `Flexible` est indispensable : sans lui, le message d'erreur
            // prend sa largeur naturelle et déborde du panneau (l'ellipsis
            // seule ne suffit pas, elle n'agit que sous contrainte).
            Flexible(
              child: Text(
                texte,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: aUneErreur ? Colors.redAccent : (aDesAvertissements ? couleur : Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
