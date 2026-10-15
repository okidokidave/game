"""골드 광산 키우기의 8비트 효과음과 배경음악을 코드로 합성해 WAV로 저장한다.

실행: python3 tool/generate_sounds.py   (gold_mine 폴더에서, numpy 필요)
결과: assets/sounds/*.wav

옛날 게임기처럼 네모파(멜로디), 삼각파(베이스), 노이즈(타악기·폭발)만 쓴다.
다른 소리로 바꾸려면 같은 이름의 WAV 파일을 덮어쓰면 된다.
"""

import os
import wave

import numpy as np

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sounds')

# ── 음 이름 → 주파수 ─────────────────────────────────────
NOTE_INDEX = {'C': -9, 'C#': -8, 'D': -7, 'D#': -6, 'E': -5, 'F': -4,
              'F#': -3, 'G': -2, 'G#': -1, 'A': 0, 'A#': 1, 'B': 2}


def freq(note):
    """'A4' → 440.0, 'C#5' 같은 이름도 된다."""
    name, octave = note[:-1], int(note[-1])
    return 440.0 * 2 ** ((NOTE_INDEX[name] + (octave - 4) * 12) / 12)


# ── 기본 파형 ───────────────────────────────────────────
def t_axis(dur):
    return np.arange(int(RATE * dur)) / RATE


def square(f, dur, duty=0.5):
    t = t_axis(dur)
    f = np.broadcast_to(f, t.shape) if np.ndim(f) else np.full(t.shape, f)
    phase = np.cumsum(f) / RATE % 1.0
    return np.where(phase < duty, 1.0, -1.0)


def triangle(f, dur):
    t = t_axis(dur)
    f = np.broadcast_to(f, t.shape) if np.ndim(f) else np.full(t.shape, f)
    phase = np.cumsum(f) / RATE % 1.0
    return 4 * np.abs(phase - 0.5) - 1


_rng = np.random.default_rng(7)


