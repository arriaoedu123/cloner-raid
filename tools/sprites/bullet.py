"""Tiro do jogador em pixel art 4x8 (vista de cima, voando para cima).

Uso: python3 tools/sprites/bullet.py
Saída: assets/sprites/bullet/player_bullet.png
"""
from style import ASSETS_DIR, write_png

PLAYER_BULLET = [
    ".kk.",
    "kffk",
    "kffk",
    "kffk",
    "kOOk",
    "kOOk",
    ".kk.",
    "....",
]

if __name__ == "__main__":
    path = ASSETS_DIR / "bullet" / "player_bullet.png"
    write_png(PLAYER_BULLET, path)
    print("gerado:", path)
