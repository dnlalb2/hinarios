// test/editor_cifra_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hinarios_app/data/services/cifras_locais_service.dart';
import 'package:hinarios_app/data/services/preferencias_service.dart';
import 'package:hinarios_app/domain/models/cifra_local.dart';
import 'package:hinarios_app/domain/models/hino.dart';
import 'package:hinarios_app/ui/core/cifras_locais_view_model.dart';
import 'package:hinarios_app/ui/core/preferencias_view_model.dart';
import 'package:hinarios_app/ui/features/hino/editor_cifra_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final hino = Hino(
    slug: 'a/1/sem-cifra', num: 1, nome: 'Sem Cifra', autor: 'A',
    autorFull: 'A', hinario: 'H', urlhinario: 'h', ritmo: '',
    letra: 'Primeira linha\n\nSegunda linha\nTerceira linha',
  );

  /// Abre o editor como na vida real: empurrado sobre uma tela qualquer (o
  /// pop do salvar/remover precisa de uma rota embaixo).
  Future<CifrasLocaisViewModel> montar(WidgetTester tester,
      {CifraLocal? inicial, double tamanhoFonte = 20}) async {
    SharedPreferences.setMockInitialValues({});
    final vm = CifrasLocaisViewModel(service: CifrasLocaisService());
    if (inicial != null) vm.salvar(hino.slug, inicial);
    final prefs = PreferenciasViewModel(service: PreferenciasService());
    await prefs.restaurar();
    prefs.setTamanhoFonte(tamanhoFonte); // o editor lê como 1:1 da exibição
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: vm),
          ChangeNotifierProvider.value(value: prefs),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => abrirEditorCifra(context, hino),
                child: const Text('abrir editor'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir editor'));
    await tester.pumpAndSettle();
    return vm;
  }

  Future<void> escolherTom(WidgetTester tester, String tom) async {
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tom).last); // o item do menu
    await tester.pumpAndSettle();
  }

  testWidgets('um campo por linha NÃO-VAZIA da letra', (tester) async {
    await montar(tester);
    expect(find.text('Cifra — Sem Cifra'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3)); // a linha vazia não conta
    expect(find.text('Primeira linha'), findsOneWidget);
    expect(find.text('Segunda linha'), findsOneWidget);
    expect(find.text('Terceira linha'), findsOneWidget);
  });

  // Regressão UX: o formulário é um preview 1:1 da exibição. O campo de
  // acordes e a régua de letra logo acima dele têm que usar a MESMA métrica
  // monoespaçada (e o mesmo tamanho do display): em fonte proporcional o
  // usuário posiciona o acorde por espaços contando colunas que não existem,
  // e a cifra sai desalinhada na exibição.
  testWidgets('campo de acordes e régua de letra: mesma métrica monoespaçada', (tester) async {
    await montar(tester, tamanhoFonte: 22);
    final campo = tester.widget<TextField>(find.byType(TextField).first);
    final regua = tester.widget<Text>(find.text('Primeira linha'));
    expect(campo.style!.fontFamily, 'monospace');
    expect(regua.style!.fontFamily, 'monospace');
    expect(campo.style!.fontSize, 22); // = vm.tamanhoFonte (1:1 com o display)
    expect(regua.style!.fontSize, campo.style!.fontSize);
  });

  testWidgets('salvar grava tom + acordes por linha no VM e volta', (tester) async {
    final vm = await montar(tester);
    await escolherTom(tester, 'D');
    await tester.enterText(find.byType(TextField).at(0), 'D Bm');
    await tester.enterText(find.byType(TextField).at(2), 'A');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    final salva = vm.cifraDe(hino.slug)!;
    expect(salva.tom, 'D');
    expect(salva.acordesPorLinha, ['D Bm', '', 'A']);
    expect(find.text('Cifra salva'), findsOneWidget); // SnackBar
    expect(find.text('abrir editor'), findsOneWidget); // rota fechada
  });

  // Regressão: os espaços à ESQUERDA posicionam o acorde sobre a sílaba
  // certa da letra — o trim() do salvar jogava o acorde para a coluna 0.
  // Só os espaços à direita (sem valor posicional) podem sair.
  testWidgets('salvar preserva os espaços de posicionamento dos acordes', (tester) async {
    final vm = await montar(tester);
    await escolherTom(tester, 'D');
    await tester.enterText(find.byType(TextField).at(0), '   Am   E7');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(vm.cifraDe(hino.slug)!.acordesPorLinha.first, '   Am   E7');
  });

  testWidgets('salvar corta só os espaços à direita do acorde', (tester) async {
    final vm = await montar(tester);
    await escolherTom(tester, 'D');
    await tester.enterText(find.byType(TextField).at(0), '  Am E7   ');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(vm.cifraDe(hino.slug)!.acordesPorLinha.first, '  Am E7');
  });

  testWidgets('sem tom ou sem nenhum acorde não salva', (tester) async {
    final vm = await montar(tester);
    await tester.enterText(find.byType(TextField).first, 'D Bm');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(vm.cifraDe(hino.slug), isNull); // faltou o tom
    expect(find.text('Escolha o tom e preencha ao menos uma linha'), findsOneWidget);
    expect(find.text('abrir editor'), findsNothing); // editor segue aberto
  });

  testWidgets('abre com a cifra existente preenchida (posicional)', (tester) async {
    final vm = await montar(
      tester,
      inicial: const CifraLocal(tom: 'G', acordesPorLinha: ['G D', '', 'Em']),
    );
    expect(find.text('G D'), findsOneWidget);
    expect(find.text('Em'), findsOneWidget);
    expect(find.text('G'), findsWidgets); // tom pré-selecionado no dropdown

    // Salvar de novo mantém o que veio (inclusive o tom pré-selecionado).
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(vm.cifraDe(hino.slug)!.tom, 'G');
    expect(vm.cifraDe(hino.slug)!.acordesPorLinha, ['G D', '', 'Em']);
  });

  testWidgets('remover: cancelar mantém, confirmar apaga e volta', (tester) async {
    final vm = await montar(tester, inicial: const CifraLocal(tom: 'D', acordesPorLinha: ['D']));
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(vm.cifraDe(hino.slug), isNotNull);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remover'));
    await tester.pumpAndSettle();
    expect(vm.cifraDe(hino.slug), isNull);
    expect(find.text('Cifra removida'), findsOneWidget);
    expect(find.text('abrir editor'), findsOneWidget); // rota fechada
  });

  // Sem cifra própria não existe o que remover: o botão não aparece.
  testWidgets('cifra nova não mostra o botão de remover', (tester) async {
    await montar(tester);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });
}
