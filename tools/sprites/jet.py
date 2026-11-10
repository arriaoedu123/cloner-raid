"""Jato inimigo em pixel art 28x22 (vista de cima, nariz para a DIREITA).

Uso: python3 tools/sprites/jet.py
Saída: assets/sprites/jet/jet_0.png, jet_1.png (chama da pós-combustão piscando)

Vermelho (inimigo), asas em flecha, cockpit azul perto do nariz.
Luz de cima: asa de cima clara, asa de baixo escura. Chama sem contorno.
"""
from style import ASSETS_DIR, blank, outline, overlay, to_rows, write_png

W, H = 28, 22

# Asa de cima: linha -> (x início, x fim). A de baixo é o espelho (linha 21 - y).
UPPER_WING = {2: (11, 12), 3: (10, 12), 4: (10, 13), 5: (9, 14), 6: (9, 15), 7: (9, 16), 8: (9, 17)}
UPPER_FIN = {6: (4, 5), 7: (4, 6), 8: (4, 7)}
FLAMES = [
    {(2, 10): "O", (2, 11): "O", (1, 10): "O", (1, 11): "f"},
    {(2, 10): "f", (2, 11): "O", (1, 10): "O", (1, 11): "O", (0, 10): "O", (0, 11): "O"},
]


def body() -> list[list[str]]:
    c = blank(W, H)
    for part in (UPPER_WING, UPPER_FIN):
        for y, (x0, x1) in part.items():
            for x in range(x0, x1 + 1):
                c[y][x] = "p" if y <= 4 else "R"     # asa de cima: clara
                c[21 - y][x] = "r"                   # asa de baixo: escura
    # fuselagem
    for x in range(4, 25):
        rows = range(9, 13) if x <= 21 else range(10, 12)
        for y in rows:
            c[y][x] = "p" if y == 9 else ("r" if y == 12 else "R")
    # cockpit
    for x in (18, 19, 20):
        c[10][x] = c[11][x] = "B"
    c[10][19] = "c"
    return outline(c)


def frame(flame: dict) -> list[str]:
    top = blank(W, H)
    for (x, y), ch in flame.items():
        top[y][x] = ch
    return to_rows(overlay(body(), top))


FRAMES = {f"jet_{i}": frame(f) for i, f in enumerate(FLAMES)}

if __name__ == "__main__":
    for name, grid in FRAMES.items():
        path = ASSETS_DIR / "jet" / f"{name}.png"
        write_png(grid, path)
        print("gerado:", path)
