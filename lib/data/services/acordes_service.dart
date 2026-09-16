// lib/data/services/acordes_service.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../../domain/models/acorde_shape.dart';

/// Desenhos de acorde do chords-db (MIT), empacotados em assets/acordes.json
/// por tool/gerar_acordes.py.
///
/// O asset tem ~40 KB e só é lido quando alguém toca num acorde — por isso não
/// entra no carregamento inicial: a folha do acorde chama [carregar], que
/// guarda o resultado em memória (o asset é imutável, uma leitura basta).
class AcordesService {
  AcordesService._();

  static final AcordesService instancia = AcordesService._();

  static const caminho = 'assets/acordes.json';

  Map<String, List<AcordeShape>>? _cache;

  Future<Map<String, List<AcordeShape>>> carregar() async {
    final guardado = _cache;
    if (guardado != null) return guardado;
    try {
      return _cache = mapaDeJson(await rootBundle.loadString(caminho));
    } catch (_) {
      // Asset ausente não pode derrubar o toque num acorde: a folha mostra
      // 'Posição não disponível' e o resto do app segue. Sem cache: se o
      // asset voltar (hot reload, reinstalação), a próxima leitura tenta de novo.
      return {};
    }
  }

  /// JSON do asset -> mapa acorde -> posições. Entrada corrompida vira mapa
  /// vazio (ou pula só a entrada ruim) em vez de exceção.
  static Map<String, List<AcordeShape>> mapaDeJson(String bruto) {
    final decodificado = _decodificar(bruto);
    if (decodificado is! Map) return {};
    final acervo = <String, List<AcordeShape>>{};
    for (final entrada in decodificado.entries) {
      final bruta = entrada.value;
      if (entrada.key is! String || bruta is! List) continue;
      try {
        acervo[entrada.key as String] = [
          for (final p in bruta)
            AcordeShape.fromJson(p as Map<String, dynamic>),
        ];
      } catch (_) {
        // Uma posição malformada não leva o resto do acervo junto.
      }
    }
    return acervo;
  }

  static dynamic _decodificar(String bruto) {
    try {
      return jsonDecode(bruto);
    } catch (_) {
      return null;
    }
  }

  /// Posições do [acorde] no [acervo]; lista vazia quando não há desenho.
  ///
  /// O acorde vem da cifra já transposto, onde convivem grafias que o acervo
  /// não usa (bemóis e variantes do meio-diminuto — ver [chaveDe]). Quando nem
  /// isso resolve, um acorde com baixo invertido ('C/G') cai no acorde base:
  /// é o mesmo acorde, só sem a nota do baixo.
  static List<AcordeShape> posicoesDe(
      Map<String, List<AcordeShape>> acervo, String acorde) {
    for (final chave in candidatosDe(acorde)) {
      final posicoes = acervo[chave];
      if (posicoes != null && posicoes.isNotEmpty) return posicoes;
    }
    return const [];
  }

  /// Chaves do acervo a tentar, na ordem: o nome normalizado e, se ele tem
  /// baixo invertido, o acorde base.
  static List<String> candidatosDe(String acorde) {
    final normalizado = chaveDe(acorde);
    if (normalizado.isEmpty) return const [];
    final corte = normalizado.indexOf('/');
    if (corte <= 0) return [normalizado];
    return [normalizado, normalizado.substring(0, corte)];
  }

  /// Nome do acorde na cifra -> chave do acervo (sempre com sustenidos).
  ///
  /// Traduz o que o povo escreve e o acervo não conhece:
  ///   * bemóis: 'Bb' -> 'A#';
  ///   * meio-diminuto: 'm7/5-', 'm7/-5', 'm7(b5)', 'ø' -> 'm7b5';
  ///   * ordinal do teclado: 'º' -> '°' (o acervo usa o grau de verdade).
  /// O que não casa com um acorde volta como veio (a busca simplesmente falha).
  static String chaveDe(String acorde) {
    final m = _acorde.firstMatch(acorde);
    if (m == null) return acorde;
    final raiz = m.group(1)! + (m.group(2) ?? '');
    final sufixo = m.group(3) ?? '';
    return '${_bemois[raiz] ?? raiz}${_aliases[sufixo.toLowerCase()] ?? sufixo}';
  }

  static final _acorde = RegExp(r'^([A-G])([#b]?)(.*)$');

  static const _bemois = {
    'Db': 'C#', 'Eb': 'D#', 'Gb': 'F#', 'Ab': 'G#', 'Bb': 'A#',
  };

  /// Grafias alternativas -> sufixo do acervo (chaves em minúsculas).
  static const _aliases = {
    'maj7': '7M',
    'm7/5-': 'm7b5',
    'm7/-5': 'm7b5',
    'm7(b5)': 'm7b5',
    'm7(5b)': 'm7b5',
    'ø': 'm7b5',
    'ø7': 'm7b5',
    'º': '°',
  };
}
