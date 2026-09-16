// lib/data/services/precache_service.dart
import '../../ui/core/cache_offline.dart';

/// Embrulho fino das funções de [cache_offline] para o [PrecacheViewModel].
///
/// O módulo condicional resolve para web ou stub em tempo de compilação e não
/// dá para trocar num teste de VM — esta classe dá: os testes injetam uma
/// implementação falsa e exercitam o progresso sem navegador nenhum.
class PrecacheService {
  const PrecacheService();

  /// Quantos assets do acervo já estão no cache (-1 = não se aplica).
  Future<int> arquivosEmCache() => arquivosDeAcervoEmCache();

  /// O navegador está online? (fora da web, sempre true: o app não usa rede)
  bool get online => onlineAgora;

  /// Baixa um asset (chave do AssetManifest, ex.: `assets/partituras/x.svg`);
  /// no-op fora da web. Lança se o download falhar.
  Future<void> baixar(String caminho) => baixarAsset(caminho);
}
