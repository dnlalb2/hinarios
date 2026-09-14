# Hinários EstudoFino Offline

App Flutter com os hinários do Santo Daime — 100% offline. Letras com
cifras alinhadas sobre cada linha, transposição de tom por meio-tom
(por hino, persistida), busca, favoritos, tema escuro, controle de
tamanho de fonte e partituras (SVG). Dados extraídos publicamente de
https://estudofino.org/ (uso pessoal).

## Rodar

    flutter pub get
    flutter run -d chrome        # teste
    flutter build apk            # Android (instalar no celular)

## Arquitetura

Camadas: `ui/` (MVVM — views + view_models, widgets compartilhados em
`ui/core/`), `domain/` (models + use_cases puros), `data/` (services +
repositories). DI via `provider`. Ver
`../docs/superpowers/specs/2026-08-27-hinarios-flutter-app-design.md`.

## Dados

- `assets/dados.json` — cópia de `../offline/dados.json`.
- `assets/partituras/*.svg` — pré-renderizadas com abcm2ps
  (`python3 ../offline/gerar_partituras.py`).
- Re-extrair dados: ver `../offline/README.txt`.

## Testes

    flutter test
