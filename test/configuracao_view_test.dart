// test/configuracao_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hinarios_app/data/services/preferencias_service.dart';
import 'package:hinarios_app/ui/core/preferencias_view_model.dart';
import 'package:hinarios_app/ui/features/configuracao/configuracao_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('toggle de tema e slider de fonte funcionam', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final vm = PreferenciasViewModel(service: PreferenciasService());
    await vm.restaurar();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: vm,
        child: const MaterialApp(home: ConfiguracaoView()),
      ),
    );
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    expect(vm.temaEscuro, isTrue);

    await tester.drag(find.byType(Slider), const Offset(100, 0));
    await tester.pump();
    expect(vm.tamanhoFonte, greaterThan(16));
  });
}
