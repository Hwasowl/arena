import * as T from './vendor/three.module.js';

const $ = id => document.getElementById(id);
const clamp = T.MathUtils.clamp, mix = T.MathUtils.lerp;
const ease = x => { x = clamp(x,0,1); return x*x*(3-2*x); };
const scene = new T.Scene(); scene.background = new T.Color(0x07111f); scene.fog = new T.FogExp2(0x0c1b2c,.015);
let renderer;
try { renderer = new T.WebGLRenderer({canvas:$('scene'),antialias:true,powerPreference:'high-performance'}); }
catch(e) { $('fatal').hidden=false; $('loading').style.display='none'; throw e; }
renderer.setPixelRatio(Math.min(devicePixelRatio,1.7)); renderer.setSize(innerWidth,innerHeight);
renderer.outputColorSpace=T.SRGBColorSpace; renderer.toneMapping=T.ACESFilmicToneMapping; renderer.toneMappingExposure=1.2;
renderer.shadowMap.enabled=true; renderer.shadowMap.type=T.PCFSoftShadowMap;
const camera = new T.PerspectiveCamera(66,innerWidth/innerHeight,.04,220); scene.add(camera);
const basePos = new T.Vector3(0,2.1,13); camera.position.copy(basePos);
let yaw=0,pitch=-.015,time=0,cast=null,blueUntil=0,blueOrb=null,domain=null,damageTotal=0,energy=100;
let muted=true,audio=null,comfort=false,toastUntil=0,demoStart=-1,demoStage=0,dragging=false,lastPointer=null;
let char='gojo',charges=0,chargesUntil=0,hp=200,slowUntil=0,devilUntil=0,devilShown=false,hold=null,kickCombo=null,hitstopUntil=0;
const keys = new Set(), effects=[], targets=[], particles=[], popups=[], timers=[], trails=[];
const cooldowns={blue:0,red:0,domain:0,dash:0,breath:0,thunder:0,god:0,rampage:0,kick:0,detonate:0,devil:0}; const durations={blue:5,red:6,domain:15,dash:2.5,breath:14,thunder:6,god:25,rampage:5,kick:4,detonate:1,devil:20};
const costs={blue:15,red:20,domain:45,dash:5,breath:20,thunder:18,god:50,rampage:0,kick:0,detonate:0,devil:0};
// Reze pays in health instead of energy: a fraction of max HP per use, never lethal.
const hpCosts={rampage:.03,kick:.03,detonate:.12};
const colors={blue:0x36adff,red:0xff365d,purple:0xa04dff,domain:0x94ddff,thunder:0xffd23f,bomb:0xff7a2e,fire:0xffd08a};
const SKILLS={
  blue:{name:'아오',type:'인력 / 3초 대기',icon:'orb-icon',glyph:'',accent:'#64cfff'},
  red:{name:'아카',type:'척력 / 3초 대기',icon:'burst-icon',glyph:'✦',accent:'#ff637d'},
  domain:{name:'무량공처',type:'영역전개',icon:'domain-icon',glyph:'∞',accent:'#d6c2ff'},
  dash:{name:'순간 가속',type:'이동',icon:'dash-icon',glyph:'»',accent:'#c3dae8'},
  breath:{name:'전집중 호흡',type:'집중 / 강화',icon:'breath-icon',glyph:'≋',accent:'#ffe27a'},
  thunder:{name:'벽력일섬',type:'돌진 / 베기',icon:'bolt-icon',glyph:'ϟ',accent:'#ffd23f'},
  god:{name:'화뢰신',type:'초고속 발도 / 반동',icon:'god-icon',glyph:'雷',accent:'#ffb347'},
  rampage:{name:'폭주대시',type:'폭발 돌진 / 화약',icon:'rampage-icon',glyph:'✸',accent:'#ff8a3d'},
  kick:{name:'폭발 킥',type:'단독 · 폭주 직후 연계',icon:'bomb-icon',glyph:'✺',accent:'#ffa25a'},
  detonate:{name:'대폭발',type:'4초 뒤 광역 · 인간 복귀',icon:'devil-icon',glyph:'爆',accent:'#ff3b1e'},
  devil:{name:'폭탄의 악마',type:'핀 / 변신 · 무제한',icon:'devil-icon',glyph:'爆',accent:'#ff5a2e'}
};
const CHARS={
  gojo:{name:'고죠 사토루',kanji:'五条 悟',seal:'悟',eyebrow:'CHARACTER 01 / LIMITLESS',desc:'공간을 지배하는 힘.<br>아오·아카는 팔을 든 채 3초 대기. 그 안에 다른 쪽을 쓰면 무라사키.',hud:'GOJO',energy:'呪力 / CURSED ENERGY',hint:'<kbd>Q</kbd>+<kbd>E</kbd> 3초 안에 합치면 무라사키 · 같은 키 다시 = 즉시 발사',demoToast:'아오+아카 → 무라사키 → 아오 단독 → 아카 단독 → 영역전개 자동 시연',slots:{q:'blue',e:'red',r:'domain',shift:'dash'},demo:[[.6,'blue'],[1.8,'red'],[6,'blue'],[6.8,'blue'],[8.2,'red'],[9,'red'],[10.5,'domain'],[20,'dash']],demoEnd:21.5},
  zenitsu:{name:'아가츠마 젠이츠',kanji:'我妻 善逸',seal:'善',eyebrow:'CHARACTER 02 / THUNDER BREATHING',desc:'번개의 호흡, 단 하나의 형을 극한까지.<br>전집중 호흡 뒤 벽력일섬은 즉시 발동됩니다.',hud:'ZENITSU',energy:'呼吸 / BREATH',hint:'<kbd>Q → E</kbd> 즉시 벽력일섬 ×3',demoToast:'벽력일섬 → 전집중 호흡 → 즉시 3연속 → 화뢰신 자동 시연',slots:{q:'breath',e:'thunder',r:'god',shift:'dash'},demo:[[.5,'thunder'],[3.6,'breath'],[5.9,'thunder'],[6.7,'thunder'],[7.5,'thunder'],[8.9,'god'],[14,'dash']],demoEnd:15.5,aimDemo:true},
  reze:{name:'레제',kanji:'レゼ',seal:'レ',eyebrow:'CHARACTER 03 / BOMB DEVIL',desc:'평소엔 대시 하나뿐.<br>쵸커의 핀을 당기면 폭탄의 악마가 깨어납니다.',hud:'REZE',energy:'火薬 / GUNPOWDER',hint:'<kbd>R</kbd> 변신(무제한) · <kbd>Q</kbd> 후 바로 <kbd>E</kbd> = 연계 킥 · <kbd>R</kbd> 다시 = 대폭발',demoToast:'변신 → 폭주대시 → 연계 킥 → 단독 킥 → 대폭발 자동 시연',slots:{q:'rampage',e:'kick',r:'devil',shift:'dash'},demo:[[.5,'devil'],[3.8,'rampage'],[4.55,'kick'],[6.4,'kick'],[8.2,'detonate'],[15,'dash']],demoEnd:16,aimDemo:true,demoPos:[0,2.1,-1]}
};
const SLOTS=['q','e','r','shift'];
const hemi=new T.HemisphereLight(0xc2e5ff,0x1b263e,2.5); scene.add(hemi);
const moon=new T.DirectionalLight(0xc6e9ff,3); moon.position.set(-14,32,-15);moon.castShadow=true;moon.shadow.mapSize.set(2048,2048);moon.shadow.camera.left=-40;moon.shadow.camera.right=40;moon.shadow.camera.top=40;moon.shadow.camera.bottom=-40;scene.add(moon);
const warm=new T.DirectionalLight(0xba8fca,.7);warm.position.set(10,5,10);scene.add(warm);
const mat=(color,roughness=.7,metalness=.1)=>new T.MeshStandardMaterial({color,roughness,metalness});
const stone=mat(0x34404b), dark=mat(0x111d2a), trim=mat(0x637384,.5,.5), cloth=mat(0x0c1323), skin=mat(0xe2bcaa,.7), hair=mat(0xdfe9ed);
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
const platform=mesh(new T.CylinderGeometry(35,36,1.4,96),dark);platform.position.y=-.8;
for(let x=-7;x<=7;x++)for(let z=-7;z<=7;z++){if(x*x+z*z>54)continue;const tile=box([4.48,.12,4.48],[x*4.55,-.06,z*4.55],mat(0x263540+Math.floor(Math.random()*8)*0x010101));tile.receiveShadow=true;}
ring(28,0x74a5bd,new T.Vector3(0,.04,0),.018);ring(28.7,0x345d77,new T.Vector3(0,.04,0),.018);ring(9,0x356b90,new T.Vector3(0,.035,-9),.012);
for(let i=0;i<12;i++){const a=i*Math.PI/6;const r=box([.09,.03,1.4],[Math.sin(a)*28,.04,Math.cos(a)*28],glowMat(0x95c2d5));r.rotation.y=a;}
for(let i=0;i<10;i++){const a=i*Math.PI*2/10;const x=Math.sin(a)*31,z=Math.cos(a)*31;const h=4+Math.random()*5;const pillar=box([1.6,h,1.6],[x,h/2,z],stone);pillar.rotation.y=a;box([2.1,.35,2.1],[x,h,z],trim);const lamp=box([.12,h*.7,.12],[x-.83,h*.5,z],glowMat(0x71ceee));glow(0x53bbff,4).position.set(x,1,z);}
// Torii-like gate: restrained geometry instead of imported unverified models.
for(const x of [-10,10]){box([1.4,11,1.4],[x,5.5,-29],dark);box([2.2,.55,2.2],[x,.25,-29],stone);box([.12,8,.08],[x-.72,5,-28.2],glowMat(0x72b1d4));}
box([26,.9,2.1],[0,11,-29],dark);box([23,.5,1.4],[0,8.8,-29],trim);box([3.3,2.1,.35],[0,9.7,-27.9],dark);
for(let i=0;i<45;i++){const a=Math.random()*Math.PI*2,r=48+Math.random()*50,h=6+Math.random()*30;const b=box([3+Math.random()*6,h,3+Math.random()*6],[Math.sin(a)*r,h/2-10,Math.cos(a)*r],mat(0x101d2c));if(i%3===0)box([.08,h*.7,.09],[b.position.x+2,b.position.y,b.position.z+3],glowMat(0x36688c));}
const starGeo=new T.BufferGeometry(), starPos=[];for(let i=0;i<850;i++){const v=new T.Vector3(Math.random()-.5,Math.random()*.6,Math.random()-.5).normalize().multiplyScalar(120);starPos.push(v.x,v.y,v.z);}
starGeo.setAttribute('position',new T.Float32BufferAttribute(starPos,3));scene.add(new T.Points(starGeo,new T.PointsMaterial({color:0xb4d9ff,size:.12,transparent:true,opacity:.7})));
const moonDisc=glow(0xc0dfff,12);moonDisc.position.set(-33,45,-75);
const mist=glow(0x204d78,55);mist.position.set(0,5,-50);mist.material.opacity=.4;

