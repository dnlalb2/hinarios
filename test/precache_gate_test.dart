// test/precache_gate_test.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hinarios_app/data/services/precache_service.dart';
import 'package:hinarios_app/ui/core/precache_view_model.dart';
import 'package:hinarios_app/ui/core/widgets/precache_gate.dart';

/// Mesmo serviço de mentira do teste do view model, reduzido ao que a tela
/// precisa: o "cache" já tem [emCache] assets e os downloads completam quando o
/// teste solta — é assim que a tela é flagrada no meio do caminho.
class _ServicoFalso implements PrecacheService {
  _ServicoFalso({this.emCache = 0, this.completarAte = -1});

  int emCache;

  /// Quantos pedidos completam sozinhos; do limite em diante ficam presos até
  /// [deixarPassar]. -1 = nenhum preso.
  int completarAte;

  int _sucessos = 0;
  Completer<void>? _trava;

  @override
  Future<int> arquivosEmCache() async => emCache;

  @override
  bool get online => true;

  @override
  Future<void> baixar(String caminho) async {
    if (completarAte >= 0 && _sucessos >= completarAte) {
      await (_trava ??= Completer<void>()).future;
    }
    _sucessos++;
  }

  /// Solta o que estava preso e deixa [quantos] pedidos completarem antes de
  /// congelar de novo (-1 = não congela mais).
  void deixarPassar([int quantos = -1]) {
    _trava?.complete();
    _trava = null;
    completarAte = quantos < 0 ? -1 : _sucessos + quantos;
  }
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
    final servico = _ServicoFalso(emCache: 10, completarAte: 0);
    final vm = PrecacheViewModel(service: servico);
    final download = vm.iniciar();
    await tester.pump();
    await tester.pumpWidget(_app(vm));

    // O app de verdade está montado embaixo, mas fora de alcance.
    expect(find.text('BIBLIOTECA'), findsOneWidget);
    expect(find.text('Preparando o hinário para uso offline…'), findsOneWidget);
    expect(find.text('10 de ${vm.total} arquivos'), findsOneWidget);
    expect(find.text('Continuar sem baixar'), findsOneWidget);
    final barra = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator));
    expect(barra.value, 10 / vm.total);

    // O progresso anda enquanto a tela está na frente: mais 500 chegaram.
    servico.deixarPassar(500);
    await tester.pump();
    expect(find.text('510 de ${vm.total} arquivos'), findsOneWidget);
    final meio = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator));
    expect(meio.value, 510 / vm.total);

    // Terminou: a tela de preparação sai da frente sozinha.
    servico.deixarPassar();
    await download;
    await tester.pump();
    expect(find.text('Preparando o hinário para uso offline…'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('BIBLIOTECA'), findsOneWidget);
    vm.dispose();
  });

  testWidgets('"continuar sem baixar" fecha a tela na hora',
      (tester) async {
    final servico = _ServicoFalso(emCache: 3, completarAte: 0);
    final vm = PrecacheViewModel(service: servico);
    final download = vm.iniciar();
    await tester.pump();
    await tester.pumpWidget(_app(vm));

    await tester.tap(find.text('Continuar sem baixar'));
    await tester.pump();

    expect(find.text('Preparando o hinário para uso offline…'), findsNothing);
    expect(find.text('BIBLIOTECA'), findsOneWidget);

    // A tela sai, o download continua até o fim.
    servico.deixarPassar();
    await download;
    expect(vm.baixados, vm.total);
    await tester.pumpWidget(const SizedBox()); // desmonta antes de descartar
    vm.dispose();
  });

  testWidgets('acervo completo: nenhuma tela de preparação é montada',
      (tester) async {
    final servico = _ServicoFalso(emCache: 5000);
    final vm = PrecacheViewModel(service: servico);
    await vm.iniciar();
    await tester.pumpWidget(_app(vm));

    expect(find.text('Preparando o hinário para uso offline…'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('BIBLIOTECA'), findsOneWidget);
    vm.dispose();
  });
}
