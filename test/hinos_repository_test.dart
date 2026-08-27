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
      ]);
}

void main() {
  test('carregar parseia e cacheia (service chamado uma vez)', () async {
    final service = HinosServiceFake();
    final repo = HinosRepository(service: service);
    final hinos = await repo.carregar();
    expect(hinos, hasLength(4));
    expect(hinos.first, isA<Hino>());
    final deNovo = await repo.carregar();
    expect(identical(hinos, deNovo), isTrue); // cache
  });

  test('agrupar: autor → hinário → ordem por num', () async {
    final repo = HinosRepository(service: HinosServiceFake());
    await repo.carregar();
    final g = repo.agrupar();
    expect(g.keys, ['A', 'B']);
    expect(g['A']!.keys, ['Hinário X', 'Hinário Y']);
    expect(g['A']!['Hinário X']!.map((x) => x.num), [1, 2]);
  });

  test('buscar: tokens todos presentes; ignora maiúsculas; tom conta', () async {
    final repo = HinosRepository(service: HinosServiceFake());
    await repo.carregar();
    expect(repo.buscar('um'), hasLength(1));          // nome 'Um'
    expect(repo.buscar('UM'), hasLength(1));
    expect(repo.buscar('terra mar'), hasLength(1));   // letra
    expect(repo.buscar('D'), hasLength(2));           // tom da cifra e nome 'Dois'
    expect(repo.buscar(''), hasLength(4));
    expect(repo.buscar('nada que exista'), isEmpty);
  });

  test('hinosDoHinario: filtra e ordena por num', () async {
    final repo = HinosRepository(service: HinosServiceFake());
    await repo.carregar();
    expect(repo.hinosDoHinario('x').map((x) => x.num), [1, 1, 2]);
  });
}
