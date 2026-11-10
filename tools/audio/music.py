"""Trilha sonora original em chiptune, em 3 camadas sincronizadas (WAV 16-bit mono).

Uso: python3 tools/audio/music.py
Saída: assets/audio/music/theme_base.wav, theme_lead.wav, theme_drums.wav

Lá menor, 132 BPM, 16 compassos (~29 s) em loop. As camadas têm exatamente o mesmo tamanho
e o jogo toca as três juntas, ligando melodia e bateria conforme a dificuldade sobe.
Usa as mesmas peças de síntese dos efeitos (tools/audio/sfx.py).
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from sfx import RATE, noise, tone, write  # noqa: E402

OUT_DIR = Path(__file__).resolve().parents[2] / "assets" / "audio" / "music"

BPM = 132
EIGHTH = round(RATE * 60 / BPM / 2)  # amostras por colcheia (grade igual para as 3 camadas)
BAR = EIGHTH * 8
BARS = 16
TOTAL = BAR * BARS

# Acordes de cada compasso (nota mais grave em MIDI) — Am F C G Am F G E, duas vezes
CHORDS = {
    "Am": [57, 60, 64], "F": [53, 57, 60], "C": [48, 52, 55], "G": [55, 59, 62], "E": [52, 56, 59],
}
PROGRESSION = ["Am", "F", "C", "G", "Am", "F", "G", "E"] * 2

# Melodia em colcheias: número = nota MIDI, "-" = segura a anterior, "." = pausa
MELODY = [
    [76, "-", 69, "-", 72, 74, 76, "-"],
    [77, "-", 76, "-", 72, "-", 69, "-"],
    [79, "-", 76, 72, 76, "-", 79, "-"],
    [74, "-", "-", "-", 71, ".", 74, "."],
    [81, "-", 79, 76, "-", 72, 76, "-"],
    [77, 76, 74, 72, "-", 69, "-", "."],
    [71, 74, 79, "-", 77, "-", 74, "-"],
    [76, "-", "-", "-", 68, ".", 71, "."],
    # segunda metade: mesma ideia, terminando em lá para o loop voltar ao começo
    [76, "-", 69, "-", 72, 74, 76, "-"],
    [77, "-", 76, "-", 72, "-", 69, "-"],
    [79, "-", 81, 79, 76, "-", 72, "-"],
    [74, "-", 76, "-", 79, "-", 74, "-"],
    [81, "-", 79, 76, "-", 72, 76, "-"],
    [77, 76, 74, 72, "-", 69, "-", "."],
    [71, 74, 76, "-", 74, "-", 71, "-"],
    [69, "-", "-", "-", "-", "-", ".", "."],
]


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def place(track, start, samples):
    for i, s in enumerate(samples):
        if start + i < len(track):
            track[start + i] += s


def base_layer():
    """Baixo em colcheias (fundamental/quinta/oitava) + acorde suave sustentado."""
    t = [0.0] * TOTAL
    for bar, name in enumerate(PROGRESSION):
        root = CHORDS[name][0] - 12
        pattern = [root, root, root + 12, root, root + 7, root, root + 12, root + 7]
        for step, note in enumerate(pattern):
            place(t, bar * BAR + step * EIGHTH, tone(EIGHTH * 0.9 / RATE, hz(note), wave_type="tri", vol=0.32))
        for note in CHORDS[name]:
            place(t, bar * BAR, tone(BAR * 0.98 / RATE, hz(note), wave_type="tri", vol=0.05, decay=False))
    return t


def lead_layer():
    """Melodia (onda quadrada) + arpejo rápido bem baixinho (semicolcheias)."""
    t = [0.0] * TOTAL
    for bar, notes in enumerate(MELODY):
        step = 0
        while step < 8:
            note = notes[step]
            if note in ("-", "."):
                step += 1
                continue
            length = 1
            while step + length < 8 and notes[step + length] == "-":
                length += 1
            dur = length * EIGHTH * 0.92 / RATE
            place(t, bar * BAR + step * EIGHTH, tone(dur, hz(note), vol=0.13, duty=0.5, decay=length == 1))
            step += length
    sixteenth = EIGHTH // 2
    for bar, name in enumerate(PROGRESSION):
        chord = [n + 12 for n in CHORDS[name]] + [CHORDS[name][0] + 24]
        for k in range(16):
            place(t, bar * BAR + k * sixteenth,
                  tone(sixteenth * 0.8 / RATE, hz(chord[k % 4]), vol=0.04, duty=0.125))
    return t


def drums_layer():
    """Bumbo nos tempos 1 e 3, caixa no 2 e 4, chimbal em colcheias."""
    t = [0.0] * TOTAL
    beat = EIGHTH * 2
    for bar in range(BARS):
        for b in range(4):
            start = bar * BAR + b * beat
            if b in (0, 2):
                place(t, start, tone(0.12, 150, 45, "tri", 0.55))
            else:
                place(t, start, noise(0.12, 0.3, 2, 3, seed=bar * 4 + b))
        for e in range(8):
            place(t, bar * BAR + e * EIGHTH, noise(0.03, 0.08, 1, seed=100 + bar * 8 + e))
    return t


if __name__ == "__main__":
    write("theme_base", base_layer(), OUT_DIR)
    write("theme_lead", lead_layer(), OUT_DIR)
    write("theme_drums", drums_layer(), OUT_DIR)
    print("duração: %.2f s (%d compassos a %d BPM)" % (TOTAL / RATE, BARS, BPM))
