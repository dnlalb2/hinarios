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
