import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/analyzer/semantic_analyzer.dart';
import '../core/lexer/lexer.dart';
import '../core/parser/parser.dart';

/// Résultat de l'analyse du programme en cours d'édition.
///
/// Une erreur de syntaxe et les signalements sémantiques sont mutuellement
/// exclusifs : tant que la syntaxe est fautive, l'arbre est incomplet et
/// l'analyse sémantique n'aurait aucun sens.
class Diagnostics {
  /// Message de l'erreur de syntaxe, `null` si le programme est bien formé.
  final String? error;

  /// Ligne de l'erreur, lorsqu'elle a pu être extraite du message.
  final int? errorLine;

  /// Signalements sémantiques, erreurs et avertissements mêlés, dans l'ordre
  /// des lignes.
  final List<SemanticDiagnostic> warnings;

  const Diagnostics({this.error, this.errorLine, this.warnings = const []});

  static const vide = Diagnostics();

  /// Signalements bloquants : le programme ne démarrera pas tant qu'il en
  /// reste un.
  List<SemanticDiagnostic> get erreurs => warnings.where((d) => d.estErreur).toList();

  /// Signalements informatifs : le programme démarre quand même.
  List<SemanticDiagnostic> get avertissements => warnings.where((d) => !d.estErreur).toList();

  /// Vrai si le programme ne peut pas tourner : syntaxe fautive, ou erreur
  /// sémantique.
  bool get aUneErreur => error != null || erreurs.isNotEmpty;

  bool get aDesAvertissements => !aUneErreur && warnings.isNotEmpty;

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
