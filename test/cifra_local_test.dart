// test/cifra_local_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinarios_app/domain/models/cifra_local.dart';
import 'package:hinarios_app/domain/use_cases/alinhamento.dart';

void main() {
  test('toJson/fromJson faz round-trip (tom + acordes por linha)', () {
    const cifra = CifraLocal(tom: 'D', acordesPorLinha: ['D Bm', '', 'A D']);
    final volta = CifraLocal.fromJson(
        jsonDecode(jsonEncode(cifra.toJson())) as Map<String, dynamic>);
    expect(volta.tom, 'D');
    expect(volta.acordesPorLinha, ['D Bm', '', 'A D']);
  });

  test('fromJson tolera campos ausentes/estranhos', () {
    final vazia = CifraLocal.fromJson(const {});
    expect(vazia.tom, '');
    expect(vazia.acordesPorLinha, isEmpty);

    final mista = CifraLocal.fromJson(const {
      'tom': 'G',
      'acordes': ['G', 42, 'D'],
    });
    expect(mista.acordesPorLinha, ['G', 'D']); // não-String é descartado
  });

  // O par letra/cifra do alinhar() é POSICIONAL quando as contagens batem:
  // textoCifra devolve UM compasso por linha da letra (linha vazia → compasso
  // vazio), então a linha vazia no meio NÃO desloca os acordes seguintes.
  test('textoCifra: um compasso por linha, linha vazia vira compasso vazio', () {
    const cifra = CifraLocal(tom: 'D', acordesPorLinha: ['D Bm', 'A']);
    expect(cifra.textoCifra('Linha um\n\nLinha dois'), 'D Bm;;A');
  });

  test('textoCifra casa 1:1 com as linhas da letra no alinhar()', () {
    const cifra = CifraLocal(tom: 'D', acordesPorLinha: ['D', 'G']);
    const letra = 'Primeira\n\nSegunda';
    final pares = alinhar(letra, cifra.textoCifra(letra));
    expect(pares.map((p) => p.acordes).toList(), ['D', null, 'G']);
    expect(pares.map((p) => p.texto).toList(), ['Primeira', '', 'Segunda']);
  });

  test('textoCifra: faltando acordes, as linhas restantes viram vazias', () {
    const cifra = CifraLocal(tom: 'D', acordesPorLinha: ['D']);
    expect(cifra.textoCifra('Um\nDois\nTrês'), 'D;;');
    expect(cifra.textoCifra('Um'), 'D');
    // Sobrando acordes, os extras são ignorados (não há linha para consumir).
    const sobrando = CifraLocal(tom: 'D', acordesPorLinha: ['D', 'G']);
    expect(sobrando.textoCifra('Um'), 'D');
  });

  test('textoCifra: letra vazia não gera compasso', () {
    const cifra = CifraLocal(tom: 'D', acordesPorLinha: ['D']);
    expect(cifra.textoCifra(''), '');
    expect(alinhar('', cifra.textoCifra('')), isEmpty);
  });

  test('textoCifra normaliza CRLF como o alinhar()', () {
    const cifra = CifraLocal(tom: 'D', acordesPorLinha: ['D', 'A']);
    expect(cifra.textoCifra('Um\r\nDois'), 'D;A');
  });
}
