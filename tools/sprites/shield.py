"""Anel do escudo em volta do avião (pixel art 40x40, 2 frames).

Uso: python3 tools/sprites/shield.py
Saída: assets/sprites/player/shield_0.png, shield_1.png

Círculo de 1 px (efeito fino, sem contorno) em azul B com traços claros c; os traços trocam
de lugar entre os 2 frames, então o anel parece girar/cintilar.
"""
import math

from style import ASSETS_DIR, blank, to_rows, write_png

SIZE = 40
RADIUS = 18
SEGMENTS = 16  # traços em volta do anel (metade claros em cada frame)


def ring(frame: int) -> list[str]:
    c = blank(SIZE, SIZE)
    center = SIZE / 2.0
    for y in range(SIZE):
        for x in range(SIZE):
            dx, dy = x + 0.5 - center, y + 0.5 - center
            if RADIUS - 0.5 <= math.hypot(dx, dy) < RADIUS + 0.5:
                seg = int((math.atan2(dy, dx) + math.pi) / (2 * math.pi) * SEGMENTS) % SEGMENTS
                c[y][x] = "c" if (seg + frame) % 2 == 0 else "B"
    return to_rows(c)


FRAMES = {f"shield_{i}": ring(i) for i in range(2)}

if __name__ == "__main__":
    for name, grid in FRAMES.items():
        path = ASSETS_DIR / "player" / f"{name}.png"
        write_png(grid, path)
        print("gerado:", path)
