// test/hinario_view_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hinarios_app/data/repositories/hinos_repository.dart';
import 'package:hinarios_app/ui/features/hinario/hinario_view_model.dart';
import 'hinos_repository_test.dart' show HinosServiceFake;

void main() {
  test('hinos do hinário em ordem', () async {
    final repo = HinosRepository(service: HinosServiceFake());
    await repo.carregar();
    final vm = HinarioViewModel(
      hinos: repo, urlhinario: 'x', autor: 'A', hinario: 'Hinário X');
    expect(vm.autor, 'A');
    expect(vm.hinos.map((h) => h.num), [1, 1, 2]); // ordenado por num
  });
}
