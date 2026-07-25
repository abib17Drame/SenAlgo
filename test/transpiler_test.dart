import 'package:senalgo/core/lexer/lexer.dart';
import 'package:senalgo/core/parser/parser.dart';
import 'package:senalgo/core/transpiler/python_transpiler.dart';
import 'package:test/test.dart';

/// Traduit un programme SenAlgo en Python. Une NOUVELLE instance de
/// [PythonTranspiler] est utilisée à chaque appel (son état interne n'est pas
/// réinitialisable).
String versPython(String source) {
  final program = Parser(Lexer(source).scanTokens()).parse();
  return PythonTranspiler().transpile(program);
}

void main() {
  test('Programme simple : déclarations, affectation, affichage', () {
    final py = versPython('''
ALGORITHME Somme
VARIABLES
  a, b, s : entier
DEBUT
  a <- 5
  b <- 10
  s <- a + b
  ecrire("Total : ", s)
FIN
''');
    expect(py, contains('def main():'));
    expect(py, contains('a = 0'));
    expect(py, contains('s = (a + b)'));
    expect(py, contains("print(str('Total : ') + str(s), end='')"));
    expect(py, contains('if __name__ == "__main__":'));
  });

  test('SI / SINONSI / SINON devient if / elif / else', () {
    final py = versPython('''
ALGORITHME Signe
VARIABLES x : entier
DEBUT
  SI x > 0 ALORS
    ecrire("positif")
  SINONSI x < 0 ALORS
    ecrire("negatif")
  SINON
    ecrire("nul")
  FINSI
FIN
''');
    expect(py, contains('if (x > 0):'));
    expect(py, contains('elif (x < 0):'));
    expect(py, contains('else:'));
  });

  test('POUR ... PAS négatif reste correct en Python', () {
    final py = versPython('''
ALGORITHME Decompte
VARIABLES i : entier
DEBUT
  POUR i ALLANT DE 10 à 1 PAS -1 FAIRE
    ecrire(i)
  FINPOUR
FIN
''');
    // La borne de fin est ajustée selon le signe du pas pour que la borne
    // supérieure du pseudocode (inclusive) reste incluse côté Python.
    expect(py, contains('_pas_i = (-(1))'));
    expect(py, contains('for i in range(10, (1) + (1 if _pas_i > 0 else -1), _pas_i):'));
  });

  test('REPETER ... JUSQUA devient une boucle while True + break', () {
    final py = versPython('''
ALGORITHME Repete
VARIABLES n : entier
DEBUT
  REPETER
    n <- n + 1
  JUSQUA n > 3
FIN
''');
    expect(py, contains('while True:'));
    expect(py, contains('if (n > 3):'));
    expect(py, contains('break'));
  });

  test('Les indices de tableau sont décalés selon la borne inférieure', () {
    final py = versPython('''
ALGORITHME Tab
VARIABLES
  t : TABLEAU[1..5] DE entier
  i : entier
DEBUT
  t[1] <- 42
  i <- t[3]
FIN
''');
    expect(py, contains('t = [0] * (((5) - (1)) + 1)'));
    expect(py, contains('t[(1) - (1)] = 42'));
    expect(py, contains('i = t[(3) - (1)]'));
  });

  test('Lire est traduit avec la conversion correspondant au type déclaré', () {
    final py = versPython('''
ALGORITHME Saisie
VARIABLES
  n : entier
  r : reel
  nom : chaine
DEBUT
  Lire n
  Lire r
  Lire nom
FIN
''');
    expect(py, contains('n = int(input())'));
    expect(py, contains('r = float(input())'));
    expect(py, contains('nom = str(input())'));
  });

  test('Un paramètre "résultat" devient une valeur de retour', () {
    final py = versPython('''
ALGORITHME Test
PROCEDURE Doubler(donnee x : entier, resultat y : entier)
DEBUT
  y <- x * 2
FIN

VARIABLES a, b : entier
DEBUT
  a <- 4
  Doubler(a, b)
FIN
''');
    expect(py, contains('def Doubler(x, y):'));
    expect(py, contains('return y'));
    // Côté appelant : affectation multiple, idiome Python standard.
    expect(py, contains('b = Doubler(a, b)'));
  });

  test('Les opérateurs booléens et la division entière sont traduits', () {
    final py = versPython('''
ALGORITHME Ops
VARIABLES a, b, c : entier
DEBUT
  c <- a DIV b
  c <- a MOD b
  SI a > 0 ET NON (b = 0) OU c ≠ 1 ALORS
    ecrire("ok")
  FINSI
FIN
''');
    expect(py, contains('c = (a // b)'));
    expect(py, contains('c = (a % b)'));
    expect(py, contains('and'));
    expect(py, contains('not'));
    expect(py, contains('or'));
    expect(py, contains('!='));
  });

  test('Les apostrophes des chaînes sont échappées', () {
    final py = versPython('''
ALGORITHME Texte
DEBUT
  ecrire("aujourd'hui")
FIN
''');
    expect(py, contains("aujourd\\'hui"));
  });
}