function label(text,color='#9cbed0'){const c=document.createElement('canvas');c.width=256;c.height=64;const ct=c.getContext('2d');ct.font='500 19px sans-serif';ct.fillStyle=color;ct.textAlign='center';ct.fillText(text,128,28);const tex=new T.CanvasTexture(c);const s=new T.Sprite(new T.SpriteMaterial({map:tex,transparent:true,depthWrite:false}));s.scale.set(3.8,.95,1);return s;}
function makeTarget(x,z,index){const g=new T.Group();g.position.set(x,0,z);scene.add(g);box([.85,1.2,.45],[0,1.55,0],cloth,g);box([.37,1,.4],[-.25,.5,0],dark,g);box([.37,1,.4],[.25,.5,0],dark,g);box([.28,.95,.35],[-.61,1.55,0],cloth,g);box([.28,.95,.35],[.61,1.55,0],cloth,g);const head=mesh(new T.SphereGeometry(.31,12,10),mat(0x71828a),g);head.position.y=2.45;box([.66,.1,.51],[0,2.48,.02],mat(0x16232f),g);box([.96,.14,.53],[0,2.1,0],mat(0xaa3648),g);const l=label('TRAINING / 0'+index);l.position.y=3.45;g.add(l);const bg=box([1.45,.05,.015],[0,3.04,.1],mat(0x213440),g);const bar=box([1.45,.05,.02],[0,3.04,.12],glowMat(0x86d4e8),g);ring(.8,0x43627a,new T.Vector3(0,.08,0),.014,g);const t={g,bar,hp:250,max:250,home:new T.Vector3(x,0,z),index,locked:false,respawn:0,vel:null,landed:0};targets.push(t);return t;}
makeTarget(0,-10,1);makeTarget(-7,-15,2);makeTarget(8,-18,3);

// Local view arms are independent from the world-body pose, as in an FPS viewmodel.
function makeHand(side){const g=new T.Group();camera.add(g);const localSkin=skin.clone();localSkin.depthTest=false;const sleeve=cloth.clone();sleeve.depthTest=false;const fore=mesh(new T.CylinderGeometry(.105,.13,.55,8),sleeve,g);fore.position.set(0,-.31,.065);fore.rotation.x=.2;const cuff=mesh(new T.CylinderGeometry(.112,.112,.07,12),sleeve,g);cuff.position.y=-.075;const palm=box([.17,.17,.085],[0,.025,0],localSkin,g);const fuse=new T.Group();g.add(fuse);const cord=mesh(new T.CylinderGeometry(.012,.012,.3,5),new T.MeshBasicMaterial({color:0x4a3626,depthTest:false}),fuse);cord.position.set(side*.1,-.16,.1);cord.rotation.set(.5,0,side*.6);const ember=glow(colors.bomb,.12,fuse);ember.material.depthTest=false;ember.position.set(side*.19,-.28,.17);fuse.visible=false;g.traverse(o=>{o.renderOrder=102;o.frustumCulled=false;o.castShadow=false;});return {g,skin:localSkin,sleeve,side,fuse,ember};}
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
function pose(hand,pos,rot){hand.g.position.set(...pos);hand.g.rotation.set(...rot);hand.skin.emissive.set(0x000000);}

// Zenitsu's sheathed katana: saya in the left hand, right hand resting on the tsuka. Local -Z points from the tsuba toward the pommel.
const swordMat=(color,roughness=.5,metalness=.3)=>{const m=mat(color,roughness,metalness);m.depthTest=false;return m;};
const sword={g:new T.Group(),hilt:new T.Group()};camera.add(sword.g);camera.add(sword.hilt);
{const gold=swordMat(0xc9a24a,.3,.8);box([.042,.052,.9],[0,0,.47],swordMat(0x2b2233,.25,.35),sword.g);box([.048,.058,.05],[0,0,.04],gold,sword.g);box([.048,.058,.04],[0,0,.9],gold,sword.g);
const tsuba=mesh(new T.CylinderGeometry(.064,.064,.016,16),swordMat(0x2a2522,.4,.7),sword.hilt);tsuba.rotation.x=Math.PI/2;
box([.034,.04,.25],[0,0,-.135],swordMat(0xf1ead8,.85,0),sword.hilt);for(let i=0;i<5;i++){const wrap=box([.037,.043,.016],[0,0,-.04-i*.045],swordMat(0x2d2a3c,.6,0),sword.hilt);wrap.rotation.y=(i%2?1:-1)*.5;}
box([.04,.046,.022],[0,0,-.27],gold,sword.hilt);
sword.blade=box([.008,.046,.92],[0,-.004,.48],swordMat(0xe3e9f0,.15,.95),sword.hilt);
sword.edge=box([.011,.012,.9],[0,-.02,.48],glowMat(0xffd23f),sword.hilt);sword.edge.material.depthTest=false;}
sword.g.traverse(o=>{o.renderOrder=100;o.frustumCulled=false;o.castShadow=false;o.receiveShadow=false;});
sword.hilt.traverse(o=>{o.renderOrder=101;o.frustumCulled=false;o.castShadow=false;o.receiveShadow=false;});
sword.g.visible=sword.hilt.visible=false;
// Reze's boot for the explosive kick, swinging up through the lower view.
const boot=box([.12,.1,.3],[0,-.5,-.5],swordMat(0x1c1a1e,.5,.2),camera);boot.renderOrder=102;boot.frustumCulled=false;boot.castShadow=false;boot.visible=false;
function ringMesh(radius){const m=mesh(new T.TorusGeometry(radius,.08,6,96),glowMat(colors.bomb),scene);m.rotation.x=Math.PI/2;m.castShadow=false;return m;}
const FWD=new T.Vector3(0,0,-1),BACK=new T.Vector3(0,0,1),UP=new T.Vector3(0,1,0);
const GRIP=new T.Vector3(0,-.01,-.15),SAYA=new T.Vector3(0,-.01,.2),RIGHT_ARM=new T.Vector3(-.4,.6,-.5).normalize(),LEFT_ARM=new T.Vector3(.5,.65,-.4).normalize();
const zen={pos:new T.Vector3(),dir:new T.Vector3(),push:0,drawn:false,hiltPos:new T.Vector3(),bladeDir:new T.Vector3(),glow:0};
function poseZen(bob){zen.pos.set(-.03,-.31+bob,-.7);zen.dir.set(.8,.25,-.55).normalize();zen.push=0;zen.drawn=false;zen.glow=0;for(const h of [left,right])h.skin.emissive.set(0x000000);}
function drawSword(pos,bladeDir){zen.drawn=true;zen.hiltPos.set(...pos);zen.bladeDir.set(...bladeDir).normalize();}
function applyZen(){sword.g.position.copy(zen.pos);sword.g.quaternion.setFromUnitVectors(FWD,zen.dir);
if(zen.drawn){sword.hilt.position.copy(zen.hiltPos);sword.hilt.quaternion.setFromUnitVectors(BACK,zen.bladeDir);}else{sword.hilt.position.copy(zen.pos).addScaledVector(zen.dir,zen.push);sword.hilt.quaternion.copy(sword.g.quaternion);}
sword.blade.visible=sword.edge.visible=zen.drawn;sword.edge.material.opacity=.45+zen.glow*.55*(.6+Math.random()*.4);
right.g.position.copy(GRIP).applyQuaternion(sword.hilt.quaternion).add(sword.hilt.position);right.g.quaternion.setFromUnitVectors(UP,RIGHT_ARM);
left.g.position.copy(SAYA).applyQuaternion(sword.g.quaternion).add(sword.g.position);left.g.quaternion.setFromUnitVectors(UP,LEFT_ARM);}

