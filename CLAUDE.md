# INFINITY — 프로젝트 가이드

Roblox 1인칭 능력 아레나 프로토타입(고죠 · 젠이츠 · 레제 · 샹크스 · 도라에몽 · 페인 · 올마이트 · 이타치)과 Three.js 브라우저 프리뷰. 캐릭터를 계속 추가할 예정이므로, 아래 **요구 방식과 디테일 기준**을 새 캐릭터에도 그대로 적용한다.

## 가장 중요한 원칙: 화면에서 어떻게 보이고 느껴지는가

작업의 합격 기준은 코드가 아니라 **1인칭 화면의 체감**이다. 구조가 맞아도 연출이 약하면 불합격이다.

1. **동작은 방향·순서·타이밍으로 지정된다.** "준비 → 행동 → 결과"로 쪼개서 구현한다.
   - 예: 돌려차기 = 약 0.3초 오른발을 들고 오른쪽으로 몸을 감았다가 → 오른쪽에서 왼쪽으로 세게 감아 찬다(즉발 금지).
   - 예: 쵸커 = 턱을 내려 목이 보임 → 오른손이 목으로 올라가 고리를 걸고 잠깐 멈춤 → 오른쪽으로 홱 당김("팅") → 폭발 → 암전 후 2초에 걸쳐 복귀.
   - 방향(좌/우), 시간(초), 신체 부위(손·발·시야)를 사용자가 말한 그대로 지킨다. 임의로 단순화하지 않는다.
2. **"찰짐"을 만든다.** 준비 동작(웅크림, 들어올림), 시야 회전/흔들림/FOV 변화, 궤적 이펙트, 적중 시 히트스톱, 사운드를 한 세트로 넣는다. 효과음이 없으면 "팅" 같은 핵심 타이밍을 합성음이라도 넣는다.
3. **하이라이트를 먼저 파악하고 거기에 공을 들인다.** 캐릭터마다 사용자가 "이게 제일 중요하다"고 하는 장면이 있다(레제는 쵸커 당기기). 그 장면은 여러 번 프레임으로 확인하며 끝까지 다듬는다.
4. **레퍼런스로 설명하면 그 레퍼런스를 따른다.** 게임/애니 장면(발로란트 오니마루 칼 쥐는 자세, 카시오페아 W, 고죠 무라사키 연계), 사용자가 붙여준 원작 설정·이미지는 그대로 반영한다. 일반적인 스킬로 대체하면 "○○ 같지 않다"는 피드백이 온다. **원작 고증이 중요하다.**
5. **상징 부위만 입힌다.** 캐릭터 전체 모델/스킨을 바꾸지 않고 알아볼 포인트만 붙인다. 나머지는 플레이어 본인 아바타를 그대로 둔다(고죠=안대, 젠이츠=칼, 레제=쵸커·변신 시 폭탄 머리).
6. **연계기는 "지금 이어 쓸 수 있다"가 보여야 한다.** 버튼이 바뀌며 빛나고, 화면 중앙에 남은 시간과 함께 안내한다(고죠 무라사키 연계 방식). 연계는 기술 + 플레이어에게 알리는 신호까지가 완성이다.
7. **강한 스킬에는 반드시 대가를 붙인다.** 사기 방지가 설계의 기본이다.
   - 준비 시간(아오/아카 3초 대기, 합치면 무라사키), 자해·슬로우(화뢰신), 체력 비용(레제 기본 스킬 HP 3%, 궁극기 12%, 변신 후 20초 재사용), 사용 후 상태 복귀.
   - 제한 시간을 없애면(레제 변신 무제한) 다른 대가(체력, 궁극기 후 인간 복귀)를 같이 제안한다.
8. **연출 세부는 사용자가 지정한 것만 고정하고 나머지는 추천한다.** 새 캐릭터를 시작할 때 막연하면 "추천안 + 선택지"를 먼저 제시하고, 사용자가 일부를 골라 방향을 틀면 그에 맞춰 확정 후 구현한다. 사용자가 "짜치다/다른 아이디어로"라고 하면 바로 접고 대안을 낸다.

## 새 캐릭터 추가 체크리스트

- [ ] 상징 부위 1~2개만 정한다(Arena.server.luau `outfit`).
- [ ] 시그니처 장면(하이라이트)이 무엇인지 확인한다. 모르면 질문한다.
- [ ] 스킬 4슬롯(Q/E/R/Shift) 구성, 비용·쿨타임·대가, 연계 여부를 확정한다.
- [ ] 각 스킬을 준비 → 행동 → 결과 타이밍으로 쓴다(시간 값 명시).
- [ ] 연계가 있으면 버튼 강조 + 화면 중앙 안내를 넣는다.
- [ ] 서버 판정(Combat), 설정값(GojoConfig), 클라이언트 연출·HUD(Gojo.client)를 같이 구현한다.
- [ ] 프리뷰(preview/app.js, index.html, style.css)에도 같은 동작을 구현해 프레임으로 확인한다.
- [ ] README의 조작·규칙 설명을 갱신한다.

## 구조

