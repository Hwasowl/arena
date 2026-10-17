import * as T from './vendor/three.module.js';

const $ = id => document.getElementById(id);
const clamp = T.MathUtils.clamp, mix = T.MathUtils.lerp;
const ease = x => { x = clamp(x,0,1); return x*x*(3-2*x); };
// Arena is ARENA_S times the original radius (29); the sky is a bright daytime one.
const ARENA_S=2,ARENA_R=29*ARENA_S;
const scene = new T.Scene(); scene.background = new T.Color(0xa9d0ee); scene.fog = new T.FogExp2(0xbcdaee,.0055);
let renderer;
try { renderer = new T.WebGLRenderer({canvas:$('scene'),antialias:true,powerPreference:'high-performance'}); }
catch(e) { $('fatal').hidden=false; $('loading').style.display='none'; throw e; }
renderer.setPixelRatio(Math.min(devicePixelRatio,1.7)); renderer.setSize(innerWidth,innerHeight);
renderer.outputColorSpace=T.SRGBColorSpace; renderer.toneMapping=T.ACESFilmicToneMapping; renderer.toneMappingExposure=1.2;
renderer.shadowMap.enabled=true; renderer.shadowMap.type=T.PCFSoftShadowMap;
const camera = new T.PerspectiveCamera(66,innerWidth/innerHeight,.04,520); scene.add(camera);
const basePos = new T.Vector3(0,2.1,13); camera.position.copy(basePos);
let yaw=0,pitch=-.015,time=0,cast=null,blueUntil=0,blueOrb=null,domain=null,damageTotal=0,energy=100;
let muted=true,audio=null,comfort=false,toastUntil=0,demoStart=-1,demoStage=0,dragging=false,lastPointer=null;
let rootUntil=0;
// Tendo Pain lives in pain.js; it is wired up near the end of this file.
// All Might lives in allmight.js, wired the same way.
let pain=null,allmight=null,okkotsu=null,kizaru=null;
let godspeedUsed=false,zenSkillGuard=null;
const ZEN_RUSH={thunder:{windup:.4,travel:.24,distance:40,damage:70},godspeed:{windup:.2,travel:.12,distance:55,damage:100},god:{windup:.6,travel:.18,distance:60,damage:150}};
let char='gojo',charges=0,chargesUntil=0,thunderHoldAt=-1,thunderHoldDemo=false,hp=200,slowUntil=0,devilUntil=0,devilShown=false,hold=null,kickCombo=null,hitstopUntil=0,rezeAirUntil=0,rezeAirVel=0,rezeAirDir=new T.Vector3(),rezeLookUntil=0,shanksReadyUntil=0,shanksParryHit=false,doraFlightStart=-1,doraFlightBase=0,doraFlightActive=false;
const THUNDER_MAX_CHARGE=1.6,THUNDER_MIN_DISTANCE=10,THUNDER_MAX_DISTANCE=40,THUNDER_CHAIN_COOLDOWN=.5;
let melee=null,sliding=null,attackQueued=false,basicCombo=0,basicUntil=0,slideCooldown=0,commonDemo=-1,commonStage=0,jumpVelocity=0;
const COMMON={windups:[.16,.18,.24],swing:.1,recoveries:[.22,.24,.32],damage:[12,14,20],comboReset:.95,slideDuration:.7};
const scabbard=()=>char==='zenitsu'||char==='shanks';
// Shanks has only his right arm: one hand, quicker and lighter cuts.
const SHANKS_BASIC={windups:[.34,.2,.2,.2],swing:.16,recoveries:[.2,.17,.17,.22],damage:[10,11,12,17],comboReset:.6,sheath:.34};
const basicCfg=()=>char==='shanks'?SHANKS_BASIC:scabbard()?ZEN_BASIC:(char==='gojo'||char==='reze')?BOXER_BASIC:COMMON;
const ZEN_BASIC={windups:[.52,.32,.32,.32],swing:.24,recoveries:[.30,.28,.28,.34],damage:[12,14,16,20],comboReset:.70,sheath:.42};
let zenDrawUntil=0,zenGuardSign=1,zenSheathSoundPlayed=true;
const keys = new Set(), effects=[], targets=[], particles=[], popups=[], timers=[], trails=[];
const cooldowns={blue:0,red:0,domain:0,dash:0,godspeed:0,thunder:0,god:0,rampage:0,kick:0,detonate:0,devil:0,haki:0,engarde:0,departure:0,pocket:0,copter:0,door:0,shinra:0,bansho:0,chibaku:0,ofa:0,smash:0,ultra:0}; const durations={blue:5,red:6,domain:15,dash:2.5,godspeed:0,thunder:6,god:25,rampage:5,kick:4,detonate:1,devil:20,haki:14,engarde:8,departure:20,pocket:5,copter:12,door:18,shinra:12,bansho:14,chibaku:80,ofa:25,smash:18,ultra:85};
Object.assign(cooldowns,{reverseCursed:0,rikaStrike:0,pureLove:0});Object.assign(durations,{reverseCursed:22,rikaStrike:9,pureLove:38});
const costs={blue:15,red:20,domain:45,dash:5,godspeed:28,thunder:18,god:50,rampage:0,kick:0,detonate:0,devil:0,haki:20,engarde:12,departure:40,pocket:12,copter:18,door:28,shinra:0,bansho:0,chibaku:0,ofa:0,smash:0,ultra:0};
Object.assign(costs,{reverseCursed:30,rikaStrike:20,pureLove:55});
// Reze pays in health instead of energy: a fraction of max HP per use, never lethal.
Object.assign(costs,{lightLaser:15,lightKick:24,lightJewels:55,lightMirror:12});Object.assign(durations,{lightLaser:5,lightKick:8,lightJewels:28,lightMirror:6});Object.assign(cooldowns,{lightLaser:0,lightKick:0,lightJewels:0,lightMirror:0});
const hpCosts={rampage:.03,kick:.03,detonate:.12};
const fuseSlowFactor=.25;
// Murasaki tuning: hand-gathering runs PURPLE_SLOW times slower, the leap is PURPLE_JUMP times higher; the shot speed is unchanged.
const PURPLE_SLOW=3,PURPLE_JUMP=3;
// Bomb Devil's Q launch: peak height scales with the square of the launch speed, so the speed is multiplied by sqrt(REZE_LIFT).
const REZE_LIFT=5;
// Roblox recoil values at the preview's 0.6 body scale. Gravity scales too, preserving flight time.
const BOMB_RECOIL={speed:24,lift:18,gravity:196.2*.6,airLimit:1.4,skidSpeed:18,skidDuration:.7,standDuration:.3};
let bombRecoil=null;
function beginBombRecoil(){
  bombRecoil={start:time,dir:flatForward().negate(),vy:BOMB_RECOIL.lift,phase:'air',land:0,dust:0,blocked:false};
  rezeAirVel=0;rezeAirUntil=0;rezeAirDir.set(0,0,0);jumpVelocity=0;sliding=null;melee=null;attackQueued=false;
}
function moveBombRecoil(dt){
  const b=bombRecoil;if(!b)return;const cfg=BOMB_RECOIL,a=time-b.start;
  if(b.phase==='air'){
    basePos.y+=b.vy*dt-.5*cfg.gravity*dt*dt;b.vy-=cfg.gravity*dt;
    if(basePos.y<=2.1&&b.vy<0){basePos.y=2.1;b.phase='skid';b.land=time;sound('shared_land',{volume:.8});sound('shared_slide_start',{volume:.55});sound('shared_slide_scrape',{loop:true,tag:'bombSkid',volume:.55});shockRing(basePos.clone().setY(.09),0xb1a394,2.5,.3,.08);}
    else if(a>cfg.airLimit){bombRecoil=null;jumpVelocity=b.vy;return;}
  }
  const age=b.phase==='skid'?time-b.land:0;
  const speed=b.blocked?0:b.phase==='air'?cfg.speed:cfg.skidSpeed*Math.pow(1-clamp(age/cfg.skidDuration,0,1),2);
  const distance=speed*dt,next=basePos.clone().addScaledVector(b.dir,distance);
  const blocked=obstacles.some(o=>basePos.y-1.7<o.h&&next.x>o.x0-.65&&next.x<o.x1+.65&&next.z>o.z0-.65&&next.z<o.z1+.65)||Math.hypot(next.x,next.z)>ARENA_R-.65;
  if(blocked)b.blocked=true;else basePos.copy(next);
  if(b.phase==='skid'){
    if(age<cfg.skidDuration&&speed>.6&&time>=b.dust){b.dust=time+.045;const side=new T.Vector3(-b.dir.z,0,b.dir.x);
      for(const sign of [-1,1]){const at=basePos.clone().addScaledVector(side,.42*sign).setY(.16);puff(at,.55,.35,.55,false);const streak=mesh(new T.BoxGeometry(.055,.018,.62),new T.MeshBasicMaterial({color:0x2b2421,transparent:true,opacity:.6,depthWrite:false}),scene);streak.position.copy(at).setY(.035);streak.rotation.y=Math.atan2(b.dir.x,b.dir.z);effect(streak,2,(o,u)=>o.material.opacity=.6*(1-u));}}
    if(age>=cfg.skidDuration)stopSkillSound('bombSkid');
    if(age>=cfg.skidDuration+cfg.standDuration){bombRecoil=null;sound('shared_slide_end',{volume:.45});}
  }
}
function poseBombRecoil(){
  const b=bombRecoil;if(!b)return;const a=time-b.start,skid=b.phase==='skid',g=skid?time-b.land:0;
  const stand=skid?ease((g-BOMB_RECOIL.skidDuration)/BOMB_RECOIL.standDuration):0,kick=1-ease(a/.22),brace=ease(a/.18)*(1-stand);
  pose(left,[-.38-.32*kick,-.48+.42*kick+.18*brace,-.8+.22*kick],[-.5*kick,.2,-.65*kick-.2*brace]);
  pose(right,[.38+.32*kick,-.42+.36*kick+.14*brace,-.8+.22*kick],[-.5*kick,-.2,.65*kick+.2*brace]);
  camera.position.y-=(skid?.8*(1-stand):-.08*kick)+(skid?.13*Math.exp(-g*17):0);
  camera.rotation.x+=.12*kick-(skid?.075*Math.exp(-g*17):0);camera.rotation.z+=.025*Math.sin(a*24)*Math.exp(-a*5)*(comfort?.3:1);
  camera.fov=66+16*Math.exp(-a*3)+4*brace;
}
const colors={blue:0x36adff,red:0xff365d,purple:0xa04dff,domain:0x94ddff,thunder:0xffd23f,bomb:0xff7a2e,fire:0xffd08a,haki:0xff263f};
const SKILLS={
  blue:{name:'아오',type:'인력 / 3초 대기',icon:'orb-icon',glyph:'',accent:'#64cfff'},
  red:{name:'아카',type:'척력 / 3초 대기',icon:'burst-icon',glyph:'✦',accent:'#ff637d'},
  domain:{name:'무량공처',type:'영역전개',icon:'domain-icon',glyph:'∞',accent:'#d6c2ff'},
  dash:{name:'순간 가속',type:'이동',icon:'dash-icon',glyph:'»',accent:'#c3dae8'},
  godspeed:{name:'벽력일섬 신속',type:'1회 · 이동속도 영구 −30%',icon:'bolt-icon',glyph:'ϟ',accent:'#fff1a8'},
  thunder:{name:'벽력일섬',type:'돌진 / 베기',icon:'bolt-icon',glyph:'ϟ',accent:'#ffd23f'},
  god:{name:'화뢰신',type:'뇌룡 발도 / 반동 없음',icon:'god-icon',glyph:'雷',accent:'#ffb347'},
  rampage:{name:'상승 폭발',type:'웅크림 0.4초 · Q 재입력 내려찍기',icon:'rampage-icon',glyph:'✸',accent:'#ff8a3d'},
  kick:{name:'오른손 폭발',type:'손을 뻗고 0.8초 뒤 · 전방 3블럭',icon:'bomb-icon',glyph:'✺',accent:'#ffa25a'},
  detonate:{name:'대폭발',type:'4초 퓨즈 · 반동 후방 슬라이딩',icon:'devil-icon',glyph:'爆',accent:'#ff3b1e'},
  devil:{name:'폭탄의 악마',type:'핀 / 변신 · 무제한',icon:'devil-icon',glyph:'爆',accent:'#ff5a2e'},
  haki:{name:'패기 발현',type:'0.5초 준비 · 반경 10 · 2회 확정 피해',icon:'domain-icon',glyph:'覇',accent:'#ff334e'},
  engarde:{name:'검 자세',type:'E 후 좌클릭 베기 · 우클릭 1초 반격',icon:'bolt-icon',glyph:'⚔',accent:'#ff6174'},
  departure:{name:'카무사리',type:'2.5초 기모으기 · 전방 50 · 50 피해',icon:'god-icon',glyph:'神',accent:'#ff263f'},
  pocket:{name:'4차원 주머니',type:'뒤적이는 중 · 도구 무작위',icon:'breath-icon',glyph:'4D',accent:'#45b6e8'},
  copter:{name:'대나무 헬리콥터',type:'머리에 꽂고 3초 비행',icon:'dash-icon',glyph:'✦',accent:'#45b6e8'},
  door:{name:'어디로든 문',type:'문을 열고 전방 24블록 이동',icon:'domain-icon',glyph:'門',accent:'#f28b82'},
  shinra:{name:'신라천정',type:'0.45초 · 반경 25 척력파',icon:'god-icon',glyph:'神',accent:'#d4c2ff'},
  bansho:{name:'만상천인',type:'중앙 12° · 55 · 끌어오기 → 찌르기',icon:'god-icon',glyph:'引',accent:'#b084ff'},
  chibaku:{name:'지폭천성',type:'중력 핵 · 암석 구체 봉인',icon:'god-icon',glyph:'星',accent:'#9d6bff'},
  ofa:{name:'원 포 올 : 풀 파워',type:'0.85초 준비 · 10초 강화',icon:'god-icon',glyph:'力',accent:'#ffce40'},
  smash:{name:'UNITED STATES OF SMASH',type:'22 돌진 · 55 + 충격파 18',icon:'god-icon',glyph:'拳',accent:'#ffce40'},
  ultra:{name:'PLUS ULTRA',type:'35 돌진 → 하늘로 · 110',icon:'god-icon',glyph:'超',accent:'#ffce40'},
};
Object.assign(SKILLS,{
 reverseCursed:{name:'반전술식',type:'최대 HP 50% · 공격력 -30% 10초',icon:'okkotsu-heal',glyph:'',accent:'#9cffe0'},
 rikaStrike:{name:'차원문 · 리카 휘둘러치기',type:'정면 5칸 → 왼쪽으로 밀쳐냄',icon:'okkotsu-claw',glyph:'',accent:'#e38bcb'},
 pureLove:{name:'순애',type:'칼 수납 → 수인 → 리카와 순애포',icon:'okkotsu-ring',glyph:'',accent:'#ffe0b1'}
});
const CHARS={
  gojo:{name:'고죠 사토루',kanji:'五条 悟',seal:'悟',eyebrow:'CHARACTER 01 / LIMITLESS',desc:'공간을 지배하는 힘.<br>아오·아카는 팔을 든 채 3초 대기. 그 안에 다른 쪽을 쓰면 무라사키.',hud:'GOJO',energy:'呪力 / CURSED ENERGY',hint:'<kbd>Q</kbd>+<kbd>E</kbd> 3초 안에 합치면 무라사키 · 같은 키 다시 = 즉시 발사',demoToast:'아오+아카 → 무라사키 → 아오 단독 → 아카 단독 → 영역전개 자동 시연',slots:{q:'blue',e:'red',r:'domain',shift:'dash'},demo:[[.6,'blue'],[1.8,'red'],[6,'blue'],[6.8,'blue'],[8.2,'red'],[9,'red'],[10.5,'domain'],[20,'dash']],demoEnd:21.5},
  zenitsu:{name:'아가츠마 젠이츠',kanji:'我妻 善逸',seal:'善',eyebrow:'CHARACTER 02 / THUNDER BREATHING',desc:'몸을 낮추고 발도하여 돌진합니다. 잠시 칼을 들고 있다가 납도하며, 평타는 바로 이어집니다.<br>신속은 한 번만 사용하며 이동속도가 30% 감소합니다. 화뢰신에는 반동이 없습니다.',hud:'ZENITSU',energy:'呼吸 / BREATH',hint:'<kbd>Q</kbd> 고정 벽력일섬 · <kbd>E</kbd> 신속 1회 / 속도 −30% · <kbd>R</kbd> 화뢰신',demoToast:'벽력일섬 → 신속 → 뇌룡 화뢰신',slots:{q:'thunder',e:'godspeed',r:'god',shift:'dash'},demo:[[.5,'thunder'],[3.8,'godspeed'],[7,'god']],demoEnd:11,aimDemo:true},
  reze:{name:'레제',kanji:'レゼ',seal:'レ',eyebrow:'CHARACTER 03 / BOMB DEVIL',desc:'변신 전에도 기본공격과 슬라이딩으로 싸웁니다.<br>쵸커의 핀을 당기면 폭탄의 악마가 깨어납니다.',hud:'REZE',energy:'火薬 / GUNPOWDER',hint:'<kbd>Q</kbd> 0.4초 웅크려 상승 · 공중에서 Q 재입력 = 내려찍기 · <kbd>E</kbd> 오른손 폭발 · <kbd>R</kbd> 대폭발',demoToast:'변신 → Q 상승 → Q 내려찍기 → E 오른손 폭발 → 대폭발',slots:{q:'rampage',e:'kick',r:'devil',shift:'dash'},demo:[[.5,'devil'],[3.8,'rampage'],[4.55,'rampage'],[5.8,'kick'],[7.8,'detonate'],[14.5,'dash']],demoEnd:15.5,aimDemo:true,demoPos:[0,2.1,-1]},
  shanks:{name:'샹크스',kanji:'赤髪のシャンクス',seal:'覇',eyebrow:'CHARACTER 04 / RED HAIRED',desc:'한 팔로 검을 든 채, 패왕색 패기로 전장을 압도합니다.<br>E 후 좌클릭은 베기, 우클릭은 공격을 받아내는 반격 자세입니다.',hud:'SHANKS',energy:'覇気 / HAKI',hint:'<kbd>Q</kbd> 패기 발현 · <kbd>E</kbd> 후 좌클릭 베기 / 우클릭 반격 · <kbd>R</kbd> 카무사리',demoToast:'패기 발현 → 카무사리 → E 좌클릭 베기 자동 시연',slots:{q:'haki',e:'engarde',r:'departure',shift:'dash'},demo:[[.5,'haki'],[4,'departure'],[8,'engarde'],[8.5,'slash'],[10.5,'dash']],demoEnd:14,aimDemo:true,demoPos:[0,2.1,-2]},
  doraemon:{name:'도라에몽',kanji:'ドラえもん',seal:'ド',eyebrow:'CHARACTER 05 / 4D POCKET',desc:'무엇이 나올지 모르는 4차원 주머니.<br>뒤적이고 꺼내는 손동작 뒤 랜덤 도구가 발동됩니다.',hud:'DORAEMON',energy:'ひみつ道具 / GADGETS',hint:'<kbd>Q</kbd> 주머니 랜덤 도구 · <kbd>E</kbd> 대나무 헬리콥터 3초 비행 · <kbd>R</kbd> 어디로든 문',demoToast:'주머니 랜덤 도구 → 대나무 헬리콥터 → 어디로든 문',slots:{q:'pocket',e:'copter',r:'door',shift:'dash'},demo:[[.5,'pocket'],[3.4,'copter'],[9,'door']],demoEnd:12,aimDemo:true,demoPos:[0,2.1,10]},
  pain:{name:'천도 페인',kanji:'天道 ペイン',seal:'輪',eyebrow:'CHARACTER 06 / RINNEGAN',desc:'윤회안의 인력과 척력.<br>밀어내고, 끌어당겨 찌르고, 하늘에 암석 구체를 만들어 봉인합니다.',hud:'PAIN',energy:'輪廻眼 / RINNEGAN',hint:'<kbd>Q</kbd> 신라천정 · <kbd>E</kbd> 만상천인 (화면 중앙 대상) · <kbd>R</kbd> 지폭천성 · 연계 E→Q, E→R, Q→R',demoToast:'만상천인 → 신라천정 연계 → 지폭천성 자동 시연',slots:{q:'shinra',e:'bansho',r:'chibaku',shift:'dash'},demo:[[.6,'bansho',[8,1.4,-18]],[3.2,'shinra'],[6.6,'chibaku',[0,2.6,-14]]],demoEnd:15,demoPos:[0,2.1,-2]},
  allmight:{name:'올마이트',kanji:'オールマイト',seal:'力',eyebrow:'CHARACTER 07 / ONE FOR ALL',desc:'평화의 상징.<br>주먹 하나의 풍압과 충격파로 땅을 부수고, 마지막 일격으로 하늘 끝까지 날려 보냅니다.',hud:'ALL MIGHT',energy:'ワン・フォー・オール / ONE FOR ALL',hint:'<kbd>Q</kbd> 원 포 올 풀 파워 · <kbd>E</kbd> United States of Smash · <kbd>R</kbd> Plus Ultra · 연계 Q→E, Q→R, E 적중 직후 R',demoToast:'풀 파워 → 스매시 → 적중 직후 PLUS ULTRA 연계 자동 시연',slots:{q:'ofa',e:'smash',r:'ultra',shift:'dash'},demo:[[.6,'ofa'],[2.0,'smash',[0,1.4,-10]],[3.35,'ultra',[9,1.4,-9]]],demoEnd:13,demoPos:[0,2.1,2]},
};
Object.assign(SKILLS,{
 lightLaser:{name:'손끝 레이저',type:'0.65초 준비 · 피해 42',icon:'burst-icon',glyph:'✧',accent:'#ffe18a'},
 lightKick:{name:'빛의 발차기',type:'0.3초 빛 모음 → 번개 돌진 킥 · 피해 65 · 날려보냄',icon:'bolt-icon',glyph:'ϟ',accent:'#ffd34e'},
 lightJewels:{name:'야사카니의 곡옥',type:'웅크림 → 높이 도약 → 공중 12발 탄막 → 낙하',icon:'domain-icon',glyph:'✦',accent:'#fff0ba'},
 lightMirror:{name:'야타의 거울',type:'0.45초 빛 변환 → 전방 24 이동',icon:'dash-icon',glyph:'»',accent:'#ffe18a'}});
 CHARS.kizaru={name:'키자루',kanji:'黄猿 · ボルサリーノ',seal:'光',eyebrow:'CHARACTER 09 / GLINT-GLINT',desc:'느긋하게 모은 빛. 피할 틈 없이 터지는 한순간.<br>빛의 속도로 차여본 적 있나?',hud:'KIZARU',energy:'光 / LIGHT',hint:'<kbd>Q</kbd> 손끝 레이저 · <kbd>E</kbd> 빛의 발차기 · <kbd>R</kbd> 야사카니의 곡옥 · <kbd>SHIFT</kbd> 야타의 거울',demoToast:'손끝에 빛 → 광속 돌진 킥(날려보냄) → 높이 도약 곡옥 탄막 → 빛 이동',slots:{q:'lightLaser',e:'lightKick',r:'lightJewels',shift:'lightMirror'},demo:[[.5,'lightLaser',[0,1.3,-10]],[2,'lightKick',[0,1.3,-10]],[4,'lightJewels',[0,1.3,-10]],[7.5,'lightMirror']],demoEnd:9,demoPos:[0,2.1,-2]};
 CHARS.okkotsu={name:'옷코츠 유타',kanji:'乙骨 憂太',seal:'憂',eyebrow:'CHARACTER 08 / QUEEN OF CURSES',desc:'차원문을 넘어 나타난 리카와 함께 싸웁니다.<br>휘둘러 밀쳐내고, 순애포를 함께 쏩니다.',hud:'OKKOTSU',energy:'呪力 / CURSED ENERGY',hint:'<kbd>Q</kbd> 반전술식 · <kbd>E</kbd> 정면 5칸 리카 휘둘러치기 · <kbd>R</kbd> 칼 수납 → 수인 → 리카와 순애포',demoToast:'차원문에서 나온 리카가 왼쪽으로 휘둘러친다 → 칼 수납 · 수인 · 함께 순애포 → 반전술식',slots:{q:'reverseCursed',e:'rikaStrike',r:'pureLove',shift:'dash'},demo:[[.5,'rikaStrike',[0,1.5,-10]],[2.5,'pureLove',[0,1.5,-10]],[8,'reverseCursed']],demoEnd:10.5,demoPos:[0,2.1,-5.7]};
const SLOTS=['q','e','r','shift'];
const hemi=new T.HemisphereLight(0xeaf6ff,0x8d9fb0,2.6); scene.add(hemi);
const moon=new T.DirectionalLight(0xfff3dc,3.2); moon.position.set(-30,70,-25);moon.castShadow=true;moon.shadow.mapSize.set(2048,2048);moon.shadow.camera.left=-90;moon.shadow.camera.right=90;moon.shadow.camera.top=90;moon.shadow.camera.bottom=-90;moon.shadow.camera.far=220;moon.shadow.mapSize.set(4096,4096);scene.add(moon);
const warm=new T.DirectionalLight(0xffe0c0,.6);warm.position.set(10,5,10);scene.add(warm);
const mat=(color,roughness=.7,metalness=.1)=>new T.MeshStandardMaterial({color,roughness,metalness});
const ground=mat(0x8b9bab,.85,.05),stone=mat(0x9aa9b6), dark=mat(0x111d2a), trim=mat(0x637384,.5,.5), cloth=mat(0x0c1323), skin=mat(0xe2bcaa,.7), hair=mat(0xdfe9ed);
const glowMat=color=>new T.MeshBasicMaterial({color,transparent:true,opacity:.8,blending:T.AdditiveBlending,depthWrite:false});
function mesh(geo,material,parent=scene){const m=new T.Mesh(geo,material);m.castShadow=true;m.receiveShadow=true;parent.add(m);return m;}
function box(size,pos,material,parent=scene){const m=mesh(new T.BoxGeometry(...size),material,parent);m.position.set(...pos);return m;}
function ring(radius,color,pos,thickness=.035,parent=scene){const m=mesh(new T.TorusGeometry(radius,thickness,6,96),glowMat(color),parent);m.rotation.x=Math.PI/2;m.position.copy(pos);return m;}
function canvasTexture(draw,size=128){const c=document.createElement('canvas');c.width=c.height=size;draw(c.getContext('2d'),size);const tex=new T.CanvasTexture(c);tex.colorSpace=T.SRGBColorSpace;return tex;}
const glowTexture=canvasTexture((c,s)=>{const g=c.createRadialGradient(s/2,s/2,0,s/2,s/2,s/2);g.addColorStop(0,'rgba(255,255,255,1)');g.addColorStop(.08,'rgba(255,255,255,.85)');g.addColorStop(.3,'rgba(255,255,255,.22)');g.addColorStop(1,'rgba(255,255,255,0)');c.fillStyle=g;c.fillRect(0,0,s,s);});
function glow(color,size,parent=scene){const s=new T.Sprite(new T.SpriteMaterial({map:glowTexture,color,transparent:true,blending:T.AdditiveBlending,depthWrite:false}));s.scale.setScalar(size);parent.add(s);return s;}
function dispose(object){object.parent?.remove(object);object.traverse(o=>{o.geometry?.dispose();if(o.material){const arr=Array.isArray(o.material)?o.material:[o.material];arr.forEach(m=>m.dispose());}});}
function effect(object,life,update){effects.push({object,born:time,life,update});return object;}
function burst(pos,color,count=35,speed=8){for(let i=0;i<count;i++){const p=glow(color,.14+Math.random()*.28);p.position.copy(pos);particles.push({object:p,v:new T.Vector3(Math.random()-.5,Math.random()-.3,Math.random()-.5).normalize().multiplyScalar(speed*(.4+Math.random())),born:time,life:.4+Math.random()*.7});}}
function shockwave(pos,color,radius=10){const m=ring(.3,color,pos,.045);effect(m,.65,(o,t)=>{o.scale.setScalar(mix(1,radius/.3,ease(t)));o.material.opacity=(1-t)*.8;});}
function orb(color,radius=.6){const g=new T.Group();scene.add(g);const shell=mesh(new T.IcosahedronGeometry(radius,3),new T.MeshBasicMaterial({color}),g);mesh(new T.IcosahedronGeometry(radius*.4,1),new T.MeshBasicMaterial({color:0xffffff}),g);const aura=glow(color,radius*10,g);for(let i=0;i<3;i++){const r=mesh(new T.TorusGeometry(radius*(1.4+i*.22),.014,4,64),glowMat(color),g);r.rotation.set(i*.8,.7+i*.3,i);r.userData.spin=i+1;}
const light=new T.PointLight(color,8,16,2);g.add(light);g.userData={shell,aura};return g;}