// Jagged additive lightning between two world points; no lights, so shaders are not recompiled per strike.
function bolt(from,to,color=colors.thunder,width=.05,life=.35,branches=2,glowSize){const g=new T.Group();scene.add(g);const dir=to.clone().sub(from),len=dir.length();const s1=new T.Vector3().crossVectors(dir,UP);if(s1.lengthSq()<1e-4)s1.set(1,0,0);s1.normalize();const s2=new T.Vector3().crossVectors(dir,s1).normalize();const pts=[from.clone()];const n=Math.max(4,Math.round(len/1.4));for(let i=1;i<n;i++){const p=from.clone().addScaledVector(dir,i/n),j=Math.min(1.2,len*.07);p.addScaledVector(s1,(Math.random()-.5)*j*2).addScaledVector(s2,(Math.random()-.5)*j*2);pts.push(p);}pts.push(to.clone());
const seg=(a,b,w,c)=>{const d=b.clone().sub(a);const m=new T.Mesh(new T.CylinderGeometry(w,w,d.length(),5,1,true),glowMat(c));m.position.copy(a).addScaledVector(d,.5);m.quaternion.setFromUnitVectors(UP,d.normalize());g.add(m);};
for(let i=0;i<pts.length-1;i++){seg(pts[i],pts[i+1],width,color);seg(pts[i],pts[i+1],width*.35,0xffffff);}
for(let b=0;b<branches;b++){const k=1+Math.floor(Math.random()*(pts.length-2)),a=pts[k];const end=a.clone().addScaledVector(dir,.12).addScaledVector(s1,(Math.random()-.5)*len*.25).addScaledVector(s2,(Math.random()-.5)*len*.25);seg(a,end,width*.5,color);}
glow(color,glowSize??Math.min(7,1.5+len*.12),g).position.copy(to);
effect(g,life,(o,u)=>{const flicker=Math.random()<.25?.35:1;o.traverse(m=>{if(m.material)m.material.opacity=(1-u)*flicker;});});return g;}
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
function explode(pos,radius=2){const core=glow(0xfff1d0,radius*1.2);core.position.copy(pos);effect(core,.25,(o,u)=>{o.scale.setScalar(radius*(1.2+u*2));o.material.opacity=1-u;});const ball=glow(colors.bomb,radius*2);ball.position.copy(pos);effect(ball,.5,(o,u)=>{o.scale.setScalar(radius*(2+u*2.5));o.material.opacity=(1-u)*.9;});
shockwave(pos.clone().setY(Math.max(.1,pos.y-radius*.5)),colors.bomb,radius*2.2);burst(pos,colors.bomb,Math.round(12+radius*8),4+radius*2);for(let i=0;i<3+radius;i++)smoke(pos.clone().add(new T.Vector3((Math.random()-.5)*radius,Math.random()*radius*.5,(Math.random()-.5)*radius)),radius*1.6);}
function later(delay,fn){timers.push({at:time+delay,fn});}
// Knockback: targets fly on a simple ballistic arc, tumble, then walk back to their post.
function launch(t,velocity){if(t.hp<=0)return;t.vel=velocity.clone();}
function sound(type){if(muted||!audio)return;const ctx=audio,t=ctx.currentTime;const gain=ctx.createGain();gain.connect(ctx.destination);gain.gain.setValueAtTime(.0001,t);let duration=.7,freq=100;const osc=ctx.createOscillator();osc.connect(gain);osc.type='sine';if(type==='snap'){duration=.09;freq=1100;osc.type='triangle';}if(type==='blue'){duration=1.5;freq=150;}if(type==='purple'){duration=1.3;freq=75;osc.type='sawtooth';}if(type==='domain'){duration=2.6;freq=46;}if(type==='dash'){duration=.2;freq=350;}if(type==='thunder'){duration=.9;freq=70;osc.type='sawtooth';}if(type==='crack'){duration=.22;freq=900;osc.type='square';}if(type==='sheath'){duration=.35;freq=2400;osc.type='triangle';}if(type==='breath'){duration=1.8;freq=110;}if(type==='boom'){duration=1.1;freq=60;osc.type='sawtooth';}if(type==='pin'){duration=.6;freq=3400;osc.type='sine';}if(type==='fizz'){duration=.35;freq=5200;osc.type='sine';}
osc.frequency.setValueAtTime(freq,t);osc.frequency.exponentialRampToValueAtTime(type==='pin'?freq*.97:freq*.28,t+duration);if(type==='pin'){const o2=ctx.createOscillator();o2.frequency.value=freq*2.76;o2.connect(gain);o2.start(t);o2.stop(t+duration*.5);}gain.gain.exponentialRampToValueAtTime(type==='snap'||type==='sheath'||type==='pin'?.09:type==='boom'?.06:.035,t+.015);gain.gain.exponentialRampToValueAtTime(.0001,t+duration);osc.start(t);osc.stop(t+duration);if(['snap','purple','dash','thunder','crack','boom','fizz'].includes(type)){const buffer=ctx.createBuffer(1,ctx.sampleRate*.25,ctx.sampleRate);const arr=buffer.getChannelData(0);for(let i=0;i<arr.length;i++)arr[i]=(Math.random()*2-1)*(1-i/arr.length);const noise=ctx.createBufferSource();noise.buffer=buffer;const ng=ctx.createGain();ng.gain.value=type==='boom'?.22:type==='purple'||type==='thunder'?.13:.05;noise.connect(ng);ng.connect(ctx.destination);noise.start();}}
function flash(color,power=.25){$('flash').style.background=color;let o={p:power};effects.push({object:null,born:time,life:.25,update:(_,t)=>$('flash').style.opacity=(1-t)*o.p});}
function toast(message){$('statusToast').textContent=message;toastUntil=time+2.4;}
function title(kicker,name,desc,color){$('castKicker').textContent=kicker;$('castName').textContent=name;$('castDescription').textContent=desc;$('castTitle').style.setProperty('--accent',color);$('castTitle').classList.add('active');}
function aimPoint(distance=18){const d=new T.Vector3(0,0,-1).applyEuler(new T.Euler(pitch,yaw,0,'YXZ'));return basePos.clone().addScaledVector(d,distance);}
function hit(t,damage,color='#d9f3ff'){if(t.hp<=0)return;const dealt=Math.min(t.hp,damage);t.hp-=dealt;damageTotal+=dealt;$('totalDamage').textContent=Math.round(damageTotal).toLocaleString();t.bar.scale.x=t.hp/t.max;t.bar.position.x=-(1-t.hp/t.max)*.725;const el=document.createElement('div');el.className='damage-number';el.textContent=Math.round(dealt);el.style.color=color;$('damageLayer').append(el);popups.push({el,pos:t.g.position.clone().add(new T.Vector3(0,2.7,0)),born:time});burst(t.g.position.clone().add(new T.Vector3(0,1.6,0)),new T.Color(color),9,4);if(t.hp<=0){t.respawn=time+4;t.g.visible=false;toast('표적 격파 · 4초 후 재생성');}updateTargetCount();}
function updateTargetCount(){$('targetCount').textContent=targets.filter(t=>t.hp>0).length;}
function slotType(slot){let t=CHARS[char].slots[slot];if(char==='reze'&&slot==='r'&&time<devilUntil)t='detonate';return t;}
function startSkill(type,fromDemo=false){if(!fromDemo){demoStart=-1;$('demo').classList.remove('active');}const word=char==='gojo'?'술식':'기술';
if((type==='rampage'||type==='kick'||type==='detonate')&&time>=devilUntil){toast('변신 후 사용 가능 · R 폭탄의 악마');return false;}
if(type==='devil'&&time<devilUntil){toast('이미 폭탄의 악마 상태예요');return false;}
// Gojo: Blue and Red are held with an arm raised for up to 3s. Using the other one during the hold fuses both into
// Purple; using the same one again releases it at once; otherwise it releases by itself when the hold runs out.
if(hold&&(type==='blue'||type==='red')){if(cast){toast('현재 '+word+'이 끝난 뒤 사용할 수 있어요');return false;}
  if(type!==hold.kind){if(cooldowns[type]>time){toast(word+' 회복 중 · '+(cooldowns[type]-time).toFixed(1)+'초');return false;}if(energy<costs[type]){toast('주력이 회복될 때까지 잠시 기다려주세요');return false;}energy-=costs[type];cooldowns[type]=time+durations[type];}
  const kind=type===hold.kind?type:'purple';endHold();return beginCast(kind,false);}
if(hold&&type!=='dash'){toast('술식 대기 중 · Q / E로 발사하거나 합치세요');return false;}
if(cast&&type==='kick'&&cast.type==='rampage'&&cast.flags.go&&time-cast.start>=cast.windup+.2){cast=null;$('castTitle').classList.remove('active');$('scene').style.filter='';}
if(cast){toast('현재 '+word+'이 끝난 뒤 사용할 수 있어요');return false;}
if(type==='dash'&&time<slowUntil){toast('다리 반동 · 대시 불가 '+(slowUntil-time).toFixed(1)+'초');return false;}
const instant=type==='thunder'&&charges>0&&chargesUntil>time;
if(instant)charges--;else{if(cooldowns[type]>time){toast(word+' 회복 중 · '+(cooldowns[type]-time).toFixed(1)+'초');return false;}if(energy<costs[type]){toast(char==='gojo'?'주력이 회복될 때까지 잠시 기다려주세요':'호흡을 가다듬는 중이에요');return false;}energy-=costs[type];cooldowns[type]=time+durations[type];}
if(hpCosts[type])hp=Math.max(1,hp-200*hpCosts[type]);
if(type==='blue'||type==='red'){hold={kind:type,start:time};const blue=type==='blue';title(blue?'CURSED TECHNIQUE · LAPSE':'CURSED TECHNIQUE · REVERSAL',(blue?'아오':'아카')+' · 대기','3초 안에 '+(blue?'E 아카':'Q 아오')+' → 무라사키 · '+(blue?'Q':'E')+' 다시 → 즉시 발사',blue?'#67ceff':'#ff7590');sound('snap');return true;}
return beginCast(type,instant);}
function endHold(){hold=null;holdGlow.visible=false;for(const h of [left,right])h.skin.emissive.set(0x000000);}
function beginCast(skill,instant){const windup=skill==='thunder'&&!instant?2:skill==='god'?.8:skill==='devil'?1:skill==='rampage'?.12:skill==='kick'?.38:skill==='detonate'?4:0;cast={type:skill,start:time,windup,duration:{blue:1.3,red:1,purple:1.7,domain:2.4,dash:.28,breath:2,thunder:windup+.6,god:windup+1.4,devil:windup+2,rampage:windup+.75,kick:windup+.5,detonate:windup+1.6}[skill],flags:{},direction:new T.Vector3(0,0,-1).applyEuler(new T.Euler(pitch,yaw,0,'YXZ')),point:aimPoint(19)};
if(skill==='thunder'){title('雷の呼吸 · 壱ノ型','벽력일섬',instant?'전집중 · 즉시 발동 · 남은 '+charges+'회':'자세를 낮추고 2초 뒤 돌진 · 경로 위 모든 표적 피해','#ffd23f');if(instant)sound('crack');}
if(skill==='breath'){title('全集中の呼吸','전집중 호흡','2초 집중 · 낙뢰 · 이후 벽력일섬 3회 즉시 발동','#ffe27a');sound('breath');}
if(skill==='god'){title('雷の呼吸 · 漆ノ型','화뢰신 · 火雷神','벽력일섬의 10배 속도 · 뇌룡 발도 · 사용 후 반동','#ffb347');sound('breath');}
if(skill==='blue'){title('CURSED TECHNIQUE · LAPSE','술식 순전 · 아오','인력을 형성합니다.','#67ceff');sound('blue');}
if(skill==='red'){title('CURSED TECHNIQUE · REVERSAL','술식 반전 · 아카','응축된 척력을 전방으로 방출합니다.','#ff7590');}
if(skill==='purple'){blueUntil=0;if(blueOrb){dispose(blueOrb);blueOrb=null;}title('HOLLOW TECHNIQUE','허식 · 무라사키','순전과 반전. 두 힘을 하나로.','#caa2ff');cast.orbs=[orb(colors.blue,.34),orb(colors.red,.34)];sound('blue');}
if(skill==='domain'){title('DOMAIN EXPANSION','영역전개 · 무량공처','2초 시전 → 영역 속 표적 이동 허용 · 스킬 봉인 · 지속 피해','#cadbff');sound('domain');}
if(skill==='devil'){title('レゼ','쵸커의 핀','핀을 당긴다 · 머리가 폭발한다','#ff7a2e');}
if(skill==='rampage'){title('BOMB DEVIL','폭주대시','발밑 폭발로 돌진 · 경로의 적을 띄움 · 화약은 1초 뒤 폭발','#ff8a3d');}
if(skill==='kick'){cast.combo=!!(kickCombo&&kickCombo.until>time);cast.dir=cast.combo?kickCombo.dir.clone():null;kickCombo=null;title('BOMB DEVIL',cast.combo?'폭주 연계 · 폭발 킥':'폭발 킥',cast.combo?'폭주대시 방향 그대로 날아가 차 터뜨림':'눈앞을 차서 터뜨림 · 폭주대시 직후엔 연계','#ffa25a');}
if(skill==='detonate'){title('BOMB DEVIL','대폭발','4초 뒤 광역 폭발 · 체력 12% 소모 · 끝나면 인간','#ff3b1e');sound('breath');}
if(skill==='dash'){sound('dash');}return true;}
function projectile(color,radius,damage,speed,start,direction){const p=orb(color,radius);p.position.copy(start);const damaged=new Set();effect(p,1.6,(o,u,dt)=>{const old=o.position.clone();o.position.addScaledVector(direction,speed*dt);o.rotation.z+=dt*3;const segment=new T.Line3(old,o.position);for(const target of targets){if(damaged.has(target)||target.hp<=0)continue;const p2=target.g.position.clone().add(new T.Vector3(0,1.5,0));if(segment.closestPointToPoint(p2,true,new T.Vector3()).distanceTo(p2)<radius+1.2){damaged.add(target);hit(target,damage,color===colors.purple?'#c5a0ff':'#ff8da4');shockwave(p2,color,4);}}if(Math.random()<.75)burst(o.position,color,2,1);});}
function createDomain(center){center.y=0;const group=new T.Group();scene.add(group);group.position.copy(center);const shader=new T.ShaderMaterial({uniforms:{t:{value:0},opacity:{value:0}},vertexShader:'varying vec3 vP; void main(){vP=position;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.);}',fragmentShader:`varying vec3 vP;uniform float t;uniform float opacity;float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}void main(){vec3 n=normalize(vP);vec2 uv=vec2(atan(n.z,n.x),asin(n.y));vec2 cell=floor(uv*160.);float stars=pow(hash(cell),110.);float lanes=pow(max(0.,sin(uv.x*32.+sin(uv.y*3.+t*.25))),18.);float curtain=lanes*(.1+.9*pow(max(0.,sin(uv.y*3.+t*.5)),4.));vec3 col=vec3(.008,.018,.038)+stars*vec3(.65,.8,1.)+curtain*vec3(.045,.12,.23);gl_FragColor=vec4(col,opacity);}`,transparent:true,side:T.BackSide,depthWrite:false});const dome=mesh(new T.SphereGeometry(26,64,32),shader,group);dome.position.y=1.5;const rings=[];for(let i=0;i<5;i++){const r=ring(7+i*4,0x88c6ff,new T.Vector3(0,.12+i*.025,0),.028,group);rings.push(r);}for(let i=0;i<32;i++){const a=i*Math.PI/16;const beam=box([.025,22,.025],[Math.sin(a)*25,8,Math.cos(a)*25],glowMat(0x77baff),group);beam.material.opacity=.32;}
const trapped=targets.filter(t=>t.hp>0&&t.g.position.distanceTo(center)<26);domain={group,dome,shader,rings,start:time,duration:7.5,center:center.clone(),lastTick:time,trapped};for(const t of trapped)t.locked=true;shockwave(center.clone().add(new T.Vector3(0,.2,0)),0x94cfff,30);flash('#82a4e1',.3);toast('무량공처 · 영역 안의 표적 스킬 봉인');}
function updateCast(dt){if(!cast)return;const c=cast,a=time-c.start,p=a/c.duration;$('castProgress').style.width=clamp(p,0,1)*100+'%';
if(c.type==='blue'){right.g.position.set(.22,-.14,-.7);right.g.rotation.set(-.2,-.3,.05);right.skin.emissive.setHex(0x092c44);if(a>.43&&!c.flags.snap){c.flags.snap=true;sound('snap');blueUntil=time+8;blueOrb=orb(colors.blue,.7);blueOrb.position.copy(c.point);blueOrb.position.y=Math.max(2.8,blueOrb.position.y);burst(blueOrb.position,colors.blue,70,8);shockwave(new T.Vector3(c.point.x,.15,c.point.z),colors.blue,7);flash('#4db4ff',.12);}}
if(c.type==='red'){right.g.position.set(.1,-.2,-.67-ease(a/.55)*.25);right.skin.emissive.setHex(0x3f0714);if(a>.42&&!c.flags.fire){c.flags.fire=true;sound('snap');projectile(colors.red,.65,65,32,basePos.clone().addScaledVector(c.direction,2),c.direction);flash('#ff506b',.17);}}
if(c.type==='purple'){const s=ease(a/.8),angle=s*Math.PI*2;const circle=.45*(1-ease((a-.6)/.4));for(const [i,hand]of [left,right].entries()){const side=i===0?-1:1;hand.g.position.set(side*circle*Math.cos(angle),-.1+circle*Math.sin(angle*side),-.87);hand.g.rotation.set(-.2,side*.25,side*angle*.25);const point=new T.Vector3(side*circle*Math.cos(angle)*5,.45+circle*Math.sin(angle*side)*4,-5).applyQuaternion(camera.quaternion).add(camera.position);if(c.orbs[i])c.orbs[i].position.copy(point);}
camera.position.y+=Math.sin(clamp(a/1.7,0,1)*Math.PI)*2.2;
if(a>.95&&!c.flags.merge){c.flags.merge=true;for(const o of c.orbs)dispose(o);c.orbs=[];c.merged=orb(colors.purple,.82);c.merged.position.copy(camera.position).addScaledVector(c.direction,5);burst(c.merged.position,colors.purple,90,10);sound('purple');flash('#a961ff',.35);}
if(c.merged)c.merged.position.copy(camera.position).addScaledVector(c.direction,5);
if(a>1.2&&!c.flags.fire){c.flags.fire=true;dispose(c.merged);c.merged=null;projectile(colors.purple,1.45,180,42,camera.position.clone().addScaledVector(c.direction,5),c.direction);shockwave(camera.position.clone().addScaledVector(c.direction,5),colors.purple,6);flash('#c593ff',.5);}
}
if(c.type==='domain'){right.g.position.set(.06,-.09,-.62);right.g.rotation.set(-.12,-.08,.14);left.g.position.set(-.3,-.55,-.7);const b=Math.sin(Math.min(a/2,1)*Math.PI);if(!comfort)$('scene').style.filter=`blur(${b*2.2}px)`;camera.fov=66-ease(a/2)*10;if(a>=2&&!c.flags.expand){c.flags.expand=true;createDomain(basePos.clone().addScaledVector(c.direction,12));}}
if(c.type==='dash'){basePos.addScaledVector(c.direction,dt*28);basePos.y=2.1;camera.fov=66+Math.sin(p*Math.PI)*12;}
if(c.type==='thunder'){const w=c.windup,fwd=flatForward();
if(a<w){if(Math.random()<dt*16){const s=basePos.clone().addScaledVector(fwd,1.2+Math.random()*1.5).add(new T.Vector3((Math.random()-.5)*1.6,0,(Math.random()-.5)*1.6));s.y=.05;bolt(s,s.clone().add(new T.Vector3((Math.random()-.5)*.6,.5+Math.random()*1.1,(Math.random()-.5)*.6)),colors.thunder,.012,.12,0,.25);}if(Math.random()<dt*3)sound('crack');}
if(a>=w&&!c.flags.go){c.flags.go=true;c.from=basePos.clone();const to=c.from.clone().addScaledVector(fwd,22);for(const t of targets)if(t.hp>0&&t.g.position.distanceTo(to.clone().setY(0))<2.2)to.addScaledVector(fwd,3.5);const r=Math.hypot(to.x,to.z);if(r>29){to.x*=29/r;to.z*=29/r;}c.to=to;
const path=new T.Line3(c.from.clone().setY(1.5),to.clone().setY(1.5));for(const t of targets){if(t.hp<=0)continue;const p2=t.g.position.clone().setY(1.5);if(path.closestPointToPoint(p2,true,new T.Vector3()).distanceTo(p2)<2.6)hit(t,70,'#ffe27a');}
bolt(c.from.clone().setY(.45),to.clone().setY(.45),colors.thunder,.09,.6,4);bolt(c.from.clone().setY(.9),to.clone().setY(.2),0xfff1b0,.04,.5,2);burst(c.from.clone().setY(.5),colors.thunder,40,9);flash('#ffe27a',.45);sound('thunder');}
if(c.flags.go){const u=clamp((a-w)/.22,0,1);basePos.lerpVectors(c.from,c.to,ease(u));basePos.y=2.1;camera.position.copy(basePos);camera.fov=66+16*Math.sin(u*Math.PI);if(!comfort)$('scene').style.filter=u<1?`blur(${Math.sin(u*Math.PI)*5}px)`:'';
if(a-w<.42){drawSword([.2,-.24,-.58],[-.75,.06,-.66]);zen.glow=1;}else if(!c.flags.sheath){c.flags.sheath=true;sound('sheath');}
if(u>=1&&!c.flags.arrive){c.flags.arrive=true;burst(c.to.clone().setY(1),colors.thunder,30,6);shockwave(c.to.clone().setY(.1),colors.thunder,5);}}
const lean=w?ease(a/.5)*(a<w?1:1-ease((a-w)/.3)):0;camera.position.y-=.55*lean;camera.position.addScaledVector(fwd,.3*lean);camera.rotation.x-=.14*lean;zen.pos.y-=.05*lean;zen.pos.z+=.06*lean;zen.glow=Math.max(zen.glow,lean);}
if(c.type==='breath'){const fwd=flatForward(),side=new T.Vector3(-fwd.z,0,fwd.x),k=Math.sin(clamp(a/2,0,1)*Math.PI);camera.fov=66-6*k;zen.pos.y+=Math.sin(a*3.2)*.012;zen.push=.03*ease(a/.4);zen.glow=k;
for(const [i,at] of [.35,.85,1.35].entries())if(a>=at&&!c.flags['b'+i]){c.flags['b'+i]=true;const s=basePos.clone().addScaledVector(fwd,5+Math.random()*5).addScaledVector(side,(Math.random()-.5)*10);s.y=0;bolt(s.clone().add(new T.Vector3((Math.random()-.5)*4,32,(Math.random()-.5)*4)),s,colors.thunder,.07,.4,3);shockwave(s.clone().setY(.1),colors.thunder,3);flash('#ffe27a',.12);sound('crack');}
if(a>=1.75&&!c.flags.self){c.flags.self=true;const s=basePos.clone().addScaledVector(fwd,2.6);s.y=0;bolt(s.clone().add(new T.Vector3(0,34,0)),s,0xfff1b0,.07,.55,5,3);bolt(s.clone().add(new T.Vector3(1,34,-1)),s,colors.thunder,.04,.45,3,2);shockwave(s.clone().setY(.1),colors.thunder,6);burst(s.clone().setY(1),colors.thunder,50,7);flash('#fff3b0',.6);sound('thunder');charges=3;chargesUntil=time+12;toast('전집중 · 벽력일섬 즉시 발동 ×3');}}
if(c.type==='god'){const w=c.windup,fwd=flatForward();
if(a<w){const k=ease(a/.3);camera.position.y-=.7*k;camera.position.addScaledVector(fwd,.35*k);camera.rotation.x-=.16*k;zen.pos.y-=.07*k;zen.pos.z+=.08*k;zen.glow=k;camera.fov=66-6*k;
if(Math.random()<dt*40){const s=basePos.clone().addScaledVector(fwd,1+Math.random()*2).add(new T.Vector3((Math.random()-.5)*2,0,(Math.random()-.5)*2));s.y=.05;bolt(s,s.clone().add(new T.Vector3((Math.random()-.5)*.8,.6+Math.random()*1.2,(Math.random()-.5)*.8)),colors.thunder,.014,.12,0,.25);}if(Math.random()<dt*5)sound('crack');}
if(a>=w&&!c.flags.go){c.flags.go=true;c.from=basePos.clone();const to=c.from.clone().addScaledVector(fwd,40);for(const t of targets)if(t.hp>0&&t.g.position.distanceTo(to.clone().setY(0))<2.2)to.addScaledVector(fwd,3.5);const r=Math.hypot(to.x,to.z);if(r>29){to.x*=29/r;to.z*=29/r;}c.to=to;
const path=new T.Line3(c.from.clone().setY(1.5),to.clone().setY(1.5));c.victims=targets.filter(t=>{if(t.hp<=0)return false;const p2=t.g.position.clone().setY(1.5);return path.closestPointToPoint(p2,true,new T.Vector3()).distanceTo(p2)<3.2;});
dragon(c.from,to);bolt(c.from.clone().setY(.3),to.clone().setY(.3),0xfff6d8,.06,.4,3);flash('#fff6d8',.75);sound('thunder');c.turnFrom=yaw;c.pitchFrom=pitch;}
// Ten times Thunderclap's speed: 40 units in 0.04s. The user then turns to look back, and the victims only
// register the cut once the turn completes.
if(c.flags.go){const after=a-w;basePos.lerpVectors(c.from,c.to,clamp(after/.04,0,1));basePos.y=2.1;camera.position.copy(basePos);camera.fov=66+24*Math.max(0,1-after/.35);if(!comfort)$('scene').style.filter=after<.3?`blur(${(1-after/.3)*7}px)`:'';
const turn=ease((after-.08)/.37);yaw=c.turnFrom+Math.PI*turn;pitch=mix(c.pitchFrom,.12,turn);camera.rotation.set(pitch,yaw,0,'YXZ');
if(after<.8){drawSword([.2,-.24,-.58],[-.75,.06,-.66]);zen.glow=1;}else if(!c.flags.sheath){c.flags.sheath=true;sound('sheath');}
if(after>=.45&&!c.flags.hit){c.flags.hit=true;for(const t of c.victims){const s=t.g.position.clone().setY(1.5);hit(t,150,'#fff1a8');shockwave(s,colors.thunder,5);burst(s,colors.thunder,40,8);}if(c.victims.length)flash('#ffe27a',.3);sound('crack');}
if(after>=.55&&!c.flags.recoil){c.flags.recoil=true;hp=Math.max(1,hp-30);slowUntil=time+4;flash('#ff4d4d',.22);toast('반동 · HP -30 · 4초간 이동 속도 저하 · 대시 불가');}}}
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
    if(grabbed&&!c.flags.pin){c.flags.pin=true;sound('pin');sound('fizz');}}
  if(a>=w&&!c.flags.boom){c.flags.boom=true;choker.visible=false;pin.visible=false;socket.visible=false;devilUntil=Infinity;cooldowns.devil=0;const healed=Math.max(0,Math.min(200,hp+40)-hp);hp+=healed;if(healed>0)toast('폭탄의 악마 · HP +'+Math.round(healed));const head=basePos.clone();explode(head.clone().add(new T.Vector3(0,.2,0)),3);for(let i=0;i<10;i++)smoke(head.clone().add(new T.Vector3((Math.random()-.5)*4,(Math.random()-.3)*2,(Math.random()-.5)*4)),2.5+Math.random()*2,2.6);sound('boom');
    for(const t of targets){if(t.hp<=0)continue;const d=t.g.position.clone().sub(head).setY(0),dist=d.length();if(dist<9.5){const power=1-.35*dist/9.5;hit(t,90,'#ffb27a');launch(t,(dist>.1?d.normalize():flatForward()).multiplyScalar(24*power).setY(10*power));}}}
  // Her own head just went off: black, then sight slowly returns over two seconds.
  if(c.flags.boom){const after=a-w,dark=after<.3?1:1-ease((after-.3)/1.7);$('blackout').style.opacity=dark;if(!comfort){$('scene').style.filter=dark>.02?`blur(${dark*9}px)`:'';camera.position.x+=(Math.random()-.5)*.08*dark;camera.position.y+=(Math.random()-.5)*.08*dark;}
    if(after>=1.05&&!c.flags.reveal){c.flags.reveal=true;title('爆弾の悪魔','폭탄의 악마','변신 · 지속 무제한 · Q 폭주대시 / E 폭발 킥 / R 대폭발','#ff5a2e');}}}
