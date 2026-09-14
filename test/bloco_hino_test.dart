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
    // O espaço inicial do compasso é preservado (coluna do acorde).
    expect(find.text(' A D'), findsOneWidget);
  });

  // Regressão I1: com cifra, a letra já vem intercalada com os acordes;
  // o Text(hino.letra) extra duplicava a música inteira.
  testWidgets('com cifra a letra aparece só uma vez', (tester) async {
    await tester.pumpWidget(montar(await vmNovo(), hino));
    expect(find.text(hino.letra), findsNothing); // texto multilinha duplicado
    final semCifra = Hino(
      slug: 'a/2/sem-cifra', num: 2, nome: 'Sem Cifra', autor: 'A',
      autorFull: 'A', hinario: 'H', urlhinario: 'h', ritmo: '',
      letra: 'Só a letra',
    );
    await tester.pumpWidget(montar(await vmNovo(), semCifra));
    expect(find.text('Só a letra'), findsOneWidget); // sem cifra, letra normal
  });

  // Regressão I2: cifra e letra acompanham o tamanho de fonte escolhido
  // (Configurações promete "Letra e cifra acompanham o tamanho escolhido").
  testWidgets('cifra e letra escalam com o tamanho de fonte', (tester) async {
    final vm = await vmNovo();
    vm.setTamanhoFonte(28);
    await tester.pumpWidget(montar(vm, hino));
    final acorde = tester.widget<Text>(find.text('D Bm'));
    expect(acorde.style!.fontSize, 13 * 28 / 16);
    expect(acorde.style!.fontFamily, 'monospace');
    final letra = tester.widget<Text>(find.text('Sol, Lua, Estrela'));
    expect(letra.style!.fontSize, 14 * 28 / 16);
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

  testWidgets('estrela alterna favorito', (tester) async {
    final vm = await vmNovo();
    await tester.pumpWidget(montar(vm, hino));
    await tester.tap(find.byIcon(Icons.star_border));
    await tester.pump();
    expect(vm.favoritos, contains(hino.slug));
    expect(find.byIcon(Icons.star), findsOneWidget);
  });
}
