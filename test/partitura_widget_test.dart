// test/partitura_widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hinarios_app/data/services/preferencias_service.dart';
import 'package:hinarios_app/domain/models/hino.dart';
import 'package:hinarios_app/ui/core/preferencias_view_model.dart';
import 'package:hinarios_app/ui/core/widgets/bloco_hino.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final hino = Hino(
    slug: 'adalia-grangeiro/1/tao-limpo-e-este-caminho',
    num: 1, nome: 'Tão limpo é este caminho', autor: 'Adália Grangeiro',
    autorFull: 'Adália Grangeiro', hinario: 'Viagem', urlhinario: 'viagem',
    ritmo: 'valsa', letra: 'Tão limpo é este caminho',
    cifra: Cifra(tom: 'Am', texto: 'Am E7; A7 Dm'),
    abc: 'X:1\nM:4/4\nK:Am\nA,2 |',
  );

  testWidgets('ícone abre dialog com a partitura', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final vm = PreferenciasViewModel(service: PreferenciasService());
    await vm.restaurar();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: vm,
        child: MaterialApp(home: Scaffold(body: BlocoHino(hino: hino))),
      ),
    );
    await tester.tap(find.byIcon(Icons.music_note));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byType(SvgPicture), findsOneWidget);

    // A partitura é preta sobre transparência: precisa de uma "folha" branca
    // atrás do SVG para não sumir no tema escuro.
    expect(
      find.ancestor(
        of: find.byType(SvgPicture),
        matching: find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == Colors.white,
        ),
      ),
      findsOneWidget,
    );
  });
}
