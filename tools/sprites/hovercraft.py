"""Aerobarco inimigo em pixel art 44x26 (vista de cima, proa para a DIREITA).

Uso: python3 tools/sprites/hovercraft.py
Saída: assets/sprites/hovercraft/hovercraft_0.png, hovercraft_1.png (hélices em + e em x)

Casco retangular arredondado vermelho (inimigo) com luz de cima e faixa clara no eixo, saia de
borracha cinza-escura em volta (o colchão de ar), cabine de vidro na proa, portas de carga
cinza e DUAS hélices em dutos de metal na popa, com pás k que giram entre os frames.
É maior que o navio (40x18) e o avião (32x32): é um barco de carga militar.
"""
from style import ASSETS_DIR, blank, outline, overlay, to_rows, write_png

W, H = 44, 26
DUCTS = ((7, 8), (7, 17))  # centro das hélices (x, y)
DUCT_R = 4


def rounded_rect(x0: int, y0: int, x1: int, y1: int, r: int) -> set:
    pts = set()
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            cx = min(max(x, x0 + r), x1 - r)
            cy = min(max(y, y0 + r), y1 - r)
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r + 0.5:
                pts.add((x, y))
    return pts


def body() -> list[list[str]]:
    c = blank(W, H)
    for x, y in rounded_rect(4, 2, 40, 23, 6):
        c[y][x] = "s"  # saia de borracha
    for x, y in rounded_rect(7, 5, 37, 20, 4):
        c[y][x] = "p" if y <= 6 else ("r" if y >= 19 else "R")
    for x in range(10, 33):  # faixa clara no eixo
        c[12][x] = "p"
    for y in range(9, 17):  # cabine de vidro na proa (brilho em cima)
        for x in (31, 32, 33):
            c[y][x] = "B" if y <= 12 else "b"
    c[9][32] = c[10][32] = "c"
    for x in range(16, 24):  # portas de carga
        c[8][x] = c[17][x] = "S"
    return c


def fans(diagonal: bool) -> list[list[str]]:
    c = blank(W, H)
    for cx, cy in DUCTS:
        for y in range(cy - DUCT_R, cy + DUCT_R + 1):
            for x in range(cx - DUCT_R, cx + DUCT_R + 1):
                d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
                if d <= DUCT_R + 0.3:
                    c[y][x] = "S" if y < cy else "s"
                if d <= DUCT_R - 1.2:
                    c[y][x] = "b"  # fundo do duto
        for d in range(-(DUCT_R - 2), DUCT_R - 1):
            if diagonal:
                c[cy + d][cx + d] = c[cy + d][cx - d] = "k"
            else:
                c[cy][cx + d] = c[cy + d][cx] = "k"
        c[cy][cx] = "w"
    return c


FRAMES = {
    "hovercraft_0": to_rows(outline(overlay(body(), fans(diagonal=False)))),
    "hovercraft_1": to_rows(outline(overlay(body(), fans(diagonal=True)))),
}

if __name__ == "__main__":
    for name, grid in FRAMES.items():
        path = ASSETS_DIR / "hovercraft" / f"{name}.png"
        write_png(grid, path)
        print("gerado:", path)
