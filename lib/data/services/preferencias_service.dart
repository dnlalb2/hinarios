import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Preferencias {
  final bool temaEscuro;
  final double tamanhoFonte;
  final Set<String> favoritos;
  /// Chaves dos hinários favoritados (ver `GrupoHinario.chave` no repositório).
  final Set<String> hinariosFavoritos;
  final Map<String, int> deslocamentos;
  const Preferencias({
    this.temaEscuro = false,
    this.tamanhoFonte = 20,
    this.favoritos = const {},
    this.hinariosFavoritos = const {},
    this.deslocamentos = const {},
  });
}

class PreferenciasService {
  Future<void> _gravacaoPendente = Future<void>.value();

  Future<void> salvar({
    required bool temaEscuro,
    required double tamanhoFonte,
    required Set<String> favoritos,
    required Set<String> hinariosFavoritos,
    required Map<String, int> deslocamentos,
  }) {
    // Gravações fire-and-forget em sequência: sem serializar, saves
    // concorrentes compartilham o singleton do SharedPreferences e a ordem
    // final dos valores pode ficar para trás (save antigo sobrescrevendo
    // o novo).
    final gravacao = _gravacaoPendente.then((_) async {
      final p = await SharedPreferences.getInstance();
      await p.setBool('hinario.tema', temaEscuro);
      await p.setDouble('hinario.fonte', tamanhoFonte);
      await p.setStringList('hinario.favoritos', favoritos.toList());
      await p.setStringList('hinario.hinarios_favoritos', hinariosFavoritos.toList());
      await p.setString('hinario.toms', jsonEncode(deslocamentos));
    });
    _gravacaoPendente = gravacao.catchError((_) {});
    return gravacao;
  }

  Future<Preferencias> restaurar() async {
    final p = await SharedPreferences.getInstance();
    return Preferencias(
      temaEscuro: p.getBool('hinario.tema') ?? false,
      tamanhoFonte: _fonteValida(p.getDouble('hinario.fonte')),
      favoritos: (p.getStringList('hinario.favoritos') ?? []).toSet(),
      hinariosFavoritos: (p.getStringList('hinario.hinarios_favoritos') ?? []).toSet(),
      deslocamentos: _lerDeslocamentos(p.getString('hinario.toms')),
    );
  }

  /// O Slider de Configurações só aceita 12..28 — valor fora da faixa (ou
  /// corrompido) dispara assert na tela. Sem valor, mantém o padrão 20.
  double _fonteValida(double? valor) {
    if (valor == null || valor.isNaN) return 20;
    return valor.clamp(12.0, 28.0);
  }

  /// Preferência corrompida não pode derrubar a inicialização: main() aguarda
  /// restaurar() antes do runApp, então JSON malformado vira mapa vazio.
  Map<String, int> _lerDeslocamentos(String? bruto) {
    try {
      final decodificado = jsonDecode(bruto ?? '{}');
      if (decodificado is! Map) return const {};
      return {
        for (final entrada in decodificado.entries)
          if (entrada.key is String && entrada.value is num)
            entrada.key as String: (entrada.value as num).toInt(),
      };
    } catch (_) {
      return const {};
    }
  }
}
