// test/main_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinarios_app/data/repositories/hinos_repository.dart';
import 'package:hinarios_app/data/services/hinos_service.dart';
import 'package:hinarios_app/data/services/preferencias_service.dart';
import 'package:hinarios_app/main.dart';
import 'package:hinarios_app/ui/core/preferencias_view_model.dart';

void main() {
  testWidgets('app inicia com os providers', (tester) async {
    final preferencias = PreferenciasViewModel(service: PreferenciasService());
    final hinosRepo = HinosRepository(service: HinosService());
    await tester.pumpWidget(
      HinariosApp(preferencias: preferencias, hinosRepository: hinosRepo),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Scaffold), findsWidgets);
  });
}