if(c.type==='rampage'){const w=c.windup,fwd=flatForward();
  const k=ease(a/.1);left.g.position.set(-.55,-.62-.18*k,-.62);left.g.rotation.set(.6*k,.2,-.4);right.g.position.set(.55,-.62-.18*k,-.62);right.g.rotation.set(.6*k,-.2,.4);
  if(a>=w&&!c.flags.go){c.flags.go=true;c.from=basePos.clone();const to=c.from.clone().addScaledVector(fwd,18);for(const t of targets)if(t.hp>0&&t.g.position.distanceTo(to.clone().setY(0))<2.2)to.addScaledVector(fwd,3.5);const r=Math.hypot(to.x,to.z);if(r>29){to.x*=29/r;to.z*=29/r;}c.to=to;kickCombo={dir:fwd.clone(),until:time+1.3};toast('연계 · E 폭발 킥!');
    explode(c.from.clone().setY(.3),1.8);flash('#ff9a4d',.3);sound('boom');
    const path=new T.Line3(c.from.clone().setY(1.5),to.clone().setY(1.5));for(const t of targets){if(t.hp<=0)continue;const p2=t.g.position.clone().setY(1.5);if(path.closestPointToPoint(p2,true,new T.Vector3()).distanceTo(p2)<2.6){c.hits=(c.hits||0)+1;hit(t,45,'#ffb27a');launch(t,fwd.clone().multiplyScalar(4).setY(11));later(.05,()=>explode(p2.clone(),1.2));}}
    // Gunpowder left along the path; it goes off on its own one second later.
    const grains=[],len=c.from.distanceTo(to),side=new T.Vector3(-fwd.z,0,fwd.x);for(let d=0;d<=len;d+=.8){const at=c.from.clone().addScaledVector(fwd,d).addScaledVector(side,(Math.random()-.5)*.7).setY(.03);const g=new T.Group();scene.add(g);g.position.copy(at);const disc=mesh(new T.CircleGeometry(.22+Math.random()*.18,8),new T.MeshBasicMaterial({color:0x1d1a19,transparent:true,opacity:.9}),g);disc.rotation.x=-Math.PI/2;if(Math.random()<.5){const e=glow(colors.bomb,.18,g);e.position.y=.06;}grains.push(g);}
    trails.push({grains,from:c.from.clone().setY(1.5),to:to.clone().setY(1.5),at:time+1});}
  if(c.flags.go){const u=clamp((a-w)/.2,0,1);basePos.lerpVectors(c.from,c.to,1-(1-u)*(1-u));basePos.y=2.1;camera.position.copy(basePos);camera.fov=66+20*(1-ease((a-w)/.45));if(!comfort)$('scene').style.filter=u<1?`blur(${Math.sin(u*Math.PI)*4}px)`:'';
  // Missed everything: the boots skid on, dropping low and kicking up dust before she recovers.
  if(!c.hits&&a-w>.2){const sl=clamp((a-w-.2)/.5,0,1),e=1-(1-sl)*(1-sl);basePos.copy(c.to).addScaledVector(fwd,5.5*e);const rr=Math.hypot(basePos.x,basePos.z);if(rr>29){basePos.x*=29/rr;basePos.z*=29/rr;}basePos.y=2.1-.6*Math.sin(Math.min(1,sl*1.6)*Math.PI*.5)*(1-.7*sl);camera.position.copy(basePos);camera.rotation.z=.04*Math.sin(sl*Math.PI);
    if(sl<.9&&Math.random()<dt*50){const q=basePos.clone().setY(.15).addScaledVector(fwd,-.6);smoke(q,.8,.7);burst(q,0xb9a78e,1,2);}if(sl<1&&!c.flags.skid){c.flags.skid=true;sound('dash');}}}}