// A compact arena with readable floor markings, broken gates, and a distant skyline.
const platform=mesh(new T.CylinderGeometry(35*ARENA_S,36*ARENA_S,1.4,128),ground);platform.position.y=-.8;
const tileMats=Array.from({length:8},(_,i)=>mat(0xb4c3d1+i*0x010101,.8,.05)),T_N=Math.ceil(7*ARENA_S);
for(let x=-T_N;x<=T_N;x++)for(let z=-T_N;z<=T_N;z++){if(x*x+z*z>54*ARENA_S*ARENA_S)continue;const tile=box([4.48,.12,4.48],[x*4.55,-.06,z*4.55],tileMats[(x*7+z*13+64)%8]);tile.castShadow=false;tile.receiveShadow=true;}
const lineMat=color=>new T.MeshBasicMaterial({color});
function floorRing(radius,color,pos,thickness){const m=new T.Mesh(new T.TorusGeometry(radius,thickness,6,160),lineMat(color));m.rotation.x=Math.PI/2;m.position.copy(pos);scene.add(m);return m;}
floorRing(28*ARENA_S,0x4f7f9a,new T.Vector3(0,.04,0),.03*ARENA_S);floorRing(28.7*ARENA_S,0x7fa6bc,new T.Vector3(0,.04,0),.03*ARENA_S);floorRing(9,0x5f8fb0,new T.Vector3(0,.035,-9),.02);floorRing(20,0x7fa6bc,new T.Vector3(0,.035,0),.02);
for(let i=0;i<24;i++){const a=i*Math.PI/12;const r=box([.16,.03,2.4],[Math.sin(a)*28*ARENA_S,.04,Math.cos(a)*28*ARENA_S],lineMat(0x4f7f9a));r.rotation.y=a;r.castShadow=false;}
for(let i=0;i<10*ARENA_S;i++){const a=i*Math.PI*2/(10*ARENA_S);const x=Math.sin(a)*31*ARENA_S,z=Math.cos(a)*31*ARENA_S;const h=(4+Math.random()*5)*1.4;const pillar=box([2.4,h,2.4],[x,h/2,z],stone);pillar.rotation.y=a;box([3.1,.45,3.1],[x,h,z],trim);box([.16,h*.7,.16],[x-1.2,h*.5,z],lineMat(0x4f9fc0));}
// Torii-like gate, scaled up with the arena.
{const gate=new T.Group();gate.scale.setScalar(ARENA_S);scene.add(gate);
for(const x of [-10,10]){box([1.4,11,1.4],[x,5.5,-29],ground,gate);box([2.2,.55,2.2],[x,.25,-29],stone,gate);}
box([26,.9,2.1],[0,11,-29],ground,gate);box([23,.5,1.4],[0,8.8,-29],trim,gate);box([3.3,2.1,.35],[0,9.7,-27.9],ground,gate);}
// Arena geometry: pillars and low walls to swing between (same layout as roblox/.../Arena.server.luau, scaled for studs).
const obstacles=[],solidMeshes=[];
function obstacle(x,z,w,d,h,lit){const b=box([w,h,d],[x,h/2,z],lit?stone:dark);const cap=box([w+.4,.3,d+.4],[x,h-.15,z],trim);solidMeshes.push(b,cap);obstacles.push({x0:x-w/2,x1:x+w/2,z0:z-d/2,z1:z+d/2,h});if(lit){box([.08,h*.7,w*.35],[x,h*.45,z+d/2+.02],glowMat(0x71ceee));glow(0x53bbff,3).position.set(x,h*.6,z+d/2+.4);}}
for(const [x,z,w,h] of [[-13,-4,2.2,11],[13,-6,2.2,13],[-17,-17,2.4,9],[18,-14,2.4,10],[0,-23,2.6,14],[-10,8,2,8],[11,9,2,9]])obstacle(x,z,w,w,h,true);
obstacle(-6,1,10,.8,5);obstacle(7,-1.5,.8,9,5);
for(const [x,z,w,h] of [[-30,-8,3,16],[30,-12,3,18],[-34,-34,3.2,14],[36,-30,3.2,15],[0,-46,3.4,20],[-22,18,2.6,12],[24,20,2.6,14],[-44,10,3,15],[45,14,3,17],[-10,42,3,13],[14,45,3,16],[-50,-20,3.4,18],[52,-6,3.4,18]])obstacle(x,z,w,w,h,true);
obstacle(-24,-1,14,1,6);obstacle(26,-4,1,14,6);obstacle(0,-34,16,1,7);
for(let i=0;i<70;i++){const a=Math.random()*Math.PI*2,r=(48+Math.random()*50)*ARENA_S*.9+30,h=(6+Math.random()*30)*1.6;const b=box([3+Math.random()*8,h,3+Math.random()*8],[Math.sin(a)*r,h/2-10,Math.cos(a)*r],mat(0x9bb0c4+Math.floor(Math.random()*6)*0x020202,.9,.05));b.castShadow=false;}
const starGeo=new T.BufferGeometry(), starPos=[];for(let i=0;i<850;i++){const v=new T.Vector3(Math.random()-.5,Math.random()*.6,Math.random()-.5).normalize().multiplyScalar(120);starPos.push(v.x,v.y,v.z);}
starGeo.setAttribute('position',new T.Float32BufferAttribute(starPos,3));scene.add(Object.assign(new T.Points(starGeo,new T.PointsMaterial({color:0xb4d9ff,size:.12,transparent:true,opacity:.7})),{visible:false}));
const moonDisc=glow(0xc0dfff,12);moonDisc.position.set(-33,45,-75);moonDisc.visible=false;
const mist=glow(0x204d78,55);mist.position.set(0,5,-50);mist.material.opacity=.4;mist.visible=false;

function label(text,color='#9cbed0'){const c=document.createElement('canvas');c.width=256;c.height=64;const ct=c.getContext('2d');ct.font='500 19px sans-serif';ct.fillStyle=color;ct.textAlign='center';ct.fillText(text,128,28);const tex=new T.CanvasTexture(c);const s=new T.Sprite(new T.SpriteMaterial({map:tex,transparent:true,depthWrite:false}));s.scale.set(3.8,.95,1);return s;}
function makeTarget(x,z,index){const g=new T.Group();g.position.set(x,0,z);scene.add(g);box([.85,1.2,.45],[0,1.55,0],cloth,g);box([.37,1,.4],[-.25,.5,0],dark,g);box([.37,1,.4],[.25,.5,0],dark,g);box([.28,.95,.35],[-.61,1.55,0],cloth,g);box([.28,.95,.35],[.61,1.55,0],cloth,g);const head=mesh(new T.SphereGeometry(.31,12,10),mat(0x71828a),g);head.position.y=2.45;box([.66,.1,.51],[0,2.48,.02],mat(0x16232f),g);box([.96,.14,.53],[0,2.1,0],mat(0xaa3648),g);const l=label('TRAINING / 0'+index);l.position.y=3.45;g.add(l);const bg=box([1.45,.05,.015],[0,3.04,.1],mat(0x213440),g);const bar=box([1.45,.05,.02],[0,3.04,.12],glowMat(0x86d4e8),g);ring(.8,0x43627a,new T.Vector3(0,.08,0),.014,g);const t={g,bar,hp:250,max:250,home:new T.Vector3(x,0,z),index,locked:false,respawn:0,vel:null,landed:0};targets.push(t);return t;}
makeTarget(0,-10,1);makeTarget(-7,-15,2);makeTarget(8,-18,3);

// Local view arms are independent from the world-body pose, as in an FPS viewmodel.
function makeHand(side){const g=new T.Group();camera.add(g);const localSkin=skin.clone();localSkin.depthTest=false;const sleeve=cloth.clone();sleeve.depthTest=false;const fore=mesh(new T.CylinderGeometry(.105,.13,.55,8),sleeve,g);fore.position.set(0,-.31,.065);fore.rotation.x=.2;const cuff=mesh(new T.CylinderGeometry(.112,.112,.07,12),sleeve,g);cuff.position.y=-.075;const palm=box([.17,.17,.085],[0,.025,0],localSkin,g);const fuse=new T.Group();g.add(fuse);const cord=mesh(new T.CylinderGeometry(.012,.012,.3,5),new T.MeshBasicMaterial({color:0x4a3626,depthTest:false}),fuse);cord.position.set(side*.1,-.16,.1);cord.rotation.set(.5,0,side*.6);const ember=glow(colors.bomb,.12,fuse);ember.material.depthTest=false;ember.position.set(side*.19,-.28,.17);fuse.visible=false;
const fingers=new T.Group();g.add(fingers);fingers.visible=false;
g.traverse(o=>{o.renderOrder=102;o.frustumCulled=false;o.castShadow=false;});return {g,palm,skin:localSkin,sleeve,cuff,side,fuse,ember,fingers};}
const left=makeHand(-1),right=makeHand(1);
// Reze's choker, shown only during the pull: the body-fixed rig follows position and yaw (not pitch), so lowering
// the chin brings the black band and its pin ring into the bottom of the view. The ring sits on her right side.
const pinMat=new T.MeshStandardMaterial({color:0xd8dde4,roughness:.2,metalness:.95,emissive:0x202428,depthTest:false});
const choker=new T.Group();scene.add(choker);choker.visible=false;
{const band=mesh(new T.TorusGeometry(.13,.011,8,48,Math.PI*1.15),new T.MeshStandardMaterial({color:0x0d0d10,roughness:.45,depthTest:false}),choker);band.rotation.set(Math.PI/2,0,Math.PI*.925);band.position.set(0,-.3,-.1);band.scale.z=1.6;}
const RING_AT=new T.Vector3(Math.sin(.3)*.13,-.272,-.1-Math.cos(.3)*.13-.012);
const chokerRing=mesh(new T.TorusGeometry(.028,.0055,6,24),pinMat,choker);chokerRing.position.copy(RING_AT);
const socket=glow(colors.bomb,.08,choker);socket.position.copy(RING_AT).setY(-.3);socket.visible=false;
choker.traverse(o=>{o.renderOrder=101;o.frustumCulled=false;o.castShadow=false;o.receiveShadow=false;});chokerRing.renderOrder=104;
// The same ring once it is in the hand.
const pin=mesh(new T.TorusGeometry(.028,.0055,6,24),pinMat,camera);pin.renderOrder=103;pin.frustumCulled=false;pin.visible=false;
const PIN_IN_HAND=new T.Vector3(-.02,.12,-.04),HOOK_ROT=new T.Euler(-.15,-.2,1.25);pin.renderOrder=103;pin.frustumCulled=false;pin.visible=false;
// Bomb Devil hair: fuse cords hanging into the top of the view, each with a lit tip.
const devilHair=new T.Group();camera.add(devilHair);devilHair.visible=false;const hairTips=[];
for(const [x,len,tilt] of [[-.62,.3,.25],[-.48,.22,.1],[.5,.24,-.12],[.64,.32,-.28]]){const c=mesh(new T.CylinderGeometry(.014,.016,len,5),new T.MeshBasicMaterial({color:0x3a2a20,depthTest:false}),devilHair);c.position.set(x,.42-len/2,-.7);c.rotation.z=tilt;const tip=glow(colors.bomb,.09,devilHair);tip.material.depthTest=false;tip.position.set(x+Math.sin(tilt)*len/2,.42-len,-.7);hairTips.push(tip);}
devilHair.traverse(o=>{o.renderOrder=104;o.frustumCulled=false;});
const holdGlow=glow(0xffffff,.42,camera);holdGlow.material.depthTest=false;holdGlow.renderOrder=105;holdGlow.visible=false;
function pose(hand,pos,rot){hand.g.position.set(...pos);hand.g.rotation.set(...rot);hand.skin.emissive.set(0x000000);hand.skin.emissiveIntensity=1;}

// Zenitsu's sheathed katana: saya in the left hand, right hand resting on the tsuka. Local -Z points from the tsuba toward the pommel.
const swordMat=(color,roughness=.5,metalness=.3)=>{const m=mat(color,roughness,metalness);m.depthTest=false;return m;};
const sword={g:new T.Group(),hilt:new T.Group()};camera.add(sword.g);camera.add(sword.hilt);
{const gold=swordMat(0xc9a24a,.3,.8);box([.042,.052,.9],[0,0,.47],swordMat(0x2b2233,.25,.35),sword.g);box([.048,.058,.05],[0,0,.04],gold,sword.g);box([.048,.058,.04],[0,0,.9],gold,sword.g);
const tsuba=mesh(new T.CylinderGeometry(.064,.064,.016,16),swordMat(0x2a2522,.4,.7),sword.hilt);tsuba.rotation.x=Math.PI/2;
box([.034,.04,.25],[0,0,-.135],swordMat(0xf1ead8,.85,0),sword.hilt);for(let i=0;i<5;i++){const wrap=box([.037,.043,.016],[0,0,-.04-i*.045],swordMat(0x2d2a3c,.6,0),sword.hilt);wrap.rotation.y=(i%2?1:-1)*.5;}
box([.04,.046,.022],[0,0,-.27],gold,sword.hilt);
sword.blade=box([.014,.052,1.3],[0,-.004,.67],swordMat(0xe3e9f0,.15,.95),sword.hilt);
sword.edge=box([.018,.015,1.28],[0,-.026,.66],glowMat(0xffd23f),sword.hilt);sword.edge.material.depthTest=false;}
sword.g.traverse(o=>{o.renderOrder=100;o.frustumCulled=false;o.castShadow=false;o.receiveShadow=false;});
sword.hilt.traverse(o=>{o.renderOrder=101;o.frustumCulled=false;o.castShadow=false;o.receiveShadow=false;});
sword.g.visible=sword.hilt.visible=false;
// Reze's boot for the explosive kick, swinging up through the lower view.
const boot=box([.12,.1,.3],[0,-.5,-.5],swordMat(0x1c1a1e,.5,.2),camera);boot.renderOrder=102;boot.frustumCulled=false;boot.castShadow=false;boot.visible=false;
// The pocket is sewn onto the abdomen. This rig follows the body yaw, never the camera pitch.
// A brief downward glance reveals the curved pocket rim and rummaging wrists.
const doraBody=new T.Group();scene.add(doraBody);doraBody.visible=false;
const doraWhite=mat(0xfffdf1,.95,0),doraInk=mat(0x313a45,.9,0),doraGold=mat(0xf4ce52,.45,.25);
const doraShirt=mesh(new T.SphereGeometry(1,32,20),mat(0x0c1323),doraBody);doraShirt.position.set(0,-1.05,.06);doraShirt.scale.set(.48,.8,.32);
// Seen from the wearer's eyes: a shallow open pocket with a curved rim, not a front-facing torso panel.
const doraPouch=new T.Group();doraBody.add(doraPouch);doraPouch.position.set(0,-.7,-.3);
function pocketOutline(rx,rz,inset=0){const shape=new T.Shape();shape.moveTo(-rx,-inset);shape.lineTo(rx,-inset);shape.absellipse(0,-inset,rx,rz,0,-Math.PI,true);shape.closePath();return shape;}
const pocketShape=pocketOutline(.285,.255);const innerPocket=pocketOutline(.252,.216,.018);pocketShape.holes.push(new T.Path(innerPocket.getPoints(48)));
// A single closed, bevelled cloth shell: no intersecting rim strips or unclosed fabric triangles.
const pouchBody=mesh(new T.ExtrudeGeometry(pocketShape,{depth:.18,bevelEnabled:true,bevelSegments:3,steps:1,bevelSize:.008,bevelThickness:.006,curveSegments:40}),doraWhite,doraPouch);pouchBody.rotation.x=Math.PI/2;
const pocketMouth=mesh(new T.ShapeGeometry(innerPocket,40),new T.MeshBasicMaterial({color:0x20262c,side:T.DoubleSide}),doraPouch);pocketMouth.rotation.x=Math.PI/2;pocketMouth.position.y=-.028;
const pocketFloor=mesh(new T.ShapeGeometry(pocketOutline(.277,.245),40),doraWhite,doraPouch);pocketFloor.rotation.x=Math.PI/2;pocketFloor.position.y=-.18;
doraBody.traverse(o=>{o.castShadow=false;o.receiveShadow=false;o.frustumCulled=false;});
const doraItemProp=new T.Group();camera.add(doraItemProp);doraItemProp.visible=false;
function doraGroup(){return new T.Group();}
function doraCylinder(group,r1,r2,height,y,color){const p=mesh(new T.CylinderGeometry(r1,r2,height,24),mat(color,.55,.2),group);p.position.y=y;return p;}
function makeDoraTool(kind){const g=doraGroup();
  if(kind==='small'){doraCylinder(g,.045,.045,.23,-.06,0xd97a9a);doraCylinder(g,.105,.05,.13,.1,0xf29fbc);const lens=mesh(new T.CircleGeometry(.086,28),new T.MeshStandardMaterial({color:0xfff9d4,emissive:0x4c3e20}),g);lens.rotation.x=-Math.PI/2;lens.position.y=.168;box([.025,.04,.018],[0,-.04,-.048],mat(0x77cfb4),g);g.rotation.x=-Math.PI/2;}
  if(kind==='cannon'){const tube=mesh(new T.CylinderGeometry(.115,.115,.29,24,1,true),new T.MeshStandardMaterial({color:0xa8adb4,side:T.DoubleSide,metalness:.5,roughness:.4}),g);tube.rotation.x=Math.PI/2;const dark=mesh(new T.CircleGeometry(.097,24),mat(0x18212a),g);dark.position.z=-.13;dark.rotation.y=Math.PI;const rim=mesh(new T.TorusGeometry(.115,.018,8,28),mat(0xdbe0e4,.3,.5),g);rim.position.z=-.15;box([.11,.065,.15],[0,-.105,.03],mat(0x686d75),g);}
  if(kind==='dorayaki'){const filling=mesh(new T.SphereGeometry(1,28,14),mat(0x5c3028),g);filling.scale.set(.145,.035,.13);for(const y of [-.038,.038]){const bun=mesh(new T.SphereGeometry(1,28,16),mat(y>0?0xc98938:0xdba74f),g);bun.scale.set(.15,.043,.135);bun.position.y=y;}const stamp=mesh(new T.CircleGeometry(.024,20),mat(0xa86a2b),g);stamp.rotation.x=-Math.PI/2;stamp.position.y=.081;}
  if(kind==='copter'){doraCylinder(g,.012,.012,.21,.015,0xd5a83c);doraCylinder(g,.04,.035,.045,.13,0xffdf70);const blades=new T.Group();blades.position.y=.157;g.add(blades);box([.48,.014,.055],[0,0,0],mat(0xe5be4d),blades);g.userData.blades=blades;}
  if(kind==='door'){box([.2,.36,.025],[0,.08,0],mat(0xf18caa),g);box([.165,.31,.03],[0,.08,-.01],mat(0xd46f91),g);const knob=mesh(new T.SphereGeometry(.013,12,8),doraGold,g);knob.position.set(.055,.07,-.035);}
  g.traverse(o=>{o.castShadow=false;o.frustumCulled=false;});return g;
}
const doraToolModels={};for(const kind of ['small','cannon','dorayaki','copter','door']){doraToolModels[kind]=makeDoraTool(kind);doraItemProp.add(doraToolModels[kind]);}
const doraRotor=makeDoraTool('copter');scene.add(doraRotor);doraRotor.scale.setScalar(1.5);doraRotor.visible=false;
let doraFlightVelocity=0;
function doraBodyPoint(point){return doraBody.localToWorld(new T.Vector3(...point));}
function doraHand(hand,point){const at=camera.worldToLocal(doraBodyPoint(point)),shoulder=camera.worldToLocal(doraBodyPoint([hand.side*.43,-.36,-.05]));hand.g.position.copy(at);hand.g.quaternion.setFromUnitVectors(new T.Vector3(0,-1,0),shoulder.sub(at).normalize());hand.g.scale.setScalar(.72);}
function doraItem(kind,point,rotation){doraItemProp.visible=!!kind;if(!kind)return;for(const [key,o] of Object.entries(doraToolModels))o.visible=key===kind;doraItemProp.position.copy(point);doraItemProp.rotation.set(...rotation);}
// Shared beats: glance down .18s; grip .12-.32s; search .32-.98s; extract while the gaze returns .98-1.34s.
function poseDora(c,a){
  const down=ease(a/.18)*(1-ease((a-.98)/.36)),search=ease((a-.32)/.12)*(1-ease((a-.94)/.1)),pull=ease((a-.98)/.34);
  camera.rotation.x=mix(pitch,Math.min(pitch,-.88),down);camera.fov=66-down;document.body.classList.toggle('pocket-peek',down>.08);camera.updateMatrixWorld();doraBody.updateMatrixWorld();
  const leftAt=new T.Vector3(-.38,-.43,-.48).lerp(new T.Vector3(-.26,-.68,-.32),ease((a-.12)/.2));
  const rightAt=new T.Vector3(.38,-.44,-.5).lerp(new T.Vector3(.045+Math.sin(a*24)*.075*search,-.755+Math.sin(a*28)*.045*search,-.43+Math.cos(a*24)*.035*search),ease((a-.21)/.16));
  rightAt.lerp(new T.Vector3(.22,-.49,-.56),pull);doraHand(left,leftAt.toArray());doraHand(right,rightAt.toArray());
  doraPouch.scale.z=1+.025*search;
  if(a>.35&&a<.94&&Math.floor((a-.35)/.17)>(c.flags.rustle??-1)){c.flags.rustle=Math.floor((a-.35)/.17);sound('rustle');}
  const kind=c.type==='pocket'?c.item:c.type==='copter'?'copter':'door';
  if(a>=.98&&kind){
    const returnLook=ease((a-.98)/.36),from=camera.worldToLocal(doraBodyPoint(rightAt.clone().add(new T.Vector3(0,.06,-.03)).toArray())),to=new T.Vector3(.3,-.22,-.65);
    let at=from.lerp(to,returnLook),rot=[0,0,-.12];
    if(c.type==='copter'){const plant=ease((a-1.5)/.5);at.lerp(new T.Vector3(.55,.72,-.72),plant);if(a>2.05)at.lerp(new T.Vector3(.335,-.33,-.825),ease((a-2.05)/.35));right.g.position.copy(at).add(new T.Vector3(.045,-.09,.025));right.g.rotation.set(.2,0,-.2);doraItem(a<2.05?kind:null,at,rot);}
    else{if(kind==='dorayaki'){const bite=ease((a-1.57)/.18)*(1-ease((a-1.87)/.2));at.lerp(new T.Vector3(.08,-.08,-.17),bite);rot=[.3,0,-.1];}
      if(kind==='cannon'&&a>=1.75)at.z+=.1*(1-ease((a-1.75)/.18));if(c.type==='pocket'&&a>1.9)at.lerp(new T.Vector3(.5,-.7,-.6),ease((a-1.9)/.3));right.g.position.copy(at).add(new T.Vector3(.01,-.09,.065));right.g.rotation.set(.2,0,.1);doraItem(kind,at,rot);}
  }else doraItemProp.visible=false;
  if(a>1.45){left.g.position.lerp(new T.Vector3(-.4,-.48,-.8),ease((a-1.45)/.4));left.g.rotation.set(.1,.1,-.2);}
}
function makeAnywhereDoor(){const g=new T.Group(),pink=mat(0xe87a9e),edge=mat(0xb74a74),panel=mat(0xeea1bb);for(const x of [-1.05,1.05])box([.18,3.7,.22],[x,1.85,0],pink,g);box([2.28,.18,.22],[0,3.7,0],pink,g);box([2.28,.1,.22],[0,.05,0],edge,g);
  const portal=box([1.94,3.48,.025],[0,1.85,.07],new T.MeshBasicMaterial({color:0xafdcea,transparent:true,opacity:.85}),g);
  const hinge=new T.Group();hinge.position.set(-.95,.1,-.05);g.add(hinge);box([1.9,3.48,.1],[.95,1.74,0],pink,hinge);for(const y of [.93,2.56])box([1.48,1.12,.025],[.95,y,-.065],panel,hinge);const knob=mesh(new T.SphereGeometry(.075,16,12),doraGold,hinge);knob.position.set(1.65,1.65,-.13);g.userData={hinge,portal};return g;}

function ringMesh(radius){const m=mesh(new T.TorusGeometry(radius,.08,6,96),glowMat(colors.bomb),scene);m.rotation.x=Math.PI/2;m.castShadow=false;return m;}
const FWD=new T.Vector3(0,0,-1),BACK=new T.Vector3(0,0,1),UP=new T.Vector3(0,1,0);
const GRIP=new T.Vector3(0,-.01,-.15),SAYA=new T.Vector3(0,-.01,.2),RIGHT_ARM=new T.Vector3(-.4,.6,-.5).normalize(),LEFT_ARM=new T.Vector3(.5,.65,-.4).normalize();
const zen={pos:new T.Vector3(),dir:new T.Vector3(),push:0,drawn:false,drawProgress:0,hiltPos:new T.Vector3(),bladeDir:new T.Vector3(),glow:0};
function poseZen(bob){zen.pos.set(-.48,-.88,-1.10);zen.dir.set(.78,.30,-.55).normalize();zen.push=0;zen.drawn=false;zen.drawProgress=0;zen.glow=0;for(const h of [left,right])h.skin.emissive.set(0x000000);}
// Two-handed grip. The right hand holds the upper tsuka, the left hand the pommel end; both forearms point back to their shoulders,
// and the hands follow the blade roll, so the arms stay sensible through the rising cut, the flip and the chop.
const SHOULDER_R=new T.Vector3(.4,-.78,.3),SHOULDER_L=new T.Vector3(-.4,-.78,.3),GRIP_R2=new T.Vector3(0,-.01,-.09),GRIP_L2=new T.Vector3(0,-.01,-.22);
let twoHandK=0;
function placeHand(hand,gripLocal,shoulder,restArm,k,roll){
  hand.g.position.copy(gripLocal).applyQuaternion(sword.hilt.quaternion).add(sword.hilt.position);
  const arm=restArm.clone().lerp(hand.g.position.clone().sub(shoulder).normalize(),k).normalize();
  hand.g.quaternion.setFromUnitVectors(UP,arm);
  if(k>0&&roll)hand.g.quaternion.premultiply(new T.Quaternion().setFromAxisAngle(arm,roll*.5*k));}
function applyShanks(){if(castSword){const s=castSword;sword.g.visible=false;sword.hilt.visible=true;sword.hilt.position.copy(s.pos);sword.hilt.quaternion.setFromUnitVectors(BACK,s.dir);if(s.roll)sword.hilt.quaternion.multiply(new T.Quaternion().setFromAxisAngle(new T.Vector3(0,0,1),s.roll));sword.blade.visible=sword.edge.visible=true;sword.blade.scale.z=sword.edge.scale.z=1;sword.blade.position.z=.67;sword.edge.position.z=.66;sword.edge.material.color.setHex(colors.haki);if(s.armsDown){left.g.visible=false;right.g.visible=true;pose(right,[.38,-.36,-.76],[.1,-.25,.3]);return;}left.g.visible=false;placeHand(right,GRIP,SHOULDER_R,RIGHT_ARM,1,s.roll||0);return;}if(swordPose&&melee){sword.g.visible=false;sword.hilt.visible=true;sword.hilt.position.copy(swordPose.pos);sword.hilt.quaternion.setFromUnitVectors(BACK,swordPose.dir);if(swordPose.roll)sword.hilt.quaternion.multiply(new T.Quaternion().setFromAxisAngle(new T.Vector3(0,0,1),swordPose.roll));sword.blade.visible=sword.edge.visible=true;sword.blade.scale.z=sword.edge.scale.z=1;sword.blade.position.z=.67;sword.edge.position.z=.66;sword.edge.material.color.setHex(colors.haki);left.g.visible=true;placeHand(right,GRIP_R2,SHOULDER_R,RIGHT_ARM,1,swordPose.roll||0);placeHand(left,GRIP_L2,SHOULDER_L,LEFT_ARM,1,-(swordPose.roll||0));return;}const dir=new T.Vector3(-.5,.34,-.8).normalize();sword.g.visible=false;sword.hilt.visible=true;sword.hilt.position.copy(right.g.position).add(new T.Vector3(0,.08,-.08));sword.hilt.quaternion.setFromUnitVectors(BACK,dir.clone().negate());sword.blade.visible=sword.edge.visible=true;sword.blade.scale.z=sword.edge.scale.z=1;sword.blade.position.z=.67;sword.edge.position.z=.66;sword.edge.material.color.setHex(colors.haki);if(!cast){right.g.position.set(.32,-.39,-.92);right.g.quaternion.setFromUnitVectors(UP,RIGHT_ARM);}left.g.visible=false;}
function drawSword(pos,bladeDir,progress=1,roll=0){zen.roll=roll;zen.drawn=progress>.02;zen.drawProgress=progress;zen.hiltPos.set(...pos);zen.bladeDir.set(...bladeDir).normalize();}
function applyZen(){left.fingers.visible=right.fingers.visible=char==='zenitsu';sword.g.visible=zenDrawUntil>0&&time>zenDrawUntil&&time<zenDrawUntil+basicCfg().sheath;sword.hilt.visible=true;left.g.visible=char!=='shanks';sword.edge.material.color.setHex(char==='shanks'?colors.haki:0xffd23f);sword.g.position.copy(zen.pos);sword.g.quaternion.setFromUnitVectors(FWD,zen.dir);
if(zen.drawn){sword.hilt.position.copy(zen.hiltPos);sword.hilt.quaternion.setFromUnitVectors(BACK,zen.bladeDir);if(zen.roll)sword.hilt.quaternion.multiply(new T.Quaternion().setFromAxisAngle(new T.Vector3(0,0,1),zen.roll));}else{sword.hilt.position.copy(zen.pos).addScaledVector(zen.dir,zen.push);sword.hilt.quaternion.copy(sword.g.quaternion);}
sword.blade.visible=sword.edge.visible=zen.drawn;sword.blade.scale.z=sword.edge.scale.z=Math.max(.001,zen.drawProgress);sword.blade.position.z=.02+.65*zen.drawProgress;sword.edge.position.z=.02+.64*zen.drawProgress;sword.edge.material.opacity=.45+zen.glow*.55*(.6+Math.random()*.4);
const one=char==='shanks',k=one?0:clamp(twoHandK,0,1),roll=zen.roll||0;
sword.g.position.copy(zen.pos);
if(char==='zenitsu'){const grip=(hand,center,shoulder)=>{const up=center.clone().sub(shoulder).normalize();hand.g.position.copy(center).addScaledVector(up,-.025);hand.g.quaternion.setFromUnitVectors(UP,up);};grip(right,new T.Vector3(0,0,-.24+.12*k).applyQuaternion(sword.hilt.quaternion).add(sword.hilt.position),SHOULDER_R);grip(left,new T.Vector3(0,0,.10).applyQuaternion(sword.g.quaternion).add(sword.g.position).lerp(new T.Vector3(0,0,-.40).applyQuaternion(sword.hilt.quaternion).add(sword.hilt.position),k),SHOULDER_L);return;}placeHand(right,k>0?GRIP_R2:GRIP,SHOULDER_R,RIGHT_ARM,(k>0||one)?1:0,roll);if(one){left.g.visible=false;return;}
if(k>0.001){const sayaHand=SAYA.clone().applyQuaternion(sword.g.quaternion).add(sword.g.position);placeHand(left,GRIP_L2,SHOULDER_L,LEFT_ARM,1,-roll);left.g.position.lerp(sayaHand,1-k);}
else{left.g.position.copy(SAYA).applyQuaternion(sword.g.quaternion).add(sword.g.position);left.g.quaternion.setFromUnitVectors(UP,LEFT_ARM);}}

