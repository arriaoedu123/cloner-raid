"""Ponte em pixel art 176x20 (vista de cima), atravessando o gargalo do rio (160 px)
e apoiando 8 px em cada margem.

Uso: python3 tools/sprites/bridge.py
Saída: assets/sprites/bridge/bridge_0.png

Asfalto cinza escuro com faixa central tracejada (igual à estrada que river.gd desenha
nas margens), guarda-corpos cinza com postes escuros a cada 8 px.
"""
from style import ASSETS_DIR, blank, outline, to_rows, write_png

W, H = 176, 20


def bridge() -> list[str]:
    c = blank(W, H)
    for y in range(1, H - 1):
        for x in range(1, W - 1):
            if y in (1, 2):           # guarda-corpo de cima (iluminado)
                c[y][x] = "w" if y == 1 else "S"
            elif y in (17, 18):       # guarda-corpo de baixo (sombra)
                c[y][x] = "S" if y == 17 else "s"
            else:                     # asfalto
                c[y][x] = "s"
            if y in (1, 2, 17, 18) and x % 8 == 4:
                c[y][x] = "k"         # postes
    # faixa central tracejada, alinhada com a da estrada (x % 12 < 6 em coordenadas do mundo:
    # a ponte começa em x = 232, que é múltiplo de 8 e de 4 -> 232 % 12 = 4)
    for x in range(1, W - 1):
        if (232 + x) % 12 < 6:
            c[9][x] = c[10][x] = "f"
    return to_rows(outline(c))


FRAMES = {"bridge_0": bridge()}

if __name__ == "__main__":
    path = ASSETS_DIR / "bridge" / "bridge_0.png"
    write_png(FRAMES["bridge_0"], path)
    print("gerado:", path)
