// lib/data/repositories/hinos_repository.dart
import 'dart:convert';
import '../../domain/models/hino.dart';
import '../services/hinos_service.dart';

/// Grupo de hinos de um mesmo hinário (autor + rótulo) devolvido pela busca.
class GrupoHinario {
  final String autor;
  final String rotulo; // rótulo do grupo (possivelmente com sufixo de colisão)
  final List<Hino> hinos;
  const GrupoHinario({required this.autor, required this.rotulo, required this.hinos});
}

// Normalização pt-BR sem NFD (não há API nativa): 28 substituições 1:1.
// Inclui os indicadores ordinais ª/º ('1ª VEZ' na letra casa com '1a vez').
const _acentos = 'áàâãäéèêëíìîïóòôõöúùûüçñýÿªº';
const _semAcento = 'aaaaaeeeeiiiiooooouuuucnyyao';

/// Minúsculas e sem acentos — o índice e a consulta passam por aqui, então
/// 'chaveirao' acha 'Chaveirão'.
String _normalizar(String texto) {
  final minusculo = texto.toLowerCase();
  final buffer = StringBuffer();
  for (final char in minusculo.split('')) {
    final i = _acentos.indexOf(char);
    buffer.write(i == -1 ? char : _semAcento[i]);
  }
  return buffer.toString();
}

/// Fonte única de verdade dos hinários. Transforma o JSON bruto em
/// domain models, cacheia e oferece agrupamento/busca/filtro.
class HinosRepository {
  HinosRepository({required HinosService service}) : _service = service;

  final HinosService _service;
  List<Hino>? _hinos;
  /// Índice de busca (nome+autor+hinário+letra+tom, minúsculo e sem acentos)
  /// construído uma única vez em [carregar]. Sem ele, cada tecla digitada
  /// reconstruía ~3,4 MB de strings para os 3087 hinos.
  List<String>? _indice;
  /// Cache do [agrupar] (reagrupar 3087 hinos custa O(n log n) por build, não
  /// por tecla). Invalidado em [carregar], quando `_hinos` é trocado.
  Map<String, Map<String, List<Hino>>>? _gruposCache;

  static final _espacos = RegExp(r'\s+');

  List<String> _tokens(String query) =>
      _normalizar(query).split(_espacos).where((t) => t.isNotEmpty).toList();

  Future<List<Hino>> carregar() async {
    if (_hinos != null) return _hinos!;
    _gruposCache = null; // invalida antes de trocar _hinos
    final texto = await _service.carregarJson();
    final lista = jsonDecode(texto) as List<dynamic>;
    _hinos = [for (final item in lista) Hino.fromJson(item as Map<String, dynamic>)];
    _indice = [for (final h in _hinos!) _textoDeBusca(h)];
    return _hinos!;
  }

  String _textoDeBusca(Hino h) => _normalizar([
        h.nome,
        h.autor,
        h.hinario,
        h.letra,
        if (h.cifra != null) h.cifra!.tom,
      ].join(' '));

  Map<String, Map<String, List<Hino>>> agrupar() {
    final cache = _gruposCache;
    if (cache != null) return cache;
    // 1. Identidade do hinário = urlhinario (hinos sem url: o nome).
    final porAutor = <String, Map<String, List<Hino>>>{};
    for (final h in _hinos!) {
      final autor = h.autor.isEmpty ? 'Sem autor' : h.autor;
      final chave = h.urlhinario.isEmpty ? h.hinario : h.urlhinario;
      porAutor.putIfAbsent(autor, () => {}).putIfAbsent(chave, () => []).add(h);
    }
    final resultado = <String, Map<String, List<Hino>>>{};
    for (final autor in porAutor.keys) {
      final grupos = porAutor[autor]!;
      // 2. Rótulo = nome de hinário mais comum no grupo (tie-break alfabético).
      final rotuloPorChave = <String, String>{
        for (final chave in grupos.keys) chave: _rotuloMaisComum(grupos[chave]!),
      };
      // 3. Colisão de rótulo (duas chaves, mesmo rótulo): o grupo de menor
      //    contagem recebe o sufixo ' (chave)'; o maior fica com o rótulo puro.
      final porRotulo = <String, List<String>>{};
      for (final chave in grupos.keys) {
        porRotulo.putIfAbsent(rotuloPorChave[chave]!, () => []).add(chave);
      }
      final comRotulo = <String, List<Hino>>{};
      for (final rotulo in porRotulo.keys) {
        final chaves = porRotulo[rotulo]!;
        if (chaves.length == 1) {
          comRotulo[rotulo] = grupos[chaves.first]!;
        } else {
          chaves.sort((a, b) {
            final c = grupos[a]!.length.compareTo(grupos[b]!.length);
            return c != 0 ? c : a.compareTo(b);
          });
          for (final chave in chaves) {
            final rotuloFinal = chave == chaves.last ? rotulo : '$rotulo ($chave)';
            comRotulo[rotuloFinal] = grupos[chave]!;
          }
        }
      }
      // 4. Ordenação: autores e rótulos alfabéticos SEM acento (senão
      //    'Índio'/'João' caem no fim, depois de todo nome sem acento);
      //    hinos por num (tie-break nome).
      final ordenado = <String, List<Hino>>{};
      for (final rotulo in comRotulo.keys.toList()
        ..sort((a, b) {
          final c = _normalizar(a).compareTo(_normalizar(b));
          return c != 0 ? c : a.compareTo(b);
        })) {
        final lista = comRotulo[rotulo]!
          ..sort((a, b) => a.num != b.num ? a.num.compareTo(b.num) : a.nome.compareTo(b.nome));
        ordenado[rotulo] = lista;
      }
      resultado[autor] = ordenado;
    }
    final autores = resultado.keys.toList()
      ..sort((a, b) {
        final c = _normalizar(a).compareTo(_normalizar(b));
        return c != 0 ? c : a.compareTo(b);
      });
    return _gruposCache = <String, Map<String, List<Hino>>>{
      for (final autor in autores) autor: resultado[autor]!,
    };
  }

