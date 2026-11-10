"""Submarino inimigo em pixel art 56x20 (vista de cima, proa para a DIREITA).

Uso: python3 tools/sprites/submarine.py
Saída (assets/sprites/submarine/):
  submarine_surface_0/1.png  na superfície (espuma na proa e na popa alternando)
  submarine_dive.png         mergulhando/subindo: casco já embaixo d'água, só a torre de fora
  submarine_under_0/1.png    submerso: só a silhueta e o periscópio com marolinha

É o maior barco do rio (casco de 50 px; o navio tem 40 e o avião do jogador 32x32).
Casco de metal cinza-escuro em charuto, com faixa vermelha no meio (inimigo), brilho claro no
alto, escotilhas e lemes cruzados na popa; torre vermelha com vigia de vidro e lemes de
mergulho. Luz de cima: metade de cima clara, de baixo escura. Embaixo d'água, a silhueta usa a
cor de sombra `z` (k transparente, a mesma das sombras), que escurece a água sem cor nova.
"""
from style import ASSETS_DIR, blank, outline, overlay, to_rows, write_png

W, H = 56, 20
HALF_LEN, HALF_HEIGHT = 25.0, 5.2   # casco: superelipse com esse meio comprimento e meia altura
TOWER_W, TOWER_H = 9, 8
CX, CY = W / 2.0 - 0.5, H / 2.0 - 0.5

HULL = {(x, y) for y in range(H) for x in range(W)
        if abs((x - CX) / HALF_LEN) ** 2.4 + abs((y - CY) / HALF_HEIGHT) ** 2.2 <= 1.0}
TOP = min(y for _, y in HULL)
BOTTOM = max(y for _, y in HULL)
MID = (TOP + BOTTOM) / 2.0
X0 = min(x for x, _ in HULL)
X1 = max(x for x, _ in HULL)

# Torre um pouco para a frente do meio, cantos arredondados
TX0 = int(CX + HALF_LEN * 0.12)
TY0 = int(round(MID - TOWER_H / 2.0 + 0.5))
TOWER = {(x, y) for y in range(TY0, TY0 + TOWER_H) for x in range(TX0, TX0 + TOWER_W)
         if not (x in (TX0, TX0 + TOWER_W - 1) and y in (TY0, TY0 + TOWER_H - 1))}
PERISCOPE_X = TX0 + TOWER_W - 3
MY = int(MID)


def paint_tower(c: list[list[str]]) -> None:
    t0, t1 = TY0, TY0 + TOWER_H - 1
    for x, y in TOWER:
        c[y][x] = "p" if y == t0 else ("r" if y == t1 else "R")
    c[MY][PERISCOPE_X] = "c"      # vigia de vidro (brilho em cima)
    c[MY + 1][PERISCOPE_X] = "B"
    lx = TX0 + TOWER_W // 2       # lemes de mergulho saindo da torre
    for d in (1, 2):
        c[t0 - d][lx] = c[t1 + d][lx] = "s"


def surfaced() -> list[list[str]]:
    c = blank(W, H)
    for x, y in HULL:
        if abs(y - MID) <= 1.0 and X0 + 4 <= x <= X1 - 5:
            c[y][x] = "R" if y < MID else "r"  # faixa vermelha no meio
        elif y == TOP:
            c[y][x] = "w" if X0 + 6 <= x <= X1 - 8 else "S"  # brilho no alto
        else:
            c[y][x] = "S" if y < MID else "s"
    for hx in (X0 + 9, X1 - 9):  # escotilhas no convés
        c[MY - 2][hx] = c[MY - 2][hx + 1] = "s"
    paint_tower(c)
    for d in (1, 2):  # lemes cruzados na popa
        c[TOP + 1 - d][X0 + 2] = c[BOTTOM - 1 + d][X0 + 2] = "s"
    return outline(c)


def silhouette(with_tower: bool) -> list[list[str]]:
    c = blank(W, H)
    for x, y in HULL | (TOWER if with_tower else set()):
        c[y][x] = "z"
    return c


def surface_frame(phase: int) -> list[str]:
    c = surfaced()
    spots = [(X1 + 2, MY - 2), (X1 + 3, MY), (X1 + 2, MY + 3), (X0 - 2, MY),
             (X0 - 3, MY + 2 - phase), (X1 - 3, TOP - 2), (X1 - 6 - phase, BOTTOM + 2)]
    for i, (x, y) in enumerate(spots):
        if c[y][x] == ".":
            c[y][x] = "w" if (i + phase) % 2 == 0 else "c"
    return to_rows(c)


def dive_frame() -> list[str]:
    top = blank(W, H)
    paint_tower(top)
    top = outline(top)
    t0, t1 = TY0, TY0 + TOWER_H - 1
    spots = [(TX0 - 2, t0), (TX0 - 2, t1), (TX0 + TOWER_W + 1, t0 + 1), (TX0 + TOWER_W + 2, MY),
             (TX0 + TOWER_W + 1, t1 - 1), (TX0 + 2, t1 + 3), (TX0 + TOWER_W - 2, t0 - 3)]
    for i, (x, y) in enumerate(spots):
        if top[y][x] == ".":
            top[y][x] = "w" if i % 2 else "c"
    return to_rows(overlay(silhouette(False), top))


def under_frame(phase: int) -> list[str]:
    c = silhouette(True)
    c[MY][PERISCOPE_X] = c[MY + 1][PERISCOPE_X] = "S"  # periscópio
    ripples = [((PERISCOPE_X + 2, MY), "c"), ((PERISCOPE_X + 2, MY + 1), "w"), ((PERISCOPE_X - 3, MY), "c")] \
        if phase == 0 else \
        [((PERISCOPE_X + 3, MY), "w"), ((PERISCOPE_X + 3, MY + 1), "c"), ((PERISCOPE_X - 4, MY + 1), "c")]
    for (x, y), ch in ripples:
        c[y][x] = ch
    return to_rows(c)


FRAMES = {
    "submarine_surface_0": surface_frame(0),
    "submarine_surface_1": surface_frame(1),
    "submarine_dive": dive_frame(),
    "submarine_under_0": under_frame(0),
    "submarine_under_1": under_frame(1),
}

if __name__ == "__main__":
    for name, grid in FRAMES.items():
        path = ASSETS_DIR / "submarine" / f"{name}.png"
        write_png(grid, path)
        print("gerado:", path)
