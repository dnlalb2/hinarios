// lib/ui/core/instalacao_view_model.dart
import 'package:flutter/foundation.dart';

import '../../data/services/instalacao_service.dart';

/// Estado do banner "instale o app na tela inicial".
///
/// O hinário é usado no salão, muitas vezes sem rede: aberto do atalho, o PWA
/// abre offline e em tela cheia. O banner só aparece quando há o que oferecer —
/// instalação disponível (Android/Chrome) ou iPhone, onde o caminho é manual.
class InstalacaoViewModel extends ChangeNotifier {
  InstalacaoViewModel({InstalacaoService? service})
      : _service = service ?? InstalacaoService.instancia;

  final InstalacaoService _service;

  /// O usuário não quer mais ver o banner nesta visita. Sem persistir: numa
  /// próxima abertura o convite volta (a menos que ele já tenha instalado).
  bool _dispensado = false;

  /// O usuário aceitou o prompt nativo. O `jaInstalado` do navegador só vira
  /// true na próxima abertura (do atalho): sem esta marca o banner ficaria
  /// pedindo para instalar o que acabou de ser instalado.
  bool _instalou = false;

  /// Foi descartado? Um aviso do navegador pode chegar depois da tela sair.
  bool _descartado = false;

  /// O aparelho é iOS: não há prompt nativo, o banner vira instrução.
  bool get ehIos => _service.ehIos;

  /// O navegador já avisou que dá para instalar (Android/Chrome).
  bool get pronto => _service.pronto;

  /// O banner deve aparecer?
  bool get mostrarBanner =>
      !_dispensado &&
      !_instalou &&
      !_service.jaInstalado &&
      (_service.pronto || _service.ehIos);

  /// Liga o aviso do serviço ao rebuild: quando o navegador avisa que dá para
  /// instalar, o banner aparece sozinho. Chamada uma vez, no boot.
  void iniciar() {
    _service.registrar(_notificar);
  }

  /// O usuário fechou o banner — some até a próxima abertura do app.
  void dispensar() {
    if (_dispensado) return;
    _dispensado = true;
    _notificar();
  }

  /// Abre o prompt nativo. Aceito, o banner sai: a instalação está a caminho.
  /// Recusado (ou sem prompt disponível), ele fica — dá para tentar de novo.
  Future<void> instalar() async {
    if (await _service.instalar()) {
      _instalou = true;
      _notificar();
    }
  }

  /// Notifica só enquanto o view model está vivo.
  void _notificar() {
    if (_descartado) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    super.dispose();
  }
}
