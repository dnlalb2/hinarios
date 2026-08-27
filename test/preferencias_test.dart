import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hinarios_app/data/services/preferencias_service.dart';
import 'package:hinarios_app/ui/core/preferencias_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('tema, fonte e favoritos notificam e alternam', () {
    final vm = PreferenciasViewModel(service: PreferenciasService());
    var notificado = 0;
    vm.addListener(() => notificado++);
    vm.toggleTema();
    vm.setTamanhoFonte(20);
    vm.toggleFavorito('a');
    vm.toggleFavorito('a');
    expect(vm.temaEscuro, isTrue);
    expect(vm.tamanhoFonte, 20);
    expect(vm.favoritos, isEmpty);
    expect(notificado, greaterThanOrEqualTo(4));
  });

  test('transposição acumula módulo 12 por slug', () {
    final vm = PreferenciasViewModel(service: PreferenciasService());
    expect(vm.deslocamentoDe('x'), 0);
    vm.transpor('x', 1);
    vm.transpor('x', 1);
    expect(vm.deslocamentoDe('x'), 2);
    vm.transpor('y', -1);
    expect(vm.deslocamentoDe('y'), 11);
    vm.transpor('x', 11);
    expect(vm.deslocamentoDe('x'), 1);
  });

  test('restaurar carrega o que foi salvo', () async {
    SharedPreferences.setMockInitialValues({});
    final service = PreferenciasService();
    final vm = PreferenciasViewModel(service: service);
    vm.toggleTema();
    vm.setTamanhoFonte(22);
    vm.toggleFavorito('z');
    vm.transpor('z', 3);
    await Future<void>.delayed(Duration.zero); // deixa o fire-and-forget gravar

    final vm2 = PreferenciasViewModel(service: service);
    await vm2.restaurar();
    expect(vm2.temaEscuro, isTrue);
    expect(vm2.tamanhoFonte, 22);
    expect(vm2.favoritos, contains('z'));
    expect(vm2.deslocamentoDe('z'), 3);
  });
}
