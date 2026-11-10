"""Lancha inimiga em pixel art 24x12 (vista de cima, proa para a DIREITA).

Uso: python3 tools/sprites/speedboat.py
Saída: assets/sprites/speedboat/speedboat_0.png, speedboat_1.png (2 frames de respingo na popa)

Lancha de corrida: casco vermelho fino (inimigo) com luz de cima, faixa branca de corrida,
para-brisa azul com brilho, banco cinza e motor de popa cinza. Respingos sem contorno.
"""
from style import ASSETS_DIR, blank, outline, overlay, to_rows, write_png

W, H = 24, 12

# Casco: linha -> (popa, proa); proa em ponta comprida
HULL = {3: (4, 15), 4: (3, 18), 5: (3, 20), 6: (3, 21), 7: (3, 20), 8: (3, 18), 9: (4, 15)}

SPRAY = [
    {(0, 5): "c", (1, 7): "w", (0, 8): "c", (5, 1): "c", (8, 11): "c", (1, 4): "w"},
    {(0, 6): "w", (1, 8): "c", (0, 4): "c", (6, 1): "c", (9, 11): "c", (1, 3): "c"},
]


def body() -> list[list[str]]:
    c = blank(W, H)
    for y, (x0, x1) in HULL.items():
        for x in range(x0, x1 + 1):
            c[y][x] = "p" if y == 3 else ("r" if y == 9 else "R")
    # faixa branca de corrida no eixo do casco
    for x in range(5, 19):
        c[6][x] = "w"
    # para-brisa (vidro azul, brilho em cima) e banco
    for y in (4, 5, 7, 8):
        c[y][12] = "B" if y <= 5 else "b"
    c[4][12] = "c"
    for y in range(5, 8):
        c[y][9] = c[y][10] = "s"
    # motor de popa
    for y in (5, 6, 7):
        c[y][2] = "S" if y < 7 else "s"
    return outline(c)


def frame(spray: dict) -> list[str]:
    base = body()
    top = blank(W, H)
    for (x, y), ch in spray.items():
        if base[y][x] == ".":  # respingo só sobre a água
            top[y][x] = ch
    return to_rows(overlay(base, top))


FRAMES = {f"speedboat_{i}": frame(s) for i, s in enumerate(SPRAY)}

if __name__ == "__main__":
    for name, grid in FRAMES.items():
        path = ASSETS_DIR / "speedboat" / f"{name}.png"
        write_png(grid, path)
        print("gerado:", path)
