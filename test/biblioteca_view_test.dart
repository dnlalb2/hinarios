// test/biblioteca_view_test.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hinarios_app/data/repositories/hinos_repository.dart';
import 'package:hinarios_app/data/services/hinos_service.dart';
import 'package:hinarios_app/data/services/preferencias_service.dart';
import 'package:hinarios_app/ui/core/preferencias_view_model.dart';
import 'package:hinarios_app/ui/core/widgets/bloco_hino.dart';
import 'package:hinarios_app/ui/features/biblioteca/biblioteca_view.dart';
import 'package:hinarios_app/ui/features/biblioteca/biblioteca_view_model.dart';
import 'hinos_repository_test.dart' show HinosServiceFake;

/// Fixture LOCAL: hinário coletivo — 2 hinos com a MESMA url 'col' mas autores
/// distintos ('X1'/'X2'), o caso real de 35 dos 84 hinários do acervo.
class HinosServiceColetivoFake implements HinosService {
  @override
  Future<String> carregarJson() async => jsonEncode([
        {
          'slug': 'x1/1/um', 'num': 1, 'nome': 'Um', 'autor': 'X1',
          'autor_full': 'X1', 'hinario': 'Caboclo', 'urlhinario': 'col',
          'ritmo': '', 'letra': 'Letra do Um',
        },
        {
          'slug': 'x2/1/dois', 'num': 2, 'nome': 'Dois', 'autor': 'X2',
          'autor_full': 'X2', 'hinario': 'Caboclo', 'urlhinario': 'col',
          'ritmo': '', 'letra': 'Letra do Dois',
        },
      ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Última instância criada por montar(): os testes de estrela leem daqui.
  late PreferenciasViewModel pref;

  Future<Widget> montar({HinosService? service, List<String> favoritos = const []}) async {
    SharedPreferences.setMockInitialValues({});
    final repo = HinosRepository(service: service ?? HinosServiceFake());
    await repo.carregar();
    pref = PreferenciasViewModel(service: PreferenciasService());
    await pref.restaurar();
    for (final slug in favoritos) {
      pref.toggleFavorito(slug);
    }
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

  // Rótulo dentro do seletor de visão (a AppBar também tem um 'Hinários').
  Finder segmento(String rotulo) => find.descendant(
      of: find.byType(SegmentedButton<bool>), matching: find.text(rotulo));

  /// 'Autores' é o 2º segmento: a árvore só aparece depois de tocar nele
  /// (o padrão da home é a lista plana de hinários).
  Future<void> irParaAutores(WidgetTester tester) async {
    await tester.tap(segmento('Autores'));
    await tester.pumpAndSettle();
  }

  testWidgets('mostra autores; expandir revela hinários', (tester) async {
    await tester.pumpWidget(await montar());
    await irParaAutores(tester);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('Hinário X'), findsNothing); // colapsado
    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();
    expect(find.text('Hinário X'), findsOneWidget);
  });

  testWidgets('busca troca a lista por resultados compactos', (tester) async {
    await tester.pumpWidget(await montar());
    await tester.enterText(find.byType(TextField), 'terra');
    await tester.pumpAndSettle();
    expect(find.byType(ExpansionTile), findsNothing);
    expect(find.text('1. Três'), findsOneWidget);
    // Resultado é um ListTile compacto — a letra inteira NÃO é despejada.
    expect(find.byType(BlocoHino), findsNothing);
    expect(find.text('Hinos (1)'), findsOneWidget);
    expect(find.widgetWithText(ListTile, '1. Três'), findsOneWidget);
    expect(find.text('A · Hinário X'), findsOneWidget); // autor · hinário
    // 'terra' casou a LETRA: o trecho aparece com o termo destacado.
    final rich = tester.widget<Text>(find.textContaining('Terra'));
    final spans = (rich.textSpan! as TextSpan).children!.cast<TextSpan>();
    expect(spans.map((s) => s.text), ['', 'Terra', ' e mar']);
    expect(spans[1].style!.fontWeight, FontWeight.w600);
    expect(spans[1].style!.color,
        Theme.of(tester.element(find.byType(BibliotecaView))).colorScheme.primary);
    expect(rich.maxLines, 2); // trecho longo não estica a linha
  });

  testWidgets('tocar num resultado abre a página do hino', (tester) async {
    await tester.pumpWidget(await montar());
    await tester.enterText(find.byType(TextField), 'terra');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, '1. Três'));
    await tester.pumpAndSettle();
    expect(find.byType(BlocoHino), findsOneWidget); // a página do hino, inteira
    expect(find.byTooltip('Favorito'), findsOneWidget);
    expect(find.text('ver no hinário'), findsOneWidget);
  });

