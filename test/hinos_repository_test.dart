// test/hinos_repository_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinarios_app/data/repositories/hinos_repository.dart';
import 'package:hinarios_app/data/services/hinos_service.dart';
import 'package:hinarios_app/domain/models/hino.dart';

class HinosServiceFake implements HinosService {
  @override
  Future<String> carregarJson() async => jsonEncode([
        {
          'slug': 'a/1/um', 'num': 2, 'nome': 'Um', 'autor': 'A',
          'autor_full': 'A', 'hinario': 'Hinário X', 'urlhinario': 'x',
          'ritmo': 'marcha', 'letra': 'Letra do Um', 'cifra': {'tom': 'D', 'texto': 'D Bm; A D'},
        },
        {
          'slug': 'a/2/dois', 'num': 1, 'nome': 'Dois', 'autor': 'A',
          'autor_full': 'A', 'hinario': 'Hinário Y', 'urlhinario': 'y',
          'ritmo': '', 'letra': 'Letra do Dois',
        },
        {
          'slug': 'a/3/tres', 'num': 1, 'nome': 'Três', 'autor': 'A',
          'autor_full': 'A', 'hinario': 'Hinário X', 'urlhinario': 'x',
          'ritmo': '', 'letra': 'Terra e mar',
        },
        {
          'slug': 'b/1/quatro', 'num': 1, 'nome': 'Quatro', 'autor': 'B',
          'autor_full': 'B', 'hinario': 'Hinário X', 'urlhinario': 'x',
          'ritmo': '', 'letra': 'Outra coisa',
        },
        {
          'slug': 'a/5/cinco', 'num': 5, 'nome': 'Cinco', 'autor': 'A',
          'autor_full': 'A', 'hinario': 'Hinário X', 'urlhinario': 'z',
          'ritmo': '', 'letra': 'Letra do Cinco',
        },
      ]);
}

/// Fixture com hinos SEM url (caso real: 18 hinos do acervo) — a chave do
/// grupo passa a ser o NOME do hinário.
class HinosServiceSemUrlFake implements HinosService {
  @override
  Future<String> carregarJson() async => jsonEncode([
        {
          'slug': 'a/1/conc1', 'num': 1, 'nome': 'Concentração 1', 'autor': 'A',
          'autor_full': 'A', 'hinario': 'Concentração', 'urlhinario': '',
          'ritmo': '', 'letra': 'Letra 1',
        },
        {
          'slug': 'a/2/conc2', 'num': 2, 'nome': 'Concentração 2', 'autor': 'A',
          'autor_full': 'A', 'hinario': 'Concentração', 'urlhinario': '',
          'ritmo': '', 'letra': 'Letra 2',
        },
        {
          'slug': 'a/3/talisma', 'num': 1, 'nome': 'O Talismã', 'autor': 'A',
          'autor_full': 'A', 'hinario': 'O Talismã', 'urlhinario': '',
          'ritmo': '', 'letra': 'Letra 3',
        },
      ]);
}

/// Fixture mínima com indicadores ordinais na letra (caso real: '1ª VEZ').
class HinosServiceOrdinalFake implements HinosService {
  @override
  Future<String> carregarJson() async => jsonEncode([
        {
          'slug': 'a/1/ordinal', 'num': 1, 'nome': 'Ordinal', 'autor': 'A',
          'autor_full': 'A', 'hinario': 'Hinário X', 'urlhinario': 'x',
          'ritmo': '', 'letra': 'Entra 1ª VEZ, repete 2º refrão',
        },
      ]);
}

/// Fixture LOCAL (não mexe na compartilhada) com rótulos cuja ordem só sai
/// certa após normalização: por code point 'Índio' ('Í' = U+00CD) viria DEPOIS
/// de 'Jardim' ('J' = U+004A); normalizado, 'indio' < 'jardim' e 'Índio' vem
/// primeiro — é isso que prova que o [gruposGlobais] normaliza de verdade.
class HinosServiceRotulosFake implements HinosService {
  @override
  Future<String> carregarJson() async => jsonEncode([
        {
          'slug': 'i/1/indio', 'num': 1, 'nome': 'Índio', 'autor': 'A',
          'autor_full': 'A', 'hinario': 'Índio', 'urlhinario': 'indio',
          'ritmo': '', 'letra': 'Letra do Índio',
        },
        {
          'slug': 'j/1/jardim', 'num': 1, 'nome': 'Jardim', 'autor': 'A',
          'autor_full': 'A', 'hinario': 'Jardim', 'urlhinario': 'jardim',
          'ritmo': '', 'letra': 'Letra do Jardim',
        },
      ]);
}

