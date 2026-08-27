// test/alinhamento_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hinarios_app/domain/use_cases/alinhamento.dart';

void main() {
  test('pareamento posicional 1:1', () {
    final linhas = alinhar(
      'Pai nosso que está no céu\nSantificado é nosso Senhor',
      '       D                          Bm;           D                       F#m',
    );
    expect(linhas.length, 2);
    expect(linhas[0].acordes, contains('D'));
    expect(linhas[0].texto, 'Pai nosso que está no céu');
    expect(linhas[1].acordes, contains('F#m'));
  });

  test('linhas vazias da letra mapeiam para compassos vazios', () {
    final linhas = alinhar(
      'Linha um\n\nLinha três',
      'D Bm; ; Em Am',
    );
    expect(linhas.length, 3);
    expect(linhas[1].acordes, isNull);
    expect(linhas[2].acordes, contains('Em'));
  });

  test('fallback: não-vazios casados na ordem', () {
    final linhas = alinhar(
      'A\n\nB\n\nC',
      'D; Em; F',
    );
    expect(linhas.where((l) => l.texto.isNotEmpty).map((l) => l.acordes),
        ['D', 'Em', 'F']);
  });

  test('letra sem cifra ou cifra sem letra', () {
    expect(alinhar('A', ''), hasLength(1));
    expect(alinhar('', ''), isEmpty);
  });
}