  /// Nome de hinário mais comum no grupo; empate → ordem alfabética.
  /// Nome vazio vira 'Sem hinário' (fallback do agrupamento antigo).
  String _rotuloMaisComum(List<Hino> hinos) {
    final contagem = <String, int>{};
    for (final h in hinos) {
      contagem[h.hinario] = (contagem[h.hinario] ?? 0) + 1;
    }
    final nome = contagem.keys.reduce((a, b) {
      final ca = contagem[a]!, cb = contagem[b]!;
      if (ca != cb) return ca > cb ? a : b;
      return a.compareTo(b) < 0 ? a : b;
    });
    return nome.isEmpty ? 'Sem hinário' : nome;
  }

  List<Hino> buscar(String query) {
    final tokens = _tokens(query);
    if (tokens.isEmpty) return _hinos!;
    final hinos = _hinos!;
    final indice = _indice!;
    return [
      for (var i = 0; i < hinos.length; i++)
        if (tokens.every(indice[i].contains)) hinos[i],
    ];
  }

  /// Grupos (do agrupamento por urlhinario) cujo rótulo OU autor casam todos
  /// os tokens da consulta (normalizada). Query vazia → lista vazia.
  /// Os grupos vêm do [agrupar] memoizado: o acervo real tem 265 grupos em 181
  /// autores, e o que pesava era o reagrupamento dos 3087 hinos — agora pago
  /// uma única vez por carga, então nenhum índice por grupo é necessário.
  List<GrupoHinario> buscarGrupos(String query) {
    final tokens = _tokens(query);
    if (tokens.isEmpty) return const [];
    final grupos = agrupar();
    final resultado = <GrupoHinario>[];
    for (final autor in grupos.keys) {
      for (final rotulo in grupos[autor]!.keys) {
        final alvo = _normalizar('$rotulo $autor');
        if (tokens.every(alvo.contains)) {
          resultado.add(GrupoHinario(
            autor: autor,
            rotulo: rotulo,
            hinos: grupos[autor]![rotulo]!,
          ));
        }
      }
    }
    return resultado;
  }

  /// Todos os grupos (de [agrupar]), em ordem alfabética pelo rótulo
  /// (normalizado, sem acentos; empate → autor normalizado).
  List<GrupoHinario> gruposPorNome() {
    final grupos = agrupar();
    final lista = <GrupoHinario>[
      for (final autor in grupos.keys)
        for (final rotulo in grupos[autor]!.keys)
          GrupoHinario(autor: autor, rotulo: rotulo, hinos: grupos[autor]![rotulo]!),
    ];
    lista.sort((a, b) {
      final c = _normalizar(a.rotulo).compareTo(_normalizar(b.rotulo));
      return c != 0 ? c : _normalizar(a.autor).compareTo(_normalizar(b.autor));
    });
    return lista;
  }

  /// Chave de agrupamento do hino: urlhinario, ou o nome quando a url é vazia.
  String chaveDe(Hino h) => h.urlhinario.isEmpty ? h.hinario : h.urlhinario;

  /// Todos os hinos do mesmo grupo do hino (mesma chave e mesmo autor),
  /// ordenados por num (tie-break nome). Espelha o agrupamento da árvore.
  List<Hino> hinosDoGrupo(Hino h) {
    final chave = chaveDe(h);
    return _hinos!
        .where((x) => x.autor == h.autor && chaveDe(x) == chave)
        .toList()
      ..sort((a, b) => a.num != b.num ? a.num.compareTo(b.num) : a.nome.compareTo(b.nome));
  }

  List<Hino> hinosDoHinario(String urlhinario) {
    final lista = _hinos!.where((h) => h.urlhinario == urlhinario).toList()
      ..sort((a, b) => a.num.compareTo(b.num));
    return lista;
  }
}
