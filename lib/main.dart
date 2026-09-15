// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/repositories/hinos_repository.dart';
import 'data/services/hinos_service.dart';
import 'data/services/preferencias_service.dart';
import 'ui/core/preferencias_view_model.dart';
import 'ui/core/theme_color.dart';
import 'ui/core/tema.dart';
import 'ui/features/biblioteca/biblioteca_view.dart';
import 'ui/features/biblioteca/biblioteca_view_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferencias = PreferenciasViewModel(service: PreferenciasService());
  await preferencias.restaurar();
  final hinosRepo = HinosRepository(service: HinosService());
  await hinosRepo.carregar();
  runApp(HinariosApp(preferencias: preferencias, hinosRepository: hinosRepo));
}

class HinariosApp extends StatelessWidget {
  const HinariosApp({super.key, required this.preferencias, required this.hinosRepository});

  final PreferenciasViewModel preferencias;
  final HinosRepository hinosRepository;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: preferencias),
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
            home: const BibliotecaView(),
          );
        },
      ),
    );
  }
}