if(c.type==='kick'){const w=c.windup,combo=c.combo,fwd=combo?c.dir:flatForward();
  // Roundhouse: coil to the right, then whip the leg across the view from right to left; the view turns with it.
  const lf=ease(a/.3),sw=ease((a-.3)/.16),up=Math.sin(sw*Math.PI),off=(-.34*lf*(1-sw)+.46*sw)*(1-ease((a-.55)/.3));
  camera.rotation.set(pitch-.06*up-.05*lf*(1-sw),yaw+off,-.1*up+.04*lf*(1-sw),'YXZ');camera.position.y-=.12*lf*(1-sw)+.3*up;camera.fov=66-3*lf*(1-sw)+12*up+(combo?8:0);
  left.g.position.set(-.55,-.62,-.62);left.g.rotation.set(.4,.2,-.4);right.g.position.set(.55-.2*sw,-.62,-.62);right.g.rotation.set(.4,-.2,.4);
  boot.visible=true;boot.scale.set(1.3,1.3,1.9);boot.position.set(mix(1.05,-1.05,sw),-.66+.3*lf*(1-sw)+.34*up,-.7-.22*lf*(1-sw)-.32*up);boot.rotation.set(-.3*lf*(1-sw)-.45*up,mix(-1.3,1.3,sw),mix(.55,-.55,sw)*.6);
  if(a>=w&&!c.flags.go){c.flags.go=true;flash('#ff9a4d',.3);sound('boom');const struck=new Set();c.from=basePos.clone();let at;
    if(combo){let to=c.from.clone().addScaledVector(fwd,18);const rr=Math.hypot(to.x,to.z);if(rr>29){to.x*=29/rr;to.z*=29/rr;}c.to=to;
      const path=new T.Line3(c.from.clone().setY(1.2),to.clone().setY(1.2));for(const t of targets){if(t.hp<=0)continue;const p2=t.g.position.clone().setY(1.2);if(path.closestPointToPoint(p2,true,new T.Vector3()).distanceTo(p2)<2.4)struck.add(t);}
      bolt(c.from.clone().setY(.45),to.clone().setY(.45),colors.bomb,.08,.5,3);bolt(c.from.clone().setY(.9),to.clone().setY(.9),0xffecc0,.035,.4,1);at=to.clone().addScaledVector(fwd,2.2).setY(.9);}
    else at=c.from.clone().addScaledVector(fwd,3.2).setY(.9);
    const radius=combo?3.6:2.9;explode(at,combo?2.4:1.7);
    {const g=new T.Group();scene.add(g);g.position.set(c.from.x,.95,c.from.z);const arcMesh=mesh(new T.TorusGeometry(combo?3.2:2.5,combo?.12:.09,6,40,Math.PI*.7),glowMat(colors.bomb),g);arcMesh.rotation.set(-Math.PI/2,0,Math.PI*.15);arcMesh.castShadow=false;const core=mesh(new T.TorusGeometry(combo?3.2:2.5,combo?.04:.03,6,40,Math.PI*.7),glowMat(0xfff1d0),g);core.rotation.copy(arcMesh.rotation);core.castShadow=false;const y0=yaw;effect(g,.32,(o,u)=>{o.rotation.y=y0-.55+1.1*ease(u*1.6);o.scale.setScalar(.85+.35*u);o.traverse(m=>{if(m.material)m.material.opacity=(1-u)*.9;});});}
    for(const t of targets){if(t.hp<=0)continue;if(struck.has(t)||t.g.position.clone().setY(.9).distanceTo(at)<radius)struck.add(t);}
    for(const t of struck){const p2=t.g.position.clone().setY(.9);hit(t,combo?85:45,'#ffb27a');launch(t,fwd.clone().multiplyScalar(combo?10:5).setY(combo?9:7));later(.04,()=>explode(p2,1.1));}
    if(struck.size)hitstopUntil=previous+130;if(combo)toast('폭주 연계!');}
  if(c.flags.go&&combo){const u=clamp((a-w)/.18,0,1);basePos.lerpVectors(c.from,c.to,1-(1-u)*(1-u));basePos.y=2.1;camera.position.copy(basePos);camera.position.y-=.35*up;if(!comfort)$('scene').style.filter=u<1?`blur(${Math.sin(u*Math.PI)*4}px)`:'';}}
