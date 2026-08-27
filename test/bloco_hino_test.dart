import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hinarios_app/data/services/preferencias_service.dart';
import 'package:hinarios_app/domain/models/hino.dart';
import 'package:hinarios_app/ui/core/preferencias_view_model.dart';
import 'package:hinarios_app/ui/core/widgets/bloco_hino.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<PreferenciasViewModel> vmNovo() async {
    SharedPreferences.setMockInitialValues({});
    final vm = PreferenciasViewModel(service: PreferenciasService());
    await vm.restaurar();
    return vm;
  }

  Widget montar(PreferenciasViewModel vm, Hino h) => ChangeNotifierProvider.value(
        value: vm,
        child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: BlocoHino(hino: h)))),
      );

  final hino = Hino(
    slug: 'mestre-irineu/1/sol-lua-estrela',
    num: 1,
    nome: 'Sol, Lua, Estrela',
    autor: 'Mestre Irineu',
    autorFull: 'Raimundo Irineu Serra',
    hinario: 'O Cruzeiro Universal',
    urlhinario: 'o-cruzeiro',
    ritmo: 'marcha',
    letra: 'Sol, Lua, Estrela\nA Terra, o Vento e o Mar',
    cifra: Cifra(tom: 'D', texto: 'D Bm; A D'),
  );

  testWidgets('mostra título, letra e acordes acima', (tester) async {
    await tester.pumpWidget(montar(await vmNovo(), hino));
    expect(find.textContaining('Sol, Lua, Estrela'), findsWidgets);
    expect(find.text('A Terra, o Vento e o Mar'), findsOneWidget);
    expect(find.text('D Bm'), findsOneWidget);
    expect(find.text('A D'), findsOneWidget);
  });

  testWidgets('botão + transposta acordes e tom exibido', (tester) async {
    final vm = await vmNovo();
    await tester.pumpWidget(montar(vm, hino));
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pump();
    expect(find.text('D#'), findsWidgets); // tom e acordes
    expect(vm.deslocamentoDe(hino.slug), 1);
  });

  testWidgets('estrela alterna favorito', (tester) async {
    final vm = await vmNovo();
    await tester.pumpWidget(montar(vm, hino));
    await tester.tap(find.byIcon(Icons.star_border));
    await tester.pump();
    expect(vm.favoritos, contains(hino.slug));
    expect(find.byIcon(Icons.star), findsOneWidget);
  });
}
