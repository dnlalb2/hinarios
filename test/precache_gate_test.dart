// test/precache_gate_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hinarios_app/data/services/precache_service.dart';
import 'package:hinarios_app/ui/core/precache_view_model.dart';
import 'package:hinarios_app/ui/core/widgets/precache_gate.dart';

/// Mesmo serviço de mentira do teste do view model: o cache é um número que o
/// teste controla e o download é simulado mexendo nele.
class _ServicoFalso implements PrecacheService {
  _ServicoFalso({this.emCache = 0});

  int emCache;
  int pedidos = 0;

  @override
  Future<int> arquivosEmCache() async => emCache;

  @override
  bool get online => true;

  @override
  void solicitar() => pedidos++;
}

Widget _app(PrecacheViewModel vm) => ChangeNotifierProvider<PrecacheViewModel>.value(
      value: vm,
      child: const MaterialApp(
        home: PrecacheGate(child: Scaffold(body: Text('BIBLIOTECA'))),
      ),
    );

void main() {
  testWidgets('cobre a biblioteca com o progresso enquanto o acervo baixa',
      (tester) async {
    final servico = _ServicoFalso(emCache: 10);
    final vm = PrecacheViewModel(
      service: servico,
      intervalo: const Duration(seconds: 1),
    );
    await vm.iniciar();
    await tester.pumpWidget(_app(vm));

    // O app de verdade está montado embaixo, mas fora de alcance.
    expect(find.text('BIBLIOTECA'), findsOneWidget);
    expect(find.text('Preparando o hinário para uso offline…'), findsOneWidget);
    expect(find.text('10 de ${vm.total} arquivos'), findsOneWidget);
    expect(find.text('Continuar sem baixar'), findsOneWidget);
    final barra = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator));
    expect(barra.value, 10 / vm.total);
    expect(servico.pedidos, 1);

    // O progresso acompanha o download.
    servico.emCache = 500;
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('500 de ${vm.total} arquivos'), findsOneWidget);

    // Terminou: a tela de preparação sai da frente sozinha.
    servico.emCache = vm.total;
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Preparando o hinário para uso offline…'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('BIBLIOTECA'), findsOneWidget);
    vm.dispose();
  });

  testWidgets('"continuar sem baixar" fecha a tela na hora',
      (tester) async {
    final servico = _ServicoFalso(emCache: 3);
    final vm = PrecacheViewModel(
      service: servico,
      intervalo: const Duration(seconds: 1),
    );
    await vm.iniciar();
    await tester.pumpWidget(_app(vm));

    await tester.tap(find.text('Continuar sem baixar'));
    await tester.pump();

    expect(find.text('Preparando o hinário para uso offline…'), findsNothing);
    expect(find.text('BIBLIOTECA'), findsOneWidget);

    // A tela sai, o download continua.
    servico.emCache = 900;
    await tester.pump(const Duration(seconds: 1));
    expect(vm.baixados, 900);
    await tester.pumpWidget(const SizedBox()); // desmonta antes de descartar
    vm.dispose();
  });

  testWidgets('acervo completo: nenhuma tela de preparação é montada',
      (tester) async {
    final servico = _ServicoFalso(emCache: 5000);
    final vm = PrecacheViewModel(
      service: servico,
      intervalo: const Duration(seconds: 1),
    );
    await vm.iniciar();
    await tester.pumpWidget(_app(vm));

    expect(find.text('Preparando o hinário para uso offline…'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('BIBLIOTECA'), findsOneWidget);
    vm.dispose();
  });
}
