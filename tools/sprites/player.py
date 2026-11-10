"""Avião do jogador em pixel art 32x32 (vista de cima, nariz para cima).

Uso: python3 tools/sprites/player.py
Saída: assets/sprites/player/*.png

O avião é desenhado por METADES (16 colunas, a partir do centro para a direita).
Cada frame junta uma metade esquerda espelhada + uma metade direita.
Na inclinação, asas, asinhas da cauda e cabine têm o MESMO formato dos dois lados: o lado de
dentro da curva fica mais escuro e o de fora, mais claro (só a cor mostra para onde vira).
"""
from style import ASSETS_DIR, mirror, player2, write_png

HALF = 16

# Partes comuns da fuselagem (linhas fora da asa e da cauda)
NOSE = [  # linhas 0-10
    "",
    "k",
    "lk",
    "Bk",
    "cBk",
    "cBk",
    "BBk",
    "bBk",
    "bYk",
    "lYk",
    "lYYk",
]
MID = [  # linhas 19-22 (entre asa e cauda)
    "lYk",
    "lYk",
    "lYk",
    "lYk",
]
TAIL_END = [  # linhas 28-31 (fim da fuselagem + chama do motor)
    "kk",
    "fO",
    "O",
    "",
]

# Asas: linhas 11-18 | Caudas: linhas 23-27
WINGS = {
    "normal": [
        "lYYkk",
        "lYYYYkk",
        "lYYYYYYkk",
        "lYYYYYYYYkk",
        "lYYYYYYYYYYkk",
        "lYYYYYYYYYYYYk",
        "lYYyyyyyyyyyyk",
        "lYkkkkkkkkkkkk",
    ],
    # Asa de fora da curva: mesmo formato da de dentro (half_down/full_down), mais clara
    "half_up": [
        "lYYkk",
        "lYYllk",
        "lYYYllkk",
        "lYYYYlllk",
        "lYYYYYYllkk",
        "lYYYYYYYYlk",
        "lYYyyyyyyyk",
        "lYkkkkkkkkk",
    ],
    "full_up": [
        "lYYkk",
        "lYYllk",
        "lYYlllk",
        "lYYllllk",
        "lYYYllllk",
        "lYYYYYllk",
        "lYYYYYYYk",
        "lYkkkkkkk",
    ],
    "half_down": [
        "lYYkk",
        "lYYYYk",
        "lYYYYYkk",
        "lYYYYYYYk",
        "lYYYYYYYYkk",
        "lYYYYYYYYYk",
        "lYYyyyyyyyk",
        "lYkkkkkkkkk",
    ],
    "full_down": [
        "lYYkk",
        "lYYyyk",
        "lYYyyyk",
        "lYYyyyyk",
        "lYYyyyyyk",
        "lYYyyyyyk",
        "lYYyyyyyk",
        "lYkkkkkkk",
    ],
}
TAILS = {
    "normal": ["lYYk", "lYYYkk", "lYYYYYk", "lYyyyyk", "yykkkkk"],
    "half_up": ["lYYk", "lYYlk", "lYYllk", "lYyyyk", "yykkkk"],  # = half_down, mais clara
    "full_up": ["lYYk", "lYYlk", "lYllk", "lYYYk", "yykkk"],  # = full_down, mais clara
    "half_down": ["lYYk", "lYYYk", "lYYyyk", "lYyyyk", "yykkkk"],
    "full_down": ["lYYk", "lYYyk", "lYyyk", "lYyyk", "yykkk"],
}


# Cabine na curva: lado de fora (_up) um tom de azul mais claro, lado de dentro (_down) mais escuro
LIGHTER = str.maketrans({"B": "c", "b": "B"})
DARKER = str.maketrans({"c": "B", "B": "b"})


def nose(variant: str) -> list[str]:
    if variant.endswith("_up"):
        return [r.translate(LIGHTER) for r in NOSE]
    if variant.endswith("_down"):
        return [r.translate(DARKER) for r in NOSE]
    return NOSE


def half(variant: str) -> list[str]:
    rows = nose(variant) + WINGS[variant] + MID + TAILS[variant] + TAIL_END
    assert len(rows) == 32, f"{variant}: {len(rows)} linhas"
    return [r.ljust(HALF, ".") for r in rows]


def frame(left: str, right: str) -> list[str]:
    return [l + r for l, r in zip(mirror(half(left)), half(right))]


FRAMES = {
    "plane_center": frame("normal", "normal"),
    "plane_right_half": frame("half_up", "half_down"),
    "plane_right_full": frame("full_up", "full_down"),
}
FRAMES["plane_left_half"] = mirror(FRAMES["plane_right_half"])
FRAMES["plane_left_full"] = mirror(FRAMES["plane_right_full"])

if __name__ == "__main__":
    for name, grid in FRAMES.items():
        path = ASSETS_DIR / "player" / f"{name}.png"
        write_png(grid, path)
        print("gerado:", path)
        # mesmo desenho em lilás para o jogador 2 (coop)
        write_png(player2(grid), ASSETS_DIR / "player" / f"{name}_p2.png")
