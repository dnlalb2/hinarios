// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/repositories/hinos_repository.dart';
import 'data/services/hinos_service.dart';
import 'data/services/preferencias_service.dart';
import 'ui/core/preferencias_view_model.dart';
import 'ui/core/tema.dart';
import 'ui/features/biblioteca/biblioteca_view.dart';

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
      ],
      child: Consumer<PreferenciasViewModel>(
        builder: (context, s, _) => MaterialApp(
          title: 'Hinários EstudoFino',
          debugShowCheckedModeBanner: false,
          theme: temaClaro(),
          darkTheme: temaEscuro(),
          themeMode: s.temaEscuro ? ThemeMode.dark : ThemeMode.light,
          home: const BibliotecaView(),
        ),
      ),
    );
  }
}
