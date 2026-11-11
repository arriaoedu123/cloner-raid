"""Escudo em volta do avião: bolha (pixel art 40x40, 3 frames).

Uso: python3 tools/sprites/shield.py
Saída: assets/sprites/player/shield_0.png, shield_1.png, shield_2.png

Anel de 2 px (efeito, sem contorno): borda clara c por fora e azul B por dentro, para aparecer
tanto sobre a água quanto sobre a grama. Um reflexo branco w no alto à esquerda (a luz vem de
cima) faz ele parecer uma esfera de vidro; um brilho w corre pelo anel, 1/3 de volta por frame.
"""
import math

from style import ASSETS_DIR, blank, to_rows, write_png

SIZE = 40
CENTER = SIZE / 2.0
FRAME_COUNT = 3
OUTER = (17.5, 19.0)        # faixa clara (c) do anel
INNER = (16.5, 17.5)        # faixa azul (B) do anel
REFLEX = (14.5, 15.5)       # arco do reflexo, por dentro do anel
REFLEX_ARC = (0.10, 0.20)   # trecho da volta (0 = esquerda, sobe no sentido horário)
SHINE_ARC = 0.06            # tamanho do brilho que corre


def polar(x: int, y: int) -> tuple[float, float]:
    """Distância do centro e posição na volta (0..1) do pixel."""
    dx, dy = x + 0.5 - CENTER, y + 0.5 - CENTER
    return math.hypot(dx, dy), (math.atan2(dy, dx) + math.pi) / (2 * math.pi)


def bubble(frame: int) -> list[str]:
    c = blank(SIZE, SIZE)
    for y in range(SIZE):
        for x in range(SIZE):
            d, a = polar(x, y)
            if OUTER[0] <= d < OUTER[1]:
                shine = (a - frame / FRAME_COUNT) % 1.0 < SHINE_ARC
                c[y][x] = "w" if shine else "c"
            elif INNER[0] <= d < INNER[1]:
                c[y][x] = "B"
            elif REFLEX[0] <= d < REFLEX[1] and REFLEX_ARC[0] <= a < REFLEX_ARC[1]:
                c[y][x] = "w"
    return to_rows(c)


FRAMES = {f"shield_{i}": bubble(i) for i in range(FRAME_COUNT)}

if __name__ == "__main__":
    for name, grid in FRAMES.items():
        path = ASSETS_DIR / "player" / f"{name}.png"
        write_png(grid, path)
        print("gerado:", path)
