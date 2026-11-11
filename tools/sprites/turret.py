"""Torre inimiga (28x28, vista de cima) e o projétil dela (8x8).

Uso: python3 tools/sprites/turret.py
Saída (assets/sprites/turret/):
  turret_<estado>_<cano>.png  estado: idle (parada), warn (luz de aviso acesa), fire (clarão na
                              boca do cano, sem contorno); cano: down (para baixo), right e left
                              (diagonal; left é o espelho de right)
  enemy_shot.png              projétil: bola de fogo laranja com miolo claro

Plataforma octogonal de concreto (cinza, luz de cima) na beira da água, anel de sacos de areia
(terracota) e torre vermelha quadrada (inimigo). O cano cinza aponta para baixo ou na diagonal,
para o lado do avião (a torre só atira num cone de ±45° para baixo).
"""
from style import ASSETS_DIR, blank, mirror, outline, overlay, to_rows, write_png

S = 28
LIGHT = ((13, 12), (14, 12), (13, 13), (14, 13))
FLASH = {
    "down": {(13, 26): "f", (14, 26): "f", (12, 26): "O", (15, 26): "O", (13, 27): "O", (14, 27): "O"},
    "right": {(24, 23): "f", (25, 24): "f", (24, 24): "O", (25, 23): "O", (26, 25): "O", (25, 25): "O"},
}


def barrel(c: list[list[str]], direction: str) -> None:
    """Cano de 2 px de metal, mais claro que o concreto para os 2 px aparecerem: lado da luz w,
    o outro S."""
    if direction == "down":  # colunas 13 e 14: o centro da torre
        for y in range(18, 26):
            c[y][13] = "w"
            c[y][14] = "S"
    else:  # diagonal para baixo e para a direita: 2 px por linha, termina antes do canto
        for i in range(6):            # (se chegasse no canto, o contorno ficaria torto)
            c[17 + i][17 + i] = "S"
            c[17 + i][18 + i] = "w"   # lado de cima/direita, virado para a luz


def body() -> list[list[str]]:
    c = blank(S, S)
    # plataforma octogonal de concreto
    for y in range(2, 26):
        for x in range(2, 26):
            if min(x - 2, 25 - x) + min(y - 2, 25 - y) >= 5:
                c[y][x] = "S" if y < 14 else "s"
    # anel de sacos de areia
    for y in range(4, 24):
        for x in range(4, 24):
            if 7.5 <= ((x - 13.5) ** 2 + (y - 13.5) ** 2) ** 0.5 <= 9.5:
                c[y][x] = "m" if y < 11 else ("n" if y > 16 else "N")
    # torre quadrada vermelha
    for y in range(9, 18):
        for x in range(10, 18):
            c[y][x] = "p" if y == 9 else ("r" if y == 17 else "R")
    return c


def turret(state: str, direction: str) -> list[str]:
    """`direction`: down ou right (left = espelho de right, feito em FRAMES)."""
    c = body()
    barrel(c, direction)
    top = blank(S, S)
    for x, y in LIGHT[:2] if state != "warn" else LIGHT:
        top[y][x] = "f" if state == "warn" else "k"
    base = outline(overlay(c, top))
    if state == "fire":
        for (x, y), ch in FLASH[direction].items():
            base[y][x] = ch
    return to_rows(base)


def shot() -> list[str]:
    c = blank(8, 8)
    for y in range(8):
        for x in range(8):
            d = ((x - 3.5) ** 2 + (y - 3.5) ** 2) ** 0.5
            if d <= 2.8:
                c[y][x] = "f" if (x <= 3 and y <= 3 and d <= 1.9) else "O"
    return to_rows(outline(c))


FRAMES = {"enemy_shot": shot()}
for _state in ("idle", "warn", "fire"):
    FRAMES[f"turret_{_state}_down"] = turret(_state, "down")
    FRAMES[f"turret_{_state}_right"] = turret(_state, "right")
    FRAMES[f"turret_{_state}_left"] = mirror(FRAMES[f"turret_{_state}_right"])

if __name__ == "__main__":
    for name, grid in FRAMES.items():
        path = ASSETS_DIR / "turret" / f"{name}.png"
        write_png(grid, path)
        print("gerado:", path)
