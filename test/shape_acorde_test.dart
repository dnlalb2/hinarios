// test/shape_acorde_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinarios_app/ui/features/hino/diagrama_acorde.dart';
import 'package:hinarios_app/ui/features/hino/shape_acorde_sheet.dart';

void main() {
  Widget appComBotao(String acorde) => MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => abrirShapeAcorde(context, acorde),
              child: const Text('abrir'),
            ),
          ),
        ),
      );

  String titulo(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('acorde-titulo'))).data!;

  testWidgets('mostra o nome, o diagrama e o crédito', (tester) async {
    await tester.pumpWidget(appComBotao('Am'));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(titulo(tester), 'Am');
    expect(find.byType(DiagramaAcorde), findsOneWidget);
    expect(find.text('Posições: chords-db (MIT)'), findsOneWidget);
    // Sem segunda posição não há seta de troca? Há: o acervo traz até 2.
    expect(find.text('1/2'), findsOneWidget);
  });

  testWidgets('acorde fora do acervo mostra o aviso, sem diagrama', (tester) async {
    await tester.pumpWidget(appComBotao('Dn'));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(titulo(tester), 'Dn');
    expect(find.text('Posição não disponível para este acorde'), findsOneWidget);
    expect(find.byType(DiagramaAcorde), findsNothing);
  });

  testWidgets('duas posições: as setas trocam o desenho', (tester) async {
    await tester.pumpWidget(appComBotao('Am'));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    final primeira = tester.widget<DiagramaAcorde>(find.byType(DiagramaAcorde)).shape;
    expect(find.text('1/2'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    expect(find.text('2/2'), findsOneWidget);
    final segunda = tester.widget<DiagramaAcorde>(find.byType(DiagramaAcorde)).shape;
    expect(segunda.frets, isNot(primeira.frets)); // outro desenho de verdade

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump();
    expect(find.text('1/2'), findsOneWidget);
    expect(tester.widget<DiagramaAcorde>(find.byType(DiagramaAcorde)).shape.frets,
        primeira.frets);
  });

  // O acorde da cifra chega transposto ('D/F#') ou em variante do vocabulário
  // ('Bm7/5-'): os dois têm que achar o desenho certo no acervo.
  testWidgets('acorde com baixo invertido acha o shape', (tester) async {
    await tester.pumpWidget(appComBotao('D/F#'));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(titulo(tester), 'D/F#');
    expect(find.byType(DiagramaAcorde), findsOneWidget);
  });

  testWidgets('variante de meio-diminuto acha o shape', (tester) async {
    await tester.pumpWidget(appComBotao('Bm7/5-'));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(titulo(tester), 'Bm7/5-');
    expect(find.byType(DiagramaAcorde), findsOneWidget);
    expect(find.text('Posição não disponível para este acorde'), findsNothing);
  });
}
