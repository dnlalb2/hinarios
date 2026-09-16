#!/usr/bin/env python3
"""Ajusta o flutter_service_worker.js para deploy em subpasta (GitHub Pages).

O Flutter gera o service worker calculando a chave do recurso como
`event.request.url.substring(origin.length + 1)`. Num deploy em subpasta
(ex.: https://usuario.github.io/hinarios/), uma navegacao para `/hinarios/`
produz a chave `hinarios/`, mas RESOURCES so contem chaves relativas ao
scope (`index.html`, `/`, `main.dart.js`, `assets/...`). O lookup falha, o
handler retorna e o navegador vai a rede -- offline isso vira
ERR_INTERNET_DISCONNECTED (a tela de "sem internet" do navegador).

Este script injeta, logo apos o calculo da chave, um strip do prefixo do
base-href, alinhando a chave com as chaves de RESOURCES.

Uso:
    python3 tool/patch_service_worker.py build/web/flutter_service_worker.js hinarios/

Comportamento:
- Idempotente: se o patch ja estiver presente, nao faz nada e sai com 0.
- Seguro: se a linha alvo nao existir (template do Flutter mudou), sai com
  codigo != 0 e mensagem clara -- o CI deve falhar alto em vez de publicar
  um service worker quebrado.
"""

import sys

# Linha exata do template do Flutter 3.35.1 (dentro do fetch handler).
ALVO = "var key = event.request.url.substring(origin.length + 1);"

# Marcador de idempotencia: se ja existir no arquivo, o patch foi aplicado.
MARCADOR = "// patch:base-href-subpasta"


def normalizar_prefixo(prefixo: str) -> str:
    """Devolve o prefixo no formato usado pelas chaves.

    As chaves derivam de `event.request.url.substring(origin.length + 1)`,
    ou seja, nao tem `/` inicial; e como a raiz do deploy e sempre um
    diretorio (`/hinarios/`), o prefixo termina em `/`. Aceita e normaliza
    `/hinarios/`, `hinarios/` e `hinarios`.
    """
    prefixo = prefixo.strip().lstrip("/")
    if prefixo and not prefixo.endswith("/"):
        prefixo += "/"
    return prefixo


def montar_patch(prefixo: str, recuo: str, nl: str) -> str:
    """Monta as linhas injetadas, com o recuo e o fim de linha do arquivo."""
    # Aspas simples sao o delimitador da string JS; escapa o que for preciso.
    literal = prefixo.replace("\\", "\\\\").replace("'", "\\'")
    return nl.join(
        [
            f"{recuo}// Patch (deploy em subpasta): a URL de navegacao/acesso chega",
            f"{recuo}// com o prefixo do base-href; o RESOURCES usa chaves relativas",
            f"{recuo}// ao scope. {MARCADOR}",
            f"{recuo}if (key.startsWith('{literal}')) {{ key = key.substring({len(prefixo)}); }}",
        ]
    )


def main(argv) -> int:
    if len(argv) != 3:
        print(__doc__.strip(), file=sys.stderr)
        print("\nErro: esperados 2 argumentos (arquivo e prefixo).", file=sys.stderr)
        return 2

    caminho, prefixo = argv[1], normalizar_prefixo(argv[2])

    if not prefixo:
        print("Prefixo vazio: deploy na raiz, nada a fazer.")
        return 0

    with open(caminho, "r", encoding="utf-8", newline="") as f:
        conteudo = f.read()

    if MARCADOR in conteudo:
        print(f"Patch ja aplicado em {caminho} (prefixo '{prefixo}'); nada a fazer.")
        return 0

    if ALVO not in conteudo:
        print(
            "ERRO: linha alvo nao encontrada em "
            f"{caminho}:\n    {ALVO}\n"
            "O template do service worker do Flutter mudou. Revise "
            "tool/patch_service_worker.py antes de publicar -- sem o patch o "
            "app NAO funciona offline em deploy de subpasta.",
            file=sys.stderr,
        )
        return 1

    nl = "\r\n" if "\r\n" in conteudo else "\n"
    linhas = conteudo.split(nl)
    saida = []
    for linha in linhas:
        saida.append(linha)
        if ALVO in linha:
            recuo = linha[: len(linha) - len(linha.lstrip())]
            saida.append(montar_patch(prefixo, recuo, nl))

    with open(caminho, "w", encoding="utf-8", newline="") as f:
        f.write(nl.join(saida))

    print(f"Service worker corrigido para o prefixo '{prefixo}': {caminho}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
