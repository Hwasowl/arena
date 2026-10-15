"""Original INFINITY sound palette. Python + NumPy; no recordings or downloaded samples."""
from pathlib import Path
import json
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / 'assets' / 'skill-pack-v1'
SR = 48000
RNG = np.random.default_rng(15102026)


def axis(duration):
    return np.arange(round(duration * SR), dtype=np.float64) / SR


def env(t, attack=.004, decay=.25, release=.04):
    return np.minimum(1, t / attack) * np.exp(-t / decay) * np.minimum(1, (len(t) / SR - t) / release)


def sweep(duration, start, end, decay=.25, gain=1, attack=.003):
    t = axis(duration)
    phase = 2 * np.pi * (start * t + (end - start) * t * t / (2 * duration))
    return np.sin(phase) * env(t, attack, decay) * gain


def tone(duration, frequency, decay=.3, gain=1, attack=.003):
    t = axis(duration)
    return np.sin(2 * np.pi * frequency * t) * env(t, attack, decay) * gain


def noise(duration, low=100, high=12000, decay=.25, gain=1, attack=.002):
    t = axis(duration)
    n = len(t)
    spectrum = np.fft.rfft(RNG.standard_normal(n))
    f = np.fft.rfftfreq(n, 1 / SR)
    # Smooth bands avoid the ringing of a rectangular frequency cutoff.
    filt = (1 - np.exp(-(f / max(low, 1)) ** 4)) * np.exp(-(f / high) ** 4)
    x = np.fft.irfft(spectrum * filt, n=n)
    x /= max(np.sqrt(np.mean(x * x)), .00001)
    return x * env(t, attack, decay) * gain


def metal(duration=.6, base=1700, gain=.3):
    x = np.zeros(len(axis(duration)))
    for ratio, strength in [(1, 1), (1.478, .53), (2.117, .25), (3.613, .12)]:
        x += tone(duration, base * ratio, .14 / np.sqrt(ratio), strength * gain)
    return x


def mix(duration, layers):
    out = np.zeros(len(axis(duration)))
    for at, signal in layers:
        start = round(at * SR)
        count = min(len(signal), len(out) - start)
        if count > 0:
            out[start:start + count] += signal[:count]
    return out


def echo(x, delay=.09, amount=.18, repeats=3):
    out = x.copy()
    for i in range(1, repeats + 1):
        shift = round(delay * SR * i)
        if shift < len(out):
            out[shift:] += x[:-shift] * amount ** i
    return out


def impact(duration=.8, weight=1):
    return mix(duration, [(0, sweep(duration, 130 * weight, 34, .21, .65)),
                          (0, noise(duration, 80, 4300, .15, .30)),
                          (.012, noise(max(.03, duration - .012), 1400, 10000, .025, .14))])


def whoosh(duration=.5, brightness=5000, gain=.5):
    t = axis(duration)
    x = noise(duration, 300, brightness, 10, gain, .005)
    return x * np.sin(np.pi * t / duration) ** 2


def charge(duration, base=100, bright=3000, gain=.3):
    t = axis(duration)
    ramp = np.sin(np.pi / 2 * t / duration) ** 1.5
    oscillator = np.sin(2 * np.pi * (base * t + base * .7 * t * t / duration))
    overtone = np.sin(2 * np.pi * (base * 2.01 * t + base * 1.2 * t * t / duration))
    x = (oscillator * .32 + overtone * .11 + noise(duration, 300, bright, 20, .25)) * ramp * gain
    x *= .8 + .2 * np.sin(2 * np.pi * (4 * t + 9 * t * t / duration))
    x[-round(.025 * SR):] *= np.linspace(1, 0, round(.025 * SR))
    return x


def electrical(duration=.8, gold=False):
    duration = max(duration, .1)
    layers = [(0, whoosh(duration, 10500 if gold else 6500, .35)), (0, sweep(duration, 320, 65, .22, .3))]
    for at in [.004, .025, .053, .095, .155, .23]:
        if at + .06 < duration:
            layers.append((at, noise(.06, 1500, 13000, .009, .28)))
    return mix(duration, layers)