// Jagged additive lightning between two world points; no lights, so shaders are not recompiled per strike.
function bolt(from,to,color=colors.thunder,width=.05,life=.35,branches=2,glowSize){const g=new T.Group();scene.add(g);const dir=to.clone().sub(from),len=dir.length();const s1=new T.Vector3().crossVectors(dir,UP);if(s1.lengthSq()<1e-4)s1.set(1,0,0);s1.normalize();const s2=new T.Vector3().crossVectors(dir,s1).normalize();const pts=[from.clone()];const n=Math.max(4,Math.round(len/1.4));for(let i=1;i<n;i++){const p=from.clone().addScaledVector(dir,i/n),j=Math.min(1.2,len*.07);p.addScaledVector(s1,(Math.random()-.5)*j*2).addScaledVector(s2,(Math.random()-.5)*j*2);pts.push(p);}pts.push(to.clone());
const seg=(a,b,w,c)=>{const d=b.clone().sub(a);const m=new T.Mesh(new T.CylinderGeometry(w,w,d.length(),5,1,true),glowMat(c));m.position.copy(a).addScaledVector(d,.5);m.quaternion.setFromUnitVectors(UP,d.normalize());g.add(m);};
for(let i=0;i<pts.length-1;i++){seg(pts[i],pts[i+1],width,color);seg(pts[i],pts[i+1],width*.35,0xffffff);}
for(let b=0;b<branches;b++){const k=1+Math.floor(Math.random()*(pts.length-2)),a=pts[k];const end=a.clone().addScaledVector(dir,.12).addScaledVector(s1,(Math.random()-.5)*len*.25).addScaledVector(s2,(Math.random()-.5)*len*.25);seg(a,end,width*.5,color);}
glow(color,glowSize??Math.min(7,1.5+len*.12),g).position.copy(to);
effect(g,life,(o,u)=>{const flicker=Math.random()<.25?.35:1;o.traverse(m=>{if(m.material)m.material.opacity=(1-u)*flicker;});});return g;}
function thunderAfterimage(at,heading){const g=new T.Group();g.position.copy(at).setY(0);g.rotation.y=Math.atan2(-heading.x,-heading.z);scene.add(g);const shade=()=>new T.MeshBasicMaterial({color:0xffe582,transparent:true,opacity:.48,depthWrite:false});box([.72,1.12,.36],[0,1.35,0],shade(),g);mesh(new T.SphereGeometry(.28,10,8),shade(),g).position.set(0,2.14,0);for(const x of [-.24,.24]){box([.22,.72,.24],[x,.48,0],shade(),g);box([.2,.72,.22],[x*1.8,1.33,-.05],shade(),g);}effect(g,.82,(o,u)=>{o.traverse(m=>{if(m.material)m.material.opacity=(1-u)*.48;});o.scale.setScalar(1+u*.15);});}
function kamusariWave(from,dir,length,width){
  const startDistance=10,visualLength=Math.max(.1,length-startDistance),wave=new T.Group();scene.add(wave);wave.position.copy(from.clone().addScaledVector(dir,startDistance));wave.quaternion.setFromUnitVectors(BACK,dir);wave.scale.z=.001;
  const bands=[];const band=(w,h,color,opacity,blend)=>{const material=new T.MeshBasicMaterial({color,transparent:true,opacity,depthWrite:false,blending:blend||T.NormalBlending,side:T.DoubleSide});const m=box([w,h,visualLength],[0,0,visualLength*.5],material,wave);bands.push({mesh:m,opacity});};
  const vfx=4,heightVfx=16;band(width*.94*vfx,.38*heightVfx,0x050509,.78);band(width*.72*vfx,.22*heightVfx,0xd31534,.92);band(width*.3*vfx,.09*heightVfx,0xfff8f5,.98,T.AdditiveBlending);
  effect(wave,.52,(o,u)=>{const grow=ease(Math.min(1,u/.24)),fade=1-ease(clamp((u-.24)/.28,0,1));o.scale.z=Math.max(.001,grow);for(const b of bands)b.mesh.material.opacity=b.opacity*fade;});
  const side=new T.Vector3().crossVectors(dir,UP);if(side.lengthSq()<.01)side.set(1,0,0);side.normalize();const up=new T.Vector3().crossVectors(dir,side).normalize();
  for(let i=0;i<14;i++){const vfx=4,at=startDistance+visualLength*(.06+Math.random()*.88),offset=side.clone().multiplyScalar((Math.random()-.5)*width*.86*vfx).add(up.clone().multiplyScalar((Math.random()-.5)*2.1*heightVfx));const start=from.clone().addScaledVector(dir,at).add(offset),end=start.clone().addScaledVector(dir,(5+Math.random()*13)*vfx).add(side.clone().multiplyScalar((Math.random()-.5)*.7*vfx)).add(up.clone().multiplyScalar((Math.random()-.5)*.45*heightVfx));bolt(start,end,i%3===0?0xffffff:i%3===1?0x111116:0xff203d,(.09+Math.random()*.06)*vfx,.38,1,2.6);}
  return wave;
}
// ---- Shanks: red / white / black haki lightning, first-person sword poses and the kamusari beam ----
// castSword is the one-handed viewmodel pose of the current Shanks cast ({pos,dir,roll} in camera space); updateCast fills it every frame.
let castSword=null;
const HAKI_RED=0xff1f3d,HAKI_BLACK=0x07060a;
const hakiDark=opacity=>new T.MeshBasicMaterial({color:HAKI_BLACK,transparent:true,opacity,depthWrite:false,side:T.DoubleSide});
const hakiBladeDir=(yawDeg,pitchDeg)=>{const y=yawDeg*Math.PI/180,p=pitchDeg*Math.PI/180;return new T.Vector3(Math.sin(y)*Math.cos(p),Math.sin(p),-Math.cos(y)*Math.cos(p)).normalize();};
const camPoint=v=>v.clone().applyQuaternion(camera.quaternion).add(camera.position);
const swordTipWorld=(s,reach=1.25)=>camPoint(s.pos.clone().addScaledVector(s.dir,reach));
// Lightning with a black outline, a red body and a white core, so it reads as the three haki colours.
function hakiBolt(from,to,width=.06,life=.4,branches=2){
  const g=new T.Group();scene.add(g);
  const dir=to.clone().sub(from),len=dir.length();if(len<1e-3)return g;
  const s1=new T.Vector3().crossVectors(dir,UP);if(s1.lengthSq()<1e-4)s1.set(1,0,0);s1.normalize();
  const s2=new T.Vector3().crossVectors(dir,s1).normalize();
  const pts=[from.clone()],n=Math.max(4,Math.round(len/1.2));
  for(let i=1;i<n;i++){const p=from.clone().addScaledVector(dir,i/n),j=Math.min(1.1,len*.08);p.addScaledVector(s1,(Math.random()-.5)*j*2).addScaledVector(s2,(Math.random()-.5)*j*2);pts.push(p);}
  pts.push(to.clone());
  const seg=(a,b,w,kind)=>{const d=b.clone().sub(a),l=d.length();if(l<1e-4)return;const mat=kind==='k'?hakiDark(.7):glowMat(kind==='r'?HAKI_RED:0xffffff);mat.userData.o=mat.opacity;const m=new T.Mesh(new T.CylinderGeometry(w,w,l,5,1,true),mat);m.position.copy(a).addScaledVector(d,.5);m.quaternion.setFromUnitVectors(UP,d.normalize());g.add(m);};
  for(let i=0;i<pts.length-1;i++){seg(pts[i],pts[i+1],width*1.7,'k');seg(pts[i],pts[i+1],width,'r');seg(pts[i],pts[i+1],width*.45,'w');}
  for(let b=0;b<branches;b++){const k=1+Math.floor(Math.random()*(pts.length-2)),a=pts[k];const end=a.clone().addScaledVector(dir,.1).addScaledVector(s1,(Math.random()-.5)*len*.3).addScaledVector(s2,(Math.random()-.5)*len*.3);seg(a,end,width*1.0,'k');seg(a,end,width*.55,'r');seg(a,end,width*.25,'w');}
  const gl=glow(HAKI_RED,Math.min(4,1+len*.1),g);gl.position.copy(to);gl.material.userData.o=gl.material.opacity;
  effect(g,life,(o,u)=>{const f=Math.random()<.25?.35:1;o.traverse(m=>{if(m.material)m.material.opacity=(m.material.userData.o??1)*(1-u)*f;});});return g;}
// Bolts falling from the sky around a point.
function hakiStorm(center,radius,count){for(let i=0;i<count;i++){const ang=Math.random()*Math.PI*2,r=2.5+Math.random()*Math.max(.1,radius-2.5),x=center.x+Math.cos(ang)*r,z=center.z+Math.sin(ang)*r;const top=new T.Vector3(x+(Math.random()-.5)*3,12+Math.random()*8,z+(Math.random()-.5)*3);later(Math.random()*.25,()=>{hakiBolt(top,new T.Vector3(x,.1,z),.09+Math.random()*.06,.45,3);burst(new T.Vector3(x,.3,z),i%2?HAKI_RED:0xffffff,6,3);});}}
// A sword streak drawn in camera space: black outline, red body, white core. Grows quickly, then fades.
function slashTrail(kind){
  const pts=[];for(let i=0;i<=12;i++){const u=i/12,bow=Math.sin(u*Math.PI);pts.push(kind==='SWAT'?new T.Vector3(mix(.8,-.8,u),mix(.02,-.2,u)+.1*bow,-1.15-.1*bow):new T.Vector3(mix(.78,-.72,u),mix(.52,-.56,u)+.16*bow,-1.1-.2*bow));}
  const curve=new T.CatmullRomCurve3(pts),g=new T.Group();scene.add(g);
  const tube=(r,mat)=>{const m=new T.Mesh(new T.TubeGeometry(curve,24,r,6,false),mat);mat.userData.o=mat.opacity;g.add(m);return m;};
  const parts=[tube(.12,hakiDark(.8)),tube(.07,glowMat(HAKI_RED)),tube(.024,glowMat(0xffffff))];
  effect(g,.5,(o,u)=>{o.position.copy(camera.position);o.quaternion.copy(camera.quaternion);const grow=ease(u/.22),fade=1-ease((u-.25)/.75);for(const m of parts){m.geometry.setDrawRange(0,Math.floor(grow*24)*36);m.material.opacity=m.material.userData.o*fade;}});}
// Kamusari: a 5-wide cylinder of black / red / white, 50 long, wrapped in lightning that keeps striking it.
function kamusariBeam(from,dir,length,radius){
  const start=2.2,L=length-start,beam=new T.Group();scene.add(beam);beam.position.copy(from).addScaledVector(dir,start);beam.quaternion.setFromUnitVectors(BACK,dir);beam.scale.z=.001;
  const layers=[];const layer=(r,mat)=>{const geo=new T.CylinderGeometry(r,r,L,36,1,true);geo.rotateX(Math.PI/2);geo.translate(0,0,L/2);mat.side=T.DoubleSide;mat.userData.o=mat.opacity;const m=new T.Mesh(geo,mat);beam.add(m);layers.push(m);};
  layer(radius*1.04,hakiDark(.6));layer(radius*.84,glowMat(HAKI_RED));layer(radius*.5,new T.MeshBasicMaterial({color:0xff5a6a,transparent:true,opacity:.8,blending:T.AdditiveBlending,depthWrite:false}));layer(radius*.22,new T.MeshBasicMaterial({color:0xffffff,transparent:true,opacity:1,blending:T.AdditiveBlending,depthWrite:false}));
  effect(beam,.9,(o,u)=>{const grow=ease(u/.16),fade=1-ease((u-.35)/.65);o.scale.z=Math.max(.001,grow);const pulse=.85+.15*Math.sin(u*70);for(const m of layers)m.material.opacity=m.material.userData.o*fade*pulse;});
  const side=new T.Vector3().crossVectors(dir,UP);if(side.lengthSq()<.01)side.set(1,0,0);side.normalize();const up=new T.Vector3().crossVectors(dir,side).normalize();
  const around=(s,ang,r)=>from.clone().addScaledVector(dir,s).addScaledVector(side,Math.cos(ang)*r).addScaledVector(up,Math.sin(ang)*r);
  for(let i=0;i<34;i++){const s=start+Math.random()*L*.92,ang=Math.random()*Math.PI*2,r0=radius*(1+Math.random()*.4),reach=5+Math.random()*13,turn=(Math.random()-.5)*1.1;later(Math.random()*.16,()=>hakiBolt(around(s,ang,r0),around(Math.min(length,s+reach),ang+turn,radius*(1.1+Math.random()*.9)),.07+Math.random()*.06,.5,2));}
  for(let i=0;i<6;i++){const s=start+(i/5)*L*.8;later(.04+s/length*.18,()=>{const rg=ring(radius,i%2?0xffffff:HAKI_RED,around(s,0,0),.1);rg.quaternion.setFromUnitVectors(BACK,dir);effect(rg,.5,(o,u)=>{o.scale.setScalar(1+1.1*u);o.material.opacity=.8*(1-u);});});}
  return beam;}
// ---- Reze: the full detonation (R in Bomb Devil form) ----
// Charge: ground cracks creep outward, embers are sucked in, a white-hot core swells before the hands and the view darkens and narrows.
// Blast: white-out, fire dome, fire pillars, flying debris, mushroom column, scorched ground and a long camera shudder.
const EMBER=0xffa24a;
function crackNet(center,R){
  const g=new T.Group();g.position.set(center.x,.06,center.z);scene.add(g);const arms=[];
  for(let i=0;i<22;i++){
    const arm=new T.Group();arm.rotation.y=i/22*Math.PI*2+(Math.random()-.5)*.2;g.add(arm);
    const len=R*(.55+Math.random()*.45),segs=5;let z=0,x=0;
    for(let s=0;s<segs;s++){const sl=len/segs,dx=(Math.random()-.5)*.9;
      const m=new T.Mesh(new T.BoxGeometry(.1+(1-s/segs)*.12,.02,sl*1.05),glowMat(s%2?0xffd27a:0xff6a1a));
      m.position.set(x+dx/2,0,-(z+sl/2));m.rotation.y=-Math.atan2(dx,sl);m.userData.at=s/segs;m.material.userData.o=m.material.opacity;m.visible=false;arm.add(m);x+=dx;z+=sl;}
    arms.push(arm);
  }
  return {group:g,arms};
}
function emberIn(center,reach,col){
  const a=Math.random()*Math.PI*2,r=reach*(.5+Math.random()*.5),from=new T.Vector3(center.x+Math.cos(a)*r,.1+Math.random()*2.6,center.z+Math.sin(a)*r),to=center.clone().setY(1+Math.random()*.8);
  const s=glow(col??(Math.random()<.5?EMBER:0xffe2a0),.12+Math.random()*.16);s.position.copy(from);
  effect(s,.9,(o,u)=>{o.position.lerpVectors(from,to,u*u);o.material.opacity=Math.min(1,u*4)*(1-u*.4);});
}
function fireDome(at,R,cols=[0xff6a14,0xfff0c8]){
  for(const [col,k,life,op,add] of [[cols[0],1,.8,.6,false],[cols[1],.7,.4,1,true]]){
    const m=new T.Mesh(new T.SphereGeometry(1,28,18),new T.MeshBasicMaterial({color:col,transparent:true,opacity:op,side:T.BackSide,blending:add?T.AdditiveBlending:T.NormalBlending,depthWrite:false}));m.position.copy(at);scene.add(m);
    effect(m,life,(o,u)=>{o.scale.setScalar(.5+R*k*1.15*ease(Math.min(1,u*1.6)));o.material.opacity=op*Math.pow(1-u,1.4);});
  }
}
function firePillar(x,z,radius,height,cols=[0xe2480a,0xffa21f,0xffffff]){
  const g=new T.Group();g.position.set(x,0,z);scene.add(g);
  const mk=(r,col,op,add)=>{const geo=new T.CylinderGeometry(r*.38,r,height,18,1,true);geo.translate(0,height/2,0);const m=new T.Mesh(geo,new T.MeshBasicMaterial({color:col,transparent:true,opacity:op,blending:add?T.AdditiveBlending:T.NormalBlending,depthWrite:false,side:T.DoubleSide}));m.material.userData.o=op;g.add(m);};
  mk(radius,cols[0],.7,false);mk(radius*.62,cols[1],.85,true);mk(radius*.26,cols[2],1,true);
  const top=glow(0xff8a2a,radius*5,g);top.position.y=height*.9;top.material.userData.o=top.material.opacity;
  effect(g,1.1,(o,u)=>{const rise=ease(u/.22),fade=1-ease((u-.3)/.7);o.scale.set(1+u*.5,Math.max(.001,rise),1+u*.5);o.traverse(m=>{if(m.material)m.material.opacity=(m.material.userData.o??1)*fade;});});
}
function debrisBurst(at,R,count){
  for(let i=0;i<count;i++){
    const ang=Math.random()*Math.PI*2,sp=6+Math.random()*R*1.2,s=.12+Math.random()*.3;
    const m=new T.Mesh(new T.BoxGeometry(s,s*.5,s*(.6+Math.random()*.8)),new T.MeshBasicMaterial({color:i%3?0x2a2a30:0x6a5444}));
    m.position.copy(at).add(new T.Vector3(Math.cos(ang)*(4+Math.random()*3),0,Math.sin(ang)*(4+Math.random()*3)));scene.add(m);
    const v=new T.Vector3(Math.cos(ang)*sp,8+Math.random()*14,Math.sin(ang)*sp),spin=new T.Vector3(Math.random()*8,Math.random()*8,Math.random()*8);
    effect(m,2.6,(o,u,dt)=>{v.y-=22*dt;o.position.addScaledVector(v,dt);if(o.position.y<.1){o.position.y=.1;v.multiplyScalar(.2);v.y=0;}else{o.rotation.x+=spin.x*dt;o.rotation.y+=spin.y*dt;}});
  }
}
function puff(pos,size,vy,life,hot=true){
  const hotC=new T.Color(0xffa050),coldC=new T.Color(0x5a534d),s=new T.Sprite(new T.SpriteMaterial({map:smokeTexture,transparent:true,depthWrite:false,opacity:.9,color:hot?0xffa050:0x555560}));
  s.scale.setScalar(size*.4);s.position.copy(pos);scene.add(s);const drift=new T.Vector3((Math.random()-.5)*1.4,0,(Math.random()-.5)*1.4);
  effect(s,life,(o,u,dt)=>{o.scale.setScalar(size*(.4+.9*ease(u)));o.position.y+=vy*dt*(1-u*.6);o.position.addScaledVector(drift,dt);o.material.color.lerpColors(hot?hotC:new T.Color(0x6a6a72),coldC,ease(u*1.1));o.material.opacity=.8*(1-u);});
}
function mushroom(at){
  for(let i=0;i<14;i++)later(i*.07,()=>puff(new T.Vector3(at.x+(Math.random()-.5)*2,1+i*1.3,at.z+(Math.random()-.5)*2),3.5+Math.random()*1.5,6+Math.random()*2,i<9));
  for(let i=0;i<18;i++)later(.9+i*.03,()=>{const a=Math.random()*Math.PI*2,r=2+Math.random()*6;puff(new T.Vector3(at.x+Math.cos(a)*r,17+Math.random()*3,at.z+Math.sin(a)*r),6+Math.random()*3,2+Math.random()*2,i%2===0);});
}
function scorch(at,R){
  const d=new T.Mesh(new T.CircleGeometry(R,48),new T.MeshBasicMaterial({color:0x0a0908,transparent:true,opacity:.55,depthWrite:false}));d.rotation.x=-Math.PI/2;d.position.set(at.x,.05,at.z);scene.add(d);
  const rim=ring(R,0xff6a1a,new T.Vector3(at.x,.07,at.z),.25);
  effect(d,7,(o,u)=>{o.material.opacity=.55*(1-ease((u-.55)/.45));});effect(rim,3.5,(o,u)=>{o.material.opacity=.8*(1-u);});
}
// ---- Reze: shared blast pieces for the transformation, the leap, the dive and the hand blast ----
function emberBurst(at,count,speed,up=4){for(let i=0;i<count;i++){const s=glow(i%3?EMBER:0xffe2a0,.1+Math.random()*.18);s.position.copy(at);const v=new T.Vector3((Math.random()-.5)*speed,up*(.4+Math.random()),(Math.random()-.5)*speed);effect(s,.8+Math.random()*.8,(o,u,dt)=>{v.y-=6*dt;o.position.addScaledVector(v,dt);o.material.opacity=1-u;});}}
function shockRing(pos,color,R,life=.6,thick=.14,normal=null){const m=ring(.3,color,pos,.028);if(normal)m.quaternion.setFromUnitVectors(BACK,normal);effect(m,life,(o,u)=>{o.scale.setScalar(1+R/.3*ease(u));o.material.opacity=.9*(1-u);});}
// Her own head goes off: white-out, fire dome, two rings, pillars fanned out in front, debris, embers and a smoke column.
function transformBlast(at){
  fireDome(at,6);shockRing(at.clone().setY(.1),0xffffff,9,.5,.2);shockRing(at.clone().setY(.15),0xff8a2a,13,.8,.25);
  const fw=flatForward(),fa=Math.atan2(fw.z,fw.x);
  for(let i=0;i<7;i++){const ang=fa+(Math.random()-.5)*2.4,d=4+Math.random()*5;later(Math.random()*.25,()=>firePillar(at.x+Math.cos(ang)*d,at.z+Math.sin(ang)*d,.5+Math.random()*.5,9+Math.random()*7));}
  debrisBurst(at.clone().setY(.5),7,26);emberBurst(at.clone().setY(1.6),50,9,9);
  for(let i=0;i<8;i++)later(i*.06,()=>puff(new T.Vector3(at.x+(Math.random()-.5)*3,1.5+i*.9,at.z+(Math.random()-.5)*3),3+Math.random()*2,5,i<4));
}
// The leap: a blast under her feet with a short fire jet, rings, debris and a ring of dust.
function launchBlast(at){
  explode(at.clone().setY(.4),3.4);shockRing(at.clone().setY(.1),0xffd9a0,8,.5,.18);shockRing(at.clone().setY(.12),0xff7a1f,12,.7,.22);
  firePillar(at.x,at.z,1.1,11);debrisBurst(at.clone().setY(.3),6,18);emberBurst(at.clone().setY(.6),36,7,7);
  for(let i=0;i<8;i++){const a=i/8*Math.PI*2;puff(new T.Vector3(at.x+Math.cos(a)*2,.6,at.z+Math.sin(a)*2),3,.8,1.2,false);}
}
// The dive lands: pillars around her, a heavy ring, debris, embers, a scorch mark and smoke.
function slamBlast(at){
  impactFrame();fireDome(at.clone().setY(.8),4);shockRing(at.clone().setY(.1),0xffffff,10,.45,.22);shockRing(at.clone().setY(.14),0xff8a2a,15,.8,.28);
  for(let i=0;i<9;i++){const ang=i/9*Math.PI*2+Math.random()*.5,d=5+Math.random()*4;later(Math.random()*.18,()=>firePillar(at.x+Math.cos(ang)*d,at.z+Math.sin(ang)*d,.6+Math.random()*.6,8+Math.random()*8));}
  debrisBurst(at.clone().setY(.4),9,32);emberBurst(at.clone().setY(.8),44,9,8);scorch(at,8);
  for(let i=0;i<10;i++){const a=Math.random()*Math.PI*2,r=3+Math.random()*5;puff(new T.Vector3(at.x+Math.cos(a)*r,.8,at.z+Math.sin(a)*r),3.5+Math.random()*2,1.8,1.6,i%3===0);}
}
// The hand blast: two rings standing against the view, a hot flare and embers thrown forward.
function handBlast(at,normal){
  shockRing(at,0xffe5c4,5,.35,.1,normal);shockRing(at,0xff8a2a,8,.55,.14,normal);emberBurst(at,40,10,4);
  const fl=glow(0xffffff,3);fl.position.copy(at);effect(fl,.18,(o,u)=>{o.scale.setScalar(3+4*u);o.material.opacity=1-u;});
  for(let i=0;i<5;i++)puff(at.clone().add(new T.Vector3((Math.random()-.5)*1.2,(Math.random()-.5)*1.2,(Math.random()-.5)*1.2)),2.4+Math.random()*1.4,1,.8,i<3);
}
// While the Bomb Devil is out, embers drift up past the edges of her view.
function devilAmbient(){const p=camPoint(new T.Vector3((Math.random()-.5)*1.8,-.55-Math.random()*.2,-.9-Math.random()*.6)),s=glow(Math.random()<.5?EMBER:0xffe2a0,.04+Math.random()*.07);s.position.copy(p);const v=new T.Vector3((Math.random()-.5)*.3,.5+Math.random()*.6,0);effect(s,1+Math.random(),(o,u,dt)=>{o.position.addScaledVector(v,dt);o.material.opacity=Math.sin(u*Math.PI)*.9;});}
// ---- Gojo and Reze basic attacks: a boxer's combination ----
// 1 jab (lead hand, quick and straight), 2 cross (rear hand, the hips drive the view round), 3 lead hook from the side (heavier).
// Both fists stay up at the chin between the punches; the weight moves into each one.
const BOXER_BASIC={windups:[.11,.13,.27],swing:.09,recoveries:[.2,.2,.36],damage:[12,14,20],comboReset:.95,slideDuration:.7};
const GUARD_L=new T.Vector3(-.3,-.2,-.78),GUARD_R=new T.Vector3(.3,-.22,-.78),REST_L=new T.Vector3(-.38,-.48,-.8),REST_R=new T.Vector3(.38,-.42,-.8);
const bez3=(a,b,c,t)=>a.clone().multiplyScalar((1-t)*(1-t)).addScaledVector(b,2*(1-t)*t).addScaledVector(c,t*t);
const arr3=(a,b,t)=>a.map((v,i)=>v+(b[i]-v)*t);
function punchPose(c,wind,strike,recovery,a){
  const out=1-recovery,hit=strike*out,settle=ease((a-(c.duration-.14))/.14),fwd=new T.Vector3(0,0,-1).applyQuaternion(camera.quaternion);
  const guardRotL=[-.5,.25,-.25],guardRotR=[-.5,-.25,.25];
  let L=GUARD_L.clone(),R=GUARD_R.clone(),rl=guardRotL,rr=guardRotR,yaw=0,roll=0,lunge=0,dip=0,fov=0;
  if(c.combo===1){
    L=GUARD_L.clone().lerp(new T.Vector3(-.34,-.26,-.7),wind).lerp(new T.Vector3(-.2,-.22,-1.45),strike).lerp(GUARD_L,recovery);
    rl=arr3(arr3(guardRotL,[-.6,.3,-.3],wind),[-.5,.5,-.2],strike);rl=arr3(rl,guardRotL,recovery);
    yaw=.02*hit;lunge=.14*hit;fov=4*hit;
  }else if(c.combo===2){
    R=GUARD_R.clone().lerp(new T.Vector3(.5,-.32,-.55),wind).lerp(new T.Vector3(.2,-.22,-1.5),strike).lerp(GUARD_R,recovery);
    rr=arr3(arr3(guardRotR,[-.65,-.6,.4],wind),[-.5,-.5,.2],strike);rr=arr3(rr,guardRotR,recovery);
    L=GUARD_L.clone().add(new T.Vector3(.05,.02,.04*wind));
    yaw=(-.06*wind*(1-strike)+.11*strike)*out;roll=.05*hit;lunge=.22*hit;fov=6*hit;
  }else{
    const p0=new T.Vector3(-.9,-.28,-.5),p1=new T.Vector3(-.62,-.12,-1.3),p2=new T.Vector3(-.06,-.14,-1.3);
    L=GUARD_L.clone().lerp(p0,wind);if(strike>0)L=bez3(p0,p1,p2,strike);L.lerp(GUARD_L,recovery);
    rl=arr3(arr3(guardRotL,[-.5,-.9,-.9],wind),[-.8,.5,.3],strike);rl=arr3(rl,guardRotL,recovery);
    yaw=(.07*wind*(1-strike)-.13*strike)*out;roll=-.07*hit;lunge=.18*hit;dip=.05*hit;fov=8*hit;
  }
  if(settle>0){L.lerp(REST_L,settle);R.lerp(REST_R,settle);rl=arr3(rl,[.1,.2,-.3],settle);rr=arr3(rr,[.05,-.25,.3],settle);}
  pose(left,L.toArray(),rl);pose(right,R.toArray(),rr);
  camera.rotation.y+=yaw;camera.rotation.z+=roll;camera.fov=66-2*wind*(1-strike)+fov;camera.position.addScaledVector(fwd,lunge);camera.position.y-=dip;
}
// ---- Gojo: the purple beam, the red repulsion blast and the domain's shattering sky ----
// Hollow Purple: a 3-wide beam of violet and white 62 long, lightning wrapped around it, then a void blast where it ends.
function purpleBeam(from,dir,length,radius){
  const beam=new T.Group();scene.add(beam);beam.position.copy(from);beam.quaternion.setFromUnitVectors(BACK,dir);beam.scale.z=.001;
  const layers=[];const layer=(r,color,op,add)=>{const geo=new T.CylinderGeometry(r,r,length,28,1,true);geo.rotateX(Math.PI/2);geo.translate(0,0,length/2);const m=new T.Mesh(geo,new T.MeshBasicMaterial({color,transparent:true,opacity:op,blending:add?T.AdditiveBlending:T.NormalBlending,depthWrite:false,side:T.DoubleSide}));m.material.userData.o=op;beam.add(m);layers.push(m);};
  layer(radius*1.15,0x4a1fc2,.5,false);layer(radius*.8,0xa04dff,.85,true);layer(radius*.45,0xe6c8ff,.9,true);layer(radius*.2,0xffffff,1,true);
  effect(beam,.95,(o,u)=>{const grow=ease(u/.14),fade=1-ease((u-.3)/.7);o.scale.z=Math.max(.001,grow);o.scale.x=o.scale.y=1+.12*Math.sin(u*60);for(const m of layers)m.material.opacity=m.material.userData.o*fade;});
  const side=new T.Vector3().crossVectors(dir,UP);if(side.lengthSq()<.01)side.set(1,0,0);side.normalize();const up=new T.Vector3().crossVectors(dir,side).normalize();
  const around=(s,ang,r)=>from.clone().addScaledVector(dir,s).addScaledVector(side,Math.cos(ang)*r).addScaledVector(up,Math.sin(ang)*r);
  for(let i=0;i<30;i++){const s=2+Math.random()*(length-8),ang=Math.random()*Math.PI*2,r0=radius*(1.1+Math.random()*.5);later(Math.random()*.2,()=>bolt(around(s,ang,r0),around(Math.min(length,s+4+Math.random()*9),ang+(Math.random()-.5),radius*(1.2+Math.random()*1.2)),i%3?colors.purple:0xffffff,.06+Math.random()*.05,.4,1));}
  for(let i=0;i<5;i++){const s=3+(i/4)*length*.8;later(.03+s/length*.16,()=>{const rg=ring(radius,i%2?0xffffff:colors.purple,around(s,0,0),.08);rg.quaternion.setFromUnitVectors(BACK,dir);effect(rg,.5,(o,u)=>{o.scale.setScalar(1+1.4*u);o.material.opacity=.8*(1-u);});});}
  return beam;
}
// The ground it passed over is scored and stays dark for a while.
function scorchLine(from,dir,length){
  const d=new T.Vector3(dir.x,0,dir.z).normalize(),mid=from.clone().addScaledVector(d,length/2);
  const m=new T.Mesh(new T.PlaneGeometry(3.4,length),new T.MeshBasicMaterial({color:0x1a0f2e,transparent:true,opacity:.6,depthWrite:false}));m.rotation.x=-Math.PI/2;m.rotation.z=Math.atan2(d.x,d.z);m.position.set(mid.x,.06,mid.z);m.rotation.order='YXZ';m.rotation.set(-Math.PI/2,Math.atan2(d.x,d.z),0);scene.add(m);
  effect(m,7,(o,u)=>{o.material.opacity=.6*(1-ease((u-.4)/.6));});
}
function voidBlast(at){
  fireDome(at,10,[0x6a2cff,0xf3e6ff]);shockRing(at.clone().setY(.15),0xffffff,16,.5,.2);shockRing(at.clone().setY(.2),colors.purple,24,.9,.25);
  for(let i=0;i<10;i++){const a=Math.random()*Math.PI*2,d=3+Math.random()*9;later(Math.random()*.3,()=>firePillar(at.x+Math.cos(a)*d,at.z+Math.sin(a)*d,.6+Math.random()*.7,10+Math.random()*10,[0x5a2bd6,0xb36bff,0xffffff]));}
  debrisBurst(at.clone().setY(.4),11,34);burst(at,colors.purple,90,14);
}
// The red orb hits: rings, sparks, and the target is thrown back.
function redImpact(at,dir,target){
  shockRing(at,0xff365d,8,.6,.2);shockRing(at,0xffffff,5,.4,.1);burst(at,colors.red,60,12);
  for(let i=0;i<8;i++)bolt(at,at.clone().add(new T.Vector3((Math.random()-.5)*5,(Math.random()-.3)*4,(Math.random()-.5)*5)),colors.red,.06,.3,1);
  launch(target,dir.clone().setY(0).normalize().multiplyScalar(14).setY(7));
}
// Domain Expansion: the sky breaks into glass shards that fly away as the dome opens.
function domainShatter(){
  const origin=camera.position.clone();
  for(let i=0;i<46;i++){const dir=new T.Vector3(Math.random()-.5,Math.random()*.7-.1,Math.random()-.5).normalize(),r=5+Math.random()*8;
    const sh=new T.Mesh(new T.PlaneGeometry(.8+Math.random()*1.6,.6+Math.random()*1.2),new T.MeshBasicMaterial({color:0xcfe6ff,transparent:true,opacity:.55,side:T.DoubleSide,depthWrite:false,blending:T.AdditiveBlending}));
    sh.position.copy(origin).addScaledVector(dir,r);sh.lookAt(origin);scene.add(sh);const spin=new T.Vector3(Math.random()*3,Math.random()*3,Math.random()*3);
    effect(sh,1.3,(o,u,dt)=>{o.position.addScaledVector(dir,(7+6*u)*dt);o.rotation.x+=spin.x*dt;o.rotation.y+=spin.y*dt;o.material.opacity=.55*(1-u);});}
  shockRing(origin.clone().setY(.2),0xffffff,30,.7,.2);shockRing(origin.clone().setY(.2),0x88c6ff,40,1.2,.2);
}
function domainMote(){const p=camera.position.clone().add(new T.Vector3((Math.random()-.5)*16,(Math.random()-.3)*6,(Math.random()-.5)*16)),s=glow(Math.random()<.5?0x9fd8ff:0xffffff,.06+Math.random()*.1);s.position.copy(p);const v=new T.Vector3((Math.random()-.5)*.3,.2+Math.random()*.4,(Math.random()-.5)*.3);effect(s,2+Math.random()*1.5,(o,u,dt)=>{o.position.addScaledVector(v,dt);o.material.opacity=Math.sin(u*Math.PI)*.9;});}
// ---- Reze: the look of the Bomb Devil ----
// A dim orange vignette and glowing hands while transformed, an impact frame (one inverted flash) on the big blasts,
// and a title card with letterbox bars for the transformation and the full detonation.
let impactUntil=0,impactOn=false;
const impactFrame=()=>{impactUntil=previous+90;};
const fxLayer=(()=>{const d=document.createElement('div');d.style.cssText='position:fixed;inset:0;pointer-events:none;z-index:40;overflow:hidden';document.body.append(d);return d;})();
const devilVignette=(()=>{const d=document.createElement('div');d.style.cssText='position:fixed;inset:0;pointer-events:none;z-index:2;opacity:0;transition:opacity .6s;background:radial-gradient(ellipse at center,rgba(0,0,0,0) 48%,rgba(150,40,0,.34) 82%,rgba(40,8,0,.62) 100%)';document.body.append(d);return d;})();
function bigTitle(jp,sub,color='#ff7a2e',life=1900){
  const w=document.createElement('div');w.style.cssText='position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:10px;transition:opacity .5s';
  const bar=top=>{const b=document.createElement('div');b.style.cssText='position:absolute;left:0;right:0;height:0;background:#000;transition:height .25s ease-out;'+(top?'top:0':'bottom:0');w.append(b);return b;};
  const t=bar(true),b=bar(false);
  const h=document.createElement('div');h.textContent=jp;h.style.cssText='font:900 clamp(56px,11vw,168px)/1 "Noto Serif KR","Noto Serif JP",serif;color:'+color+';letter-spacing:.08em;text-shadow:0 0 30px '+color+',0 0 80px '+color+';transform:scale(1.7);opacity:0;transition:transform .35s cubic-bezier(.2,.9,.2,1),opacity .2s;position:relative';
  const s=document.createElement('div');s.textContent=sub;s.style.cssText='font:700 clamp(14px,1.6vw,24px)/1 sans-serif;color:#fff;letter-spacing:.5em;opacity:0;transition:opacity .5s .2s;position:relative;text-shadow:0 0 12px '+color;
  w.append(h,s);fxLayer.append(w);
  requestAnimationFrame(()=>{t.style.height=b.style.height='9vh';h.style.transform='scale(1)';h.style.opacity='1';s.style.opacity='.9';});
  setTimeout(()=>{w.style.opacity='0';setTimeout(()=>w.remove(),550);},life);
}
function flatForward(){return new T.Vector3(-Math.sin(yaw),0,-Math.cos(yaw));}
// Seventh form: a lightning dragon forms along the dash path, then curls up and back over it so that its head
// faces the user, who turns around after arriving. The head leads while the tube body grows behind it.
function dragon(from,to){const fwd=to.clone().sub(from).setY(0);const pathLen=fwd.length();fwd.normalize();const side=new T.Vector3(-fwd.z,0,fwd.x);const pts=[];
for(let i=0;i<=30;i++){const s=i/30;pts.push(from.clone().addScaledVector(fwd,pathLen*s).addScaledVector(side,Math.sin(s*Math.PI*3)*1.4+1.8).setY(1+Math.sin(s*Math.PI*2)*.5));}
for(let j=1;j<=14;j++){const t=j/14;pts.push(to.clone().addScaledVector(fwd,2.5*Math.sin(t*Math.PI)-Math.min(12,pathLen*.45)*t).addScaledVector(side,1.8+2.5*Math.sin(t*Math.PI)).setY(1+5*Math.sin(t*Math.PI/2)));}
const curve=new T.CatmullRomCurve3(pts),segs=160,radial=8;const g=new T.Group();scene.add(g);
const body=new T.Mesh(new T.TubeGeometry(curve,segs,.32,radial,false),glowMat(colors.thunder)),core=new T.Mesh(new T.TubeGeometry(curve,segs,.11,radial,false),glowMat(0xfff6d8));g.add(body,core);
const head=new T.Group();head.scale.setScalar(1.7);g.add(head);const hm=glowMat(colors.thunder);box([.9,.7,1.1],[0,0,0],hm,head);box([.6,.42,.95],[0,.05,-.9],hm,head);box([.55,.16,.9],[0,-.35,-.75],hm,head).rotation.x=-.45;
for(const x of [-.28,.28]){const horn=box([.09,.09,1.1],[x,.45,.55],hm,head);horn.rotation.set(.55,x>0?.25:-.25,0);glow(0xffffff,.5,head).position.set(x,.22,-.45);}
glow(colors.thunder,4,head);g.traverse(o=>{o.castShadow=false;o.receiveShadow=false;});
const tangent=new T.Vector3(),sparked=new Set();
effect(g,2,(o,u)=>{const grow=clamp(u*2/.45,.001,1),drawn=Math.floor(grow*segs)*radial*6;body.geometry.setDrawRange(0,drawn);core.geometry.setDrawRange(0,drawn);
head.position.copy(curve.getPointAt(grow));head.quaternion.setFromUnitVectors(FWD,curve.getTangentAt(grow,tangent));
const fade=(u<.45?1:1-ease((u-.45)/.55))*(Math.random()<.2?.5:1);o.traverse(m=>{if(m.material)m.material.opacity=fade;});
const k=Math.floor(grow*8);if(k>0&&!sparked.has(k)){sparked.add(k);const q=curve.getPointAt(k/8);bolt(q,q.clone().add(new T.Vector3((Math.random()-.5)*3,(Math.random()-.2)*2.5,(Math.random()-.5)*3)),colors.thunder,.03,.25,1,.6);}});
return g;}

