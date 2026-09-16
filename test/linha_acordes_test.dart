// test/linha_acordes_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinarios_app/ui/core/widgets/linha_acordes.dart';
import 'package:hinarios_app/ui/features/hino/diagrama_acorde.dart';
import 'package:hinarios_app/ui/features/hino/shape_acorde_sheet.dart';

void main() {
  Widget montar(String texto) => MaterialApp(
        home: Scaffold(
          body: LinhaAcordes(
            texto: texto,
            estilo: const TextStyle(fontFamily: 'monospace', fontSize: 20),
          ),
        ),
      );

  testWidgets('o texto puro da linha continua idêntico (espaços incluídos)', (tester) async {
    // As colunas são o que põe o acorde sobre a sílaba: um TextSpan por token
    // não pode mudar UM espaço da linha.
    await tester.pumpWidget(montar('  D Bm   A7'));
    expect(find.text('  D Bm   A7'), findsOneWidget);
  });

  testWidgets('tocar num acorde abre a folha do acorde tocado', (tester) async {
    await tester.pumpWidget(montar('D Bm'));
    await tester.tapOnText(find.textRange.ofSubstring('Bm'));
    await tester.pumpAndSettle();

    expect(tester.widget<Text>(find.byKey(chaveTituloAcorde)).data, 'Bm');
    expect(find.byType(DiagramaAcorde), findsOneWidget);
  });

  // Cifra que não cabe na largura quebra em duas linhas: o vazio à direita da
  // primeira (que a caixa do Text ocupa — a caixa tem a largura da coluna, não
  // a da linha) não é acorde nenhum. A posição do toque é clampada ao FIM da
  // linha: sem conferir que o dedo está sobre os glifos, tocar no branco abriria
  // a folha do acorde que termina ali.
  testWidgets('tocar no vazio depois do fim de uma linha quebrada não abre', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 100, // 5 colunas: 'D Bm A D' quebra
            child: LinhaAcordes(
              texto: 'D Bm A D',
              estilo: const TextStyle(fontFamily: 'monospace', fontSize: 20),
            ),
          ),
        ),
      ),
    ));

    final caixa = tester.getRect(find.text('D Bm A D'));
    expect(caixa.height, greaterThan(20)); // quebrou mesmo, duas linhas
    // A caixa tem a largura do bloco: a 2ª linha ('A D') acaba em 60 e o resto
    // da caixa, até 100, é branco — e a posição do toque ali é clampada para o
    // FIM do texto, que é o 'D' final.
    await tester.tapAt(Offset(caixa.right - 3, caixa.bottom - 5));
    await tester.pumpAndSettle();
    expect(find.byKey(chaveTituloAcorde), findsNothing);

    // A 2ª linha continua tocável: o alvo é o acorde, não o branco.
    await tester.tapOnText(find.textRange.ofSubstring('A'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(chaveTituloAcorde)).data, 'A');
  });

  // Cifra digitada à mão traz de tudo ('2ªvez', '1ª', anotações): o que não
  // começa com nota não é acorde e não pode abrir folha nenhuma.
  testWidgets('token que não é acorde não é tocável', (tester) async {
    await tester.pumpWidget(montar('D 2ªvez'));
    await tester.tapOnText(find.textRange.ofSubstring('2ªvez'));
    await tester.pumpAndSettle();

    expect(find.byKey(chaveTituloAcorde), findsNothing);
    expect(find.byType(DiagramaAcorde), findsNothing);
  });

  // A linha é reconstruída a cada rebuild (transposição, tema, fonte): o texto
  // novo tem que ser o tocável — e o velho, não.
  testWidgets('depois de trocar o texto, só o acorde novo responde', (tester) async {
    await tester.pumpWidget(montar('D Bm'));
    await tester.pumpWidget(montar('D# Cm'));
    expect(find.text('D Bm'), findsNothing);

    await tester.tapOnText(find.textRange.ofSubstring('Cm'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(chaveTituloAcorde)).data, 'Cm');
  });
}
