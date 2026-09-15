import 'package:flutter_test/flutter_test.dart';
import 'package:hinarios_app/domain/use_cases/chordpro.dart';

void main() {
  // O colchete marca a coluna: o acorde fica sobre a sílaba que ele precede.
  // 'Quem não ' tem 9 colunas → o E7 entra na coluna 9 (7 espaços depois do
  // 'Am', que ocupa as colunas 0 e 1).
  test('acorde fica na coluna da sílaba que ele precede', () {
    final l = parsearChordPro('[Am]Quem não [E7]anda no caminho').single;
    expect(l.letra, 'Quem não anda no caminho');
    expect(l.acordes, 'Am       E7');
  });

  test('acorde no fim da linha sai da letra e vai para a coluna certa', () {
    final l = parsearChordPro('Quem anda[E7]').single;
    expect(l.letra, 'Quem anda');
    expect(l.acordes, '         E7');
  });

  // Dois acordes na MESMA coluna viram um token só ('AmE7') se colarem: o
  // segundo é empurrado por um espaço.
  test('acordes na mesma coluna são separados por um espaço', () {
    final l = parsearChordPro('[Am][E7]Quem').single;
    expect(l.letra, 'Quem');
    expect(l.acordes, 'Am E7');
  });

  test('linha sem acorde tem acordes vazio e letra intacta', () {
    final l = parsearChordPro('Só a letra').single;
    expect(l.letra, 'Só a letra');
    expect(l.acordes, '');
  });

  test("'[' sem ']' na linha é texto literal", () {
    final l = parsearChordPro('[Am]Quem [falta').single;
    expect(l.letra, 'Quem [falta');
    expect(l.acordes, 'Am');
  });

  test('uma entrada por linha, inclusive as vazias', () {
    final linhas = parsearChordPro('[C]Um\n\n[G]Dois');
    expect(linhas.length, 3);
    expect(linhas[0].letra, 'Um');
    expect(linhas[0].acordes, 'C');
    expect(linhas[1].letra, '');
    expect(linhas[1].acordes, '');
    expect(linhas[2].letra, 'Dois');
    expect(linhas[2].acordes, 'G');
  });

  test('texto vazio não gera linha', () {
    expect(parsearChordPro(''), isEmpty);
  });

  // Mesma normalização de quebras do alinhar(): '\r\n' conta como UMA linha
  // (a letra do acervo vem com '\r\n').
  test('CRLF conta como uma quebra só', () {
    final linhas = parsearChordPro('[C]Um\r\n[G]Dois');
    expect(linhas.length, 2);
    expect(linhas[0].letra, 'Um');
    expect(linhas[1].acordes, 'G');
  });

  test('colchete vazio não é acorde nem letra', () {
    final l = parsearChordPro('[]Quem').single;
    expect(l.letra, 'Quem');
    expect(l.acordes, '');
  });
}
