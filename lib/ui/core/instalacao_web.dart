// lib/ui/core/instalacao_web.dart
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// O evento `beforeinstallprompt` capturado e ainda não usado.
///
/// O Chrome só dispara esse evento quando o app é instalável (manifest + service
/// worker + HTTPS) e o prompt nativo só pode ser aberto UMA vez, a partir do
/// próprio evento. Por isso ele fica guardado aqui até o usuário tocar em
/// 'Instalar' — quem decide a hora é ele, não o navegador.
_PromptEvent? _evento;

/// Quem quer saber quando a instalação ficar disponível (o view model). Um só:
/// o banner é um.
void Function()? _aoAtualizar;

/// O ouvinte de `beforeinstallprompt` já está na página?
bool _observando = false;

/// O evento de instalação do Chrome, visto do Dart: `prompt()` abre o diálogo
/// nativo e `userChoice` resolve quando o usuário responde.
///
/// Não existe tipo para ele no package:web (é uma interface que o Chrome
/// inventou e o Safari/iPhone nunca implementou); os membros são declarados
/// aqui, e o objeto real vem do próprio evento.
extension type _PromptEvent._(JSObject _) implements JSObject {
  /// Sem isto o Chrome engole o evento para mostrar o mini-infobar dele — e o
  /// prompt se perde (só se abre uma vez). Com o `preventDefault` o evento
  /// continua disponível para o `prompt()` daqui a pouco.
  external void preventDefault();

  /// Abre o diálogo nativo de instalação.
  external void prompt();

  /// Resolve com `{outcome: 'accepted' | 'dismissed'}` quando o usuário
  /// responde ao diálogo.
  external JSPromise<JSObject> get userChoice;
}

/// O app já está aberto como app instalado (atalho na tela inicial)?
bool get appInstalado =>
    web.window.matchMedia('(display-mode: standalone)').matches;

/// O aparelho é um iPhone/iPad/iPod?
///
/// No iOS não existe `beforeinstallprompt`: a instalação é manual, pelo menu
/// Compartilhar → Adicionar à Tela de Início — e só faz sentido ensinar isso
/// enquanto o app NÃO estiver aberto do atalho.
bool get aparelhoIos {
  if (appInstalado) return false;
  final ua = web.window.navigator.userAgent;
  return ua.contains('iPhone') || ua.contains('iPad') || ua.contains('iPod');
}

/// O navegador já avisou que dá para instalar?
bool get instalacaoDisponivel => _evento != null;

/// Põe na página o ouvinte de `beforeinstallprompt` (uma vez; repetir é no-op).
///
/// Chamado já na construção do serviço: o evento pode chegar antes de qualquer
/// um perguntar, e quem chega depois encontra [_evento] guardado.
void observarInstalacao() {
  if (_observando) return;
  _observando = true;
  web.window
      .addEventListener('beforeinstallprompt', ((JSObject evento) {
    final capturado = _PromptEvent._(evento);
    capturado.preventDefault();
    _evento = capturado;
    _aoAtualizar?.call();
  }).toJS);
}

/// Avisa [aoAtualizar] quando a instalação ficar disponível — e na hora, se
/// ela já estiver (o evento pode ter chegado antes de alguém perguntar).
void avisarQuandoInstalavel(void Function() aoAtualizar) {
  _aoAtualizar = aoAtualizar;
  if (instalacaoDisponivel) aoAtualizar();
}

/// Abre o prompt nativo de instalação e diz se o usuário aceitou.
///
/// Sem evento capturado não há o que abrir: devolve false (o banner continua no
/// lugar). O evento é consumido — um prompt, uma vez.
Future<bool> pedirInstalacao() async {
  final evento = _evento;
  if (evento == null) return false;
  _evento = null;
  evento.prompt();
  final escolha = await evento.userChoice.toDart;
  // O `userChoice` é um objeto cru do navegador: ler `outcome` por propriedade
  // é o que dispensa declarar mais um tipo para ele.
  final resultado = escolha.getProperty<JSAny?>('outcome'.toJS)?.dartify();
  return resultado == 'accepted';
}
