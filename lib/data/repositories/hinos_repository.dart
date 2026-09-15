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
  /// Cache do [gruposGlobais] (reagrupar 3087 hinos custa O(n log n) por
  /// build, não por tecla). Invalidado em [carregar], quando `_hinos` troca.
  List<GrupoHinario>? _gruposGlobaisCache;
  /// Cache do [agrupar] (autor → grupos globais): mesma razão.
  Map<String, List<GrupoHinario>>? _gruposCache;

  static final _espacos = RegExp(r'\s+');

  List<String> _tokens(String query) =>
      _normalizar(query).split(_espacos).where((t) => t.isNotEmpty).toList();

  Future<List<Hino>> carregar() async {
    if (_hinos != null) return _hinos!;
    _gruposGlobaisCache = null; // invalida antes de trocar _hinos
    _gruposCache = null;
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

  /// Todos os hinários como grupos GLOBAIS por urlhinario (hinos sem url: o
  /// nome), independentemente de quem recebeu cada hino. Memoizado.
  ///
  /// É a unidade real do site: 35 dos 84 hinários são coletivos (hinos
  /// recebidos por canais/autores diferentes) — o grupo 'caboclo-guerreiro',
  /// por exemplo, tem 43 hinos de 41 autores. O campo [GrupoHinario.autor] é o
  /// autor único quando todos os hinos o compartilham, senão 'Diversos'.
  List<GrupoHinario> gruposGlobais() {
    final cache = _gruposGlobaisCache;
    if (cache != null) return cache;
    // 1. Identidade do hinário = urlhinario (hinos sem url: o nome).
    final porChave = <String, List<Hino>>{};
    for (final h in _hinos!) {
      porChave.putIfAbsent(chaveDe(h), () => []).add(h);
    }
    // 2. Rótulo = nome de hinário mais comum no grupo (tie-break alfabético).
    final rotuloPorChave = <String, String>{
      for (final chave in porChave.keys) chave: _rotuloMaisComum(porChave[chave]!),
    };
    // 3. Colisão de rótulo (duas chaves, mesmo rótulo): o grupo de menor
    //    contagem GLOBAL recebe o sufixo ' (chave)'; o maior fica com o puro.
    final porRotulo = <String, List<String>>{};
    for (final chave in porChave.keys) {
      porRotulo.putIfAbsent(rotuloPorChave[chave]!, () => []).add(chave);
    }
    final comRotulo = <String, List<Hino>>{};
    for (final rotulo in porRotulo.keys) {
      final chaves = porRotulo[rotulo]!;
      if (chaves.length == 1) {
        comRotulo[rotulo] = porChave[chaves.first]!;
      } else {
        chaves.sort((a, b) {
          final c = porChave[a]!.length.compareTo(porChave[b]!.length);
          return c != 0 ? c : a.compareTo(b);
        });
        for (final chave in chaves) {
          final rotuloFinal = chave == chaves.last ? rotulo : '$rotulo ($chave)';
          comRotulo[rotuloFinal] = porChave[chave]!;
        }
      }
    }
    // 4. Ordenação: rótulo normalizado (sem acento, senão 'Índio' cai depois
    //    de todo nome sem acento), empate → autor normalizado; hinos por num
    //    (tie-break nome).
    final lista = <GrupoHinario>[
      for (final rotulo in comRotulo.keys)
        GrupoHinario(
          autor: _autorDoGrupo(comRotulo[rotulo]!),
          rotulo: rotulo,
          hinos: comRotulo[rotulo]!
            ..sort((a, b) => a.num != b.num ? a.num.compareTo(b.num) : a.nome.compareTo(b.nome)),
        ),
    ];
    lista.sort((a, b) {
      final c = _normalizar(a.rotulo).compareTo(_normalizar(b.rotulo));
      return c != 0 ? c : _normalizar(a.autor).compareTo(_normalizar(b.autor));
    });
    return _gruposGlobaisCache = lista;
  }

  /// Autor do grupo: o único autor quando TODOS os hinos o compartilham, senão
  /// 'Diversos' (hinário coletivo). Vazio vira 'Sem autor'.
  String _autorDoGrupo(List<Hino> hinos) {
    final primeiro = _autorDe(hinos.first);
    for (final h in hinos.skip(1)) {
      if (_autorDe(h) != primeiro) return 'Diversos';
    }
    return primeiro;
  }

  String _autorDe(Hino h) => h.autor.isEmpty ? 'Sem autor' : h.autor;

  /// Autor → os hinários GLOBAIS em que ele tem ao menos um hino, ordenados
  /// por rótulo normalizado. Os grupos são os mesmos de [gruposGlobais]
  /// (contagem global, abrem o hinário completo).
  Map<String, List<GrupoHinario>> agrupar() {
    final cache = _gruposCache;
    if (cache != null) return cache;
    final resultado = <String, List<GrupoHinario>>{};
    for (final grupo in gruposGlobais()) {
      for (final h in grupo.hinos) {
        resultado.putIfAbsent(_autorDe(h), () => []).add(grupo);
      }
    }
    final autores = resultado.keys.toList()
      ..sort((a, b) {
        final c = _normalizar(a).compareTo(_normalizar(b));
        return c != 0 ? c : a.compareTo(b);
      });
    return _gruposCache = <String, List<GrupoHinario>>{
      for (final autor in autores) autor: _semRepetir(resultado[autor]!),
    };
  }

  /// Remove grupos repetidos (um autor com vários hinos no mesmo hinário).
  List<GrupoHinario> _semRepetir(List<GrupoHinario> grupos) {
    final vistos = <GrupoHinario>{};
    return [for (final g in grupos) if (vistos.add(g)) g];
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

  /// Grupos GLOBAIS cujo rótulo OU autor casam todos os tokens da consulta
  /// (normalizada). Query vazia → lista vazia.
  /// Os grupos vêm do [gruposGlobais] memoizado: o acervo real tem 84 hinários,
  /// e o que pesava era o reagrupamento dos 3087 hinos — agora pago uma única
  /// vez por carga, então nenhum índice por grupo é necessário.
  List<GrupoHinario> buscarGrupos(String query) {
    final tokens = _tokens(query);
    if (tokens.isEmpty) return const [];
    final resultado = <GrupoHinario>[];
    for (final grupo in gruposGlobais()) {
      final alvo = _normalizar('${grupo.rotulo} ${grupo.autor}');
      if (tokens.every(alvo.contains)) resultado.add(grupo);
    }
    return resultado;
  }

  /// Chave de agrupamento do hino: urlhinario, ou o nome quando a url é vazia.
  String chaveDe(Hino h) => h.urlhinario.isEmpty ? h.hinario : h.urlhinario;

  /// Todos os hinos do hinário GLOBAL do hino (mesma urlhinario; hinos sem url:
  /// o nome), de quaisquer autores, ordenados por num (tie-break nome). É o
  /// grupo que a navegação abre — o coletivo completo, não o recorte do autor.
  List<Hino> hinosDoGrupo(Hino h) {
    final chave = chaveDe(h);
    return _hinos!
        .where((x) => chaveDe(x) == chave)
        .toList()
      ..sort((a, b) => a.num != b.num ? a.num.compareTo(b.num) : a.nome.compareTo(b.nome));
  }

  List<Hino> hinosDoHinario(String urlhinario) {
    final lista = _hinos!.where((h) => h.urlhinario == urlhinario).toList()
      ..sort((a, b) => a.num.compareTo(b.num));
    return lista;
  }
}