/// Fixture LOCAL (não mexe na compartilhada) com autores e rótulos acentuados
/// que o sort cru joga para o fim: 'Índio' ('Í' = U+00CD > 'J' = U+004A),
/// 'Hino Índio' (o 'Í' do meio vence a comparação com 'Hino Jardim').
/// Ordenado por code point cru viria ['Jardim', 'Índio'] e
/// ['Hino Jardim', 'Hino Índio']; normalizado vem 'Índio'/'Hino Índio' antes.
/// As urls 'ind'/'ind2' têm o mesmo rótulo 'Hino Índio': com a contagem GLOBAL
/// empatada (1 hino cada), a chave menor ('ind') ganha o sufixo de colisão e a
/// maior ('ind2') fica com o rótulo puro.
class HinosServiceAutoresFake implements HinosService {
  @override
  Future<String> carregarJson() async => jsonEncode([
        {
          'slug': 'i/1/indio', 'num': 1, 'nome': 'Hino Um', 'autor': 'Índio',
          'autor_full': 'Índio', 'hinario': 'Hino Índio', 'urlhinario': 'ind',
          'ritmo': '', 'letra': 'Letra do Um',
        },
        {
          'slug': 'j/1/jardim', 'num': 1, 'nome': 'Hino Dois', 'autor': 'Jardim',
          'autor_full': 'Jardim', 'hinario': 'Hino Jardim', 'urlhinario': 'jar',
          'ritmo': '', 'letra': 'Letra do Dois',
        },
        // Mesmo autor 'Jardim', outra url (ind2): grupo próprio, rótulo 'Hino Índio'.
        {
          'slug': 'j/2/indio', 'num': 2, 'nome': 'Hino Três', 'autor': 'Jardim',
          'autor_full': 'Jardim', 'hinario': 'Hino Índio', 'urlhinario': 'ind2',
          'ritmo': '', 'letra': 'Letra do Três',
        },
      ]);
}

/// Fixture LOCAL com o termo SÓ na letra (acentuado, no meio de uma letra
/// longa e com quebra de linha): o trecho sai cortado nas duas pontas e o
/// destaque precisa cair sobre a palavra ORIGINAL, acentuada. O 2º hino casa
/// apenas pelo TOM da cifra — não pode gerar trecho nenhum.
class HinosServiceLetraFake implements HinosService {
  @override
  Future<String> carregarJson() async => jsonEncode([
        {
          'slug': 'c/1/coracao', 'num': 1, 'nome': 'Hino Bonito', 'autor': 'C',
          'autor_full': 'C', 'hinario': 'Hinário Z', 'urlhinario': 'z',
          'ritmo': '',
          // Sem 'f' em lugar nenhum: o 'f' da consulta só existe no TOM do 2º
          // hino ('F#'), então o casamento dele não pode gerar trecho.
          'letra': 'Primeira linha do hino\ncom palavras compridas e um coração '
              'no meio, e depois segue adiante com mais palavras no encerramento.',
        },
        {
          'slug': 'c/2/toada', 'num': 2, 'nome': 'Toada', 'autor': 'C',
          'autor_full': 'C', 'hinario': 'Hinário Z', 'urlhinario': 'z',
          'ritmo': '', 'letra': 'Sol e lua',
          'cifra': {'tom': 'F#', 'texto': 'F# B'},
        },
      ]);
}

