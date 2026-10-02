import 'package:flutter/material.dart';
import '../theme.dart';

void showLanguageGuide(BuildContext context) {
  showModalBottomSheet<void>(
    context: context, isScrollControlled: true, useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Text('Vos premiers pas', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700))),
            IconButton(tooltip: 'Fermer le guide', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
          ]),
          const Text('Écrivez en français. Observez ce qui se passe.', style: TextStyle(color: SenAlgoTheme.muted, height: 1.6)),
          const SizedBox(height: 24),
          for (final entry in const <String, String>{
            '1. Déclarer et calculer': 'VARIABLES\n  n : entier\nDEBUT\n  n <- 5 + 3\n  ecrire(n)\nFIN',
            '2. Demander une valeur': 'VARIABLES\n  nom : chaine\nDEBUT\n  ecrire("Votre prénom : ")\n  lire(nom)\n  ecrire("Bonjour ", nom)\nFIN',
            '3. Choisir': 'SI n > 0 ALORS\n  ecrire("Positif")\nSINON\n  ecrire("Nul ou négatif")\nFINSI',
            '4. Répéter': 'POUR i ALLANT DE 1 à 10 FAIRE\n  ecrire(i)\nFINPOUR',
          }.entries) ...[
            Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 10),
            Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: SenAlgoTheme.darkBg, borderRadius: BorderRadius.circular(14)),
              child: SelectableText(entry.value, style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.7, color: SenAlgoTheme.neonCyan))),
            const SizedBox(height: 24),
          ],
          const Text('Voir l’algorithme avancer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Choisissez « Pas à pas », puis « Suivant » pour exécuter une instruction. Le code indique la ligne courante et les variables montrent leurs valeurs. « Auto » avance à votre place. « Arrêter » interrompt le programme.', style: TextStyle(color: SenAlgoTheme.muted, height: 1.7)),
          const SizedBox(height: 24),
          const Text('Les gestes utiles', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Sur téléphone, la rangée sous le code donne accès aux symboles et à l’indentation. Les réglages permettent d’agrandir le texte.\n\nSur ordinateur : F5 pour exécuter, Ctrl+S pour sauvegarder, Ctrl+Z pour annuler.\n\nLe programme en cours est repris automatiquement au prochain lancement. Sauvegardez un fichier .algo pour conserver plusieurs programmes.', style: TextStyle(color: SenAlgoTheme.muted, height: 1.7)),
        ]),
      ),
    ),
  );
}
