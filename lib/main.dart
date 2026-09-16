// lib/main.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/repositories/hinos_repository.dart';
import 'data/services/acordes_service.dart';
import 'data/services/cifras_locais_service.dart';
import 'data/services/hinos_service.dart';
import 'data/services/instalacao_service.dart';
import 'data/services/precache_service.dart';
import 'data/services/preferencias_service.dart';
import 'ui/core/cifras_locais_view_model.dart';
import 'ui/core/instalacao_view_model.dart';
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
  // O serviço de instalação já entra na página ouvindo `beforeinstallprompt`
  // (construção da instância única): o evento pode chegar antes do primeiro
  // quadro, e quem chega depois o encontra guardado.
  final instalacao = InstalacaoViewModel(service: InstalacaoService.instancia);
  // Acorda o acervo de acordes (~40 KB) sem esperar: assim ele entra no cache
  // do service worker já na primeira visita, mesmo que ninguém toque num
  // acorde. Fora da web é só uma leitura de asset que ficaria no bundle.
  unawaited(AcordesService.instancia.carregar());
  runApp(HinariosApp(
    preferencias: preferencias,
    hinosRepository: hinosRepo,
    cifrasLocais: cifrasLocais,
    precache: precache,
    instalacao: instalacao,
  ));
  // O banner só aparece quando o navegador avisar (ou no iPhone): o aviso vira
  // rebuild a partir daqui.
  instalacao.iniciar();
  // Depois do primeiro quadro: confere o que já está em cache e baixa o que
  // falta — partituras e acordes inclusive —, asset por asset, com a tela de
  // preparação mostrando o progresso. A conferida é local e barata (não disputa
  // banda com o boot); o download é do próprio app, para o progresso ser real
  // (o service worker cacheia cada requisição que passa por ele). Fora da web
  // é um no-op.
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
    required this.instalacao,
  });

  final PreferenciasViewModel preferencias;
  final HinosRepository hinosRepository;
  final CifrasLocaisViewModel cifrasLocais;
  final PrecacheViewModel precache;
  final InstalacaoViewModel instalacao;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: preferencias),
        ChangeNotifierProvider.value(value: cifrasLocais),
        ChangeNotifierProvider.value(value: precache),
        ChangeNotifierProvider.value(value: instalacao),
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