const smokeTexture=canvasTexture((c,s)=>{const g=c.createRadialGradient(s/2,s/2,0,s/2,s/2,s/2);g.addColorStop(0,'rgba(70,62,62,.9)');g.addColorStop(.5,'rgba(50,44,46,.45)');g.addColorStop(1,'rgba(40,36,38,0)');c.fillStyle=g;c.fillRect(0,0,s,s);});
function smoke(pos,size,life=1.6){const s=new T.Sprite(new T.SpriteMaterial({map:smokeTexture,transparent:true,depthWrite:false,opacity:.8}));s.scale.setScalar(size*.5);s.position.copy(pos);scene.add(s);const rise=.6+Math.random()*.8;effect(s,life,(o,u,dt)=>{o.scale.setScalar(size*(.5+u));o.position.y+=dt*rise;o.material.opacity=.8*(1-u);});}
// Reze's explosions: white-hot core, orange fireball, ring, embers and smoke.
function explode(pos,radius=2,smoky=true){if(radius<3.6)for(let i=0;i<4;i++)puff(pos.clone().add(new T.Vector3((Math.random()-.5)*radius*.8,(Math.random()-.2)*radius*.6,(Math.random()-.5)*radius*.8)),radius*2.4,1.1,.55+Math.random()*.2,true);const core=glow(0xfff1d0,radius*1.2);core.position.copy(pos);effect(core,.25,(o,u)=>{o.scale.setScalar(radius*(1.2+u*2));o.material.opacity=1-u;});const ball=glow(colors.bomb,radius*2);ball.position.copy(pos);effect(ball,.5,(o,u)=>{o.scale.setScalar(radius*(2+u*2.5));o.material.opacity=(1-u)*.9;});
shockwave(pos.clone().setY(Math.max(.1,pos.y-radius*.5)),colors.bomb,radius*2.2);burst(pos,colors.bomb,Math.round(12+radius*8),4+radius*2);for(let i=0;smoky&&i<3+radius;i++)smoke(pos.clone().add(new T.Vector3((Math.random()-.5)*radius,Math.random()*radius*.5,(Math.random()-.5)*radius)),radius*1.6);}
function later(delay,fn){timers.push({at:time+delay,fn});}
// Knockback: targets fly on a simple ballistic arc, tumble, then walk back to their post.
function launch(t,velocity){if(t.hp<=0)return;t.vel=velocity.clone();}
// Decoded once after the deliberate Sound ON gesture. Images and WAV bytes also work offline.
const skillMedia=window.INFINITY_ASSETS||{icons:{},soundData:{}},skillBuffers=new Map(),skillVoices=new Set(),skillLoops=new Map();
let skillSoundLoad=null;
async function loadSkillSounds(){if(!skillSoundLoad)skillSoundLoad=Promise.all(Object.entries(skillMedia.soundData).map(async([id,data])=>{try{skillBuffers.set(id,await audio.decodeAudioData(skillMedia.bytes(data).buffer));}catch(error){console.warn('Skill sound could not be decoded:',id,error);}}));await skillSoundLoad;}
function stopSkillSound(tag){const voice=skillLoops.get(tag);if(voice){try{voice.source.stop();}catch{}voice.source.disconnect();voice.gain.disconnect();skillVoices.delete(voice);skillLoops.delete(tag);}}
function stopSkillSounds(){for(const voice of [...skillVoices]){try{voice.source.stop();}catch{}voice.source.disconnect();voice.gain.disconnect();}skillVoices.clear();skillLoops.clear();}
function playSkillSound(id,{loop=false,tag,rate=1,volume=.65}={}){const buffer=skillBuffers.get(id);if(!buffer)return;if(tag)stopSkillSound(tag);if(skillVoices.size>=20){const oldest=skillVoices.values().next().value;try{oldest.source.stop();}catch{}skillVoices.delete(oldest);}const source=audio.createBufferSource(),gain=audio.createGain(),voice={source,gain,tag};source.buffer=buffer;source.loop=loop;source.playbackRate.value=rate;gain.gain.value=volume;source.connect(gain);gain.connect(audio.destination);skillVoices.add(voice);if(tag)skillLoops.set(tag,voice);source.onended=()=>{source.disconnect();gain.disconnect();skillVoices.delete(voice);if(tag&&skillLoops.get(tag)===voice)skillLoops.delete(tag);};source.start();return voice;}
const skillArt={blue:'gojo_blue',red:'gojo_red',purple:'gojo_purple',domain:'gojo_domain',godspeed:'zenitsu_thunderclap',thunder:'zenitsu_thunderclap',god:'zenitsu_flamegod',rampage:'reze_rampage',dive:'reze_dive',kick:'reze_hand_blast',devil:'reze_transform',detonate:'reze_detonation',haki:'shanks_haki',engarde:'shanks_stance',shanksSlash:'shanks_slash',shanksParry:'shanks_parry',departure:'shanks_departure',dash:'shared_dash'};
function setSkillArt(button,key){const icon=button.querySelector('.skill-icon'),id=skillArt[key],url=skillMedia.icons[id];if(!url)return;if(icon.dataset.artId===id&&icon.firstElementChild?.tagName==='IMG')return;icon.className='skill-icon asset-icon';icon.dataset.artId=id;const img=document.createElement('img');img.src=url;img.alt='';img.draggable=false;icon.replaceChildren(img);}
function updateSkillArt(){for(const slot of SLOTS){let key=slotType(slot);if(char==='gojo'&&['q','e'].includes(slot)&&(cast?.type==='purple'||hold&&hold.kind!==key))key='purple';if(char==='reze'&&slot==='q'&&(rezeAirUntil>time||cast?.dive))key='dive';if(char==='shanks'&&slot==='e'&&['shanksSlash','shanksParry'].includes(cast?.type))key=cast.type;setSkillArt($(slot+'Btn'),key);}const choices=$('shanksChoices');if(choices){choices.hidden=char!=='shanks'||shanksReadyUntil<=time;choices.querySelector('output').textContent=Math.max(0,shanksReadyUntil-time).toFixed(1)+'초';}}
function startShanksParry(){if(char!=='shanks'||shanksReadyUntil<=time)return false;shanksReadyUntil=0;cast={type:'shanksParry',start:time,windup:0,duration:1,flags:{},direction:aimDir(),hit:false};title('패기 반격','칼을 일자로 세우고 웅크려 물러난다','1초 동안 공격을 무시 · 받아내면 오른쪽에서 왼쪽으로 쳐내고 찌르기','#ff5267');return true;}
const SOUND_ALIASES={dash:'shared_dash',rustle:'shared_rustle',gadget:'dora_gadget',light:'dora_light',air:'dora_air',bite:'dora_bite',rotor:'dora_rotor',door:'dora_door',snap:'gojo_snap',breath:'zenitsu_breath',crack:'shared_crack',boom:'shared_boom',slash:'shared_sword_swing_1'};
function sound(type,options={}){if(muted||!audio)return;const id=SOUND_ALIASES[type]||type;if(!skillMedia.soundData[id]){console.warn('Missing sound cue:',id);return;}return playSkillSound(id,options);}
function flash(color,power=.25){$('flash').style.background=color;let o={p:power};effects.push({object:null,born:time,life:.25,update:(_,t)=>$('flash').style.opacity=(1-t)*o.p});}
function toast(message){$('statusToast').textContent=message;toastUntil=time+2.4;}
function title(kicker,name,desc,color){$('castKicker').textContent=kicker;$('castName').textContent=name;$('castDescription').textContent=desc;$('castTitle').style.setProperty('--accent',color);$('castTitle').classList.add('active');}
function aimPoint(distance=18){const d=new T.Vector3(0,0,-1).applyEuler(new T.Euler(pitch,yaw,0,'YXZ'));return basePos.clone().addScaledVector(d,distance);}
function doraCannonWall(from,direction){for(let distance=.1;distance<=20;distance+=.1){const p=from.clone().addScaledVector(direction,distance);if(obstacles.some(o=>p.x>o.x0-.45&&p.x<o.x1+.45&&p.z>o.z0-.45&&p.z<o.z1+.45&&p.y<o.h))return {distance};}return null;}
function doraTarget(direction,range=42){let best=null,alongBest=Infinity;const origin=basePos.clone().add(new T.Vector3(0,1.3,0));for(const t of targets){if(t.hp<=0)continue;const delta=t.g.position.clone().add(new T.Vector3(0,1.5,0)).sub(origin),along=delta.dot(direction);if(along>0&&along<range&&delta.clone().addScaledVector(direction,-along).length()<4&&along<alongBest){best=t;alongBest=along;}}return best;}
function wallOnRay(from,direction,distance){for(let d=.25;d<=distance;d+=.25){const p=from.clone().addScaledVector(direction,d);if(obstacles.some(o=>p.x>o.x0&&p.x<o.x1&&p.z>o.z0&&p.z<o.z1&&p.y<o.h))return true;}return false;}
function nearestObstacleDistance(from,direction,distance){for(let d=.5;d<=distance;d+=.5){const p=from.clone().addScaledVector(direction,d);if(obstacles.some(o=>p.x>o.x0-1.1&&p.x<o.x1+1.1&&p.z>o.z0-1.1&&p.z<o.z1+1.1&&p.y<o.h))return Math.max(0,d-1.3);}return distance;}
function hit(t,damage,color='#d9f3ff'){if(t.hp<=0)return;if(char==='okkotsu')damage*=okkotsu?.damageFactor()??1;const dealt=Math.min(t.hp,damage);t.hp-=dealt;damageTotal+=dealt;$('totalDamage').textContent=Math.round(damageTotal).toLocaleString();t.bar.scale.x=t.hp/t.max;t.bar.position.x=-(1-t.hp/t.max)*.725;const el=document.createElement('div');el.className='damage-number';el.textContent=Math.round(dealt);el.style.color=color;$('damageLayer').append(el);popups.push({el,pos:t.g.position.clone().add(new T.Vector3(0,2.7,0)),born:time});burst(t.g.position.clone().add(new T.Vector3(0,1.6,0)),new T.Color(color),9,4);if(t.hp<=0){t.respawn=time+4;t.g.visible=false;toast('표적 격파 · 4초 후 재생성');}updateTargetCount();}
function updateTargetCount(){$('targetCount').textContent=targets.filter(t=>t.hp>0).length;}
function slotType(slot){let t=CHARS[char].slots[slot];if(char==='reze'&&slot==='r'&&time<devilUntil)t='detonate';return t;}
function startBasic(fromDemo=false){
  if(!fromDemo){demoStart=-1;commonDemo=-1;}
  if(char==='shanks'&&shanksReadyUntil>time){shanksReadyUntil=0;cast={type:'shanksSlash',start:time,windup:.25,duration:.8,flags:{},direction:aimDir()};title('赤髪の剣技','내지르기 · 사선 베기','살짝 떠오르며 전방으로 돌진','#ff5267');return true;}
  if(melee){if(melee.duration-(time-melee.start)<=.15)attackQueued=true;return false;}
  if(cast||hold||sliding||bombRecoil||time<rootUntil)return false;
  zenSkillGuard=null;
  const cfg=basicCfg();
  const chained=time<basicUntil;
  basicCombo=chained?basicCombo%cfg.windups.length+1:1;
  const alreadyDrawn=char==='zenitsu'&&time<zenDrawUntil+cfg.sheath;
  const i=basicCombo-1,w=alreadyDrawn?.08:cfg.windups[i],duration=w+cfg.swing+cfg.recoveries[i];
  melee={combo:basicCombo,draw:scabbard()&&!chained&&!alreadyDrawn,start:time,windup:w,swing:cfg.swing,duration,dir:aimDir(),hit:false};basicUntil=time+duration+cfg.comboReset;
  if(scabbard()){zenDrawUntil=basicUntil;zenGuardSign=basicCombo%2===1?-1:1;zenSheathSoundPlayed=false;if(melee.draw)sound('zenitsu_sheath',{rate:1.55,volume:.35});}
  toast((scabbard()?'기본 베기':'기본공격')+' · '+basicCombo+' / '+cfg.windups.length);return true;
}
function startSlide(direction=null,fromDemo=false){
  if(!fromDemo){demoStart=-1;commonDemo=-1;}
  if((cast&&cast.type!=='dash')||hold||melee||sliding||bombRecoil||jumpVelocity||time<rootUntil||time<slowUntil||time<slideCooldown||energy<6||basePos.y>2.15)return false;
  const d=direction?direction.clone():new T.Vector3((keys.has('KeyD')?1:0)-(keys.has('KeyA')?1:0),0,(keys.has('KeyS')?1:0)-(keys.has('KeyW')?1:0)).applyAxisAngle(UP,yaw);
  if(d.lengthSq()<.01){toast('이동 중 CTRL · 슬라이딩');return false;}
  if(cast?.type==='dash'){cast=null;$('castTitle').classList.remove('active');}d.normalize();energy-=6;slideCooldown=time+1.4;basicUntil=0;zenDrawUntil=0;sliding={start:time,dir:d,duration:COMMON.slideDuration,dust:0};sound('shared_slide_start');sound('shared_slide_scrape',{tag:'slideScrape',volume:.35});return true;
}
function startJump(){if(cast?.type==='dash'){cast=null;$('castTitle').classList.remove('active');}if(cast||hold||melee||bombRecoil||doraFlightActive||rezeAirVel||basePos.y>2.15||jumpVelocity)return false;jumpVelocity=7.7;sound('shared_jump');return true;}
// Sword basic attacks (Zenitsu, Shanks): two alternating cuts in one tilted vertical plane.
//  UP  (odd combos): a rising cut. The blade starts low and behind, pointing down-left, and sweeps up through the front to point up-right.
//  DN  (even combos): the blade turns over (flip) at the top, then chops down from the upper right to the lower left.
// The blade direction is an angle in that plane (theta), the hilt travels along a curve, and the blade rolls half a turn between the cuts.
const nrm=(x,y,z)=>new T.Vector3(x,y,z).normalize();
const CUT_AXIS=nrm(.42,.9,0),SIDE_AXIS=nrm(1,-.12,0),CUT_FWD=new T.Vector3(0,0,-1),rad=d=>d*Math.PI/180;
// UP / DN swing in the tilted vertical plane; MID is the flat horizontal cut across the middle, from the left to the right.
const SWORD_SWING={
  UP:{ax:CUT_AXIS,h:new T.CatmullRomCurve3([new T.Vector3(-.4,-.45,-.8),new T.Vector3(-.05,-.3,-.95),new T.Vector3(.4,-.05,-1)]),a:rad(-78),b:rad(72),r0:0,r1:.7},
  DN:{ax:CUT_AXIS,h:new T.CatmullRomCurve3([new T.Vector3(.44,0,-.82),new T.Vector3(.1,-.12,-.98),new T.Vector3(-.28,-.34,-.9)]),a:rad(130),b:rad(-18),r0:Math.PI,r1:Math.PI+.7},
  MID:{ax:SIDE_AXIS,h:new T.CatmullRomCurve3([new T.Vector3(-.4,-.1,-.62),new T.Vector3(0,-.06,-.84),new T.Vector3(.42,-.1,-.62)]),a:rad(-82),b:rad(78),r0:Math.PI,r1:Math.PI}
};
let swordPose=null;
// Combo order: Zenitsu cuts up, down, across, down; Shanks cuts up, down, across. Every cut ends where the next one starts.
const SWORD_ORDER={zenitsu:['UP','DN','MID','DN'],shanks:['UP','DN','MID','DN']};
const swordKind=combo=>{const o=SWORD_ORDER[char]||SWORD_ORDER.shanks;return o[(combo-1)%o.length];};
const bladeAt=(th,ax=CUT_AXIS)=>CUT_FWD.clone().multiplyScalar(Math.cos(th)).addScaledVector(ax,Math.sin(th)).normalize();
function swingAt(kind,u,pre=0){const k=SWORD_SWING[kind],th=k.a+(k.b-k.a)*u-Math.sign(k.b-k.a)*pre;return {pos:k.h.getPoint(u),dir:bladeAt(th,k.ax),len:1,roll:k.r0+(k.r1-k.r0)*u};}
function mixPose(p,q,t){return {pos:p.pos.clone().lerp(q.pos,t),dir:p.dir.clone().lerp(q.dir,t).normalize(),len:p.len+(q.len-p.len)*t,roll:p.roll+(q.roll-p.roll)*t};}
// Between two cuts: inside one plane the blade keeps turning the same way (so the flip is a real turn-over); across planes it just blends.
function swingBetween(kind,next,t,end,nxt){const k=SWORD_SWING[kind],n=SWORD_SWING[next];
  if(k.ax===n.ax){const th=k.b+(n.a-k.b)*t;return {pos:end.pos.clone().lerp(nxt.pos,t),dir:bladeAt(th,k.ax),len:1,roll:end.roll+(nxt.roll-end.roll)*t};}
  return mixPose(end,nxt,t);}
