// test/acorde_shape_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinarios_app/domain/models/acorde_shape.dart';

void main() {
  // Uma posição do chords-db, do jeito que ela sai do nosso asset:
  // frets relativos ao baseFret (-1 mudo, 0 solta), dedos e barres.
  const bruto = {
    'frets': [-1, 3, 2, 0, 1, 0],
    'fingers': [0, 3, 2, 0, 1, 0],
    'baseFret': 1,
    'barres': <int>[],
  };

  test('fromJson lê frets, fingers, baseFret e barres', () {
    final shape = AcordeShape.fromJson(bruto);
    expect(shape.frets, [-1, 3, 2, 0, 1, 0]);
    expect(shape.fingers, [0, 3, 2, 0, 1, 0]);
    expect(shape.baseFret, 1);
    expect(shape.barres, isEmpty);
  });

  test('fromJson sobrevive à ida e volta pelo jsonEncode', () {
    final comBarre = {
      'frets': [-1, 1, 2, 1, 2, -1],
      'fingers': [0, 1, 3, 2, 4, 0],
      'baseFret': 4,
      'barres': [1],
    };
    final shape = AcordeShape.fromJson(
        jsonDecode(jsonEncode(comBarre)) as Map<String, dynamic>);
    expect(shape.frets, comBarre['frets']);
    expect(shape.fingers, comBarre['fingers']);
    expect(shape.baseFret, 4);
    expect(shape.barres, [1]);
  });
}