def noise(dur, step=1):
    """step이 클수록 낮고 거친 노이즈 (옛날 게임기 노이즈 채널처럼)."""
    n = int(RATE * dur)
    raw = _rng.choice([-1.0, 1.0], size=n // step + 1)
    return np.repeat(raw, step)[:n]


def sweep(f0, f1, dur):
    """f0에서 f1로 미끄러지는 주파수 배열."""
    return np.linspace(f0, f1, int(RATE * dur))


def env(sig, attack=0.005, release=0.05, decay_to=None):
    """짧은 어택과 릴리즈, 선택적으로 지수 감쇠."""
    n = len(sig)
    e = np.ones(n)
    a = min(n, int(RATE * attack))
    r = min(n, int(RATE * release))
    if a:
        e[:a] = np.linspace(0, 1, a)
    if r:
        e[n - r:] *= np.linspace(1, 0, r)
    if decay_to is not None:
        e *= np.exp(np.linspace(0, np.log(max(decay_to, 1e-4)), n))
    return sig * e


def seq(parts):
    return np.concatenate(parts)


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = np.zeros(n)
    for t in tracks:
        out[:len(t)] += t
    return out


def save(name, sig, peak=0.8):
    sig = np.asarray(sig, dtype=float)
    top = np.max(np.abs(sig)) or 1.0
    data = (sig / top * peak * 32767).astype('<i2')
    path = os.path.join(OUT, name)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    print(f'{name}: {len(sig) / RATE:.2f}s, {os.path.getsize(path) // 1024}KB')


# ── 효과음 ──────────────────────────────────────────────
def sfx_pick():
    """곡괭이 "깡": 짧은 노이즈 + 금속성 높은 음."""
    hit = env(noise(0.03, step=2), release=0.02) * 0.6
    ring = env(square(sweep(1400, 900, 0.09), 0.09, duty=0.25),
               release=0.06, decay_to=0.2) * 0.5
    return mix(hit, ring)


def sfx_coin():
    """골드 "짤랑": 두 음 위로."""
    return seq([
        env(square(freq('B5'), 0.05, 0.25), release=0.01),
        env(square(freq('E6'), 0.16, 0.25), release=0.12, decay_to=0.3),
    ]) * 0.6


def sfx_blast():
    """다이너마이트 "쾅": 거친 노이즈 + 낮게 떨어지는 음."""
    boom = env(noise(0.7, step=6), attack=0.002, release=0.2, decay_to=0.02)
    low = env(square(sweep(140, 35, 0.4), 0.4), release=0.15, decay_to=0.05)
    return mix(boom * 0.9, low * 0.5)


def sfx_buy():
    """구매·강화: 올라가는 아르페지오."""
    return seq([env(square(freq(n), 0.055, 0.5), release=0.015)
                for n in ('C5', 'E5', 'G5', 'C6')]) * 0.5


def sfx_fanfare():
    """승급 팡파르."""
    lead = seq([env(square(freq(n), d, 0.25), release=0.02)
                for n, d in (('G4', 0.09), ('C5', 0.09), ('E5', 0.09),
                             ('G5', 0.12), ('E5', 0.07), ('G5', 0.4))])
    bass = seq([env(triangle(freq(n), d), release=0.02)
                for n, d in (('C3', 0.27), ('G3', 0.19), ('C4', 0.4))])
    return mix(lead * 0.55, bass * 0.5)


def sfx_alert():
    """돌발상황 경고: 내려가는 두 번의 삑."""
    return seq([
        env(square(freq('A5'), 0.11, 0.5), release=0.02),
        np.zeros(int(RATE * 0.04)),
        env(square(freq('E5'), 0.15, 0.5), release=0.05),
    ]) * 0.45


def sfx_sparkle():
    """좋은 일 (다이아, 금맥): 반짝이는 빠른 고음."""
    notes = ('E6', 'G6', 'B6', 'E7', 'B6', 'E7')
    return seq([env(square(freq(n), 0.045, 0.125), release=0.02)
                for n in notes]) * 0.4


def sfx_rare():
    """희귀 광석 발견: 겹쳐 울리는 종소리."""
    parts = []
    for i, n in enumerate(('C6', 'E6', 'G6', 'C7')):
        tone = env(triangle(freq(n), 0.9), release=0.3, decay_to=0.05)
        parts.append(np.concatenate([np.zeros(int(RATE * 0.08 * i)), tone]))
    shimmer = env(square(freq('C7'), 0.9, 0.125), release=0.3, decay_to=0.02)
    return mix(*parts, shimmer * 0.15) * 0.6


def sfx_pioneer():
    """지역 개척: 긴 팡파르."""
    melody = (('C5', 0.12), ('C5', 0.12), ('C5', 0.12), ('C5', 0.3),
              ('G#4', 0.3), ('A#4', 0.3), ('C5', 0.18), ('A#4', 0.08),
              ('C5', 0.6))
    lead = seq([env(square(freq(n), d, 0.25), release=0.03)
                for n, d in melody])
    bass = seq([env(triangle(freq(n), d), release=0.03)
                for n, d in (('C3', 0.66), ('G#2', 0.3), ('A#2', 0.3),
                             ('C3', 0.86))])
    return mix(lead * 0.55, bass * 0.5)


def sfx_click():
    """버튼 누를 때 작은 소리."""
    return env(square(freq('A6'), 0.025, 0.5), release=0.01) * 0.3


# ── 배경음악 ────────────────────────────────────────────
BPM = 112
BEAT = 60 / BPM

# (음, 박자). 'R' = 쉼표. 4/4 박자 16마디: Am F C G ×2, F G Em Am ×2
MELODY = [
    # A
    ('A4', 1), ('C5', 1), ('E5', 1), ('D5', .5), ('C5', .5),
    ('A4', 1), ('F4', 1), ('A4', 1), ('C5', 1),
    ('G4', 1), ('E4', .5), ('G4', .5), ('C5', 1), ('E5', 1),
    ('D5', 2), ('B4', 1), ('G4', 1),
    # A'
    ('A4', 1), ('C5', 1), ('E5', 1), ('A5', 1),
    ('G5', .5), ('F5', .5), ('E5', 1), ('C5', 1), ('A4', 1),
    ('G4', 1), ('C5', 1), ('E5', .5), ('D5', .5), ('C5', 1),
    ('B4', 1), ('D5', 1), ('A4', 2),
    # B
    ('C5', 1), ('A4', .5), ('C5', .5), ('F5', 1), ('E5', 1),
    ('D5', 1), ('B4', .5), ('D5', .5), ('G5', 1), ('F5', 1),
    ('E5', 1), ('G5', 1), ('B5', 1), ('G5', 1),
    ('A5', 2), ('E5', 1), ('C5', 1),
    # B'
    ('F5', 1), ('E5', 1), ('C5', 1), ('A4', 1),
    ('G4', 1), ('B4', 1), ('D5', 1), ('G5', 1),
    ('E5', 2), ('D5', 1), ('B4', 1),
    ('A4', 2), ('R', 2),
]

CHORDS = ['A', 'F', 'C', 'G'] * 2 + ['F', 'G', 'E', 'A'] * 2


def bgm():
    # 멜로디 (가는 네모파)
    lead = []
    for note, beats in MELODY:
        dur = beats * BEAT
        if note == 'R':
            lead.append(np.zeros(int(RATE * dur)))
        else:
            lead.append(env(square(freq(note), dur, 0.25),
                            release=min(0.06, dur / 3), decay_to=0.55))
    lead = seq(lead)

    # 베이스 (삼각파, 8분음표로 근음-옥타브)
    bass = []
    for root in CHORDS:
        for k in range(8):
            n = f'{root}2' if k % 2 == 0 else f'{root}3'
            bass.append(env(triangle(freq(n), BEAT / 2), release=0.03))
    bass = seq(bass)

    # 드럼: 1·3박 킥, 2·4박 스네어, 8분 하이햇
    bar_len = int(RATE * BEAT * 4)
    total = bar_len * len(CHORDS)
    drums = np.zeros(total)

    def put(sig, at):
        i = int(RATE * at)
        end = min(total, i + len(sig))
        drums[i:end] += sig[:end - i]

    kick = env(triangle(sweep(160, 45, 0.12), 0.12), release=0.05) * 0.9
    snare = env(noise(0.1, step=2), release=0.08, decay_to=0.1) * 0.35
    hat = env(noise(0.025), release=0.02) * 0.15
    for bar in range(len(CHORDS)):
        start = bar * BEAT * 4
        for beat in range(4):
            at = start + beat * BEAT
            put(kick if beat in (0, 2) else snare, at)
            put(hat, at + BEAT / 2)

    n = min(len(lead), len(bass), total)
    return lead[:n] * 0.32 + bass[:n] * 0.38 + drums[:n] * 0.5


def main():
    os.makedirs(OUT, exist_ok=True)
    sounds = {
        'pick.wav': sfx_pick(),
        'coin.wav': sfx_coin(),
        'blast.wav': sfx_blast(),
        'buy.wav': sfx_buy(),
        'fanfare.wav': sfx_fanfare(),
        'alert.wav': sfx_alert(),
        'sparkle.wav': sfx_sparkle(),
        'rare.wav': sfx_rare(),
        'pioneer.wav': sfx_pioneer(),
        'click.wav': sfx_click(),
    }
    for name, sig in sounds.items():
        save(name, sig)
    save('bgm_mine.wav', bgm(), peak=0.7)


if __name__ == '__main__':
    main()
