// test/main_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hinarios_app/data/repositories/hinos_repository.dart';
import 'package:hinarios_app/data/services/cifras_locais_service.dart';
import 'package:hinarios_app/data/services/hinos_service.dart';
import 'package:hinarios_app/data/services/preferencias_service.dart';
import 'package:hinarios_app/main.dart';
import 'package:hinarios_app/ui/core/cifras_locais_view_model.dart';
import 'package:hinarios_app/ui/core/preferencias_view_model.dart';

void main() {
  testWidgets('app inicia com os providers', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferencias = PreferenciasViewModel(service: PreferenciasService());
    final cifras = CifrasLocaisViewModel(service: CifrasLocaisService());
    await cifras.restaurar(); // como no main()
    final hinosRepo = HinosRepository(service: HinosService());
    await tester.runAsync(() => hinosRepo.carregar()); // main() também carrega antes do runApp
    await tester.pumpWidget(
      HinariosApp(
        preferencias: preferencias,
        hinosRepository: hinosRepo,
        cifrasLocais: cifras,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Scaffold), findsWidgets);
  });
}
