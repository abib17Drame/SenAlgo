import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/analyzer/semantic_analyzer.dart';
import '../core/lexer/lexer.dart';
import '../core/parser/parser.dart';

/// Résultat de l'analyse du programme en cours d'édition.
///
/// Une erreur de syntaxe et des avertissements sémantiques sont mutuellement
/// exclusifs : tant que la syntaxe est fautive, l'arbre est incomplet et
/// l'analyse sémantique n'aurait aucun sens.
class Diagnostics {
  /// Message de l'erreur de syntaxe, `null` si le programme est bien formé.
  final String? error;

  /// Ligne de l'erreur, lorsqu'elle a pu être extraite du message.
  final int? errorLine;

  /// Avertissements sémantiques. N'empêchent jamais l'exécution.
  final List<SemanticWarning> warnings;

  const Diagnostics({this.error, this.errorLine, this.warnings = const []});

  static const vide = Diagnostics();

  bool get aUneErreur => error != null;
  bool get aDesAvertissements => error == null && warnings.isNotEmpty;

  /// Ligne vers laquelle amener le curseur au clic sur le badge.
  int? get ligneAAtteindre => errorLine ?? (warnings.isNotEmpty ? warnings.first.line : null);
}

class DiagnosticsNotifier extends Notifier<Diagnostics> {
  @override
  Diagnostics build() => Diagnostics.vide;

  /// Analyse [source] et met à jour l'état.
  ///
  /// L'appelant est responsable du différé : analyser à chaque frappe serait
  /// inutilement coûteux.
  void analyser(String source) {
    try {
      final programme = Parser(Lexer(source).scanTokens()).parse();
      state = Diagnostics(warnings: SemanticAnalyzer().analyser(programme));
    } catch (e) {
      final message = e.toString();
      final ligne = RegExp(r'ligne (\d+)').firstMatch(message);
      state = Diagnostics(
        error: message,
        errorLine: ligne != null ? int.tryParse(ligne.group(1)!) : null,
      );
    }
  }
}

final diagnosticsProvider =
    NotifierProvider<DiagnosticsNotifier, Diagnostics>(DiagnosticsNotifier.new);
