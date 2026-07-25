import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/lexer/lexer.dart';
import '../../core/parser/parser.dart';
import '../../core/transpiler/python_transpiler.dart';
import '../theme.dart';

/// Traduit [source] en Python et affiche le résultat dans une boîte de
/// dialogue, avec un bouton de copie.
///
/// Extrait de `main_screen.dart` lors du découpage. Seule différence de
/// comportement : la largeur, auparavant figée à 700 pixels, s'adapte
/// désormais aux petits écrans.
Future<void> showPythonTranslationDialog(BuildContext context, String source) {
  String pythonCode;
  String? error;
  try {
    final tokens = Lexer(source).scanTokens();
    final program = Parser(tokens).parse();
    pythonCode = PythonTranspiler().transpile(program);
  } catch (e) {
    pythonCode = '';
    error = e.toString();
  }

  final messenger = ScaffoldMessenger.of(context);

  return showDialog(
    context: context,
    builder: (dialogContext) {
      final tailleEcran = MediaQuery.sizeOf(dialogContext);
      return Dialog(
        backgroundColor: SenAlgoTheme.surfaceBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: math.min(700, tailleEcran.width * 0.9),
          constraints: BoxConstraints(maxHeight: math.min(600, tailleEcran.height * 0.85)),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.code, color: SenAlgoTheme.neonYellow),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Traduction en Python',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (error != null)
                Text(
                  'Impossible de traduire : corrige d\'abord les erreurs du programme.\n$error',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                )
              else ...[
                Flexible(
                  child: SingleChildScrollView(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: SelectableText(
                        pythonCode,
                        style: GoogleFonts.firaCode(fontSize: 12, color: Colors.white),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: pythonCode));
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Code Python copié !'), duration: Duration(seconds: 2)),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copier'),
                    style: ElevatedButton.styleFrom(backgroundColor: SenAlgoTheme.neonCyan.withValues(alpha: 0.2)),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