  testWidgets('só favoritos (sem busca) segue com os BlocoHino completos', (tester) async {
    await tester.pumpWidget(await montar(favoritos: ['a/3/tres']));
    await tester.tap(find.byTooltip('Favoritos'));
    await tester.pumpAndSettle();
    expect(find.byType(BlocoHino), findsOneWidget);
    expect(find.text('1. Três'), findsOneWidget);
    expect(find.text('Hinos (1)'), findsNothing); // lista de leitura, não de busca
  });

  testWidgets('busca + só favoritos também usa a lista compacta', (tester) async {
    await tester.pumpWidget(await montar(favoritos: ['a/3/tres']));
    await tester.enterText(find.byType(TextField), 'terra');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Favoritos'));
    await tester.pumpAndSettle();
    expect(find.byType(BlocoHino), findsNothing);
    expect(find.text('Hinos (1)'), findsOneWidget);
    expect(find.widgetWithText(ListTile, '1. Três'), findsOneWidget);
  });

  testWidgets('busca sem acento mostra a seção Hinários e navega para o grupo', (tester) async {
    await tester.pumpWidget(await montar());
    await tester.enterText(find.byType(TextField), 'hinario'); // 'Hinário' sem acento
    await tester.pumpAndSettle();
    // Cabeçalho da seção de grupos (a AppBar agora mostra o nome do app).
    expect(find.text('Hinários'), findsOneWidget);
    // Grupos GLOBAIS (X coletivo, X (z) de A, Y de A) — só ListTile, não os
    // chips do BlocoHino. 'Hinário X' aparece UMA vez (o grupo de A e B juntos).
    expect(find.widgetWithText(ListTile, 'Hinário X'), findsOneWidget);
    expect(find.text('Diversos · 3 hinos'), findsOneWidget); // subtítulo do 1º
    // Os hinos que casam continuam logo abaixo da seção de grupos, agora
    // como resultados compactos.
    expect(find.text('Hinos (5)'), findsOneWidget);
    expect(find.widgetWithText(ListTile, '2. Um'), findsOneWidget);
    expect(tester.getTopLeft(find.text('2. Um')).dy,
        greaterThan(tester.getTopLeft(find.byType(Divider)).dy));
    await tester.tap(find.widgetWithText(ListTile, 'Hinário X').first);
    await tester.pumpAndSettle();
    expect(find.text('1. Três'), findsOneWidget); // hinos do grupo escolhido
    expect(find.text('2. Um'), findsOneWidget);
    expect(find.text('1. Quatro'), findsOneWidget); // o de B entra no grupo global
  });

  testWidgets('só favoritos não mostra a seção de hinários', (tester) async {
    await tester.pumpWidget(await montar());
    await tester.enterText(find.byType(TextField), 'hinario');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Hinário X'), findsOneWidget);
    await tester.tap(find.byTooltip('Favoritos'));
    await tester.pumpAndSettle();
    expect(find.text('Hinários'), findsNothing); // a seção de grupos some no modo favoritos
    expect(find.widgetWithText(ListTile, 'Hinário X'), findsNothing);
  });

  testWidgets('tocar no hinário abre a página do hinário', (tester) async {
    await tester.pumpWidget(await montar());
    await irParaAutores(tester);
    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hinário X'));
    await tester.pumpAndSettle();
    expect(find.text('1. Três'), findsOneWidget); // hinos em sequência
    expect(find.text('2. Um'), findsOneWidget);
    expect(find.text('1. Quatro'), findsOneWidget); // grupo global: traz o de B
    expect(find.text('Diversos · 3 hinos'), findsOneWidget); // cabeçalho do grupo
  });

