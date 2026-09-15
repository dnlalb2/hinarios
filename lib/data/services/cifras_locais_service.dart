// lib/data/services/cifras_locais_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/cifra_local.dart';

/// Cifras próprias do usuário, por dispositivo. Grava o mapa slug→cifra
/// inteiro numa chave só (o acervo local é pequeno e um save parcial no disco
/// deixaria o mapa pela metade).
class CifrasLocaisService {
  static const chave = 'hinario.cifras_locais';

  Future<void> _gravacaoPendente = Future<void>.value();

  Future<void> salvar(Map<String, CifraLocal> cifras) {
    // Gravações fire-and-forget em sequência: sem serializar, saves
    // concorrentes compartilham o singleton do SharedPreferences e a ordem
    // final dos valores pode ficar para trás (save antigo sobrescrevendo o
    // novo). Mesmo padrão do PreferenciasService.
    final gravacao = _gravacaoPendente.then((_) async {
      final p = await SharedPreferences.getInstance();
      await p.setString(
        chave,
        jsonEncode({for (final e in cifras.entries) e.key: e.value.toJson()}),
      );
    });
    _gravacaoPendente = gravacao.catchError((_) {});
    return gravacao;
  }

  Future<Map<String, CifraLocal>> restaurar() async {
    final p = await SharedPreferences.getInstance();
    return mapaDeJson(p.getString(chave));
  }

  /// JSON corrompido (ou de formato inesperado) vira mapa vazio em vez de
  /// exceção: main() aguarda restaurar() antes do runApp, e o importar() da
  /// Fase 2 recebe texto de fora — nenhum dos dois pode derrubar a tela.
  static Map<String, CifraLocal> mapaDeJson(String? bruto) {
    try {
      final decodificado = jsonDecode(bruto ?? '{}');
      if (decodificado is! Map) return {};
      return {
        for (final entrada in decodificado.entries)
          if (entrada.key is String && entrada.value is Map<String, dynamic>)
            entrada.key as String: CifraLocal.fromJson(entrada.value as Map<String, dynamic>),
      };
    } catch (_) {
      return {};
    }
  }
}
