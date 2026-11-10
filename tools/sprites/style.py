"""Padrão visual compartilhado por TODOS os sprites do jogo (pixel art).

Cada sprite é desenhado como uma grade de caracteres; cada caractere é uma cor
da PALETTE abaixo. Não use cores fora da paleta; se precisar de uma nova família,
adicione aqui seguindo o padrão base / escuro / claro (ver "Estilo visual" no CLAUDE.md).
"""
import struct
import zlib
from pathlib import Path

ASSETS_DIR = Path(__file__).resolve().parents[2] / "assets" / "sprites"

# char -> cor (hex RGB). "." é transparente.
PALETTE = {
    ".": None,
    # contorno universal (usado em todos os sprites)
    "k": "#22161E",
    # amarelo (avião do jogador)
    "Y": "#FFC93C", "y": "#D9931A", "l": "#FFE89A",
    # azul (cockpit, vidros, água)
    "B": "#3FA9F5", "b": "#1F6FB5", "c": "#BDE6FF",
    # laranja (fogo, motor, explosões)
    "O": "#FF7A1A", "f": "#FFE27A",
    # vermelho (inimigos, perigo)
    "R": "#E8433A", "r": "#A82630", "p": "#FF8F7A",
    # verde (margens, vegetação)
    "G": "#4CAF50", "g": "#2E7D32", "h": "#A5D66B",
    # cinza / branco (metal, pontes, estruturas)
    "S": "#8A8F99", "s": "#555A66", "w": "#F4F4F0",
    # terracota (telhados, madeira, terra batida)
    "N": "#C0683F", "n": "#7E3F2A", "m": "#E8A06E",
    # lilás (avião do jogador 2: as mesmas letras do amarelo trocadas por Y->V, y->v, l->u)
    "V": "#A77BE0", "v": "#6D45A8", "u": "#D9C2F7",
    # sombra embutida: contorno k com 35% de opacidade (igual ao shadow_material.tres).
    # Não é cor nova, é transparência; use só via with_shadow()
    "z": "#22161E59",
}


def _rgba(ch: str) -> bytes:
    color = PALETTE[ch]
    if color is None:
        return b"\x00\x00\x00\x00"
    alpha = bytes.fromhex(color[7:9]) if len(color) == 9 else b"\xff"
    return bytes.fromhex(color[1:7]) + alpha


def check(grid: list[str], name: str = "sprite") -> None:
    width = len(grid[0])
    for i, row in enumerate(grid):
        if len(row) != width:
            raise ValueError(f"{name}: linha {i} tem {len(row)} px, esperado {width}")
        for ch in row:
            if ch not in PALETTE:
                raise ValueError(f"{name}: cor '{ch}' fora da paleta (linha {i})")


def write_png(grid: list[str], path: Path, scale: int = 1) -> None:
    """Salva a grade como PNG RGBA (scale > 1 só para previews)."""
    check(grid, path.name)
    w, h = len(grid[0]) * scale, len(grid) * scale
    raw = b""
    for row in grid:
        line = b"".join(_rgba(ch) * scale for ch in row)
        raw += (b"\x00" + line) * scale

    def chunk(tag: bytes, data: bytes) -> bytes:
        return (struct.pack(">I", len(data)) + tag + data
                + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))

    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(raw, 9))
           + chunk(b"IEND", b""))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)


## Troca o amarelo do jogador 1 pelo lilás do jogador 2 (mesmo desenho, outra cor).
PLAYER2 = str.maketrans({"Y": "V", "y": "v", "l": "u"})


def player2(grid: list[str]) -> list[str]:
    return [row.translate(PLAYER2) for row in grid]


def mirror(grid: list[str]) -> list[str]:
    """Espelha horizontalmente (ex.: frame da direita -> esquerda)."""
    return [row[::-1] for row in grid]


def blank(width: int, height: int) -> list[list[str]]:
    """Tela vazia editável (lista de listas) para desenhar com set/paint."""
    return [["."] * width for _ in range(height)]


def outline(canvas: list[list[str]]) -> list[list[str]]:
    """Aplica o contorno padrão: 1 px 'k' em volta de toda a silhueta (vizinhança de 4)."""
    h, w = len(canvas), len(canvas[0])
    out = [row[:] for row in canvas]
    for y in range(h):
        for x in range(w):
            if canvas[y][x] != ".":
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and canvas[ny][nx] not in (".", "k"):
                    out[y][x] = "k"
                    break
    return out


def overlay(base: list[list[str]], top: list[list[str]]) -> list[list[str]]:
    """Desenha 'top' por cima de 'base' (pixels '.' de top são ignorados)."""
    return [[t if t != "." else b for b, t in zip(rb, rt)] for rb, rt in zip(base, top)]


def to_rows(canvas: list[list[str]]) -> list[str]:
    return ["".join(row) for row in canvas]


def with_shadow(grid: list[str], dx: int, dy: int) -> list[str]:
    """Embute a sombra no sprite: a silhueta deslocada (dx, dy) em 'z' por baixo do desenho.
    A borda cresce igual dos dois lados (dx/dy px), então o centro do sprite não muda."""
    w, h = len(grid[0]) + 2 * dx, len(grid) + 2 * dy
    out = [["."] * w for _ in range(h)]
    for y, row in enumerate(grid):
        for x, ch in enumerate(row):
            if ch != ".":
                out[y + 2 * dy][x + 2 * dx] = "z"
    for y, row in enumerate(grid):
        for x, ch in enumerate(row):
            if ch != ".":
                out[y + dy][x + dx] = ch
    return to_rows(out)
