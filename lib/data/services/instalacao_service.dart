// lib/data/services/instalacao_service.dart
import '../../ui/core/instalacao.dart';

/// Embrulho fino das funções de [instalacao] para o [InstalacaoViewModel].
///
/// Mesma razão do [PrecacheService]: o módulo condicional resolve para web ou
/// stub em tempo de compilação e não dá para trocar num teste de VM — esta
/// classe dá (os testes injetam uma implementação falsa e exercitam o banner
/// sem navegador nenhum).
class InstalacaoService {
  InstalacaoService() {
    // O `beforeinstallprompt` pode chegar antes de qualquer um perguntar: o
    // ouvinte entra já aqui, na construção, e o estado fica guardado no módulo.
    observarInstalacao();
  }

  /// A instância do app — um único ouvinte de `beforeinstallprompt` na página.
  static final InstalacaoService instancia = InstalacaoService();

  /// O app já está aberto no modo instalado (atalho na tela inicial)?
  bool get jaInstalado => appInstalado;

  /// O aparelho é iOS (onde não existe prompt de instalação)?
  bool get ehIos => aparelhoIos;

  /// O navegador já avisou que dá para instalar?
  bool get pronto => instalacaoDisponivel;

  /// Registra [aoAtualizar] para ser chamado quando [pronto] virar true — ou na
  /// hora, se já tiver virado.
  void registrar(void Function() aoAtualizar) => avisarQuandoInstalavel(aoAtualizar);

  /// Abre o prompt nativo de instalação e diz se o usuário aceitou. Sem
  /// instalação disponível (fora da web inclusive) devolve false.
  Future<bool> instalar() => pedirInstalacao();
}
