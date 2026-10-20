-- Roblox block hands only. Server owns healing, weakness, hit timing and cancellation.
local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local Lighting=game:GetService("Lighting")
local K=require(RS:WaitForChild("OkkotsuConfig"))
local VFX=require(RS:WaitForChild("OkkotsuVFX"))
local P=K.Colors
local player=Players.LocalPlayer
local O={};local env;local arms={};local views={};local transient={};local cast;local weakUntil=0
local shakeUntil,shakePower=0,0
local grade=Instance.new("ColorCorrectionEffect");grade.Name="OkkotsuCinematic";grade.Enabled=false;grade.Parent=Lighting
local root=Instance.new("Folder");root.Name="OkkotsuLocalFX";root.Parent=workspace
local function clock() return workspace:GetServerTimeNow() end
local function smooth(x) x=math.clamp(x,0,1);return x*x*(3-2*x) end
local function seg(a,b,c) return smooth((a-b)/(c-b)) end
local function part(parent,name,size,color,shape,material)
    local p=Instance.new("Part");p.Name=name;p.Size=size;p.Color=color;p.Shape=shape or Enum.PartType.Block;p.Material=material or Enum.Material.SmoothPlastic
    p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Parent=parent
    return p
end
local function model(name,parent) local m=Instance.new("Model");m.Name=name;m.Parent=parent or root;return m end
local function add(list,parent,name,size,cf,color,shape,material)
    local p=part(parent,name,size,color,shape,material);table.insert(list,{p=p,cf=cf});return p
end
local function line(list,parent,from,to,width,color)
    local d=(to-from).Magnitude
    return add(list,parent,"Tendon",Vector3.new(width,width,d+.01),CFrame.lookAt((from+to)/2,to),color,Enum.PartType.Block)
end
local function put(list,frame,alpha,scale)
    scale=scale or 1
    for _,x in list do
        x.p.CFrame=frame*CFrame.new(x.cf.Position*scale)*x.cf.Rotation
        if not x.size then x.size=x.p.Size end;x.p.Size=x.size*math.max(.001,scale);x.p.Transparency=alpha or 0
    end
end
local function effect(life,update,cleanup) table.insert(transient,{born=clock(),life=life,update=update,cleanup=cleanup}) end
local nextMote=0
local saya={};local healRings={};local healCore;local healLight
local function buildArm(side)
    local m=model("OkkotsuBlockHand",env.viewmodel);local fixed={};local skin=Color3.fromRGB(215,180,163)
    add(fixed,m,"Sleeve",Vector3.new(.25,.66,.27),CFrame.new(0,-.35,.035),Color3.fromRGB(17,23,35))
    add(fixed,m,"BlockHand",Vector3.new(.21,.23,.13),CFrame.new(0,.075,0),skin)
    if side<0 then
        for i=0,19 do local a=i*math.pi/10;local b=(i+1)*math.pi/10
            line(fixed,m,Vector3.new(.015+math.cos(a)*.024,.11+math.sin(a)*.024,.073),Vector3.new(.015+math.cos(b)*.024,.11+math.sin(b)*.024,.073),.008,P.Gold)
        end
        add(fixed,m,"RingGem",Vector3.new(.018,.024,.012),CFrame.new(.015,.13,.078),Color3.fromRGB(220,201,235),Enum.PartType.Ball,Enum.Material.Metal)
    end
    local a={m=m,fixed=fixed,sword={}}
    if side>0 then
        add(a.sword,m,"Grip",Vector3.new(.065,.25,.06),CFrame.new(0,.08,0),Color3.fromRGB(20,24,36))
        for i=0,6 do add(a.sword,m,"Wrap",Vector3.new(.05,.012,.005),CFrame.new(0,-.02+i*.032,.034)*CFrame.Angles(0,0,i%2==0 and .5 or -.5),Color3.fromRGB(204,198,189)) end
        add(a.sword,m,"Guard",Vector3.new(.26,.036,.16),CFrame.new(0,.23,0),P.Gold,Enum.PartType.Ball,Enum.Material.Metal)
        add(a.sword,m,"Blade",Vector3.new(.045,1.26,.014),CFrame.new(0,.87,0),Color3.fromRGB(211,226,233),nil,Enum.Material.Metal)
        add(a.sword,m,"Edge",Vector3.new(.006,1.26,.017),CFrame.new(-.024,.87,0),Color3.fromRGB(241,252,255),nil,Enum.Material.Neon)
    end
    return a
