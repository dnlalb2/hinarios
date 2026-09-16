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
/// Hoje ninguém chama: o download passou a ser feito pelo app (ver
/// [baixarAsset]), que assim enxerga o progresso — o `downloadOffline` do
/// service worker usa `cache.addAll` e, no Chromium, as entradas só aparecem
/// quando o lote inteiro termina. Fica aqui porque é a forma barata de aquecer
/// o cache sem passar pela página, caso volte a ser útil.
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

/// Baixa um asset para o cache do service worker.
///
/// [caminhoRelativo] é a chave do AssetManifest (ex.: `assets/partituras/x.svg`)
/// — a mesma que o [rootBundle] usa. O Flutter serve uma chave `k` na URL
/// `<base>/assets/k` (o primeiro `assets/` é o diretório de assets do build, o
/// segundo já vem de dentro da chave); resolver contra [Uri.base] — e não
/// contra a origem — é o que faz o app funcionar sob `--base-href` (deploy em
/// subpasta, ex.: `/hinarios/`).
///
/// O corpo da resposta não interessa: o que se quer é a requisição passar pelo
/// fetch handler do service worker, que cacheia o que está em RESOURCES. Por
/// isso o `fetch` cru e não o [rootBundle] (que decodificaria o asset à toa) e
/// por isso uma resposta não-OK vira erro — quem chamou decide se tenta de novo.
Future<void> baixarAsset(String caminhoRelativo) async {
  await _comControle();
  final url = Uri.base.resolve('assets/$caminhoRelativo');
  final resposta = await web.window.fetch(url.toString().toJS).toDart;
  if (!resposta.ok) {
    throw StateError('asset não baixou: HTTP ${resposta.status} em $url');
  }
}

/// Espera a página ficar sob controle do service worker antes de baixar.
///
/// Requisição de página não controlada não passa pelo fetch handler e não é
/// cacheada: na primeira visita o SW instala em paralelo ao boot e pode ainda
/// não ter assumido a página quando o download começa. O `controllerchange`
/// avisa quando o controle chega; o prazo (5 s, uma única vez) evita prender o
/// download para sempre num navegador onde o SW não sobe — aí ele baixa sem
/// cachear, como aconteceria antes.
Future<void> _comControle() {
  return _controle ??= () async {
    final container = web.window.navigator.serviceWorker;
    if (container.controller != null) return;
    final chegou = Completer<void>();
    late final web.EventListener ouvinte;
    ouvinte = ((web.Event _) {
      container.removeEventListener('controllerchange', ouvinte);
      if (container.controller != null && !chegou.isCompleted) chegou.complete();
    }).toJS;
    container.addEventListener('controllerchange', ouvinte);
    await chegou.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {},
    );
  }();
}

/// Guarda a espera pelo controle: a primeira requisição paga, as outras não.
Future<void>? _controle;

/// Quantos assets do ACERVO (partituras + acordes.json + dados.json + o que
/// mais o AssetManifest lista) já estão no cache do service worker. É o
/// numerador inicial da tela de preparação; o denominador é o próprio
/// AssetManifest.
///
/// Conta só o que o app declara como asset — o cache também guarda shell,
/// fontes e canvaskit, que não interessam a quem espera as partituras. As URLs
/// no cache são absolutas e a chave do AssetManifest vira `<base>/assets/<chave>`
/// (`https://host/assets/assets/partituras/x.svg`: o primeiro `assets/` é o do
/// site, o segundo vem da própria chave) — daí a busca por trecho, que também
/// ignora o prefixo do base-href.
Future<int> arquivosDeAcervoEmCache() async {
  final cache = await web.window.caches.open(_nomeDoCache).toDart;
  final chaves = await cache.keys().toDart;
  var total = 0;
  for (final requisicao in chaves.toDart) {
    final url = requisicao.url;
    if (url.contains('/assets/assets/') || url.contains('/assets/packages/')) {
      total++;
    }
  }
  return total;
}

/// O navegador está online? Sem rede a tela de preparação não bloqueia o app:
/// não há o que baixar, e o que já está em cache abre do mesmo jeito.
bool get onlineAgora => web.window.navigator.onLine;