void main() {
  test('carregar parseia e cacheia (service chamado uma vez)', () async {
    final service = HinosServiceFake();
    final repo = HinosRepository(service: service);
    final hinos = await repo.carregar();
    expect(hinos, hasLength(5));
    expect(hinos.first, isA<Hino>());
    final deNovo = await repo.carregar();
    expect(identical(hinos, deNovo), isTrue); // cache
  });

  test('gruposGlobais: url compartilhada por autores vira UM grupo (Diversos)', () async {
    final repo = HinosRepository(service: HinosServiceFake());
    await repo.carregar();
    final grupos = repo.gruposGlobais();
    // Rótulo normalizado asc: 'hinario x' < 'hinario x (z)' < 'hinario y'.
    expect(grupos.map((g) => '${g.autor}:${g.rotulo}'),
        ['Diversos:Hinário X', 'A:Hinário X (z)', 'A:Hinário Y']);
    // A url 'x' junta A (Três, Um) e B (Quatro) num grupo só, por num.
    final x = grupos.first;
    expect(x.hinos.map((h) => h.nome), ['Quatro', 'Três', 'Um']);
    expect(x.hinos.map((h) => h.autor).toSet(), {'A', 'B'});
    // Autor único: o grupo preserva o nome dele (não vira 'Diversos').
    expect(grupos[1].autor, 'A');
    expect(grupos[2].autor, 'A');
  });

  test('gruposGlobais: colisão de rótulo desambiguada pela contagem GLOBAL', () async {
    final repo = HinosRepository(service: HinosServiceFake());
    await repo.carregar();
    // As urls 'x' (Três+Quatro+Um) e 'z' (Cinco) têm o mesmo nome mais comum:
    // a maior ('x', 3 hinos com o de B) mantém o rótulo puro; a menor ganha sufixo.
    final grupos = repo.gruposGlobais();
    expect(grupos.map((g) => g.rotulo),
        ['Hinário X', 'Hinário X (z)', 'Hinário Y']);
    expect(grupos.first.hinos, hasLength(3)); // contagem global, não por autor
    expect(grupos[1].hinos.map((h) => h.nome), ['Cinco']);
  });

  test('agrupar: autor → grupos GLOBAIS em que ele tem hino', () async {
    final repo = HinosRepository(service: HinosServiceFake());
    await repo.carregar();
    final g = repo.agrupar();
    expect(g.keys, ['A', 'B']);
    expect(g['A']!.map((x) => '${x.autor}:${x.rotulo}'),
        ['Diversos:Hinário X', 'A:Hinário X (z)', 'A:Hinário Y']);
    // O coletivo aparece sob os DOIS autores — e é o MESMO grupo de 3 hinos,
    // não um recorte de 1 hino por autor.
    expect(g['B']!.map((x) => '${x.autor}:${x.rotulo}'), ['Diversos:Hinário X']);
    expect(g['B']!.single.hinos, hasLength(3));
    expect(identical(g['A']!.first, g['B']!.single), isTrue);
  });

  test('gruposGlobais: memoizado (mesma lista entre chamadas)', () async {
    final repo = HinosRepository(service: HinosServiceFake());
    await repo.carregar();
    expect(identical(repo.gruposGlobais(), repo.gruposGlobais()), isTrue);
  });

  test('agrupar: autores e rótulos ordenados sem acento (não code point)', () async {
    final repo = HinosRepository(service: HinosServiceAutoresFake());
    await repo.carregar();
    final g = repo.agrupar();
    // Code point cru daria ['Jardim', 'Índio'] ('Í' U+00CD > 'J' U+004A);
    // normalizado, 'indio' < 'jardim' → 'Índio' primeiro.
    expect(g.keys, ['Índio', 'Jardim']);
    // Idem intra-autor: cru daria ['Hino Jardim', 'Hino Índio'].
    expect(g['Jardim']!.map((x) => x.rotulo), ['Hino Índio', 'Hino Jardim']);
  });

  test('buscar: tokens todos presentes; ignora maiúsculas; tom conta', () async {
    final repo = HinosRepository(service: HinosServiceFake());
    await repo.carregar();
    expect(repo.buscar('um'), hasLength(1));          // nome 'Um'
    expect(repo.buscar('UM'), hasLength(1));
    expect(repo.buscar('terra mar'), hasLength(1));   // letra
    // tom da cifra (Um), nome 'Dois' e letra 'do' do Cinco
    expect(repo.buscar('D'), hasLength(3));
    expect(repo.buscar(''), hasLength(5));
    expect(repo.buscar('nada que exista'), isEmpty);
    // Query vazia: todos os hinos, nenhum com trecho (nada foi destacado).
    expect(repo.buscar('').every((r) => r.trecho == null), isTrue);
  });

  test('buscar: casamento pela letra traz o trecho com o termo destacado', () async {
    final repo = HinosRepository(service: HinosServiceFake());
    await repo.carregar();
    final r = repo.buscar('terra').single;
    expect(r.hino.nome, 'Três');
    expect(r.trecho, 'Terra e mar'); // letra inteira: coube na janela de 30
    expect(r.trecho!.substring(r.destaqueInicio!, r.destaqueFim!), 'Terra');
    // O destaque seleciona o TERMO buscado (normalizado, ignora caixa).
    expect(r.trecho!.substring(r.destaqueInicio!, r.destaqueFim!).toLowerCase(),
        'terra');
  });

  test('buscar: casamento por nome+autor+hinário não traz trecho', () async {
    final repo = HinosRepository(service: HinosServiceFake());
    await repo.carregar();
    for (final r in repo.buscar('um')) {
      expect(r.hino.nome, 'Um');
      expect(r.trecho, isNull);
      expect(r.destaqueInicio, isNull);
      expect(r.destaqueFim, isNull);
    }
    // 'hinario x' casa o cabeçalho (hinário) de todos eles — sem trecho.
    expect(repo.buscar('hinario x').every((r) => r.trecho == null), isTrue);
    expect(repo.buscar('hinario x').map((r) => r.hino.nome),
        ['Um', 'Três', 'Quatro', 'Cinco']);
  });

  test('buscar: ignora acentos (normalização pt-BR)', () async {
    final repo = HinosRepository(service: HinosServiceFake());
    await repo.carregar();
    // Caso real: 'chaveirao' precisa achar 'Chaveirão'.
    expect(repo.buscar('tres').map((r) => r.hino.nome), ['Três']);
    expect(repo.buscar('TRÊS').map((r) => r.hino.nome), ['Três']);
    // Nome casa: nada de trecho, com ou sem acento na consulta.
    expect(repo.buscar('tres').single.trecho, isNull);
    expect(repo.buscar('TRÊS').single.trecho, isNull);
    // 'hinario x' sem acento acha os hinos dos dois grupos de rótulo 'Hinário X'
    expect(repo.buscar('hinario x').map((r) => r.hino.nome), ['Um', 'Três', 'Quatro', 'Cinco']);
  });

  test('buscar: letra acentuada — trecho recortado com o termo original destacado', () async {
    final repo = HinosRepository(service: HinosServiceLetraFake());
    await repo.carregar();
    // 'coracao' (sem acento) casa a LETRA 'coração' (com acento).
    final r = repo.buscar('coracao').single;
    expect(r.hino.nome, 'Hino Bonito');
    final trecho = r.trecho!;
    expect(trecho, contains('coração'));
    expect(trecho, isNot(contains('\n'))); // quebras viram espaço
    expect(trecho, startsWith('…')); // cortado antes do termo
    expect(trecho, endsWith('…'));   // e depois dele
    // O índice achado no texto normalizado vale na letra ORIGINAL: o destaque
    // cobre a palavra acentuada, não um deslocamento.
    expect(trecho.substring(r.destaqueInicio!, r.destaqueFim!), 'coração');
  });

  test('buscar: casamento só pelo tom não gera trecho', () async {
    final repo = HinosRepository(service: HinosServiceLetraFake());
    await repo.carregar();
    // 'f' só existe no tom 'F#' da cifra — a letra não tem o termo.
    final resultado = repo.buscar('f');
    expect(resultado.map((r) => r.hino.nome), ['Toada']);
    expect(resultado.single.trecho, isNull);
  });

  test('buscar: ª e º também são normalizados', () async {
    final repo = HinosRepository(service: HinosServiceOrdinalFake());
    await repo.carregar();
    // '1ª VEZ' na letra casa com a consulta acentuada e com '1a vez'.
    expect(repo.buscar('1ª VEZ').map((r) => r.hino.nome), ['Ordinal']);
    expect(repo.buscar('1a vez').map((r) => r.hino.nome), ['Ordinal']);
    expect(repo.buscar('2o refrao').map((r) => r.hino.nome), ['Ordinal']); // º → o
    // Casou pela letra: o destaque cobre '1ª' na letra ORIGINAL — o token
    // normalizado '1a' tem o mesmo comprimento (ª → a é 1:1).
    final r = repo.buscar('1a vez').single;
    expect(r.trecho, isNotNull);
    expect(r.trecho!.substring(r.destaqueInicio!, r.destaqueFim!), '1ª');
  });

  test('buscarGrupos: casa rótulo e autor, na ordem dos grupos globais', () async {
    final repo = HinosRepository(service: HinosServiceFake());
    await repo.carregar();
    expect(repo.buscarGrupos(''), isEmpty); // query vazia → lista vazia
    expect(repo.buscarGrupos('zzz'), isEmpty);

    // sem acento e minúsculo: os 3 grupos globais do fixture têm 'Hinário'.
    final grupos = repo.buscarGrupos('hinario');
    expect(grupos.map((g) => '${g.autor}:${g.rotulo}'),
        ['Diversos:Hinário X', 'A:Hinário X (z)', 'A:Hinário Y']);
    expect(grupos.first, isA<GrupoHinario>());
    // Ordem por num; o grupo da url 'x' traz A e B juntos (coletivo completo).
    expect(grupos.first.hinos.map((h) => h.nome), ['Quatro', 'Três', 'Um']);
    expect(repo.buscarGrupos('HINÁRIO'), hasLength(3)); // caixa/acento não importam
  });

  test('buscarGrupos: autor também casa; token é substring', () async {
    final repo = HinosRepository(service: HinosServiceFake());
    await repo.carregar();
    expect(repo.buscarGrupos('y').map((g) => g.rotulo), ['Hinário Y']);
    // 'a' é substring de todos os alvos (rótulos 'Hinário'/'Diversos'/'A').
    expect(repo.buscarGrupos('a'), hasLength(3));
    // 'a x': casa 'Hinário X'/'Diversos' e 'Hinário X (z)'/'A', não 'Hinário Y'.
    expect(repo.buscarGrupos('a x').map((g) => '${g.autor}:${g.rotulo}'),
        ['Diversos:Hinário X', 'A:Hinário X (z)']);
  });

  test('gruposGlobais: lista achatada ordenada por rótulo normalizado', () async {
    final repo = HinosRepository(service: HinosServiceFake());
    await repo.carregar();
    final grupos = repo.gruposGlobais();
    expect(grupos, hasLength(3));
    // Rótulo normalizado asc ('hinario x' < 'hinario x (z)' < 'hinario y').
    expect(grupos.map((g) => '${g.autor}:${g.rotulo}'),
        ['Diversos:Hinário X', 'A:Hinário X (z)', 'A:Hinário Y']);
    // Os hinos de cada grupo vêm na ordem do agrupamento (por num).
    expect(grupos.first.hinos.map((h) => h.nome), ['Quatro', 'Três', 'Um']);
  });

  test('gruposGlobais: acento não muda o lugar (normaliza, não code point)', () async {
    final repo = HinosRepository(service: HinosServiceRotulosFake());
    await repo.carregar();
    // 'Í' (U+00CD) > 'J' (U+004A) no code point cru: sem normalizar, 'Jardim'
    // viria primeiro. Como o sort usa _normalizar, 'indio' < 'jardim'.
    expect(repo.gruposGlobais().map((g) => g.rotulo), ['Índio', 'Jardim']);
  });

  test('hinosDoHinario: filtra e ordena por num', () async {
    final repo = HinosRepository(service: HinosServiceFake());
    await repo.carregar();
    expect(repo.hinosDoHinario('x').map((x) => x.num), [1, 1, 2]);
  });

  test('hinosDoGrupo: o grupo GLOBAL do hino (por url, ou nome quando sem url)', () async {
    final repo = HinosRepository(service: HinosServiceFake());
    await repo.carregar();
    final um = (await repo.carregar()).firstWhere((h) => h.nome == 'Um');
    expect(repo.chaveDe(um), 'x');
    // chave 'x' inteira (sem filtro de autor): Três/Quatro(1), Um(2).
    expect(repo.hinosDoGrupo(um).map((h) => h.nome), ['Quatro', 'Três', 'Um']);
    expect(repo.hinosDoGrupo(um).map((h) => h.autor).toSet(), {'A', 'B'});
    // Mesma chave 'x' a partir do hino do outro autor: MESMO grupo global.
    final quatro = (await repo.carregar()).firstWhere((h) => h.nome == 'Quatro');
    expect(repo.hinosDoGrupo(quatro).map((h) => h.nome), ['Quatro', 'Três', 'Um']);

    // Sem url: a chave é o NOME do hinário — grupos distintos não se juntam.
    final semUrl = HinosRepository(service: HinosServiceSemUrlFake());
    await semUrl.carregar();
    final conc1 = (await semUrl.carregar()).firstWhere((h) => h.nome == 'Concentração 1');
    expect(semUrl.chaveDe(conc1), 'Concentração');
    expect(semUrl.hinosDoGrupo(conc1).map((h) => h.nome), ['Concentração 1', 'Concentração 2']);
    final talisma = (await semUrl.carregar()).firstWhere((h) => h.nome == 'O Talismã');
    expect(semUrl.hinosDoGrupo(talisma).map((h) => h.nome), ['O Talismã']);
  });
}
