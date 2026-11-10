"""Posto de combustível em pixel art 30x18 (vista de cima): tanque cilíndrico deitado
sobre quatro boias.

Uso: python3 tools/sprites/fuel_depot.py
Saída: assets/sprites/fuel_depot/fuel_depot.png

Laranja = combustível/fogo; boias e tampa em cinza (metal); cintas brancas para ser
reconhecido de relance. Luz de cima: faixa clara no topo do cilindro, escura embaixo.
"""
from style import ASSETS_DIR, blank, outline, to_rows, write_png

W, H = 30, 18

# Tom de cada linha do cilindro (claro em cima, escuro embaixo)
CYLINDER_SHADE = {4: "f", 5: "f", 6: "O", 7: "O", 8: "O", 9: "O", 10: "O", 11: "r", 12: "r", 13: "r"}
FLOATS_X = (4, 21)    # começo de cada par de boias (5 px de largura)
STRAPS_X = (10, 11, 18, 19)


def depot() -> list[str]:
    c = blank(W, H)
    # boias em cima e embaixo de cada ponta
    for x0 in FLOATS_X:
        for x in range(x0, x0 + 5):
            for y in (2, 3, 14, 15):
                c[y][x] = "w" if y in (2, 14) else "s"
    # cilindro com pontas arredondadas
    for y, color in CYLINDER_SHADE.items():
        x0, x1 = (3, 26) if y in (4, 13) else ((2, 27) if y in (5, 12) else (1, 28))
        for x in range(x0, x1 + 1):
            c[y][x] = color
    # cintas brancas (sombreadas embaixo)
    for x in STRAPS_X:
        for y in range(4, 14):
            c[y][x] = "w" if y < 11 else "S"
    # tampa da válvula
    c[3][14] = c[3][15] = "S"
    return to_rows(outline(c))


FRAMES = {"fuel_depot": depot()}

if __name__ == "__main__":
    path = ASSETS_DIR / "fuel_depot" / "fuel_depot.png"
    write_png(FRAMES["fuel_depot"], path)
    print("gerado:", path)
