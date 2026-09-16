// lib/ui/core/precache_view_model.dart
import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../data/services/precache_service.dart';

/// Progresso do download offline do primeiro acesso.
///
/// O acervo inteiro (1025 partituras + acordes + dados, ~13 MB) precisa estar
/// no cache do service worker para o app abrir offline. Sem uma tela dizendo
/// que algo está acontecendo, o usuário fecha a página no meio e fica com um
/// offline pela metade.
///
/// Quem baixa é este view model, asset por asset: o `downloadOffline` do
/// service worker usa `cache.addAll`, e no Chromium as entradas do Cache API só
/// aparecem quando o lote inteiro termina — a tela ficaria parada em
/// "2 de 1027" por minutos, o que é pior do que não ter barra. Baixando daqui,
/// cada requisição passa pelo fetch handler do service worker (que cacheia o
/// que está em RESOURCES) e o progresso é honesto: o numerador é o que já
/// chegou, o denominador é o AssetManifest.
class PrecacheViewModel extends ChangeNotifier {
  PrecacheViewModel({required PrecacheService service}) : _service = service;

  final PrecacheService _service;

  /// Quantos assets ficam em voo ao mesmo tempo. Seis é o que o Chrome aguenta
  /// por host sem enfileirar — mais que isso só troca progresso por espera.
  static const concorrencia = 6;

  /// Retentativas por asset, além da primeira tentativa. Duas é o suficiente
  /// para um tropeço de rede e ainda mantém o pior caso curto.
  static const retentativas = 2;

  /// Espera entre duas tentativas do mesmo asset.
  static const pausaEntreTentativas = Duration(milliseconds: 250);

  int _baixados = 0;
  int _total = 0;
  bool _completo = false;
  bool _dispensado = false;
  bool _iniciado = false;
  bool _decidido = false;
  bool _descartado = false;
  final List<String> _falhados = [];

  /// Assets que já chegaram (em cache de antes + baixados agora).
  int get baixados => _baixados;

  /// Assets que o acervo tem ao todo (0 = ainda não calculado).
  int get total => _total;

  /// Acabou: o download terminou, ou nem se aplica (fora da web, sem rede ou
  /// com o cache já cheio). Nos três casos não há o que esperar.
  bool get completo => _completo;

  /// O usuário tocou em "continuar sem baixar" — usa o app agora; o download
  /// segue no que já está em voo e o cache continua enchendo.
  bool get dispensado => _dispensado;

  /// Assets que não baixaram depois de todas as tentativas. Não impedem o app
  /// de abrir (o que faltou fica para a próxima visita), mas dizem se o
  /// offline saiu completo.
  int get falhas => _falhados.length;

  /// Os assets que falharam, na ordem em que a fila os entregou.
  List<String> get falhados => UnmodifiableListView(_falhados);

  /// A tela de preparação deve cobrir o app?
  ///
  /// Só depois da primeira leitura e só se HOUVER o que baixar ([_decidido]):
  /// antes de saber o total a tela mostraria "0 de 0 arquivos" com barra
  /// indefinida, e numa reabertura com o cache cheio ela chegaria a piscar por
  /// um quadro antes do "já está tudo aqui". Quem não tem nada a esperar não
  /// vê preparação nenhuma — nem de relance.
  bool get mostrar => _decidido && !_completo && !_dispensado;

  /// Primeira leitura do cache e, se houver o que baixar, o download do acervo
  /// inteiro (concorrência limitada, com retentativas). Chamada uma vez só
  /// (repetir é no-op). O retorno só se completa ao fim do download — quem
  /// chama não precisa esperar por ele.
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
      final acervo = await _acervoDoApp();
      _total = acervo.length;
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
      // de verdade ("2 de 1028").
      _baixados = emCache;
      _decidido = true;
      _notificar();
      await _baixarTudo(acervo);
    } catch (_) {
      // Falha inesperada (cache inacessível, manifesto ilegível): melhor abrir
      // o app do que prender o usuário numa preparação eterna.
      _concluir();
    }
  }

  /// O usuário prefere usar o app agora: tira a tela; o que já está em voo
  /// termina e o cache segue enchendo.
  void continuarSemBaixar() {
    if (_dispensado) return;
    _dispensado = true;
    _notificar();
  }

  /// Baixa o acervo com [concorrencia] requisições em voo.
  ///
  /// Falha não para a fila: o app abre de qualquer jeito, e o que faltou fica
  /// para a próxima visita (o asset em cache nunca é rebaixado). No fim a
  /// preparação acaba mesmo com falhas — a tela sai e o app entra.
  Future<void> _baixarTudo(List<String> acervo) async {
    final fila = Queue<String>.of(acervo);
    Future<void> trabalhador() async {
      while (!_descartado && fila.isNotEmpty) {
        final caminho = fila.removeFirst();
        final baixou = await _baixarComRetentativas(caminho);
        if (_descartado) return; // descartado no meio: nada de estado nem aviso
        if (baixou) {
          if (_baixados < _total) _baixados++;
        } else {
          _falhados.add(caminho);
        }
        _notificar();
      }
    }

    await Future.wait([for (var i = 0; i < concorrencia; i++) trabalhador()]);
    _concluir();
  }

  /// Uma tentativa e [retentativas] retentativas espaçadas de um asset.
  Future<bool> _baixarComRetentativas(String caminho) async {
    for (var tentativa = 0; tentativa <= retentativas; tentativa++) {
      if (_descartado) return false;
      try {
        await _service.baixar(caminho);
        return true;
      } catch (_) {
        if (tentativa == retentativas) return false;
        await Future<void>.delayed(pausaEntreTentativas);
      }
    }
    return false;
  }

  void _concluir() {
    if (_descartado) return;
    _completo = true;
    _notificar();
  }

  /// Notifica só enquanto o view model está vivo — um download em voo pode
  /// voltar depois do dispose (a tela foi embora com o app aberto).
  void _notificar() {
    if (_descartado) return;
    notifyListeners();
  }

  /// Os assets que o app declara no AssetManifest — partituras, acordes.json,
  /// dados.json, fontes de pacote — na chave que o [rootBundle] usa
  /// (`assets/partituras/x.svg`). É o acervo que precisa estar em cache para o
  /// app abrir offline; quem transforma a chave em URL é o módulo web.
  static Future<List<String>> _acervoDoApp() async {
    final manifesto = await AssetManifest.loadFromAssetBundle(rootBundle);
    return manifesto.listAssets().toList()..sort();
  }

  @override
  void dispose() {
    // Para de agendar: os trabalhadores param na próxima volta e o que já está
    // em voo termina em silêncio (sem estado e sem aviso).
    _descartado = true;
    super.dispose();
  }
}
