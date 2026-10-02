import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/lexer/lexer.dart';
import '../../core/parser/parser.dart';
import '../../core/transpiler/python_transpiler.dart';
import '../theme.dart';

/// La présentation s'adapte à l'écran ; la traduction reste celle du cœur.
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
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final size = MediaQuery.sizeOf(dialogContext);
      final mobile = size.width < 600;
      final content = SafeArea(
        child: Padding(
          padding: EdgeInsets.all(mobile ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: SenAlgoTheme.neonYellow.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.code_rounded, color: SenAlgoTheme.neonYellow, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('Traduction en Python', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18))),
                IconButton(tooltip: 'Fermer la traduction', icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(dialogContext)),
              ]),
              const SizedBox(height: 12),
              const Text('Le même algorithme, dans un autre langage.', style: TextStyle(color: SenAlgoTheme.muted, fontSize: 13, height: 1.6)),
              const SizedBox(height: 20),
              Expanded(child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: SenAlgoTheme.darkBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: SenAlgoTheme.border)),
                child: SingleChildScrollView(child: SelectableText(
                  error != null ? 'Impossible de traduire : corrigez d’abord les erreurs du programme.\n\n$error' : pythonCode,
                  style: GoogleFonts.firaCode(fontSize: 13, height: 1.7, color: error != null ? const Color(0xFFFF9B9B) : SenAlgoTheme.ink),
                )),
              )),
              if (error == null) ...[
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: pythonCode));
                    messenger.showSnackBar(const SnackBar(content: Text('Code Python copié !'), duration: Duration(seconds: 2)));
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18), label: const Text('Copier le code Python'),
                )),
              ],
            ],
          ),
        ),
      );
      if (mobile) return Dialog.fullscreen(backgroundColor: SenAlgoTheme.surfaceBg, child: content);
      return Dialog(
        backgroundColor: SenAlgoTheme.surfaceBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: SizedBox(width: math.min(800, size.width * 0.88), height: math.min(720, size.height * 0.85), child: content),
      );
    },
  );
}
