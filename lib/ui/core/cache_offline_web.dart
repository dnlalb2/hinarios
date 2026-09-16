// lib/ui/core/cache_offline_web.dart
import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Mensagem que o service worker do Flutter entende como "baixe tudo que
/// ainda falta no cache" (ver `downloadOffline` no flutter_service_worker.js).
const _mensagem = 'downloadOffline';

/// Nome do cache que o service worker do Flutter usa (CACHE_NAME em
/// flutter_service_worker.js). É onde o acervo baixado aparece.
const _nomeDoCache = 'flutter-app-cache';

/// Pede ao service worker o download de TODOS os recursos do app.
///
/// Sem isso só fica offline o que o usuário abriu uma vez: as partituras (1025
/// SVGs) e o acordes.json são buscados sob demanda. Manda a mensagem e segue —
/// o download acontece no SW, fora do isolate da UI, e é barato nas próximas
/// visitas (o SW só baixa o que ainda falta).
void solicitarCacheCompleto() {
  final container = web.window.navigator.serviceWorker;
  final controlador = container.controller;
  if (controlador != null) {
    controlador.postMessage(_mensagem.toJS);
    return;
  }
  // Primeira visita: o SW instala em paralelo, então a página ainda não está
  // sob controle dele. O `controllerchange` avisa quando o controle chega; se
  // ele não vier (registro lento, SW já ativo mas sem assumir a página), uma
  // única retentativa em 5 s cobre o caso. O download é um extra: nada disso
  // bloqueia nem atrasa o boot.
  var pedido = false;
  void pedir() {
    if (pedido) return;
    final atual = container.controller;
    if (atual == null) return;
    pedido = true;
    atual.postMessage(_mensagem.toJS);
  }

  container.addEventListener('controllerchange', ((web.Event _) => pedir()).toJS);
  Timer(const Duration(seconds: 5), pedir);
}

/// Quantos arquivos do ACERVO (partituras + acordes.json + dados.json) já
/// estão no cache do service worker. É o numerador do progresso da tela de
/// preparação; o denominador é o AssetManifest do app.
///
/// Conta só as chaves do acervo — o cache também guarda shell, fontes e
/// canvaskit, que não interessam a quem espera as partituras. As URLs no cache
/// são absolutas (`https://host/assets/assets/partituras/x.svg`: o primeiro
/// `assets/` é o do site, o segundo vem do pubspec), por isso a busca é por
/// trecho e não por prefixo.
Future<int> arquivosDeAcervoEmCache() async {
  final cache = await web.window.caches.open(_nomeDoCache).toDart;
  final chaves = await cache.keys().toDart;
  var total = 0;
  for (final requisicao in chaves.toDart) {
    final url = requisicao.url;
    if (url.contains('/assets/partituras/') ||
        url.contains('/assets/acordes.json') ||
        url.contains('/assets/dados.json')) {
      total++;
    }
  }
  return total;
}

/// O navegador está online? Sem rede a tela de preparação não bloqueia o app:
/// não há o que baixar, e o que já está em cache abre do mesmo jeito.
bool get onlineAgora => web.window.navigator.onLine;