// One point of a cut: wind-up (a short pull-back), the cut itself, then the move into the next cut's start.
function swordSwingPose(kind,wind,strike,recovery,next){
  if(recovery>0){const end=swingAt(kind,1),nxt=swingAt(next,0);if(next==='UP')nxt.roll+=Math.PI*2;return swingBetween(kind,next,recovery,end,nxt);}
  const k=SWORD_SWING[kind],p=swingAt(kind,strike,.3*wind*(1-strike));p.pos.addScaledVector(k.h.getPoint(0).sub(k.h.getPoint(1)).normalize(),.1*wind*(1-strike));return p;}
function updateCommon(dt){swordPose=null;twoHandK=0;
  if(commonDemo>=0){
    const age=time-commonDemo,isZen=scabbard(),at=isZen?[.3,1.5,2.55,3.6,5.8]:[.3,.95,1.65,2.65],attacks=isZen?4:3;
    if(commonStage<at.length&&age>=at[commonStage]&&!melee&&!sliding){
      if(commonStage<attacks)startBasic(true);else startSlide(new T.Vector3(1,0,0),true);commonStage++;
    }
    if(age>(isZen?7.2:3.6)&&commonStage===at.length){commonDemo=-1;toast('기본공격 '+attacks+'연타 → 납도 → 슬라이딩 시연 완료');}
  }
  if(sliding){
    const c=sliding,a=time-c.start,u=clamp(a/c.duration,0,1),dip=ease(a/.12)*(1-ease((a-c.duration+.18)/.18));
    const speed=(12+(38-12)*(1-u)*(1-u))/3,next=basePos.clone().addScaledVector(c.dir,speed*dt);
    const blocked=obstacles.some(o=>basePos.y-1.7<o.h-.35&&next.x>o.x0-.55&&next.x<o.x1+.55&&next.z>o.z0-.55&&next.z<o.z1+.55);
    if(a>=c.duration||blocked||Math.hypot(next.x,next.z)>ARENA_R){sliding=null;stopSkillSound('slideScrape');sound('shared_slide_end');}
    else{
      basePos.copy(next);camera.position.copy(basePos);camera.position.y-=.65*dip;
      camera.rotation.x-=.05*dip;camera.rotation.z+=.045*dip;camera.fov=66+12*dip;
      pose(left,[-.5,-.65,-.72],[.4,.25,-.45]);pose(right,[.5,-.65,-.72],[.4,-.25,.45]);
      if(scabbard())zen.pos.y+=.15*dip;
      if(time>c.dust){c.dust=time+.08;smoke(basePos.clone().setY(.1).addScaledVector(c.dir,-.6),.45,.25);}
    }
  }
  if(melee){
    const c=melee,a=time-c.start,wind=ease(a/c.windup),strike=ease((a-c.windup)/c.swing),recovery=ease((a-c.windup-c.swing)/(c.duration-c.windup-c.swing)),sign=c.combo%2===0?-1:1;
    const guard=new T.Vector3(sign*.5,-.38,-.8),prep=new T.Vector3(sign*.7,c.combo===3?-.75:-.34,-.48),contact=new T.Vector3(sign*.06,c.combo===3?-.06:-.24,-1.52);
    const hand=guard.clone().lerp(prep,wind).lerp(contact,strike).lerp(guard,recovery);
    if(char==='gojo'||char==='reze')punchPose(c,wind,strike,recovery,a);
    else{
    if(char!=='zenitsu'){pose(c.combo===2?left:right,hand.toArray(),[-.2*strike,sign*(-.5*wind+.5*strike),sign*.12*(1-strike)]);pose(c.combo===2?right:left,[-sign*.48,-.4,-.8],[.1,0,0]);}
    camera.rotation.y+=sign*(-.04*wind+.09*strike)*(1-recovery);camera.rotation.z-=sign*.045*strike*(1-recovery);camera.fov=66-2*wind+6*strike*(1-recovery);
    }
    if(char==='zenitsu'||char==='shanks'){
      const kind=swordKind(c.combo),next=swordKind(c.combo+1),start=swingAt(kind,0);let sp;
      if(scabbard()&&c.draw&&a<c.windup){
        // Drawing from the scabbard: the hilt slides out along the saya axis while the blade is exposed, then the wrist brings it round to the first cut's start.
        const p=ease(a/(c.windup*.75)),turn=ease((a/c.windup-.55)/.45),out=zen.pos.clone().addScaledVector(zen.dir,.5*p);
        sp={pos:out.lerp(start.pos,turn),dir:zen.dir.clone().negate().normalize().lerp(start.dir,turn).normalize(),len:p,roll:start.roll*turn};
      }else sp=swordSwingPose(kind,wind,strike,recovery>0?recovery:0,next);
      if(scabbard())drawSword(sp.pos.toArray(),sp.dir.toArray(),sp.len,sp.roll||0);
      swordPose=sp;twoHandK=scabbard()&&c.draw?ease((a/c.windup-.6)/.4):1;
    }
    if(a>=c.windup&&!c.sound){c.sound=true;sound((char==='zenitsu'||char==='shanks'?'shared_sword_swing_':'shared_punch_swing_')+((c.combo-1)%3+1),{volume:.58,rate:char==='zenitsu'?.75:char==='shanks'?1.2:1});}
    if(a>=c.windup+c.swing*.5&&!c.hit){
      c.hit=true;const origin=basePos.clone(),ray=new T.Raycaster();let nearest=null,distance=Infinity;
      for(const t of targets){
        if(t.hp<=0)continue;const delta=t.g.position.clone().setY(1.5).sub(origin),along=delta.dot(c.dir);
        if(along<=0||along>(scabbard()?6:2.8)||delta.clone().addScaledVector(c.dir,-along).length()>(scabbard()?2.4:1.2)||delta.length()>=distance)continue;
        ray.set(origin,delta.clone().normalize());ray.far=delta.length();if(ray.intersectObjects(solidMeshes,false).length)continue;
        nearest=t;distance=delta.length();
      }
      if(char==='reze'&&time<devilUntil){
        const fist=nearest?nearest.g.position.clone().setY(1.4):origin.clone().addScaledVector(c.dir,1.9).add(new T.Vector3(0,-.1,0)),big=c.combo===3;
        explode(fist,big?1.15:.8);shockwave(fist.clone().setY(Math.max(.1,fist.y-.6)),colors.bomb,big?3:2);sound('shared_boom',{volume:big?.62:.48});hitstopUntil=Math.max(hitstopUntil,previous+(nearest?80:0));
        for(const t of targets){if(t.hp<=0||t===nearest)continue;if(t.g.position.clone().setY(1.3).distanceTo(fist)<(big?2.2:1.6)){hit(t,big?10:6,'#ffb27a');launch(t,c.dir.clone().setY(0).normalize().multiplyScalar(3).setY(4));}}
        if(nearest)hit(nearest,big?10:6,'#ffb27a');
      }
      if(nearest){
        hit(nearest,basicCfg().damage[c.combo-1]*(allmight?.basicFactor()??1),'#eaf4ff');burst(nearest.g.position.clone().setY(1.5),0xeaf4ff,12,3);sound(char==='zenitsu'||char==='shanks'?'shared_sword_hit':'shared_punch_hit_'+c.combo,{volume:.6});hitstopUntil=previous+65;
        if(c.combo===(scabbard()?4:3))launch(nearest,c.dir.clone().setY(0).normalize().multiplyScalar(8*(allmight?.knockFactor()??1)).setY(3));
      }
    }
    if(a>=c.duration){melee=null;if(attackQueued){attackQueued=false;startBasic(commonDemo>=0);}}
  }
  if(scabbard()&&!melee&&!cast&&thunderHoldAt<0&&zenDrawUntil>0&&time<zenDrawUntil+basicCfg().sheath){const sheathe=time<zenDrawUntil?0:ease((time-zenDrawUntil)/basicCfg().sheath),idleCut=zenSkillGuard||swingAt(swordKind(basicCombo+1),0),guard=idleCut.pos.clone(),guardDir=idleCut.dir.clone();const at=guard.lerp(zen.pos,sheathe),dir=guardDir.lerp(zen.dir.clone().negate(),sheathe).normalize();drawSword(at.toArray(),dir.toArray(),1-sheathe,idleCut.roll*(1-sheathe));twoHandK=1-ease(sheathe*2);if(sheathe>0&&!zenSheathSoundPlayed){zenSheathSoundPlayed=true;sound('zenitsu_sheath',{volume:.55});}}
  $('basicAttack').textContent=melee?'기본공격 '+melee.combo+' / '+(scabbard()?4:3):'기본공격 · 좌클릭';
  $('slide').textContent=sliding?'슬라이딩 중':slideCooldown>time?'슬라이딩 '+(slideCooldown-time).toFixed(1)+'초':'슬라이딩 · CTRL';
}
function startThunderHold(fromDemo=false){return startSkill('thunder',fromDemo);}
function releaseThunderHold(){return false;}
function startSkill(type,fromDemo=false,thunderCharge=null){if(type==='dash'&&sliding){sliding=null;stopSkillSound('slideScrape');}if(char==='okkotsu'&&!okkotsu.allow(type))return false;if(melee||sliding||bombRecoil||thunderHoldAt>=0){toast('현재 동작이 끝난 뒤 사용할 수 있어요');return false;}if(!fromDemo)commonDemo=-1;if(!fromDemo){demoStart=-1;$('demo').classList.remove('active');}const word=char==='gojo'?'술식':'기술';
if(type==='godspeed'&&godspeedUsed){toast('이번 생의 신속을 이미 사용했어요');return false;}
if(char==='shanks'&&type==='engarde'){if(shanksReadyUntil>time){toast('이미 자세를 잡았어요 · 좌클릭 / 우클릭');return false;}if(cooldowns.engarde>time||energy<costs.engarde){toast(cooldowns.engarde>time?'내지르기 / 반격 회복 중':'패기가 부족해요');return false;}energy-=costs.engarde;cooldowns.engarde=time+durations.engarde;shanksReadyUntil=time+3;title('赤髪の剣技','칼을 오른쪽으로 낮춘다','3초 안에 좌클릭 내지르기 · 우클릭 1초 반격','#ff5267');sound('shanks_draw');return true;}
if((type==='rampage'||type==='kick'||type==='detonate')&&time>=devilUntil){toast('변신 후 사용 가능 · R 폭탄의 악마');return false;}
if(type==='devil'&&time<devilUntil){toast('이미 폭탄의 악마 상태예요');return false;}
// Gojo: Blue and Red are held with an arm raised for up to 3s. Using the other one during the hold fuses both into
// Purple; using the same one again releases it at once; otherwise it releases by itself when the hold runs out.
if(hold&&(type==='blue'||type==='red')){if(cast){toast('현재 '+word+'이 끝난 뒤 사용할 수 있어요');return false;}
  if(type!==hold.kind){if(cooldowns[type]>time){toast(word+' 회복 중 · '+(cooldowns[type]-time).toFixed(1)+'초');return false;}if(energy<costs[type]){toast('주력이 회복될 때까지 잠시 기다려주세요');return false;}energy-=costs[type];cooldowns[type]=time+durations[type];}
  const kind=type===hold.kind?type:'purple';endHold();return beginCast(kind,false);}
if(hold&&type!=='dash'){toast('술식 대기 중 · Q / E로 발사하거나 합치세요');return false;}
// All Might: R may cut the smash's follow-through short once the fist has landed (E -> R).
if(cast&&allmight?.canCancel(type)){allmight.cancel(cast);cast=null;$('castTitle').classList.remove('active');$('scene').style.filter='';}
const rezeDive=type==='rampage'&&rezeAirUntil>time;if(cast&&!(rezeDive&&cast.type==='rampage'&&!cast.dive)){toast('현재 '+word+'이 끝난 뒤 사용할 수 있어요');return false;}if(rezeDive&&cast?.type==='rampage'){cast=null;$('castTitle').classList.remove('active');$('scene').style.filter='';}

if(type==='dash'&&time<slowUntil){toast('다리 반동 · 대시 불가 '+(slowUntil-time).toFixed(1)+'초');return false;}
const instant=false;
if(cooldowns[type]>time&&!rezeDive)return false;if(energy<costs[type])return false;energy-=costs[type];cooldowns[type]=time+durations[type];if(type==='godspeed')godspeedUsed=true;
if(hpCosts[type])hp=Math.max(1,hp-200*hpCosts[type]);
if(type==='blue'||type==='red'){hold={kind:type,start:time};const blue=type==='blue';title(blue?'CURSED TECHNIQUE · LAPSE':'CURSED TECHNIQUE · REVERSAL',(blue?'아오':'아카')+' · 대기','3초 안에 '+(blue?'E 아카':'Q 아오')+' → 무라사키 · '+(blue?'Q':'E')+' 다시 → 즉시 발사',blue?'#67ceff':'#ff7590');sound('gojo_blue_charge',{tag:'hold',rate:blue?1:.7,volume:blue?.5:.3});return true;}
if(scabbard())zenDrawUntil=0;return beginCast(type,instant,thunderCharge??THUNDER_MAX_CHARGE);}
function endHold(){stopSkillSound('hold');hold=null;holdGlow.visible=false;for(const h of [left,right])h.skin.emissive.set(0x000000);}
function beginCast(skill,instant,thunderCharge=THUNDER_MAX_CHARGE){const dive=skill==='rampage'&&rezeAirUntil>time;const windup=ZEN_RUSH[skill]?.windup??(skill==='god'?.6:skill==='devil'?1:skill==='rampage'?(dive?.05:.4):skill==='kick'?.2:skill==='detonate'?4:skill==='departure'?2.5:skill==='haki'?.5:skill==='pocket'?1.75:skill==='copter'?2.05:skill==='door'?2.3:0);cast={type:skill,dive,start:time,windup,thunderCharge,thunderEnhanced:skill==='thunder'&&instant,fuse:skill==='kick'?.8:0,duration:{blue:1.3,red:1,purple:1.7*PURPLE_SLOW,domain:2.4,dash:.28,breath:2,thunder:.79,godspeed:.47,god:.93,devil:windup+2,rampage:windup+.75,kick:windup+.8+.5,detonate:windup+1.6,haki:2,departure:3.1,pocket:2.2,copter:2.4,door:2.65,shanksSlash:.8,shanksParry:1}[skill]||windup,flags:{},direction:new T.Vector3(0,0,-1).applyEuler(new T.Euler(pitch,yaw,0,'YXZ')),point:aimPoint(19)};
if(skill==='dash'){const d=new T.Vector3((keys.has('KeyD')?1:0)-(keys.has('KeyA')?1:0),0,(keys.has('KeyS')?1:0)-(keys.has('KeyW')?1:0)).applyAxisAngle(UP,yaw);if(d.lengthSq()>.01)cast.direction.copy(d.normalize());}
if(kizaru?.skills.has(skill))kizaru.begin(cast);if(okkotsu?.skills.has(skill))okkotsu.begin(cast);if(pain?.skills.has(skill))pain.begin(cast);if(allmight?.skills.has(skill))allmight.begin(cast);
if(ZEN_RUSH[skill])title('雷の呼吸',skill==='god'?'화뢰신 · 火雷神':skill==='godspeed'?'벽력일섬 신속':'벽력일섬',skill==='godspeed'?'1회 · 이동속도 영구 −30%':skill==='god'?'뇌룡과 초고속 발도 · 반동 없음':'차징 없는 고정 발도','#ffd23f');
if(skill==='blue'){title('CURSED TECHNIQUE · LAPSE','술식 순전 · 아오','인력을 형성합니다.','#67ceff');}
if(skill==='red'){title('CURSED TECHNIQUE · REVERSAL','술식 반전 · 아카','응축된 척력을 전방으로 방출합니다.','#ff7590');}
if(skill==='purple'){blueUntil=0;if(blueOrb){dispose(blueOrb);blueOrb=null;}title('HOLLOW TECHNIQUE','허식 · 무라사키','순전과 반전. 두 힘을 하나로.','#caa2ff');cast.orbs=[orb(colors.blue,.34),orb(colors.red,.34)];sound('gojo_purple_charge',{tag:'castCharge'});}
if(skill==='domain'){title('DOMAIN EXPANSION','영역전개 · 무량공처','2초 시전 → 영역 속 표적 이동 허용 · 스킬 봉인 · 지속 피해','#cadbff');}
if(skill==='devil'){title('レゼ','쵸커의 핀','핀을 당긴다 · 머리가 폭발한다','#ff7a2e');}
if(skill==='rampage'){title('BOMB DEVIL',dive?'爆撃 · 내려찍기':'爆撃 · 상승','0.4초 웅크린 뒤 폭발 상승 · 공중에서 Q를 다시 눌러 내려찍기','#ff8a3d');}
if(skill==='kick'){sound('reze_fuse_loop',{loop:true,tag:'fuse',volume:.2});title('BOMB DEVIL','오른손 폭발','손을 앞으로 뻗고 0.8초 뒤 전방 3블럭에서 폭발','#ffa25a');}
if(skill==='detonate'){title('BOMB DEVIL','대폭발','4초 퓨즈 · 폭발 후 뒤로 튕겨 착지·슬라이딩','#ff3b1e');sound('reze_detonation_charge',{tag:'castCharge'});sound('reze_fuse_loop',{loop:true,tag:'fuse',volume:.22});}
if(skill==='pocket'){title('四次元ポケット','4차원 주머니','배의 흰 주머니를 벌리고 손을 넣어 뒤적입니다 · 도구 무작위 선택','#45b6e8');sound('breath');}
if(skill==='copter'){title('タケコプター','대나무 헬리콥터','주머니에서 꺼내 머리에 꽂는다 · 3초 비행','#45b6e8');sound('snap');}
if(skill==='door'){title('どこでもドア','어디로든 문','문을 펼쳐 열고 전방 24블록으로 이동','#f28b82');sound('snap');}
if(skill==='haki'){title('覇王色の覇気','패기 발현','0.5초간 붉은 번개 · 시야가 흐려진 뒤 반경 10칸을 두 번 압박','#ff334e');sound('shanks_haki_charge',{tag:'castCharge'});}
if(skill==='departure'){title('神避 · KAMUSARI','카무사리','칼을 뒤로 빼고 2.5초 기를 모은 뒤 · 폭 5칸 / 사거리 50칸 / 50 피해','#ff263f');sound('shanks_departure_charge',{tag:'castCharge'});}
if(skill==='dash'){sound('dash');}return true;}
function projectile(color,radius,damage,speed,start,direction){const p=orb(color,radius);p.position.copy(start);const damaged=new Set();effect(p,1.6,(o,u,dt)=>{const old=o.position.clone();o.position.addScaledVector(direction,speed*dt);o.rotation.z+=dt*3;const segment=new T.Line3(old,o.position);for(const target of targets){if(damaged.has(target)||target.hp<=0)continue;const p2=target.g.position.clone().add(new T.Vector3(0,1.5,0));if(segment.closestPointToPoint(p2,true,new T.Vector3()).distanceTo(p2)<radius+1.2){damaged.add(target);hit(target,damage,color===colors.purple?'#c5a0ff':'#ff8da4');shockwave(p2,color,4);if(color===colors.red)redImpact(p2,direction,target);}}if(Math.random()<.75)burst(o.position,color,2,1);if(color===colors.red&&Math.random()<.6)bolt(o.position,o.position.clone().add(new T.Vector3((Math.random()-.5)*2.4,(Math.random()-.5)*2.4,(Math.random()-.5)*2.4)),colors.red,.03,.14,0);});}
function endDomain(reason='expired'){if(!domain)return;const old=domain;domain=null;stopSkillSound('domainInside');dispose(old.group);for(const t of old.trapped)t.locked=false;sound(reason==='shattered'?'gojo_domain_break':'gojo_domain_end',{volume:.72});toast(reason==='shattered'?'기존 영역 파괴 · 나중에 전개한 영역 승리':'영역 해제');}
function createDomain(center,owner='player'){center.y=0;if(domain)endDomain('shattered');sound('gojo_domain_open');const group=new T.Group();scene.add(group);group.position.copy(center);const shader=new T.ShaderMaterial({uniforms:{t:{value:0},opacity:{value:0}},vertexShader:'varying vec3 vP; void main(){vP=position;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.);}',fragmentShader:`varying vec3 vP;uniform float t;uniform float opacity;float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}void main(){vec3 n=normalize(vP);vec2 uv=vec2(atan(n.z,n.x),asin(n.y));vec2 cell=floor(uv*160.);float stars=pow(hash(cell),110.);float lanes=pow(max(0.,sin(uv.x*32.+sin(uv.y*3.+t*.25))),18.);float curtain=lanes*(.1+.9*pow(max(0.,sin(uv.y*3.+t*.5)),4.));vec3 col=vec3(.008,.018,.038)+stars*vec3(.65,.8,1.)+curtain*vec3(.045,.12,.23);gl_FragColor=vec4(col,opacity);}`,transparent:true,side:T.BackSide,depthWrite:false});const dome=mesh(new T.SphereGeometry(26,64,32),shader,group);dome.position.y=1.5;const rings=[];for(let i=0;i<5;i++){const r=ring(7+i*4,0x88c6ff,new T.Vector3(0,.12+i*.025,0),.028,group);rings.push(r);}for(let i=0;i<32;i++){const a=i*Math.PI/16;const beam=box([.025,22,.025],[Math.sin(a)*25,8,Math.cos(a)*25],glowMat(0x77baff),group);beam.material.opacity=.32;}
const trapped=targets.filter(t=>t.hp>0&&t.g.position.distanceTo(center)<26);domain={group,dome,shader,rings,start:time,duration:7.5,center:center.clone(),lastTick:time,trapped,owner};for(const t of trapped)t.locked=true;shockwave(center.clone().add(new T.Vector3(0,.2,0)),0x94cfff,30);flash('#82a4e1',.3);toast('무량공처 · 영역 안의 표적 스킬 봉인');}
function updateCast(dt){castSword=null;if(!cast)return;const c=cast,a=time-c.start,p=a/c.duration;$('castProgress').style.width=clamp(p,0,1)*100+'%';if(c.kizaru)kizaru.update(c,a,dt);if(c.okkotsu)okkotsu.update(c,a,dt);if(c.pain)pain.update(c,a,dt);if(c.allmight)allmight.update(c,a,dt);
if(['pocket','copter','door'].includes(c.type)){
  if(c.type==='pocket'&&a>=.98&&!c.item){c.item=c.forcedItem||['small','cannon','dorayaki'][Math.floor(Math.random()*3)];sound('gadget');toast({small:'스몰라이트!',cannon:'공기포!',dorayaki:'단팥빵!'}[c.item]);}
  poseDora(c,a);
  if(c.type==='pocket'&&a>=c.windup&&!c.flags.use){c.flags.use=true;
    if(c.item==='dorayaki'){const healed=Math.min(20,200-hp);hp+=healed;toast('단팥빵 · 체력 +'+healed);sound('bite');flash('#ffe2b6',.08);}
    else{const dir=c.direction.clone().normalize(),t=doraTarget(dir),from=camera.localToWorld(doraItemProp.position.clone());
      if(c.item==='small'){sound('light');toast('스몰라이트 · 2초간 크기 -40% / 공격력 -30%');const to=t?t.g.position.clone().add(new T.Vector3(0,1.3,0)):from.clone().addScaledVector(dir,30),beam=mesh(new T.CylinderGeometry(.75,.04,from.distanceTo(to),24,1,true),new T.MeshBasicMaterial({color:0xfff3a2,transparent:true,opacity:.22,depthWrite:false}));beam.position.copy(from).lerp(to,.5);beam.quaternion.setFromUnitVectors(UP,to.clone().sub(from).normalize());effect(beam,.32,(o,u)=>o.material.opacity=.22*(1-u));if(t){t.g.scale.setScalar(.6);t.g.userData.doraSmallUntil=time+2;later(2,()=>{t.g.scale.setScalar(1);t.g.userData.doraSmallUntil=0;});}}
      else{sound('air');camera.position.addScaledVector(dir,-.08);const push=dir.clone().setY(0).normalize(),wall=t?doraCannonWall(t.g.position.clone().add(new T.Vector3(0,1,0)),push):null;toast('공기포 · '+(wall?'벽 충돌 피해 30':'피해 10')+' · 20블록 넉백');if(t){hit(t,10,'#d5f5ff');t.vel=null;t.g.rotation.x=0;const origin=t.g.position.clone(),distance=wall?Math.max(0,wall.distance-.6):20;t.g.userData.cannonUntil=time+.38;effect(null,.38,(_,u)=>{t.g.position.copy(origin).addScaledVector(push,distance*ease(u));t.g.position.y=origin.y+Math.sin(u*Math.PI)*.65;});later(.38,()=>{t.g.position.copy(origin).addScaledVector(push,distance);t.landed=time;if(wall){hit(t,20,'#e5faff');sound('air');}});}
        for(let i=0;i<4;i++){const ring=mesh(new T.TorusGeometry(.15+i*.04,.015,6,40),new T.MeshBasicMaterial({color:0xe5fbff,transparent:true,opacity:.7,depthWrite:false}));ring.position.copy(from);ring.quaternion.setFromUnitVectors(new T.Vector3(0,0,1),dir);effect(ring,.32+i*.04,(o,u)=>{o.position.copy(from).addScaledVector(dir,u*(12+i*2));o.scale.setScalar(1+u*5);o.material.opacity=.7*(1-u);});}}
    }
  }
  if(c.type==='copter'&&a>=c.windup&&!c.flags.flight){c.flags.flight=true;doraFlightStart=time;doraFlightBase=basePos.y;doraFlightVelocity=0;doraFlightActive=true;sound('rotor');toast('대나무 헬리콥터 · 3초 비행 · WASD 이동 / SPACE 상승 / CTRL 하강');}
  if(c.type==='door'){
    if(a>=1.45&&!c.door){c.door=makeAnywhereDoor();scene.add(c.door);const dir=c.direction.clone().setY(0).normalize();c.door.position.copy(basePos).addScaledVector(dir,2.2);c.door.position.y=basePos.y-2.1;c.door.rotation.y=yaw;c.door.scale.setScalar(.1);const door=c.door;effect(door,1.5,(o,u)=>{if(u>.75)o.traverse(p=>{if(p.material){p.material.transparent=true;p.material.opacity=1-ease((u-.75)/.25);}});});}
    if(c.door){c.door.scale.setScalar(.1+.9*ease((a-1.45)/.25));c.door.userData.hinge.rotation.y=-1.65*ease((a-1.72)/.4);doraItemProp.visible=false;}
    if(a>=c.windup&&!c.flags.open){c.flags.open=true;const dir=c.direction.clone().setY(0).normalize(),distance=nearestObstacleDistance(basePos,dir,24);basePos.addScaledVector(dir,distance);camera.position.copy(basePos);flash('#f6e8f0',.22);sound('door');toast('어디로든 문 · 전방 '+Math.round(distance)+'블록 이동');}
  }
}
if(c.type==='haki'){
  // 0-.5s: blur, the sword is raised. .5-2s: the sword sinks slowly to point at the ground while the haki erupts in two pulses.
  const k=ease(a/.5),lower=ease((a-.5)/1.5),shake=a>=.5&&a<2?(1-lower)*.012:0;
  camera.fov=66-5*k+3*Math.sin(clamp((a-.5)/.3,0,1)*Math.PI);
  if(!comfort)$('scene').style.filter=a<.5?`blur(${Math.sin(Math.min(1,a/.5)*Math.PI)*8}px)`:'';
  castSword={pos:new T.Vector3(.36+(Math.random()-.5)*shake,mix(-.28,-.34,k)+(Math.random()-.5)*shake,-.76),dir:hakiBladeDir(4,-80),roll:0,armsDown:true};camera.rotation.x-=.05*k*(1-lower*.6);
  const kick=a>=.5?Math.max(0,1-(a-(a<1.5?.5:1.5))/.45):0;if(kick>0){camera.rotation.x+=(Math.random()-.5)*.03*kick;camera.rotation.z+=(Math.random()-.5)*.04*kick;}
  if(a>.1&&a<2&&Math.random()<dt*(a<.5?30:55)){const side=Math.random()<.5?-1:1,tip=camPoint(new T.Vector3(side*(.3+Math.random()*.15),-.55,-.7));hakiBolt(tip,tip.clone().add(new T.Vector3(side*Math.random()*.7,.25+Math.random()*.8,-(Math.random()*.7))),.006+Math.random()*.006,.22,1);}
  if(a<.5&&Math.random()<dt*30){const from=camera.position.clone().add(new T.Vector3((Math.random()-.5)*1.5,(Math.random()-.5)*1.1,-1.2)),to=from.clone().add(new T.Vector3((Math.random()-.5)*.7,(Math.random()-.5)*.7,-1));hakiBolt(from,to,.02,.16,1);}
  if(a>=.5&&a<2&&time-(c.flags.floor||0)>.11){c.flags.floor=time;const ang=Math.random()*Math.PI*2,r=3+Math.random()*7,feet=basePos.clone().setY(.15);hakiBolt(feet.clone().add(new T.Vector3(Math.cos(ang),0,Math.sin(ang)).multiplyScalar(1.5)),feet.clone().add(new T.Vector3(Math.cos(ang)*r,.1,Math.sin(ang)*r)),.05,.3,1);}
  for(let i=0;i<2;i++){const at=.5+i;if(a>=at&&!c.flags['pulse'+i]){c.flags['pulse'+i]=true;flash('#ff263f',.18);sound('shanks_haki_pulse');shockwave(basePos.clone().setY(.1),colors.haki,10);shockwave(basePos.clone().setY(.14),0xffffff,6.5);burst(basePos.clone().add(new T.Vector3(0,1,0)),colors.haki,28,6);hakiStorm(basePos,10,i?14:10);for(const t of targets)if(t.hp>0&&t.g.position.distanceTo(basePos)<=10)hit(t,10,'#ff5267');}}
}
if(c.type==='departure'){
  // 0-2.5s: the sword is held up to the upper right and trembles while tri-colour lightning gathers on it. 2.5s: an overhead cut releases the beam.
  const k=ease(a/2.5),rel=ease((a-2.5)/.22),fin=ease((a-2.78)/.32);
  camera.fov=66-5*k+(a>=2.5?12*(1-fin):0);
  let pos,dir;
  if(a<2.5){pos=new T.Vector3(mix(.4,.36,k)+(Math.random()-.5)*.012*k,mix(-.38,0,k)+(Math.random()-.5)*.012*k,mix(-.6,-.55,k));dir=hakiBladeDir(mix(24,38,k),mix(8,58,k));}
  else{pos=new T.Vector3(mix(.36,.2,rel),mix(0,-.3,rel),mix(-.55,-.9,rel));dir=hakiBladeDir(mix(38,-2,rel),mix(58,-50,rel));}
  castSword={pos,dir,roll:0};
  if(fin>0){const idle={pos:new T.Vector3(.34,-.42,-.8),dir:hakiBladeDir(18,22),len:1,roll:0};const m=mixPose({...castSword,len:1},idle,fin);castSword={pos:m.pos,dir:m.dir,roll:0};}
  if(a<2.5&&Math.random()<dt*(10+110*k)){const s=.25+Math.random()*1,from=camPoint(pos.clone().addScaledVector(dir,s));hakiBolt(from,from.clone().add(new T.Vector3((Math.random()-.5)*(.6+k*2),(Math.random()-.3)*(.6+k*2),(Math.random()-.5)*(.6+k*2))),.012+.014*k,.2+.1*k,1);}
  if(k>.55&&a<2.5&&time-(c.flags.storm||0)>.4){c.flags.storm=time;hakiStorm(basePos,6+6*k,1+Math.round(k*3));}
  if(a<2.5&&a>0&&time-c.start>(c.flags.nextSpark||.06)){c.flags.nextSpark=time-c.start+.06;const forward=new T.Vector3(0,0,-1).applyQuaternion(camera.quaternion),side=new T.Vector3(1,0,0).applyQuaternion(camera.quaternion),up=new T.Vector3(0,1,0).applyQuaternion(camera.quaternion);for(let eye=-1;eye<=1;eye+=2){const seed=camera.position.clone().addScaledVector(forward,.75).addScaledVector(side,eye*.09).addScaledVector(up,.065);const end=seed.clone().addScaledVector(forward,.06+Math.random()*.06).addScaledVector(side,(Math.random()-.5)*.14).addScaledVector(up,(Math.random()-.5)*.1);hakiBolt(seed,end,.012,.13,1);}}
  if(a>=2.5&&a<3){const kick=1-(a-2.5)/.5;camera.rotation.x+=(Math.random()-.5)*.05*kick;camera.rotation.z+=(Math.random()-.5)*.06*kick;camera.position.y+=(Math.random()-.5)*.05*kick;}
  if(a>=2.5&&!c.flags.fire){c.flags.fire=true;const eye=basePos.clone().add(new T.Vector3(0,-.35,0)),from=basePos.clone().add(new T.Vector3(0,1.5,0)),dir=c.direction.clone().normalize(),to=from.clone().addScaledVector(dir,50),line=new T.Line3(from,to);
    kamusariBeam(eye,dir,50,2.5);hakiStorm(basePos,9,18);shockwave(basePos.clone().setY(.1),colors.haki,14);shockwave(basePos.clone().setY(.14),0xffffff,9);burst(eye.clone().addScaledVector(dir,3),0xffffff,40,10);burst(eye.clone().addScaledVector(dir,3),colors.haki,40,12);
    flash('#fff6f6',.12);setTimeout(()=>flash('#ff1838',.04),55);stopSkillSound('castCharge');sound('shanks_departure_release');
    for(const t of targets){if(t.hp<=0)continue;const q=t.g.position.clone().add(new T.Vector3(0,1.5,0));if(line.closestPointToPoint(q,true,new T.Vector3()).distanceTo(q)<=2.5&&q.distanceTo(from)<=50)hit(t,50,'#ff5267');}}
}
if(c.type==='shanksSlash'){
  // 0-.25s: the weight drops back and the sword is drawn to the upper right. .25-.43s: lunge forward and cut from the upper right to the lower left.
  const prep=ease(a/.25),sw=clamp((a-.25)/.18,0,1),rec=ease((a-.5)/.3);
  let pose=a<.25?swingAt('DN',0,.55*prep):swingAt('DN',ease(sw));
  if(a<.25){pose.pos.x+=.02*prep;pose.pos.y+=.05*prep;}
  if(rec>0)pose=mixPose(pose,{pos:new T.Vector3(.34,-.42,-.8),dir:hakiBladeDir(18,22),len:1,roll:0},rec);
  castSword={pos:pose.pos,dir:pose.dir,roll:pose.roll||0};
  const lunge=ease(clamp((a-.25)/.2,0,1)),done=c.flags.lunge||0;if(lunge>done){basePos.addScaledVector(c.direction.clone().setY(0).normalize(),8*(lunge-done));c.flags.lunge=lunge;}
  camera.fov=a<.25?66-4*prep:a<.43?mix(62,88,ease(sw)):mix(88,66,rec);
  camera.position.y+=-.2*prep*(1-sw)+Math.sin(sw*Math.PI)*.05;camera.rotation.x+=-.07*Math.sin(clamp((a-.2)/.35,0,1)*Math.PI);camera.rotation.z+=-.09*Math.sin(sw*Math.PI)+.03*prep*(1-sw);
  if(a>=.25&&!c.flags.cut){c.flags.cut=true;c.flags.start=basePos.clone();slashTrail('DN');sound('shanks_slash');flash('#ff5267',.16);}
  if(a>=.25&&a<.5&&Math.random()<dt*70){const x=(Math.random()-.5)*2.4,y=(Math.random()-.5)*1.4,from=camPoint(new T.Vector3(x,y,-6)),to=camPoint(new T.Vector3(x*1.1,y*1.1,-1.2));hakiBolt(from,to,.016,.16,0);}
  if(a>=.4&&!c.flags.hit){c.flags.hit=true;const end=basePos.clone(),start=c.flags.start?end.clone().addScaledVector(c.direction.clone().setY(0).normalize(),-8):end.clone();for(const t of targets){if(t.hp<=0)continue;const q=t.g.position.clone().add(new T.Vector3(0,1.5,0));if(new T.Line3(start,end).closestPointToPoint(q,true,new T.Vector3()).distanceTo(q)<3.5){hit(t,35,'#ff8792');burst(q,HAKI_RED,22,6);burst(q,0xffffff,14,7);hakiBolt(q.clone().add(new T.Vector3(-1.2,1.1,0)),q.clone().add(new T.Vector3(1.2,-1.1,0)),.08,.3,2);}}hitstopUntil=previous+70;}
}
if(c.type==='shanksParry'){
  // Guard: the sword is held upright and the body drops and slides back. If an attack lands inside the window: sweep it aside from right to left, then thrust forward.
  const settle=ease(a/.22),flat=c.direction.clone().setY(0).normalize();
  const backK=ease(a/.28);basePos.addScaledVector(flat,-1.3*(backK-(c.flags.back||0)));c.flags.back=backK;
  // Preview stand-in for an enemy strike: the nearest dummy lashes out part-way through the window, so the counter can be seen.
  if(!c.hit&&!c.flags.incoming&&a>=.4){const foe=targets.filter(t=>t.hp>0).sort((x,y)=>x.g.position.distanceTo(basePos)-y.g.position.distanceTo(basePos))[0];if(foe){c.flags.incoming=a;hakiBolt(foe.g.position.clone().setY(1.5),camera.position.clone().addScaledVector(c.direction,1.2),.07,.16,1);}}
  if(c.flags.incoming&&!c.hit&&a>=c.flags.incoming+.14)c.hit=true;
  if(c.hit&&c.flags.contactAt===undefined){c.flags.contactAt=a;c.duration=Math.max(c.duration,a+.62);sound('shanks_parry');flash('#ffffff',.3);hitstopUntil=previous+90;const tip=swordTipWorld({pos:new T.Vector3(.1,-.2,-.78),dir:hakiBladeDir(-30,40)},.9);burst(tip,0xffffff,26,7);burst(tip,HAKI_RED,18,6);for(let i=0;i<4;i++)hakiBolt(tip,tip.clone().add(new T.Vector3((Math.random()-.5)*2.4,(Math.random()-.2)*2,(Math.random()-.5)*2.4)),.03,.25,1);}
  const guard={pos:new T.Vector3(.3,-.28,-.72),dir:hakiBladeDir(12,72)};
  const tr=a<.9?(Math.random()-.5)*.004:0;
  let pos=guard.pos.clone().add(new T.Vector3(tr,tr,0)),dir=guard.dir.clone(),crouch=settle;
  if(c.flags.contactAt!==undefined){
    const u=a-c.flags.contactAt,swat=ease(u/.12),thrust=ease((u-.12)/.16),rec=ease((u-.32)/.3);
    crouch=1-ease(u/.14);
    pos=new T.Vector3(mix(.3,-.38,swat),mix(-.28,-.2,swat),mix(-.72,-.8,swat));dir=hakiBladeDir(mix(12,-72,swat),mix(72,12,swat));
    if(thrust>0){pos=new T.Vector3(mix(-.38,.04,thrust),mix(-.2,-.18,thrust),mix(-.8,-1.02,thrust));dir=hakiBladeDir(mix(-72,-2,thrust),mix(12,3,thrust));}
    if(rec>0){pos.lerp(new T.Vector3(.34,-.42,-.8),rec);dir=dir.lerp(hakiBladeDir(18,22),rec).normalize();}
    camera.fov=u<.12?66+(-3):mix(80,66,ease((u-.28)/.3));camera.rotation.x+=-.05*Math.sin(clamp((u-.1)/.25,0,1)*Math.PI);
    const lunge=thrust,done=c.flags.lunge||0;if(lunge>done){basePos.addScaledVector(flat,2.8*(lunge-done));c.flags.lunge=lunge;}
    if(u>=.12&&!c.flags.counter){c.flags.counter=true;sound('shanks_counter');flash('#ff5267',.3);slashTrail('SWAT');const at=basePos.clone().addScaledVector(c.direction,5);const t=targets.find(t=>t.hp>0&&t.g.position.distanceTo(at)<6);if(t){hit(t,45,'#ff5267');const q=t.g.position.clone().setY(1.5);burst(q,HAKI_RED,26,7);burst(q,0xffffff,18,8);hakiBolt(camera.position.clone().addScaledVector(c.direction,1.5),q,.06,.3,2);}}
  }else{camera.fov=66-3*settle;if(a>=.82)crouch*=1-ease((a-.82)/.18);}
  camera.position.y-=.34*crouch;
  castSword={pos,dir,roll:0};
  if(a>=c.duration&&!c.flags.done){c.flags.done=true;if(!c.hit)toast('반격 종료 · 공격을 받아내지 못했습니다');}
}
if(c.type==='blue'){right.g.position.set(.34,-.57,-1.05-.18*ease((a-.25)/.16));right.g.rotation.set(-.2,-.3,.05);right.skin.emissive.setHex(0x092c44);if(a>.43&&!c.flags.snap){c.flags.snap=true;sound('gojo_snap');blueUntil=time+1;
    const from=camPoint(new T.Vector3(.22,-.14,-1.1)),to=c.point.clone();to.y=Math.max(2.8,to.y);const dv=to.clone().sub(from);if(dv.length()>9)to.copy(from).addScaledVector(dv.normalize(),9);
    blueOrb=orb(colors.blue,.7);blueOrb.position.copy(from);blueOrb.scale.setScalar(.2);blueOrb.userData.fly={from,to,t0:time,dur:.6};burst(from,colors.blue,24,5);flash('#4db4ff',.1);}}
if(c.type==='red'){right.g.position.set(.1,-.2,-.67-ease(a/.55)*.25);right.skin.emissive.setHex(0x3f0714);
  if(a>.42&&!c.flags.fire){c.flags.fire=true;sound('gojo_red_release');const at=camPoint(new T.Vector3(.1,-.18,-1.4)),face=camera.position.clone().sub(at).normalize();projectile(colors.red,.9,65,32,basePos.clone().addScaledVector(c.direction,2),c.direction);flash('#ff506b',.2);
    shockRing(at,0xff365d,6,.45,.1,face);shockRing(at,0xffffff,3.5,.3,.1,face);burst(at,colors.red,40,9);for(let i=0;i<6;i++)bolt(at,at.clone().add(new T.Vector3((Math.random()-.5)*3,(Math.random()-.5)*3,(Math.random()-.5)*3)),colors.red,.04,.25,1);hitstopUntil=previous+60;}
  if(a>.42){const u=a-.42;camera.fov=mix(78,66,ease(u/.5));camera.position.addScaledVector(c.direction,-.3*Math.exp(-u*6));camera.rotation.x+=.05*Math.exp(-u*5);}
}
if(c.type==='purple'){const K=PURPLE_SLOW,s=ease(a/(.8*K)),angle=s*Math.PI*2;const circle=.45*(1-ease((a-.6*K)/(.4*K)));
  // Hands stay low at the sides so the two lights, not the sleeves, fill the view.
  for(const [i,hand]of [left,right].entries()){const side=i===0?-1:1;hand.g.position.set(side*(circle*Math.cos(angle)+.24),-.36+circle*.8*Math.sin(angle*side),-.82);hand.g.rotation.set(-.35,side*.35,side*angle*.2);const point=new T.Vector3(side*circle*Math.cos(angle)*5,.45+circle*Math.sin(angle*side)*4,-5).applyQuaternion(camera.quaternion).add(camera.position);if(c.orbs[i])c.orbs[i].position.copy(point);}
  camera.position.y+=Math.sin(clamp(a/c.duration,0,1)*Math.PI)*2.2*PURPLE_JUMP;
  const ahead=camera.position.clone().addScaledVector(c.direction,5);
  if(a>.5*K&&!c.flags.merge&&Math.random()<dt*(20+60*ease((a-.5*K)/(.45*K))))emberIn(ahead,7,Math.random()<.5?colors.blue:colors.red);
  if(a>.95*PURPLE_SLOW&&!c.flags.merge){c.flags.merge=true;for(const o of c.orbs)dispose(o);c.orbs=[];c.merged=orb(colors.purple,.82);c.merged.position.copy(ahead);burst(c.merged.position,colors.purple,90,10);flash('#a961ff',.35);shockRing(ahead,0xffffff,9,.5,.1,camera.position.clone().sub(ahead).normalize());}
  if(c.merged){c.merged.position.copy(ahead);const grow=ease((a-.95*K)/(.25*K));c.merged.scale.setScalar(1+1.1*grow+Math.sin(a*40)*.05*grow);if(Math.random()<dt*30)bolt(ahead.clone(),ahead.clone().add(new T.Vector3((Math.random()-.5)*4,(Math.random()-.5)*4,(Math.random()-.5)*4)),Math.random()<.4?0xffffff:colors.purple,.04,.2,1);camera.position.x+=(Math.random()-.5)*.03*grow;camera.position.y+=(Math.random()-.5)*.03*grow;}
  if(a>1.2*PURPLE_SLOW&&!c.flags.fire){c.flags.fire=true;stopSkillSound('castCharge');sound('gojo_purple_release');dispose(c.merged);c.merged=null;projectile(colors.purple,1.45,180,42,ahead.clone(),c.direction);
    shockwave(ahead,colors.purple,6);flash('#c593ff',.5);purpleBeam(camera.position.clone().addScaledVector(c.direction,3),c.direction,62,1.5);scorchLine(camera.position.clone().setY(0),c.direction,62);later(.22,()=>voidBlast(camera.position.clone().addScaledVector(c.direction,64).setY(1)));hitstopUntil=previous+90;}
  if(c.flags.fire){const u=a-1.2*K;camera.fov=mix(94,66,ease(u/.9));camera.position.addScaledVector(c.direction,-.55*Math.exp(-u*5));camera.rotation.x+=.09*Math.exp(-u*4);camera.rotation.z+=(Math.random()-.5)*.03*Math.exp(-u*3);}
}
if(c.type==='domain'){
  // 0-2s: both hands meet at the chest in the crossed-finger seal while blue light gathers and ripples spread over the floor; at 2s the sky shatters into the domain.
  const k=ease(a/.7),glowK=ease(a/2);
  left.g.position.set(mix(-.38,-.1,k),mix(-.48,-.2,k),mix(-.8,-.72,k));left.g.rotation.set(mix(.1,-.9,k),mix(.2,.4,k),mix(-.3,.3,k));
  right.g.position.set(mix(.38,.1,k),mix(-.42,-.17,k),mix(-.8,-.7,k));right.g.rotation.set(mix(.05,-.95,k),mix(-.25,-.4,k),mix(.3,-.3,k));
  holdGlow.visible=a<2;holdGlow.material.color.setHex(0x8fd2ff);holdGlow.position.set(0,-.08,-.8);holdGlow.scale.setScalar((.12+.5*glowK)*(1+Math.sin(a*30)*.12));
  const bl=Math.sin(Math.min(a/2,1)*Math.PI);if(!comfort)$('scene').style.filter='blur('+bl*1.6+'px)';camera.fov=66-ease(a/2)*10;camera.position.x+=(Math.random()-.5)*.012*glowK;camera.position.y+=(Math.random()-.5)*.012*glowK;
  if(a<2&&time-(c.flags.rip||0)>.4){c.flags.rip=time;shockRing(basePos.clone().setY(.1),0x88c6ff,10+4*glowK,1,.1);}
  if(a<2&&Math.random()<dt*(10+50*glowK))emberIn(basePos.clone().setY(1.2),6,0x9fd8ff);
  if(a>=2&&!c.flags.expand){c.flags.expand=true;holdGlow.visible=false;createDomain(basePos.clone().addScaledVector(c.direction,12));domainShatter();}
}
if(c.type==='dash'){basePos.addScaledVector(c.direction,dt*28);basePos.y=2.1;camera.fov=66+Math.sin(p*Math.PI)*12;}
if(ZEN_RUSH[c.type]){
const cfg=ZEN_RUSH[c.type],w=cfg.windup,fwd=c.direction.clone().setY(0).normalize();
if(a<w){const k=ease(a/w);camera.position.y-=.7*k;camera.rotation.x-=.12*k;zen.pos.set(-.48,-.88,-1.10);zen.dir.set(.78,.30,-.55).normalize();zen.glow=k;camera.fov=66-6*k;}
if(a>=w&&!c.flags.go){c.flags.go=true;c.from=basePos.clone();const distance=nearestObstacleDistance(c.from,fwd,cfg.distance);c.to=c.from.clone().addScaledVector(fwd,distance);const r=Math.hypot(c.to.x,c.to.z);if(r>ARENA_R)c.to.multiplyScalar(ARENA_R/r);c.to.y=2.1;
const path=new T.Line3(c.from.clone().setY(1.5),c.to.clone().setY(1.5));c.victims=targets.filter(t=>t.hp>0&&path.closestPointToPoint(t.g.position.clone().setY(1.5),true,new T.Vector3()).distanceTo(t.g.position.clone().setY(1.5))<3.2);
if(c.type==='god')dragon(c.from,c.to);bolt(c.from.clone().setY(.3),c.to.clone().setY(.3),colors.thunder,.08,.45,3);thunderAfterimage(c.from.clone().lerp(c.to,.4),fwd);sound(c.type==='god'?'zenitsu_flamegod':'zenitsu_thunderclap');flash('#fff1b0',.35);zenDrawUntil=time+cfg.travel+.15+2;zenSheathSoundPlayed=false;zenSkillGuard={pos:new T.Vector3(.08,-.24,-1.12),dir:new T.Vector3(-.55,.50,-.67).normalize(),roll:-.15};}
if(c.flags.go){const after=a-w,u=clamp(after/cfg.travel,0,1);basePos.lerpVectors(c.from,c.to,ease(u));camera.position.copy(basePos);const travel=clamp(after/cfg.travel,0,1),extract=ease(travel/.72),slash=ease((travel-.85)/.15);twoHandK=ease((travel-.65)/.20);zen.pos.set(-.48,-.88,-1.10);zen.dir.set(.78,.30,-.55).normalize();const extracted=zen.pos.clone().addScaledVector(zen.dir,1.48*extract),at=extracted.lerp(new T.Vector3(.08,-.24,-1.12),slash),dir=zen.dir.clone().negate().lerp(new T.Vector3(-.55,.50,-.67).normalize(),slash).normalize();drawSword(at.toArray(),dir.toArray(),extract,-.15*slash);zen.glow=1;camera.fov=72+20*(1-u);
if(after>=cfg.travel+(c.type==='god'?.18:0)&&!c.flags.hit){c.flags.hit=true;for(const t of c.victims)hit(t,cfg.damage,'#fff1a8');}}
}
if(c.type==='devil'){const w=c.windup;
  // Beats over the 1s windup: chin down while the right arm rises elbow-out to the choker (to .45), fingers hook the
  // ring and hold (.45-.62), a hard yank out to the right — ting (.62-.72), the empty socket fizzes, then the head goes off.
  const reach=ease((a-.04*w)/(w*.41)),pull=ease((a-w*.62)/(w*.1)),hooked=a>=w*.45&&a<w*.62,grabbed=a>=w*.62;
  if(!c.flags.boom){const tilt=ease(a/(w*.35));camera.rotation.x=pitch-.5*tilt;camera.fov=66-8*ease((a-w*.42)/(w*.2))+6*pull;
    choker.visible=true;choker.position.copy(basePos);choker.rotation.set(0,yaw,0);choker.updateMatrixWorld();camera.updateMatrixWorld();
    const size=mix(1,.62,reach);right.g.scale.setScalar(size);left.g.position.y-=.35*tilt;
    const ringLocal=camera.worldToLocal(chokerRing.getWorldPosition(new T.Vector3()));const atRing=ringLocal.sub(PIN_IN_HAND.clone().multiplyScalar(size).applyEuler(HOOK_ROT));
    const jitter=hooked?Math.sin(a*70)*.003:0,out=new T.Vector3(.56,-.2,-.62);
    const idle=new T.Vector3(.38,-.42,-.8),p=idle.lerp(atRing,reach).lerp(out,pull);right.g.position.set(p.x+jitter,p.y+jitter,p.z);
    right.g.rotation.set(mix(mix(.05,HOOK_ROT.x,reach),-.05,pull),mix(mix(-.25,HOOK_ROT.y,reach),-.3,pull),mix(mix(.3,HOOK_ROT.z,reach),.7,pull));
    chokerRing.visible=!grabbed;pin.visible=grabbed;if(grabbed){pin.position.copy(PIN_IN_HAND).multiplyScalar(size).applyQuaternion(right.g.quaternion).add(right.g.position);pin.quaternion.copy(right.g.quaternion);}
    else{chokerRing.rotation.set(0,0,hooked?Math.sin(a*50)*.15:0);}
    socket.visible=grabbed;if(grabbed){socket.material.opacity=.5+Math.random()*.5;socket.scale.setScalar(.04+Math.random()*.05);if(Math.random()<dt*30){const at=socket.getWorldPosition(new T.Vector3());bolt(at,at.clone().add(new T.Vector3((Math.random()-.5)*.08,.02+Math.random()*.06,(Math.random()-.5)*.08)),colors.bomb,.0025,.1,0,.03);}}
    if(hooked&&!c.flags.hook){c.flags.hook=true;sound('snap');}
    if(grabbed&&!c.flags.pin){c.flags.pin=true;sound('reze_pin');sound('reze_fuse_loop',{loop:true,tag:'fuse',volume:.24});}}
  if(grabbed&&!c.flags.boom&&Math.random()<dt*30)emberIn(basePos,4);
  if(a>=w&&!c.flags.boom){c.flags.boom=true;choker.visible=false;pin.visible=false;socket.visible=false;devilUntil=Infinity;cooldowns.devil=0;const healed=Math.max(0,Math.min(200,hp+40)-hp);hp+=healed;if(healed>0)toast('폭탄의 악마 · HP +'+Math.round(healed));const head=basePos.clone();explode(head.clone().add(new T.Vector3(0,.2,0)),3);transformBlast(head);impactFrame();for(let i=0;i<10;i++)smoke(head.clone().add(new T.Vector3((Math.random()-.5)*4,(Math.random()-.3)*2,(Math.random()-.5)*4)),2.5+Math.random()*2,2.6);stopSkillSound('fuse');sound('reze_transform');
    for(const t of targets){if(t.hp<=0)continue;const d=t.g.position.clone().sub(head).setY(0),dist=d.length();if(dist<9.5){const power=1-.35*dist/9.5;hit(t,90,'#ffb27a');launch(t,(dist>.1?d.normalize():flatForward()).multiplyScalar(24*power).setY(10*power));}}}
  // Her own head just went off: black, then sight slowly returns over two seconds.
  if(c.flags.boom){const after=a-w,dark=after<.3?1:1-ease((after-.3)/1.7);$('blackout').style.opacity=dark;if(!comfort){$('scene').style.filter=dark>.02?`blur(${dark*9}px)`:'';camera.position.x+=(Math.random()-.5)*.08*dark;camera.position.y+=(Math.random()-.5)*.08*dark;}
    if(after>=1.05&&!c.flags.reveal){c.flags.reveal=true;bigTitle('爆弾の悪魔','BOMB DEVIL');title('爆弾の悪魔','폭탄의 악마','변신 · 제한 시간 없음 · Q 상승/내려찍기 · E 오른손 폭발 · R 대폭발','#ff5a2e');}}}
if(c.type==='rampage'){const w=c.windup,fwd=flatForward();
  if(!c.dive){const crouch=ease(a/.4);left.g.position.set(-.48,-.48-.22*crouch,-.7);right.g.position.set(.48,-.44-.26*crouch,-.68);left.g.rotation.set(.3*crouch,0,-.2);right.g.rotation.set(.45*crouch,0,.24);camera.position.y-=.5*crouch;camera.fov=66-4*crouch;
    if(a>=w&&!c.flags.launch){c.flags.launch=true;rezeAirVel=19*Math.sqrt(REZE_LIFT);rezeAirDir=fwd.clone();rezeAirUntil=time+2*rezeAirVel/25;launchBlast(basePos.clone());fireDome(basePos.clone().setY(.2),3.4);rezeLookUntil=time+.2;emberBurst(basePos.clone().setY(.6),40,4,16);flash('#ffad67',.35);sound('reze_launch');}
    if(c.flags.launch){camera.fov=66+8*Math.sin(clamp((a-w)/.7,0,1)*Math.PI);if(Math.random()<dt*45)puff(basePos.clone().add(new T.Vector3((Math.random()-.5)*.8,-1.8,(Math.random()-.5)*.8)),2+Math.random()*1.4,-2,.9,true);if(Math.random()<dt*14)emberBurst(basePos.clone().setY(basePos.y-1.6),2,3,-1);if(a<w+1.6&&Math.random()<dt*70){const sp=glow(Math.random()<.5?EMBER:0xffe2a0,.1+Math.random()*.16);sp.position.copy(basePos).add(new T.Vector3((Math.random()-.5)*14,(Math.random()-.5)*10,(Math.random()-.5)*14));effect(sp,.7,(o,u)=>{o.material.opacity=1-u;});}}
  }else{left.g.position.set(-.45,-.42,-.65);right.g.position.set(.45,-.42,-.65);camera.fov=74;
    if(c.flags.dive&&!c.flags.slam){if(Math.random()<dt*50)puff(basePos.clone().add(new T.Vector3((Math.random()-.5)*1.4,2.6,(Math.random()-.5)*1.4)),2.4,3,.8,true);if(Math.random()<dt*45){const f0=basePos.clone().add(new T.Vector3((Math.random()-.5)*5,-2+Math.random()*5,(Math.random()-.5)*5));bolt(f0,f0.clone().add(new T.Vector3(0,7,0)),colors.bomb,.03,.14,0);}}
    if(a>=w&&!c.flags.dive){c.flags.dive=true;rezeAirUntil=0;rezeAirVel=-18;sound('reze_dive',{tag:'dive'});flash('#ffb36f',.2);}
    if(c.flags.dive&&basePos.y<=2.1&&!c.flags.slam){c.flags.slam=true;c.landTime=time;basePos.y=2.1;rezeAirVel=0;rezeLookUntil=time+.2;const at=basePos.clone().setY(.25);explode(at,4.6);shockwave(at,colors.bomb,12);slamBlast(at);for(const [col,hgt,life,reach] of [[0xff7a1f,4.5,.5,16],[0xffd24a,2.6,.36,11]]){const wall=new T.Mesh(new T.CylinderGeometry(1,1,hgt,48,1,true),new T.MeshBasicMaterial({color:col,transparent:true,opacity:.9,side:T.DoubleSide,depthWrite:false}));wall.position.set(at.x,hgt/2,at.z);scene.add(wall);effect(wall,life,(o,u)=>{const r=1+reach*ease(u);o.scale.set(r,1,r);o.material.opacity=.9*Math.pow(1-u,1.4);});}for(let k=0;k<7;k++)later(k*.05,()=>{const ang=k*Math.PI*2/7+Math.random()*.5,r=2.5+Math.random()*3;explode(new T.Vector3(at.x+Math.cos(ang)*r,.5,at.z+Math.sin(ang)*r),1.7);});hitstopUntil=previous+110;flash('#ffd0a0',.55);stopSkillSound('dive');sound('reze_slam');
      const p0=at.clone().add(new T.Vector3(-2.5,0,-2.5)),p1=at.clone().add(new T.Vector3(0,0,-5)),p2=at.clone().add(new T.Vector3(2.5,0,-2.5));bolt(p0,p1,colors.bomb,.12,.55,2);bolt(p1,p2,0xffedc9,.12,.55,2);
      for(const t of targets){if(t.hp<=0)continue;const d=t.g.position.clone().sub(at),flat=new T.Vector3(d.x,0,d.z);if(flat.length()<9){hit(t,65,'#ffb27a');launch(t,(flat.length()>.1?flat.normalize():flatForward()).multiplyScalar(8).setY(12));}}
    }
    if(c.flags.dive&&!c.flags.slam)camera.rotation.x=mix(pitch,-.58,ease((a-w)/.15));else if(c.flags.slam)camera.rotation.x=mix(-.58,pitch,ease((time-c.landTime)/.2));
  }}
if(c.type==='kick'){const k=ease(a/.2);right.g.position.set(.32,-.48+.42*k,-.82-.45*k);right.g.rotation.set(-.75*k,-.12,.22*k);left.g.position.set(-.42,-.5,-.8);left.g.rotation.set(.08,0,-.2);camera.fov=66-2*k;
  // The blast belongs to the extended hand: it goes off 3 blocks straight ahead of the palm (same sideways/vertical offset as the hand, along the view direction, pitch included).
  const hr=clamp(camera.aspect,.55,1),palmAt=()=>{camera.updateMatrixWorld(true);return camera.localToWorld(new T.Vector3(right.g.position.x*hr,right.g.position.y+.12,-3.2));};
  if(a<c.windup+c.fuse){const f=clamp((a-c.windup)/c.fuse,0,1);right.skin.emissive.setHex(f>0?0xff5a1e:0);right.skin.emissiveIntensity=.3+f*1.6;
    holdGlow.visible=a>c.windup*.6;holdGlow.material.color.setHex(colors.bomb);holdGlow.position.set(right.g.position.x,right.g.position.y+.14,right.g.position.z-.12);holdGlow.scale.setScalar((.12+.3*f)*(1+Math.sin(time*(26+40*f))*.18));
    if(f>0&&Math.random()<dt*(10+40*f)){const p=palmAt();burst(p.clone().addScaledVector(camera.getWorldDirection(new T.Vector3()),-1.4).add(new T.Vector3((Math.random()-.5)*.5,(Math.random()-.3)*.4,(Math.random()-.5)*.5)),colors.bomb,1,1.5);}}
  if(a>=c.windup+c.fuse-.5&&!c.flags.chev){c.flags.chev=true;const from=camera.localToWorld(new T.Vector3(right.g.position.x*hr,right.g.position.y+.12,-1.15)),to=palmAt(),d=to.clone().sub(from),len=d.length();d.normalize();
    // Arrowheads ">" fly out of the hand toward the blast point, one after another: -] > > > > BOOM
    // Screen-facing ">" marks, pointing along the hand-to-blast direction as seen from the eye (a head-on 3D arrowhead would read as a "+").
    const p0=from.clone().project(camera),p1=to.clone().project(camera),turn=new T.Quaternion().setFromAxisAngle(new T.Vector3(0,0,1),Math.atan2(p1.y-p0.y,(p1.x-p0.x)*camera.aspect));
    for(let i=0;i<5;i++)later(i*.09,()=>{const g=new T.Group();scene.add(g);g.position.copy(from).addScaledVector(d,len*(.16+.17*i));
      for(const sd of [-1,1]){const arm=mesh(new T.BoxGeometry(.34,.07,.04),glowMat(i%2?0xffe0b0:colors.bomb),g);arm.position.set(-.1,sd*.1,0);arm.rotation.z=-sd*.75;arm.castShadow=false;}
      const sc=.55+.08*i;effect(g,.2,(o,u)=>{o.quaternion.copy(camera.quaternion).multiply(turn);o.scale.setScalar(sc*(.85+.4*ease(u)));o.traverse(m=>{if(m.material)m.material.opacity=(u<.2?u/.2:1-(u-.2)/.8)*.95;});});sound('crack');});}
  if(a>=c.windup+c.fuse&&!c.flags.blast){c.flags.blast=true;holdGlow.visible=false;right.skin.emissiveIntensity=1;const fwd=flatForward(),at=palmAt(),hand=camera.localToWorld(new T.Vector3(right.g.position.x*hr,right.g.position.y+.12,-1.15));right.skin.emissive.setHex(0xff7a2e);explode(at,2.1);shockwave(at,colors.bomb,4.5);handBlast(at,fwd.clone().setY(0).lengthSq()?camera.getWorldDirection(new T.Vector3()):fwd);bolt(hand,at,0xffe5c4,.1,.35,2);flash('#ffb27a',.24);stopSkillSound('fuse');sound('reze_hand_blast');
    for(const t of targets){if(t.hp<=0)continue;const d=t.g.position.clone().add(new T.Vector3(0,1.3,0)).sub(at);if(d.length()<3.5){hit(t,55,'#ffb27a');launch(t,fwd.clone().multiplyScalar(7).setY(8));}}
  }}
if(c.type==='detonate'){const w=c.windup;
  // Fuse hair burns down for four seconds: hands clenched before the face, a pulsing danger ring, the view shudders harder.
  if(!c.flags.go){const k=a/w;left.g.position.set(-.16,-.28,-.68);left.g.rotation.set(.1,.7,-.5);right.g.position.set(.16,-.28,-.68);right.g.rotation.set(.1,-.7,.5);
    const still=a>w-.15?0:1;camera.fov=66-8*k-6*ease((a-(w-.4))/.4);camera.position.x+=(Math.random()-.5)*.14*k*k*still;camera.position.y+=(Math.random()-.5)*.14*k*k*still;
    if(!c.ring){const ring=ringMesh(12);c.ring=ring;}c.ring.position.set(basePos.x,.07,basePos.z);
    c.ring.material.opacity=.45+.4*Math.sin(a*(4+a*a*3));
    if(Math.random()<dt*(6+20*k)){const q=basePos.clone().add(new T.Vector3((Math.random()-.5)*1.5,.9+Math.random()*.6,(Math.random()-.5)*1.5));smoke(q,.9,1);burst(q,colors.bomb,2,2);}
    if(!c.crack&&a>.8)c.crack=crackNet(basePos,12);
    if(c.crack){const ck=ease((a-.8)/2.6),pulse=.55+.45*Math.sin(a*(5+a*5));for(const arm of c.crack.arms)for(const m of arm.children){m.visible=ck>m.userData.at;m.scale.z=clamp((ck-m.userData.at)*5.5,0,1);m.material.opacity=m.material.userData.o*(.4+.6*ck)*pulse;}}
    if(Math.random()<dt*(10+60*k))emberIn(basePos,10-4*k);
    if(a>1.6){if(!c.core){c.core=glow(0xff9a3a,.3);c.core2=glow(0xffffff,.2);c.core.material.depthTest=c.core2.material.depthTest=false;c.core.renderOrder=c.core2.renderOrder=110;}
      const ck=ease((a-1.6)/2.3),pu=1+.12*Math.sin(a*(14+ck*20)),at=camPoint(new T.Vector3(0,-.14,-.9));c.core.position.copy(at);c.core2.position.copy(at);c.core.scale.setScalar((.2+1.6*ck)*pu);c.core2.scale.setScalar((.1+.7*ck)*pu);}
    if(!comfort){const f=ease((a-1.5)/2.2);$('scene').style.filter='brightness('+(1-.4*f)+') saturate('+(1+.6*f)+') sepia('+.45*f+')';}
    const n=Math.ceil(w-a);if(n!==c.count){c.count=n;toast('폭발까지 '+n);sound('crack');}}
  if(a>=w&&!c.flags.go){c.flags.go=true;if(c.ring){dispose(c.ring);c.ring=null;}if(c.crack){dispose(c.crack.group);c.crack=null;}if(c.core){dispose(c.core);dispose(c.core2);c.core=c.core2=null;}const at=basePos.clone().setY(.8),R=12;
    explode(at,5);shockwave(at.clone().setY(.1),colors.bomb,R*1.3);flash('#ffffff',.95);hitstopUntil=previous+160;
    impactFrame();bigTitle('大爆発','FULL DETONATION','#ff5a1f',2200);fireDome(at,R);later(.12,()=>shockwave(at.clone().setY(.15),0xffffff,R*1.6));later(.3,()=>shockwave(at.clone().setY(.1),0xffb04a,R*2));
    const fw=flatForward(),fa=Math.atan2(fw.z,fw.x);for(let i=0;i<16;i++){const ang=i<11?fa+(Math.random()-.5)*2.2:Math.random()*Math.PI*2,d=7+Math.random()*(R-5);later(Math.random()*.45,()=>firePillar(at.x+Math.cos(ang)*d,at.z+Math.sin(ang)*d,.7+Math.random()*.8,16+Math.random()*12));}
    debrisBurst(at,R,46);mushroom(at.clone().addScaledVector(fw,16));scorch(at,R);sound('shared_boom',{volume:.9});stopSkillSound('fuse');stopSkillSound('castCharge');sound('reze_detonation_blast');
    for(let k=1;k<=16;k++)later(k*.06,()=>{const ang=Math.random()*Math.PI*2,d=Math.random()*R*.9;explode(new T.Vector3(at.x+Math.cos(ang)*d,.7,at.z+Math.sin(ang)*d),2.8,false);});
    for(const t of targets){if(t.hp<=0)continue;const d=t.g.position.clone().sub(at).setY(0),dist=d.length();if(dist<R){const power=1-.55*dist/R;hit(t,170,'#ffb27a');launch(t,(dist>.1?d.normalize():flatForward()).multiplyScalar(26*power).setY(14*power));}}
    // Back to human; the transformation can be used again after 20 seconds.
    devilUntil=0;cooldowns.devil=time+20;beginBombRecoil();toast('폭압 반동 → 뒤로 착지 · 슬라이딩 · 인간 복귀');}
  if(c.flags.go){const u=a-w,sh=Math.exp(-u*2.2);if(!bombRecoil&&u>.2)c.duration=a;camera.position.x+=(Math.random()-.5)*.5*sh;camera.position.y+=(Math.random()-.5)*.5*sh;camera.rotation.z+=(Math.random()-.5)*.08*sh;camera.rotation.x+=.22*Math.sin(clamp(u/1.2,0,1)*Math.PI);camera.fov=mix(96,66,ease(u/.9));
    if(!comfort)$('scene').style.filter=u<1.4?'brightness('+(.75+.25*ease(u/1.4))+') sepia('+.3*(1-ease(u/1.4))+')':'';
    if(u<1.2&&Math.random()<dt*14){const a2=Math.random()*Math.PI*2,r2=10+Math.random()*6;puff(basePos.clone().add(new T.Vector3(Math.cos(a2)*r2,.5+Math.random()*2,Math.sin(a2)*r2)),4+Math.random()*3,1.5,2,false);}}
}
if(a>=c.duration&&!(c.dive&&!c.flags.slam&&a<8)){boot.visible=false;if(c.ring)dispose(c.ring);if(c.crack)dispose(c.crack.group);if(c.core){dispose(c.core);dispose(c.core2);}if(c.type==='devil'){$('blackout').style.opacity=0;pin.visible=false;choker.visible=false;}if(c.orbs)for(const o of c.orbs)dispose(o);if(c.merged)dispose(c.merged);if(c.pain)pain.end(c);if(c.allmight)allmight.end(c);stopSkillSound('fuse');stopSkillSound('castCharge');cast=null;$('castTitle').classList.remove('active');$('scene').style.filter='';}}
function reset(){zenSkillGuard=null;godspeedUsed=false;kizaru?.reset();bombRecoil=null;pain?.reset();allmight?.reset();okkotsu?.reset();thunderHoldDemo=false;stopSkillSounds();document.body.classList.remove('pocket-peek');doraFlightVelocity=0;doraItemProp.visible=false;doraFlightStart=-1;doraFlightActive=false;doraFlightBase=0;rezeAirUntil=0;rezeAirVel=0;rezeAirDir.set(0,0,0);rezeLookUntil=0;melee=null;sliding=null;jumpVelocity=0;attackQueued=false;basicUntil=0;basicCombo=0;zenDrawUntil=0;zenSheathSoundPlayed=true;slideCooldown=0;commonDemo=-1;commonStage=0;if(cast?.ring)dispose(cast.ring);if(cast?.crack)dispose(cast.crack.group);if(cast?.core){dispose(cast.core);dispose(cast.core2);}boot.visible=false;kickCombo=null;cast?.orbs?.forEach(dispose);if(cast?.merged)dispose(cast.merged);cast=null;if(blueOrb)dispose(blueOrb);blueOrb=null;blueUntil=0;charges=0;chargesUntil=0;thunderHoldAt=-1;hp=200;slowUntil=0;hold=null;holdGlow.visible=false;devilUntil=0;for(const tr of trails)tr.grains.forEach(dispose);trails.length=0;timers.length=0;pin.visible=false;choker.visible=false;$('blackout').style.opacity=0;if(domain)dispose(domain.group);domain=null;for(const fx of effects)if(fx.object)dispose(fx.object);effects.length=0;for(const p of particles)dispose(p.object);particles.length=0;for(const p of popups)p.el.remove();popups.length=0;Object.keys(cooldowns).forEach(k=>cooldowns[k]=0);energy=100;damageTotal=0;$('totalDamage').textContent='0';for(const t of targets){t.hp=t.max;t.g.scale.setScalar(1);delete t.g.userData.doraSmallUntil;delete t.g.userData.cannonUntil;t.g.visible=true;t.g.position.copy(t.home);t.bar.scale.x=1;t.bar.position.x=0;t.locked=false;t.respawn=0;t.vel=null;t.landed=0;t.g.rotation.x=0;}rootUntil=0;basePos.set(0,2.1,13);yaw=0;pitch=-.015;$('castTitle').classList.remove('active');$('scene').style.filter='';$('flash').style.opacity=0;updateTargetCount();}

