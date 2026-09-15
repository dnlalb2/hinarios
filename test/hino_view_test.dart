// test/hino_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hinarios_app/data/repositories/hinos_repository.dart';
import 'package:hinarios_app/data/services/preferencias_service.dart';
import 'package:hinarios_app/ui/core/preferencias_view_model.dart';
import 'package:hinarios_app/ui/features/hino/hino_view.dart';
import 'package:hinarios_app/ui/features/hino/hino_view_model.dart';
import 'hinos_repository_test.dart' show HinosServiceFake;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mostra o hino e navega para o hinário', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = HinosRepository(service: HinosServiceFake());
    await repo.carregar();
    final pref = PreferenciasViewModel(service: PreferenciasService());
    await pref.restaurar();
    final hino = repo.hinosDoHinario('x').first; // '1. Três'
    final vm = HinoViewModel(hinos: repo, hino: hino);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: pref),
          ChangeNotifierProvider.value(value: vm),
          Provider<HinosRepository>.value(value: repo),
        ],
        child: const MaterialApp(home: HinoView()),
      ),
    );
    expect(find.text('1. Três'), findsOneWidget);
    expect(find.text('ver no hinário'), findsOneWidget);
    await tester.tap(find.text('ver no hinário'));
    await tester.pumpAndSettle();
    expect(find.text('2. Um'), findsOneWidget); // página do hinário
    // Grupo GLOBAL por url: '1. Quatro' (autor B, mesma url 'x') também entra —
    // o hinário abre completo, não o recorte do autor do hino.
    expect(find.text('1. Quatro'), findsOneWidget);
    expect(find.text('1. Três'), findsOneWidget);
  });

  testWidgets('atalho de Configurações abre a tela de configurações',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = HinosRepository(service: HinosServiceFake());
    await repo.carregar();
    final pref = PreferenciasViewModel(service: PreferenciasService());
    await pref.restaurar();
    final hino = repo.hinosDoHinario('x').first; // '1. Três'
    final vm = HinoViewModel(hinos: repo, hino: hino);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: pref),
          ChangeNotifierProvider.value(value: vm),
          Provider<HinosRepository>.value(value: repo),
        ],
        child: const MaterialApp(home: HinoView()),
      ),
    );
    expect(find.byTooltip('Configurações'), findsOneWidget);
    await tester.tap(find.byTooltip('Configurações'));
    await tester.pumpAndSettle();
    expect(find.text('Configurações'), findsOneWidget);
    expect(find.text('Tema escuro'), findsOneWidget);
  });
}
