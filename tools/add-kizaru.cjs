const fs=require('fs');
const read=p=>fs.readFileSync(p,'utf8').replace(/\r\n/g,'\n');
const write=(p,s)=>fs.writeFileSync(p,s.replace(/\r?\n/g,'\r\n'));
function edit(p,fn){write(p,fn(read(p)));}
function sub(s,a,b){if(!s.includes(a))throw Error('Missing anchor: '+a.slice(0,80));return s.replace(a,b);}
edit('preview/app.js',s=>{
 s=sub(s,'let pain=null,allmight=null,okkotsu=null;','let pain=null,allmight=null,okkotsu=null,kizaru=null;');
 s=sub(s,'const hpCosts=',"Object.assign(costs,{lightLaser:15,lightKick:24,lightJewels:55,lightMirror:12});Object.assign(durations,{lightLaser:5,lightKick:8,lightJewels:28,lightMirror:6});Object.assign(cooldowns,{lightLaser:0,lightKick:0,lightJewels:0,lightMirror:0});\nconst hpCosts=");
 const at=s.indexOf('CHARS.okkotsu=');
 s=s.slice(0,at)+`Object.assign(SKILLS,{
 lightLaser:{name:'손끝 레이저',type:'0.65초 준비 · 피해 42',icon:'burst-icon',glyph:'✧',accent:'#ffe18a'},
 lightKick:{name:'빛의 발차기',type:'0.85초 들어올림 → 광속 킥 · 피해 65',icon:'bolt-icon',glyph:'ϟ',accent:'#ffd34e'},
 lightJewels:{name:'야사카니의 곡옥',type:'1.25초 준비 → 빛의 탄막 12발',icon:'domain-icon',glyph:'✦',accent:'#fff0ba'},
 lightMirror:{name:'야타의 거울',type:'0.45초 빛 변환 → 전방 24 이동',icon:'dash-icon',glyph:'»',accent:'#ffe18a'}});
 CHARS.kizaru={name:'키자루',kanji:'黄猿 · ボルサリーノ',seal:'光',eyebrow:'CHARACTER 09 / GLINT-GLINT',desc:'느긋하게 모은 빛. 피할 틈 없이 터지는 한순간.<br>빛의 속도로 차여본 적 있나?',hud:'KIZARU',energy:'光 / LIGHT',hint:'<kbd>Q</kbd> 손끝 레이저 · <kbd>E</kbd> 빛의 발차기 · <kbd>R</kbd> 야사카니의 곡옥 · <kbd>SHIFT</kbd> 야타의 거울',demoToast:'손끝에 빛 → 느긋한 오른발 준비 · 광속 킥 → 곡옥 탄막 → 빛 이동',slots:{q:'lightLaser',e:'lightKick',r:'lightJewels',shift:'lightMirror'},demo:[[.5,'lightLaser',[0,1.3,-10]],[2,'lightKick',[0,1.3,-10]],[4,'lightJewels',[0,1.3,-10]],[7.5,'lightMirror']],demoEnd:9,demoPos:[0,2.1,-2]};
 `+s.slice(at);
 s=sub(s,'if(okkotsu?.skills.has(skill))','if(kizaru?.skills.has(skill))kizaru.begin(cast);if(okkotsu?.skills.has(skill))');
 s=sub(s,'if(c.okkotsu)okkotsu.update(c,a,dt);','if(c.kizaru)kizaru.update(c,a,dt);if(c.okkotsu)okkotsu.update(c,a,dt);');
 s=sub(s,'function reset(){','function reset(){kizaru?.reset();');
 s=sub(s,"pain?.activate(char==='pain');","kizaru?.activate(char==='kizaru');pain?.activate(char==='pain');");
 s=sub(s,"Digit8:'okkotsu'","Digit9:'kizaru',Digit8:'okkotsu'");
 s=sub(s,'okkotsu?.frame(dt,movement.lengthSq()>0);','okkotsu?.frame(dt,movement.lengthSq()>0);kizaru?.frame(dt);');
 s=sub(s,"else if(char==='okkotsu')okkotsu.hud();","else if(char==='kizaru')kizaru.hud();else if(char==='okkotsu')okkotsu.hud();");
 s=sub(s,'okkotsu=window.OkkotsuPreview?',`kizaru=window.KizaruPreview({T,scene,camera,basePos,targets,obstacles,hit,launch,burst,title,flash,wallOnRay,pose,left,right,hitstop:ms=>{hitstopUntil=Math.max(hitstopUntil,previous+ms);},get time(){return time},get cast(){return cast},get comfort(){return comfort},get muted(){return muted},get audio(){return audio}});
okkotsu=window.OkkotsuPreview?`);
 s=sub(s,'window.__lab={','window.__lab={kizaru:()=>kizaru.state(),');
 return s;
});
edit('preview/index.html',s=>sub(sub(s,'<button data-pick="okkotsu"','<button data-pick="kizaru" title="9">키자루</button><button data-pick="okkotsu"'),'<script src="okkotsu.js"></script>','<script src="okkotsu.js"></script>\n  <script src="kizaru.js"></script>'));
edit('preview/style.css',s=>s+`\nbody[data-char="kizaru"]{--accent:#ffdc77;--accent-rgb:255,220,119}body[data-char="kizaru"] .seal{color:#ffe49c}body[data-char="kizaru"] .skill{border-color:#6c5830}\n`);
edit('tools/build-preview.cjs',s=>sub(s,"const okkotsuTag=",`html=html.replace('<script src="kizaru.js"></script>',()=>'<script>\\n'+esc(p('kizaru.js'))+'\\n</script>');
const okkotsuTag=`));
edit('roblox/src/ReplicatedStorage/GojoConfig.luau',s=>sub(sub(s,'Kits = {','Kits = {\n        Kizaru = {"LightLaser","LightKick","LightJewels","LightMirror"},'),'    Blue = {',`    LightLaser = {Cost=15,Cooldown=5,Windup=.65,Duration=1.05,Damage=42,Range=90,Width=.8},
    LightKick = {Cost=24,Cooldown=8,Windup=.85,Duration=1.4,Damage=65,Range=12,Width=2.4},
    LightJewels = {Cost=55,Cooldown=28,Windup=1.25,Duration=2.8,Damage=12,Range=80,Width=1.25},
    LightMirror = {Cost=12,Cooldown=6,Windup=.45,Duration=.85,Range=24},
    Blue = {`));