  testWidgets('visão Hinários: lista plana por nome e navega', (tester) async {
    await tester.pumpWidget(await montar());
    expect(find.byType(SegmentedButton<bool>), findsOneWidget);
    expect(find.byType(ExpansionTile), findsNothing); // padrão: lista plana

    // UM grupo global por hinário: 'Hinário X' (A+B juntos), 'X (z)' e 'Y'.
    expect(find.widgetWithText(ListTile, 'Hinário X'), findsOneWidget);
    expect(find.text('Diversos · 3 hinos'), findsOneWidget); // subtítulo do 1º
    // Os dois grupos de A sozinhos: a url 'z' (1 hino) e o 'y' (1 hino).
    expect(find.text('A · 1 hinos'), findsNWidgets(2));
    expect(find.text('Hinário Y'), findsOneWidget);

    // O 1º é o coletivo (ordenado pelo rótulo normalizado) e abre completo.
    await tester.tap(find.widgetWithText(ListTile, 'Hinário X'));
    await tester.pumpAndSettle();
    expect(find.text('1. Três'), findsOneWidget); // hinos do grupo escolhido
    expect(find.text('2. Um'), findsOneWidget);
    expect(find.text('1. Quatro'), findsOneWidget); // veio do autor B
  });

  testWidgets('voltar para Autores restaura a árvore', (tester) async {
    await tester.pumpWidget(await montar());
    expect(find.byType(ExpansionTile), findsNothing); // padrão: lista plana
    expect(find.text('Hinário X'), findsOneWidget);

    await irParaAutores(tester);
    expect(find.byType(ExpansionTile), findsWidgets);
    expect(find.text('Hinário X'), findsNothing); // árvore colapsada

    await tester.tap(segmento('Hinários'));
    await tester.pumpAndSettle();
    expect(find.byType(ExpansionTile), findsNothing); // árvore deu lugar à lista
    expect(find.widgetWithText(ListTile, 'Hinário X'), findsOneWidget);
  });

  testWidgets('em busca (ou só favoritos) o seletor de visão não aparece', (tester) async {
    await tester.pumpWidget(await montar());
    expect(find.byType(SegmentedButton<bool>), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'terra');
    await tester.pumpAndSettle();
    expect(find.byType(SegmentedButton<bool>), findsNothing);
    expect(find.text('1. Três'), findsOneWidget); // resultados seguem iguais

    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Favoritos'));
    await tester.pumpAndSettle();
    expect(find.byType(SegmentedButton<bool>), findsNothing);
  });

  testWidgets('botão de limpar aparece só com busca ativa', (tester) async {
    await tester.pumpWidget(await montar());
    expect(find.byTooltip('Limpar busca'), findsNothing); // campo vazio

    await tester.enterText(find.byType(TextField), 'terra');
    await tester.pumpAndSettle();
    expect(find.byTooltip('Limpar busca'), findsOneWidget);
  });

