import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hinarios_app/data/services/cifras_locais_service.dart';
import 'package:hinarios_app/data/services/preferencias_service.dart';
import 'package:hinarios_app/domain/models/cifra_local.dart';
import 'package:hinarios_app/domain/models/hino.dart';
import 'package:hinarios_app/ui/core/cifras_locais_view_model.dart';
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

  Widget montar(PreferenciasViewModel vm, Hino h, {CifrasLocaisViewModel? cifras}) =>
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: vm),
          ChangeNotifierProvider.value(
              value: cifras ?? CifrasLocaisViewModel(service: CifrasLocaisService())),
        ],
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

  final semCifra = Hino(
    slug: 'a/2/sem-cifra', num: 2, nome: 'Sem Cifra', autor: 'A',
    autorFull: 'A', hinario: 'H', urlhinario: 'h', ritmo: '',
    letra: 'Só a letra',
  );

  testWidgets('mostra título, letra e acordes acima', (tester) async {
    await tester.pumpWidget(montar(await vmNovo(), hino));
    expect(find.textContaining('Sol, Lua, Estrela'), findsWidgets);
    expect(find.text('A Terra, o Vento e o Mar'), findsOneWidget);
    expect(find.text('D Bm'), findsOneWidget);
    // O espaço inicial do compasso é preservado (coluna do acorde).
    expect(find.text(' A D'), findsOneWidget);
  });

  // Regressão I1: com cifra, a letra já vem intercalada com os acordes;
  // o Text(hino.letra) extra duplicava a música inteira.
  testWidgets('com cifra a letra aparece só uma vez', (tester) async {
    await tester.pumpWidget(montar(await vmNovo(), hino));
    expect(find.text(hino.letra), findsNothing); // texto multilinha duplicado
    await tester.pumpWidget(montar(await vmNovo(), semCifra));
    expect(find.text('Só a letra'), findsOneWidget); // sem cifra, letra normal
  });

  // Regressão I2: cifra e letra acompanham o tamanho de fonte escolhido
  // (Configurações promete "Letra e cifra acompanham o tamanho escolhido") —
  // e com o MESMO tamanho: um caractere da linha de acordes tem que ocupar a
  // mesma coluna da linha de letra, senão o acorde não fica sobre a sílaba.
  testWidgets('cifra e letra usam o mesmo tamanho de fonte', (tester) async {
    final vm = await vmNovo();
    vm.setTamanhoFonte(22);
    await tester.pumpWidget(montar(vm, hino));
    final acorde = tester.widget<Text>(find.text('D Bm'));
    expect(acorde.style!.fontSize, 22); // = vm.tamanhoFonte, sem escala própria
    expect(acorde.style!.fontFamily, 'monospace');
    final letra = tester.widget<Text>(find.text('Sol, Lua, Estrela'));
    expect(letra.style!.fontSize, acorde.style!.fontSize);
    expect(letra.style!.fontFamily, 'monospace'); // mesma fonte dos acordes
  });

  testWidgets('botão + transposta acordes e tom exibido', (tester) async {
    final vm = await vmNovo();
    await tester.pumpWidget(montar(vm, hino));
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pump();
    expect(find.text('D#'), findsWidgets); // tom e acordes
    expect(vm.deslocamentoDe(hino.slug), 1);
  });

  // Regressão C1: 179 cifras do acervo usam NBSP (U+00A0) como preenchimento.
  // O split por espaço simples tratava uma sequência de acordes colados por
  // NBSP como UM token e só o primeiro transpunha (o tom exibido atualizava,
  // escondendo o bug). Com a normalização no parse, todos os acordes movem.
  testWidgets('cifra com NBSP transpõe todos os acordes', (tester) async {
    final hinoNbsp = Hino.fromJson({
      'slug': 'alex-polari/3/fardamento',
      'num': 3,
      'nome': 'Fardamento',
      'autor': 'Alex Polari',
      'autor_full': 'Alex Polari',
      'hinario': 'Nova Anunciação',
      'urlhinario': 'nova-anunciacao',
      'ritmo': 'marcha',
      'letra': 'Vou vestir a farda\nDa Virgem Mãe\nCom fé',
      'cifra': {
        'tom': 'D',
        // NBSP separa acordes (e preenche colunas) — antes do fix o split
        // por espaço tratava cada compasso inteiro como um único token.
        'texto': 'D A D;Bm F#m Bm;Em   A   D',
      },
    });
    final vm = await vmNovo();
    await tester.pumpWidget(montar(vm, hinoNbsp));
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pump();
    // Todos os acordes do compasso movem (antes: 1º movia, demais ficavam).
    expect(find.text('D# A# D#'), findsOneWidget);
    expect(find.text('Cm Gm Cm'), findsOneWidget);
    expect(find.text('Fm   A#   D#'), findsOneWidget); // runs de NBSP viram espaços
  });

  // Fase 1 das cifras próprias: ~2000 hinos do acervo não têm cifra — o
  // convite para escrever uma fica logo abaixo da letra.
  testWidgets('hino sem cifra: botão Adicionar cifra abre o editor', (tester) async {
    await tester.pumpWidget(montar(await vmNovo(), semCifra));
    expect(find.text('Só a letra'), findsOneWidget);
    expect(find.byIcon(Icons.edit), findsNothing); // nada para editar ainda
    await tester.tap(find.text('Adicionar cifra'));
    await tester.pumpAndSettle();
    expect(find.text('Cifra — Sem Cifra'), findsOneWidget); // editor aberto
  });

  // Cifra própria tem precedência sobre a oficial E entra na mesma
  // transposição (mesmo caminho de renderização das cifras do acervo).
  testWidgets('cifra local renderiza acordes transponíveis e o lápis', (tester) async {
    final cifras = CifrasLocaisViewModel(service: CifrasLocaisService());
    cifras.salvar(semCifra.slug, const CifraLocal(tom: 'D', acordesPorLinha: ['D Bm']));
    await tester.pumpWidget(montar(await vmNovo(), semCifra, cifras: cifras));

    expect(find.text('D Bm'), findsOneWidget); // acordes acima da letra
    expect(find.text('Só a letra'), findsOneWidget); // letra sem duplicar
    expect(find.text('Adicionar cifra'), findsNothing);

    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pump();
    expect(find.text('D# Cm'), findsOneWidget); // meio tom acima, como nas oficiais

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();
    expect(find.text('Cifra — Sem Cifra'), findsOneWidget);
    expect(find.text('D Bm'), findsOneWidget); // campo preenchido (tom original)
  });

  // Regressão: o espaço inicial do acorde (coluna sobre a sílaba) precisa
  // sobreviver ao caminho inteiro — cifra local → textoCifra → alinhar →
  // render. O match exato da string prova que a coluna não se perdeu.
  testWidgets('cifra local mantém os espaços de posicionamento dos acordes', (tester) async {
    final cifras = CifrasLocaisViewModel(service: CifrasLocaisService());
    cifras.salvar(semCifra.slug, const CifraLocal(tom: 'D', acordesPorLinha: ['   Am   E7']));
    await tester.pumpWidget(montar(await vmNovo(), semCifra, cifras: cifras));

    expect(find.text('   Am   E7'), findsOneWidget); // coluna preservada
  });

  // Regressão UX: "digito os espaços para posicionar o acorde no formulário,
  // mas a exibição não bate". As colunas só batem se a linha de acordes e a
  // de letra tiverem a MESMA métrica (família monoespaçada + mesmo tamanho),
  // inclusive quando os espaços à esquerda empurram o acorde para a direita.
  testWidgets('acorde com espaços à esquerda mantém a métrica da letra', (tester) async {
    final vm = await vmNovo();
    vm.setTamanhoFonte(22);
    final cifras = CifrasLocaisViewModel(service: CifrasLocaisService());
    cifras.salvar(semCifra.slug, const CifraLocal(tom: 'D', acordesPorLinha: ['   Am']));
    await tester.pumpWidget(montar(vm, semCifra, cifras: cifras));

    final acorde = tester.widget<Text>(find.text('   Am'));
    final letra = tester.widget<Text>(find.text('Só a letra'));
    expect(acorde.style!.fontFamily, 'monospace');
    expect(letra.style!.fontFamily, 'monospace');
    expect(acorde.style!.fontSize, letra.style!.fontSize); // mesma coluna
    expect(acorde.style!.fontSize, 22);
  });

  // Pitch idêntico ao do editor: lá a régua e o campo usam letterSpacing 0
  // (ver editor_cifra_view). Se a exibição herdar o letterSpacing do tema
  // (bodyMedium = 0.25), a coluna N da exibição anda 0.25px por caractere em
  // relação ao preview do formulário — o acorde sai do lugar combinado.
  testWidgets('acordes e letra com letterSpacing 0 (pitch idêntico ao editor)', (tester) async {
    final vm = await vmNovo();
    vm.setTamanhoFonte(22);
    final cifras = CifrasLocaisViewModel(service: CifrasLocaisService());
    cifras.salvar(semCifra.slug, const CifraLocal(tom: 'D', acordesPorLinha: ['   Am']));
    await tester.pumpWidget(montar(vm, semCifra, cifras: cifras));

    final acorde = find.text('   Am');
    final letra = find.text('Só a letra');
    // Declarado...
    expect(tester.widget<Text>(acorde).style!.letterSpacing, 0);
    expect(tester.widget<Text>(letra).style!.letterSpacing, 0);
    // ...e EFETIVO (depois do merge com o DefaultTextStyle do tema).
    final estiloAcorde = tester.renderObject<RenderParagraph>(acorde).text.style!;
    final estiloLetra = tester.renderObject<RenderParagraph>(letra).text.style!;
    expect(estiloAcorde.letterSpacing, 0);
    expect(estiloLetra.letterSpacing, 0);

    // Posicional: a coluna 3 (onde começa o 'Am') cai no MESMO x nas duas
    // linhas — é a promessa "o acorde fica sobre a sílaba".
    double coluna(Finder f, int i) =>
        tester.getTopLeft(f).dx +
        tester
            .renderObject<RenderParagraph>(f)
            .getBoxesForSelection(TextSelection(baseOffset: i, extentOffset: i + 1))
            .first
            .left;
    expect(coluna(acorde, 3), coluna(letra, 3));
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
