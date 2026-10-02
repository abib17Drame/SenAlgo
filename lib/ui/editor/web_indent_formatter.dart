import 'package:flutter/services.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';

import 'senalgo_enter_modifier.dart';

/// Le navigateur peut transmettre Entrée comme une saisie de texte plutôt
/// que comme le raccourci clavier. On indente cette saisie avant que le champ
/// l'applique, avec la sélection qui précédait le saut de ligne.
class WebIndentFormatter extends TextInputFormatter {
  final EditorParams params;

  const WebIndentFormatter(this.params);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final selection = oldValue.selection;
    if (!selection.isValid || !newValue.composing.isCollapsed) return newValue;
    final expected = oldValue.text.replaceRange(selection.start, selection.end, '\n');
    // Les collages, les autres frappes et les retours déjà indentés passent
    // intacts ; un saut de ligne seul est traité une seule fois.
    if (newValue.text != expected) return newValue;
    return const SenAlgoEnterModifier().updateString(
      oldValue.text, selection, params,
    ) ?? newValue;
  }
}