function setCharacter(next){if(!CHARS[next])return;if(cast||melee||sliding||bombRecoil){toast('현재 동작이 끝난 뒤 바꿀 수 있어요');return;}demoStart=-1;$('demo').classList.remove('active');const injury=godspeedUsed;char=next;reset();godspeedUsed=injury;kizaru?.activate(char==='kizaru');pain?.activate(char==='pain');okkotsu?.activate(char==='okkotsu');updateTargetCount();const C=CHARS[char];
document.body.dataset.char=char;$('injury').hidden=char!=='okkotsu';document.title='INFINITY / '+C.name+' · Skill Lab';$('charEyebrow').textContent=C.eyebrow;$('charName').innerHTML=C.name+'<span>'+C.kanji+'</span>';$('charDesc').innerHTML=C.desc;$('seal').textContent=C.seal;$('hudName').textContent=C.hud;$('energyLabel').textContent=C.energy;$('comboHint').innerHTML=C.hint;$('movesDemo').textContent=scabbard()?'발도 4연타 · 납도 시연':'기본공격 · 슬라이딩 시연';
for(const slot of SLOTS){const s=SKILLS[C.slots[slot]],b=$(slot+'Btn'),icon=b.querySelector('.skill-icon');b.style.setProperty('--accent',s.accent);icon.className='skill-icon '+s.icon;icon.textContent=s.glyph;b.querySelector('strong').textContent=s.name;b.querySelector('.skill-type').textContent=s.type;b.classList.remove('combo','locked');b.dataset.skill='';}
for(const b of document.querySelectorAll('.char-switch button'))b.classList.toggle('active',b.dataset.pick===char);
sword.g.visible=sword.hilt.visible=char==='zenitsu'||char==='shanks';left.g.visible=char!=='shanks';shanksReadyUntil=0;$('comboKey').textContent='E';$('comboText').textContent=' 연계 킥!';$('comboPrompt').classList.remove('on');devilShown=null;updateSkillArt();}
// Sleeves and Bomb Devil extras follow the character and transformation.
function applyLook(){for(const h of [left,right]){if(char==='gojo'||char==='zenitsu')h.palm.scale.set(.215/.17,.205/.17,.19/.085);else h.palm.scale.set(1,1,1);}left.fingers.visible=right.fingers.visible=char==='zenitsu';const devil=char==='reze'&&time<devilUntil;if(devil===devilShown)return;const was=devilShown;devilShown=devil;document.body.classList.toggle('devil',devil);devilHair.visible=devil;for(const h of [left,right]){h.fuse.visible=devil;h.sleeve.color.setHex(char==='zenitsu'?0xe0a526:char==='reze'?(devil?0x2a2628:0xe2bcaa):0x0c1323);}
if(char==='reze'){$('seal').textContent=devil?'爆':'レ';$('hudName').textContent=devil?'BOMB DEVIL':'REZE';if(!devil&&was===true)toast('변신 해제 · 궁극기 재사용 대기');}}
function faceNearestTarget(){const alive=targets.filter(t=>t.hp>0&&t.g.position.distanceTo(basePos.clone().setY(0))>3);if(!alive.length)return;alive.sort((x,y)=>x.g.position.distanceTo(basePos)-y.g.position.distanceTo(basePos));const d=alive[0].g.position.clone().sub(basePos);yaw=Math.atan2(-d.x,-d.z);pitch=-.015;}
$('basicAttack').onclick=()=>startBasic();$('slide').onclick=()=>startSlide();
$('movesDemo').onclick=()=>{reset();demoStart=-1;basePos.set(0,2.1,-7.5);yaw=0;pitch=-.015;commonDemo=time;commonStage=0;toast(char==='zenitsu'?'칼집에서 발도 → 좌우 4연타 → 납도 → 슬라이딩':'기본공격 3연타 → 슬라이딩 자동 시연');};
for(const slot of SLOTS)$(slot+'Btn').addEventListener('click',()=>{startSkill(slotType(slot));});
for(const b of document.querySelectorAll('.char-switch button'))b.onclick=()=>{setCharacter(b.dataset.pick);toast(CHARS[char].name+' 선택');};
$('injury').onclick=()=>{if(cast||melee||sliding)return;hp=100;toast('부상 상태 · Q 반전술식으로 회복해보세요');};
$('reset').onclick=()=>{demoStart=-1;$('demo').classList.remove('active');reset();toast('표적과 쿨타임을 초기화했습니다');};
$('demo').onclick=()=>{if(demoStart>=0){demoStart=-1;$('demo').classList.remove('active');return;}reset();if(CHARS[char].demoPos)basePos.set(...CHARS[char].demoPos);if(char==='okkotsu')hp=80;demoStart=time;demoStage=0;$('demo').classList.add('active');toast(CHARS[char].demoToast);};
$('sound').onclick=async()=>{if(!muted){muted=true;stopSkillSounds();$('sound').textContent='소리 OFF';return;}$('sound').disabled=true;$('sound').textContent='소리 준비 중';try{audio??=new (window.AudioContext||window.webkitAudioContext)();await audio.resume();await loadSkillSounds();muted=false;$('sound').textContent='소리 ON';sound(char==='gojo'?'gojo_snap':char==='zenitsu'?'zenitsu_sheath':char==='reze'?'reze_pin':char==='shanks'?'shanks_draw':'snap',{volume:.4});}catch(error){muted=true;$('sound').textContent='소리 OFF';toast('소리를 켜지 못했어요 · 다시 눌러주세요');}finally{$('sound').disabled=false;}};
document.addEventListener('visibilitychange',()=>{if(!audio)return;if(document.hidden)audio.suspend().catch(()=>{});else if(!muted)audio.resume().catch(()=>{});});
$('settings').onclick=()=>{comfort=!comfort;$('settings').textContent=comfort?'연출: 저자극':'연출: 기본';if(comfort)$('scene').style.filter='';};
window.addEventListener('keydown',e=>{if(e.repeat)return;keys.add(e.code);if(e.code==='ControlLeft'||e.code==='ControlRight'){e.preventDefault();if(!doraFlightActive)startSlide();return;}if(e.code==='Space'){e.preventDefault();if(!doraFlightActive){if(sliding){sliding=null;stopSkillSound('slideScrape');sound('shared_slide_end');}startJump();}return;}const pick={Digit1:'gojo',Digit2:'zenitsu',Digit3:'reze',Digit4:'shanks',Digit5:'doraemon',Digit6:'pain',Digit7:'allmight',Digit9:'kizaru',Digit8:'okkotsu'}[e.code];if(pick){setCharacter(pick);return;}const slot={KeyQ:'q',KeyE:'e',KeyR:'r',ShiftLeft:'shift',ShiftRight:'shift'}[e.code];if(slot){e.preventDefault();startSkill(slotType(slot));}});window.addEventListener('keyup',e=>{keys.delete(e.code);if(e.code==='KeyE')releaseThunderHold();});window.addEventListener('blur',()=>{keys.clear();dragging=false;releaseThunderHold();});
$('scene').addEventListener('contextmenu',e=>e.preventDefault());
$('scene').addEventListener('pointerdown',e=>{if(e.pointerType!=='touch'&&e.button===0){startBasic();return;}if(e.pointerType!=='touch'&&e.button===2){if(startShanksParry())return;dragging=true;lastPointer={x:e.clientX,y:e.clientY};$('scene').setPointerCapture(e.pointerId);return;}if(e.pointerType!=='touch')return;dragging=true;lastPointer={x:e.clientX,y:e.clientY};$('scene').setPointerCapture(e.pointerId);});
$('scene').addEventListener('pointermove',e=>{if(!dragging)return;yaw-=(e.clientX-lastPointer.x)*.003;pitch=clamp(pitch-(e.clientY-lastPointer.y)*.003,-1.1,1.1);lastPointer={x:e.clientX,y:e.clientY};});$('scene').addEventListener('pointerup',()=>dragging=false);
window.addEventListener('resize',()=>{camera.aspect=innerWidth/innerHeight;camera.updateProjectionMatrix();renderer.setSize(innerWidth,innerHeight);});

