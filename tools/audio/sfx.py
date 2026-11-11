"""Gera os efeitos sonoros do jogo (WAV 16-bit mono) por síntese, estilo chiptune.

Uso: python3 tools/audio/sfx.py
Saída: assets/audio/sfx/<nome>.wav

Todos os sons usam as mesmas peças (onda quadrada/triangular, ruído "sample and hold",
envelope de ataque/decaimento), para soarem como uma família — o equivalente sonoro da
paleta fechada dos sprites. Só biblioteca padrão do Python.
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
OUT_DIR = Path(__file__).resolve().parents[2] / "assets" / "audio" / "sfx"


def tone(dur, f0, f1=None, wave_type="square", vol=0.4, duty=0.5, decay=True):
    """Onda com frequência indo de f0 a f1 (exponencial) e envelope simples."""
    f1 = f0 if f1 is None else f1
    n = int(dur * RATE)
    out, phase = [], 0.0
    for i in range(n):
        t = i / max(n - 1, 1)
        f = f0 * (f1 / f0) ** t
        phase = (phase + f / RATE) % 1.0
        if wave_type == "square":
            s = 1.0 if phase < duty else -1.0
        else:  # triangular
            s = 4.0 * abs(phase - 0.5) - 1.0
        out.append(s * vol * _env(i, n, decay))
    return out


def noise(dur, vol=0.5, hold0=1, hold1=None, decay=True, seed=1):
    """Ruído "sample and hold": segura cada valor por `hold` amostras (mais = mais grave)."""
    rnd = random.Random(seed)
    hold1 = hold0 if hold1 is None else hold1
    n = int(dur * RATE)
    out, value, left = [], 0.0, 0
    for i in range(n):
        if left <= 0:
            value = rnd.uniform(-1.0, 1.0)
            left = int(hold0 + (hold1 - hold0) * i / max(n - 1, 1))
        left -= 1
        out.append(value * vol * _env(i, n, decay))
    return out


def soft_noise(dur, vol=0.5, smooth=0.05, decay=False, seed=1):
    """Ruído abafado (filtro passa-baixa simples): som de vento/jato em vez de chiado."""
    rnd = random.Random(seed)
    n = int(dur * RATE)
    out, y = [], 0.0
    for i in range(n):
        y += smooth * (rnd.uniform(-1.0, 1.0) - y)
        out.append(y * vol * 6.0 * _env(i, n, decay))
    return out


def lowpass(samples, smooth=0.1):
    """Abafa o som (tira os agudos): quanto menor `smooth`, mais abafado."""
    out, y = [], 0.0
    for s in samples:
        y += smooth * (s - y)
        out.append(y)
    return out


def pulse(samples, rate_hz, depth=0.6):
    """Volume pulsando `rate_hz` vezes por segundo (efeito de hélice girando)."""
    return [s * (1.0 - depth * 0.5 * (1.0 + math.cos(2 * math.pi * rate_hz * i / RATE)))
            for i, s in enumerate(samples)]


def seamless_loop(make, dur, fade=0.15):
    """Gera `dur + fade` segundos e mistura o fim no começo: o loop emenda sem estalo."""
    a = make(dur + fade)
    n, f = int(dur * RATE), int(fade * RATE)
    return [a[i] * (i / f) + a[n + i] * (1.0 - i / f) if i < f else a[i] for i in range(n)]


def _env(i, n, decay):
    attack = int(0.004 * RATE)
    release = int(0.01 * RATE)
    a = min(1.0, i / attack) if attack else 1.0
    if decay:
        return a * (1.0 - i / n) ** 2
    return a * min(1.0, (n - i) / release)


def silence(dur):
    return [0.0] * int(dur * RATE)


def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(n)]


def seq(*parts):
    return [s for p in parts for s in p]


def write(name, samples, out_dir=OUT_DIR):
    out_dir.mkdir(parents=True, exist_ok=True)
    path = out_dir / f"{name}.wav"
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32000)) for s in samples))
    print("gerado:", path)


SOUNDS = {
    # estalo de metralhadora: ruído curtíssimo + baque grave
    "shoot": lambda: mix(noise(0.06, 0.45, 2, 5, seed=11), tone(0.07, 220, 110, "tri", 0.4)),
    # "tunc" seco: ruído grave + tom descendo
    "hit": lambda: mix(noise(0.06, 0.35, 4, 8, seed=5), tone(0.07, 400, 250, "tri", 0.35)),
    # estouro: ruído que vai ficando grave + baque grave
    "explosion_small": lambda: mix(noise(0.45, 0.55, 2, 14), tone(0.3, 180, 60, "tri", 0.4)),
    "explosion_big": lambda: mix(noise(1.0, 0.6, 3, 24, seed=7), tone(0.8, 120, 40, vol=0.3)),
    # bipe do reabastecimento (o jogo muda o tom conforme o tanque enche)
    "refuel": lambda: tone(0.05, 880, 880, "tri", 0.35),
    # alerta: dois bipes
    "low_fuel": lambda: seq(tone(0.12, 990, vol=0.25, decay=False), silence(0.04),
                            tone(0.12, 740, vol=0.25, decay=False)),
    # arpejo subindo (dó, mi, sol, dó)
    "extra_life": lambda: seq(*[tone(0.07, f, vol=0.25, decay=False) for f in (523, 659, 784, 1047)]),
    # menu: bipe curto ao mudar de opção e dois tons subindo ao confirmar
    "ui_move": lambda: tone(0.04, 660, 660, "tri", 0.3),
    "ui_select": lambda: seq(tone(0.06, 660, vol=0.22, decay=False), tone(0.1, 990, vol=0.22)),
    # pegou caixa de power-up: notas alternadas bem rápidas subindo (brilho "mágico")
    "power_up": lambda: seq(*[tone(0.035, f, vol=0.2, decay=False) for f in (440, 660, 550, 830, 660, 990, 830, 1245)]),
    # escudo absorveu uma batida: estalo de vidro (chiado agudo) + tom caindo
    "shield_break": lambda: mix(noise(0.18, 0.4, 1, 3, seed=21), tone(0.25, 1400, 300, "tri", 0.35)),
    # disparo da torre: estouro grave e longo (ruído ficando grave + baque descendo)
    "cannon": lambda: mix(noise(0.32, 0.5, 4, 20, seed=31), tone(0.3, 150, 50, "tri", 0.45)),
}

PREVIEW_DIR = Path(__file__).resolve().parents[2] / "audio_preview"

# Versões candidatas para escolher de ouvido: coloque aqui receitas novas (ex.: "shoot_c") e
# rode `python3 tools/audio/sfx.py preview` — vão para audio_preview/, que o Godot ignora.
# Depois de escolher, passe a receita para SOUNDS, esvazie esta lista e apague audio_preview/.
CANDIDATES = {}

if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "preview":
        PREVIEW_DIR.mkdir(exist_ok=True)
        (PREVIEW_DIR / ".gdignore").touch()  # o Godot ignora esta pasta
        for name, make in CANDIDATES.items():
            write(name, make(), PREVIEW_DIR)
    else:
        for name, make in SOUNDS.items():
            write(name, make())
