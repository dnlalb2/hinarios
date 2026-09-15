// test/pinca_fonte_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hinarios_app/data/services/preferencias_service.dart';
import 'package:hinarios_app/ui/core/preferencias_view_model.dart';
import 'package:hinarios_app/ui/core/widgets/pinca_fonte.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<PreferenciasViewModel> montar(WidgetTester tester, Widget filho) async {
    SharedPreferences.setMockInitialValues({});
    final vm = PreferenciasViewModel(service: PreferenciasService());
    await vm.restaurar();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: vm,
        child: MaterialApp(home: Scaffold(body: PincaFonte(child: filho))),
      ),
    );
    return vm;
  }

  testWidgets('pinça para fora aumenta o tamanho real da fonte', (tester) async {
    final vm = await montar(
      tester,
      const SingleChildScrollView(child: SizedBox(height: 2000)),
    );
    expect(vm.tamanhoFonte, 20);

    final g1 = await tester.startGesture(const Offset(200, 300));
    final g2 = await tester.startGesture(const Offset(300, 300));
    await g1.moveTo(const Offset(100, 300));
    await g2.moveTo(const Offset(400, 300));
    await tester.pump();
    expect(vm.tamanhoFonte, greaterThan(20));

    await g1.up();
    await g2.up();
    await tester.pumpAndSettle();
  });

  testWidgets('pinça é persistida na preferência de fonte', (tester) async {
    final vm = await montar(
      tester,
      const SingleChildScrollView(child: SizedBox(height: 2000)),
    );

    final g1 = await tester.startGesture(const Offset(200, 300));
    final g2 = await tester.startGesture(const Offset(300, 300));
    await g1.moveTo(const Offset(100, 300));
    await g2.moveTo(const Offset(400, 300));
    await tester.pump();
    final aposPinca = vm.tamanhoFonte;
    expect(aposPinca, greaterThan(20));
    expect(aposPinca, lessThanOrEqualTo(28));
    await g1.up();
    await g2.up();
    await tester.pumpAndSettle();

    // O valor sobrevive a um novo restaurar() (foi gravado no SharedPreferences).
    final outra = PreferenciasViewModel(service: PreferenciasService());
    await outra.restaurar();
    expect(outra.tamanhoFonte, aposPinca);
  });

  testWidgets('pinça para dentro diminui o tamanho real da fonte',
      (tester) async {
    final vm = await montar(
      tester,
      const SingleChildScrollView(child: SizedBox(height: 2000)),
    );
    vm.setTamanhoFonte(28);
    await tester.pump();

    final g1 = await tester.startGesture(const Offset(200, 300));
    final g2 = await tester.startGesture(const Offset(300, 300));
    await g1.moveTo(const Offset(240, 300));
    await g2.moveTo(const Offset(260, 300));
    await tester.pump();
    expect(vm.tamanhoFonte, lessThan(28));
    expect(vm.tamanhoFonte, greaterThanOrEqualTo(12));

    await g1.up();
    await g2.up();
    await tester.pumpAndSettle();
  });

  testWidgets('rolagem de 1 dedo continua funcionando dentro da PincaFonte',
      (tester) async {
    await montar(
      tester,
      ListView(
        children: [
          for (var i = 0; i < 30; i++)
            SizedBox(height: 60, child: Text('item $i')),
        ],
      ),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    final posicao =
        tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels;
    expect(posicao, greaterThan(0));
  });

  testWidgets('indicador com a fonte aparece durante a pinça e some no fim',
      (tester) async {
    final vm = await montar(
      tester,
      const SingleChildScrollView(child: SizedBox(height: 2000)),
    );
    expect(find.textContaining('Fonte:'), findsNothing);

    final g1 = await tester.startGesture(const Offset(200, 300));
    final g2 = await tester.startGesture(const Offset(300, 300));
    await g1.moveTo(const Offset(100, 300));
    await g2.moveTo(const Offset(400, 300));
    await tester.pump();
    expect(find.textContaining('Fonte:'), findsOneWidget);
    expect(find.text('Fonte: ${vm.tamanhoFonte.round()}'), findsOneWidget);

    await g1.up();
    await g2.up();
    await tester.pump();
    expect(find.textContaining('Fonte:'), findsNothing);
  });
}
