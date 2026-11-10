"""Explosão em pixel art 32x32, 6 frames: clarão -> bola de fogo -> fumaça.

Uso: python3 tools/sprites/explosion.py
Saída: assets/sprites/explosion/explosion_0.png ... explosion_5.png

Cada frame é feito de "nuvens" (círculos) com 3 tons: claro em cima, escuro embaixo
(luz vinda de cima, igual aos outros sprites), e recebe o contorno padrão.
"""
from style import ASSETS_DIR, blank, outline, to_rows, write_png

SIZE = 32

# Paletas de cada material: (base, claro, escuro)
FLASH = ("f", "w", "O")
FIRE = ("O", "f", "r")
HOT = ("f", "w", "O")
EMBER = ("R", "O", "r")
SMOKE = ("S", "w", "s")


def puff(c, cx: float, cy: float, r: float, colors) -> None:
    base, light, dark = colors
    for y in range(SIZE):
        for x in range(SIZE):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            if dx * dx + dy * dy <= r * r:
                if dy < -r * 0.35:
                    c[y][x] = light
                elif dy > r * 0.45:
                    c[y][x] = dark
                else:
                    c[y][x] = base


# Cada frame: lista de nuvens (x, y, raio, material), desenhadas em ordem
FRAMES_SPEC = [
    [(16, 16, 4, FLASH), (16, 16, 2, HOT)],
    [(11, 14, 4, FIRE), (21, 15, 4, FIRE), (16, 16, 7, FIRE), (16, 15, 3, HOT)],
    [(9, 12, 5, FIRE), (23, 12, 5, FIRE), (13, 22, 5, FIRE), (21, 22, 4, FIRE),
     (16, 16, 9, FIRE), (16, 14, 4, HOT)],
    [(8, 11, 5, SMOKE), (24, 10, 5, SMOKE), (12, 23, 5, SMOKE), (22, 23, 5, SMOKE),
     (16, 15, 9, EMBER), (16, 14, 4, FIRE)],
    [(9, 10, 5, SMOKE), (24, 9, 5, SMOKE), (11, 21, 5, SMOKE), (22, 21, 5, SMOKE),
     (16, 13, 7, SMOKE), (16, 15, 2, FIRE)],
    [(12, 8, 4, SMOKE), (21, 7, 4, SMOKE), (10, 18, 3, SMOKE), (23, 17, 3, SMOKE),
     (16, 12, 4, SMOKE)],
]


def frame(spec) -> list[str]:
    c = blank(SIZE, SIZE)
    for cx, cy, r, colors in spec:
        puff(c, cx, cy, r, colors)
    return to_rows(outline(c))


FRAMES = {f"explosion_{i}": frame(spec) for i, spec in enumerate(FRAMES_SPEC)}

# Faísca das partículas: quadrado 2x2 branco, sem contorno (detalhe). A cor vem do
# color_ramp das partículas, que usa só cores da paleta (em degraus, sem degradê).
SPARK = ["ww", "ww"]

if __name__ == "__main__":
    for name, grid in FRAMES.items():
        path = ASSETS_DIR / "explosion" / f"{name}.png"
        write_png(grid, path)
        print("gerado:", path)
    write_png(SPARK, ASSETS_DIR / "explosion" / "spark.png")
    print("gerado:", ASSETS_DIR / "explosion" / "spark.png")
