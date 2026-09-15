// test/cifras_locais_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hinarios_app/data/services/cifras_locais_service.dart';
import 'package:hinarios_app/domain/models/cifra_local.dart';
import 'package:hinarios_app/ui/core/cifras_locais_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CifraLocal cifra(String tom, List<String> acordes) =>
      CifraLocal(tom: tom, acordesPorLinha: acordes);

  test('salvar persiste e restaurar lê de volta', () async {
    SharedPreferences.setMockInitialValues({});
    final service = CifrasLocaisService();
    final vm = CifrasLocaisViewModel(service: service);
    vm.salvar('a/1/um', cifra('D', ['D Bm', 'A']));
    await Future<void>.delayed(Duration.zero); // deixa o fire-and-forget gravar

    final vm2 = CifrasLocaisViewModel(service: service);
    await vm2.restaurar();
    expect(vm2.cifraDe('a/1/um')!.tom, 'D');
    expect(vm2.cifraDe('a/1/um')!.acordesPorLinha, ['D Bm', 'A']);
    expect(vm2.cifraDe('outro/slug'), isNull);
  });

  test('salvar notifica e a visão é imutável', () {
    SharedPreferences.setMockInitialValues({});
    final vm = CifrasLocaisViewModel(service: CifrasLocaisService());
    var notificado = 0;
    vm.addListener(() => notificado++);
    vm.salvar('a', cifra('C', ['C']));
    vm.salvar('b', cifra('G', ['G']));
    expect(notificado, 2);
    expect(vm.cifras.keys, containsAll(['a', 'b']));
    expect(() => vm.cifras['c'] = cifra('D', ['D']), throwsUnsupportedError);
  });

  test('remover apaga, notifica e persiste', () async {
    SharedPreferences.setMockInitialValues({});
    final service = CifrasLocaisService();
    final vm = CifrasLocaisViewModel(service: service);
    vm.salvar('a', cifra('C', ['C']));
    await Future<void>.delayed(Duration.zero);

    var notificado = 0;
    vm.addListener(() => notificado++);
    vm.remover('a');
    expect(vm.cifraDe('a'), isNull);
    expect(notificado, 1);
    await Future<void>.delayed(Duration.zero);

    final vm2 = CifrasLocaisViewModel(service: service);
    await vm2.restaurar();
    expect(vm2.cifras, isEmpty);
  });

  test('importar faz merge por slug: adiciona, sobrescreve e devolve a contagem', () {
    SharedPreferences.setMockInitialValues({});
    final vm = CifrasLocaisViewModel(service: CifrasLocaisService());
    vm.salvar('a', cifra('C', ['C']));
    final json = jsonEncode({
      'a': cifra('G', ['G D']).toJson(),
      'b': cifra('D', ['D']).toJson(),
    });
    expect(vm.importar(json), 2);
    expect(vm.cifraDe('a')!.tom, 'G'); // sobrescreveu
    expect(vm.cifraDe('a')!.acordesPorLinha, ['G D']);
    expect(vm.cifraDe('b')!.tom, 'D'); // entrou nova
  });

  test('exportarJson volta pelo importar (round-trip)', () {
    SharedPreferences.setMockInitialValues({});
    final origem = CifrasLocaisViewModel(service: CifrasLocaisService());
    origem.salvar('a', cifra('D', ['D Bm', '']));
    origem.salvar('b', cifra('Am', ['Am E7']));

    final destino = CifrasLocaisViewModel(service: CifrasLocaisService());
    expect(destino.importar(origem.exportarJson()), 2);
    expect(destino.cifraDe('a')!.tom, 'D');
    expect(destino.cifraDe('a')!.acordesPorLinha, ['D Bm', '']);
    expect(destino.cifraDe('b')!.acordesPorLinha, ['Am E7']);
  });

  test('importar json inválido não derruba (devolve 0)', () {
    SharedPreferences.setMockInitialValues({});
    final vm = CifrasLocaisViewModel(service: CifrasLocaisService());
    expect(vm.importar('não é json'), 0);
    expect(vm.importar('["lista"]'), 0);
    expect(vm.cifras, isEmpty);
  });

  // main() aguarda restaurar() antes do runApp: JSON corrompido no disco vira
  // mapa vazio em vez de exceção (mesmo tratamento de PreferenciasService).
  test('json corrompido no disco vira mapa vazio', () async {
    SharedPreferences.setMockInitialValues({'hinario.cifras_locais': '{quebrado'});
    expect(await CifrasLocaisService().restaurar(), isEmpty);
  });

  test('salvar é serializado: o último valor é o que fica no disco', () async {
    SharedPreferences.setMockInitialValues({});
    final service = CifrasLocaisService();
    final vm = CifrasLocaisViewModel(service: service);
    for (var i = 0; i < 5; i++) {
      vm.salvar('a', cifra('C', ['C$i']));
    }
    await Future<void>.delayed(Duration.zero);

    final vm2 = CifrasLocaisViewModel(service: service);
    await vm2.restaurar();
    expect(vm2.cifraDe('a')!.acordesPorLinha, ['C4']);
  });
}
