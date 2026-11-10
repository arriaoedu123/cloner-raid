"""Mina flutuante inimiga em pixel art 16x16 (vista de cima).

Uso: python3 tools/sprites/mine.py
Saída: assets/sprites/mine/mine_0.png (luz acesa), mine_1.png (luz apagada)

Esfera de metal cinza com 12 pinos de contato e uma luz vermelha no meio que pisca (o perigo).
Luz de cima: brilho claro no alto da esfera, metade de baixo escura.
"""
from style import ASSETS_DIR, blank, outline, to_rows, write_png

SIZE = 16
CENTER = 7.5
RADIUS = 4.6
PINS = ((7, 1), (8, 1), (7, 14), (8, 14), (1, 7), (1, 8), (14, 7), (14, 8),
        (3, 3), (12, 3), (3, 12), (12, 12))


def mine(lit: bool) -> list[str]:
    c = blank(SIZE, SIZE)
    for y in range(SIZE):
        for x in range(SIZE):
            d = ((x - CENTER) ** 2 + (y - CENTER) ** 2) ** 0.5
            if d <= RADIUS:
                if y <= 5 and d <= 3.2 and x <= 8:
                    c[y][x] = "w"  # brilho
                else:
                    c[y][x] = "s" if y >= 10 else "S"
    for x, y in PINS:
        c[y][x] = "s"
    for x, y in ((7, 7), (8, 7), (7, 8), (8, 8)):
        c[y][x] = "R" if lit else "r"
    return to_rows(outline(c))


FRAMES = {"mine_0": mine(lit=True), "mine_1": mine(lit=False)}

if __name__ == "__main__":
    for name, grid in FRAMES.items():
        path = ASSETS_DIR / "mine" / f"{name}.png"
        write_png(grid, path)
        print("gerado:", path)
