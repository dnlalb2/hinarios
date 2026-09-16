// test/precache_view_model_test.dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hinarios_app/data/services/precache_service.dart';
import 'package:hinarios_app/ui/core/precache_view_model.dart';

/// Serviço de mentira: o "download" é uma lista em memória e o teste decide
/// quantos pedidos completam sozinhos — do limite em diante eles ficam presos
/// num completer, que é como se olha o download em voo (e a concorrência).
class _ServicoFalso implements PrecacheService {
  _ServicoFalso({
    this.emCache = 0,
    this.estaOnline = true,
    this.completarAte = -1,
  });

  int emCache;
  bool estaOnline;

  /// Quantos pedidos completam sozinhos; do [completarAte] em diante ficam
  /// presos até [deixarPassar]. -1 = nenhum preso.
  int completarAte;

  /// Assets que falham em todas as tentativas.
  final Set<String> quebrados = {};

  /// Assets que falham só na primeira tentativa (tropeço de rede).
  final Set<String> falhamUmaVez = {};

  /// Toda chave pedida, com repetição: as retentativas aparecem aqui.
  final List<String> chamadas = [];

  /// Pedidos em voo agora e o maior número que já esteve em voo de uma vez —
  /// é por ele que se vê a concorrência.
  int emVoo = 0;
  int picoEmVoo = 0;

  /// Cache inacessível: a leitura estoura em vez de devolver um número.
  bool cacheQuebrado = false;

  int _completas = 0;
  Completer<void>? _trava;

  @override
  Future<int> arquivosEmCache() async {
    if (cacheQuebrado) throw StateError('cache inacessível');
    return emCache;
  }

  @override
  bool get online => estaOnline;

  @override
  Future<void> baixar(String caminho) async {
    chamadas.add(caminho);
    emVoo++;
    if (emVoo > picoEmVoo) picoEmVoo = emVoo;
    try {
      if (completarAte >= 0 && _completas >= completarAte) {
        await (_trava ??= Completer<void>()).future;
      }
      if (quebrados.contains(caminho) || falhamUmaVez.remove(caminho)) {
        throw StateError('sem rede: $caminho');
      }
      _completas++;
    } finally {
      emVoo--;
    }
  }

  /// Solta o que estava preso e deixa [quantos] pedidos completarem antes de
  /// congelar de novo (-1 = não congela mais).
  void deixarPassar([int quantos = -1]) {
    _trava?.complete();
    _trava = null;
    completarAte = quantos < 0 ? -1 : _completas + quantos;
  }
}

