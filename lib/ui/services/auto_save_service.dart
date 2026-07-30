import 'package:shared_preferences/shared_preferences.dart';

/// Conservation du programme en cours d'édition d'un lancement à l'autre.
///
/// Sans elle, fermer l'application — ou la voir tuée par Android en arrière-plan
/// — fait perdre tout le travail non enregistré dans un fichier `.algo`.
/// C'est une reprise après interruption, pas un remplacement de la sauvegarde
/// explicite : un seul programme est conservé, celui de la dernière session.
///
/// Aucune erreur n'est propagée. Un échec de stockage ne doit jamais empêcher
/// d'écrire du code : dans le pire des cas la reprise ne fonctionne pas, ce qui
/// ramène au comportement d'avant.
class AutoSaveService {
  const AutoSaveService._();

  static const String _cle = 'senalgo.programme_en_cours';

  /// Enregistre [source]. Ne lève jamais.
  static Future<void> enregistrer(String source) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cle, source);
    } catch (_) {
      // Stockage indisponible : on continue sans reprise.
    }
  }

  /// Relit le programme de la session précédente.
  ///
  /// Renvoie `null` s'il n'y en a pas, si le stockage est indisponible, ou si
  /// ce qui a été retrouvé est vide — auquel cas l'appelant garde le programme
  /// d'exemple par défaut plutôt que d'ouvrir un éditeur vide.
  static Future<String?> reprendre() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final source = prefs.getString(_cle);
      if (source == null || source.trim().isEmpty) return null;
      return source;
    } catch (_) {
      return null;
    }
  }

  /// Oublie le programme conservé.
  static Future<void> effacer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cle);
    } catch (_) {
      // Sans effet observable pour l'utilisateur.
    }
  }
}
