import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:google_fonts/google_fonts.dart';

import '../editor/wrapping_code_field.dart';
import '../editor_highlight.dart';
import '../theme.dart';

/// Panneau d'édition : le champ de code, sa gouttière, le badge de
/// diagnostics et le bouton de retour à la ligne.
///
/// Extrait de `main_screen.dart` lors du découpage. Le [CodeController] reste
/// la propriété de l'écran principal, qui le crée et le libère ; ce panneau ne
/// fait que l'afficher.
class EditorPanel extends StatelessWidget {
  final CodeController controller;

  /// Badge d'état construit par l'écran principal, qui détient les
  /// diagnostics.
  final Widget diagnosticsBadge;

  /// Ligne en cours d'exécution en mode pas-à-pas, `null` sinon.
  final int? debugLine;

  /// Retour à la ligne automatique.
  final bool wrapLines;
  final VoidCallback onToggleWrap;

  /// Raccourcis clavier : F5 exécute, Ctrl+S sauvegarde.
  final VoidCallback onRun;
  final VoidCallback onSave;

  const EditorPanel({
    super.key,
    required this.controller,
    required this.diagnosticsBadge,
    required this.debugLine,
    required this.wrapLines,
    required this.onToggleWrap,
    required this.onRun,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f5): onRun,
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): onSave,
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Expanded(child: diagnosticsBadge),
                IconButton(
                  icon: Icon(
                    wrapLines ? Icons.wrap_text : Icons.swap_horiz,
                    size: 18,
                    color: wrapLines ? SenAlgoTheme.neonCyan : Colors.grey,
                  ),
                  tooltip: wrapLines
                      ? 'Retour à la ligne activé — cliquer pour défiler horizontalement'
                      : 'Défilement horizontal — cliquer pour revenir à la ligne',
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  onPressed: onToggleWrap,
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: SenAlgoTheme.surfaceBg.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: debugLine != null
                      ? SenAlgoTheme.neonCyan.withValues(alpha: 0.6)
                      : Colors.white10,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CodeTheme(
                  data: CodeThemeData(styles: SenAlgoSyntaxColors.styles),
                  child: WrappingCodeField(
                    controller: controller,
                    textStyle: GoogleFonts.firaCode(),
                    expands: true,
                    wrap: wrapLines,
                    gutterStyle: const GutterStyle(
                      width: 65,
                      margin: 10,
                      textStyle: TextStyle(color: Colors.grey),
                    ),
                    // Surligne le numéro de la ligne en cours d'exécution en
                    // mode pas-à-pas (mécanisme du package, positionnement
                    // toujours correct même avec le retour à la ligne/scroll).
                    lineNumberBuilder: (lineNumber, style) {
                      if (debugLine != null && lineNumber == debugLine) {
                        return TextSpan(
                          text: '▶ $lineNumber',
                          style: (style ?? const TextStyle()).copyWith(
                            color: SenAlgoTheme.neonCyan,
                            fontWeight: FontWeight.bold,
                            backgroundColor: SenAlgoTheme.neonCyan.withValues(alpha: 0.15),
                          ),
                        );
                      }
                      return TextSpan(text: '$lineNumber', style: style);
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
