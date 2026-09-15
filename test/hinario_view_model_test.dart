// test/hinario_view_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hinarios_app/data/repositories/hinos_repository.dart';
import 'package:hinarios_app/ui/features/hinario/hinario_view_model.dart';
import 'hinos_repository_test.dart' show HinosServiceFake;

void main() {
  /// ViewModel do hinário 'x' do fake: Três (letra 'Terra e mar'), Quatro
  /// (letra 'Outra coisa') e Um (num 2) — ordenados por num.
  Future<HinarioViewModel> montar() async {
    final repo = HinosRepository(service: HinosServiceFake());
    await repo.carregar();
    return HinarioViewModel(
        hinos: repo.hinosDoHinario('x'), autor: 'A', hinario: 'Hinário X', chave: 'x');
  }

  test('hinos do hinário vêm da lista recebida (sem re-buscar)', () async {
    final repo = HinosRepository(service: HinosServiceFake());
    await repo.carregar();
    final lista = repo.hinosDoHinario('x'); // Três, Quatro, Um
    final vm = HinarioViewModel(hinos: lista, autor: 'A', hinario: 'Hinário X', chave: 'x');
    expect(vm.autor, 'A');
    expect(vm.hinario, 'Hinário X');
    expect(vm.chave, 'x'); // chave do grupo global — a estrela usa esta chave
    expect(vm.hinos.map((h) => h.num), [1, 1, 2]); // ordenado por num
    expect(identical(vm.hinos, lista), isTrue); // devolve a MESMA lista recebida
  });

  test('busca interna: letra, nome sem acento e número', () async {
    final vm = await montar();
    // Sem busca, todos os hinos do hinário (e a mesma lista recebida).
    expect(vm.query, '');
    expect(identical(vm.hinosFiltrados, vm.hinos), isTrue);
    expect(vm.hinosFiltrados.map((h) => h.nome), ['Três', 'Quatro', 'Um']);

    // Trecho da letra ('Terra e mar'): só o Três.
    vm.setQuery('terra');
    expect(vm.hinosFiltrados.map((h) => h.nome), ['Três']);

    // Nome acentuado com consulta sem acento (mesma semântica da busca geral).
    vm.setQuery('tres');
    expect(vm.hinosFiltrados.map((h) => h.nome), ['Três']);

    // Número do hino: o 'Um' é o num 2 do hinário.
    vm.setQuery('2');
    expect(vm.hinosFiltrados.map((h) => h.nome), ['Um']);

    // Sem casamento nenhum: lista vazia (a view mostra 'Nenhum hino encontrado').
    vm.setQuery('zzz');
    expect(vm.hinosFiltrados, isEmpty);

    // Limpar restaura a lista inteira.
    vm.setQuery('');
    expect(vm.query, '');
    expect(vm.hinosFiltrados.map((h) => h.nome), ['Três', 'Quatro', 'Um']);
  });

  test('setQuery notifica (o X e o cabeçalho dependem disso)', () async {
    final vm = await montar();
    var notificacoes = 0;
    vm.addListener(() => notificacoes++);
    vm.setQuery('terra');
    vm.setQuery('');
    expect(notificacoes, 2);
    // A API antiga do hinário segue intacta.
    expect(vm.autor, 'A');
    expect(vm.hinario, 'Hinário X');
    expect(vm.chave, 'x');
  });
}
