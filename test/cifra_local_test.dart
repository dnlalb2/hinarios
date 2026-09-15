import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinarios_app/domain/models/cifra_local.dart';
import 'package:hinarios_app/domain/use_cases/alinhamento.dart';
import 'package:hinarios_app/domain/use_cases/chordpro.dart';

void main() {
  test('toJson/fromJson do formato novo (tom + texto) faz round-trip', () {
    const cifra = CifraLocal(tom: 'D', texto: '[D]Quem não [A]anda');
    final volta = CifraLocal.fromJson(
        jsonDecode(jsonEncode(cifra.toJson())) as Map<String, dynamic>);
    expect(volta.tom, 'D');
    expect(volta.texto, '[D]Quem não [A]anda');
    expect(volta.acordesPorLinha, isEmpty);
  });

  // MIGRADA (com texto): o campo legado NUNCA vai para o disco — nem se a
  // lista ainda estiver no objeto (o editor grava CifraLocal(tom:, texto:)).
  test('toJson de uma cifra migrada não escreve o campo legado', () {
    const cifra = CifraLocal(tom: 'D', texto: '[D]Um');
    expect(cifra.toJson(), {'tom': 'D', 'texto': '[D]Um'});
    expect(cifra.toJson().containsKey('acordes'), isFalse);

    const comResto = CifraLocal(tom: 'D', texto: '[D]Um', acordesPorLinha: ['  D']);
    expect(comResto.toJson().containsKey('acordes'), isFalse);
  });

  // NÃO MIGRADA: uma cifra que só existe no formato antigo (nunca aberta no
  // editor) é regravada com os acordes. O _persistir do view model regrava o
  // mapa inteiro — sem isto, salvar OUTRA cifra apagaria estes acordes.
  test('toJson de uma cifra legada preserva os acordes', () {
    final legada = CifraLocal.fromJson(const {
      'tom': 'D',
      'acordes': ['   Am   E7', 'A'],
    });
    expect(legada.toJson(), {
      'tom': 'D',
      'texto': '',
      'acordes': ['   Am   E7', 'A'],
    });
  });

  // Round-trip do que fica no disco para uma cifra ainda não migrada: os
  // acordes continuam lá (e o editor migra depois, ao salvar).
  test('round-trip de uma cifra legada não perde os acordes', () {
    const acordes = ['   Am   E7', 'A'];
    const legada = CifraLocal(tom: 'D', acordesPorLinha: acordes);
    final volta = CifraLocal.fromJson(
        jsonDecode(jsonEncode(legada.toJson())) as Map<String, dynamic>);
    expect(volta.texto, '');
    expect(volta.acordesPorLinha, acordes);
    expect(volta.textoChordPro('Só a letra'), 'Só [Am]a let[E7]ra');
  });

  test('fromJson tolera campos ausentes/estranhos', () {
    final vazia = CifraLocal.fromJson(const {});
    expect(vazia.tom, '');
    expect(vazia.texto, '');
    expect(vazia.acordesPorLinha, isEmpty);

    final mista = CifraLocal.fromJson(const {
      'tom': 'G',
      'texto': 42,
      'acordes': ['G', 42, 'D'],
    });
    expect(mista.texto, ''); // não-String é descartado
    expect(mista.acordesPorLinha, ['G', 'D']); // não-String é descartado
  });

  test('textoChordPro: formato novo devolve o próprio texto', () {
    const cifra = CifraLocal(tom: 'D', texto: '[D]Um [A]dois');
    expect(cifra.textoChordPro('letra do acervo'), '[D]Um [A]dois');
  });

  // MIGRAÇÃO: o formato antigo guardava a coluna do acorde em espaços. A
  // conversão insere o colchete ANTES do caractere daquela coluna — a coluna
  // sobrevive, e o parsearChordPro devolve a string original.
  test('textoChordPro converte o legado preservando as colunas', () {
    const legado = CifraLocal(tom: 'D', acordesPorLinha: ['   Am   E7']);
    final texto = legado.textoChordPro('Só a letra');
    expect(texto, 'Só [Am]a let[E7]ra');

    final linha = parsearChordPro(texto).single;
    expect(linha.letra, 'Só a letra');
    expect(linha.acordes, '   Am   E7'); // colunas idênticas às do legado
  });

  test('textoChordPro: acorde além do fim da letra vira acorde no fim', () {
    const legado = CifraLocal(tom: 'D', acordesPorLinha: ['     D']);
    expect(legado.textoChordPro('Um'), 'Um   [D]');
  });

  test('textoChordPro: linha vazia não consome acorde (pareamento posicional)', () {
    const legado = CifraLocal(tom: 'D', acordesPorLinha: ['D', 'A']);
    expect(legado.textoChordPro('Um\n\nDois'), '[D]Um\n\n[A]Dois');
  });

  test('textoChordPro: acordes sobrando são ignorados, faltando vira nada', () {
    const sobrando = CifraLocal(tom: 'D', acordesPorLinha: ['D', 'G']);
    expect(sobrando.textoChordPro('Um'), '[D]Um');

    const faltando = CifraLocal(tom: 'D', acordesPorLinha: ['D']);
    expect(faltando.textoChordPro('Um\nDois'), '[D]Um\nDois');
  });

  test('textoChordPro normaliza CRLF como o alinhar()', () {
    const legado = CifraLocal(tom: 'D', acordesPorLinha: ['D', 'A']);
    expect(legado.textoChordPro('Um\r\nDois'), '[D]Um\n[A]Dois');
  });

  test('textoChordPro: cifra sem texto nem acordes devolve vazio', () {
    const vazia = CifraLocal(tom: 'D');
    expect(vazia.textoChordPro('Um'), '');
    expect(vazia.textoChordPro(''), '');
  });

  test('json legado (acordes por linha) é lido e vira ChordPro', () {
    final antiga = CifraLocal.fromJson(const {
      'tom': 'D',
      'acordes': ['   Am   E7'],
    });
    expect(antiga.texto, '');
    expect(antiga.textoChordPro('Só a letra'), 'Só [Am]a let[E7]ra');
  });

  // O par letra/cifra do alinhar() é POSICIONAL: textoChordPro +
  // parsearChordPro devolvem uma entrada por linha da letra (linha vazia
  // inclusive), então a linha vazia no meio não desloca os acordes seguintes.
  test('ChordPro alimenta o alinhar() 1:1 com as linhas', () {
    const cifra = CifraLocal(tom: 'D', texto: '[D]Primeira\n\n[G]Segunda');
    final linhas = parsearChordPro(cifra.textoChordPro('letra do acervo'));
    final letra = linhas.map((l) => l.letra).join('\n');
    final acordes = linhas.map((l) => l.acordes).join(';');
    expect(letra, 'Primeira\n\nSegunda');

    final pares = alinhar(letra, acordes);
    expect(pares.map((p) => p.acordes).toList(), ['D', null, 'G']);
    expect(pares.map((p) => p.texto).toList(), ['Primeira', '', 'Segunda']);
  });
}
