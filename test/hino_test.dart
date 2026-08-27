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
