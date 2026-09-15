// test/biblioteca_view_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hinarios_app/data/repositories/hinos_repository.dart';
import 'package:hinarios_app/data/services/preferencias_service.dart';
import 'package:hinarios_app/ui/core/preferencias_view_model.dart';
import 'package:hinarios_app/ui/features/biblioteca/biblioteca_view_model.dart';
import 'hinos_repository_test.dart' show HinosServiceFake;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('busca e favoritos controlam resultados', () async {
    final repo = HinosRepository(service: HinosServiceFake());
    await repo.carregar();
    final pref = PreferenciasViewModel(service: PreferenciasService());
    final vm = BibliotecaViewModel(hinos: repo, preferencias: pref);

    expect(vm.emBusca, isFalse);
    expect(vm.grupos.keys, contains('A'));
    // Visão plana: grupos GLOBAIS (o da url 'x' junta os autores A e B).
    expect(vm.gruposHinarios.map((g) => '${g.autor}:${g.rotulo}'),
        ['Diversos:Hinário X', 'A:Hinário X (z)', 'A:Hinário Y']);

    vm.setQuery('terra');
    expect(vm.emBusca, isTrue);
    expect(vm.resultados.map((r) => r.hino.nome), ['Três']);
    // 'terra' só existe na letra: o VM expõe o trecho para a lista compacta.
    expect(vm.resultados.single.trecho, isNotNull);

    pref.toggleFavorito('a/3/tres');
    vm.toggleSoFavoritos();
    vm.setQuery('');
    expect(vm.resultados.map((r) => r.hino.nome), ['Três']); // só favorito

    vm.toggleSoFavoritos();
    expect(vm.resultados, hasLength(5)); // fixture do repo tem 5 hinos
  });
}
