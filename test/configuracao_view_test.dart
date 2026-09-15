// test/configuracao_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hinarios_app/data/services/cifras_locais_service.dart';
import 'package:hinarios_app/data/services/preferencias_service.dart';
import 'package:hinarios_app/domain/models/cifra_local.dart';
import 'package:hinarios_app/ui/core/cifras_locais_view_model.dart';
import 'package:hinarios_app/ui/core/preferencias_view_model.dart';
import 'package:hinarios_app/ui/features/configuracao/configuracao_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<PreferenciasViewModel> preferenciasVm() async {
    final vm = PreferenciasViewModel(service: PreferenciasService());
    await vm.restaurar();
    return vm;
  }

  Future<CifrasLocaisViewModel> cifrasVm() async {
    final vm = CifrasLocaisViewModel(service: CifrasLocaisService());
    await vm.restaurar();
    return vm;
  }

  Widget montar(PreferenciasViewModel preferencias, CifrasLocaisViewModel cifras) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: preferencias),
        ChangeNotifierProvider.value(value: cifras),
      ],
      child: const MaterialApp(home: ConfiguracaoView()),
    );
  }

  // bySubtype: OutlinedButton.icon devolve _OutlinedButtonWithIcon (subclasse),
  // que find.byType (tipo exato) não encontra.
  OutlinedButton botao(WidgetTester tester, String rotulo) =>
      tester.widget<OutlinedButton>(find.ancestor(
        of: find.text(rotulo),
        matching: find.bySubtype<OutlinedButton>(),
      ));

  testWidgets('toggle de tema e slider de fonte funcionam', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final vm = await preferenciasVm();
    await tester.pumpWidget(montar(vm, await cifrasVm()));
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    expect(vm.temaEscuro, isTrue);

    await tester.drag(find.byType(Slider), const Offset(100, 0));
    await tester.pump();
    // Padrão agora é 20; arrastar para a direita precisa aumentar de fato.
    expect(vm.tamanhoFonte, greaterThan(20));
  });

  testWidgets('seção Minhas cifras: sem cifras o exportar fica desabilitado', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final cifras = await cifrasVm();
    await tester.pumpWidget(montar(await preferenciasVm(), cifras));

    expect(find.text('Minhas cifras'), findsOneWidget);
    expect(find.text('0 cifra(s) criada(s) neste aparelho'), findsOneWidget);
    expect(botao(tester, 'Exportar cifras').onPressed, isNull);
    // Importar continua disponível mesmo sem cifras locais.
    expect(botao(tester, 'Importar cifras').onPressed, isNotNull);
  });

  testWidgets('com 1 cifra o exportar habilita e mostra o SnackBar', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final cifras = await cifrasVm();
    cifras.salvar('a/1/um', const CifraLocal(tom: 'D', texto: '[D]Um'));
    await tester.pumpWidget(montar(await preferenciasVm(), cifras));

    expect(find.text('1 cifra(s) criada(s) neste aparelho'), findsOneWidget);
    expect(botao(tester, 'Exportar cifras').onPressed, isNotNull);

    // Na VM de teste baixarTexto é no-op; o SnackBar confirma a ação.
    await tester.tap(find.text('Exportar cifras'));
    await tester.pump();
    expect(find.text('Cifras exportadas'), findsOneWidget);
  });

  testWidgets('importar sem seletor de arquivo (fora da web) não faz nada', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final cifras = await cifrasVm();
    await tester.pumpWidget(montar(await preferenciasVm(), cifras));

    // escolherArquivoTexto devolve null fora da web: toque não pode lançar
    // nem mostrar SnackBar.
    await tester.tap(find.text('Importar cifras'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(SnackBar), findsNothing);
    expect(cifras.cifras, isEmpty);
  });
}
