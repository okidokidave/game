"""스트리머 키우기의 8비트 효과음과 배경음악을 코드로 합성해 WAV로 저장한다.

실행: python3 tool/generate_sounds.py   (influencer_sim 폴더에서, numpy 필요)
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
def sfx_coin():
    """돈 "짤랑": 두 음 위로."""
    return seq([
        env(square(freq('B5'), 0.05, 0.25), release=0.01),
        env(square(freq('E6'), 0.16, 0.25), release=0.12, decay_to=0.3),
    ]) * 0.6


def sfx_donate():
    """후원 "띠링~": 금전등록기 종소리 + 반짝임."""
    bell = seq([
        env(triangle(freq('E6'), 0.07), release=0.02),
        env(triangle(freq('B6'), 0.45), release=0.3, decay_to=0.05),
    ])
    sparkle = seq([np.zeros(int(RATE * 0.07))] + [env(square(freq(n), 0.04, 0.125), release=0.02) for n in ('E7', 'G#7', 'B7')])
    return mix(bell * 0.7, sparkle * 0.25)


def sfx_buy():
    """구입·이사: 올라가는 아르페지오."""
    return seq([env(square(freq(n), 0.055, 0.5), release=0.015) for n in ('C5', 'E5', 'G5', 'C6')]) * 0.5


def sfx_fanfare():
    """마일스톤·순위 상승 팡파르."""
    lead = seq([env(square(freq(n), d, 0.25), release=0.02)
                for n, d in (('G4', 0.09), ('C5', 0.09), ('E5', 0.09), ('G5', 0.12), ('E5', 0.07), ('G5', 0.4))])
    bass = seq([env(triangle(freq(n), d), release=0.02) for n, d in (('C3', 0.27), ('G3', 0.19), ('C4', 0.4))])
    return mix(lead * 0.55, bass * 0.5)


def sfx_alert():
    """사건 발생: 내려가는 두 번의 삑."""
    return seq([
        env(square(freq('A5'), 0.11, 0.5), release=0.02),
        np.zeros(int(RATE * 0.04)),
        env(square(freq('E5'), 0.15, 0.5), release=0.05),
    ]) * 0.45


def sfx_sparkle():
    """떡상: 반짝이는 빠른 고음."""
    return seq([env(square(freq(n), 0.045, 0.125), release=0.02) for n in ('E6', 'G6', 'B6', 'E7', 'B6', 'E7')]) * 0.4


def sfx_pop():
    """채팅 반응 성공: 짧게 튀어 오르는 소리."""
    return env(square(sweep(600, 1500, 0.07), 0.07, 0.25), release=0.03) * 0.5


def sfx_notify():
    """SNS 알림: 부드러운 두 번 톡톡."""
    return seq([
        env(triangle(freq('C6'), 0.06), release=0.03),
        np.zeros(int(RATE * 0.03)),
        env(triangle(freq('G6'), 0.12), release=0.08),
    ]) * 0.6


def sfx_click():
    """버튼 누를 때 작은 소리."""
    return env(square(freq('A6'), 0.025, 0.5), release=0.01) * 0.3


# ── 배경음악: 밝은 방송 BGM (C-Am-F-G) ───────────────────
BPM = 104
BEAT = 60 / BPM

MELODY = [
    ('E5', 1), ('G5', .5), ('E5', .5), ('D5', 1), ('C5', 1),
    ('A4', 1), ('C5', .5), ('E5', .5), ('A5', 1), ('G5', 1),
    ('F5', 1), ('E5', .5), ('F5', .5), ('A5', 1), ('C6', 1),
    ('B5', 1.5), ('A5', .5), ('G5', 2),
    ('E5', 1), ('G5', .5), ('C6', .5), ('B5', 1), ('G5', 1),
    ('A5', 1), ('E5', .5), ('C5', .5), ('E5', 1), ('A5', 1),
    ('F5', .5), ('G5', .5), ('A5', 1), ('G5', .5), ('F5', .5), ('E5', 1),
    ('D5', 1), ('G4', 1), ('C5', 2),
]

CHORDS = ['C', 'A', 'F', 'G'] * 2


def bgm():
    lead = []
    for note, beats in MELODY:
        dur = beats * BEAT
        lead.append(env(square(freq(note), dur, 0.25), release=min(0.06, dur / 3), decay_to=0.5))
    lead = seq(lead)

    # 베이스와 화음(아르페지오)
    triads = {'C': ('C', 'E', 'G'), 'A': ('A', 'C', 'E'), 'F': ('F', 'A', 'C'), 'G': ('G', 'B', 'D')}
    bass, arp = [], []
    for root in CHORDS:
        for k in range(8):
            n = f'{root}2' if k % 2 == 0 else f'{root}3'
            bass.append(env(triangle(freq(n), BEAT / 2), release=0.03))
            arp.append(env(square(freq(f'{triads[root][k % 3]}5'), BEAT / 2, 0.125), release=0.04, decay_to=0.3))
    bass, arp = seq(bass), seq(arp)

    bar_len = int(RATE * BEAT * 4)
    total = bar_len * len(CHORDS)
    drums = np.zeros(total)

    def put(sig, at):
        i = int(RATE * at)
        end = min(total, i + len(sig))
        drums[i:end] += sig[:end - i]

    kick = env(triangle(sweep(160, 45, 0.12), 0.12), release=0.05) * 0.9
    snare = env(noise(0.1, step=2), release=0.08, decay_to=0.1) * 0.3
    hat = env(noise(0.025), release=0.02) * 0.12
    for bar in range(len(CHORDS)):
        start = bar * BEAT * 4
        for beat in range(4):
            at = start + beat * BEAT
            put(kick if beat in (0, 2) else snare, at)
            put(hat, at + BEAT / 2)

    n = min(len(lead), len(bass), total)
    return lead[:n] * 0.28 + bass[:n] * 0.36 + arp[:n] * 0.08 + drums[:n] * 0.45


def main():
    os.makedirs(OUT, exist_ok=True)
    sounds = {
        'coin.wav': sfx_coin(),
        'donate.wav': sfx_donate(),
        'buy.wav': sfx_buy(),
        'fanfare.wav': sfx_fanfare(),
        'alert.wav': sfx_alert(),
        'sparkle.wav': sfx_sparkle(),
        'pop.wav': sfx_pop(),
        'notify.wav': sfx_notify(),
        'click.wav': sfx_click(),
    }
    for name, sig in sounds.items():
        save(name, sig)
    save('bgm_room.wav', bgm(), peak=0.65)


if __name__ == '__main__':
    main()
