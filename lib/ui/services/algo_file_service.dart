import 'dart:io';

import 'package:file_picker/file_picker.dart';

/// Lecture et écriture des fichiers `.algo`.
///
/// Extrait de `main_screen.dart` lors du découpage. Ne contient volontairement
/// aucun élément d'interface : les messages de succès ou d'erreur restent à la
/// charge de l'écran appelant, ce qui rend ces fonctions testables et évite de
/// manipuler un `BuildContext` après un `await`.
class AlgoFileService {
  const AlgoFileService._();

  /// Demande un fichier à l'utilisateur et renvoie son contenu.
  ///
  /// Renvoie `null` si la sélection est annulée. Les erreurs de lecture sont
  /// propagées à l'appelant.
  static Future<String?> pickAndRead() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['algo', 'txt'],
    );
    final path = result?.files.single.path;
    if (path == null) return null;
    return File(path).readAsString();
  }

  /// Propose d'enregistrer [content] dans un fichier `.algo`.
  ///
  /// Renvoie `true` si le fichier a bien été écrit, `false` si l'utilisateur a
  /// annulé. Les erreurs d'écriture sont propagées à l'appelant.
  static Future<bool> pickAndWrite(String content) async {
    final path = await FilePicker.saveFile(
      dialogTitle: 'Sauvegarder votre algorithme',
      fileName: suggestedFileName(content),
      type: FileType.custom,
      allowedExtensions: ['algo'],
    );
    if (path == null) return false;
    await File(path).writeAsString(content);
    return true;
  }

  /// Nom de fichier proposé par défaut, déduit du nom de l'algorithme déclaré
  /// dans [source]. Retombe sur `mon_algorithme.algo` en l'absence de nom.
  static String suggestedFileName(String source) {
    final match = RegExp(r'ALGORITHME\s+([a-zA-Zà-ÿÀ-ß0-9_]+)', caseSensitive: false).firstMatch(source);
    final nom = match?.group(1);
    return nom == null ? 'mon_algorithme.algo' : '$nom.algo';
  }
}
