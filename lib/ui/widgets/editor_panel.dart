import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:google_fonts/google_fonts.dart';

import '../editor/wrapping_code_field.dart';
import '../editor_highlight.dart';
import '../theme.dart';

class EditorPanel extends StatefulWidget {
  final CodeController controller;
  final Widget diagnosticsBadge;
  final int? debugLine;
  final bool wrapLines;
  final VoidCallback onToggleWrap;
  final VoidCallback onRun;
  final VoidCallback onSave;

  const EditorPanel({super.key, required this.controller, required this.diagnosticsBadge,
    required this.debugLine, required this.wrapLines, required this.onToggleWrap,
    required this.onRun, required this.onSave});

  @override
  State<EditorPanel> createState() => _EditorPanelState();
}

class _EditorPanelState extends State<EditorPanel> {
  final _focus = FocusNode();
  final _history = UndoHistoryController();
  double _fontSize = 14;

  @override
  void dispose() {
    _focus.dispose();
    _history.dispose();
    super.dispose();
  }

  void _insert(String value) {
    _focus.requestFocus();
    final controller = widget.controller;
    if (!controller.selection.isValid) {
      controller.selection = TextSelection.collapsed(offset: controller.text.length);
    }
    controller.insertStr(value);
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 800;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f5): widget.onRun,
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): widget.onSave,
      },
      child: Container(
        margin: EdgeInsets.all(mobile ? 12 : 8),
        decoration: BoxDecoration(
          color: SenAlgoTheme.surfaceBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: widget.debugLine != null ? SenAlgoTheme.neonCyan : SenAlgoTheme.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 4),
              child: LayoutBuilder(builder: (context, constraints) => Row(children: [
                if (constraints.maxWidth >= 220) ...[
                const Icon(Icons.description_outlined, size: 18, color: SenAlgoTheme.neonCyan),
                const SizedBox(width: 8),
                ],
                Expanded(child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: widget.controller,
                  builder: (context, value, _) {
                    final name = RegExp(r'ALGORITHME\s+([a-zA-Zà-ÿÀ-ß0-9_]+)', caseSensitive: false).firstMatch(value.text)?.group(1);
                    return Text(name == null ? 'Votre programme' : '$name.algo', overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13));
                  },
                )),
                if (constraints.maxWidth >= 280) ValueListenableBuilder<UndoHistoryValue>(
                  valueListenable: _history,
                  builder: (context, value, _) => Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(tooltip: 'Annuler la modification', onPressed: value.canUndo ? _history.undo : null, icon: const Icon(Icons.undo_rounded, size: 18)),
                    if (!mobile && constraints.maxWidth >= 360) IconButton(tooltip: 'Rétablir la modification', onPressed: value.canRedo ? _history.redo : null, icon: const Icon(Icons.redo_rounded, size: 18)),
                  ]),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Réglages de l’éditeur',
                  icon: const Icon(Icons.tune_rounded, size: 19),
                  onSelected: (value) {
                    if (value == 'wrap') widget.onToggleWrap();
                    if (value == 'larger') setState(() => _fontSize = (_fontSize + 1).clamp(12, 20).toDouble());
                    if (value == 'smaller') setState(() => _fontSize = (_fontSize - 1).clamp(12, 20).toDouble());
                    if (value == 'undo') _history.undo();
                    if (value == 'redo') _history.redo();
                  },
                  itemBuilder: (context) => [
                    if (constraints.maxWidth < 280) PopupMenuItem(value: 'undo', enabled: _history.value.canUndo, child: const Text('Annuler la modification')),
                    PopupMenuItem(value: 'larger', enabled: _fontSize < 20, child: const Text('Agrandir le texte')),
                    PopupMenuItem(value: 'smaller', enabled: _fontSize > 12, child: const Text('Réduire le texte')),
                    PopupMenuItem(value: 'wrap', child: Text(widget.wrapLines ? 'Défilement horizontal' : 'Retour à la ligne')),
                    if (mobile || constraints.maxWidth < 360) PopupMenuItem(value: 'redo', enabled: _history.value.canRedo, child: const Text('Rétablir la modification')),
                  ],
                ),
              ])),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 8),
              child: Row(children: [
                Expanded(child: widget.diagnosticsBadge),
                IconButton(
                  icon: Icon(widget.wrapLines ? Icons.wrap_text : Icons.swap_horiz, size: 18,
                    color: widget.wrapLines ? SenAlgoTheme.neonCyan : SenAlgoTheme.muted),
                  tooltip: widget.wrapLines ? 'Retour à la ligne activé, cliquer pour défiler horizontalement' : 'Défilement horizontal, cliquer pour revenir à la ligne',
                  onPressed: widget.onToggleWrap,
                ),
              ]),
            ),
            Expanded(
              child: CodeTheme(
                data: CodeThemeData(styles: SenAlgoSyntaxColors.styles),
                child: WrappingCodeField(
                  controller: widget.controller, undoController: _history, focusNode: _focus,
                  textStyle: GoogleFonts.firaCode(fontSize: _fontSize, height: 1.65, color: SenAlgoTheme.ink),
                  background: SenAlgoTheme.surfaceBg,
                  cursorColor: SenAlgoTheme.neonGreen,
                  padding: const EdgeInsets.only(top: 8, right: 16, bottom: 24),
                  expands: true, wrap: widget.wrapLines,
                  gutterStyle: GutterStyle(width: mobile ? 42 : 54, margin: 8, textStyle: const TextStyle(color: SenAlgoTheme.muted)),
                  lineNumberBuilder: (line, style) => TextSpan(
                    text: widget.debugLine == line ? '▶ $line' : '$line',
                    style: widget.debugLine == line ? (style ?? const TextStyle()).copyWith(
                      color: SenAlgoTheme.neonCyan, fontWeight: FontWeight.bold,
                      backgroundColor: SenAlgoTheme.neonCyan.withValues(alpha: 0.15),
                    ) : style,
                  ),
                ),
              ),
            ),
            if (mobile) ...[
              const Divider(height: 1),
              SizedBox(
                height: 48,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(children: [
                    if (keyboard) IconButton(tooltip: 'Masquer le clavier', onPressed: () => _focus.unfocus(), icon: const Icon(Icons.keyboard_hide_outlined, size: 20)),
                    for (final entry in const <String, String>{'⇥': '  ', '←': ' <- ', '(': '(', ')': ')', '[': '[', ']': ']', '"': '"', ':': ':', '≠': ' <> ', '≤': ' <= ', '≥': ' >= '}.entries)
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: TextButton(
                        onPressed: () => _insert(entry.value),
                        style: TextButton.styleFrom(minimumSize: const Size(44, 44), foregroundColor: SenAlgoTheme.ink, padding: const EdgeInsets.symmetric(horizontal: 12)),
                        child: Tooltip(message: entry.key == '⇥' ? 'Insérer une indentation' : 'Insérer ${entry.key}', child: Text(entry.key, style: GoogleFonts.firaCode(fontSize: 16))),
                      )),
                  ]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