edit('roblox/src/ServerScriptService/Combat.server.luau',s=>{
 s=sub(s,'local Okkotsu=require','local Kizaru=require(script.Parent:WaitForChild("KizaruServer"))\nlocal Okkotsu=require');
 s=sub(s,'    if Okkotsu.handles(skill) then','    if Kizaru.handles(skill) then\n        if kitOf(p)=="Kizaru" then Kizaru.request(p,s,m,h,r,skill,aim.Unit) end\n        return\n    end\n    if Okkotsu.handles(skill) then');
 s=sub(s,'    local noJump=','    if (m:GetAttribute("KizaruCastUntil") or 0)>n then speed*=.3 end\n    local noJump=(m:GetAttribute("KizaruCastUntil") or 0)>n or ');
 // Speed must be modified before it is assigned to the humanoid, below the other cast slows.
 s=sub(s,'    if (m:GetAttribute("OkkotsuCastUntil")','    if (m:GetAttribute("KizaruCastUntil") or 0)>n then speed*=.3 end\n    if (m:GetAttribute("OkkotsuCastUntil")');
 s=s.replace('    if (m:GetAttribute("KizaruCastUntil") or 0)>n then speed*=.3 end\n    local noJump=','    local noJump=');
 s=s.replaceAll('Okkotsu.reset(p)','Okkotsu.reset(p);Kizaru.reset(p)');
 s=sub(s,'Okkotsu.init({', 'Kizaru.init({fx=fx,states=states,clock=clock,character=character,targets=targets,damage=damage,updateSpeed=updateSpeed,sendState=sendState,launch=launch,kitOf=kitOf,held=AllMight.held})\nOkkotsu.init({');return s;
});
edit('roblox/src/ServerScriptService/Arena.server.luau',s=>sub(s,'    elseif kind=="Okkotsu" then',`    elseif kind=="Kizaru" then
        for _,side in {-1,1} do
            local lens=attach(head,"KizaruAmberLens",Vector3.new(.55,.32,.055),CFrame.new(side*.32,.08,-head.Size.Z/2-.06),Color3.fromRGB(185,125,44),Enum.Material.Glass)
            lens.Transparency=.25
            attach(head,"KizaruGlassesRim",Vector3.new(.59,.035,.065),CFrame.new(side*.32,.25,-head.Size.Z/2-.07),Color3.fromRGB(210,182,97),Enum.Material.Metal)
        end
        attach(head,"KizaruBridge",Vector3.new(.15,.035,.065),CFrame.new(0,.13,-head.Size.Z/2-.07),Color3.fromRGB(210,182,97),Enum.Material.Metal)
    elseif kind=="Okkotsu" then`));
