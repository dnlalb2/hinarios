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
/// primeiro — é isso que prova que o [gruposPorNome] normaliza de verdade.
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

  test('agrupar: autor → hinário → ordem por num', () async {
    final repo = HinosRepository(service: HinosServiceFake());
    await repo.carregar();
    final g = repo.agrupar();
    expect(g.keys, ['A', 'B']);
    // grupo por url: 'Hinário X' é a url 'x' (Três, Um); a url 'z' (Cinco,
    // mesmo nome) colide e fica como 'Hinário X (z)'.
    expect(g['A']!.keys, ['Hinário X', 'Hinário X (z)', 'Hinário Y']);
    expect(g['A']!['Hinário X']!.map((x) => x.num), [1, 2]);
    expect(g['A']!['Hinário X (z)']!.map((x) => x.num), [5]);
    expect(g['A']!['Hinário Y']!.map((x) => x.num), [1]);
    expect(g['B']!['Hinário X']!.map((x) => x.num), [1]);
  });

  test('agrupar: colisão de rótulo desambiguada', () async {
    final repo = HinosRepository(service: HinosServiceFake());
    await repo.carregar();
    final g = repo.agrupar();
    // Duas urls no autor A têm o mesmo nome mais comum ('Hinário X'):
    // url 'x' (2 hinos) mantém o rótulo puro; url 'z' (1 hino, menor) ganha sufixo.
    expect(g['A']!.keys, contains('Hinário X'));
    expect(g['A']!.keys, contains('Hinário X (z)'));
    expect(g['A']!['Hinário X (z)']!.map((x) => x.num), [5]);
    expect(g['A']!['Hinário X']!.map((x) => x.num), [1, 2]);
    expect(g['A']!['Hinário X']!.length, greaterThan(g['A']!['Hinário X (z)']!.length));
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
  });

  test('buscar: ignora acentos (normalização pt-BR)', () async {
    final repo = HinosRepository(service: HinosServiceFake());
    await repo.carregar();
    // Caso real: 'chaveirao' precisa achar 'Chaveirão'.
    expect(repo.buscar('tres').map((h) => h.nome), ['Três']);
    expect(repo.buscar('TRÊS').map((h) => h.nome), ['Três']);
    // 'hinario x' sem acento acha os hinos dos dois grupos de rótulo 'Hinário X'
    expect(repo.buscar('hinario x').map((h) => h.nome), ['Um', 'Três', 'Quatro', 'Cinco']);
  });

  test('buscar: ª e º também são normalizados', () async {
    final repo = HinosRepository(service: HinosServiceOrdinalFake());
    await repo.carregar();
    // '1ª VEZ' na letra casa com a consulta acentuada e com '1a vez'.
    expect(repo.buscar('1ª VEZ').map((h) => h.nome), ['Ordinal']);
    expect(repo.buscar('1a vez').map((h) => h.nome), ['Ordinal']);
    expect(repo.buscar('2o refrao').map((h) => h.nome), ['Ordinal']); // º → o
  });

  test('buscarGrupos: casa rótulo e autor, na ordem do agrupamento', () async {
    final repo = HinosRepository(service: HinosServiceFake());
    await repo.carregar();
    expect(repo.buscarGrupos(''), isEmpty); // query vazia → lista vazia
    expect(repo.buscarGrupos('zzz'), isEmpty);

    // sem acento e minúsculo: os 4 grupos do fixture têm 'Hinário' no rótulo.
    final grupos = repo.buscarGrupos('hinario');
    expect(grupos.map((g) => '${g.autor}:${g.rotulo}'),
        ['A:Hinário X', 'A:Hinário X (z)', 'A:Hinário Y', 'B:Hinário X']);
    expect(grupos.first, isA<GrupoHinario>());
    expect(grupos.first.hinos.map((h) => h.nome), ['Três', 'Um']); // ordem por num
    expect(repo.buscarGrupos('HINÁRIO'), hasLength(4)); // caixa/acento não importam
  });

  test('buscarGrupos: autor também casa; token é substring', () async {
    final repo = HinosRepository(service: HinosServiceFake());
    await repo.carregar();
    expect(repo.buscarGrupos('y').map((g) => g.rotulo), ['Hinário Y']);
    // 'a' é substring de todos os alvos (autor 'A') → casa todos os grupos.
    expect(repo.buscarGrupos('a'), hasLength(4));
    expect(repo.buscarGrupos('a x').map((g) => '${g.autor}:${g.rotulo}'),
        ['A:Hinário X', 'A:Hinário X (z)', 'B:Hinário X']);
  });

  test('gruposPorNome: achata o agrupamento e ordena por rótulo normalizado', () async {
    final repo = HinosRepository(service: HinosServiceFake());
    await repo.carregar();
    final grupos = repo.gruposPorNome();
    expect(grupos, hasLength(4));
    // Rótulo normalizado asc; empate ('Hinário X') → autor normalizado (A < B).
    expect(grupos.map((g) => '${g.autor}:${g.rotulo}'),
        ['A:Hinário X', 'B:Hinário X', 'A:Hinário X (z)', 'A:Hinário Y']);
    // Os hinos de cada grupo vêm na ordem do agrupamento (por num).
    expect(grupos.first.hinos.map((h) => h.nome), ['Três', 'Um']);
  });

  test('gruposPorNome: acento não muda o lugar (normaliza, não code point)', () async {
    final repo = HinosRepository(service: HinosServiceRotulosFake());
    await repo.carregar();
    // 'Í' (U+00CD) > 'J' (U+004A) no code point cru: sem normalizar, 'Jardim'
    // viria primeiro. Como o sort usa _normalizar, 'indio' < 'jardim'.
    expect(repo.gruposPorNome().map((g) => g.rotulo), ['Índio', 'Jardim']);
  });

  test('hinosDoHinario: filtra e ordena por num', () async {
    final repo = HinosRepository(service: HinosServiceFake());
    await repo.carregar();
    expect(repo.hinosDoHinario('x').map((x) => x.num), [1, 1, 2]);
  });

  test('hinosDoGrupo: por url, e por nome quando sem url', () async {
    final repo = HinosRepository(service: HinosServiceFake());
    await repo.carregar();
    final um = (await repo.carregar()).firstWhere((h) => h.nome == 'Um');
    expect(repo.chaveDe(um), 'x');
    // chave 'x' E autor A: Três(1), Um(2) — ordenados por num.
    expect(repo.hinosDoGrupo(um).map((h) => h.nome), ['Três', 'Um']);
    // Mesma chave 'x', autor B: o grupo do hino é só o dele (não cruza autores).
    final quatro = (await repo.carregar()).firstWhere((h) => h.nome == 'Quatro');
    expect(repo.hinosDoGrupo(quatro).map((h) => h.nome), ['Quatro']);

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
