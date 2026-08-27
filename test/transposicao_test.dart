// test/transposicao_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hinarios_app/domain/use_cases/transposicao.dart';

void main() {
  test('meio tom acima', () {
    expect(transporAcorde('Am', 1), 'A#m');
    expect(transporAcorde('E7', 1), 'F7');
    expect(transporAcorde('D', 1), 'D#');
  });
  test('meio tom abaixo', () {
    expect(transporAcorde('D', -1), 'C#');
    expect(transporAcorde('C', -1), 'B');
  });
  test('bemóis são normalizados', () {
    expect(transporAcorde('Bb', 1), 'B');
    expect(transporAcorde('Ab', 0), 'G#');
    expect(transporAcorde('Eb', 1), 'E');
  });
  test('sufixos complexos preservados', () {
    expect(transporAcorde('C#m7b5', 1), 'Dm7b5');
    expect(transporAcorde('G7+', 2), 'A7+');
    expect(transporAcorde('D°', 1), 'D#°');
  });
  test('slash chords transpostos nos dois lados', () {
    expect(transporAcorde('D/F#', 1), 'D#/G');
    expect(transporAcorde('G/B', -2), 'F/A');
    expect(transporAcorde('Em7/5-', 1), 'Fm7/5-');
  });
  test('módulo 12', () {
    expect(transporAcorde('C', 12), 'C');
    expect(transporAcorde('C', 13), 'C#');
    expect(transporAcorde('C', -13), 'B');
  });
  test('texto que não é acorde passa intacto', () {
    expect(transporAcorde('x', 1), 'x');
    expect(transporAcorde('', 1), '');
  });
}