end
local function arm(a,frame,visible,swordVisible,fraction)
    local cf=workspace.CurrentCamera.CFrame*frame;local alpha=visible and 0 or 1;put(a.fixed,cf,alpha)
    local source=player.Character and (player.Character:FindFirstChild(a==arms[1] and "LeftHand" or "RightHand") or player.Character:FindFirstChild(a==arms[1] and "Left Arm" or "Right Arm"))
    if source then for _,entry in a.fixed do if entry.p.Name=="BlockHand" then entry.p.Color=source.Color end end end
    local sf=cf*CFrame.new(0,.14,0)*CFrame.Angles(-math.pi/2,0,0);put(a.sword,sf,visible and swordVisible and 0 or 1)
    fraction=fraction or 1
    for _,entry in a.sword do if entry.p.Name=="Blade" or entry.p.Name=="Edge" then
        entry.p.Size=Vector3.new(entry.size.X,math.max(.001,entry.size.Y*fraction),entry.size.Z)
        entry.p.CFrame=sf*CFrame.new(entry.cf.Position.X,.23+(entry.cf.Position.Y-.23)*fraction,entry.cf.Position.Z)
    end end
end
local function avatarSword(m,hidden)
    if not m then return end
    for _,p in m:GetChildren() do if p:IsA("BasePart") and (p.Name=="OkkotsuBlade" or p.Name=="OkkotsuGrip" or p.Name=="OkkotsuGuard") then p.LocalTransparencyModifier=hidden and 1 or 0 end end
end
local function actorFrame(m,direction)
    local head=m and m:FindFirstChild("Head");local rootPart=m and m:FindFirstChild("HumanoidRootPart")
    if not head or not rootPart then return end
    local flat=Vector3.new(direction.X,0,direction.Z);if flat.Magnitude<.01 then flat=rootPart.CFrame.LookVector else flat=flat.Unit end
    return CFrame.lookAt(head.Position,head.Position+flat)
end
function O.init(e)
    env=e;arms={buildArm(-1),buildArm(1)}
    local m=model("OkkotsuSaya",e.viewmodel)
    add(saya,m,"Scabbard",Vector3.new(.075,1.2,.06),CFrame.new(0,-.58,0),Color3.fromRGB(19,21,34))
    add(saya,m,"ScabbardMouth",Vector3.new(.11,.05,.09),CFrame.new(0,.02,0),Color3.fromRGB(142,124,100),Enum.PartType.Ball,Enum.Material.Metal)
    local lattice=model("ReverseCursedLattice",e.viewmodel)
    for i=1,3 do
        healRings[i]={}
        for j=0,23 do
            local a=j*math.pi/12;local b=(j+1)*math.pi/12
            local p=line(healRings[i],lattice,Vector3.new(math.cos(a)*.14,math.sin(a)*.14,0),Vector3.new(math.cos(b)*.14,math.sin(b)*.14,0),.005,P.Heal);p.Material=Enum.Material.Neon
        end
    end
    healCore=part(lattice,"HealingLight",Vector3.one*.01,P.Heal);healCore.Transparency=1
    healLight=Instance.new("PointLight");healLight.Color=P.Heal;healLight.Range=3;healLight.Brightness=0;healLight.Parent=healCore
end
function O.busy() return cast~=nil and clock()<cast.start+cast.duration end
function O.onEvent(kind,d)
    local own=d.owner==player.UserId
    if kind=="OkkotsuCast" then
        if own then
            cast=d
            env.announce(d.skill=="ReverseCursed" and "反転術式 · 반전술식" or d.skill=="PureLove" and "리카, 힘을 빌려줘" or "차원문 · 리카 휘둘러치기",d.skill=="ReverseCursed" and "최대 HP 50% 회복 · 공격력 -30% 10초" or d.skill=="PureLove" and "칼 수납 → 수인 → 함께 순애포" or "정면 5칸 · 왼쪽으로 쓸어 밀쳐냄")
        end
        if d.skill=="ReverseCursed" then VFX.sound("heal",d.position) end
        if d.skill=="PureLove" then if views[d.owner] then views[d.owner].rig.m:Destroy() end;views[d.owner]={data=d,rig=VFX.newRig()} end
    elseif kind=="OkkotsuHeal" then
        VFX.motes(d.position,P.Heal,26,true);VFX.ring(d.position-Vector3.yAxis*2.5,4,1,P.Heal);VFX.sound("release",d.position)
        if own then weakUntil=d.untilTime end
    elseif kind=="OkkotsuMark" then VFX.claw(d)
    elseif kind=="OkkotsuClaw" then
        VFX.motes(d.position,P.Aura,20,false);VFX.sound("hit",d.position)
        if own then shakeUntil=clock()+.32;shakePower=.075 end
    elseif kind=="OkkotsuLock" then
        local finish=d.position+d.direction*K.PureLove.Range
        local p=part(root,"PureLoveWarning",Vector3.new(.025,.025,(finish-d.position).Magnitude),P.Aura);p.Material=Enum.Material.Neon;p.CFrame=CFrame.lookAt((d.position+finish)/2,finish)
        effect(d.delay,function(u) p.Transparency=.7+.15*math.sin(u*12) end,function() p:Destroy() end)
        VFX.sound("charge",d.position)
    elseif kind=="OkkotsuBeam" then
        local v=views[d.owner];local m=Players:GetPlayerByUserId(d.owner);m=m and m.Character
        local cf=actorFrame(m,d.direction)
        local faceOrigin=v and v.faceOrigin or (cf and (cf*CFrame.new(.2,3,-2)).Position) or d.position+Vector3.yAxis*3
        local hand=own and (workspace.CurrentCamera.CFrame*CFrame.new(.065,.02,-1)).Position or (cf and (cf*CFrame.new(.1,0,-1.5)).Position) or d.position
        VFX.beam(d,faceOrigin,hand)
        if own then shakeUntil=clock()+.85;shakePower=.075 end
    elseif kind=="OkkotsuEnd" then
        if own then cast=nil end
        local v=views[d.owner];if v then v.rig.m:Destroy();views[d.owner]=nil end
        local owner=Players:GetPlayerByUserId(d.owner);avatarSword(owner and owner.Character,false);VFX.cancel(d.owner)
    end
