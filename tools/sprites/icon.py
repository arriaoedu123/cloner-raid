"""Ícone do jogo em pixel art 64x64: o avião amarelo atirando, no rio entre as margens.

Uso: python3 tools/sprites/icon.py
Saída: assets/icon/icon.png (1024x1024 = 64 px ampliados 16x, sem suavização)

Usa os sprites de verdade (player.py, bullet.py) e desenha margens, espuma e ondinhas
do mesmo jeito que o rio do jogo (river.gd / water.gdshader).
"""
from style import ASSETS_DIR, blank, to_rows, write_png
import bullet
import player

SIZE = 64
RADIUS = 9  # cantos arredondados
OUT = ASSETS_DIR.parent / "icon" / "icon.png"


def inside(x: int, y: int) -> bool:
    """Quadrado arredondado de 1 a 62 (a coluna/linha 0 e 63 ficam para o contorno)."""
    lo, hi = 1 + RADIUS, SIZE - 2 - RADIUS
    dx = max(lo - x, 0, x - hi)
    dy = max(lo - y, 0, y - hi)
    return dx * dx + dy * dy <= RADIUS * RADIUS


def is_land(x: int, y: int) -> bool:
    """Margens em degraus: o rio alarga no meio, onde está o avião."""
    if y < 20:
        left, right = 12, 51
    elif y < 44:
        left, right = 8, 55
    else:
        left, right = 13, 50
    return x < left or x > right


def draw() -> list[str]:
    c = blank(SIZE, SIZE)
    for y in range(SIZE):
        for x in range(SIZE):
            if not inside(x, y):
                continue
            if not is_land(x, y):
                c[y][x] = "b"  # água (mesma cor do jogo)
                continue
            # terra: contorno k colado na água, faixa clara h de 2 px atrás dele (como no rio)
            near = lambda d: any(not is_land(x + dx, y + dy) for dx, dy in ((d, 0), (-d, 0), (0, d), (0, -d)))
            c[y][x] = "k" if near(1) else ("h" if near(2) or near(3) else "G")

    # espuma tracejada do lado da água, colada na terra
    for y in range(SIZE):
        for x in range(SIZE):
            if c[y][x] == "b" and any(is_land(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                if (x + y) % 4 < 2:
                    c[y][x] = "c"

    # ondinhas (B) longe do avião
    for x, y in ((18, 6), (40, 12), (13, 30), (47, 36), (20, 54), (39, 58)):
        for i in range(3):
            if c[y][x + i] == "b":
                c[y][x + i] = "B"

    def stamp(grid: list[str], ox: int, oy: int) -> None:
        for y, row in enumerate(grid):
            for x, ch in enumerate(row):
                if ch != ".":
                    c[oy + y][ox + x] = ch

    stamp(player.FRAMES["plane_center"], 16, 18)
    stamp(bullet.PLAYER_BULLET, 30, 7)

    # recorta o quadrado arredondado e contorna. Aqui o contorno envolve QUALQUER pixel
    # (o outline() do style.py pula vizinhos 'k' e deixaria furos onde a margem encosta na borda)
    for y in range(SIZE):
        for x in range(SIZE):
            if not inside(x, y):
                c[y][x] = "."
    out = [row[:] for row in c]
    for y in range(SIZE):
        for x in range(SIZE):
            if c[y][x] == "." and any(
                    0 <= x + dx < SIZE and 0 <= y + dy < SIZE and c[y + dy][x + dx] != "."
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                out[y][x] = "k"
    return to_rows(out)


ICON = draw()
FRAMES = {"icon": ICON}

if __name__ == "__main__":
    write_png(ICON, OUT, scale=16)
    print("gerado:", OUT)
