"""Decoração das margens em pixel art (vista de cima): árvores, arbusto, pedra e casa.

Uso: python3 tools/sprites/decorations.py
Saída: assets/sprites/decorations/<nome>.png

Só enfeite (sem colisão). Luz de cima como em todo o jogo: claro em cima, escuro embaixo.
A sombra vem embutida no PNG (with_shadow); o centro do sprite continua no mesmo lugar.
A ordem de DECORATIONS precisa ser a mesma de DECOR_TEXTURES em scripts/river.gd.
"""
from style import ASSETS_DIR, blank, outline, to_rows, with_shadow, write_png


def disk(c, cx: float, cy: float, r: float, light: str, base: str, dark: str) -> None:
    for y in range(len(c)):
        for x in range(len(c[0])):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            if dx * dx + dy * dy <= r * r:
                c[y][x] = light if dy < -r * 0.35 else (dark if dy > r * 0.4 else base)


def tree_round() -> list[str]:
    """Copa redonda com um tufo de brilho."""
    c = blank(16, 16)
    # copa mais escura que o gramado (G), senão some no chão
    disk(c, 8, 8, 6.5, "G", "g", "g")
    c[4][6] = c[4][7] = c[5][5] = "h"
    return to_rows(outline(c))


def tree_pine() -> list[str]:
    """Pinheiro visto de cima: estrela de galhos, mais escuro."""
    rows = [
        ".....g.....",
        "....gGg....",
        "..g.gGg.g..",
        "...gGhGg...",
        ".ggGGhGGgg.",
        "gGGGhhhGGGg",
        ".ggGGGGGgg.",
        "...gGGGg...",
        "..g.gGg.g..",
        "....ggg....",
        ".....g.....",
    ]
    c = blank(13, 13)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                c[1 + y][1 + x] = ch
    return to_rows(outline(c))


def bush() -> list[str]:
    c = blank(12, 9)
    disk(c, 4, 4.5, 3, "G", "g", "g")
    disk(c, 7.5, 4.5, 3, "G", "g", "g")
    c[3][3] = c[3][7] = "h"
    return to_rows(outline(c))


def rock() -> list[str]:
    c = blank(10, 8)
    disk(c, 5, 4, 3.2, "w", "S", "s")
    c[3][3] = "w"
    return to_rows(outline(c))


def house() -> list[str]:
    """Casa de telhado de duas águas: metade de cima iluminada, cumeeira escura, chaminé."""
    w, h = 20, 16
    c = blank(w, h)
    for y in range(2, 14):
        for x in range(2, 18):
            if y < 7:
                c[y][x] = "m"      # água do telhado virada para a luz
            elif y == 7:
                c[y][x] = "n"      # cumeeira
            else:
                c[y][x] = "N" if y < 12 else "n"
    for y in (3, 4):               # chaminé
        for x in (13, 14):
            c[y][x] = "S"
    c[3][13] = "w"
    return to_rows(outline(c))


# Sombra embutida (dx, dy): quanto mais alto o enfeite, mais longe ela cai
DECORATIONS = {
    "tree_round": with_shadow(tree_round(), 2, 3),
    "tree_pine": with_shadow(tree_pine(), 2, 3),
    "bush": with_shadow(bush(), 1, 2),
    "rock": with_shadow(rock(), 1, 1),
    "house": with_shadow(house(), 2, 3),
}
FRAMES = DECORATIONS

if __name__ == "__main__":
    for name, grid in DECORATIONS.items():
        path = ASSETS_DIR / "decorations" / f"{name}.png"
        write_png(grid, path)
        print("gerado:", path)
