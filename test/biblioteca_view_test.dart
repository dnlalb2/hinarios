// test/biblioteca_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hinarios_app/data/repositories/hinos_repository.dart';
import 'package:hinarios_app/data/services/preferencias_service.dart';
import 'package:hinarios_app/ui/core/preferencias_view_model.dart';
import 'package:hinarios_app/ui/core/widgets/bloco_hino.dart';
import 'package:hinarios_app/ui/features/biblioteca/biblioteca_view.dart';
import 'package:hinarios_app/ui/features/biblioteca/biblioteca_view_model.dart';
import 'hinos_repository_test.dart' show HinosServiceFake;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Widget> montar() async {
    SharedPreferences.setMockInitialValues({});
    final repo = HinosRepository(service: HinosServiceFake());
    await repo.carregar();
    final pref = PreferenciasViewModel(service: PreferenciasService());
    await pref.restaurar();
    final vm = BibliotecaViewModel(hinos: repo, preferencias: pref);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: pref),
        ChangeNotifierProvider.value(value: vm),
        Provider<HinosRepository>.value(value: repo), // navegação para o HinarioView
      ],
      child: const MaterialApp(home: BibliotecaView()),
    );
  }

  testWidgets('mostra autores; expandir revela hinários', (tester) async {
    await tester.pumpWidget(await montar());
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('Hinário X'), findsNothing); // colapsado
    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();
    expect(find.text('Hinário X'), findsOneWidget);
  });

  testWidgets('busca troca a lista por resultados', (tester) async {
    await tester.pumpWidget(await montar());
    await tester.enterText(find.byType(TextField), 'terra');
    await tester.pumpAndSettle();
    expect(find.text('1. Três'), findsOneWidget);
    expect(find.byType(ExpansionTile), findsNothing);
  });

  testWidgets('busca sem acento mostra a seção Hinários e navega para o grupo', (tester) async {
    await tester.pumpWidget(await montar());
    await tester.enterText(find.byType(TextField), 'hinario'); // 'Hinário' sem acento
    await tester.pumpAndSettle();
    // AppBar + cabeçalho da seção de grupos.
    expect(find.text('Hinários'), findsNWidgets(2));
    // Tiles dos grupos (A: X, X (z), Y; B: X) — só ListTile, não os chips do BlocoHino.
    expect(find.widgetWithText(ListTile, 'Hinário X'), findsNWidgets(2));
    expect(find.text('A · 2 hinos'), findsOneWidget); // subtítulo do 1º grupo
    // Os hinos que casam continuam logo abaixo da seção de grupos.
    expect(find.text('2. Um'), findsOneWidget);
    expect(tester.getTopLeft(find.byType(BlocoHino).first).dy,
        greaterThan(tester.getTopLeft(find.byType(Divider)).dy));
    await tester.tap(find.widgetWithText(ListTile, 'Hinário X').first);
    await tester.pumpAndSettle();
    expect(find.text('1. Três'), findsOneWidget); // hinos do grupo escolhido
    expect(find.text('2. Um'), findsOneWidget);
  });

  testWidgets('só favoritos não mostra a seção de hinários', (tester) async {
    await tester.pumpWidget(await montar());
    await tester.enterText(find.byType(TextField), 'hinario');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Hinário X'), findsNWidgets(2));
    await tester.tap(find.byTooltip('Favoritos'));
    await tester.pumpAndSettle();
    expect(find.text('Hinários'), findsOneWidget); // só o AppBar
    expect(find.widgetWithText(ListTile, 'Hinário X'), findsNothing);
  });

  testWidgets('tocar no hinário abre a página do hinário', (tester) async {
    await tester.pumpWidget(await montar());
    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hinário X'));
    await tester.pumpAndSettle();
    expect(find.text('1. Três'), findsOneWidget); // hinos em sequência
    expect(find.text('2. Um'), findsOneWidget);
  });
}
