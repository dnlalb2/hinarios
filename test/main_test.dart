// test/main_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hinarios_app/data/repositories/hinos_repository.dart';
import 'package:hinarios_app/data/services/cifras_locais_service.dart';
import 'package:hinarios_app/data/services/hinos_service.dart';
import 'package:hinarios_app/data/services/instalacao_service.dart';
import 'package:hinarios_app/data/services/precache_service.dart';
import 'package:hinarios_app/data/services/preferencias_service.dart';
import 'package:hinarios_app/main.dart';
import 'package:hinarios_app/ui/core/cifras_locais_view_model.dart';
import 'package:hinarios_app/ui/core/instalacao_view_model.dart';
import 'package:hinarios_app/ui/core/precache_view_model.dart';
import 'package:hinarios_app/ui/core/preferencias_view_model.dart';

void main() {
  testWidgets('app inicia com os providers', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferencias = PreferenciasViewModel(service: PreferenciasService());
    final cifras = CifrasLocaisViewModel(service: CifrasLocaisService());
    await cifras.restaurar(); // como no main()
    final hinosRepo = HinosRepository(service: HinosService());
    await tester.runAsync(() => hinosRepo.carregar()); // main() também carrega antes do runApp
    // Fora da web o precache não se aplica (-1): a preparação nem aparece.
    final precache = PrecacheViewModel(service: const PrecacheService());
    await precache.iniciar(); // main() chama depois do primeiro quadro
    // Fora da web não há PWA a instalar: o serviço real cai no stub.
    final instalacao = InstalacaoViewModel(service: InstalacaoService.instancia);
    instalacao.iniciar(); // main() chama depois do runApp
    await tester.pumpWidget(
      HinariosApp(
        preferencias: preferencias,
        hinosRepository: hinosRepo,
        cifrasLocais: cifras,
        precache: precache,
        instalacao: instalacao,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Scaffold), findsWidgets);
    expect(find.text('Preparando o hinário para uso offline…'), findsNothing);
  });
}
