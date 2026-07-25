/// Types manipulés par l'analyse sémantique.
library;

enum TypeBase { entier, reel, booleen, caractere, chaine, tableau, vide, inconnu }

/// Type d'une variable ou d'une expression.
///
/// [TypeBase.inconnu] n'est pas une erreur : c'est le type attribué à tout ce
/// que l'analyse ne sait pas déterminer. Aucun avertissement n'est jamais émis
/// à partir d'un type inconnu, ce qui garantit qu'un programme valide mais
/// écrit d'une façon inattendue ne déclenche pas de faux signalement.
class TypeSenAlgo {
  final TypeBase base;

  /// Type des éléments, uniquement lorsque [base] vaut [TypeBase.tableau].
  final TypeBase element;

  const TypeSenAlgo(this.base, {this.element = TypeBase.inconnu});

  static const inconnu = TypeSenAlgo(TypeBase.inconnu);
  static const vide = TypeSenAlgo(TypeBase.vide);
  static const entier = TypeSenAlgo(TypeBase.entier);
  static const reel = TypeSenAlgo(TypeBase.reel);
  static const booleen = TypeSenAlgo(TypeBase.booleen);
  static const caractere = TypeSenAlgo(TypeBase.caractere);
  static const chaine = TypeSenAlgo(TypeBase.chaine);

  bool get estConnu => base != TypeBase.inconnu;
  bool get estNumerique => base == TypeBase.entier || base == TypeBase.reel;
  bool get estTableau => base == TypeBase.tableau;

  /// Normalise un nom de type écrit dans le programme.
  ///
  /// Accepte les accents, les pluriels et les formes issues de « tableau de X »
  /// / « tableau d'X », le lexeur agglomérant l'apostrophe au mot suivant.
  static TypeBase baseDepuisNom(String nom) {
    var t = nom.toLowerCase().trim();
    if (t.startsWith("d'")) t = t.substring(2);
    if (t.startsWith("'")) t = t.substring(1);
    if (t.endsWith("'")) t = t.substring(0, t.length - 1);
    t = t.trim();
    if (t.endsWith('s')) t = t.substring(0, t.length - 1);
    switch (t) {
      case 'entier':
        return TypeBase.entier;
      case 'reel':
      case 'réel':
        return TypeBase.reel;
      case 'booleen':
      case 'booléen':
        return TypeBase.booleen;
      case 'caractere':
      case 'caractère':
        return TypeBase.caractere;
      case 'chaine':
      case 'chaîne':
        return TypeBase.chaine;
      default:
        return TypeBase.inconnu;
    }
  }

  factory TypeSenAlgo.depuisNom(String nom) => TypeSenAlgo(baseDepuisNom(nom));

  factory TypeSenAlgo.tableauDe(String nomElement) =>
      TypeSenAlgo(TypeBase.tableau, element: baseDepuisNom(nomElement));

  /// Libellé lisible, pour les messages destinés à l'utilisateur.
  String get libelle {
    switch (base) {
      case TypeBase.entier:
        return 'entier';
      case TypeBase.reel:
        return 'réel';
      case TypeBase.booleen:
        return 'booléen';
      case TypeBase.caractere:
        return 'caractère';
      case TypeBase.chaine:
        return 'chaîne';
      case TypeBase.tableau:
        return 'tableau';
      case TypeBase.vide:
        return 'sans valeur';
      case TypeBase.inconnu:
        return 'indéterminé';
    }
  }

  /// Peut-on affecter une valeur de type [source] à une cible de ce type ?
  ///
  /// Seul l'élargissement `entier → réel` est admis : un entier EST un réel,
  /// alors que l'inverse perdrait la partie décimale. Un caractère est admis
  /// dans une chaîne, cas courant et sans perte.
  bool accepte(TypeSenAlgo source) {
    if (!estConnu || !source.estConnu) return true;
    if (base == source.base) return true;
    if (base == TypeBase.reel && source.base == TypeBase.entier) return true;
    if (base == TypeBase.chaine && source.base == TypeBase.caractere) return true;
    return false;
  }

  @override
  bool operator ==(Object other) =>
      other is TypeSenAlgo && other.base == base && other.element == element;

  @override
  int get hashCode => Object.hash(base, element);

  @override
  String toString() => estTableau ? 'tableau de ${TypeSenAlgo(element).libelle}' : libelle;
}
