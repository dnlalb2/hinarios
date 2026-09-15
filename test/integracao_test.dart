// test/integracao_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hinarios_app/main.dart';
import 'package:hinarios_app/data/repositories/hinos_repository.dart';
import 'package:hinarios_app/data/services/hinos_service.dart';
import 'package:hinarios_app/data/services/preferencias_service.dart';
import 'package:hinarios_app/ui/core/preferencias_view_model.dart';
import 'package:hinarios_app/ui/core/widgets/bloco_hino.dart';
import 'hinos_repository_test.dart' show HinosServiceFake;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpApp(WidgetTester tester, HinosService service) async {
    SharedPreferences.setMockInitialValues({});
    final pref = PreferenciasViewModel(service: PreferenciasService());
    await pref.restaurar();
    final repo = HinosRepository(service: service);
    await repo.carregar();
    await tester.pumpWidget(HinariosApp(preferencias: pref, hinosRepository: repo));
    await tester.pumpAndSettle();
  }

  testWidgets('busca → hino → ver no hinário', (tester) async {
    await pumpApp(tester, HinosServiceFake());
    await tester.enterText(find.byType(TextField), 'terra');
    await tester.pumpAndSettle();
    // O resultado é compacto: nenhuma letra inteira na tela de busca.
    expect(find.byType(BlocoHino), findsNothing);
    await tester.tap(find.text('1. Três'));
    await tester.pumpAndSettle();
    expect(find.byType(BlocoHino), findsOneWidget); // a página do hino
    expect(find.text('ver no hinário'), findsOneWidget);
    await tester.tap(find.text('ver no hinário'));
    await tester.pumpAndSettle();
    expect(find.text('2. Um'), findsOneWidget);
  });
}
