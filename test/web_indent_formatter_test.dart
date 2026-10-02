import 'package:flutter/services.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:senalgo/ui/editor/web_indent_formatter.dart';

void main() {
  const formatter = WebIndentFormatter(EditorParams());

  test('une saisie native Entrée indente le SI et positionne le curseur', () {
    const text = 'ALGORITHME T\nDEBUT\n  SI vrai ALORS\nFIN';
    final offset = text.indexOf('ALORS') + 5;
    final before = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: offset));
    final native = TextEditingValue(text: text.replaceRange(offset, offset, '\n'), selection: TextSelection.collapsed(offset: offset + 1));
    final result = formatter.formatEditUpdate(before, native);
    expect(result.text, contains('  SI vrai ALORS\n    \n  FinSi'));
    expect(result.selection, TextSelection.collapsed(offset: offset + 5));
  });

  test('une ligne ordinaire conserve son indentation', () {
    const before = TextEditingValue(text: '  x <- 1', selection: TextSelection.collapsed(offset: 8));
    const native = TextEditingValue(text: '  x <- 1\n', selection: TextSelection.collapsed(offset: 9));
    final result = formatter.formatEditUpdate(before, native);
    expect(result.text, '  x <- 1\n  ');
    expect(result.selection.baseOffset, 11);
  });

  test('le collage de plusieurs lignes reste intact', () {
    const before = TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0));
    const pasted = TextEditingValue(text: 'DEBUT\n  x <- 1\nFIN', selection: TextSelection.collapsed(offset: 18));
    expect(formatter.formatEditUpdate(before, pasted), pasted);
  });

  test('un retour déjà indenté ne subit aucune seconde insertion', () {
    const before = TextEditingValue(text: '  x <- 1', selection: TextSelection.collapsed(offset: 8));
    const indented = TextEditingValue(text: '  x <- 1\n  ', selection: TextSelection.collapsed(offset: 11));
    expect(formatter.formatEditUpdate(before, indented), indented);
  });
}
