// lib/main.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/repositories/hinos_repository.dart';
import 'data/services/acordes_service.dart';
import 'data/services/cifras_locais_service.dart';
import 'data/services/hinos_service.dart';
import 'data/services/precache_service.dart';
import 'data/services/preferencias_service.dart';
import 'ui/core/cifras_locais_view_model.dart';
import 'ui/core/precache_view_model.dart';
import 'ui/core/preferencias_view_model.dart';
import 'ui/core/theme_color.dart';
import 'ui/core/tema.dart';
import 'ui/core/widgets/precache_gate.dart';
import 'ui/features/biblioteca/biblioteca_view.dart';
import 'ui/features/biblioteca/biblioteca_view_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferencias = PreferenciasViewModel(service: PreferenciasService());
  await preferencias.restaurar();
  final cifrasLocais = CifrasLocaisViewModel(service: CifrasLocaisService());
  await cifrasLocais.restaurar();
  final hinosRepo = HinosRepository(service: HinosService());
  await hinosRepo.carregar();
  final precache = PrecacheViewModel(service: const PrecacheService());
  // Acorda o acervo de acordes (~40 KB) sem esperar: assim ele entra no cache
  // do service worker já na primeira visita, mesmo que ninguém toque num
  // acorde. Fora da web é só uma leitura de asset que ficaria no bundle.
  unawaited(AcordesService.instancia.carregar());
  runApp(HinariosApp(
    preferencias: preferencias,
    hinosRepository: hinosRepo,
    cifrasLocais: cifrasLocais,
    precache: precache,
  ));
  // Depois do primeiro quadro: confere o que já está em cache e pede ao
  // service worker o download do que falta — partituras e acordes inclusive.
  // A conferida é local e barata (não disputa banda com o boot); o download
  // em si acontece no service worker. Fora da web é um no-op.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(precache.iniciar());
  });
}

class HinariosApp extends StatelessWidget {
  const HinariosApp({
    super.key,
    required this.preferencias,
    required this.hinosRepository,
    required this.cifrasLocais,
    required this.precache,
  });

  final PreferenciasViewModel preferencias;
  final HinosRepository hinosRepository;
  final CifrasLocaisViewModel cifrasLocais;
  final PrecacheViewModel precache;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: preferencias),
        ChangeNotifierProvider.value(value: cifrasLocais),
        ChangeNotifierProvider.value(value: precache),
        Provider<HinosRepository>.value(value: hinosRepository),
        ChangeNotifierProvider<BibliotecaViewModel>(
          create: (_) => BibliotecaViewModel(hinos: hinosRepository, preferencias: preferencias),
        ),
      ],
      child: Consumer<PreferenciasViewModel>(
        builder: (context, s, _) {
          final tema = s.temaEscuro ? temaEscuro() : temaClaro();
          // A barra de status do PWA (meta theme-color) acompanha o tema,
          // inclusive na primeira renderização. Fora da web é um no-op.
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => atualizarThemeColor(tema.colorScheme.surface.toARGB32()),
          );
          return MaterialApp(
            title: 'Hinário Cifrado Céu de São José',
            debugShowCheckedModeBanner: false,
            theme: tema,
            darkTheme: temaEscuro(),
            themeMode: s.temaEscuro ? ThemeMode.dark : ThemeMode.light,
            // A tela de preparação cobre a biblioteca no primeiro acesso,
            // enquanto o service worker baixa o acervo inteiro.
            home: PrecacheGate(child: const BibliotecaView()),
          );
        },
      ),
    );
  }
}
