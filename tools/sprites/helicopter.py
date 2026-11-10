"""Helicóptero inimigo em pixel art 24x24 (vista de cima, nariz para a DIREITA).

Uso: python3 tools/sprites/helicopter.py
Saída: assets/sprites/helicopter/heli_0.png, heli_1.png (hélice em + e em x)

Objetos que andam de lado são desenhados virados para a direita;
no jogo, o sprite é espelhado (flip_h) quando anda para a esquerda.
"""
from style import ASSETS_DIR, blank, outline, overlay, to_rows, write_png

SIZE = 24
ROTOR_HUB = (15, 11)  # (x, y)

# Cabine: linha -> (coluna inicial, coluna final), formato arredondado
CABIN = {8: (12, 18), 9: (11, 19), 10: (10, 20), 11: (10, 20),
         12: (10, 20), 13: (10, 20), 14: (11, 19), 15: (12, 18)}
GLASS_FROM_X = 17


def body() -> list[list[str]]:
    c = blank(SIZE, SIZE)
    # cabine: luz vem de cima (linhas de cima claras, de baixo escuras)
    for y, (x0, x1) in CABIN.items():
        for x in range(x0, x1 + 1):
            if x >= GLASS_FROM_X:
                c[y][x] = "b" if y >= 14 else "B"
            else:
                c[y][x] = "p" if y <= 9 else ("R" if y <= 12 else "r")
    c[10][18] = c[10][19] = "c"  # brilho do vidro
    # cauda
    for x in range(3, 10):
        c[11][x] = "R"
        c[12][x] = "r"
    # rotor de cauda (visto de cima é um traço)
    for y in range(9, 15):
        c[y][2] = "S"
    return outline(c)


def rotor(diagonal: bool) -> list[list[str]]:
    """Pás na cor do contorno: contrastam tanto com a água quanto com o corpo."""
    c = blank(SIZE, SIZE)
    hx, hy = ROTOR_HUB
    if diagonal:
        for d in range(1, 8):
            for sx, sy in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
                c[hy + sy * d][hx + sx * d] = "k"
    else:
        for d in range(1, 9):
            c[hy][hx + d] = c[hy][hx - d] = "k"
            c[hy + d][hx] = c[hy - d][hx] = "k"
    c[hy][hx] = "S"
    return c


FRAMES = {
    "heli_0": to_rows(overlay(body(), rotor(diagonal=False))),
    "heli_1": to_rows(overlay(body(), rotor(diagonal=True))),
}

if __name__ == "__main__":
    for name, grid in FRAMES.items():
        path = ASSETS_DIR / "helicopter" / f"{name}.png"
        write_png(grid, path)
        print("gerado:", path)