def sword(duration=.5, heavy=False):
    return mix(duration, [(0, whoosh(duration, 6200 if heavy else 10000, .5)),
                          (.035, sweep(duration - .035, 900 if heavy else 1700, 130, .12, .22)),
                          (.03, metal(duration - .03, 1250 if heavy else 2200, .06))])


CLIPS = []


def add(id, character, label, duration, cue, signal, skills, loop=False, gain=.85):
    # Keep the attacks intact; restrained saturation catches coincident transient peaks.
    x = np.tanh(signal * 1.15)
    peak = max(np.max(np.abs(x)), .00001)
    x *= min(gain / peak, .18 / max(np.sqrt(np.mean(x * x)), .00001))
    fade = min(round(.004 * SR), len(x) // 4)
    x[:fade] *= np.linspace(0, 1, fade)
    x[-fade:] *= np.linspace(1, 0, fade)
    path = PACK / 'sounds' / character / (id + '.wav')
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = (np.clip(x, -1, 1) * 32767).astype('<i2')
    with wave.open(str(path), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    CLIPS.append(dict(id=id, character=character, label=label, file=path.relative_to(PACK).as_posix(),
                      duration=round(len(x) / SR, 3), cue=cue, skills=skills, loop=loop,
                      uploadAssetId='', sampleRate=SR, channels=1, bits=16,
                      peakDbFS=round(20 * np.log10(max(np.max(np.abs(x)), 1e-10)), 2),
                      rmsDbFS=round(20 * np.log10(max(np.sqrt(np.mean(x*x)), 1e-10)), 2)))


def make():
    add('gojo_snap', 'gojo', '손가락 스냅', .22, '아오 손가락이 맞닿는 프레임',
        mix(.22, [(0, noise(.12, 1200, 13000, .009, .6)), (.003, tone(.16, 870, .016, .28)), (.009, noise(.17, 180, 1300, .028, .16))]), ['Blue'])
    add('gojo_blue_charge', 'gojo', '아오 응축', 1.2, '아오 구체 생성부터 홀드 중 앞부분',
        echo(charge(1.2, 165, 3800, .9), .067, .17), ['Blue'])
    add('gojo_blue_pull', 'gojo', '아오 흡인', .85, '구체가 앞으로 나가고 흡인이 시작될 때',
        mix(.85, [(0, whoosh(.85, 2600, .55)), (.1, sweep(.75, 100, 390, .5, .18)), (.03, tone(.8, 82, .45, .2))]), ['Blue'])
    add('gojo_red_release', 'gojo', '아카 반발', .75, '아카 발사 프레임',
        mix(.75, [(0, impact(.75, 1.45)), (0, electrical(.4)), (.03, sweep(.65, 960, 105, .12, .23))]), ['Red'])
    add('gojo_purple_charge', 'gojo', '무라사키 융합', 3.6, '무라사키 준비 시작; 2.85초에 융합 악센트',
        mix(3.6, [(0, charge(3.6, 70, 5000, .95)), (2.85, metal(.75, 580, .11)), (2.85, sweep(.75, 350, 1100, .65, .16))]), ['Purple'])
    add('gojo_purple_release', 'gojo', '무라사키 발사', 1.5, '3.6초 준비 종료 후 발사',
        echo(mix(1.5, [(0, impact(1.5, 1.3)), (0, electrical(1.1)), (.08, tone(1.4, 55, .55, .25))]), .14, .23), ['Purple'])
    add('gojo_domain_open', 'gojo', '무량공처 전개', 2.6, '2초 준비 후 영역이 펼쳐질 때',
        echo(mix(2.6, [(0, sweep(2.6, 240, 48, 1.2, .28)), (0, tone(2.6, 73.4, 1.5, .2)), (.08, metal(2.3, 440, .1)), (.1, whoosh(2.3, 2200, .27))]), .21, .35), ['Domain'])

    t = axis(2)
    breath = noise(2, 250, 2300, 20, .5, .1) * np.sin(np.pi*t/2)**1.5
    add('zenitsu_breath', 'zenitsu', '전집중 들숨', 2, '전집중 2초 준비 전체',
        mix(2, [(0, breath), (.6, charge(1.4, 210, 5400, .24))]), ['Breath'])
    add('zenitsu_thunderclap', 'zenitsu', '벽력일섬 질주', 1, '발도와 이동이 동시에 시작되는 프레임',
        mix(1, [(0, electrical(1, True)), (0, sword(.5)), (.16, impact(.8, 1.7))]), ['Thunderclap'])
    add('zenitsu_sheath', 'zenitsu', '납도 클릭', .48, '질주 후 칼이 칼집에 잠기는 프레임',
        mix(.48, [(0, whoosh(.2, 4200, .12)), (.16, metal(.32, 1850, .2)), (.16, noise(.15, 400, 3000, .02, .18))]), ['Thunderclap', 'FlameGod'])
    add('zenitsu_flamegod', 'zenitsu', '화뢰신 용의 질주', 1.65, '화뢰신 이동 시작; 잔광까지',
        echo(mix(1.65, [(0, electrical(1.6, True)), (0, sweep(1.5, 135, 42, .6, .3)), (.04, sword(.7)), (.15, noise(1.5, 300, 2500, .5, .3))]), .055, .22), ['FlameGod'])
    add('zenitsu_delayed_hit', 'zenitsu', '화뢰신 지연 적중', .7, '통과 후 서버 HitDelay 0.9초의 적중 프레임',
        mix(.7, [(0, impact(.7, 1.8)), (0, electrical(.5, True)), (.025, metal(.65, 700, .08))]), ['FlameGod'])

    add('reze_pin', 'reze', '쵸커 핀 당기기 · 팅', .42, '고리를 오른쪽으로 확 당겨 빠지는 순간',
        mix(.42, [(0, noise(.04, 1500, 14000, .006, .22)), (.007, metal(.413, 2350, .65)), (.001, tone(.2, 450, .018, .15))]), ['BombDevil'])
    t = axis(1)
    fuse = noise(1, 1700, 11500, 30, .16, .005) * (.58 + .42 * np.sin(2*np.pi*37*t)**2)
    for at in np.arange(.03, .98, .073):
        fuse += mix(1, [(float(at), noise(.018, 4000, 15000, .004, .25))])
    add('reze_fuse_loop', 'reze', '도화선 지글거림 · 반복', 1, '도화선이 타는 동안 반복, 종료·변신·사망 때 정지', fuse, ['BombDevil', 'Detonation'], True, .5)
    add('reze_transform', 'reze', '변신 폭발', 1.7, '변신 폭발 및 암전이 시작될 때',
        echo(mix(1.7, [(0, impact(1.7, 1.05)), (.008, noise(1.2, 150, 7000, .26, .45)), (.07, metal(1.6, 390, .09))]), .13, .18), ['BombDevil'])
    add('reze_launch', 'reze', '발밑 폭발 도약', .7, '0.4초 웅크린 뒤 발밑 폭발과 상승',
        mix(.7, [(0, impact(.6, 1.6)), (.06, whoosh(.64, 6200, .4)), (.08, sweep(.6, 240, 580, .45, .1))]), ['Rampage'])
    add('reze_dive', 'reze', '공중 급강하', .8, '공중 Q 재입력부터 착지까지; 착지 시 중지 가능',
        mix(.8, [(0, whoosh(.8, 7900, .5)), (0, sweep(.8, 1300, 180, .65, .2))]), ['RampageDive'])
    add('reze_slam', 'reze', '급강하 지면 충돌', 1.1, '지면에 닿는 순간',
        mix(1.1, [(0, impact(1.1, .9)), (.03, noise(1.05, 100, 3200, .3, .32)), (.08, noise(.7, 2200, 8000, .15, .12))]), ['RampageDive'])
    add('reze_hand_blast', 'reze', '근거리 손 폭발', .65, '오른손을 든 뒤 앞쪽 폭발 프레임',
        mix(.65, [(0, impact(.65, 2)), (0, noise(.3, 900, 12000, .045, .45)), (.02, sweep(.5, 700, 100, .09, .19))]), ['Kick'])
    add('reze_detonation_charge', 'reze', '전면 폭발 압축', 4, '변신 후 궁극기 4초 준비 전체; 폭발 직전 절정',
        mix(4, [(0, charge(4, 45, 8000, 1)), (3.15, charge(.85, 160, 11000, .6))]), ['Detonation'])
    add('reze_detonation_blast', 'reze', '전면 폭발', 2.3, '4초 준비 종료 후 폭발',
        echo(mix(2.3, [(0, impact(2.3, .78)), (.02, noise(2.28, 60, 6000, .52, .55)), (.12, tone(2.1, 43, .75, .3)), (.07, noise(1.8, 1800, 10000, .28, .2))]), .19, .27), ['Detonation'])

    add('shanks_haki_charge', 'shanks', '패기 집중', .5, '패왕색 0.5초 준비', charge(.5, 65, 3000, 1), ['Haki'])
    add('shanks_haki_pulse', 'shanks', '패왕색 압력파', 1, '준비 후 첫 파동, 1초 뒤 두 번째 파동에 각각 재생',
        echo(mix(1, [(0, impact(1, .7)), (.01, electrical(.65)), (0, sweep(1, 140, 32, .4, .33))]), .075, .18), ['Haki'])
    add('shanks_draw', 'shanks', '검 자세 진입', .65, 'E 자세에 들어가 검을 올릴 때',
        mix(.65, [(0, whoosh(.5, 6000, .23)), (.08, metal(.57, 1550, .15)), (.04, sweep(.6, 1300, 450, .3, .1))]), ['EnGarde'])
    add('shanks_slash', 'shanks', '전진 베기', .6, '자세 중 좌클릭 전진 베기', sword(.6, True), ['EnGardeSlash'])
    add('shanks_parry', 'shanks', '패링 금속 충돌', .75, '1초 가드 중 실제 공격을 막은 순간에만',
        echo(mix(.75, [(0, metal(.75, 1230, .75)), (0, noise(.15, 1800, 13000, .013, .27)), (.008, tone(.35, 260, .04, .18))]), .04, .17), ['EnGardeParry'])
    add('shanks_counter', 'shanks', '패링 후 반격', .8, '패링 성공 후 서버 반격 프레임',
        mix(.8, [(0, sword(.65, True)), (.12, impact(.68, 1.55)), (.09, electrical(.55))]), ['EnGardeParry'])
    add('shanks_departure_charge', 'shanks', '카무사리 패기 응축', 2.5, '카무사리 2.5초 준비 전체',
        mix(2.5, [(0, charge(2.5, 52, 4700, .85)), (1.7, metal(.8, 790, .12)), (1.9, whoosh(.6, 9000, .3))]), ['DivineDeparture'])
    add('shanks_departure_release', 'shanks', '카무사리 참격', 1.5, '2.5초 준비 종료 후 장거리 참격',
        echo(mix(1.5, [(0, sword(1.05, True)), (.02, electrical(1.2)), (.045, impact(1.45, .88)), (.08, sweep(1.3, 350, 40, .4, .3))]), .09, .21), ['DivineDeparture'])
    add('shared_dash', 'shared', '공통 대시', .4, 'Shift 이동 시작 프레임',
        mix(.4, [(0, whoosh(.4, 5200, .6)), (0, sweep(.4, 390, 105, .16, .14))]), ['Dash'], gain=.65)

    manifest_path = PACK / 'manifest.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8-sig'))
    manifest['sounds'] = CLIPS
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\r\n')
    print(f'Created {len(CLIPS)} original WAV files, 48 kHz / 16 bit / mono.')


if __name__ == '__main__':
    make()