function aimAt(p){const d=p.clone().sub(basePos);yaw=Math.atan2(-d.x,-d.z);pitch=Math.atan2(d.y,Math.hypot(d.x,d.z));}
function aimDir(){return new T.Vector3(0,0,-1).applyEuler(new T.Euler(pitch,yaw,0,'YXZ'));}
let previous=performance.now(),paused=false,stepping=false;
function animate(now){if(!stepping)requestAnimationFrame(animate);if(paused&&!stepping)return;let dt=Math.min((now-previous)/1000,.05);previous=now;if(now<hitstopUntil)dt*=.06;time+=dt;
const movement=new T.Vector3((keys.has('KeyD')?1:0)-(keys.has('KeyA')?1:0),0,(keys.has('KeyS')?1:0)-(keys.has('KeyW')?1:0));const fuseProgress=cast?.type==='detonate'?clamp((time-cast.start)/cast.windup,0,1):0;if(!sliding&&!bombRecoil&&movement.lengthSq()){movement.normalize().applyAxisAngle(new T.Vector3(0,1,0),yaw);basePos.addScaledVector(movement,char==='okkotsu'?dt*(cast?.type==='pureLove'?1.5:cast?3.3:6):char==='pain'?dt*6*pain.speed():char==='allmight'?dt*6*allmight.speed():dt*(godspeedUsed?.7:1)*(thunderHoldAt>=0?0:cast&&cast.type!=='detonate'?2:6)*(time<slowUntil?.4:1)*(cast?.type==='detonate'?1-(1-fuseSlowFactor)*fuseProgress:1));document.body.classList.add('moving');}else document.body.classList.remove('moving');
document.body.classList.remove('pocket-peek');doraBody.visible=char==='doraemon';doraItemProp.visible=false;doraRotor.visible=char==='doraemon'&&doraFlightActive;doraRotor.position.copy(basePos).add(new T.Vector3(0,.22,.08).applyAxisAngle(UP,yaw));doraRotor.rotation.set(0,yaw,0);doraBody.position.copy(basePos);doraBody.rotation.set(0,yaw,0);doraBody.updateMatrixWorld();doraPouch.scale.z=1;
if(char==='doraemon'&&doraFlightActive){const age=time-doraFlightStart;if(age>=3){doraFlightActive=false;doraFlightVelocity=0;toast('대나무 헬리콥터 · 비행 종료');}else{basePos.y=clamp(basePos.y+dt*(age<.4?5:keys.has('Space')?5:keys.has('ControlLeft')||keys.has('ControlRight')?-5:0),2.1,14);doraRotor.userData.blades.rotation.y=time*45;if(Math.floor(age/.22)>Math.floor((age-dt)/.22))sound('rotor');}}
if(jumpVelocity){basePos.y+=jumpVelocity*dt;jumpVelocity-=18*dt;if(basePos.y<=2.1){basePos.y=2.1;jumpVelocity=0;sound('shared_land');}}
if(char==='doraemon'&&!doraFlightActive&&!jumpVelocity&&basePos.y>2.1){doraFlightVelocity-=dt*15;basePos.y=Math.max(2.1,basePos.y+doraFlightVelocity*dt);}
if(rezeAirVel){basePos.y+=rezeAirVel*dt;basePos.addScaledVector(rezeAirDir,12*dt);rezeAirVel-=25*dt;if(rezeAirVel<0&&basePos.y<=2.1&&!cast?.dive){basePos.y=2.1;rezeAirVel=0;rezeAirDir.set(0,0,0);}}if(Math.hypot(basePos.x,basePos.z)>ARENA_R){const l=ARENA_R/Math.hypot(basePos.x,basePos.z);basePos.x*=l;basePos.z*=l;}
moveBombRecoil(dt);camera.position.copy(basePos);camera.rotation.set(pitch,yaw,0,'YXZ');if(time<rezeLookUntil)camera.rotation.x=mix(-.58,pitch,ease(1-(rezeLookUntil-time)/.2));
// Recoil after the seventh form: knees buckle, the view sags and limps until the slow wears off.
if(time<slowUntil){const k=Math.min(1,(slowUntil-time)/.6);camera.position.y-=.28*k;camera.rotation.z=Math.sin(time*(movement.lengthSq()?7:2))*.025*k;}camera.fov=mix(camera.fov,66,dt*7);const bob=movement.lengthSq()?Math.sin(time*10)*.012:Math.sin(time*1.9)*.008;if(!scabbard()){if(char==='gojo'){pose(left,[-.61,-.60,-1.03],[.12,.12,-.08]);pose(right,[.61,-.57,-1.03],[.12,-.12,.08]);}else{pose(left,[-.38,-.48+bob,-.8],[.1,.2,-.3]);pose(right,[.38,-.42-bob,-.8],[.05,-.25,.3]);}left.g.visible=char!=='pain'&&char!=='allmight'&&char!=='okkotsu';right.g.visible=char!=='pain'&&char!=='allmight'&&char!=='okkotsu';}else{poseZen(bob);right.g.visible=true;}
if(thunderHoldAt>=0&&time-thunderHoldAt>=THUNDER_MAX_CHARGE)releaseThunderHold();
for(const h of [left,right]){h.skin.depthTest=char==='doraemon';h.sleeve.depthTest=char==='doraemon';}updateCast(dt);updateCommon(dt);poseBombRecoil();applyLook();if(char==='reze'&&time<devilUntil&&Math.random()<dt*7)devilAmbient();
  {const dv=char==='reze'&&time<devilUntil;devilVignette.style.opacity=dv?String(.85+.15*Math.sin(time*2.5)):'0';
   if(dv&&!cast){const pu=.5+.5*Math.sin(time*3);for(const h of [left,right]){h.skin.emissive.setHex(0x5a1800);h.skin.emissiveIntensity=.35+.5*pu;}}
   if(previous<impactUntil){$('scene').style.filter='invert(1) contrast(1.6)';impactOn=true;}else if(impactOn){impactOn=false;$('scene').style.filter='';}}pain?.frame(dt,movement.lengthSq()>0);allmight?.frame(dt,movement.lengthSq()>0);okkotsu?.frame(dt,movement.lengthSq()>0);kizaru?.frame(dt);
// Hold: Blue raises the right arm, Red the left, with the technique gathering in the palm.
if(hold){const blue=hold.kind==='blue',h=blue?right:left,side=blue?1:-1,u=time-hold.start,k=ease(u/.25);if(blue){h.g.position.set(.34,-.57,-1.05);h.g.rotation.set(-.2,-.3,.05);}else{h.g.position.set(side*.3,-.42+.3*k,-.8+.06*k);h.g.rotation.set(.35*k,0,side*(.3-.22*k));}h.skin.emissive.setHex(blue?0x0a3a5a:0x4a0a18);
  holdGlow.visible=true;holdGlow.material.color.setHex(blue?colors.blue:colors.red);holdGlow.position.copy(h.g.position).add(new T.Vector3(0,.16,0));holdGlow.scale.setScalar((.3+.15*k)*(1+Math.sin(time*14)*.08));
  $('castTitle').classList.add('active');$('castProgress').style.width=clamp(u/3,0,1)*100+'%';
  if(u>=3&&!cast){const kind=hold.kind;endHold();beginCast(kind,false);}}if(char==='zenitsu'&&thunderHoldAt>=0){const u=clamp((time-thunderHoldAt)/THUNDER_MAX_CHARGE,0,1);zen.pos.y-=.09+.08*u;zen.pos.z+=.1*u;zen.push=.07*u;zen.glow=.4+.6*u;camera.position.y-=.4+.2*u;camera.rotation.x-=.1*u;camera.fov=66-6*u;document.getElementById("castProgress").style.width=(u*100)+'%';if(Math.random()<dt*(12+u*22)){const at=basePos.clone().addScaledVector(flatForward(),2).setY(.05);bolt(at,at.clone().add(new T.Vector3((Math.random()-.5)*.6,1+u,0)),colors.thunder,.02,.15,0);}}left.cuff.visible=right.cuff.visible=!scabbard();if(char==='shanks'&&castSword)applyShanks();else if(scabbard())applyZen();const handRatio=clamp(camera.aspect,.55,1);holdGlow.position.x*=handRatio;for(const o of [left.g,right.g,sword.g,sword.hilt]){if(o===right.g&&cast?.type==='devil'&&!cast.flags.boom)continue;if(char==='doraemon'&&cast&&['pocket','copter','door'].includes(cast.type))continue;o.position.x*=handRatio;o.scale.setScalar(mix(.78,1,handRatio)*(scabbard()&&(o===left.g||o===right.g)?.62:1));}camera.updateProjectionMatrix();
if(blueOrb){if(time>blueUntil){burst(blueOrb.position,colors.blue,15,3);dispose(blueOrb);blueOrb=null;}else{blueOrb.rotation.y+=dt*1.7;blueOrb.rotation.z+=dt*.7;
    const fl=blueOrb.userData.fly;
    if(fl){const u=clamp((time-fl.t0)/fl.dur,0,1),e=1-Math.pow(1-u,3);blueOrb.position.lerpVectors(fl.from,fl.to,e);blueOrb.scale.setScalar(.25+1.0*ease(u));
      if(Math.random()<dt*70){const p=glow(colors.blue,.2+Math.random()*.2);p.position.copy(blueOrb.position).add(new T.Vector3((Math.random()-.5)*.4,(Math.random()-.5)*.4,(Math.random()-.5)*.4));effect(p,.35,(o,k)=>{o.material.opacity=1-k;});}
      if(u>=1){blueOrb.userData.fly=null;blueOrb.userData.arrived=time;const at=blueOrb.position.clone();sound('gojo_blue_pull');flash('#4db4ff',.16);burst(at,colors.blue,50,8);
        for(let i=0;i<4;i++)later(i*.16,()=>{const m=ring(.3,colors.blue,at,.03),face=camera.position.clone().sub(at).normalize();m.quaternion.setFromUnitVectors(BACK,face);effect(m,.7,(o,k)=>{o.scale.setScalar(mix(34,3,ease(k)));o.material.opacity=.15+.75*ease(k);});});}}
    else blueOrb.scale.setScalar(1+Math.sin(time*9)*.04);
    if(Math.random()<(blueOrb.userData.arrived&&time-blueOrb.userData.arrived<1.6?.9:.3)){const p=glow(colors.blue,.15);const v=new T.Vector3(Math.random()-.5,Math.random()-.5,Math.random()-.5).normalize().multiplyScalar(4+Math.random()*3);const destination=blueOrb.position.clone();p.position.copy(destination).add(v);effect(p,.5,(o,u)=>{o.position.lerp(destination,u*.3);o.material.opacity=1-u;});}for(const t of targets){if(t.hp<=0)continue;const d=blueOrb.position.clone().sub(t.g.position);d.y=0;if(!blueOrb.userData.fly&&d.length()<11&&d.length()>1.5)t.g.position.addScaledVector(d.normalize(),dt*1.5);}if(!cast){right.skin.emissive.setHex(0x052030);}}}
if(domain){const d=domain,a=time-d.start;if(Math.random()<dt*9)domainMote();const inside=basePos.distanceTo(d.center)<26;if(inside&&!skillLoops.has('domainInside'))sound('gojo_domain_inside',{loop:true,tag:'domainInside',volume:.24});else if(!inside)stopSkillSound('domainInside');d.shader.uniforms.t.value=a;d.shader.uniforms.opacity.value=ease(a/.7)*(1-ease((a-d.duration+1)));d.group.scale.setScalar(.01+.99*ease(a/.8));d.rings.forEach((r,i)=>r.material.opacity=(.25+Math.sin(time*2+i)*.12)*(1-ease(a-d.duration+1)));if(time-d.lastTick>.5){d.lastTick=time;for(const t of d.trapped)if(t.hp>0)hit(t,8,'#9ccfff');}if(a>d.duration)endDomain('expired');}
for(let i=timers.length-1;i>=0;i--)if(time>=timers[i].at){const fn=timers[i].fn;timers.splice(i,1);fn();}
for(let i=trails.length-1;i>=0;i--){const tr=trails[i];if(time<tr.at){for(const g of tr.grains)g.children[1]&&(g.children[1].material.opacity=.5+Math.random()*.5);continue;}trails.splice(i,1);
  const path=new T.Line3(tr.from,tr.to);for(const t of targets){if(t.hp<=0)continue;const p2=t.g.position.clone().setY(1.5);if(path.closestPointToPoint(p2,true,new T.Vector3()).distanceTo(p2)<2.6){hit(t,35,'#ffb27a');launch(t,new T.Vector3(0,9,0));}}
  sound('boom');tr.grains.forEach((g,k)=>later(k*.025,()=>{const at=g.position.clone();dispose(g);if(k%2===0)explode(at.setY(.5),1.1);}));}
if(char==='reze'&&time<devilUntil){for(const [i,tip] of hairTips.entries())tip.material.opacity=.6+Math.random()*.4;devilHair.position.y=Math.sin(time*2)*.008;for(const h of [left,right])h.ember.material.opacity=.6+Math.random()*.4;}
for(const t of targets){if(t.vel){t.g.position.addScaledVector(t.vel,dt);t.vel.y-=25*dt;t.g.rotation.x-=dt*7;const r=Math.hypot(t.g.position.x,t.g.position.z);if(r>ARENA_R){t.g.position.x*=ARENA_R/r;t.g.position.z*=ARENA_R/r;}if(t.g.position.y<=0&&t.vel.y<0){t.g.position.y=0;t.vel=null;t.g.rotation.x=0;t.landed=time;shockwave(t.g.position.clone().setY(.1),0x8a7a70,1.5);}}
  else if(t.landed&&t.hp>0&&!t.locked&&time>t.landed+1.5){const back=t.home.clone().sub(t.g.position).setY(0);if(back.length()>.3)t.g.position.addScaledVector(back.normalize(),Math.min(back.length(),dt*2.5));else t.landed=0;}}
for(const t of targets){if(t.hp<=0&&time>=t.respawn){t.hp=t.max;t.g.visible=true;t.g.position.copy(t.home);t.bar.scale.x=1;t.bar.position.x=0;updateTargetCount();}if(t.hp>0){t.g.rotation.y=Math.sin(time*.6+t.index)*.08;if((t.g.userData.cannonUntil||0)<time)t.g.position.x+=Math.sin(time*.8+t.index)*dt*.12;}}
for(let i=effects.length-1;i>=0;i--){const e=effects[i],age=(time-e.born)/e.life;if(age>=1){if(e.object)dispose(e.object);else $('flash').style.opacity=0;effects.splice(i,1);}else e.update?.(e.object,age,dt);}
for(let i=particles.length-1;i>=0;i--){const p=particles[i],age=(time-p.born)/p.life;if(age>=1){dispose(p.object);particles.splice(i,1);}else{p.object.position.addScaledVector(p.v,dt);p.v.y-=dt*2;p.object.material.opacity=(1-age);}}
for(let i=popups.length-1;i>=0;i--){const p=popups[i],a=time-p.born;if(a>1){p.el.remove();popups.splice(i,1);continue;}const v=p.pos.clone();v.y+=a*1.2;v.project(camera);p.el.style.left=(v.x*.5+.5)*innerWidth+'px';p.el.style.top=(-v.y*.5+.5)*innerHeight+'px';p.el.style.opacity=v.z>1?'0':1-a;}
$('hpText').textContent=hp+' / 200';$('hpBar').style.width=hp/2+'%';const slow=slowUntil-time,devilLeft=char==='reze'?devilUntil-time:0;$('debuff').classList.toggle('on',slow>0||char==='reze'||char==='doraemon');if(slow>0)$('debuff').textContent='반동 · 이동 속도 -60% · 대시 불가 '+slow.toFixed(1)+'초';else if(char==='doraemon')$('debuff').textContent=doraFlightActive?'대나무 헬리콥터 · 비행 '+Math.max(0,3-(time-doraFlightStart)).toFixed(1)+'초':cooldowns.pocket>time?'4차원 주머니 · 다음 도구까지 '+(cooldowns.pocket-time).toFixed(1)+'초':'4차원 주머니 · Q 무작위 도구';else if(char==='reze')$('debuff').textContent=bombRecoil?(bombRecoil.phase==='air'?'폭압 반동 · 뒤로 튕겨나는 중':'폭압 반동 · 착지 슬라이딩 후 자세 회복'):devilLeft>0?'폭탄의 악마 · 무제한 · Q 상승/내려찍기 · E 오른손 폭발 · R 대폭발':cooldowns.devil>time?'인간 · 폭탄의 악마 재사용 '+(cooldowns.devil-time).toFixed(1)+'초':'인간 · 기본공격·슬라이딩·대시 / R 변신';
energy=Math.min(100,energy+dt*5);$('energyBar').style.width=energy+'%';$('energyText').textContent=Math.floor(energy)+'%';$('statusToast').style.opacity=time<toastUntil?1:0;
const eBtn=$('eBtn'),eName=eBtn.querySelector('strong'),eHint=eBtn.querySelector('.skill-type');const charged=char==='zenitsu'&&charges>0&&chargesUntil>time;
if(char==='gojo'){for(const [b,kind,base,baseHint] of [[$('qBtn'),'blue','아오','인력 / 3초 대기'],[eBtn,'red','아카','척력 / 3초 대기']]){const held=hold&&hold.kind===kind,fuse=hold&&hold.kind!==kind;b.classList.toggle('combo',!!fuse);b.querySelector('strong').textContent=fuse?'무라사키':held?base+' 발사':base;b.querySelector('.skill-type').textContent=held?'다시 눌러 즉시 · '+Math.max(0,3-(time-hold.start)).toFixed(1)+'초':fuse?'합쳐서 발사':baseHint;}}
else if(char==='reze'){const kc=Math.max(0,rezeAirUntil-time);eBtn.classList.remove('combo');eName.textContent='오른손 폭발';eHint.textContent='손을 뻗고 0.8초 · 전방 3블럭';$('comboPrompt').classList.remove('on');$('qBtn').querySelector('strong').textContent=kc>0?'내려찍기':'상승 폭발';$('qBtn').querySelector('.skill-type').textContent=kc>0?'공중 재입력 · '+kc.toFixed(1)+'초':'웅크림 0.4초';for(const slot of ['q','e'])$(slot+'Btn').classList.toggle('locked',time>=devilUntil);const rb=$('rBtn'),sk=SKILLS[slotType('r')];if(rb.dataset.skill!==slotType('r')){rb.dataset.skill=slotType('r');rb.style.setProperty('--accent',sk.accent);const ic=rb.querySelector('.skill-icon');ic.className='skill-icon '+sk.icon;ic.textContent=sk.glyph;rb.querySelector('strong').textContent=sk.name;rb.querySelector('.skill-type').textContent=sk.type;}}
else if(char==='doraemon'){eBtn.classList.remove('combo');eHint.textContent=doraFlightActive?'비행 중 · '+Math.max(0,3-(time-doraFlightStart)).toFixed(1)+'초':'뒤적임 → 머리에 장착 · 3초 비행';$('qBtn').querySelector('.skill-type').textContent='배의 주머니를 뒤져 도구 꺼내기';$('rBtn').querySelector('.skill-type').textContent='주머니 → 문을 펼침 · 최대 24블록';}else if(char==='shanks'){eBtn.classList.toggle('combo',shanksReadyUntil>time);eName.textContent=cast?.type==='shanksSlash'?'전진 베기':cast?.type==='shanksParry'?'패링 반격':'검 자세';eHint.textContent=cast?.type==='shanksParry'?'1초 가드 · 적중 시 반격':shanksReadyUntil>time?'좌클릭 베기 · 우클릭 패링':'자세 → 베기 / 패링';}else if(char==='kizaru')kizaru.hud();else if(char==='okkotsu')okkotsu.hud();else if(char==='pain')pain.hud();else if(char==='allmight')allmight.hud();else{eBtn.classList.remove('combo');eName.textContent='벽력일섬 신속';eHint.textContent=godspeedUsed?'사용 완료 · 이동속도 −30%':'1회 · 준비 시간/돌진 시간 절반';}
updateSkillArt();
for(const slot of SLOTS){const type=slotType(slot),remain=Math.max(0,cooldowns[type]-time,type==='dash'?slow:0),button=$(slot+'Btn');button.querySelector('.cooldown').style.height=remain/(type==='thunder'&&charged?THUNDER_CHAIN_COOLDOWN:durations[type])*100+'%';button.querySelector('small').textContent=remain>0?remain.toFixed(1):'';}
if(demoStart>=0){const a=time-demoStart,C=CHARS[char],schedule=C.demo;if(demoStage<schedule.length&&a>=schedule[demoStage][0]&&(!cast||allmight?.canCancel(schedule[demoStage][1])||(schedule[demoStage][1]==='rampage'&&rezeAirUntil>time&&cast.type==='rampage'))){if(C.aimDemo)faceNearestTarget();if(schedule[demoStage][2])aimAt(new T.Vector3(...schedule[demoStage][2]));schedule[demoStage][1]==='slash'?startBasic(true):startSkill(schedule[demoStage][1],true);demoStage++;}if(a>C.demoEnd&&demoStage>=schedule.length&&!cast){demoStart=-1;$('demo').classList.remove('active');toast('시연 완료 · Q / E / R 키로 직접 사용해보세요');}}

if($('qaReadout'))$('qaReadout').textContent=JSON.stringify({combo:melee?.combo??0,slide:!!sliding,cast:cast?.type,age:cast?+(time-cast.start).toFixed(2):null,thunderCharge:cast?.type==='thunder'?+cast.thunderCharge.toFixed(2):null,thunderEnhanced:cast?.thunderEnhanced??false,thunderPass:cast?.segmentShown??-1,charging:thunderHoldAt>=0,charges,item:cast?.item,flight:doraFlightActive,small:targets.map(t=>t.g.scale.x),targetPos:targets[0].g.position.toArray().map(v=>+v.toFixed(2)),damage:damageTotal,hp:targets.map(t=>t.hp),pos:basePos.toArray().map(n=>+n.toFixed(2)),recoil:bombRecoil?{phase:bombRecoil.phase,age:+(time-bombRecoil.start).toFixed(2),groundAge:bombRecoil.land?+(time-bombRecoil.land).toFixed(2):null,blocked:bombRecoil.blocked}:null,playerHp:hp,audioLoops:[...skillLoops.keys()],energy:Math.round(energy),domain:domain?.owner??null,domainAge:domain?+(time-domain.start).toFixed(2):null,domainAudio:skillLoops.has('domainInside')});
renderer.render(scene,camera);
}
kizaru=window.KizaruPreview({T,scene,camera,basePos,targets,obstacles,hit,launch,burst,title,flash,wallOnRay,pose,left,right,hitstop:ms=>{hitstopUntil=Math.max(hitstopUntil,previous+ms);},get time(){return time},get cast(){return cast},get comfort(){return comfort},get muted(){return muted},get audio(){return audio}});
okkotsu=window.OkkotsuPreview?window.OkkotsuPreview({T,scene,camera,targets,basePos,obstacles,hit,launch,title,toast,flash,wallOnRay,aimDir,cooldowns,hitstop:ms=>{hitstopUntil=Math.max(hitstopUntil,previous+ms);},get time(){return time},get energy(){return energy},get hp(){return hp},heal:amount=>{const before=hp;hp=Math.min(200,hp+amount);return hp-before;},get cast(){return cast},get melee(){return melee},get sliding(){return sliding},get muted(){return muted},get audio(){return audio},get comfort(){return comfort}}):null;
pain=window.PainPreview?window.PainPreview({T,scene,camera,targets,basePos,obstacles,arenaR:ARENA_R,makeTarget,hit,later,title,toast,flash,wallOnRay,aimDir,flatForward,cooldowns,get time(){return time},get cast(){return cast},get melee(){return melee},get sliding(){return sliding},get pitch(){return pitch},get muted(){return muted},get audio(){return audio},get comfort(){return comfort}}):null;
allmight=window.AllMightPreview?window.AllMightPreview({T,scene,camera,targets,basePos,obstacles,arenaR:ARENA_R,makeTarget,hit,later,title,toast,flash,flatForward,cooldowns,hitstop:ms=>{hitstopUntil=Math.max(hitstopUntil,previous+ms);},get time(){return time},get cast(){return cast},get melee(){return melee},get sliding(){return sliding},get muted(){return muted},get audio(){return audio},get comfort(){return comfort}}):null;
{const panel=document.createElement('div');panel.id='shanksChoices';panel.hidden=true;for(const [key,label,action] of [['shanks_slash','좌클릭 · 전진 베기',()=>startBasic()],['shanks_parry','우클릭 · 패링',startShanksParry]]){const b=document.createElement('button'),img=document.createElement('img');img.src=skillMedia.icons[key];img.alt='';b.append(img,document.createTextNode(label));b.onclick=action;panel.append(b);}panel.append(document.createElement('output'));document.body.append(panel);}
{const q=new URLSearchParams(location.search).get('char');setCharacter(CHARS[q]?q:'gojo');}
// #debug exposes manual stepping so effects can be inspected while the tab is hidden and rAF is paused.
if(location.hash==='#debug')window.__lab={kizaru:()=>kizaru.state(),okkotsu:()=>okkotsu?.state(),pain:()=>pain?.state(),allmight:()=>allmight?.state(),cooldowns,startBasic,startSlide,reset,startSkill,thunderTest:(charge=0,boosted=false)=>{setCharacter('zenitsu');reset();basePos.x=42;targets[0].g.position.x=42;if(boosted){charges=3;chargesUntil=time+12;}yaw=0;startSkill('thunder',true,charge);},domainClash:()=>{reset();const center=basePos.clone().add(new T.Vector3(0,-2.1,-12));createDomain(center,'rival');later(.45,()=>createDomain(center.clone().add(new T.Vector3(2,0,0)),'player'));},setCharacter,faceNearestTarget,camera,targets,aimAt,state:()=>({common:{combo:melee?.combo??0,slide:!!sliding,basicCombo,slideCooldown:+slideCooldown.toFixed(2),damageTotal},time:+time.toFixed(2),pos:basePos.toArray().map(v=>+v.toFixed(1)),energy:Math.round(energy),hp,charges,cast:cast?cast.type:null,domain:domain?{owner:domain.owner,age:+(time-domain.start).toFixed(2)}:null,audioLoops:[...skillLoops.keys()]}),setYaw:v=>{yaw=v;},shot:()=>{renderer.render(scene,camera);return renderer.domElement.toDataURL('image/jpeg',.82);},pause:on=>{paused=on;previous=performance.now();},step:(n=1)=>{stepping=true;for(let i=0;i<n;i++)animate(previous+1000/60);stepping=false;}};
requestAnimationFrame(animate);$('loading').style.opacity=0;setTimeout(()=>$('loading').remove(),650);
if(location.hash==='#debug'){
  const qa=document.createElement('div');qa.id='frameTools';qa.innerHTML='<button id="qaPause">프레임 일시정지</button><button id="qaStep1">+1 프레임</button><button id="qaStep6">+6 프레임</button><button id="qaStep30">+30 프레임</button><button id="qaShot">캔버스 캡처</button><button id="qaThunderShort">젠이츠 벽력일섬</button><button id="qaThunderFull">젠이츠 신속</button><button id="qaThunderBreath">젠이츠 화뢰신</button><button id="qaLookBack">잔상 뒤돌아보기</button><button id="qaDomainClash">영역 충돌 시연</button><output id="qaReadout"></output>';document.body.append(qa);
  const okQA=document.createElement('span');okQA.innerHTML='<button id="qaOkkotsuFrames">옷코츠 연출 프레임 저장</button><button id="qaOkkotsuTest">옷코츠 전투 검증</button><output id="okkotsuQAResult"></output>';qa.append(okQA);
  const prepareOkkotsu=()=>{reset();setCharacter('okkotsu');window.__lab.pause(true);basePos.set(0,2.1,-5.7);yaw=0;pitch=0;aimAt(targets[0].g.position.clone().add(new T.Vector3(0,1.5,0)));};
  const advanceOkkotsu=seconds=>{const until=time+seconds;for(let n=0;time<until&&n<1800;n++)window.__lab.step(1);};
  $('qaOkkotsuFrames').onclick=async()=>{
    const samples=[];const capture=async(name)=>{await fetch('/shot?name='+name,{method:'POST',body:window.__lab.shot()});samples.push({name,state:okkotsu.state()});};
    prepareOkkotsu();startSkill('pureLove');let prev=0;for(const [i,age]of [.1,.45,.8,1.15,1.55,2.1,2.65,3.08,3.24,3.65,4.25,4.7].entries()){advanceOkkotsu(age-prev);prev=age;await capture('okkotsu-v2-r-'+String(i).padStart(2,'0'));}
    prepareOkkotsu();hp=60;startSkill('reverseCursed');prev=0;for(const [i,age]of [.2,.7,1.16,1.55].entries()){advanceOkkotsu(age-prev);prev=age;await capture('okkotsu-v2-q-'+i);}
    prepareOkkotsu();startSkill('rikaStrike');prev=0;for(const [i,age]of [.45,.72,.86,.94,1.18].entries()){advanceOkkotsu(age-prev);prev=age;await capture('okkotsu-v2-e-'+i);}$('okkotsuQAResult').textContent=JSON.stringify({frames:samples});
  };
  $('qaOkkotsuTest').onclick=async()=>{
    const checks=[],check=(name,pass,actual)=>checks.push({name,pass,actual}),yieldFrame=()=>new Promise(r=>setTimeout(r,0)),near=(a,b)=>Math.abs(a-b)<.01;
    await yieldFrame();prepareOkkotsu();hp=50;startSkill('reverseCursed');advanceOkkotsu(.9);check('heal has real windup',hp===50,hp);advanceOkkotsu(.95);check('heals 50 percent maximum HP',hp===150,hp);check('damage reduced by 30 percent',okkotsu.damageFactor()===.7,okkotsu.state());startSkill('rikaStrike');advanceOkkotsu(.8);check('Rika damage also reduced',near(damageTotal,19.6),damageTotal);check('Rika swing sends target left',targets[0].vel.x<0,targets[0].vel.toArray());advanceOkkotsu(10);check('damage recovers after ten seconds',okkotsu.damageFactor()===1,okkotsu.state());
    await yieldFrame();prepareOkkotsu();hp=160;startSkill('reverseCursed');advanceOkkotsu(1.9);check('healing cannot exceed maximum',hp===200,hp);
    await yieldFrame();prepareOkkotsu();const e=energy;check('full HP does not waste cost',startSkill('reverseCursed')===false&&energy===e,energy);
    await yieldFrame();prepareOkkotsu();startSkill('rikaStrike');advanceOkkotsu(.8);check('E hits one target inside five studs',near(damageTotal,28),damageTotal);check('E knocks the target to the player\'s left',targets[0].vel.x<0,targets[0].vel.toArray());
    await yieldFrame();prepareOkkotsu();targets[0].g.position.z=basePos.z-5.8;aimAt(targets[0].g.position.clone().add(new T.Vector3(0,1.5,0)));startSkill('rikaStrike');advanceOkkotsu(.8);check('E misses beyond five studs',damageTotal===0,damageTotal);
    await yieldFrame();prepareOkkotsu();startSkill('rikaStrike');advanceOkkotsu(.2);targets[0].g.position.x+=6;advanceOkkotsu(.7);check('E target can dodge the committed swing',damageTotal===0,damageTotal);
    await yieldFrame();prepareOkkotsu();startSkill('pureLove');advanceOkkotsu(2.1);check('sword put away before cannon',okkotsu.state().sheathed,okkotsu.state());check('Rika is behind the caster',okkotsu.state().rikaBehind,okkotsu.state());advanceOkkotsu(2.8);check('R damages once',near(damageTotal,110),damageTotal);check('sword and pose return after R',!cast&&okkotsu.state().swordVisible&&!okkotsu.state().rikaVisible,okkotsu.state());
    await yieldFrame();prepareOkkotsu();hp=50;startSkill('reverseCursed');advanceOkkotsu(1.9);startSkill('pureLove');advanceOkkotsu(4.9);check('cannon respects healing tradeoff',near(damageTotal,77),damageTotal);
    await yieldFrame();prepareOkkotsu();basePos.set(-6,2.1,4);targets[0].g.position.set(-6,0,-1);aimAt(targets[0].g.position.clone().add(new T.Vector3(0,1.5,0)));startSkill('pureLove');advanceOkkotsu(4.9);check('cannon stopped by walls',damageTotal===0,damageTotal);
    await yieldFrame();prepareOkkotsu();hp=50;startSkill('reverseCursed');advanceOkkotsu(.8);reset();advanceOkkotsu(2);check('cancelled healing does not fire later',hp===200&&okkotsu.damageFactor()===1,okkotsu.state());$('okkotsuQAResult').textContent=JSON.stringify({passed:checks.filter(c=>c.pass).length,total:checks.length,checks});
  };
  $('qaThunderShort').onclick=()=>window.__lab.thunderTest(0,false);
  $('qaThunderFull').onclick=()=>{setCharacter('zenitsu');reset();startSkill('godspeed',true);};
  $('qaThunderBreath').onclick=()=>{setCharacter('zenitsu');reset();startSkill('god',true);};
  $('qaLookBack').onclick=()=>{yaw+=Math.PI;};
  $('qaDomainClash').onclick=()=>window.__lab.domainClash();
  const rezeQA=document.createElement('span');rezeQA.innerHTML='<button id="qaRezeRecoil">레제 궁극기 반동</button><button id="qaRezeWall">레제 반동 벽 확인</button><button id="qaRezeRecord">레제 반동 프레임 저장</button>';qa.append(rezeQA);
  function prepareRezeRecoil(wall=false){reset();setCharacter('reze');basePos.set(0,2.1,-1);yaw=0;pitch=-.015;
    if(wall){const o=obstacles[0];basePos.set((o.x0+o.x1)/2,2.1,o.z1+1.5);yaw=Math.PI;}
    devilUntil=Infinity;applyLook();startSkill('detonate');window.__lab.pause(true);window.__lab.step(228);$('qaPause').textContent='프레임 계속';}
  $('qaRezeRecoil').onclick=()=>prepareRezeRecoil();$('qaRezeWall').onclick=()=>prepareRezeRecoil(true);
  $('qaRezeRecord').onclick=async()=>{prepareRezeRecoil();const samples=[];for(const [i,n] of [0,20,8,8,12,18,24,24,24].entries()){window.__lab.step(n);const name='reze-recoil-'+String(i).padStart(2,'0');await fetch('/shot?name='+name,{method:'POST',body:window.__lab.shot()});samples.push({name,...JSON.parse($('qaReadout').textContent)});}$('qaRezeRecord').dataset.samples=JSON.stringify(samples);$('qaRezeRecord').textContent='반동 9프레임 저장됨';};
  $('qaPause').onclick=()=>{window.__lab.pause(!paused);$('qaPause').textContent=paused?'프레임 계속':'프레임 일시정지';};
  for(const n of [1,6,30])$('qaStep'+n).onclick=()=>{window.__lab.pause(true);$('qaPause').textContent='프레임 계속';window.__lab.step(n);};
  const doraQA=document.createElement('span');doraQA.innerHTML='<button id="qaSmall">스몰라이트 시연</button><button id="qaCannon">공기포 시연</button><button id="qaBun">단팥빵 시연</button>';qa.append(doraQA);for(const [id,item] of [['qaSmall','small'],['qaCannon','cannon'],['qaBun','dorayaki']])$(id).onclick=()=>{reset();setCharacter('doraemon');faceNearestTarget();hp=160;startSkill('pocket');if(cast)cast.forcedItem=item;};const record=document.createElement('button');record.id='qaRecordPocket';record.textContent='주머니 모션 캡처';qa.append(record);record.onclick=async()=>{reset();setCharacter('doraemon');faceNearestTarget();startSkill('pocket');cast.forcedItem='small';window.__lab.pause(true);window.__lab.step(1);for(let i=0;i<38;i++){if(i)window.__lab.step(4);await fetch('/shot?name=dora-pocket-motion-'+String(i).padStart(3,'0'),{method:'POST',body:window.__lab.shot()});}record.textContent='모션 38프레임 저장됨';};let shotNumber=0;$('qaShot').onclick=()=>fetch('/shot?name='+char+'-common-'+(++shotNumber),{method:'POST',body:window.__lab.shot()});
}
// The initial scene stays controllable; auto demonstration is a deliberate user action.
