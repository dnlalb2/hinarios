import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Preferencias {
  final bool temaEscuro;
  final double tamanhoFonte;
  final Set<String> favoritos;
  final Map<String, int> deslocamentos;
  const Preferencias({
    this.temaEscuro = false,
    this.tamanhoFonte = 16,
    this.favoritos = const {},
    this.deslocamentos = const {},
  });
}

class PreferenciasService {
  Future<void> _gravacaoPendente = Future<void>.value();

  Future<void> salvar({
    required bool temaEscuro,
    required double tamanhoFonte,
    required Set<String> favoritos,
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
      await p.setString('hinario.toms', jsonEncode(deslocamentos));
    });
    _gravacaoPendente = gravacao.catchError((_) {});
    return gravacao;
  }

  Future<Preferencias> restaurar() async {
    final p = await SharedPreferences.getInstance();
    final toms = jsonDecode(p.getString('hinario.toms') ?? '{}') as Map<String, dynamic>;
    return Preferencias(
      temaEscuro: p.getBool('hinario.tema') ?? false,
      tamanhoFonte: p.getDouble('hinario.fonte') ?? 16,
      favoritos: (p.getStringList('hinario.favoritos') ?? []).toSet(),
      deslocamentos: toms.map((k, v) => MapEntry(k, (v as num).toInt())),
    );
  }
}
