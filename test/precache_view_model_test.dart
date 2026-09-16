// test/precache_view_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hinarios_app/data/services/precache_service.dart';
import 'package:hinarios_app/ui/core/precache_view_model.dart';

/// Serviço de mentira: o "cache do service worker" é um contador que o teste
/// controla e o download em andamento é simulado mexendo nele entre um tick e
/// outro do timer. [leituras] conta quantas vezes o cache foi consultado —
/// é por ele que se vê o timer parado depois de concluir.
class _ServicoFalso implements PrecacheService {
  _ServicoFalso({this.emCache = 0, this.estaOnline = true});

  int emCache;
  bool estaOnline;
  bool falhar = false;
  int pedidos = 0;
  int leituras = 0;

  @override
  Future<int> arquivosEmCache() async {
    leituras++;
    if (falhar) throw StateError('cache inacessível');
    return emCache;
  }

  @override
  bool get online => estaOnline;

  @override
  void solicitar() => pedidos++;
}

PrecacheViewModel _vm(_ServicoFalso servico) => PrecacheViewModel(
      service: servico,
      intervalo: const Duration(seconds: 1),
    );

void main() {
  testWidgets('mostra o progresso, avança a cada tick e conclui no total',
      (tester) async {
    final servico = _ServicoFalso(emCache: 5);
    final vm = _vm(servico);
    var avisos = 0;
    vm.addListener(() => avisos++);

    // Sem saber ainda o que falta, não há tela nenhuma (nem a de "0 de 0").
    expect(vm.mostrar, isFalse);
    await vm.iniciar();

    // Primeira leitura na hora: o cache já tinha 5 arquivos do acervo.
    expect(vm.baixados, 5);
    expect(vm.total, greaterThan(1000)); // 1025 partituras + acordes + dados
    expect(vm.mostrar, isTrue);
    expect(servico.pedidos, 1); // pediu o download ao service worker
    expect(avisos, greaterThan(0)); // a tela acorda com o número novo

    // O service worker baixou mais um punhado: o próximo tick lê o número novo.
    servico.emCache = 42;
    await tester.pump(const Duration(seconds: 1));
    expect(vm.baixados, 42);
    expect(vm.mostrar, isTrue);
    expect(vm.completo, isFalse);

    // Bateu o total: a tela sai sozinha.
    servico.emCache = vm.total;
    await tester.pump(const Duration(seconds: 1));
    expect(vm.completo, isTrue);
    expect(vm.mostrar, isFalse);

    // E o timer para: nada mais consulta o cache.
    final leiturasAoConcluir = servico.leituras;
    await tester.pump(const Duration(seconds: 3));
    expect(servico.leituras, leiturasAoConcluir);
    vm.dispose();
  });

  testWidgets('cache já cheio: nem pisca, nem pede download de novo',
      (tester) async {
    // Reabertura depois do primeiro acesso: o acervo inteiro já está no cache.
    final servico = _ServicoFalso(emCache: 5000);
    final vm = _vm(servico);

    // Nem antes da leitura: sem total não há o que mostrar, e mostrar "0 de 0"
    // por um quadro seria pior que não mostrar nada.
    expect(vm.mostrar, isFalse);
    await vm.iniciar();

    expect(vm.completo, isTrue);
    expect(vm.mostrar, isFalse);
    expect(servico.pedidos, 0);
    vm.dispose();
  });

  testWidgets('offline: libera o app na hora e não pede download',
      (tester) async {
    final servico = _ServicoFalso(emCache: 0, estaOnline: false);
    final vm = _vm(servico);

    await vm.iniciar();

    expect(vm.completo, isTrue);
    expect(vm.mostrar, isFalse);
    expect(servico.pedidos, 0);
    expect(servico.leituras, 1); // não fica consultando o cache à toa
    vm.dispose();
  });

  testWidgets('fora da web (-1): a pergunta não se aplica, libera o app',
      (tester) async {
    final servico = _ServicoFalso(emCache: -1);
    final vm = _vm(servico);

    await vm.iniciar();

    expect(vm.completo, isTrue);
    expect(vm.mostrar, isFalse);
    expect(servico.pedidos, 0);
    expect(servico.leituras, 1);
    vm.dispose();
  });

  testWidgets('continuar sem baixar tira a tela e deixa o download seguir',
      (tester) async {
    final servico = _ServicoFalso(emCache: 0);
    final vm = _vm(servico);
    await vm.iniciar();
    expect(vm.mostrar, isTrue);

    vm.continuarSemBaixar();

    expect(vm.dispensado, isTrue);
    expect(vm.mostrar, isFalse);

    // O service worker não foi interrompido: o cache continua enchendo.
    final leiturasAntes = servico.leituras;
    servico.emCache = 100;
    await tester.pump(const Duration(seconds: 1));
    expect(servico.leituras, greaterThan(leiturasAntes));
    expect(vm.baixados, 100);
    vm.dispose();
  });

  testWidgets('falha na leitura do cache não prende o usuário na preparação',
      (tester) async {
    final servico = _ServicoFalso()..falhar = true;
    final vm = _vm(servico);

    await vm.iniciar();

    expect(vm.completo, isTrue);
    expect(vm.mostrar, isFalse);
    vm.dispose();
  });
}
