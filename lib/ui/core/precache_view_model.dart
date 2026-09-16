// lib/ui/core/precache_view_model.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../data/services/precache_service.dart';

/// Progresso do download offline do primeiro acesso.
///
/// O service worker baixa o acervo inteiro (1025 partituras + acordes + dados,
/// ~13 MB) em segundo plano, fora do isolate da UI. Sem uma tela dizendo que
/// algo está acontecendo, o usuário fecha a página no meio e fica com um
/// offline pela metade. O DENOMINADOR sai do AssetManifest — o que o app
/// espera ter em cache — e o NUMERADOR, do próprio cache do service worker.
class PrecacheViewModel extends ChangeNotifier {
  PrecacheViewModel({
    required PrecacheService service,
    this.intervalo = const Duration(seconds: 1),
  }) : _service = service;

  final PrecacheService _service;

  /// De quanto em quanto tempo o cache é reconferido.
  final Duration intervalo;

  int _baixados = 0;
  int _total = 0;
  bool _completo = false;
  bool _dispensado = false;
  bool _iniciado = false;
  bool _decidido = false;
  bool _descartado = false;
  Timer? _timer;

  /// Arquivos do acervo que já estão no cache.
  int get baixados => _baixados;

  /// Arquivos que o acervo tem ao todo (0 = ainda não calculado).
  int get total => _total;

  /// Acabou: o download terminou, ou nem se aplica (fora da web, sem rede ou
  /// com o cache já cheio). Nos três casos não há o que esperar.
  bool get completo => _completo;

  /// O usuário tocou em "continuar sem baixar" — usa o app agora; o download
  /// continua no service worker e o cache segue enchendo.
  bool get dispensado => _dispensado;

  /// A tela de preparação deve cobrir o app?
  ///
  /// Só depois da primeira leitura e só se HOUVER o que baixar ([_decidido]):
  /// antes de saber o total a tela mostraria "0 de 0 arquivos" com barra
  /// indefinida, e numa reabertura com o cache cheio ela chegaria a piscar por
  /// um quadro antes do "já está tudo aqui". Quem não tem nada a esperar não
  /// vê preparação nenhuma — nem de relance.
  bool get mostrar => _decidido && !_completo && !_dispensado;

  /// Primeira leitura do cache, e então o pedido de download ao service worker
  /// seguido de uma conferida periódica. Chamada uma vez só (repetir é no-op).
  Future<void> iniciar() async {
    if (_iniciado) return;
    _iniciado = true;
    try {
      final emCache = await _service.arquivosEmCache();
      if (emCache < 0) {
        // Fora da web não existe cache de service worker a aquecer.
        _concluir();
        return;
      }
      _baixados = emCache;
      _total = await _totalDoAcervo();
      // Cache já cheio (reabertura depois do primeiro acesso): nada a baixar.
      // Conclui ANTES de qualquer notify — nada de a tela de preparação
      // piscar para quem já tem tudo.
      if (emCache >= _total) {
        _concluir();
        return;
      }
      // Sem rede não há o que baixar: bloquear o app só pioraria.
      if (!_service.online) {
        _concluir();
        return;
      }
      // Há o que baixar: agora sim a tela de preparação entra, já com números
      // de verdade ("5 de 1027").
      _decidido = true;
      _notificar();
      _service.solicitar();
      _timer = Timer.periodic(intervalo, (_) => _atualizar());
    } catch (_) {
      // Falha inesperada (cache inacessível, manifesto ilegível): melhor abrir
      // o app do que prender o usuário numa preparação eterna.
      _concluir();
    }
  }

  /// O usuário prefere usar o app agora: tira a tela, deixa o download rolando.
  void continuarSemBaixar() {
    if (_dispensado) return;
    _dispensado = true;
    _notificar();
  }

  /// Um tick do timer: relê o cache e conclui quando alcança o total.
  Future<void> _atualizar() async {
    int arquivos;
    try {
      arquivos = await _service.arquivosEmCache();
    } catch (_) {
      _concluir();
      return;
    }
    if (_descartado) return;
    _baixados = arquivos;
    if (arquivos >= _total) {
      _concluir();
      return;
    }
    _notificar();
  }

  void _concluir() {
    _timer?.cancel();
    _timer = null;
    _completo = true;
    _notificar();
  }

  /// Notifica só enquanto o view model está vivo — um tick do timer pode
  /// voltar depois do dispose (a tela foi embora com o app aberto).
  void _notificar() {
    if (_descartado) return;
    notifyListeners();
  }

  /// Quantos arquivos o acervo offline tem: as partituras do AssetManifest
  /// mais os dois JSONs que o app busca no boot.
  static Future<int> _totalDoAcervo() async {
    final manifesto = await AssetManifest.loadFromAssetBundle(rootBundle);
    final partituras = manifesto
        .listAssets()
        .where((a) => a.startsWith('assets/partituras/') && a.endsWith('.svg'))
        .length;
    return partituras + 2; // acordes.json + dados.json
  }

  @override
  void dispose() {
    _descartado = true;
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}