- `roblox/src/ReplicatedStorage/GojoConfig.luau` — 수치와 `Kits`(캐릭터별 허용 스킬). 서버는 Kits에 없는 요청을 거부한다.
- `roblox/src/ServerScriptService/Combat.server.luau` — 서버 판정(에너지·쿨타임·피해·넉백·상태). 모든 전투 판정은 서버에서 한다.
- `roblox/src/ServerScriptService/Arena.server.luau` — 경기장, 훈련 표적, 캐릭터별 상징 부위(`outfit`).
- `roblox/src/StarterPlayer/StarterPlayerScripts/Gojo.client.luau` — 모든 캐릭터 공용 1인칭 뷰모델·HUD·카메라·VFX. 캐릭터는 플레이어 속성 `Character`로 구분.
- 천도 페인은 모듈로 분리했다: `PainAbilityConfig`(수치), `PainServer`(Combat이 require하는 판정 모듈, 상태는 Combat의 `states`를 공유), `PainVFX`·`PainClient`(Gojo.client가 require). 피해자 제어는 캐릭터 속성 `PainHeldUntil`·`PainSpeedUntil`·`PainSealedUntil` 등으로 한다.
- 올마이트도 같은 방식이다: `AllMightConfig`, `AllMightServer`(Combat의 `damage`가 `damageFactor`로 받는 피해 −15%·E +20%·기본공격 +25%를 적용), `AllMightVFX`·`AllMightClient`. 속성은 `AllMightBuffUntil`·`AllMightHeldUntil`·`AllMightGuardUntil`(R 시전 중 경직 저항, PainServer도 이를 존중) 등.
- 이타치도 같은 방식이다: `ItachiConfig`, `ItachiServer`, `ItachiVFX`·`ItachiClient`. 패시브(까마귀 분신)는 Combat의 `damage`가 피해 전에 `Itachi.tryDodge(owner,t,kind)`로 굴린다. **새 피해 호출에는 반드시 종류(`Basic`·`Melee`·`Kick`·`Weapon`·`Dash`·`Projectile`은 회피 가능, `DoT`·`Status`·`Genjutsu`·`Shockwave`·`Explosion`·`Environment`·`Ultimate`은 불가)를 넘긴다.** 속성은 `ItachiHeldUntil`·`ItachiSealedUntil`·`ItachiTsukuyomiUntil`·`ItachiSlowUntil`·`ItachiGuardUntil`(스사노오 경직 저항·회피 직후, Pain·AllMight 이동도 존중)·`ItachiMirrorUntil` 등.
- `preview/` — 브라우저 프리뷰 소스(`app.js`가 거의 전부). `Gojo-preview.html`은 이를 단일 파일로 번들한 결과물. 페인은 `preview/pain.js`(`window.PainPreview(api)`), 올마이트는 `preview/allmight.js`(`window.AllMightPreview(api)`), 이타치는 `preview/itachi.js`(`window.ItachiPreview(api)`)로 분리했고 `build-preview.cjs`가 함께 인라인한다. 프리뷰 거리는 Roblox 스터드의 0.6배.
- `InfinityArena-Gojo.rbxlx` — Studio용. 스크립트 소스를 CDATA로 포함한다.

## 작업 절차

Rojo가 설치되어 있지 않아 `.rbxlx`는 스크립트 소스를 직접 동기화한다.

```bash
node tools/check-luau.cjs roblox/src/ServerScriptService/Combat.server.luau   # Luau 문법 검사(npm i luaparse@0.3.1 필요)
node tools/sync-rbxlx.cjs .                                                    # roblox/src → .rbxlx 동기화
node tools/build-preview.cjs . Gojo-preview.html                               # preview/ → 단일 HTML 번들
node tools/serve-test.cjs                                                      # 127.0.0.1:4599 에서 번들 서빙 + 캡처 저장
```

- 프리뷰는 `?char=gojo|zenitsu|reze|shanks|doraemon|pain|allmight|itachi#debug`로 열면 `window.__lab`(pause/step/shot/setYaw/startSkill 등)이 노출된다. 탭이 숨겨지면 requestAnimationFrame이 멈추므로 `pause(true)` + `step(n)` + `shot()`(캔버스 캡처를 `POST /shot?name=`으로 저장)으로 프레임을 확인한다.
- 연출은 **프레임 캡처를 직접 보고** 판단한다. 숫자만 맞추지 않는다.
- 프로젝트 파일은 CRLF다. 스크립트로 수정할 때 개행을 유지한다.
- 아티팩트용 번들은 `data:` URL과 모듈 import 없이 단일 HTML이어야 한다(`build-preview.cjs`가 처리).

## 알려진 한계 (사용자에게 숨기지 말고 말한다)

- **Roblox Studio에서 실행해 보지 못했다.** Luau는 파서로 문법만 검사했다. 손·칼·쵸커·부츠 위치 같은 뷰모델 수치는 추정값이라 Studio에서 보고 조정해야 한다.
- 히트스톱, 일부 사운드(젠이츠, 레제 도화선 지글거림)는 프리뷰에만 있거나 아직 없다.
- 스토어 VFX는 런타임 로딩이라 권한에 따라 실패할 수 있다(실패해도 직접 만든 효과로 동작).
- 멀티플레이·모바일 성능은 확인하지 않았다.
