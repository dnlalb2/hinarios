// test/hinario_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hinarios_app/data/repositories/hinos_repository.dart';
import 'package:hinarios_app/data/services/preferencias_service.dart';
import 'package:hinarios_app/ui/core/preferencias_view_model.dart';
import 'package:hinarios_app/ui/core/widgets/bloco_hino.dart';
import 'package:hinarios_app/ui/core/widgets/pinca_fonte.dart';
import 'package:hinarios_app/ui/features/hinario/hinario_view.dart';
import 'package:hinarios_app/ui/features/hinario/hinario_view_model.dart';
import 'hinos_repository_test.dart' show HinosServiceFake;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Página do hinário 'x' do fake (Três, Quatro e Um, nesta ordem).
  Future<void> montar(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = HinosRepository(service: HinosServiceFake());
    await repo.carregar();
    final pref = PreferenciasViewModel(service: PreferenciasService());
    await pref.restaurar();
    final vm = HinarioViewModel(
        hinos: repo.hinosDoHinario('x'), autor: 'A', hinario: 'Hinário X', chave: 'x');
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: pref),
          ChangeNotifierProvider.value(value: vm),
        ],
        child: const MaterialApp(home: HinarioView(autor: 'A', hinario: 'Hinário X')),
      ),
    );
  }

  testWidgets('todos os hinos do hinário em sequência', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = HinosRepository(service: HinosServiceFake());
    await repo.carregar();
    final pref = PreferenciasViewModel(service: PreferenciasService());
    await pref.restaurar();
    final vm = HinarioViewModel(
      hinos: repo.hinosDoHinario('x'), autor: 'A', hinario: 'Hinário X', chave: 'x');
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: pref),
          ChangeNotifierProvider.value(value: vm),
        ],
        child: const MaterialApp(home: HinarioView(autor: 'A', hinario: 'Hinário X')),
      ),
    );
    // AppBar com o nome do hinário (o nome também aparece como chip nos BlocoHino)
    expect(find.descendant(of: find.byType(AppBar), matching: find.text('Hinário X')),
        findsOneWidget);
    expect(find.text('A · 3 hinos'), findsOneWidget);
    // A pinça de fonte envolve a lista do hinário.
    expect(find.byType(PincaFonte), findsOneWidget);
    expect(find.text('1. Três'), findsOneWidget);
    expect(find.text('1. Quatro'), findsOneWidget);
    expect(find.text('2. Um'), findsOneWidget);
    expect(find.text('Terra e mar'), findsOneWidget);
  });

  testWidgets('atalho de Configurações abre a tela de configurações',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = HinosRepository(service: HinosServiceFake());
    await repo.carregar();
    final pref = PreferenciasViewModel(service: PreferenciasService());
    await pref.restaurar();
    final vm = HinarioViewModel(
        hinos: repo.hinosDoHinario('x'), autor: 'A', hinario: 'Hinário X', chave: 'x');
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: pref),
          ChangeNotifierProvider.value(value: vm),
        ],
        child:
            const MaterialApp(home: HinarioView(autor: 'A', hinario: 'Hinário X')),
      ),
    );
    expect(find.byTooltip('Configurações'), findsOneWidget);
    await tester.tap(find.byTooltip('Configurações'));
    await tester.pumpAndSettle();
    expect(find.text('Configurações'), findsOneWidget);
    expect(find.text('Tema escuro'), findsOneWidget);
  });

  testWidgets('estrela na AppBar favorita o hinário inteiro', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = HinosRepository(service: HinosServiceFake());
    await repo.carregar();
    final pref = PreferenciasViewModel(service: PreferenciasService());
    await pref.restaurar();
    final vm = HinarioViewModel(
        hinos: repo.hinosDoHinario('x'), autor: 'A', hinario: 'Hinário X', chave: 'x');
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: pref),
          ChangeNotifierProvider.value(value: vm),
        ],
        child:
            const MaterialApp(home: HinarioView(autor: 'A', hinario: 'Hinário X')),
      ),
    );
    // A estrela fica na AppBar, antes da engrenagem — e é do HINÁRIO, não do
    // hino (os BlocoHino da lista têm a sua própria, com tooltip 'Favorito').
    Finder estrela(IconData icone) => find.descendant(
        of: find.byType(AppBar), matching: find.byIcon(icone));
    expect(find.byTooltip('Favoritar hinário'), findsOneWidget);
    expect(estrela(Icons.star_border), findsOneWidget);

    await tester.tap(find.byTooltip('Favoritar hinário'));
    await tester.pumpAndSettle();
    expect(pref.hinariosFavoritos, contains('x'));
    expect(estrela(Icons.star), findsOneWidget);

    await tester.tap(find.byTooltip('Favoritar hinário'));
    await tester.pumpAndSettle();
    expect(pref.hinariosFavoritos, isEmpty);
    expect(estrela(Icons.star_border), findsOneWidget);
    expect(find.byTooltip('Configurações'), findsOneWidget); // engrenagem intacta
  });

  testWidgets('busca interna filtra os hinos do hinário e o X restaura',
      (tester) async {
    await montar(tester);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Buscar neste hinário…'), findsOneWidget);
    expect(find.text('A · 3 hinos'), findsOneWidget);
    expect(find.byTooltip('Limpar busca'), findsNothing); // sem busca, sem X

    // 'terra' só existe na letra do Três: os outros dois somem da lista.
    await tester.enterText(find.byType(TextField), 'terra');
    await tester.pump();
    expect(find.text('1. Três'), findsOneWidget);
    expect(find.text('1. Quatro'), findsNothing);
    expect(find.text('2. Um'), findsNothing);
    expect(find.text('A · 1 de 3 hinos'), findsOneWidget);
    expect(find.text('A · 3 hinos'), findsNothing); // cabeçalho de busca

    // O X limpa o campo e restaura a lista inteira.
    await tester.tap(find.byTooltip('Limpar busca'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '');
    expect(find.text('A · 3 hinos'), findsOneWidget);
    expect(find.text('1. Quatro'), findsOneWidget);
    expect(find.text('2. Um'), findsOneWidget);
    expect(find.byTooltip('Limpar busca'), findsNothing);
  });

  testWidgets('busca interna sem resultado mostra a mensagem', (tester) async {
    await montar(tester);
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.text('Nenhum hino encontrado'), findsOneWidget);
    expect(find.byType(BlocoHino), findsNothing);
    expect(find.text('A · 0 de 3 hinos'), findsOneWidget);
  });

  testWidgets('busca interna casa nome sem acento e número do hino',
      (tester) async {
    await montar(tester);
    // Nome acentuado ('Três') com consulta sem acento.
    await tester.enterText(find.byType(TextField), 'tres');
    await tester.pump();
    expect(find.text('1. Três'), findsOneWidget);
    expect(find.text('1. Quatro'), findsNothing);

    // Número do hino: o 'Um' é o num 2 do hinário.
    await tester.enterText(find.byType(TextField), '2');
    await tester.pump();
    expect(find.text('2. Um'), findsOneWidget);
    expect(find.text('1. Três'), findsNothing);
  });
}
