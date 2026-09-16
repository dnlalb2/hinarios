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
