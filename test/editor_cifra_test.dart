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
    // CRLF, como vem do acervo.
    letra: 'Primeira linha\r\n\r\nSegunda linha\r\nTerceira linha',
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
    prefs.setTamanhoFonte(tamanhoFonte);
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

  /// O texto do campo único — o que o usuário vê e o que o salvar grava.
  String textoDoCampo(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  testWidgets('campo único, monoespaçado, com a instrução do formato', (tester) async {
    await montar(tester);
    expect(find.text('Cifra — Sem Cifra'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget); // acabou o campo por linha
    expect(find.textContaining('entre colchetes antes da palavra'), findsOneWidget);

    final campo = tester.widget<TextField>(find.byType(TextField));
    expect(campo.style!.fontFamily, 'monospace'); // 1:1 com a exibição
    expect(campo.style!.fontSize, 20);
    expect(campo.maxLines, isNull); // cresce com o texto
    expect(campo.expands, isTrue);
  });

  testWidgets('hino sem cifra abre com a letra pronta para marcar', (tester) async {
    await montar(tester);
    expect(textoDoCampo(tester), 'Primeira linha\n\nSegunda linha\nTerceira linha');
  });

  testWidgets('cifra existente abre com o ChordPro dela', (tester) async {
    const texto = '[G]Primeira linha\n\n[D7]Segunda linha\n[C]Terceira linha';
    await montar(tester, inicial: const CifraLocal(tom: 'G', texto: texto));
    expect(textoDoCampo(tester), texto);
    expect(find.text('G'), findsWidgets); // tom pré-selecionado no dropdown
  });

  // MIGRAÇÃO: a cifra no formato antigo abre já convertida — o usuário só
  // confirma e o que é gravado é o ChordPro (o toJson do formato novo não tem
  // campo legado: ver cifra_local_test).
  testWidgets('cifra no formato antigo abre convertida para ChordPro', (tester) async {
    final vm = await montar(
      tester,
      inicial: const CifraLocal(tom: 'G', acordesPorLinha: ['  G', 'D7']),
    );
    expect(textoDoCampo(tester), 'Pr[G]imeira linha\n\n[D7]Segunda linha\nTerceira linha');

    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    final salva = vm.cifraDe(hino.slug)!;
    expect(salva.texto, 'Pr[G]imeira linha\n\n[D7]Segunda linha\nTerceira linha');
    expect(salva.acordesPorLinha, isEmpty); // o objeto salvo já é o novo
  });

  testWidgets('salvar grava o ChordPro digitado no VM e volta', (tester) async {
    final vm = await montar(tester);
    await escolherTom(tester, 'D');
    await tester.enterText(
        find.byType(TextField),
        '[D]Primeira linha\n\n[D]Segunda linha\n[A]Terceira linha');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    final salva = vm.cifraDe(hino.slug)!;
    expect(salva.tom, 'D');
    expect(salva.texto, '[D]Primeira linha\n\n[D]Segunda linha\n[A]Terceira linha');
    expect(find.text('Cifra salva'), findsOneWidget); // SnackBar
    expect(find.text('abrir editor'), findsOneWidget); // rota fechada
  });

  testWidgets('sem nenhum acorde entre colchetes não salva', (tester) async {
    final vm = await montar(tester);
    await escolherTom(tester, 'D');
    // Só a letra: nada entre colchetes.
    await tester.enterText(find.byType(TextField), 'Primeira linha');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(vm.cifraDe(hino.slug), isNull);
    expect(find.text('Escolha o tom e escreva ao menos um acorde entre colchetes'),
        findsOneWidget);
    expect(find.text('abrir editor'), findsNothing); // editor segue aberto

    // Colchete que não é acorde: nota fora de A-G e '[' sem ']'.
    await tester.enterText(find.byType(TextField), '[x]Primeira linha [Am');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(vm.cifraDe(hino.slug), isNull);
  });

  testWidgets('sem tom o ChordPro sozinho não salva', (tester) async {
    final vm = await montar(tester);
    await tester.enterText(find.byType(TextField), '[Am]Primeira linha');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(vm.cifraDe(hino.slug), isNull);
    expect(find.text('abrir editor'), findsNothing); // editor segue aberto
  });

  testWidgets('remover: cancelar mantém, confirmar apaga e volta', (tester) async {
    final vm = await montar(
        tester, inicial: const CifraLocal(tom: 'D', texto: '[D]Primeira linha'));
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
