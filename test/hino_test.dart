// test/hino_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hinarios_app/domain/models/hino.dart';

void main() {
  test('parse de hino completo com cifra', () {
    final h = Hino.fromJson({
      'slug': 'mestre-irineu/1/sol-lua-estrela',
      'num': 1,
      'nome': 'Sol, Lua, Estrela',
      'autor': 'Mestre Irineu',
      'autor_full': 'Raimundo Irineu Serra',
      'hinario': 'O Cruzeiro Universal',
      'urlhinario': 'o-cruzeiro',
      'ritmo': 'marcha',
      'letra': 'Sol, Lua, Estrela',
      'cifra': {'tom': 'D', 'texto': 'D Bm; A D'},
      'abc': 'A,2 |"D" D2 |',
    });
    expect(h.slug, 'mestre-irineu/1/sol-lua-estrela');
    expect(h.num, 1);
    expect(h.cifra!.tom, 'D');
    expect(h.abc, 'A,2 |"D" D2 |');
  });

  // Regressão C1: NBSP (U+00A0) vira espaço ASCII no parse — o split por
  // espaço simples da UI volta a enxergar cada acorde.
  test('parse normaliza NBSP na cifra e na letra', () {
    final h = Hino.fromJson({
      'slug': 'a/1/nbsp',
      'num': 1,
      'nome': 'NBSP',
      'autor': '',
      'autor_full': '',
      'hinario': '',
      'urlhinario': '',
      'ritmo': '',
      'letra': 'Linha com NBSP',
      'cifra': {'tom': 'D', 'texto': 'D A D'},
    });
    expect(h.cifra!.texto, 'D A D');
    expect(h.letra, 'Linha com NBSP');
    expect(h.cifra!.texto.contains(' '), isFalse);
    expect(h.letra.contains(' '), isFalse);
  });

  // Regressão D1 (caso real do acervo): 11 cifras vieram do site só com
  // lixo (';;;; ;;;;' ou 'undefined;undefined;') — nenhum acorde. Sem o
  // guard a UI mostra 'Cifra em Am' + botões de transposição sem nada
  // dentro; com o guard vira 'Adicionar cifra' (a comunidade preenche).
  test('cifra só com lixo ";;;;" vira nula', () {
    final h = Hino.fromJson({
      'slug': 'jose-ricardo/6/agradecimento',
      'num': 6,
      'nome': 'Agradecimento',
      'autor': '', 'autor_full': '', 'hinario': '', 'urlhinario': '', 'ritmo': '',
      'letra': 'Agradeço',
      'cifra': {'tom': 'Am', 'texto': ';;;; ;;;;'},
    });
    expect(h.cifra, isNull);
  });

  test('cifra só com "undefined;" vira nula', () {
    final h = Hino.fromJson({
      'slug': 'alex-polari/31/dama-das-flores',
      'num': 31,
      'nome': 'Dama das Flores',
      'autor': '', 'autor_full': '', 'hinario': '', 'urlhinario': '', 'ritmo': '',
      'letra': 'Dama',
      'cifra': {'tom': 'E', 'texto': 'undefined;undefined;undefined;'},
    });
    expect(h.cifra, isNull);
  });

  // Controle: 'Am;E7' tem acorde de verdade e continua cifra.
  test('cifra com acorde real ("Am;E7") não é afetada pelo guard', () {
    final h = Hino.fromJson({
      'slug': 'a/1/real',
      'num': 1,
      'nome': 'Real',
      'autor': '', 'autor_full': '', 'hinario': '', 'urlhinario': '', 'ritmo': '',
      'letra': 'Letra',
      'cifra': {'tom': 'Am', 'texto': 'Am;E7'},
    });
    expect(h.cifra, isNotNull);
    expect(h.cifra!.tom, 'Am');
    expect(h.cifra!.texto, 'Am;E7');
  });

  test('hino sem cifra nem abc', () {
    final h = Hino.fromJson({
      'slug': 'a', 'num': 0, 'nome': 'X', 'autor': '',
      'autor_full': '', 'hinario': '', 'urlhinario': '', 'ritmo': '', 'letra': '',
    });
    expect(h.cifra, isNull);
    expect(h.abc, isNull);
    expect(h.letra, '');
  });
}
