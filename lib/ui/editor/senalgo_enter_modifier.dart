import 'package:flutter/widgets.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';

// Extrait de main_screen.dart lors du decoupage : contenu inchange.

// Mots-clés qui ouvrent un bloc (avec leur fermeture officielle), utilisés
// par l'indentation intelligente. On reconnaît volontairement toutes les
// variantes (accentuées ou non, "Tant que" en un ou deux mots...).
const Map<String, String> _blockClosers = {
  'si': 'FinSi',
  'pour': 'FinPour',
  'tantque': 'FinTantQue',
  'tant': 'FinTant que', // "Tant que" écrit en 2 mots -> fermeture officielle assortie
  'selon': 'FinSelon',
  'fonction': 'Fin',
  'procedure': 'Fin',
  'procédure': 'Fin',
  'algorithme': 'Fin',
};

// Utilisé par le scan mot-à-mot de _nearestOpener (inclut les fragments
// d'un mot-clé composé comme "fintant" dans "FinTant que").
const Set<String> _closingWordFragments = {
  'finsi', 'finpour', 'fintantque', 'fintant', 'finselon', 'fin', 'sinon', 'sinonsi',
};

/// Trouve le mot-clé "ouvreur" de bloc le plus proche avant [offset], pour
/// décider quelle fermeture proposer (Si -> FinSi, Pour -> FinPour, etc.).
String? _nearestOpener(String textBeforeCursor) {
  final wordRegex = RegExp(r"[a-zA-Zà-ÿÀ-ß']+");
  String? found;
  int bestIndex = -1;
  for (final m in wordRegex.allMatches(textBeforeCursor)) {
    final w = m.group(0)!.toLowerCase();
    if (_blockClosers.containsKey(w) && m.start > bestIndex) {
      found = w;
      bestIndex = m.start;
    }
    // Un mot-clé de fermeture rencontré referme le bloc correspondant :
    // on "consomme" virtuellement le dernier ouvreur en le retirant de la
    // course pour ne pas ré-proposer un bloc déjà fermé.
    if (_closingWordFragments.contains(w)) {
      found = null;
      bestIndex = m.start;
    }
  }
  return found;
}

class SenAlgoEnterModifier extends CodeModifier {
  const SenAlgoEnterModifier() : super('\n');

  @override
  TextEditingValue? updateString(String text, TextSelection sel, EditorParams params) {
    if (!sel.isValid) return null;

    final beforeSelection = text.substring(0, sel.start);
    final lines = beforeSelection.split('\n');
    if (lines.isEmpty) return null;

    final lastLine = lines.last;
    final trimmedLastLine = lastLine.trim();
    final lowerLastLine = trimmedLastLine.toLowerCase();

    final indentMatch = RegExp(r'^(\s*)').firstMatch(lastLine);
    final currentIndent = indentMatch?.group(1) ?? "";

    final opensBlock = lowerLastLine.endsWith('alors') ||
        lowerLastLine.endsWith('faire') ||
        lowerLastLine.endsWith('debut') ||
        lowerLastLine.endsWith('début') ||
        lowerLastLine == 'sinon' ||
        lowerLastLine == 'repeter' ||
        lowerLastLine == 'répéter';

    if (!opensBlock) {
      return replace(text, sel.start, sel.end, '\n$currentIndent');
    }

    final newBodyIndent = '$currentIndent  ';

    final opener = _nearestOpener(beforeSelection);
    final closer = opener != null ? _blockClosers[opener] : null;

    if (closer != null) {
      bool needsCloser = true;
      final fullText = text.toLowerCase();
      int countWord(String w) {
        int c = 0;
        for (final m in RegExp(r"[a-zA-Zà-ÿÀ-ß']+").allMatches(fullText)) {
          if (m.group(0) == w) c++;
        }
        return c;
      }

      final cLower = closer.toLowerCase();
      if (cLower == 'finsi') {
        needsCloser = countWord('si') > countWord('finsi');
      } else if (cLower == 'finpour') {
        needsCloser = countWord('pour') > countWord('finpour');
      } else if (cLower == 'finselon') {
        needsCloser = countWord('selon') > countWord('finselon');
      } else if (cLower == 'fintantque' || cLower == 'fintant que') {
        needsCloser = (countWord('tantque') + countWord('tant')) > (countWord('fintantque') + countWord('fintant'));
      } else if (cLower == 'fin') {
        final openersCount = countWord('algorithme') + countWord('fonction') + countWord('procedure') + countWord('procédure');
        needsCloser = openersCount > countWord('fin');
      }

      if (!needsCloser) {
        return replace(text, sel.start, sel.end, '\n$newBodyIndent');
      }

      final insert = '\n$newBodyIndent\n$currentIndent$closer';
      final newText = text.replaceRange(sel.start, sel.end, insert);
      final offset = sel.start + 1 + newBodyIndent.length;
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: offset),
      );
    } else {
      return replace(text, sel.start, sel.end, '\n$newBodyIndent');
    }
  }
}
