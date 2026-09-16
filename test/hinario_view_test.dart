// test/hinario_view_test.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hinarios_app/data/repositories/hinos_repository.dart';
import 'package:hinarios_app/data/services/cifras_locais_service.dart';
import 'package:hinarios_app/data/services/hinos_service.dart';
import 'package:hinarios_app/data/services/preferencias_service.dart';
import 'package:hinarios_app/ui/core/cifras_locais_view_model.dart';
import 'package:hinarios_app/ui/core/preferencias_view_model.dart';
import 'package:hinarios_app/ui/core/widgets/bloco_hino.dart';
import 'package:hinarios_app/ui/core/widgets/pinca_fonte.dart';
import 'package:hinarios_app/ui/features/hinario/hinario_view.dart';
import 'package:hinarios_app/ui/features/hinario/hinario_view_model.dart';
import 'hinos_repository_test.dart' show HinosServiceFake;

/// Fixture LOCAL com 25 hinos no hinário 'x' — o fixture compartilhado tem só
/// 3, curto demais para a lista rolar (os testes de esconder a busca precisam
/// de conteúdo além da tela).
class HinosServiceGrandeFake implements HinosService {
  @override
  Future<String> carregarJson() async => jsonEncode([
        for (var i = 1; i <= 25; i++)
          {
            'slug': 'a/$i/hino$i', 'num': i, 'nome': 'Hino $i', 'autor': 'A',
            'autor_full': 'A', 'hinario': 'Hinário X', 'urlhinario': 'x',
            'ritmo': '', 'letra': 'Letra do hino $i',
          },
      ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Página do hinário 'x' do fake (Três, Quatro e Um, nesta ordem).
  Future<HinarioViewModel> montar(WidgetTester tester,
      {HinosService? service}) async {
    SharedPreferences.setMockInitialValues({});
    final repo = HinosRepository(service: service ?? HinosServiceFake());
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
          // o BlocoHino lê as cifras próprias do usuário
          ChangeNotifierProvider.value(
              value: CifrasLocaisViewModel(service: CifrasLocaisService())),
        ],
        child: const MaterialApp(home: HinarioView(autor: 'A', hinario: 'Hinário X')),
      ),
    );
    return vm;
  }

  /// Quanto do campo de busca está à mostra: 1.0 inteiro, 0.0 escondido. Sobe
  /// do TextField — que fica MONTADO mesmo escondido — até o AnimatedAlign que
  /// o envolve. `.last` é o mais externo: o nosso wrapper, não algum
  /// AnimatedAlign interno do Material (mesmo helper da BibliotecaView).
  double? fatorDaBusca(WidgetTester tester) => tester
      .widgetList<AnimatedAlign>(find.ancestor(
          of: find.byType(TextField), matching: find.byType(AnimatedAlign)))
      .last
      .heightFactor;

  /// Rola a lista. Só o gesto do usuário mexe no campo: por isso os testes
  /// usam drag, não `jumpTo`.
  Future<void> rolar(WidgetTester tester, double dy) async {
    await tester.drag(find.byType(ListView).first, Offset(0, dy));
    await tester.pumpAndSettle();
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
          // o BlocoHino lê as cifras próprias do usuário
          ChangeNotifierProvider.value(
              value: CifrasLocaisViewModel(service: CifrasLocaisService())),
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
          // o BlocoHino lê as cifras próprias do usuário
          ChangeNotifierProvider.value(
              value: CifrasLocaisViewModel(service: CifrasLocaisService())),
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
          // o BlocoHino lê as cifras próprias do usuário
          ChangeNotifierProvider.value(
              value: CifrasLocaisViewModel(service: CifrasLocaisService())),
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

  testWidgets('rolar para baixo esconde a busca e rolar para cima traz de volta',
      (tester) async {
    await montar(tester, service: HinosServiceGrandeFake());
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Buscar neste hinário…'), findsOneWidget);
    expect(fatorDaBusca(tester), 1.0); // abre com a busca à mostra

    // Rolar para baixo esconde o campo de busca...
    await rolar(tester, -600);
    expect(fatorDaBusca(tester), 0.0);
    // ...mas ele segue MONTADO escondido: o texto digitado e o foco
    // sobrevivem ao sumiço.
    expect(find.byType(TextField), findsOneWidget);

    // Rolar para cima traz de volta.
    await rolar(tester, 200);
    expect(fatorDaBusca(tester), 1.0);
  });

  testWidgets('trocar a busca reexibe o campo escondido pela rolagem',
      (tester) async {
    final vm = await montar(tester, service: HinosServiceGrandeFake());
    // Filtra e rola para baixo: o campo fica escondido.
    await tester.enterText(find.byType(TextField), 'hino 1');
    await tester.pumpAndSettle();
    await rolar(tester, -600);
    expect(fatorDaBusca(tester), 0.0);

    // A busca mudou por fora do gesto (o X do próprio campo zera a query):
    // o campo volta sozinho, sem o usuário precisar rolar de volta.
    vm.setQuery('');
    await tester.pumpAndSettle();
    // Volta sozinho, sem nenhum gesto de rolagem.
    expect(fatorDaBusca(tester), 1.0);

    // E a lista voltou ao conteúdo inteiro (25 hinos) — o cabeçalho só
    // reaparece porque o filho do topo volta a ser construído ao subir.
    await rolar(tester, 600);
    expect(find.text('A · 25 hinos'), findsOneWidget);
  });
}
