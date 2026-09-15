// lib/domain/use_cases/busca.dart
// Normalização e casamento da busca — a semântica é a mesma na busca principal
// (biblioteca) e na busca interna do hinário, então mora no domínio, onde pode
// ser testada sozinha. O repositório deixou de ter a cópia privada.

// Normalização pt-BR sem NFD (não há API nativa): 28 substituições 1:1.
// Inclui os indicadores ordinais ª/º ('1ª VEZ' na letra casa com '1a vez').
const _acentos = 'áàâãäéèêëíìîïóòôõöúùûüçñýÿªº';
const _semAcento = 'aaaaaeeeeiiiiooooouuuucnyyao';

/// Minúsculas e sem acentos (pt-BR) — mesma normalização da busca principal.
String normalizar(String texto) {
  final minusculo = texto.toLowerCase();
  final buffer = StringBuffer();
  for (final char in minusculo.split('')) {
    final i = _acentos.indexOf(char);
    buffer.write(i == -1 ? char : _semAcento[i]);
  }
  return buffer.toString();
}

final _espacos = RegExp(r'\s+');

/// Tokens da consulta: [normalizar] e quebra por espaços, vazios fora. É a
/// MESMA tokenização usada pela busca principal — o repositório a consome no
/// lugar da cópia privada que tinha.
List<String> tokenizar(String query) =>
    normalizar(query).split(_espacos).where((t) => t.isNotEmpty).toList();

/// true quando TODOS os tokens de [query] aparecem em [alvo]. Os dois lados
/// passam por [normalizar] — 'chaveirao' casa 'Chaveirão'. Query vazia (ou só
/// espaços) → true: sem busca, tudo casa.
bool casaBusca(String query, String alvo) {
  final normalizado = normalizar(alvo);
  return tokenizar(query).every(normalizado.contains);
}
