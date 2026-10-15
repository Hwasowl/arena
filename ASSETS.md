# 에셋 출처 및 적용 상태

확인일: 2026-10-14. 유료 구매 없음.

| 에셋 | 제작자 | 용도 | 상태 |
|---|---|---|---|
| [Red and Blue VFX Gojo !](https://create.roblox.com/store/asset/17879749515/Red-and-Blue-VFX-Gojo) | @XxMurder_ProgamexX | 아오·아카·무라사키 파티클 | 로그인 계정 인벤토리 추가 확인. 실행 시 ParticleEmitter만 복사하도록 연결. Studio에서 실제 로딩/외관 미확인. |
| [Finger Snap 12 (SFX)](https://create.roblox.com/store/asset/9114427347/Finger-Snap-12-SFX) | @ProSoundEffects | 아오 스냅 | 인벤토리 추가 확인. Roblox SoundId에 연결. 엔진 재생 미확인. |
| [Eerie Ambience 2 (SFX)](https://create.roblox.com/store/asset/9112775414/Eerie-Ambience-2-SFX) | @ProSoundEffects | 영역·무라사키 준비 저음 | Creator Store에서 출처 확인. Roblox SoundId에 연결. 엔진 재생 미확인. |

## 모델 취급

`StoreVFX.server.luau`는 선택한 모델을 로드한 뒤 DataModel에 연결하기 전에 스크립트를 제거합니다. 모델 전체를 설치하지 않으며 ParticleEmitter 최대 8개만 별도 복사합니다. 각 구체에는 최대 3개를 붙이고 방출률·수명·속도를 제한합니다. 실패하면 직접 작성한 구체/광원 효과로 동작합니다. 스토어 원본 모델의 상세 내용은 다운로드 차단으로 로컬에서 검사하지 못했습니다.

첫 후보였던 [Gojo vfx pack](https://create.roblox.com/store/asset/15300157819/Gojo-vfx-pack)은 획득 후 상세 리뷰에서 악성 스크립트 관련 이용자 신고를 확인했습니다. 사실 여부를 단정할 수 없지만 프로젝트 적용에서 제외했습니다. 해당 항목은 계정 인벤토리에 남아 있으며 이 프로젝트 코드에서는 로드하지 않습니다.

## 직접 제작한 부분

경기장, 뷰모델 손, 캐릭터의 임시 흰 머리·안대, 훈련 표적, 전투 코드, UI, 영역 효과는 이 프로젝트용 코드로 생성합니다. 브라우저판 효과와 사운드는 자체 생성이며 Creator Store 모델을 렌더링한 결과가 아닙니다.

브라우저 렌더링: Three.js 0.160.0, MIT license, https://github.com/mrdoob/three.js. 로컬 파일에 포함합니다.

## 스킬 아이콘·사운드 V1 (2026-10-15)

- 고죠·젠이츠·레제·샹크스: 아이콘 18개, 별도 효과음 30개. 무라사키·급강하·변신 후 궁극기·패링 같은 조건부 스킬과 공통 대시 포함.
- [미리보기·미리듣기](assets/skill-pack-v1/index.html), [전체 파일·타이밍·생성 프롬프트](assets/skill-pack-v1/manifest.json), [사용 설명](assets/skill-pack-v1/README.md).
- 아이콘은 내장 imagegen으로 각각 생성. 생성 원본을 `sources/`에 보관하고 업로드용 파일은 투명 여백을 정리해 512×512 PNG로 저장.
- 효과음은 `tools/make-skill-audio.py`의 노이즈·발진음·금속 공명 합성으로 제작. 원작 대사나 음원 샘플 없음. 48kHz / 16bit PCM / 모노 WAV.
- `InfinityArena-SkillAssets-v1.zip`에 업로드용 PNG·WAV·갤러리·ID 카탈로그를 묶음. 브라우저 게임 프리뷰와 단일 HTML에 아이콘·스킬별 효과음을 연결함. Roblox 업로드·Roblox HUD/SoundId 연결·Studio 재생은 아직 하지 않음.
