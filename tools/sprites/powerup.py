"""Caixas de power-up em pixel art 16x16 (vista de cima), flutuando no rio.

Uso: python3 tools/sprites/powerup.py
Saída: assets/sprites/powerup/<nome>.png

Caixa de madeira (terracota, luz de cima: borda de cima clara, de baixo escura) com uma
placa escura no meio e o símbolo do power-up (8x8) na cor dele.
"""
from style import ASSETS_DIR, outline, to_rows, write_png

# Símbolos 8x8 sobre fundo k
SYMBOLS = {
    # tiro duplo: dois tiros lado a lado (laranja, ponta clara)
    "powerup_double": [
        "kkkkkkkk",
        "kffkkffk",
        "kffkkffk",
        "kffkkffk",
        "kffkkffk",
        "kOOkkOOk",
        "kOOkkOOk",
        "kkkkkkkk",
    ],
    # escudo: brasão azul, borda de cima clara, faixa clara no eixo, pontas de baixo escuras
    "powerup_shield": [
        "kkkkkkkk",
        "kcccccck",
        "kBBccBBk",
        "kBBccBBk",
        "kbBccBbk",
        "kkbBBbkk",
        "kkkbbkkk",
        "kkkkkkkk",
    ],
    # vida extra: aviãozinho amarelo (como o ícone de vidas do HUD), cabine azul
    "powerup_life": [
        "kkkkkkkk",
        "kkkBBkkk",
        "kkkllkkk",
        "kYYllYYk",
        "kyyllyyk",
        "kkkllkkk",
        "kkYllYkk",
        "kkkkkkkk",
    ],
}


def crate(symbol: list[str]) -> list[str]:
    rows = ["mmmmmmmmmmmmmm", "mNNNNNNNNNNNNn", "mNssssssssssNn"]
    rows += ["mNs" + line + "sNn" for line in symbol]
    rows += ["mNssssssssssNn", "mNNNNNNNNNNNNn", "nnnnnnnnnnnnnn"]
    canvas = [["."] * 16 for _ in range(16)]
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            canvas[1 + y][1 + x] = ch
    return to_rows(outline(canvas))


POWERUPS = {name: crate(symbol) for name, symbol in SYMBOLS.items()}
FRAMES = POWERUPS

if __name__ == "__main__":
    for name, grid in POWERUPS.items():
        path = ASSETS_DIR / "powerup" / f"{name}.png"
        write_png(grid, path)
        print("gerado:", path)
