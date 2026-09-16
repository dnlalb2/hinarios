// test/instalacao_view_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hinarios_app/data/services/instalacao_service.dart';
import 'package:hinarios_app/ui/core/instalacao_view_model.dart';

/// Serviço de mentira: o teste escolhe o estado do aparelho e o que o usuário
/// responde ao prompt nativo. O módulo real é condicional (web/stub) e não dá
/// para trocar num teste de VM — esta classe dá.
class InstalacaoServiceFalso implements InstalacaoService {
  InstalacaoServiceFalso({
    this.jaInstalado = false,
    this.pronto = false,
    this.ehIos = false,
    this.aceitaInstalar = true,
  });

  @override
  bool jaInstalado;

  @override
  bool pronto;

  @override
  bool ehIos;

  /// O que o usuário responde ao prompt: aceita (true) ou recusa (false).
  bool aceitaInstalar;

  /// Quantas vezes o botão 'Instalar' chegou ao serviço.
  int pedidos = 0;

  /// Callback registrado pelo view model — o teste o dispara à mão para
  /// simular o `beforeinstallprompt` chegando depois do boot.
  void Function()? aoAtualizar;

  /// O navegador avisou que dá para instalar — depois do registro, como
  /// acontece de verdade (o evento chega quando o Chrome decide).
  void ficarPronto() {
    pronto = true;
    aoAtualizar?.call();
  }

  @override
  void registrar(void Function() aoAtualizar) {
    this.aoAtualizar = aoAtualizar;
    if (pronto) aoAtualizar();
  }

  @override
  Future<bool> instalar() async {
    pedidos++;
    return aceitaInstalar;
  }
}

void main() {
  test('Android com instalação disponível: banner aparece', () {
    final vm = InstalacaoViewModel(
        service: InstalacaoServiceFalso(pronto: true));

    expect(vm.mostrarBanner, isTrue);
    expect(vm.pronto, isTrue);
    expect(vm.ehIos, isFalse);
  });

  test('iOS (sem prompt nativo): banner de instruções aparece', () {
    final vm = InstalacaoViewModel(service: InstalacaoServiceFalso(ehIos: true));

    expect(vm.mostrarBanner, isTrue);
    expect(vm.ehIos, isTrue);
    // No iOS não há botão: a instalação é manual, pelo menu Compartilhar.
    expect(vm.pronto, isFalse);
  });

  test('sem aviso do navegador (desktop comum): nada aparece', () {
    final vm = InstalacaoViewModel(service: InstalacaoServiceFalso());

    expect(vm.mostrarBanner, isFalse);
  });

  test('app já instalado: nada aparece', () {
    final vm = InstalacaoViewModel(
        service: InstalacaoServiceFalso(jaInstalado: true, pronto: true));

    expect(vm.mostrarBanner, isFalse);
  });

  test('iniciar() registra o aviso: o banner aparece quando ele chega', () {
    final servico = InstalacaoServiceFalso();
    final vm = InstalacaoViewModel(service: servico);
    var avisos = 0;
    vm.addListener(() => avisos++);

    vm.iniciar();
    expect(vm.mostrarBanner, isFalse);

    servico.ficarPronto();
    expect(vm.mostrarBanner, isTrue);
    expect(avisos, 1);
  });

  test('iniciar() com o aviso já chegado avisa na hora', () {
    final vm = InstalacaoViewModel(
        service: InstalacaoServiceFalso(pronto: true));
    var avisos = 0;
    vm.addListener(() => avisos++);

    vm.iniciar();

    expect(avisos, 1);
    expect(vm.mostrarBanner, isTrue);
  });

  test('dispensar() esconde o banner', () {
    final vm = InstalacaoViewModel(
        service: InstalacaoServiceFalso(pronto: true));

    vm.dispensar();

    expect(vm.mostrarBanner, isFalse);
  });

  test('instalação aceita esconde o banner', () async {
    final servico = InstalacaoServiceFalso(pronto: true);
    final vm = InstalacaoViewModel(service: servico);

    await vm.instalar();

    expect(servico.pedidos, 1);
    expect(vm.mostrarBanner, isFalse);
  });

  test('instalação recusada mantém o banner', () async {
    final servico =
        InstalacaoServiceFalso(pronto: true, aceitaInstalar: false);
    final vm = InstalacaoViewModel(service: servico);

    await vm.instalar();

    expect(servico.pedidos, 1);
    expect(vm.mostrarBanner, isTrue);
  });

  test('fora da web (stub) nada quebra e o banner não aparece', () async {
    // Sem serviço injetado: cai no módulo condicional, que fora da web é o
    // stub — não existe atalho de PWA para oferecer.
    final vm = InstalacaoViewModel();

    vm.iniciar();
    expect(vm.mostrarBanner, isFalse);
    expect(vm.ehIos, isFalse);
    expect(vm.pronto, isFalse);

    await vm.instalar();
    expect(vm.mostrarBanner, isFalse);

    vm.dispensar(); // idempotente no stub também
    expect(vm.mostrarBanner, isFalse);
  });

  test('aviso do serviço depois do dispose não notifica', () {
    final servico = InstalacaoServiceFalso();
    final vm = InstalacaoViewModel(service: servico);
    vm.iniciar();
    vm.dispose();

    // O evento pode chegar depois da tela sair; notificar um
    // ChangeNotifier descartado lançaria.
    servico.ficarPronto();
  });
}