if(c.type==='detonate'){const w=c.windup;
  // Fuse hair burns down for four seconds: hands clenched before the face, a pulsing danger ring, the view shudders harder.
  if(!c.flags.go){const k=a/w;left.g.position.set(-.16,-.28,-.68);left.g.rotation.set(.1,.7,-.5);right.g.position.set(.16,-.28,-.68);right.g.rotation.set(.1,-.7,.5);
    camera.fov=66-8*k;camera.position.x+=(Math.random()-.5)*.14*k*k;camera.position.y+=(Math.random()-.5)*.14*k*k;
    if(!c.ring){const ring=ringMesh(12);ring.position.set(basePos.x,.07,basePos.z);c.ring=ring;}
    c.ring.material.opacity=.45+.4*Math.sin(a*(4+a*a*3));
    if(Math.random()<dt*(6+20*k)){const q=basePos.clone().add(new T.Vector3((Math.random()-.5)*1.5,.9+Math.random()*.6,(Math.random()-.5)*1.5));smoke(q,.9,1);burst(q,colors.bomb,2,2);}
    const n=Math.ceil(w-a);if(n!==c.count){c.count=n;toast('폭발까지 '+n);sound('crack');}}
  if(a>=w&&!c.flags.go){c.flags.go=true;if(c.ring){dispose(c.ring);c.ring=null;}const at=basePos.clone().setY(.8),R=12;
    explode(at,5);shockwave(at.clone().setY(.1),colors.bomb,R*1.3);flash('#ffffff',.95);sound('boom');
    for(let k=1;k<=10;k++)later(k*.04,()=>{const ang=Math.random()*Math.PI*2,d=Math.random()*R*.85;explode(new T.Vector3(at.x+Math.cos(ang)*d,.7,at.z+Math.sin(ang)*d),2.4);});
    for(const t of targets){if(t.hp<=0)continue;const d=t.g.position.clone().sub(at).setY(0),dist=d.length();if(dist<R){const power=1-.55*dist/R;hit(t,170,'#ffb27a');launch(t,(dist>.1?d.normalize():flatForward()).multiplyScalar(26*power).setY(14*power));}}
    // Back to human; the transformation can be used again after 20 seconds.
    devilUntil=0;cooldowns.devil=time+20;toast('인간으로 돌아온다 · 폭탄의 악마 재사용 20초');}}