edit('roblox/src/StarterPlayer/StarterPlayerScripts/Gojo.client.luau',s=>{
 s=sub(s,'local OkkotsuClient=require','local KizaruClient=require(script.Parent:WaitForChild("KizaruClient"))\nlocal OkkotsuClient=require');
 s=sub(s,'local KITS={',`local KITS={
    Kizaru={title="黄猿 · 키자루",energy="LIGHT",hint="Q 손끝 레이저 · E 빛의 발차기 · R 야사카니의 곡옥 · SHIFT 야타의 거울",handScale=1,
        slots={{"LightLaser","Q","손끝 레이저"},{"LightKick","E","빛의 발차기"},{"LightJewels","R","야사카니의 곡옥"},{"LightMirror","SHIFT","야타의 거울"}}},`);
 s=sub(s,'local function colorOf(kind) ','local function colorOf(kind) if string.sub(kind,1,5)=="Light" then return Color3.fromRGB(255,220,119) end ');
 s=sub(s,'local PICK_NAMES={','local PICK_NAMES={Kizaru="키자루",');
 s=sub(s,'"AllMight","Okkotsu"} do','"AllMight","Okkotsu","Kizaru"} do');
 s=sub(s,'UDim2.fromOffset(720,34)','UDim2.fromOffset(810,34)');
 s=sub(s,'OkkotsuClient.init({','KizaruClient.init({viewmodel=viewmodel,gui=gui,commonLook=commonLook,announce=announce})\nOkkotsuClient.init({');
 s=s.replaceAll('OkkotsuClient.reset()','OkkotsuClient.reset();KizaruClient.reset()');
 s=s.replaceAll('(current()=="Okkotsu" and OkkotsuClient.busy())','(current()=="Okkotsu" and OkkotsuClient.busy()) or (current()=="Kizaru" and KizaruClient.busy())');
 s=sub(s,'[Enum.KeyCode.Eight]="Okkotsu"','[Enum.KeyCode.Nine]="Kizaru",[Enum.KeyCode.Eight]="Okkotsu"');
 s=sub(s,'    if string.sub(kind,1,7)=="Okkotsu"','    if string.sub(kind,1,6)=="Kizaru" then KizaruClient.onEvent(kind,data);return end\n    if string.sub(kind,1,7)=="Okkotsu"');
 s=sub(s,'    local isOkkotsu=',`    local kizaruOut=KizaruClient.render(dt,current()=="Kizaru",h~=nil and h.Health>0)
    if kizaruOut then l=kizaruOut.left;r=kizaruOut.right;desiredFov=kizaruOut.fov end
    local isOkkotsu=`);
 s=sub(s,'local posed=zen or','local posed=kizaruOut~=nil or zen or');return s;
});
edit('tools/sync-rbxlx.cjs',s=>sub(sub(s,'const scripts = {',`const scripts = {
  KizaruServer: 'roblox/src/ServerScriptService/KizaruServer.luau',
  KizaruClient: 'roblox/src/StarterPlayer/StarterPlayerScripts/KizaruClient.luau',`),'const siblings={',"const siblings={KizaruServer:'PainServer',KizaruClient:'PainClient',"));
for(const p of ['preview/kizaru.js','roblox/src/ServerScriptService/KizaruServer.luau','roblox/src/StarterPlayer/StarterPlayerScripts/KizaruClient.luau'])write(p,read(p));
edit('README.md',s=>`## 키자루 — 9번 / 웹 \`?char=kizaru\`

원래 아바타에 호박색 안경만 붙입니다. 핵심은 느긋한 준비와 한순간의 황금빛 방출입니다. 자연계 상시 무적은 없습니다. 모든 스킬은 시전 중 이동 30%, 점프 제한을 가지며 피해·쿨타임·에너지는 서버가 판정합니다.

| 입력 | 준비 → 행동 → 결과 | 에너지 / 재사용 |
|---|---|---|
| Q 손끝 레이저 | 오른손을 들어 0.65초 빛을 모음 → 가는 백금색 광선 → 42 피해, 사거리 90, 1.05초에 복귀 | 15 / 5초 |
| E 빛의 발차기 | 0.85초 오른발을 느긋하게 들어 빛을 모음 → 0.12초 오른쪽에서 왼쪽으로 휘두름 → 65 피해·넉백, 사거리 12, 1.4초 복귀 | 24 / 8초 |
| R 야사카니의 곡옥 | 양손에 1.25초 빛을 모음 → 0.085초 간격으로 12발 탄막 → 발당 12 피해, 사거리 80, 2.8초 복귀 | 55 / 28초 |
| Shift 야타의 거울 | 0.45초 빛 변환 준비 → 전방 최대 24 이동·빛 잔상 → 0.85초 복귀 | 12 / 6초 |

조준은 시전 시작에 고정됩니다. 레이저와 탄막은 벽에 막히며 탄막은 퍼지므로 전탄 적중을 보장하지 않습니다. 야타의 거울은 반사 경로 대신 전방 직선 이동으로 구현한 프로토타입이며 벽 앞에서 정지합니다. 시전 중 사망·교체·영역 봉인·강제 이동은 남은 공격을 취소합니다. M1 평타와 Ctrl 슬라이딩은 공용입니다.

브라우저는 합성 충전음·발사음과 적중 히트스톱을 사용하고 Roblox는 내장 임시 효과음을 사용합니다. Roblox Studio 실행과 실제 아바타 손발 위치, 멀티플레이 및 모바일 성능은 검증하지 않았습니다.

`+s);
console.log('Kizaru wired; CRLF retained.');