end
function O.render(dt,info)
    local n=clock();local visible=info.isOkkotsu and info.alive;local out={fov=72}
    if cast and n>=cast.start+cast.duration then cast=nil end
    local bob=info.moving and math.sin(n*10)*.012 or math.sin(n*1.8)*.005
    local restL=CFrame.new(-.38,-.48+bob,-.76)*CFrame.Angles(.12,.2,-.28)
    local restR=CFrame.new(.42,-.4-bob,-.78)*CFrame.Angles(.12,-.18,.3)
    local l,r=restL,restR;local swordVisible=true;local fraction=1;local healK=0;local healAge=0;local healScale=.3
    if visible and info.melee and not cast then
        local me=info.melee;local a=n-me.start;local p=seg(a,0,me.windup);local hit=seg(a,me.windup,me.windup+me.swing);local k=1-seg(a,me.windup+me.swing,me.duration)
        r=CFrame.new(.42+(.2*p-.85*hit)*k,-.4+(.14*p-.3*hit)*k,-.78)*CFrame.Angles(.12,-.18+(.7*p-1.5*hit)*k,.3+(.7*p-1.8*hit)*k)
    end
    if visible and cast then
        local a=n-cast.start
        if cast.skill=="ReverseCursed" then
            local lift=seg(a,0,.48);local release=seg(a,1.15,1.8);local k=lift*(1-release)
            healK=k;healAge=a;healScale=.3+.7*lift
            l=CFrame.new(-.38+.23*k,-.48+.29*k,-.76+.17*k)*CFrame.Angles(.12-.85*k,.2+.25*k,-.28+.5*k)
            r=CFrame.new(.42+.13*k,-.4-.25*k,-.78)*CFrame.Angles(.12-.38*k,-.18,.3+.25*k)
            env.commonLook(CFrame.Angles(-.1*k,0,0));out.fov=72-5*k+4*seg(a,1.15,1.3)*(1-release)
            if n>=nextMote and a<1.18 then
                nextMote=n+.075;local center=(workspace.CurrentCamera.CFrame*CFrame.new(-.13,-.11,-.6)).Position
                VFX.motes(center,P.Heal,3,true)
                if a>.2 and math.floor(a/.2)~=math.floor((a-dt)/.2) then VFX.ring(center,.3,.35,P.Heal) end
            end
        elseif cast.skill=="RikaStrike" then
            local prep=seg(a,0,.16)*(1-seg(a,.76,1.05));local sweep=seg(a,.5,.74)*(1-seg(a,.78,1.08))
            l=CFrame.new(-.38-.08*prep-.12*sweep,-.48+.16*prep+.04*sweep,-.76-.1*prep)*CFrame.Angles(.12-.35*prep,.2,-.28-.15*prep-.5*sweep)
            env.commonLook(CFrame.Angles(.035*prep,0,-.045*sweep))
            out.fov=72+3*prep+5*sweep-5*seg(a,.82,1.12)
        else
            local k=seg(a,.8,1.25);local push=seg(a,3.1,3.2)*(1-seg(a,3.5,4.05));local back=seg(a,4.05,4.55);local h=k*(1-back)
            r=restR:Lerp(CFrame.new(.065,-.22,-.91)*CFrame.Angles(.04,-.12,-.035),h)*CFrame.new(0,-push*.025,-push*.15)
            l=restL:Lerp(CFrame.new(-.12,-.37,-.79)*CFrame.Angles(.2,-.45,-1.1),h)
            if a<.8 then
                local sheath=seg(a,0,.72)
                r=restR:Lerp(CFrame.new(-.34,-.68,-.61)*CFrame.Angles(-.15,-.18,-1.1),sheath)
                l=CFrame.new(-.43,-.65,-.63)*CFrame.Angles(.15,.1,-.9)
            end
            swordVisible=a<.8 or a>4.05;fraction=a<.8 and 1-seg(a,.25,.72) or seg(a,4.05,4.55)
            local recoil=seg(a,3.1,3.18)*(1-seg(a,3.35,4.2))
            env.commonLook(CFrame.Angles(.3*seg(a,1.05,1.8)*(1-seg(a,2.7,3.08))-.035*recoil,0,0))
            out.fov=72-7*seg(a,.85,1.4)*(1-seg(a,2.8,3.1))+13*recoil
        end
    end
    grade.Enabled=visible and cast~=nil
    if grade.Enabled then
        local a=n-cast.start;local heal=cast.skill=="ReverseCursed";local k=cast.skill=="PureLove" and seg(a,.75,1.9)*(1-seg(a,3.9,4.6)) or .3*seg(a,0,.6)*(1-seg(a,1.3,1.8))
        grade.TintColor=Color3.new(1,1,1):Lerp(heal and P.Heal or Color3.fromRGB(222,190,221),k*.18);grade.Brightness=-.1*k;grade.Contrast=.14*k;grade.Saturation=-.2*k
    end
    if visible and n<shakeUntil then local k=(shakeUntil-n)/.85;env.commonLook(CFrame.new(0,math.sin(n*87)*shakePower*.25*k,0)*CFrame.Angles(0,0,math.sin(n*73)*shakePower*k)) end
    if info.sliding then l*=CFrame.new(0,-.1,0);r*=CFrame.new(0,-.1,0) end
    arm(arms[1],l,visible,false,1);arm(arms[2],r,visible,swordVisible,fraction)
    put(saya,workspace.CurrentCamera.CFrame*CFrame.new(-.48,-.7,-.6)*CFrame.Angles(.12,0,-.9),visible and 0 or 1)
    local healFrame=workspace.CurrentCamera.CFrame*CFrame.new(-.13,-.11,-.6)*CFrame.Angles(healAge*.6,-healAge*2.5,healAge)
    for i,ring in healRings do put(ring,healFrame*CFrame.Angles((i-1)*.8,(i-1)*.6,i-1),1-.5*healK,healScale) end
    healCore.CFrame=healFrame;healLight.Brightness=1.2*healK
    for id,v in views do
        local d=v.data;local a=n-d.start;local owner=Players:GetPlayerByUserId(id);local m=owner and owner.Character;local h=m and m:FindFirstChildOfClass("Humanoid");local cf=actorFrame(m,d.direction)
        if not cf or not h or h.Health<=0 or owner:GetAttribute("Character")~="Okkotsu" or a>d.duration then
            v.rig.m:Destroy();avatarSword(m,false);views[id]=nil
        else
            avatarSword(m,a>.8 and a<4.05)
            if a>=.72 and not v.sheath then v.sheath=true;VFX.sound("sheath",cf.Position) end
            if a>=.92 and not v.manifest then
                v.manifest=true;VFX.sound("manifest",cf.Position)
                VFX.portal(cf.Position-d.direction*1.2+Vector3.yAxis*1.3,-d.direction)
            end
            v.faceOrigin=VFX.poseRig(v.rig,cf,a)
            if a>1.8 and a<3.1 and math.floor(a/.12)~=math.floor((a-dt)/.12) then VFX.motes(cf.Position+d.direction*4,P.Aura,3,true) end
        end
    end
    for i=#transient,1,-1 do local f=transient[i];local u=(n-f.born)/f.life;if u>=1 then f.cleanup();table.remove(transient,i) else f.update(u) end end
    VFX.render()
    local weaken=math.max(weakUntil,(player.Character and player.Character:GetAttribute("OkkotsuWeakenedUntil")) or 0)-n
    if visible and weaken>0 then out.weakened=weaken end
    return out
end
function O.reset()
    cast=nil;weakUntil=0;shakeUntil=0;grade.Enabled=false
    for id,v in views do v.rig.m:Destroy();local owner=Players:GetPlayerByUserId(id);avatarSword(owner and owner.Character,false) end;views={}
    for _,f in transient do f.cleanup() end;transient={};VFX.reset();avatarSword(player.Character,false)
end
return O
