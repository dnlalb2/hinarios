// lib/ui/features/hino/partitura.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../domain/models/hino.dart';

String slugDeArquivo(Hino hino) =>
    hino.slug.replaceAll('/', '__').replaceAll('\t', '');

void abrirPartitura(BuildContext context, Hino hino) {
  showDialog<void>(
    context: context,
    builder: (_) => Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text('${hino.num}. ${hino.nome}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        body: InteractiveViewer(
          maxScale: 5,
          child: Center(
            child: SvgPicture.asset(
              'assets/partituras/${slugDeArquivo(hino)}.svg',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    ),
  );
}
