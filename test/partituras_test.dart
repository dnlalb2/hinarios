// test/partituras_test.dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('partitura SVG do primeiro hino com abc existe e é válida', () async {
    final dados = jsonDecode(await rootBundle.loadString('assets/dados.json')) as List;
    final comAbc = dados.firstWhere((d) => (d['abc'] as String? ?? '').isNotEmpty);
    final slug = (comAbc['slug'] as String).replaceAll('/', '__').replaceAll('\t', '');
    final svg = await rootBundle.loadString('assets/partituras/$slug.svg');
    expect(svg, contains('<svg'));
  });
}
