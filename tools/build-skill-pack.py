"""Assemble import assets, contact sheet, standalone audition gallery, and Roblox catalog."""
from pathlib import Path
import json, shutil, html, wave, zipfile
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / 'assets' / 'skill-pack-v1'


def textwrite(path, text):
    path.write_text(text, encoding='utf-8', newline='\r\n')


def build():
    manifest = json.loads((PACK / 'manifest.json').read_text(encoding='utf-8-sig'))
    source = PACK / 'generated-sources.json'
    sources = json.loads(source.read_text(encoding='utf-8-sig'))
    (PACK / 'icons').mkdir(exist_ok=True)
    (PACK / 'sources').mkdir(exist_ok=True)
    for icon in manifest['icons']:
        src = Path(sources[icon['id']])
        if not src.is_absolute():
            src = PACK / src
        destination = PACK / 'sources' / (icon['id'] + '.png')
        if src.resolve() != destination.resolve():
            shutil.copy2(src, destination)
        image = Image.open(src).convert('RGBA')
        bounds = image.getchannel('A').getbbox()
        if not bounds:
            raise ValueError('Empty icon: ' + icon['id'])
        image = image.crop(bounds)
        image.thumbnail((432, 432), Image.Resampling.LANCZOS)
        canvas = Image.new('RGBA', (512, 512))
        canvas.alpha_composite(image, ((512-image.width)//2, (512-image.height)//2))
        canvas.save(PACK / icon['file'], optimize=True)
        icon['width'] = 512
        icon['height'] = 512
        icon['safeMarginPx'] = 40
    textwrite(PACK / 'manifest.json', json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')

    # Contact sheet includes small actual HUD size samples for every icon.
    font = ImageFont.truetype('C:/Windows/Fonts/malgun.ttf', 21)
    small = ImageFont.truetype('C:/Windows/Fonts/malgun.ttf', 14)
    title = ImageFont.truetype('C:/Windows/Fonts/malgunbd.ttf', 30)
    groups = [('gojo', 'GOJO / 고죠', '#58bfff'), ('zenitsu', 'ZENITSU / 젠이츠', '#ffda65'),
              ('reze', 'REZE / 레제', '#ff9c62'), ('shanks', 'SHANKS / 샹크스', '#ff687a'),
              ('shared', 'SHARED / 공통', '#a7d9eb')]
    sheet = Image.new('RGB', (1360, 1420), '#0b101a')
    draw = ImageDraw.Draw(sheet)
    draw.text((36, 20), 'INFINITY / ABILITY ICONS · V1', font=title, fill='#f2f5ff')
    draw.text((38, 62), '512px transparent PNG  /  48px HUD samples  /  18 icons', font=small, fill='#9daabc')
    y = 100
    for group, label, color in groups:
        draw.text((36, y), label, font=font, fill=color)
        y += 34
        for index, icon in enumerate(i for i in manifest['icons'] if i['character'] == group):
            x = 36 + index * 260
            draw.rounded_rectangle((x, y, x+244, y+201), radius=14, fill='#141d2c', outline='#28374d')
            original = Image.open(PACK / icon['file']).convert('RGBA')
            big = original.resize((154,154), Image.Resampling.LANCZOS)
            sheet.paste(big, (x+10,y+4), big)
            tiny = original.resize((48,48), Image.Resampling.LANCZOS)
            draw.rounded_rectangle((x+179,y+28,x+235,y+84), radius=8, fill='#080d15', outline='#40516a')
            sheet.paste(tiny, (x+183,y+32), tiny)
            draw.text((x+181,y+91), '48px', font=small, fill='#9daabc')
            draw.text((x+14,y+151), icon['label'], font=font, fill='#eef4ff')
            draw.text((x+14,y+179), icon['skill'], font=small, fill='#9daabc')
        y += 214
    sheet.crop((0,0,1360,y+10)).save(PACK / 'icon-contact-sheet.jpg', quality=94)

    # Data embedded so the gallery also opens directly from a local file.
    payload = json.dumps(manifest, ensure_ascii=False).replace('</', '<\\/')
    page = '''<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>INFINITY · 스킬 에셋 V1</title><style>
:root{color-scheme:dark;font-family:system-ui,'Malgun Gothic',sans-serif;background:#0b101a;color:#ecf3ff}*{box-sizing:border-box}body{max-width:1440px;margin:auto;padding:32px}h1{font-size:32px;letter-spacing:-1px;margin:8px 0}header p{color:#9baec4;margin:10px 0;line-height:1.6}.tools{display:flex;gap:16px;flex-wrap:wrap;align-items:center;margin:22px 0 28px}button,select{font:inherit;color:inherit;background:#18263b;border:1px solid #3d5069;border-radius:8px;padding:10px 14px;cursor:pointer}button:hover{background:#253c59}input{accent-color:#64c5ff}section{margin:32px 0}h2{font-size:23px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:16px}.card{min-width:0;border:1px solid #293a51;border-radius:16px;background:#131e2f;padding:18px}.art{height:188px;display:flex;align-items:center;justify-content:center;border-radius:10px;background:#080e18}.light .art{background:#e7edf5}.art img{height:184px;width:184px;object-fit:contain}.sample{display:flex;align-items:center;gap:10px;color:#8fa5bf;font-size:12px;margin:12px 0}.sample img{width:48px;height:48px;background:#080e18;border:1px solid #3d5069;border-radius:8px}.card h3{font-size:18px;margin:8px 0}.skill{color:#849ab6;font-size:12px;margin:6px 0 14px}.sound{border-top:1px solid #293a51;padding-top:12px;margin-top:12px}.sound button{width:100%;display:flex;justify-content:space-between;gap:8px;text-align:left;font-size:13px}.sound p{color:#96abc4;font-size:12px;line-height:1.6;margin:7px 0}.sequence{background:#193729;border-color:#3e7357}.badge{font-size:12px;color:#a9bfd6}.footer{border-top:1px solid #293a51;padding-top:20px;color:#91a8c2;font-size:13px;line-height:1.8}a{color:#80d2ff}#now{color:#afdbf3;min-height:22px;font-size:13px}body.compact .art{height:90px}body.compact .art img{height:64px;width:64px}@media(max-width:620px){body{padding:18px}.grid{grid-template-columns:1fr}}
</style><header><div class="badge">INFINITY / ORIGINAL ASSET PACK / V1</div><h1>스킬 아이콘과 효과음</h1><p>고죠 · 젠이츠 · 레제 · 샹크스. 아이콘 18개 / 녹음과 합성음을 겹친 효과음 __SOUND_COUNT__개.<br>큰 그림과 실제 HUD 크기를 함께 확인하고, 각 효과음을 눌러 들어보세요.</p></header>
<div class="tools"><button id="theme">밝은 배경으로 보기</button><button id="compact">64px로 보기</button><button id="stop">모든 소리 정지</button><label>볼륨 <input id="volume" type="range" min="0" max="1" step="0.05" value="0.65"></label></div><div id="now" role="status" aria-live="polite"></div><main id="main"></main><div class="footer">PNG: 512 × 512, 투명 배경. WAV: 48,000Hz · 16bit · 모노.<br>게임 업로드 전 시안입니다. 실제 녹음층은 Kenney CC0. Roblox 에셋 ID는 업로드 후 <a href="RobloxAssets.luau">RobloxAssets.luau</a>에 채웁니다. 합성음에는 애니메이션 원본 음성·음원을 사용하지 않았습니다.<br><a href="README.md">에셋 설명</a> · <a href="manifest.json">파일·타이밍 목록</a> · <a href="icon-contact-sheet.jpg">아이콘 한눈에 보기</a></div>
<script>const pack=__PACK__;let active=[],timers=[];const volume=document.getElementById('volume'),now=document.getElementById('now');
function stop(){active.forEach(a=>{a.pause();a.currentTime=0});active=[];timers.forEach(clearTimeout);timers=[];now.textContent=''}
function playSound(sound,at=0){const a=new Audio(sound.file);a.volume=Number(volume.value);active.push(a);if(at>0)timers.push(setTimeout(()=>a.play().catch(()=>now.textContent='재생을 시작하려면 효과음 버튼을 눌러 주세요.'),at*1000));else a.play().catch(()=>now.textContent='오디오 파일을 열지 못했습니다.');return a}
function play(id){stop();const s=pack.sounds.find(s=>s.id===id);playSound(s);now.textContent=s.label+' · '+s.cue}
const sequences={Purple:[[0,'gojo_purple_charge'],[3.6,'gojo_purple_release']],FlameGod:[[0,'zenitsu_flamegod'],[.9,'zenitsu_delayed_hit'],[1.6,'zenitsu_sheath']],BombDevil:[[0,'reze_pin'],[.01,'reze_transform']],Detonation:[[0,'reze_detonation_charge'],[0,'reze_fuse_loop'],[1,'reze_fuse_loop'],[2,'reze_fuse_loop'],[3,'reze_fuse_loop'],[4,'reze_detonation_blast']],Haki:[[0,'shanks_haki_charge'],[.5,'shanks_haki_pulse'],[1.5,'shanks_haki_pulse']],DivineDeparture:[[0,'shanks_departure_charge'],[2.5,'shanks_departure_release']]};
function sequence(skill){stop();sequences[skill].forEach(([at,id])=>playSound(pack.sounds.find(s=>s.id===id),at));now.textContent='연속 재생 · '+skill}
const groups=[['gojo','고죠','#58bfff'],['zenitsu','젠이츠','#ffda65'],['reze','레제','#ff9c62'],['shanks','샹크스','#ff687a'],['shared','공통','#a7d9eb']];
for(const [group,label,color] of groups){const section=document.createElement('section');const heading=document.createElement('h2');heading.textContent=label;heading.style.color=color;section.append(heading);const grid=document.createElement('div');grid.className='grid';for(const icon of pack.icons.filter(i=>i.character===group)){const card=document.createElement('article');card.className='card';const art=document.createElement('div');art.className='art';const image=document.createElement('img');image.src=icon.file;image.alt=icon.label;art.append(image);card.append(art);const sample=document.createElement('div');sample.className='sample';const tiny=image.cloneNode();sample.append(tiny,document.createTextNode('실제 HUD 48px'));card.append(sample);const name=document.createElement('h3');name.textContent=icon.label;card.append(name);const skill=document.createElement('div');skill.className='skill';skill.textContent=icon.skill+' · 512px PNG';card.append(skill);if(sequences[icon.skill]){const button=document.createElement('button');button.className='sequence';button.textContent='▶ 준비 → 발동 연속 듣기';button.onclick=()=>sequence(icon.skill);card.append(button)}for(const sound of pack.sounds.filter(s=>s.skills.includes(icon.skill))){const row=document.createElement('div');row.className='sound';const button=document.createElement('button');const text=document.createElement('span');text.textContent='▶ '+sound.label;const duration=document.createElement('span');duration.textContent=sound.duration.toFixed(2)+'s';button.append(text,duration);button.onclick=()=>play(sound.id);const cue=document.createElement('p');cue.textContent=sound.cue;row.append(button,cue);card.append(row)}grid.append(card)}section.append(grid);document.getElementById('main').append(section)}
const library=document.createElement('section');library.innerHTML='<h2>전체 효과음 목록</h2><p>스킬·이동·점프·슬라이딩·평타·도구 소리를 개별로 들어볼 수 있습니다.</p>';const soundGrid=document.createElement('div');soundGrid.className='grid';for(const [group,label] of [...groups,['doraemon','도라에몽']]){const sounds=pack.sounds.filter(s=>s.character===group);if(!sounds.length)continue;const card=document.createElement('article');card.className='card';const title=document.createElement('h3');title.textContent=label+' · '+sounds.length+'개';card.append(title);for(const item of sounds){const row=document.createElement('div');row.className='sound';const button=document.createElement('button');button.textContent='▶ '+item.label+' · '+item.duration.toFixed(2)+'초';button.onclick=()=>play(item.id);const cue=document.createElement('p');cue.textContent=item.cue;row.append(button,cue);card.append(row)}soundGrid.append(card)}library.append(soundGrid);document.getElementById('main').append(library);
document.getElementById('stop').onclick=stop;document.getElementById('theme').onclick=e=>{document.body.classList.toggle('light');e.target.textContent=document.body.classList.contains('light')?'어두운 배경으로 보기':'밝은 배경으로 보기'};document.getElementById('compact').onclick=e=>{document.body.classList.toggle('compact');e.target.textContent=document.body.classList.contains('compact')?'큰 그림으로 보기':'64px로 보기'};volume.oninput=()=>active.forEach(a=>a.volume=Number(volume.value));window.addEventListener('pagehide',stop);
</script></html>'''.replace('__PACK__',payload).replace('__SOUND_COUNT__',str(len(manifest['sounds'])))
    textwrite(PACK / 'index.html', page)

    lines = ['-- INFINITY original asset pack V1. Fill AssetId after uploading to your Roblox account/group.',
             '-- Keep this catalog in ReplicatedStorage. Empty IDs deliberately do not reference other creators.',
             'return {', '    Icons = {']
    for i in manifest['icons']:
        lines.append('        '+i['id']+' = { AssetId = "", File = "'+i['file']+'", Skill = "'+i['skill']+'" },')
    lines += ['    },', '    Sounds = {']
    for s in manifest['sounds']:
        lines.append('        '+s['id']+' = { AssetId = "", File = "'+s['file']+'", Duration = '+str(s['duration'])+', Looped = '+str(s['loop']).lower()+' },')
    lines += ['    },', '}', '']
    textwrite(PACK / 'RobloxAssets.luau', '\n'.join(lines))
    readme = '''# INFINITY 스킬 에셋 V1

고죠·젠이츠·레제·샹크스용 **아이콘 18개 / 효과음 __SOUND_COUNT__개**. 효과음에는 도라에몽 도구와 공통 점프·슬라이딩·평타도 포함합니다. 도라에몽 아이콘은 포함하지 않습니다.

## 열기

`index.html`을 브라우저에서 열면 아이콘, 48px HUD 샘플, 효과음 버튼과 준비→발동 연속 재생을 확인할 수 있습니다. 파일이 한 폴더에 있어야 그림·음원이 열립니다. 브라우저의 첫 재생은 클릭이 필요합니다.

- `icons/`: 업로드용 512×512 RGBA PNG. 투명 배경, 최소 40px 여백.
- `sounds/`: 48kHz / 16bit PCM / 모노 WAV. 각 파일은 별도로 재생하는 짧은 큐입니다.
- `sounds/shared/`: 발구름·착지, 슬라이딩 시작·마찰·종료, 평타 1·2·3타 휘두름·적중 소리입니다.
- `sounds/doraemon/`: 주머니 도구·공기포·문·헬리콥터 소리입니다.
- `sources/`: 프로젝트 폴더에 보관한 imagegen 생성 원본(ZIP에서는 제외). 업로드용 PNG는 원본의 투명 여백만 정리하고 비율을 유지하여 축소했습니다.
- `manifest.json`: 한국어 이름, 스킬 매핑, 재생 시점, 길이, 반복 여부, 이미지 생성 프롬프트.
- `RobloxAssets.luau`: 업로드 후 ID를 입력할 카탈로그.
- `icon-contact-sheet.jpg`: 전체 아이콘 및 작은 HUD 크기 비교.

## 아이콘 구성

| 캐릭터 | 아이콘 |
|---|---|
| 고죠 | 아오 / 아카 / 무라사키 / 무량공처 |
| 젠이츠 | 전집중 호흡 / 벽력일섬 / 화뢰신 |
| 레제 | 폭발 도약 / 급강하 / 손바닥 폭발 / 핀 당겨 변신 / 전면 폭발 |
| 샹크스 | 패왕색 / 검 자세 / 전진 베기 / 패링 반격 / 카무사리 |
| 공통 | 대시 |

`Kick`은 현재 코드의 키 이름이며 실제 연출은 **오른손 폭발**입니다. 발차기 아이콘으로 만들지 않았습니다. 공중 Q 재입력에는 `reze_dive`, 변신 후 R에는 `reze_detonation`, 무라사키 연계에는 `gojo_purple`을 사용합니다.

## 사운드 붙이기

효과음의 길이가 서버 준비 시간을 바꾸지는 않습니다. 현재 전투 이벤트에서 해당 동작이 실제 일어나는 시점에 재생합니다. `manifest.json`의 `cue`를 기준으로 연결하세요.

- 레제 `reze_pin`: 고리가 빠지는 정확한 순간의 금속성 “팅”. 변신 폭발은 별도 `reze_transform`입니다. 갤러리의 변신 연속 재생은 핀 직후 폭발 예시입니다.
- `reze_fuse_loop`: 1초 반복용. 도화선이 타는 동안만 재생하고 폭발·취소·사망·캐릭터 교체 시 정지합니다.
- 무라사키: 준비 3.6초, 융합 강조 2.85초, 발사음 3.6초에 별도 재생.
- 무량공처: 전개음 후 플레이어가 영역 안에 있는 동안 `gojo_domain_inside`를 반복합니다. 밖으로 나오면 멈춥니다. 7.5초 만료 시 `gojo_domain_end`, 충돌로 깨질 때 `gojo_domain_break`를 재생합니다.
- 화뢰신: 질주음, 통과 0.9초 후 적중음, 납도음을 나눴습니다. 납도 시점은 뷰모델에 맞춥니다.
- 패왕색: 0.5초 준비 뒤 파동, 1초 후 파동 한 번 더.
- 카무사리: 2.5초 준비 뒤 참격.
- 패링음은 실제 가드 성공 시에만, 반격음은 반격이 시작될 때 재생합니다.

업로드 후 `AssetId`를 `rbxassetid://숫자` 형태로 채워 `ImageLabel.Image` / `Sound.SoundId`에 사용합니다. 오디오는 실제 게임 소유자·그룹에서 사용할 수 있게 업로드 권한을 설정해야 합니다. 현재 카탈로그의 ID는 비어 있으며 Roblox HUD·SoundId에 자동 연결하지 않았습니다. 브라우저 게임 프리뷰에는 같은 PNG·WAV를 연결했습니다. 업로드나 Studio 실행은 하지 않았습니다.

Roblox 공식 가져오기 안내: [오디오](https://create.roblox.com/docs/audio/assets), [이미지](https://create.roblox.com/docs/studio/importer).

## 제작과 한계

아이콘: OpenAI 내장 imagegen을 아이콘마다 별도 호출하여 생성. 전체 프롬프트는 manifest에 보관했습니다. 음원: Kenney의 CC0 실녹음 충격·칼·옷·발소리를 주된 타격층으로 쓰고, `tools/make-skill-audio.py`의 합성음은 에너지감과 저역 잔향에 섞었습니다. 전체 스킬 30개와 공통 이동·평타·도라에몽 큐에 적용했습니다. 녹음 원본과 출처는 `../foley/kenney/`에 보관했습니다. 원작 대사, 성우 음성, 애니메이션 음원 샘플을 사용하지 않았습니다.

효과음은 녹음과 합성을 섞은 시안입니다. 실제 Roblox 공간음, 동시 발동 시 믹싱, 기기 스피커에서의 청감은 아직 확인하지 않았습니다. 기본 미리듣기 볼륨은 65%입니다.

## 재생성

프로젝트 루트에서:

```powershell
python tools/make-skill-audio.py
python tools/build-skill-pack.py
```

필요 패키지는 NumPy와 Pillow입니다. 오디오는 고정 난수 시드로 재생성합니다. 아이콘 생성 원본 경로는 `generated-sources.json`에 기록되어 있고, `sources/`에도 원본을 보관했습니다. 생성 원본 경로가 없으면 `sources/`의 파일을 가리키도록 수정할 수 있습니다.
'''
    textwrite(PACK / 'README.md', readme.replace('__SOUND_COUNT__',str(len(manifest['sounds']))))
    for path in [ROOT/'tools'/'make-skill-audio.py', ROOT/'tools'/'build-skill-pack.py']:
        if path.exists():
            textwrite(path, path.read_text(encoding='utf-8-sig'))
    # Transport bundle excludes redundant full-resolution generation sources and machine-specific paths.
    output = ROOT / 'InfinityArena-SkillAssets-v1.zip'
    with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as z:
        for path in PACK.rglob('*'):
            if path.is_file() and 'sources' not in path.relative_to(PACK).parts and path.name != 'generated-sources.json':
                z.write(path, path.relative_to(PACK))
    print(f'Built {len(manifest["icons"])} PNG icons, {len(manifest["sounds"])} WAV sounds, gallery, catalog and {output.name}')


if __name__ == '__main__':
    build()