if(a>=c.duration){boot.visible=false;if(c.ring)dispose(c.ring);if(c.type==='devil'){$('blackout').style.opacity=0;pin.visible=false;choker.visible=false;}if(c.orbs)for(const o of c.orbs)dispose(o);if(c.merged)dispose(c.merged);cast=null;$('castTitle').classList.remove('active');$('scene').style.filter='';}}
function reset(){if(cast?.ring)dispose(cast.ring);boot.visible=false;kickCombo=null;cast?.orbs?.forEach(dispose);if(cast?.merged)dispose(cast.merged);cast=null;if(blueOrb)dispose(blueOrb);blueOrb=null;blueUntil=0;charges=0;chargesUntil=0;hp=200;slowUntil=0;hold=null;holdGlow.visible=false;devilUntil=0;for(const tr of trails)tr.grains.forEach(dispose);trails.length=0;timers.length=0;pin.visible=false;choker.visible=false;$('blackout').style.opacity=0;if(domain)dispose(domain.group);domain=null;for(const fx of effects)if(fx.object)dispose(fx.object);effects.length=0;for(const p of particles)dispose(p.object);particles.length=0;for(const p of popups)p.el.remove();popups.length=0;Object.keys(cooldowns).forEach(k=>cooldowns[k]=0);energy=100;damageTotal=0;$('totalDamage').textContent='0';for(const t of targets){t.hp=t.max;t.g.visible=true;t.g.position.copy(t.home);t.bar.scale.x=1;t.bar.position.x=0;t.locked=false;t.respawn=0;t.vel=null;t.landed=0;t.g.rotation.x=0;}basePos.set(0,2.1,13);yaw=0;pitch=-.015;$('castTitle').classList.remove('active');$('scene').style.filter='';$('flash').style.opacity=0;updateTargetCount();}

