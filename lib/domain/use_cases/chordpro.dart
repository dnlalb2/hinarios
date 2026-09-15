// lib/domain/use_cases/chordpro.dart

/// Uma linha do texto ChordPro: a letra limpa (sem os acordes) e a linha de
/// acordes posicional (com espaços), prontas para o alinhar().
class LinhaChordPro {
  final String letra;
  final String acordes;
  const LinhaChordPro({required this.letra, required this.acordes});

  @override
  String toString() => 'LinhaChordPro(letra: "$letra", acordes: "$acordes")';
}

/// Converte texto ChordPro em uma entrada por linha.
/// Regras: [X] marca um acorde na coluna = tamanho atual da letra limpa;
/// colisão (dois acordes na mesma posição) empurra com um espaço; '[' sem
/// ']' na linha é tratado como texto literal; linhas sem acordes têm
/// acordes = ''.
List<LinhaChordPro> parsearChordPro(String texto) {
  if (texto.isEmpty) return const [];
  // Mesma normalização de quebras do alinhar(): '\r\n' conta como UMA linha,
  // senão a linha 1:1 do pareamento posicional sairia do lugar.
  final linhas =
      texto.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  return [for (final linha in linhas) _parsearLinha(linha)];
}

LinhaChordPro _parsearLinha(String linha) {
  final letra = StringBuffer();
  final acordes = StringBuffer();
  var i = 0;
  while (i < linha.length) {
    final abre = linha.indexOf('[', i);
    if (abre < 0) {
      letra.write(linha.substring(i)); // resto da linha: só letra
      break;
    }
    letra.write(linha.substring(i, abre)); // texto antes do colchete
    final fecha = linha.indexOf(']', abre + 1);
    if (fecha < 0) {
      // '[' sem ']' na linha inteira: é texto literal, não acorde.
      letra.write(linha.substring(abre));
      break;
    }
    final acorde = linha.substring(abre + 1, fecha);
    // '[]' não é acorde: não posiciona nada nem suja a letra.
    if (acorde.isNotEmpty) _posicionar(acordes, letra.length, acorde);
    i = fecha + 1;
  }
  return LinhaChordPro(letra: letra.toString(), acordes: acordes.toString());
}

/// Escreve [acorde] na coluna [coluna] da linha de acordes em construção,
/// preenchendo o caminho com espaços. Se já houver acorde ali (ou encostado),
/// empurra UM espaço: sem ele os dois virariam um token só ('AmE7').
void _posicionar(StringBuffer acordes, int coluna, String acorde) {
  final atual = acordes.length;
  if (coluna > atual) {
    acordes.write(' ' * (coluna - atual));
  } else if (atual > 0) {
    acordes.write(' ');
  }
  acordes.write(acorde);
}
