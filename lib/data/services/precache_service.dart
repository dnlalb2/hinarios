// lib/data/services/precache_service.dart
import '../../ui/core/cache_offline.dart';

/// Embrulho fino das funções de [cache_offline] para o [PrecacheViewModel].
///
/// O módulo condicional resolve para web ou stub em tempo de compilação e não
/// dá para trocar num teste de VM — esta classe dá: os testes injetam uma
/// implementação falsa e exercitam o progresso sem navegador nenhum.
class PrecacheService {
  const PrecacheService();

  /// Quantos arquivos do acervo já estão no cache (-1 = não se aplica).
  Future<int> arquivosEmCache() => arquivosDeAcervoEmCache();

  /// O navegador está online? (fora da web, sempre true: o app não usa rede)
  bool get online => onlineAgora;

  /// Pede ao service worker o download de tudo que ainda falta (no-op fora da web).
  void solicitar() => solicitarCacheCompleto();
}
