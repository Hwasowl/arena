"""INFINITY sound palette: CC0 Kenney recordings layered with original synthesis."""
from pathlib import Path
import json
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / 'assets' / 'skill-pack-v1'
SR = 48000
RNG = np.random.default_rng(15102026)
FOLEY = ROOT / 'assets' / 'foley' / 'kenney'


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


def recorded(name, gain=1, rate=1):
    """Use a short CC0 recording for the audible attack; keep synthesis for fantasy tails."""
    with wave.open(str(FOLEY / (name + '.wav')), 'rb') as source:
        assert source.getnchannels() == 1 and source.getsampwidth() == 2 and source.getframerate() == SR
        x = np.frombuffer(source.readframes(source.getnframes()), dtype='<i2').astype(np.float64) / 32768
    positions = np.arange(max(1, round(len(x) / rate))) * rate
    return np.interp(positions, np.arange(len(x)), x, right=0) * gain


def foley(name, peak=.5, rate=1):
    x = recorded(name, 1, rate)
    return x * peak / max(np.max(np.abs(x)), .00001)


# The recorded attack gives each fantasy cue a physical material and a short sense
# of space. The original synthesis stays underneath for energy, lightning and scale.
# Entries are (seconds after cue, recording, peak, playback rate).
FOLEY_LAYERS = {
    'gojo_snap': [(0, 'metalClick', .48, 1.7)],
    'gojo_blue_charge': [(0, 'cloth1', .28, .8), (.82, 'impactBell_heavy_001', .18, 1.5)],
    'gojo_blue_pull': [(0, 'knifeSlice', .48, .75)],
    'gojo_red_release': [(0, 'impactPunch_heavy_003', .64, .85), (.04, 'impactGlass_light_003', .38, .9)],
    'gojo_purple_charge': [(0, 'clothBelt', .28, .75), (2.85, 'impactBell_heavy_001', .32, 1.3)],
    'gojo_purple_release': [(0, 'impactPlate_heavy_002', .7, .8), (.04, 'impactGlass_heavy_002', .42, .75)],
    'gojo_domain_open': [(0, 'impactBell_heavy_001', .58, .75), (.08, 'cloth1', .18, .55)],
    'zenitsu_breath': [(0, 'cloth1', .24, .7), (.82, 'cloth2', .2, .75)],
    'zenitsu_sheath': [(0, 'drawKnife1', .3, 1.5), (.16, 'metalLatch', .62, 1.35)],
    'zenitsu_flamegod': [(0, 'knifeSlice2', .52, 1.3), (.15, 'impactPunch_heavy_003', .53, .8)],
    'zenitsu_delayed_hit': [(0, 'impactPunch_heavy_001', .65, 1.1), (.025, 'impactMetal_medium_003', .34, 1.2)],
    'reze_fuse_loop': [(.13, 'impactGlass_light_003', .15, 2), (.59, 'impactGlass_light_003', .12, 2.5)],
    'reze_launch': [(0, 'impactPunch_heavy_003', .65, .9), (.025, 'footstep_concrete_001', .28, .8)],
    'reze_dive': [(0, 'knifeSlice2', .48, .8)],
    'reze_slam': [(0, 'impactPlank_medium_001', .62, .75), (.025, 'impactPunch_heavy_001', .55, .85)],
    'reze_hand_blast': [(0, 'impactPunch_heavy_003', .72, 1.1), (.016, 'impactGlass_light_003', .4, .9)],
    'reze_detonation_charge': [(0, 'clothBelt', .3, .7), (3.15, 'impactGlass_light_003', .23, .5)],
    'reze_detonation_blast': [(0, 'impactPlate_heavy_002', .75, .7), (.03, 'impactGlass_heavy_002', .52, .65)],
    'shanks_haki_charge': [(0, 'clothBelt', .3, .8)],
    'shanks_haki_pulse': [(0, 'impactBell_heavy_001', .52, 1.2), (.015, 'impactPunch_medium_002', .36, .8)],
    'shanks_draw': [(0, 'drawKnife1', .5, .95), (.08, 'metalLatch', .3, 1.3)],
    'shanks_slash': [(0, 'knifeSlice2', .55, .9)],
    'shanks_counter': [(0, 'knifeSlice', .5, 1.1), (.12, 'impactMetal_medium_003', .48, 1.2)],
    'shanks_departure_charge': [(0, 'drawKnife2', .34, .75), (1.7, 'clothBelt', .22, .8)],
    'shanks_departure_release': [(0, 'knifeSlice2', .62, .75), (.06, 'impactPlate_heavy_002', .58, .8)],
    'shared_dash': [(0, 'cloth1', .43, 1.55), (.04, 'footstep_concrete_001', .2, 1.1)],
}


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
    if id in FOLEY_LAYERS:
        layers = [(0, signal * (.62 if 'charge' in id or id == 'zenitsu_breath' else .42))]
        layers += [(at, foley(name, peak, rate)) for at, name, peak, rate in FOLEY_LAYERS[id]]
        signal = mix(duration, layers)
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
    add('gojo_domain_inside', 'gojo', '무량공처 내부 지속음', 2, '영역 안에 있는 동안만 반복; 밖으로 나가거나 영역이 끝나면 정지',
        mix(2, [(0, noise(2, 220, 2600, 3, .12, .12) * np.sin(np.pi*axis(2)/2)**2),
                (0, tone(2, 55, 3, .11, .08)), (.42, foley('impactBell_heavy_001', .12, 1.8)),
                (1.24, foley('cloth2', .08, .65))]), ['Domain'], True, .34)
    add('gojo_domain_end', 'gojo', '무량공처 닫힘', 1.05, '7.5초가 끝나 공간이 접힐 때',
        mix(1.05, [(0, foley('impactBell_heavy_001', .57, .85)),
                   (.04, sweep(1, 410, 45, .35, .28)),
                   (.12, foley('clothBelt', .21, .65))]), ['Domain'])
    add('gojo_domain_break', 'gojo', '영역 충돌 · 기존 영역 파괴', .85, '늦게 전개한 영역이 겹쳐 기존 영역을 깰 때',
        mix(.85, [(0, foley('impactGlass_heavy_002', .68, .7)),
                  (.015, foley('impactMetal_medium_003', .48, .8)),
                  (0, sweep(.85, 730, 56, .18, .27))]), ['Domain'])

    t = axis(2)
    breath = noise(2, 250, 2300, 20, .5, .1) * np.sin(np.pi*t/2)**1.5
    add('zenitsu_breath', 'zenitsu', '전집중 들숨', 2, '전집중 2초 준비 전체',
        mix(2, [(0, breath), (.6, charge(1.4, 210, 5400, .24))]), ['Breath'])
    add('zenitsu_thunderclap', 'zenitsu', '벽력일섬 질주', 1, '발도와 이동이 동시에 시작되는 프레임',
        mix(1, [(0, mix(1, [(0, electrical(1, True)), (0, sword(.5)), (.16, impact(.8, 1.7))])*.42),
                (0, recorded('drawKnife2', .7, 1.4)), (.16, recorded('impactPunch_heavy_001', .5, 1.15))]), ['Thunderclap'])
    add('zenitsu_sheath', 'zenitsu', '납도 클릭', .48, '질주 후 칼이 칼집에 잠기는 프레임',
        mix(.48, [(0, whoosh(.2, 4200, .12)), (.16, metal(.32, 1850, .2)), (.16, noise(.15, 400, 3000, .02, .18))]), ['Thunderclap', 'FlameGod'])
    add('zenitsu_flamegod', 'zenitsu', '화뢰신 용의 질주', 1.65, '화뢰신 이동 시작; 잔광까지',
        echo(mix(1.65, [(0, electrical(1.6, True)), (0, sweep(1.5, 135, 42, .6, .3)), (.04, sword(.7)), (.15, noise(1.5, 300, 2500, .5, .3))]), .055, .22), ['FlameGod'])
    add('zenitsu_delayed_hit', 'zenitsu', '화뢰신 지연 적중', .7, '통과 후 서버 HitDelay 0.9초의 적중 프레임',
        mix(.7, [(0, impact(.7, 1.8)), (0, electrical(.5, True)), (.025, metal(.65, 700, .08))]), ['FlameGod'])

    add('reze_pin', 'reze', '쵸커 핀 당기기 · 팅', .42, '고리를 오른쪽으로 확 당겨 빠지는 순간',
        mix(.42, [(0, mix(.42, [(0, noise(.04, 1500, 14000, .006, .22)),
                              (.007, metal(.413, 2350, .65)), (.001, tone(.2, 450, .018, .15))])*.18),
                  (0, recorded('metalLatch', .75, 1.25)), (.025, recorded('metalClick', .9, 1.25))]), ['BombDevil'])
    t = axis(1)
    fuse = noise(1, 1700, 11500, 30, .16, .005) * (.58 + .42 * np.sin(2*np.pi*37*t)**2)
    for at in np.arange(.03, .98, .073):
        fuse += mix(1, [(float(at), noise(.018, 4000, 15000, .004, .25))])
    add('reze_fuse_loop', 'reze', '도화선 지글거림 · 반복', 1, '도화선이 타는 동안 반복, 종료·변신·사망 때 정지', fuse, ['BombDevil', 'Detonation'], True, .5)
    add('reze_transform', 'reze', '변신 폭발', 1.7, '변신 폭발 및 암전이 시작될 때',
        mix(1.7, [(0, echo(mix(1.7, [(0, impact(1.7, 1.05)),
                                    (.008, noise(1.2, 150, 7000, .26, .45)),
                                    (.07, metal(1.6, 390, .09))]), .13, .18)*.35),
                  (0, recorded('impactPunch_heavy_001', 1, .85)),
                  (.025, recorded('impactGlass_heavy_002', .68, .85))]), ['BombDevil'])
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
        mix(.75, [(0, echo(mix(.75, [(0, metal(.75, 1230, .75)),
                                    (0, noise(.15, 1800, 13000, .013, .27)),
                                    (.008, tone(.35, 260, .04, .18))]), .04, .17)*.25),
                  (0, recorded('impactMetal_light_001', .85, .9)),
                  (.018, recorded('impactTin_medium_000', .5, .7))]), ['EnGardeParry'])
    add('shanks_counter', 'shanks', '패링 후 반격', .8, '패링 성공 후 서버 반격 프레임',
        mix(.8, [(0, sword(.65, True)), (.12, impact(.68, 1.55)), (.09, electrical(.55))]), ['EnGardeParry'])
    add('shanks_departure_charge', 'shanks', '카무사리 패기 응축', 2.5, '카무사리 2.5초 준비 전체',
        mix(2.5, [(0, charge(2.5, 52, 4700, .85)), (1.7, metal(.8, 790, .12)), (1.9, whoosh(.6, 9000, .3))]), ['DivineDeparture'])
    add('shanks_departure_release', 'shanks', '카무사리 참격', 1.5, '2.5초 준비 종료 후 장거리 참격',
        echo(mix(1.5, [(0, sword(1.05, True)), (.02, electrical(1.2)), (.045, impact(1.45, .88)), (.08, sweep(1.3, 350, 40, .4, .3))]), .09, .21), ['DivineDeparture'])
    add('shared_dash', 'shared', '공통 대시', .4, 'Shift 이동 시작 프레임',
        mix(.4, [(0, whoosh(.4, 5200, .6)), (0, sweep(.4, 390, 105, .16, .14))]), ['Dash'], gain=.65)

    # Movement and basic attacks use separate preparation, swing, contact and recovery cues.
    add('shared_jump', 'shared', '점프 발구름', .32, '지상 Space로 점프가 시작될 때',
        mix(.32, [(0, foley('footstep_concrete_001', .64)), (.03, foley('cloth1', .27, 1.7)),
                  (.04, whoosh(.28, 3800, .16))]), ['Jump'])
    add('shared_land', 'shared', '착지', .42, '일반 점프 후 지면에 닿을 때',
        mix(.42, [(0, foley('footstep_concrete_003', .55, .75)),
                  (.018, foley('impactSoft_medium_001', .34, .9)), (.04, foley('cloth2', .2, 1.3))]), ['Jump'])
    add('shared_slide_start', 'shared', '슬라이딩 발동', .34, '몸이 낮아지고 발이 바닥을 밀기 시작할 때',
        mix(.34, [(0, foley('footstep_concrete_001', .45, 1.1)),
                  (.035, foley('cloth1', .56, 1.25)), (.06, whoosh(.27, 2800, .23))]), ['Slide'])
    add('shared_slide_scrape', 'shared', '슬라이딩 마찰', .7, '0.7초 슬라이딩 중 바닥 마찰',
        mix(.7, [(0, foley('knifeSlice', .26, .85)), (.06, foley('clothBelt', .46, 1.05)),
                 (0, noise(.7, 200, 2500, .5, .07))]), ['Slide'])
    add('shared_slide_end', 'shared', '슬라이딩 멈춤', .29, '슬라이딩 종료·벽 충돌·점프 취소',
        mix(.29, [(0, foley('footstep_concrete_003', .58, 1.25)),
                  (.02, foley('cloth2', .32, 1.5))]), ['Slide'])
    for i, source in enumerate(['cloth1', 'cloth2', 'clothBelt'], 1):
        add(f'shared_punch_swing_{i}', 'shared', f'평타 {i}타 공기 가르기', .3,
            f'평타 {i}타 준비가 끝나고 주먹이 나가는 순간',
            mix(.3, [(0, foley(source, .46, 1.3 + i*.14)),
                     (0, whoosh(.3, 4200+i*600, .24))]), ['BasicAttack'])
    for i, source in enumerate(['impactPunch_medium_002', 'impactPunch_heavy_001', 'impactPunch_heavy_003'], 1):
        add(f'shared_punch_hit_{i}', 'shared', f'평타 {i}타 적중', .52,
            f'평타 {i}타 실제 적중 프레임',
            mix(.52, [(0, foley(source, .7, 1.18-i*.1)),
                      (.018, impact(.5, .8+i*.2)*.22)]), ['BasicAttack'])
    for i, source in enumerate(['knifeSlice', 'knifeSlice2', 'knifeSlice'], 1):
        add(f'shared_sword_swing_{i}', 'shared', f'검 평타 {i}타 베기', .45,
            f'젠이츠·샹크스 평타 {i}타 칼이 나가는 순간',
            mix(.45, [(0, foley(source, .64, .9+i*.11)),
                      (0, sword(.45)*.23)]), ['BasicAttack'])
    add('shared_sword_hit', 'shared', '검 평타 적중', .48, '검 평타 실제 적중 프레임',
        mix(.48, [(0, foley('impactMetal_medium_003', .49, 1.2)),
                  (.01, foley('impactPunch_medium_002', .44, 1.2))]), ['BasicAttack'])
    add('shared_crack', 'shared', '번개·충격 잔타', .25, '짧은 번개나 접촉 충격 프레임',
        mix(.25, [(0, foley('impactGlass_light_003', .6, 1.5)),
                  (0, electrical(.22)*.17)]), ['Impact'])
    add('shared_boom', 'shared', '작은 폭발', .9, '기본공격 폭발·파편 폭발 프레임',
        mix(.9, [(0, foley('impactPunch_heavy_003', .7, .78)),
                 (.02, foley('impactGlass_heavy_002', .4, 1.15)),
                 (0, impact(.9, 1.25)*.32)]), ['Impact'])
    add('shared_rustle', 'shared', '옷·주머니 마찰', .28, '손이 옷·주머니를 뒤적이는 프레임',
        foley('cloth1', .62, 2.1)[:round(.28*SR)], ['Foley'])
    add('dora_gadget', 'doraemon', '도구 꺼내기', .5, '주머니에서 도구가 나올 때',
        mix(.5, [(0, foley('clothBelt', .35, 1.55)), (.1, foley('metalClick', .4, 1.5))]), ['Pocket'])
    add('dora_light', 'doraemon', '스몰라이트', .4, '빛이 발사될 때',
        mix(.4, [(0, foley('impactBell_heavy_001', .33, 4)), (0, sweep(.4, 1100, 480, .12, .15))]), ['Pocket'])
    add('dora_air', 'doraemon', '공기포', .47, '공기포가 발사·벽에 닿을 때',
        mix(.47, [(0, foley('impactSoft_medium_001', .56, .85)),
                  (0, whoosh(.47, 2400, .4))]), ['Pocket'])
    add('dora_bite', 'doraemon', '단팥빵 한입', .36, '단팥빵을 먹을 때',
        mix(.36, [(0, foley('impactSoft_medium_001', .28, 1.6)),
                  (.04, foley('cloth2', .25, 1.5))]), ['Pocket'])
    add('dora_rotor', 'doraemon', '대나무 헬리콥터 회전', .25, '헬리콥터 날개 반복 회전 박자',
        mix(.25, [(0, foley('cloth1', .3, 2.6)), (0, whoosh(.25, 2600, .15))]), ['Copter'])
    add('dora_door', 'doraemon', '어디로든 문 개방', .55, '문이 열릴 때',
        mix(.55, [(0, foley('impactPlank_medium_001', .3, 1.25)),
                  (.08, foley('clothBelt', .32, 1.2))]), ['Door'])

    manifest_path = PACK / 'manifest.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8-sig'))
    manifest['sounds'] = CLIPS
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\r\n')
    print(f'Created {len(CLIPS)} layered WAV files, 48 kHz / 16 bit / mono.')


if __name__ == '__main__':
    make()
