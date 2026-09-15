// test/hinario_view_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hinarios_app/data/repositories/hinos_repository.dart';
import 'package:hinarios_app/ui/features/hinario/hinario_view_model.dart';
import 'hinos_repository_test.dart' show HinosServiceFake;

void main() {
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
}