void main() {
  testWidgets('mostra o progresso, avança a cada asset e conclui no fim',
      (tester) async {
    final servico = _ServicoFalso(emCache: 2, completarAte: 10);
    final vm = PrecacheViewModel(service: servico);
    var avisos = 0;
    vm.addListener(() => avisos++);

    // Sem saber ainda o que falta, não há tela nenhuma (nem a de "0 de 0").
    expect(vm.mostrar, isFalse);
    final download = vm.iniciar();
    await tester.pump();

    // Primeira leitura na hora: o cache já tinha 2 assets do acervo.
    expect(vm.total, greaterThan(1000)); // 1025 partituras + acordes + dados
    expect(vm.baixados, 12); // 2 de antes + 10 que chegaram
    expect(vm.mostrar, isTrue);
    expect(avisos, greaterThan(1)); // avisa a cada asset que chega
    // Concorrência 6: seis pedidos em voo, nenhum a mais agendado.
    expect(servico.picoEmVoo, 6);
    expect(servico.emVoo, 6);

    // Soltou: a fila drena e o progresso fecha no total.
    servico.deixarPassar();
    await download;
    expect(vm.baixados, vm.total);
    expect(vm.completo, isTrue);
    expect(vm.mostrar, isFalse);
    expect(vm.falhas, 0);
    expect(servico.chamadas.length, vm.total);
    vm.dispose();
  });

  testWidgets('cache já cheio: nem pisca, nem baixa de novo', (tester) async {
    // Reabertura depois do primeiro acesso: o acervo inteiro já está no cache.
    final servico = _ServicoFalso(emCache: 5000);
    final vm = PrecacheViewModel(service: servico);

    // Nem antes da leitura: sem total não há o que mostrar, e mostrar "0 de 0"
    // por um quadro seria pior que não mostrar nada.
    expect(vm.mostrar, isFalse);
    await vm.iniciar();

    expect(vm.completo, isTrue);
    expect(vm.mostrar, isFalse);
    expect(servico.chamadas, isEmpty);
    vm.dispose();
  });

  testWidgets('offline: libera o app na hora e não baixa nada', (tester) async {
    final servico = _ServicoFalso(emCache: 0, estaOnline: false);
    final vm = PrecacheViewModel(service: servico);

    await vm.iniciar();

    expect(vm.completo, isTrue);
    expect(vm.mostrar, isFalse);
    expect(servico.chamadas, isEmpty);
    vm.dispose();
  });

  testWidgets('fora da web (-1): a pergunta não se aplica, libera o app',
      (tester) async {
    final servico = _ServicoFalso(emCache: -1);
    final vm = PrecacheViewModel(service: servico);

    await vm.iniciar();

    expect(vm.completo, isTrue);
    expect(vm.mostrar, isFalse);
    expect(servico.chamadas, isEmpty);
    vm.dispose();
  });

  testWidgets('continuar sem baixar tira a tela e deixa o download seguir',
      (tester) async {
    final servico = _ServicoFalso(emCache: 0, completarAte: 10);
    final vm = PrecacheViewModel(service: servico);
    final download = vm.iniciar();
    await tester.pump();
    expect(vm.mostrar, isTrue);

    vm.continuarSemBaixar();

    expect(vm.dispensado, isTrue);
    expect(vm.mostrar, isFalse);

    // O download não foi interrompido: o que estava em voo chegou e a fila
    // seguiu até o fim.
    servico.deixarPassar();
    await download;
    expect(vm.baixados, vm.total);
    expect(vm.completo, isTrue);
    vm.dispose();
  });

  testWidgets('asset que falha não para a fila: tenta 3 vezes e conta a falha',
      (tester) async {
    final servico = _ServicoFalso(emCache: 0)
      ..quebrados.add('assets/dados.json');
    final vm = PrecacheViewModel(service: servico);

    final download = vm.iniciar();
    // As retentativas esperam entre uma tentativa e outra: sem tempo no relógio
    // falso a fila não drena.
    await tester.pump(const Duration(seconds: 1));
    await download;

    expect(vm.completo, isTrue); // a falha não prende o usuário na preparação
    expect(vm.mostrar, isFalse);
    expect(vm.baixados, vm.total - 1); // tudo menos o que falhou
    expect(vm.falhas, 1);
    expect(vm.falhados, ['assets/dados.json']);
    // Uma tentativa e duas retentativas, e o resto da fila seguiu baixando.
    expect(servico.chamadas.where((c) => c == 'assets/dados.json').length, 3);
    expect(servico.chamadas.length, vm.total + 2);
    vm.dispose();
  });

  testWidgets('tropeço de rede: a retentativa resolve e não conta falha',
      (tester) async {
    final servico = _ServicoFalso(emCache: 0)
      ..falhamUmaVez.add('assets/acordes.json');
    final vm = PrecacheViewModel(service: servico);

    final download = vm.iniciar();
    await tester.pump(const Duration(seconds: 1));
    await download;

    expect(vm.completo, isTrue);
    expect(vm.baixados, vm.total);
    expect(vm.falhas, 0);
    expect(servico.chamadas.where((c) => c == 'assets/acordes.json').length, 2);
    vm.dispose();
  });

  testWidgets('dispose no meio: para de agendar e não avisa mais nada',
      (tester) async {
    final servico = _ServicoFalso(emCache: 0, completarAte: 0); // tudo preso
    final vm = PrecacheViewModel(service: servico);
    var avisos = 0;
    vm.addListener(() => avisos++);

    final download = vm.iniciar();
    await tester.pump();
    expect(vm.mostrar, isTrue);
    expect(servico.chamadas.length, 6); // seis em voo, presos
    expect(vm.baixados, 0);

    vm.dispose();
    final avisosAoDescartar = avisos;

    // Os que estavam em voo terminam em silêncio e nenhum novo é agendado.
    servico.deixarPassar();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await download;

    expect(servico.chamadas.length, 6);
    expect(vm.baixados, 0);
    expect(avisos, avisosAoDescartar);
  });

  testWidgets('falha na leitura do cache não prende o usuário na preparação',
      (tester) async {
    final servico = _ServicoFalso()..cacheQuebrado = true;
    final vm = PrecacheViewModel(service: servico);

    await vm.iniciar();

    expect(vm.completo, isTrue);
    expect(vm.mostrar, isFalse);
    vm.dispose();
  });
}
