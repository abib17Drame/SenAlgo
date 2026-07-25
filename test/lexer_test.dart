import 'package:senalgo/core/lexer/lexer.dart';
import 'package:senalgo/core/lexer/token.dart';
import 'package:test/test.dart';

void main() {
  test('Lexer scans basic pseudo-code in French', () {
    const source = '''
ALGORITHME Test
VAR a, b: entier
DEBUT
  a <- 5
  b <- 10.5
  SI a < b ALORS
    ecrire("Petit")
  SINON
    ecrire("Grand")
  FINSI
FIN
''';
    final lexer = Lexer(source);
    final tokens = lexer.scanTokens();
    expect(tokens.any((t) => t.type == TokenType.ALGORITHME), isTrue);
    expect(tokens.any((t) => t.type == TokenType.VAR), isTrue);
    expect(tokens.any((t) => t.type == TokenType.DEBUT), isTrue);
    expect(tokens.any((t) => t.type == TokenType.AFFECTATION), isTrue);
    expect(tokens.any((t) => t.type == TokenType.ENTIER && t.literal == 5), isTrue);
    expect(tokens.any((t) => t.type == TokenType.REEL && t.literal == 10.5), isTrue);
    expect(tokens.any((t) => t.type == TokenType.SI), isTrue);
    expect(tokens.any((t) => t.type == TokenType.CHAINE && t.literal == 'Petit'), isTrue);
    expect(tokens.any((t) => t.type == TokenType.FIN), isTrue);
    expect(tokens.last.type, TokenType.EOF);
  });

  test('Lexer handles accents and French keywords', () {
    const source = 'début réel tantque répéter jusqu\'à finsi';
    final lexer = Lexer(source);
    final tokens = lexer.scanTokens();
    expect(tokens[0].type, TokenType.DEBUT);
    expect(tokens[1].type, TokenType.T_REEL);
    expect(tokens[2].type, TokenType.TANTQUE);
    expect(tokens[3].type, TokenType.REPETER);
    expect(tokens[4].type, TokenType.JUSQUA);
    expect(tokens[5].type, TokenType.FINSI);
  });
}
