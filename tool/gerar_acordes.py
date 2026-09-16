#!/usr/bin/env python3
"""Gera assets/acordes.json a partir do chords-db (MIT).

Fonte: https://github.com/tombatossals/chords-db (lib/guitar.json).

O acervo usa os nomes de acorde como o povo escreve nas cifras do hinário
('A#', 'Cm', 'F#°', 'D/F#'), não como o dataset os batiza ('Bb', 'Csharp',
'dim'). Este script faz duas traduções:

  * raízes:  'Csharp' -> 'C#', 'Eb' -> 'D#', 'Ab' -> 'G#', 'Bb' -> 'A#'
    (nosso vocabulário é sempre com sustenidos, igual à transposição do app);
  * sufixos: 'major' -> '', 'minor' -> 'm', 'dim' -> '°', 'maj7' -> '7M',
    'aug7' -> '7+', 'sus4' -> '4' etc.

Além disso emite os acordes com baixo invertido (sufixos '/F', '/Bb' embaixo
da raiz), com a nota do baixo também sustenizada: 'C/F', 'C/D#'.

Saída: mapa acorde -> lista de até POSICOES_POR_ACORDE posições, cada uma com
frets (6 cordas; -1 = mudo, 0 = solta), fingers, baseFret e barres.

Uso: python3 tool/gerar_acordes.py [entrada] [saida]
"""

import json
import pathlib
import sys

ENTRADA_PADRAO = "/tmp/guitar.json"
SAIDA_PADRAO = "assets/acordes.json"

# nome da raiz no dataset -> nosso nome
RAIZES = {
    "C": "C",
    "Csharp": "C#",
    "D": "D",
    "Eb": "D#",
    "E": "E",
    "F": "F",
    "Fsharp": "F#",
    "G": "G",
    "Ab": "G#",
    "A": "A",
    "Bb": "A#",
    "B": "B",
}

# sufixo no dataset -> sufixo nosso (vocabulário das cifras do acervo)
SUFIXOS = {
    "major": "",
    "minor": "m",
    "7": "7",
    "m7": "m7",
    "maj7": "7M",
    "aug7": "7+",
    "9": "9",
    "dim": "°",
    "sus4": "4",
    "5": "5",
    "m7b5": "m7b5",
}

# bemol -> sustenido (mesma tabela da transposição em Dart)
ENARMONIA = {"Db": "C#", "Eb": "D#", "Gb": "F#", "Ab": "G#", "Bb": "A#"}

POSICOES_POR_ACORDE = 2


def sustenizar(nota):
    """'Bb' -> 'A#'; o que já é sustenido (ou desconhecido) fica igual."""
    return ENARMONIA.get(nota, nota)


def baixo_de(sufixo):
    """Sufixo '/Bb' -> '/A#'; '' (ou sem barra) -> None."""
    if not sufixo.startswith("/"):
        return None
    return "/" + sustenizar(sufixo[1:])


def posicao(bruta):
    return {
        "frets": bruta["frets"],
        "fingers": bruta["fingers"],
        "baseFret": bruta["baseFret"],
        "barres": bruta["barres"],
    }


def gerar(dados):
    acordes = dados["chords"]
    saida = {}
    faltando = []

    for raiz, nosso_nome in RAIZES.items():
        disponiveis = {c["suffix"]: c for c in acordes[raiz]}

        for sufixo_dataset, sufixo_nosso in SUFIXOS.items():
            chord = disponiveis.get(sufixo_dataset)
            if chord is None:
                faltando.append(f"{nosso_nome}{sufixo_nosso} (dataset: {raiz}/{sufixo_dataset})")
                continue
            chave = nosso_nome + sufixo_nosso
            saida[chave] = [posicao(p) for p in chord["positions"][:POSICOES_POR_ACORDE]]

        # Acordes com baixo invertido: no dataset o baixo vem como sufixo
        # ('/F' em 'C'), aqui vira parte do nome ('C/F'), com sustenido.
        for sufixo_dataset, chord in disponiveis.items():
            if not sufixo_dataset.startswith("/"):
                continue
            chave = nosso_nome + baixo_de(sufixo_dataset)
            saida[chave] = [posicao(p) for p in chord["positions"][:POSICOES_POR_ACORDE]]

    # Ordem estável (o diff do asset fica legível em revisão).
    return dict(sorted(saida.items())), faltando


def main():
    entrada = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ENTRADA_PADRAO)
    saida = pathlib.Path(sys.argv[2] if len(sys.argv) > 2 else SAIDA_PADRAO)

    dados = json.loads(entrada.read_text(encoding="utf-8"))
    acordes, faltando = gerar(dados)

    saida.parent.mkdir(parents=True, exist_ok=True)
    # Compacto de propósito: é asset gerado, não código para ler.
    saida.write_text(
        json.dumps(acordes, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )

    posicoes = sum(len(v) for v in acordes.values())
    com_duas = sum(1 for v in acordes.values() if len(v) > 1)
    print(f"{saida}: {len(acordes)} acordes, {posicoes} posições "
          f"({com_duas} acordes com 2 posições)")
    if faltando:
        print(f"{len(faltando)} combinações sem par no dataset:")
        for f in faltando:
            print(f"  - {f}")
    else:
        print("nenhuma combinação faltando")


if __name__ == "__main__":
    main()
