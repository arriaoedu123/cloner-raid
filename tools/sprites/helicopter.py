"""Helicóptero de ataque inimigo em pixel art 28x28 (vista de cima, nariz para a DIREITA).

Uso: python3 tools/sprites/helicopter.py
Saída: assets/sprites/helicopter/heli_0.png, heli_1.png (pás em "\\" e em "/")

Objetos que andam de lado são desenhados virados para a direita;
no jogo, o sprite é espelhado (flip_h) quando anda para a esquerda.

Mesma família do jato: fuselagem comprida vermelha com luz de cima (linha de cima clara,
de baixo escura), cabine dupla de vidro azul, asinhas de metal cinza com casulos de foguete
(ponta vermelha) e metralhadora no nariz. As duas pás são cinza, finas e sem contorno, sempre
na diagonal para nunca ficarem deitadas em cima do corpo.
"""
from style import ASSETS_DIR, blank, outline, overlay, to_rows, write_png

SIZE = 28
ROTOR_HUB = (15, 14)  # (x, y)
BLADE = 10  # comprimento de cada pá a partir do centro (a ponta é clara)


def red(y: int, top: int, bottom: int) -> str:
    """Vermelho com luz de cima: linha de cima clara, de baixo escura."""
    return "p" if y == top else ("r" if y == bottom else "R")


def body() -> list[list[str]]:
    c = blank(SIZE, SIZE)
    # asinhas de metal atravessando o corpo (luz de cima: metade de cima clara)
    for y in range(6, 23):
        for x in (13, 14):
            c[y][x] = "S" if y <= 14 else "s"
    # casulos de foguete nas pontas das asinhas, com a ponta vermelha virada para a frente
    for y in (6, 7, 21, 22):
        for x in range(10, 18):
            c[y][x] = "S" if y in (6, 21) else "s"
        c[y][18] = "R"
    # fuselagem comprida (como a do jato), mais fina no nariz
    for x in range(3, 26):
        rows = range(12, 17) if x <= 23 else range(13, 16)
        for y in rows:
            c[y][x] = red(y, 12, 16)
    # cabine dupla (piloto e atirador) em vidro azul, com brilho
    for x in (17, 18, 20, 21):
        c[13][x] = c[14][x] = "B"
        c[15][x] = "b"
    c[13][18] = c[13][21] = "c"
    # metralhadora no nariz
    c[14][26] = "s"
    # deriva da cauda
    for y in range(9, 20):
        c[y][3] = "R" if y < 14 else "r"
        c[y][4] = "p" if y < 14 else "R"
    return outline(c)


def rotor(flip: bool) -> list[list[str]]:
    """Duas pás cinza na diagonal: frame 0 em "\\", frame 1 em "/"."""
    c = blank(SIZE, SIZE)
    hx, hy = ROTOR_HUB
    for d in range(-BLADE, BLADE + 1):
        if d != 0:
            c[hy - d if flip else hy + d][hx + d] = "w" if abs(d) == BLADE else "S"
    c[hy][hx] = "s"
    return c


FRAMES = {
    "heli_0": to_rows(overlay(body(), rotor(flip=False))),
    "heli_1": to_rows(overlay(body(), rotor(flip=True))),
}

if __name__ == "__main__":
    for name, grid in FRAMES.items():
        path = ASSETS_DIR / "helicopter" / f"{name}.png"
        write_png(grid, path)
        print("gerado:", path)
