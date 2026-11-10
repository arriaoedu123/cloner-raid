"""Navio inimigo em pixel art 40x18 (vista de cima, proa para a DIREITA).

Uso: python3 tools/sprites/ship.py
Saída: assets/sprites/ship/ship_0.png, ship_1.png (2 frames de espuma na popa)

Casco com borda vermelha de 2 px (inimigo) e convés cinza; cabine vermelha com
janelas azuis, chaminé e canhão cinza na proa. Espuma da esteira sem contorno.
"""
from style import ASSETS_DIR, blank, outline, overlay, to_rows, write_png

W, H = 40, 18

# Casco: linha -> (popa, proa). Popa quase reta, proa arredondada em ponta.
HULL = {3: (6, 27), 4: (5, 31), 5: (4, 33), 6: (4, 35), 7: (4, 36), 8: (4, 37),
        9: (4, 37), 10: (4, 36), 11: (4, 35), 12: (4, 33), 13: (5, 31), 14: (6, 27)}
RIM = 2  # largura da borda vermelha do casco

WAKE = [
    {(3, 6): "c", (2, 7): "w", (1, 8): "c", (2, 9): "w", (3, 11): "c", (0, 10): "c", (1, 5): "c",
     (7, 2): "c", (10, 2): "c", (8, 15): "c", (11, 15): "c", (0, 7): "c"},
    {(3, 7): "c", (2, 8): "w", (1, 9): "c", (3, 12): "c", (2, 5): "c", (0, 8): "c", (1, 11): "w",
     (6, 2): "c", (9, 2): "c", (7, 15): "c", (10, 15): "c", (12, 15): "c"},
]


def in_hull(x: int, y: int) -> bool:
    return y in HULL and HULL[y][0] <= x <= HULL[y][1]


def body() -> list[list[str]]:
    c = blank(W, H)
    for y, (x0, x1) in HULL.items():
        for x in range(x0, x1 + 1):
            # é borda se algum vizinho até RIM px de distância está fora do casco
            rim = any(not in_hull(x + dx, y + dy)
                      for dx in range(-RIM, RIM + 1) for dy in range(-RIM, RIM + 1)
                      if abs(dx) + abs(dy) <= RIM)
            if rim:
                c[y][x] = "p" if y <= 5 else ("r" if y >= 12 else "R")
            else:
                c[y][x] = "w" if y <= 6 else ("s" if y >= 11 else "S")
    # cabine vermelha
    for y in range(6, 12):
        for x in range(11, 20):
            c[y][x] = "p" if y == 6 else ("r" if y == 11 else "R")
    for y in range(7, 11):  # janelas viradas para a proa
        c[y][19] = "c" if y <= 8 else "B"
    # chaminé
    for y in (8, 9):
        for x in (13, 14):
            c[y][x] = "k"
    # canhão na proa
    for y in range(7, 11):
        for x in range(25, 28):
            c[y][x] = "S" if y < 10 else "s"
    for x in range(28, 33):
        c[8][x] = "k"
    return outline(c)


def frame(wake: dict) -> list[str]:
    base = body()
    top = blank(W, H)
    for (x, y), ch in wake.items():
        if base[y][x] == ".":  # espuma só sobre a água
            top[y][x] = ch
    return to_rows(overlay(base, top))


FRAMES = {f"ship_{i}": frame(w) for i, w in enumerate(WAKE)}

if __name__ == "__main__":
    for name, grid in FRAMES.items():
        path = ASSETS_DIR / "ship" / f"{name}.png"
        write_png(grid, path)
        print("gerado:", path)