  testWidgets('botão de limpar esvazia o campo e sai da busca', (tester) async {
    await tester.pumpWidget(await montar());
    await tester.enterText(find.byType(TextField), 'terra');
    await tester.pumpAndSettle();
    expect(find.text('Hinos (1)'), findsOneWidget);

    await tester.tap(find.byTooltip('Limpar busca'));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '');
    expect(find.text('Hinos (1)'), findsNothing);
    expect(find.byType(SegmentedButton<bool>), findsOneWidget);
  });

  testWidgets('cabeçalho do autor conta só os hinos dele no coletivo', (tester) async {
    await tester.pumpWidget(await montar(service: HinosServiceColetivoFake()));
    await irParaAutores(tester);

    await tester.tap(find.text('X1'));
    await tester.pumpAndSettle();

    // O cabeçalho do autor conta só os hinos DELE ('X1' tem 1 dos 2 do 'col').
    final cabecalho = find.widgetWithText(ExpansionTile, 'X1');
    expect(find.descendant(of: cabecalho, matching: find.text('1 hinos')),
        findsOneWidget);
    // O tile do grupo segue com a contagem GLOBAL (o hinário completo).
    expect(
        find.descendant(
            of: find.widgetWithText(ListTile, 'Caboclo'),
            matching: find.text('2 hinos')),
        findsOneWidget);
  });

  testWidgets('hinário coletivo: aparece sob cada autor e mostra Diversos', (tester) async {
    await tester.pumpWidget(await montar(service: HinosServiceColetivoFake()));
    await irParaAutores(tester);

    // Árvore: 'col' (autores X1 e X2) é UM grupo global sob CADA autor, com os
    // 2 hinos — antes fragmentava num grupo de 1 hino por autor.
    await tester.tap(find.text('X1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('X2'));
    await tester.pumpAndSettle();
    final tiles = find.widgetWithText(ListTile, 'Caboclo');
    expect(tiles, findsNWidgets(2)); // um sob cada autor
    expect(find.descendant(of: tiles.first, matching: find.text('2 hinos')),
        findsOneWidget);

    // Lista plana: o coletivo vira 'Diversos · 2 hinos'.
    await tester.tap(segmento('Hinários'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Caboclo'), findsOneWidget);
    expect(find.text('Diversos · 2 hinos'), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, 'Caboclo'));
    await tester.pumpAndSettle();
    expect(find.text('1. Um'), findsOneWidget); // hinos dos DOIS autores
    expect(find.text('2. Dois'), findsOneWidget);
    expect(find.text('Diversos · 2 hinos'), findsOneWidget); // cabeçalho
  });

  testWidgets('estrela no tile da árvore favorita o hinário sem abri-lo', (tester) async {
    await tester.pumpWidget(await montar());
    await irParaAutores(tester);
    await tester.tap(find.text('A')); // expande o autor
    await tester.pumpAndSettle();

    final tile = find.widgetWithText(ListTile, 'Hinário Y');
    await tester.tap(
        find.descendant(of: tile, matching: find.byTooltip('Favoritar hinário')));
    await tester.pumpAndSettle();

    expect(pref.hinariosFavoritos, contains('y'));
    // Favoritar não navega: a biblioteca segue na tela, com a estrela cheia.
    expect(find.byType(SegmentedButton<bool>), findsOneWidget);
    expect(find.descendant(of: tile, matching: find.byIcon(Icons.star)), findsOneWidget);
  });

  testWidgets('estrela no tile da lista plana favorita o grupo', (tester) async {
    await tester.pumpWidget(await montar());
    expect(find.byType(ExpansionTile), findsNothing); // padrão: lista plana

    final tile = find.widgetWithText(ListTile, 'Hinário X');
    await tester.tap(
        find.descendant(of: tile, matching: find.byTooltip('Favoritar hinário')));
    await tester.pumpAndSettle();

    expect(pref.hinariosFavoritos, contains('x'));
    expect(find.descendant(of: tile, matching: find.byIcon(Icons.star)), findsOneWidget);
  });

  testWidgets('só favoritos: seção Hinários + hinos favoritos completos', (tester) async {
    await tester.pumpWidget(await montar(favoritos: ['a/3/tres']));
    // Favorita o hinário pela estrela da árvore.
    await irParaAutores(tester);
    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.widgetWithText(ListTile, 'Hinário Y'),
        matching: find.byTooltip('Favoritar hinário')));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Favoritos'));
    await tester.pumpAndSettle();

    // 1ª seção: os hinários favoritados.
    expect(find.text('Hinários'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Hinário Y'), findsOneWidget);
    // 2ª seção: os hinos favoritos, inteiros (lista de leitura).
    expect(find.byType(BlocoHino), findsOneWidget);
    expect(find.text('1. Três'), findsOneWidget);

    // Tocar no hinário favoritado abre o hinário COMPLETO.
    await tester.tap(find.widgetWithText(ListTile, 'Hinário Y'));
    await tester.pumpAndSettle();
    expect(find.text('1. Dois'), findsOneWidget);
  });

  testWidgets('só favoritos sem hinário favoritado não mostra a seção', (tester) async {
    await tester.pumpWidget(await montar(favoritos: ['a/3/tres']));
    await tester.tap(find.byTooltip('Favoritos'));
    await tester.pumpAndSettle();
    expect(find.text('Hinários'), findsNothing); // sem grupos estrelados
    expect(find.byType(BlocoHino), findsOneWidget); // só a lista de hinos
  });
}