function setCharacter(next){if(!CHARS[next])return;if(cast){toast('현재 기술이 끝난 뒤 바꿀 수 있어요');return;}demoStart=-1;$('demo').classList.remove('active');char=next;reset();const C=CHARS[char];
document.body.dataset.char=char;document.title='INFINITY / '+C.name+' · Skill Lab';$('charEyebrow').textContent=C.eyebrow;$('charName').innerHTML=C.name+'<span>'+C.kanji+'</span>';$('charDesc').innerHTML=C.desc;$('seal').textContent=C.seal;$('hudName').textContent=C.hud;$('energyLabel').textContent=C.energy;$('comboHint').innerHTML=C.hint;
for(const slot of SLOTS){const s=SKILLS[C.slots[slot]],b=$(slot+'Btn'),icon=b.querySelector('.skill-icon');b.style.setProperty('--accent',s.accent);icon.className='skill-icon '+s.icon;icon.textContent=s.glyph;b.querySelector('strong').textContent=s.name;b.querySelector('.skill-type').textContent=s.type;b.classList.remove('combo','locked');b.dataset.skill='';}
for(const b of document.querySelectorAll('.char-switch button'))b.classList.toggle('active',b.dataset.pick===char);
sword.g.visible=sword.hilt.visible=char==='zenitsu';devilShown=null;}
// Sleeves and Bomb Devil extras follow the character and transformation.
function applyLook(){const devil=char==='reze'&&time<devilUntil;if(devil===devilShown)return;const was=devilShown;devilShown=devil;document.body.classList.toggle('devil',devil);devilHair.visible=devil;for(const h of [left,right]){h.fuse.visible=devil;h.sleeve.color.setHex(char==='zenitsu'?0xe0a526:char==='reze'?(devil?0x2a2628:0xe2bcaa):0x0c1323);}
if(char==='reze'){$('seal').textContent=devil?'爆':'レ';$('hudName').textContent=devil?'BOMB DEVIL':'REZE';if(!devil&&was===true)toast('변신 해제 · 궁극기 재사용 대기');}}
function faceNearestTarget(){const alive=targets.filter(t=>t.hp>0&&t.g.position.distanceTo(basePos.clone().setY(0))>3);if(!alive.length)return;alive.sort((x,y)=>x.g.position.distanceTo(basePos)-y.g.position.distanceTo(basePos));const d=alive[0].g.position.clone().sub(basePos);yaw=Math.atan2(-d.x,-d.z);pitch=-.015;}
for(const slot of SLOTS)$(slot+'Btn').addEventListener('click',()=>startSkill(slotType(slot)));
for(const b of document.querySelectorAll('.char-switch button'))b.onclick=()=>{setCharacter(b.dataset.pick);toast(CHARS[char].name+' 선택');};
$('reset').onclick=()=>{demoStart=-1;$('demo').classList.remove('active');reset();toast('표적과 쿨타임을 초기화했습니다');};
$('demo').onclick=()=>{if(demoStart>=0){demoStart=-1;$('demo').classList.remove('active');return;}reset();if(CHARS[char].demoPos)basePos.set(...CHARS[char].demoPos);demoStart=time;demoStage=0;$('demo').classList.add('active');toast(CHARS[char].demoToast);};
$('sound').onclick=()=>{muted=!muted;if(!muted){audio??=new (window.AudioContext||window.webkitAudioContext)();audio.resume();sound('snap');}$('sound').textContent=muted?'소리 OFF':'소리 ON';};
$('settings').onclick=()=>{comfort=!comfort;$('settings').textContent=comfort?'연출: 저자극':'연출: 기본';if(comfort)$('scene').style.filter='';};
window.addEventListener('keydown',e=>{if(e.repeat)return;keys.add(e.code);const pick={Digit1:'gojo',Digit2:'zenitsu',Digit3:'reze'}[e.code];if(pick){setCharacter(pick);return;}const slot={KeyQ:'q',KeyE:'e',KeyR:'r',ShiftLeft:'shift',ShiftRight:'shift'}[e.code];if(slot){e.preventDefault();startSkill(slotType(slot));}});window.addEventListener('keyup',e=>keys.delete(e.code));window.addEventListener('blur',()=>{keys.clear();dragging=false;});
$('scene').addEventListener('pointerdown',e=>{dragging=true;lastPointer={x:e.clientX,y:e.clientY};$('scene').setPointerCapture(e.pointerId);});
$('scene').addEventListener('pointermove',e=>{if(!dragging)return;yaw-=(e.clientX-lastPointer.x)*.003;pitch=clamp(pitch-(e.clientY-lastPointer.y)*.003,-1.1,1.1);lastPointer={x:e.clientX,y:e.clientY};});$('scene').addEventListener('pointerup',()=>dragging=false);
window.addEventListener('resize',()=>{camera.aspect=innerWidth/innerHeight;camera.updateProjectionMatrix();renderer.setSize(innerWidth,innerHeight);});
let previous=performance.now(),paused=false,stepping=false;
function animate(now){if(!stepping)requestAnimationFrame(animate);if(paused&&!stepping)return;let dt=Math.min((now-previous)/1000,.05);previous=now;if(now<hitstopUntil)dt*=.06;time+=dt;
const movement=new T.Vector3((keys.has('KeyD')?1:0)-(keys.has('KeyA')?1:0),0,(keys.has('KeyS')?1:0)-(keys.has('KeyW')?1:0));if(movement.lengthSq()){movement.normalize().applyAxisAngle(new T.Vector3(0,1,0),yaw);basePos.addScaledVector(movement,dt*(cast?2:6)*(time<slowUntil?.4:1));document.body.classList.add('moving');}else document.body.classList.remove('moving');if(Math.hypot(basePos.x,basePos.z)>29){const l=29/Math.hypot(basePos.x,basePos.z);basePos.x*=l;basePos.z*=l;}
camera.position.copy(basePos);camera.rotation.set(pitch,yaw,0,'YXZ');
// Recoil after the seventh form: knees buckle, the view sags and limps until the slow wears off.
if(time<slowUntil){const k=Math.min(1,(slowUntil-time)/.6);camera.position.y-=.28*k;camera.rotation.z=Math.sin(time*(movement.lengthSq()?7:2))*.025*k;}camera.fov=mix(camera.fov,66,dt*7);const bob=movement.lengthSq()?Math.sin(time*10)*.012:Math.sin(time*1.9)*.008;if(char!=='zenitsu'){pose(left,[-.38,-.48+bob,-.8],[.1,.2,-.3]);pose(right,[.38,-.42-bob,-.8],[.05,-.25,.3]);}else poseZen(bob);
updateCast(dt);applyLook();
// Hold: Blue raises the right arm, Red the left, with the technique gathering in the palm.
if(hold){const blue=hold.kind==='blue',h=blue?right:left,side=blue?1:-1,u=time-hold.start,k=ease(u/.25);h.g.position.set(side*.3,-.42+.3*k,-.8+.06*k);h.g.rotation.set(.35*k,0,side*(.3-.22*k));h.skin.emissive.setHex(blue?0x0a3a5a:0x4a0a18);
  holdGlow.visible=true;holdGlow.material.color.setHex(blue?colors.blue:colors.red);holdGlow.position.copy(h.g.position).add(new T.Vector3(0,.16,0));holdGlow.scale.setScalar((.3+.15*k)*(1+Math.sin(time*14)*.08));
  $('castTitle').classList.add('active');$('castProgress').style.width=clamp(u/3,0,1)*100+'%';
  if(u>=3&&!cast){const kind=hold.kind;endHold();beginCast(kind,false);}}if(char==='zenitsu')applyZen();const handRatio=clamp(camera.aspect,.55,1);holdGlow.position.x*=handRatio;for(const o of [left.g,right.g,sword.g,sword.hilt]){if(o===right.g&&cast?.type==='devil'&&!cast.flags.boom)continue;o.position.x*=handRatio;o.scale.setScalar(mix(.78,1,handRatio)*(char==='zenitsu'&&(o===left.g||o===right.g)?.62:1));}camera.updateProjectionMatrix();
if(blueOrb){if(time>blueUntil){burst(blueOrb.position,colors.blue,15,3);dispose(blueOrb);blueOrb=null;}else{blueOrb.rotation.y+=dt*1.7;blueOrb.rotation.z+=dt*.7;blueOrb.scale.setScalar(1+Math.sin(time*9)*.04);if(Math.random()<.3){const p=glow(colors.blue,.15);const v=new T.Vector3(Math.random()-.5,Math.random()-.5,Math.random()-.5).normalize().multiplyScalar(4+Math.random()*3);const destination=blueOrb.position.clone();p.position.copy(destination).add(v);effect(p,.5,(o,u)=>{o.position.lerp(destination,u*.3);o.material.opacity=1-u;});}for(const t of targets){if(t.hp<=0)continue;const d=blueOrb.position.clone().sub(t.g.position);d.y=0;if(d.length()<11&&d.length()>1.5)t.g.position.addScaledVector(d.normalize(),dt*1.5);}if(!cast){right.skin.emissive.setHex(0x052030);}}}
if(domain){const d=domain,a=time-d.start;d.shader.uniforms.t.value=a;d.shader.uniforms.opacity.value=ease(a/.7)*(1-ease((a-d.duration+1)));d.group.scale.setScalar(.01+.99*ease(a/.8));d.rings.forEach((r,i)=>r.material.opacity=(.25+Math.sin(time*2+i)*.12)*(1-ease(a-d.duration+1)));if(time-d.lastTick>.5){d.lastTick=time;for(const t of d.trapped)if(t.hp>0)hit(t,8,'#9ccfff');}if(a>d.duration){dispose(d.group);for(const t of d.trapped)t.locked=false;domain=null;toast('영역 해제');}}
for(let i=timers.length-1;i>=0;i--)if(time>=timers[i].at){const fn=timers[i].fn;timers.splice(i,1);fn();}
for(let i=trails.length-1;i>=0;i--){const tr=trails[i];if(time<tr.at){for(const g of tr.grains)g.children[1]&&(g.children[1].material.opacity=.5+Math.random()*.5);continue;}trails.splice(i,1);
  const path=new T.Line3(tr.from,tr.to);for(const t of targets){if(t.hp<=0)continue;const p2=t.g.position.clone().setY(1.5);if(path.closestPointToPoint(p2,true,new T.Vector3()).distanceTo(p2)<2.6){hit(t,35,'#ffb27a');launch(t,new T.Vector3(0,9,0));}}
  sound('boom');tr.grains.forEach((g,k)=>later(k*.025,()=>{const at=g.position.clone();dispose(g);if(k%2===0)explode(at.setY(.5),1.1);}));}
if(char==='reze'&&time<devilUntil){for(const [i,tip] of hairTips.entries())tip.material.opacity=.6+Math.random()*.4;devilHair.position.y=Math.sin(time*2)*.008;for(const h of [left,right])h.ember.material.opacity=.6+Math.random()*.4;}
for(const t of targets){if(t.vel){t.g.position.addScaledVector(t.vel,dt);t.vel.y-=25*dt;t.g.rotation.x-=dt*7;const r=Math.hypot(t.g.position.x,t.g.position.z);if(r>29){t.g.position.x*=29/r;t.g.position.z*=29/r;}if(t.g.position.y<=0&&t.vel.y<0){t.g.position.y=0;t.vel=null;t.g.rotation.x=0;t.landed=time;shockwave(t.g.position.clone().setY(.1),0x8a7a70,1.5);}}
  else if(t.landed&&t.hp>0&&!t.locked&&time>t.landed+1.5){const back=t.home.clone().sub(t.g.position).setY(0);if(back.length()>.3)t.g.position.addScaledVector(back.normalize(),Math.min(back.length(),dt*2.5));else t.landed=0;}}
for(const t of targets){if(t.hp<=0&&time>=t.respawn){t.hp=t.max;t.g.visible=true;t.g.position.copy(t.home);t.bar.scale.x=1;t.bar.position.x=0;updateTargetCount();}if(t.hp>0){t.g.rotation.y=Math.sin(time*.6+t.index)*.08;t.g.position.x+=Math.sin(time*.8+t.index)*dt*.12;}}
for(let i=effects.length-1;i>=0;i--){const e=effects[i],age=(time-e.born)/e.life;if(age>=1){if(e.object)dispose(e.object);else $('flash').style.opacity=0;effects.splice(i,1);}else e.update?.(e.object,age,dt);}
for(let i=particles.length-1;i>=0;i--){const p=particles[i],age=(time-p.born)/p.life;if(age>=1){dispose(p.object);particles.splice(i,1);}else{p.object.position.addScaledVector(p.v,dt);p.v.y-=dt*2;p.object.material.opacity=(1-age);}}
for(let i=popups.length-1;i>=0;i--){const p=popups[i],a=time-p.born;if(a>1){p.el.remove();popups.splice(i,1);continue;}const v=p.pos.clone();v.y+=a*1.2;v.project(camera);p.el.style.left=(v.x*.5+.5)*innerWidth+'px';p.el.style.top=(-v.y*.5+.5)*innerHeight+'px';p.el.style.opacity=v.z>1?'0':1-a;}
$('hpText').textContent=hp+' / 200';$('hpBar').style.width=hp/2+'%';const slow=slowUntil-time,devilLeft=char==='reze'?devilUntil-time:0;$('debuff').classList.toggle('on',slow>0||char==='reze');if(slow>0)$('debuff').textContent='반동 · 이동 속도 -60% · 대시 불가 '+slow.toFixed(1)+'초';else if(char==='reze')$('debuff').textContent=devilLeft>0?'폭탄의 악마 · 지속 무제한 · 기본 스킬 HP 3% · R 대폭발':cooldowns.devil>time?'인간 · 폭탄의 악마 재사용 '+(cooldowns.devil-time).toFixed(1)+'초':'변신 전 · R 폭탄의 악마 / SHIFT 대시만 가능';
energy=Math.min(100,energy+dt*5);$('energyBar').style.width=energy+'%';$('energyText').textContent=Math.floor(energy)+'%';$('statusToast').style.opacity=time<toastUntil?1:0;
const eBtn=$('eBtn'),eName=eBtn.querySelector('strong'),eHint=eBtn.querySelector('.skill-type');const charged=char==='zenitsu'&&charges>0&&chargesUntil>time;
if(char==='gojo'){for(const [b,kind,base,baseHint] of [[$('qBtn'),'blue','아오','인력 / 3초 대기'],[eBtn,'red','아카','척력 / 3초 대기']]){const held=hold&&hold.kind===kind,fuse=hold&&hold.kind!==kind;b.classList.toggle('combo',!!fuse);b.querySelector('strong').textContent=fuse?'무라사키':held?base+' 발사':base;b.querySelector('.skill-type').textContent=held?'다시 눌러 즉시 · '+Math.max(0,3-(time-hold.start)).toFixed(1)+'초':fuse?'합쳐서 발사':baseHint;}}
else if(char==='reze'){const kc=kickCombo&&kickCombo.until>time?kickCombo.until-time:0;eBtn.classList.toggle('combo',kc>0);eName.textContent=kc>0?'연계 킥':'폭발 킥';eHint.textContent=kc>0?'지금 · '+kc.toFixed(1)+'초':'단독 · 폭주 직후 연계';$('comboPrompt').classList.toggle('on',kc>0);$('comboPrompt').style.setProperty('--left',(kc/1.3*100)+'%');for(const slot of ['q','e'])$(slot+'Btn').classList.toggle('locked',time>=devilUntil);const rb=$('rBtn'),sk=SKILLS[slotType('r')];if(rb.dataset.skill!==slotType('r')){rb.dataset.skill=slotType('r');rb.style.setProperty('--accent',sk.accent);const ic=rb.querySelector('.skill-icon');ic.className='skill-icon '+sk.icon;ic.textContent=sk.glyph;rb.querySelector('strong').textContent=sk.name;rb.querySelector('.skill-type').textContent=sk.type;}}
else{if(!charged)charges=0;eBtn.classList.toggle('combo',charged);eHint.textContent=charged?'즉시 ×'+charges+' · '+Math.ceil(chargesUntil-time)+'초':'돌진 / 베기';}
for(const slot of SLOTS){const type=slotType(slot),remain=(type==='thunder'&&charged)?0:Math.max(0,cooldowns[type]-time,type==='dash'?slow:0),button=$(slot+'Btn');button.querySelector('.cooldown').style.height=remain/durations[type]*100+'%';button.querySelector('small').textContent=remain>0?remain.toFixed(1):'';}
if(demoStart>=0){const a=time-demoStart,C=CHARS[char],schedule=C.demo;if(demoStage<schedule.length&&a>=schedule[demoStage][0]&&!cast){if(C.aimDemo)faceNearestTarget();startSkill(schedule[demoStage][1],true);demoStage++;}if(a>C.demoEnd&&demoStage>=schedule.length&&!cast){demoStart=-1;$('demo').classList.remove('active');toast('시연 완료 · Q / E / R 키로 직접 사용해보세요');}}
renderer.render(scene,camera);
}
{const q=new URLSearchParams(location.search).get('char');setCharacter(CHARS[q]?q:'gojo');}
// #debug exposes manual stepping so effects can be inspected while the tab is hidden and rAF is paused.
if(location.hash==='#debug')window.__lab={startSkill,setCharacter,faceNearestTarget,camera,targets,setYaw:v=>{yaw=v;},shot:()=>{renderer.render(scene,camera);return renderer.domElement.toDataURL('image/jpeg',.82);},pause:on=>{paused=on;previous=performance.now();},step:(n=1)=>{stepping=true;for(let i=0;i<n;i++)animate(previous+1000/60);stepping=false;}};
requestAnimationFrame(animate);$('loading').style.opacity=0;setTimeout(()=>$('loading').remove(),650);
// The initial scene stays controllable; auto demonstration is a deliberate user action.
