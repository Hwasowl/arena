local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local Tween=game:GetService("TweenService")
local Debris=game:GetService("Debris")
local Lighting=game:GetService("Lighting")
local player=Players.LocalPlayer
local C=require(RS:WaitForChild("GojoConfig"))
-- Warm audio while the avatar loads so the first charge/release stays on its visual beat.
do
    local preload={}
    for _,id in {C.SoundIds.Charge,C.SoundIds.Blast,C.SoundIds.Sword,"rbxasset://sounds/volume_slider.ogg","rbxasset://sounds/impact_explosion_03.mp3","rbxasset://sounds/action_falling.ogg"} do
        local s=Instance.new("Sound");s.Name="InfinityAudioPreload";s.SoundId=id;s.Volume=0;s.Parent=game:GetService("SoundService");table.insert(preload,s)
    end
    task.spawn(function()
        pcall(function() game:GetService("ContentProvider"):PreloadAsync(preload) end)
        for _,s in preload do s:Destroy() end
    end)
end
local visualCollisionGroup=RS:GetAttribute("ViewmodelCollisionGroup")
while not visualCollisionGroup do
    RS:GetAttributeChangedSignal("ViewmodelCollisionGroup"):Wait()
    visualCollisionGroup=RS:GetAttribute("ViewmodelCollisionGroup")
end
local action=RS:WaitForChild("GojoAction")
local aimRemote=RS:WaitForChild("GojoAim")
local nextAimAt=0
local event=RS:WaitForChild("GojoFX")
local selectRemote=RS:WaitForChild("SelectCharacter")
local GojoHands=require(script.Parent:WaitForChild("GojoHands"))
local PainClient=require(script.Parent:WaitForChild("PainClient"))
local KizaruClient=require(script.Parent:WaitForChild("KizaruClient"))
local OkkotsuClient=require(script.Parent:WaitForChild("OkkotsuClient"))
local AllMightClient=require(script.Parent:WaitForChild("AllMightClient"))
local camera=workspace.CurrentCamera
local effects=Instance.new("Folder");effects.Name="LocalGojoFX";effects.Parent=workspace
local viewmodel=Instance.new("Model");viewmodel.Name="GojoViewmodel";viewmodel.Parent=camera
GojoHands.init(viewmodel,visualCollisionGroup)
-- Body-fixed Doraemon accents. The white pocket is part of the abdomen, never a camera-floating prop.
local dora={rotorUntil=0,tool=nil,parts={}}
do
    local white=Color3.fromRGB(255,253,241);local ink=Color3.fromRGB(49,58,69);local gold=Color3.fromRGB(244,206,82)
    local function model(name,parent)
        local m=Instance.new("Model");m.Name=name;m.Parent=parent or viewmodel;dora.parts[m]={};return m
    end
    local function add(m,name,size,cf,color,shape)
        local p=Instance.new("Part");p.Name=name;p.Size=size;p.CFrame=cf;p.Color=color;p.Material=Enum.Material.SmoothPlastic
        if shape then p.Shape=shape end
        p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.LocalTransparencyModifier=1;p.Parent=m
        table.insert(dora.parts[m],{p=p,offset=cf});m.WorldPivot=CFrame.identity;return p
    end
    local function cylinder(m,name,radius,length,y,color)
        return add(m,name,Vector3.new(length,radius*2,radius*2),CFrame.new(0,y,0)*CFrame.Angles(0,0,math.pi/2),color,Enum.PartType.Cylinder)
    end
    dora.show=function(m,visible)
        for _,v in m:GetDescendants() do if v:IsA("BasePart") then local hidden=v.Name=="RedCollar" or v.Name=="Bell" or v.Name=="BellGroove" or v.Name=="BellSlot";v.LocalTransparencyModifier=(visible and not hidden) and 0 or 1 end end
    end
    dora.pocket=model("DoraemonAbdomen")
    dora.shirt=add(dora.pocket,"AvatarBodyCurve",Vector3.new(.96,1.6,.64),CFrame.new(0,-1.05,.06),Color3.fromRGB(12,19,35),Enum.PartType.Ball)
    -- A closed pocket with a curved upper rim, an interior mask, back wall and bottom.
    -- The wearer sees its silhouette from above; no front-facing belly panel is drawn.
    for i=0,47 do
        local a=i*math.pi/48;local b=(i+1)*math.pi/48
        local p1=Vector3.new(-.285*math.cos(a),-.7,-.3-.255*math.sin(a))
        local p2=Vector3.new(-.285*math.cos(b),-.7,-.3-.255*math.sin(b))
        local frame=CFrame.lookAt((p1+p2)/2,p2)
        add(dora.pocket,"PocketRim",Vector3.new(.022,.022,(p2-p1).Magnitude+.004),frame,white)
        add(dora.pocket,"PocketRimRound",Vector3.one*.022,CFrame.new(p1),white,Enum.PartType.Ball)
        add(dora.pocket,"PocketWall",Vector3.new(.022,.18,(p2-p1).Magnitude+.004),frame*CFrame.new(0,-.09,0),white)
    end
    add(dora.pocket,"PocketBackWall",Vector3.new(.57,.18,.02),CFrame.new(0,-.79,-.3),white)
    dora.lip=add(dora.pocket,"PocketLip",Vector3.new(.57,.018,.025),CFrame.new(0,-.696,-.3),white)
    for i=0,35 do
        local depth=(i+.5)*.216/36;local width=.504*math.sqrt(math.max(0,1-(depth/.216)^2))
        add(dora.pocket,"PocketInterior",Vector3.new(width,.006,.216/36+.0005),CFrame.new(0,-.728,-.318-depth),Color3.fromRGB(32,38,44))
        local floorDepth=(i+.5)*.245/36;local floorWidth=.554*math.sqrt(math.max(0,1-(floorDepth/.245)^2))
        add(dora.pocket,"PocketBottom",Vector3.new(floorWidth,.01,.245/36+.0005),CFrame.new(0,-.88,-.3-floorDepth),white)
    end
    dora.tools={}
    for _,kind in {"SmallLight","AirCannon","Dorayaki","Copter","Door"} do
        local g=model(kind);dora.tools[kind]=g
        if kind=="SmallLight" then
            cylinder(g,"PinkHandle",.045,.23,-.06,Color3.fromRGB(217,122,154))
            cylinder(g,"LampHead",.1,.13,.1,Color3.fromRGB(242,159,188))
            cylinder(g,"Lens",.087,.012,.17,Color3.fromRGB(255,249,212))
            add(g,"Switch",Vector3.new(.025,.04,.018),CFrame.new(0,-.04,-.048),Color3.fromRGB(119,207,180))
        elseif kind=="AirCannon" then
            add(g,"Barrel",Vector3.new(.29,.23,.23),CFrame.Angles(0,math.pi/2,0),Color3.fromRGB(168,173,180),Enum.PartType.Cylinder)
            add(g,"DarkMuzzle",Vector3.new(.008,.192,.192),CFrame.new(0,0,-.15)*CFrame.Angles(0,math.pi/2,0),ink,Enum.PartType.Cylinder)
            for i=0,19 do local a=i*math.pi/10;add(g,"MuzzleRim",Vector3.one*.035,CFrame.new(math.cos(a)*.11,math.sin(a)*.11,-.16),Color3.fromRGB(219,224,228),Enum.PartType.Ball) end
            add(g,"WristStrap",Vector3.new(.11,.065,.15),CFrame.new(0,-.105,.03),Color3.fromRGB(104,109,117))
        elseif kind=="Dorayaki" then
            add(g,"RedBeanFilling",Vector3.new(.29,.07,.26),CFrame.identity,Color3.fromRGB(92,48,40),Enum.PartType.Ball)
            for _,y in {-.038,.038} do add(g,"Pancake",Vector3.new(.3,.086,.27),CFrame.new(0,y,0),Color3.fromRGB(201,137,56),Enum.PartType.Ball) end
            cylinder(g,"BakedStamp",.024,.004,.081,Color3.fromRGB(168,106,43))
        elseif kind=="Copter" then
            cylinder(g,"BambooShaft",.012,.21,.015,gold);cylinder(g,"RotorHub",.04,.045,.13,gold)
            add(g,"TwoBlades",Vector3.new(.48,.014,.055),CFrame.new(0,.157,0),gold)
        else
            add(g,"MiniPinkDoor",Vector3.new(.2,.36,.025),CFrame.new(0,.08,0),Color3.fromRGB(241,140,170))
            add(g,"MiniDoorKnob",Vector3.one*.026,CFrame.new(.055,.07,-.035),gold,Enum.PartType.Ball)
        end
    end
    dora.makeDoor=function(parent)
        local g=model("AnywhereDoorFrame",parent);local pink=Color3.fromRGB(232,122,158)
        for _,x in {-1.05,1.05} do add(g,"DoorPost",Vector3.new(.18,3.7,.22),CFrame.new(x,1.85,0),pink) end
        add(g,"DoorLintel",Vector3.new(2.28,.18,.22),CFrame.new(0,3.7,0),pink)
        local portal=add(g,"DoorOpening",Vector3.new(1.94,3.48,.025),CFrame.new(0,1.85,.07),Color3.fromRGB(175,220,234));portal.Material=Enum.Material.Neon;portal.Transparency=.2
        local leaf=model("HingedPanel",g)
        add(leaf,"DoorPanel",Vector3.new(1.9,3.48,.1),CFrame.new(.95,1.74,0),pink)
        for _,y in {.93,2.56} do add(leaf,"InsetPanel",Vector3.new(1.48,1.12,.025),CFrame.new(.95,y,-.065),Color3.fromRGB(238,161,187)) end
        add(leaf,"DoorKnob",Vector3.one*.15,CFrame.new(1.65,1.65,-.13),gold,Enum.PartType.Ball)
        return g,leaf
    end
end
local blur=Instance.new("BlurEffect");blur.Size=0;blur.Parent=Lighting
local state={energy=100,cooldowns={},blueUntil=0,charges=0,chargesUntil=0}
local cast=nil
local melee=nil
local sliding=nil
local slideBufferedUntil=0
local attackQueued=false
local ZEN_DRAWS={Thunderclap=true,Godspeed=true,FlameGod=true}
local enGardeUntil=0
local bodyMoves={}
local commonViewOffset=CFrame.identity
local function commonLook(offset)
    camera.CFrame*=offset;commonViewOffset*=offset
end
local flameTurn=nil
local chinOffset=0
local CHIN_DIP=math.rad(7)
local holdState=nil
local slideUntil=0
local drawnUntil,fovKickUntil=0,0
local zenBasicUntil,zenGuardSign,zenSheathPlayed=0,1,true
local zenReadyPose
local rezeLookUntil,rezeAirUntil=0,0
local bombRecoil=nil
local blueOrbs,shots,activeEffects={},{},{}
local domainViews={}
local rushView=nil
local gojoCharges={}
-- Replace these built-in fallbacks with the uploaded gojo_domain_inside/end/break AssetIds.
local DOMAIN_SOUND_IDS={Inside="rbxasset://sounds/action_falling.ogg",End="rbxasset://sounds/volume_slider.ogg",Break="rbxasset://sounds/impact_explosion_03.mp3"}
local function smoothstep(x) x=math.clamp(x,0,1);return x*x*(3-2*x) end
local clock=workspace.GetServerTimeNow
local function time() return clock(workspace) end
local KITS={
    Kizaru={title="黄猿 · 키자루",energy="LIGHT",hint="Q 손끝 레이저 · E 빛의 발차기 · R 야사카니의 곡옥 · SHIFT 야타의 거울",handScale=1,
        slots={{"LightLaser","Q","손끝 레이저"},{"LightKick","E","빛의 발차기"},{"LightJewels","R","야사카니의 곡옥"},{"LightMirror","SHIFT","야타의 거울"}}},
    Okkotsu={title="乙骨 憂太  ·  옷코츠 유타",energy="CURSED ENERGY",hint="Q 반전술식 (회복 후 공격력 -30%) · E 차원문 리카 휘둘러치기 · R 칼 수납 → 수인 → 함께 순애포   /   SHIFT 대시",handScale=1,
        slots={{"ReverseCursed","Q","반전술식"},{"RikaStrike","E","리카 휘둘러치기"},{"PureLove","R","순애"},{"Dash","SHIFT","대시"}}},
    Gojo={title="五条 悟  ·  고죠 사토루",energy="CURSED ENERGY",hint="Q / E 3초 대기 · 그 안에 다른 쪽 = 무라사키 · 같은 키 = 즉시 발사   /   SHIFT 대시   /   1 · 2 · 3 캐릭터",
        handScale=1,
        slots={{"Blue","Q","아오"},{"Red","E","아카"},{"Domain","R","영역전개"},{"Dash","SHIFT","대시"}}},
    Zenitsu={title="我妻 善逸  ·  아가츠마 젠이츠",energy="BREATH",hint="Q 벽력일섬 · E 신속 1회 / 사용 시 이동속도 영구 −30% · R 화뢰신 / 반동 없음",
        handScale=1,
        slots={{"Thunderclap","Q","벽력일섬"},{"Godspeed","E","벽력일섬 신속"},{"FlameGod","R","화뢰신"},{"Dash","SHIFT","대시"}}},
    Reze={title="レゼ  ·  레제",energy="GUNPOWDER",hint="Q 0.4초 웅크려 상승 → 공중 Q 재입력 내려찍기 · E 오른손 폭발 · R 퓨즈 대폭발   /   SHIFT 대시   /   1 · 2 · 3 캐릭터",
        handScale=1,
        slots={{"Rampage","Q","상승 폭발"},{"Kick","E","오른손 폭발"},{"BombDevil","R","폭탄의 악마"},{"Dash","SHIFT","대시"}}},
    Shanks={title="赤髪のシャンクス  ·  샹크스",energy="HAKI",hint="Q 패기 발현 · E 자세 잡기 후 좌클릭 베기 / 우클릭 반격 · R 카무사리   /   SHIFT 대시",
        handScale=1,
        slots={{"Haki","Q","패기 발현"},{"EnGarde","E","내지르기 / 반격"},{"DivineDeparture","R","카무사리"},{"Dash","SHIFT","대시"}}},
    Doraemon={title="ドラえもん  ·  도라에몽",energy="GADGETS",hint="Q 주머니 랜덤 도구 · E 대나무 헬리콥터 3초 비행 · R 어디로든 문   /   SHIFT 대시",handScale=1,
        slots={{"Pocket","Q","주머니 뒤지기"},{"BambooCopter","E","대나무 헬리콥터"},{"AnywhereDoor","R","어디로든 문"},{"Dash","SHIFT","대시"}}},
    Pain={title="天道ペイン  ·  천도 페인",energy="CHAKRA",hint="Q 신라천정 밀어내기 · E 만상천인 끌어당기기 → 찌르기 · R 지폭천성   /   SHIFT 대시   /   6 캐릭터",handScale=1,
        slots={{"ShinraTensei","Q","신라천정"},{"BanshoTenin","E","만상천인"},{"ChibakuTensei","R","지폭천성"},{"Dash","SHIFT","대시"}}},
    AllMight={title="オールマイト  ·  올마이트",energy="ONE FOR ALL",hint="Q 풀 파워 10초 · E 유나이티드 스테이츠 오브 스매시 · R PLUS ULTRA (E 적중 직후 R 연계)   /   SHIFT 대시   /   7 캐릭터",handScale=1,
        slots={{"OneForAll","Q","원 포 올: 풀 파워"},{"UnitedStatesOfSmash","E","UNITED STATES OF SMASH"},{"PlusUltra","R","PLUS ULTRA!"},{"Dash","SHIFT","대시"}}},
}
local BOMB_KINDS={BombDevil=true,Rampage=true,Kick=true,Detonation=true}
local DORA_KINDS={Pocket=true,BambooCopter=true,AnywhereDoor=true}
local PAIN_KINDS={ShinraTensei=true,BanshoTenin=true,ChibakuTensei=true}
local ALLMIGHT_KINDS={OneForAll=true,UnitedStatesOfSmash=true,PlusUltra=true}
local function current() local name=player:GetAttribute("Character");return KITS[name] and name or "Gojo" end
local function colorOf(kind) if string.sub(kind,1,5)=="Light" then return Color3.fromRGB(255,220,119) end if kind=="ReverseCursed" then return Color3.fromRGB(112,255,203) end if kind=="RikaStrike" or kind=="PureLove" then return Color3.fromRGB(227,139,203) end if PAIN_KINDS[kind] then return Color3.fromRGB(176,132,255) end if ALLMIGHT_KINDS[kind] then return Color3.fromRGB(255,206,64) end return C.Colors[kind] or ((kind=="Haki" or kind=="EnGarde" or kind=="DivineDeparture") and C.Colors.Haki) or (BOMB_KINDS[kind] and C.Colors.Bomb) or (DORA_KINDS[kind] and C.Colors.Dora) or ((kind=="Thunderclap" or kind=="Godspeed" or kind=="FlameGod") and C.Colors.Thunder) or C.Colors.Purple end
local function part(parent,name,size,color,cf,shape)
    local p=Instance.new("Part");p.Name=name;p.Size=size;p.Color=color;p.CFrame=cf or CFrame.identity
    p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.CollisionGroup=visualCollisionGroup
    p.Material=Enum.Material.Neon;p.Shape=shape or Enum.PartType.Block;p.Parent=parent
    return p
end
local function tween(obj,duration,properties)
    Tween:Create(obj,TweenInfo.new(duration,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),properties):Play()
end
-- The old sword/ping/impact paths do not ship with the current Roblox client.
local SOUND_ALIASES={
    ["rbxasset://sounds/electronicpingshort.wav"]="rbxasset://sounds/volume_slider.ogg",
    ["rbxasset://sounds/electronicpingshort.mp3"]="rbxasset://sounds/volume_slider.ogg",
    ["rbxasset://sounds/impact_generic.mp3"]="rbxasset://sounds/impact_explosion_03.mp3",
    ["rbxasset://sounds/action_falling.mp3"]="rbxasset://sounds/action_falling.ogg",
    ["rbxasset://sounds/swordslash.wav"]=C.SoundIds.Sword,
    ["rbxasset://sounds/swordlunge.wav"]=C.SoundIds.Sword,
    ["rbxasset://sounds/swordunsheath.wav"]=C.SoundIds.Sword,
}
local function sound(id,position,volume,speed,duration)
    id=SOUND_ALIASES[id] or id
    local holder=part(effects,"SoundPoint",Vector3.one*.1,Color3.new(1,1,1),CFrame.new(position))
    holder.Transparency=1
    local s=Instance.new("Sound");s.SoundId=type(id)=="string" and id or "rbxassetid://"..id;s.Volume=volume;s.PlaybackSpeed=speed or 1
    s.RollOffMaxDistance=110;s.RollOffMinDistance=12;s.Parent=holder
    -- A public audio permission failure must still leave an audible local fallback.
    if string.find(s.SoundId,"rbxassetid://",1,true) then
        task.delay(.7,function()
            if s.Parent and not s.IsLoaded then s.SoundId="rbxasset://sounds/impact_explosion_03.mp3";s.PlaybackSpeed=.8;s:Play() end
        end)
    end
    s:Play();Debris:AddItem(holder,duration or 3)
    return s
end
local function stopGojoCharge(owner)
    local s=gojoCharges[owner];gojoCharges[owner]=nil
    if s and s.Parent then Tween:Create(s,TweenInfo.new(.12),{Volume=0}):Play();Debris:AddItem(s.Parent,.15) end
end
local function gojoCharge(owner,kind,position,duration)
    stopGojoCharge(owner)
    local s=sound(C.SoundIds.Charge,position,kind=="Purple" and .65 or .38,kind=="Red" and .85 or 1,duration+.5)
    s.Name="Gojo"..kind.."Charge";s.Looped=true
    local eq=Instance.new("EqualizerSoundEffect");eq.LowGain=kind=="Purple" and 6 or 0;eq.HighGain=kind=="Blue" and 3 or -2;eq.Parent=s
    gojoCharges[owner]=s
end
local function gojoRelease(kind,position)
    local s=sound(C.SoundIds.Blast,position,kind=="Purple" and .85 or .65,kind=="Purple" and .65 or 1.15,3)
    s.Name="Gojo"..kind.."Release"
    if kind=="Purple" or kind=="Domain" then sound("rbxasset://sounds/impact_explosion_03.mp3",position,.38,.65,3) end
end
local function temporary(seconds,update,cleanup)
    local effect={start=time(),duration=seconds,update=update,cleanup=cleanup}
    table.insert(activeEffects,effect)
    return effect
end
-- Pose the visible avatar on every client as well as the local first-person arms.
local function bodyMotion(data,isSlide)
    if isSlide and data.owner==player.UserId then return end
    local owner=Players:GetPlayerByUserId(data.owner);local m=owner and owner.Character
    if not m then return end
    if bodyMoves[data.owner] then bodyMoves[data.owner].cleanup() end
    local move={joints={},stopped=false}
    for _,joint in m:GetDescendants() do
        if joint:IsA("Motor6D") and joint.Part1 then
            local limb=joint.Part1.Name
            if limb=="Left Arm" or limb=="LeftUpperArm" or limb=="Right Arm" or limb=="RightUpperArm"
                or limb=="Torso" or limb=="LowerTorso" or limb=="Left Leg" or limb=="Right Leg" or limb=="LeftUpperLeg" or limb=="RightUpperLeg" then
                table.insert(move.joints,{joint=joint,base=joint.C0,limb=limb})
            end
        end
    end
    function move.cleanup()
        if move.stopped then return end
        move.stopped=true
        for _,j in move.joints do if j.joint.Parent then j.joint.C0=j.base end end
        if bodyMoves[data.owner]==move then bodyMoves[data.owner]=nil end
    end
    bodyMoves[data.owner]=move
    temporary(data.duration+.1,function()
        if move.stopped then return end
        if not m.Parent then move.cleanup();return end
        local age=time()-data.start
        local wind=isSlide and smoothstep(age/.12)*(1-smoothstep((age-data.duration+.18)/.18)) or smoothstep(age/data.windup)
        local strike=isSlide and 0 or smoothstep((age-data.windup)/data.swing)
        local recovery=isSlide and 0 or smoothstep((age-data.windup-data.swing)/(data.duration-data.windup-data.swing))
        local power=isSlide and wind or (wind-strike*.75)*(1-recovery)
        for _,j in move.joints do
            local offset=CFrame.identity
            if j.limb=="Torso" or j.limb=="LowerTorso" then
                offset=isSlide and CFrame.new(0,-.45*power,0)*CFrame.Angles(-.3*power,0,.08*power)
                    or CFrame.Angles(0,(data.combo%2==0 and -1 or 1)*.18*power,0)
            elseif string.find(j.limb,"Leg") then
                if isSlide then offset=CFrame.Angles((string.find(j.limb,"Left") and -.7 or .9)*power,0,0) end
            else
                local leftArm=string.find(j.limb,"Left")~=nil
                if isSlide then offset=CFrame.Angles(-.35*power,0,(leftArm and -.2 or .2)*power)
                elseif data.kit=="Zenitsu" or data.kit=="Shanks" then
                    local cut=(data.combo-1)%4+1
                    local rising=cut==1
                    local across=cut==3
                    local draw=data.draw and smoothstep(age/.34) or 1
                    local active=(1-recovery)*draw
                    if not leftArm then
                        local pitch=across and -.9 or rising and (.45-1.9*strike) or (-1.6+1.8*strike)
                        offset=CFrame.Angles(pitch*active,(across and (-.8+1.6*strike) or .4-.8*strike)*active,(rising and -.4 or .4)*wind*active)
                    elseif data.kit=="Zenitsu" then
                        offset=CFrame.Angles(-(.55+strike*.65)*active,.35*active,-.25*active)
                    end
                elseif leftArm==(data.combo==2) then offset=CFrame.Angles((-1.2*strike+.25*wind)*(1-recovery),0,(leftArm and -.3 or .3)*power) end
            end
            if j.joint.Parent then j.joint.C0=j.base*offset end
        end
    end,move.cleanup)
end
local function particles(p,color)
    local templates=RS:FindFirstChild("StoreVFX")
    if not templates then return end
    local count=0
    for _,source in templates:GetChildren() do
        if source:IsA("ParticleEmitter") and count<3 then
            count+=1;local e=source:Clone();e.Color=ColorSequence.new(color);e.Enabled=true;e.Parent=p
        end
    end
end
local function orb(position,color,radius)
    local m=Instance.new("Model");m.Name="EnergyOrb"
    local core=part(m,"Core",Vector3.one*radius*1.4,Color3.new(1,1,1),CFrame.new(position),Enum.PartType.Ball)
    m.PrimaryPart=core
    for i=1,3 do
        local shell=part(m,"Aura",Vector3.one*radius*(1.7+i*.45),color,CFrame.new(position),Enum.PartType.Ball)
        shell.Transparency=.55+i*.1
    end
    local light=Instance.new("PointLight");light.Color=color;light.Brightness=3;light.Range=radius*10;light.Parent=core
    particles(core,color)
    m.Parent=effects
    return m
end
local function clearCastVFX()
    if not cast then return end
    for _,o in cast.orbs or {} do o:Destroy() end
    cast.orbs={}
    if cast.merged then cast.merged:Destroy();cast.merged=nil end
end
local function zenDrawBody(data)
    if data.owner==player.UserId then return end
    local p=Players:GetPlayerByUserId(data.owner);local m=p and p.Character
    if not m then return end
    if bodyMoves[data.owner] then bodyMoves[data.owner].cleanup() end
    local cfg=C[data.kind];local move={joints={},stopped=false}
    for _,j in m:GetDescendants() do
        if j:IsA("Motor6D") and j.Part1 then table.insert(move.joints,{joint=j,base=j.C0,limb=j.Part1.Name}) end
    end
    function move.cleanup()
        if move.stopped then return end;move.stopped=true
        for _,v in move.joints do if v.joint.Parent then v.joint.C0=v.base end end
        if bodyMoves[data.owner]==move then bodyMoves[data.owner]=nil end
    end
    bodyMoves[data.owner]=move
    temporary(data.windup+cfg.RushDuration+.2,function()
        if move.stopped then return end
        if not m.Parent then move.cleanup();return end
        local age=time()-data.start
        local prep=smoothstep(age/math.min(data.windup,.22))
        local cut=smoothstep((age-data.windup)/cfg.RushDuration)
        local k=prep*(1-.8*cut)
        for _,v in move.joints do
            local limb=v.limb;local offset=CFrame.identity
            if limb=="LowerTorso" or limb=="Torso" then offset=CFrame.new(0,-.65*k,0)*CFrame.Angles(-.48*k,0,0)
            elseif limb=="UpperTorso" then offset=CFrame.Angles(-.28*k,.15*k,0)
            elseif limb=="Head" then offset=CFrame.Angles(.3*k,0,0)
            elseif limb=="LeftUpperLeg" or limb=="Left Leg" then offset=CFrame.Angles(-1.1*k,0,-.15*k)
            elseif limb=="RightUpperLeg" or limb=="Right Leg" then offset=CFrame.Angles(.5*k,0,.35*k)
            elseif limb=="LeftLowerLeg" then offset=CFrame.Angles(1.3*k,0,0)
            elseif limb=="RightLowerLeg" then offset=CFrame.Angles(1.05*k,0,0)
            elseif limb=="RightUpperArm" or limb=="Right Arm" then offset=CFrame.Angles(-.65*k,-.5*k,-.3*k+.8*cut)
            elseif limb=="LeftUpperArm" or limb=="Left Arm" then offset=CFrame.Angles(-.6*k,.45*k,.25*k)
            elseif limb=="RightLowerArm" then offset=CFrame.Angles(-.95*k,0,0)
            elseif limb=="LeftLowerArm" then offset=CFrame.Angles(-.8*k,0,0) end
            if v.joint.Parent then v.joint.C0=v.base*offset end
        end
    end,move.cleanup)
end
local function finishFlameTurn()
    local turn=flameTurn
    if not turn then return end
    flameTurn=nil
    if turn.humanoid.Parent then turn.humanoid.AutoRotate=turn.autoRotate end
    camera.CameraType=turn.cameraType
    blur.Size=0
end
local function burst(position,color,radius)
    local p=part(effects,"Shockwave",Vector3.one*.2,color,CFrame.new(position),Enum.PartType.Ball)
    p.Transparency=.35;tween(p,.45,{Size=Vector3.one*radius*2,Transparency=1});Debris:AddItem(p,.5)
    for i=1,18 do
        local direction=Vector3.new(math.random()-.5,math.random()-.5,math.random()-.5).Unit
        local q=part(effects,"Spark",Vector3.new(.09,.09,math.random()*1.1+.2),color,CFrame.lookAt(position,position+direction))
        tween(q,.4,{Position=position+direction*radius*1.6,Transparency=1});Debris:AddItem(q,.45)
    end
end
local function purpleRing(position,direction,radius,color)
    -- A hollow expanding ring keeps the sphere and targets visible through the pressure wave.
    local frame=CFrame.lookAt(position,position+direction)
    local ring=Instance.new("Model");ring.Name="PurplePressureRing";ring.Parent=effects
    local segments={}
    for i=1,24 do segments[i]=part(ring,"Arc",Vector3.one*.07,color or C.Colors.Purple) end
    temporary(.35,function(age)
        local u=math.clamp(age/.35,0,1);local r=radius*(1+1.5*smoothstep(u))
        for i,p in segments do
            local a=(i-1)*math.pi*2/#segments;local b=i*math.pi*2/#segments
            local from=(frame*CFrame.new(math.cos(a)*r,math.sin(a)*r,0)).Position
            local to=(frame*CFrame.new(math.cos(b)*r,math.sin(b)*r,0)).Position
            p.Size=Vector3.new(.07,.07,(to-from).Magnitude)
            p.CFrame=CFrame.lookAt(from,to)*CFrame.new(0,0,-(to-from).Magnitude/2)
            p.Transparency=.4+.6*u
        end
    end,function() ring:Destroy() end)
    Debris:AddItem(ring,.4)
end
-- Other players see the same two-sphere orbit and merge around the caster's elevated body.
local function showPurpleCharge(data)
    local cfg=C.Purple
    local pair={orb(data.position,C.Colors.Blue,cfg.ChargeRadius),orb(data.position,C.Colors.Red,cfg.ChargeRadius)}
    local merged=nil
    local function cleanup()
        for _,o in pair do o:Destroy() end;pair={}
        if merged then merged:Destroy();merged=nil end
    end
    temporary(math.max(.01,cfg.Windup-(time()-data.start)),function()
        local owner=Players:GetPlayerByUserId(data.owner)
        local m=owner and owner.Character;local head=m and m:FindFirstChild("Head")
        local h=m and m:FindFirstChildOfClass("Humanoid")
        if not (head and h and h.Health>0) then cleanup();return end
        local a=time()-data.start
        local focus=CFrame.lookAt(head.Position,head.Position+data.direction)
        local angle=smoothstep(a/cfg.RiseDuration)*math.pi*2
        local spread=1-smoothstep((a-cfg.Windup*.5)/(cfg.MergeAt-cfg.Windup*.5))
        if a<cfg.MergeAt then
            for i,o in pair do
                local side=i==1 and -1 or 1
                o:PivotTo(focus*CFrame.new(side*2.2*spread*math.cos(angle),.45+side*1.8*spread*math.sin(angle),-cfg.OrbDistance))
            end
        elseif a<cfg.Windup then
            if not merged then
                for _,o in pair do o:Destroy() end;pair={}
                merged=orb((focus*CFrame.new(0,0,-cfg.OrbDistance)).Position,C.Colors.Purple,cfg.MergedRadius)
                merged.PrimaryPart.Color=Color3.fromRGB(227,192,255)
            end
            merged:PivotTo(focus*CFrame.new(0,0,-cfg.OrbDistance))
        else cleanup() end
    end,cleanup)
end
-- Jagged neon lightning between two points; each segment fades on its own.
local function bolt(from,to,color,width,life)
    local dir=to-from;local length=dir.Magnitude
    if length<.1 then return end
    local right=dir:Cross(Vector3.yAxis);if right.Magnitude<.01 then right=Vector3.xAxis end;right=right.Unit
    local up=dir:Cross(right).Unit
    local count=math.max(4,math.floor(length/4));local previous=from
    for i=1,count do
        local jitter=math.min(3,length*.07)
        local point=i==count and to or from+dir*(i/count)+right*(math.random()-.5)*jitter*2+up*(math.random()-.5)*jitter*2
        local segment=part(effects,"Bolt",Vector3.new(width,width,(point-previous).Magnitude),color,CFrame.lookAt((previous+point)/2,point))
        tween(segment,life,{Transparency=1});Debris:AddItem(segment,life+.05)
        previous=point
    end
end
local function kamusariWave(from,to,width)
    local delta=to-from;local length=delta.Magnitude;if length<1 then return end
    local direction=delta.Unit;local startDistance=10;local visualLength=math.max(.1,length-startDistance);local bands={}
    local function band(name,w,h,color,transparency,material,yOffset)
        local origin=from+direction*startDistance;local p=part(effects,name,Vector3.new(w,h,.1),color,CFrame.lookAt(origin,origin+direction)*CFrame.new(0,yOffset or 0,0));p.Transparency=transparency
        if material then p.Material=material end
        table.insert(bands,{part=p,width=w,height=h,transparency=transparency,yOffset=yOffset or 0})
    end
    local vfx=4;local heightVfx=16
    band("KamusariBlackCut",width*.94*vfx,.38*heightVfx,Color3.fromRGB(5,5,9),.2,Enum.Material.SmoothPlastic,0)
    band("KamusariCrimsonCut",width*.72*vfx,.22*heightVfx,Color3.fromRGB(224,18,48),.04,nil,.06*heightVfx)
    band("KamusariWhiteEdge",width*.3*vfx,.09*heightVfx,Color3.fromRGB(255,249,245),.02,nil,.09*heightVfx)
    temporary(.52,function(age)
        local progress=smoothstep(math.clamp(age/.24,0,1));local fade=1-smoothstep(math.clamp((age-.24)/.28,0,1));local shown=math.max(.1,visualLength*progress)
        local center=from+direction*(startDistance+shown*.5);local frame=CFrame.lookAt(center,center+direction)
        for _,item in bands do
            item.part.Size=Vector3.new(item.width,item.height,shown);item.part.CFrame=frame*CFrame.new(0,item.yOffset,0);item.part.Transparency=item.transparency+(1-item.transparency)*(1-fade)
        end
    end,function() for _,item in bands do item.part:Destroy() end end)
    local right=direction:Cross(Vector3.yAxis);if right.Magnitude<.01 then right=Vector3.xAxis end;right=right.Unit
    local up=right:Cross(direction).Unit
    for i=1,14 do
        local vfx=4;local at=startDistance+visualLength*(.06+math.random()*.88);local offset=right*((math.random()-.5)*width*.86*vfx)+up*((math.random()-.5)*2.1*8)
        local start=from+direction*at+offset;local finish=start+direction*(5+math.random()*13)*vfx+right*((math.random()-.5)*1.1*vfx)+up*((math.random()-.5)*.8*8)
        bolt(start,finish,i%3==0 and Color3.new(1,1,1) or (i%3==1 and Color3.fromRGB(255,24,52) or Color3.fromRGB(60,6,18)),.44,.38)
    end
end
local function skyStrike(position,big)
    local width=big and .9 or .45
    bolt(position+Vector3.new((math.random()-.5)*8,60,(math.random()-.5)*8),position,Color3.fromRGB(255,244,196),width,big and .6 or .35)
    if big then
        for _=1,2 do bolt(position+Vector3.new((math.random()-.5)*16,60,(math.random()-.5)*16),position,C.Colors.Thunder,.45,.5) end
        burst(position,C.Colors.Thunder,9)
    else
        burst(position,C.Colors.Thunder,3)
    end
end

-- Reze's explosions: the engine Explosion for the flash and debris (no pressure, no joint breaking; damage is
-- server-side), plus a neon fireball and a few smoke puffs.
local function blast(position,radius)
    local e=Instance.new("Explosion");e.Position=position;e.BlastRadius=radius;e.BlastPressure=0
    e.DestroyJointRadiusPercent=0;e.ExplosionType=Enum.ExplosionType.NoCraters;e.Parent=effects
    local core=part(effects,"Fireball",Vector3.one*radius*.5,Color3.fromRGB(255,226,160),CFrame.new(position),Enum.PartType.Ball)
    tween(core,.35,{Size=Vector3.one*radius*1.5,Transparency=1,Color=C.Colors.Bomb});Debris:AddItem(core,.4)
    for _=1,4 do
        local puff=part(effects,"Smoke",Vector3.one*radius*.5,Color3.fromRGB(52,46,46),CFrame.new(position+Vector3.new(math.random()-.5,math.random()*.5,math.random()-.5)*radius*.6),Enum.PartType.Ball)
        puff.Material=Enum.Material.SmoothPlastic;puff.Transparency=.35
        tween(puff,1.4,{Size=Vector3.one*radius*1.1,Transparency=1,Position=puff.Position+Vector3.new(0,radius*.6,0)});Debris:AddItem(puff,1.5)
    end
    burst(position,C.Colors.Bomb,radius)
end
-- Seventh form: a lightning dragon that forms along the dash path and keeps flying past the end point,
-- so the user (already at the end) sees it surge ahead. Head leads, body follows in segments.
local function dragon(from,to)
    local flat=Vector3.new(to.X-from.X,0,to.Z-from.Z)
    if flat.Magnitude<.1 then flat=Vector3.new(0,0,-1) end
    flat=flat.Unit
    local side=flat:Cross(Vector3.yAxis)
    local dragonFrom=from+flat*2+side*4+Vector3.yAxis*3
    local dragonTo=to+flat*10+side*4+Vector3.yAxis*3
    local dragonScale=C.FlameGod.DragonScale
    local count=44
    local points={}
    local segments={}
    local function pathPoint(t,age)
        local envelope=math.sin(t*math.pi)
        local sway=math.sin(t*math.pi*2.5)*3.5+math.sin(t*math.pi*4-age*3)*.65
        local lift=math.sin(t*math.pi*2-age*2)*1.8
        return dragonFrom:Lerp(dragonTo,t)+(side*sway+Vector3.yAxis*lift)*envelope
    end
    -- Race alongside the caster and finish ahead, so the dragon stays visible without a forced turn.
    for i=0,count do
        local t=i/count
        points[i]=pathPoint(t,0)
    end
    local grow=C.FlameGod.RushDuration
    for i=1,count do
        local a,b=points[i-1],points[i];local thick=.62*dragonScale*(.45+.55*math.sin(i/count*math.pi/2))
        local body=part(effects,"DragonBody",Vector3.new(thick,thick,(b-a).Magnitude+.4),C.Colors.Thunder,CFrame.lookAt((a+b)/2,b),Enum.PartType.Ball)
        body.Transparency=1
        local core=part(effects,"DragonCore",Vector3.new(.2*dragonScale,.2*dragonScale,(b-a).Magnitude+.4),Color3.fromRGB(255,248,220),CFrame.lookAt((a+b)/2,b))
        core.Transparency=1
        table.insert(segments,{body=body,core=core})
        task.delay(grow*i/count,function()
            body.Transparency=.2;core.Transparency=0
            tween(body,2.2,{Transparency=1});tween(core,2,{Transparency=1})
            if i%3==0 then bolt(b,b+Vector3.new((math.random()-.5)*8,(math.random()-.3)*6,(math.random()-.5)*8),C.Colors.Thunder,.18,.3) end
        end)
        Debris:AddItem(body,grow+2.4);Debris:AddItem(core,grow+2.4)
    end
    -- Head: skull, snout, open jaw, horns and eyes, traveling along the growing body.
    local shape={
        {Vector3.new(1.53,1.19,1.87),CFrame.identity},
        {Vector3.new(1.02,.71,1.62),CFrame.new(0,.08,-1.53)},
        {Vector3.new(.94,.28,1.53),CFrame.new(0,-.6,-1.28)*CFrame.Angles(-.45,0,0)},
        {Vector3.new(.15,.15,1.87),CFrame.new(-.48,.77,.94)*CFrame.Angles(.55,-.2,0)},
        {Vector3.new(.15,.15,1.87),CFrame.new(.48,.77,.94)*CFrame.Angles(.55,.2,0)},
    }
    local headParts={}
    for _,piece in shape do table.insert(headParts,{part=part(effects,"DragonHead",piece[1],C.Colors.Thunder,CFrame.new()),offset=piece[2]}) end
    for _,x in {-.48,.48} do
        table.insert(headParts,{part=part(effects,"DragonEye",Vector3.one*.16,Color3.new(1,1,1),CFrame.new(),Enum.PartType.Ball),offset=CFrame.new(x,.37,-.77)})
    end
    for _,entry in headParts do
        entry.part.Size*=dragonScale
        entry.offset=CFrame.new(entry.offset.Position*dragonScale)*entry.offset.Rotation
        entry.part.Transparency=1;Debris:AddItem(entry.part,2.8)
    end
    local dragonBurst=false
    temporary(2.7,function(age)
        for i=0,count do points[i]=pathPoint(i/count,age) end
        for i,segment in segments do
            local a,b=points[i-1],points[i]
            local pose=CFrame.lookAt((a+b)/2,b)
            if segment.body.Parent then
                segment.body.CFrame=pose;segment.core.CFrame=pose
                segment.body.Size=Vector3.new(segment.body.Size.X,segment.body.Size.Y,(b-a).Magnitude+.4)
                segment.core.Size=Vector3.new(segment.core.Size.X,segment.core.Size.Y,(b-a).Magnitude+.4)
            end
        end
        local progress=math.clamp(age/grow,0,1)
        local along=progress*count
        local index=math.min(math.floor(along),count-1)
        local alpha=along-index
        local point=points[index]:Lerp(points[index+1],alpha)
        local tangent=(points[index+1]-points[index]).Unit
        local head=CFrame.lookAt(point,point+tangent)
        local fade=age<grow and 0 or math.clamp((age-grow)/2.2,0,1)
        for _,entry in headParts do
            entry.part.CFrame=head*entry.offset
            entry.part.Transparency=fade
        end
        if age>=grow and not dragonBurst then dragonBurst=true;burst(points[count],C.Colors.Thunder,5*dragonScale) end
    end,function() for _,entry in headParts do if entry.part.Parent then entry.part:Destroy() end end end)
end

-- Viewmodel pieces are posed every frame relative to the camera; sizes scale per character.
local function piece(list,name,size,offset,color,material,shape)
    local p=part(viewmodel,name,size,color,nil,shape);p.Material=material or Enum.Material.SmoothPlastic
    local entry={p=p,offset=offset,size=size};table.insert(list,entry);return entry
end
-- The rendered arms come from the player's loaded avatar, including R6/R15 body
-- meshes, skin colors and classic clothing. No kit-specific skin or sleeves.
local left={scale=1,avatar={}}
local right={scale=1,avatar={}}
local avatarRig=nil
local avatarDirty=true
local avatarConnections={}
local ARM_NAMES={Left={"Left Arm","LeftUpperArm","LeftLowerArm","LeftHand"},Right={"Right Arm","RightUpperArm","RightLowerArm","RightHand"}}
local function rebuildAvatarArms()
    avatarDirty=false
    if avatarRig then avatarRig:Destroy();avatarRig=nil end
    left.avatar={};right.avatar={};dora.torsoEntries={}
    local character=player.Character
    if not character or not character:FindFirstChildOfClass("Humanoid") then return end
    local archivable=character.Archivable;character.Archivable=true
    local rig=character:Clone();character.Archivable=archivable
    if not rig then return end
    rig.Name="AvatarArms"
    -- Keep the rig and clothing containers so Roblox renders classic shirt sleeves.
    for _,v in rig:GetDescendants() do
        if v:IsA("BaseScript") or v:IsA("ModuleScript") or v:IsA("Tool") or v:IsA("Accessory") or v:GetAttribute("Outfit") then
            v:Destroy()
        elseif v:IsA("BasePart") then
            v.CollisionGroup=visualCollisionGroup
            v.Anchored=true;v.CanCollide=false;v.CanTouch=false;v.CanQuery=false;v.CastShadow=false
            v.LocalTransparencyModifier=0;v.Transparency=1
        elseif v:IsA("Decal") then v.Transparency=1
        elseif v:IsA("Humanoid") then
            -- A display rig must never restore limb collisions or run character physics.
            v.EvaluateStateMachine=false;v.AutoRotate=false;v.AutomaticScalingEnabled=false
            v.RequiresNeck=false;v.BreakJointsOnDeath=false;v.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
        end
    end
    for side,hd in {Left=left,Right=right} do
        local names=ARM_NAMES[side]
        local palm=character:FindFirstChild(side.."Hand") or character:FindFirstChild(side.." Arm")
        if palm then
            local grip=palm.CFrame
            if palm.Name==side.." Arm" then grip*=CFrame.new(0,-palm.Size.Y/2+.16,0) end
            grip*=CFrame.Angles(0,0,math.pi)
            for _,name in names do
                local source=character:FindFirstChild(name);local clone=rig:FindFirstChild(name)
                if source and clone then
                    local meshes={}
                    for _,mesh in clone:GetChildren() do if mesh:IsA("SpecialMesh") then table.insert(meshes,{p=mesh,scale=mesh.Scale}) end end
                    table.insert(hd.avatar,{p=clone,source=source,size=source.Size,offset=grip:ToObjectSpace(source.CFrame),transparency=source.Transparency,meshes=meshes})
                end
            end
        end
    end
    -- Keep clothed torso surfaces for Doraemon's downward glance, using the same loaded avatar rig.
    local sourceRoot=character:FindFirstChild("HumanoidRootPart")
    if sourceRoot then
        for _,name in {"Torso","UpperTorso","LowerTorso"} do
            local source=character:FindFirstChild(name);local clone=rig:FindFirstChild(name)
            if source and clone then
                local meshes={};for _,child in clone:GetChildren() do if child:IsA("SpecialMesh") then table.insert(meshes,{p=child,scale=child.Scale}) end end
                table.insert(dora.torsoEntries,{p=clone,source=source,size=source.Size,offset=sourceRoot.CFrame:ToObjectSpace(source.CFrame),meshes=meshes})
            end
        end
    end
    -- Arms and cloth surfaces are rendered. Hidden root/legs would still form a humanoid
    -- collider even with state evaluation disabled, so remove them and all joints.
    local armParts={}
    for _,hd in {left,right} do for _,entry in hd.avatar do armParts[entry.p]=true end end
    for _,entry in dora.torsoEntries do armParts[entry.p]=true end
    for _,v in rig:GetDescendants() do
        if v:IsA("JointInstance") or v:IsA("Constraint") or v:IsA("Animator") or (v:IsA("BasePart") and not armParts[v]) then v:Destroy() end
    end
    rig.Parent=viewmodel;avatarRig=rig
end
local function watchAvatar(character)
    for _,connection in avatarConnections do connection:Disconnect() end
    avatarConnections={};avatarDirty=true
    local function changed(v)
        if v:IsA("BasePart") or v:IsA("Clothing") or v:IsA("BodyColors") or v:IsA("CharacterMesh") or v:IsA("Accessory") or v:IsA("SurfaceAppearance") then avatarDirty=true end
    end
    table.insert(avatarConnections,character.DescendantAdded:Connect(changed))
    table.insert(avatarConnections,character.DescendantRemoving:Connect(changed))
    local humanoid=character:FindFirstChildOfClass("Humanoid")
    if humanoid then table.insert(avatarConnections,humanoid.ApplyDescriptionFinished:Connect(function() avatarDirty=true end)) end
end
player.CharacterAdded:Connect(watchAvatar)
player.CharacterAppearanceLoaded:Connect(function(character) if character==player.Character then avatarDirty=true end end)
if player.Character then watchAvatar(player.Character) end
local function showAvatarArm(hd,frame,posed,alive)
    local swordArms=current()=="Zenitsu" or current()=="Shanks"
    local articulated=current()=="Gojo" or current()=="Zenitsu"
    local size=(articulated and .30 or swordArms and .26 or .42)*hd.scale
    for _,entry in hd.avatar do
        if entry.source.Parent then
            entry.p.Size=entry.size*size
            for _,mesh in entry.meshes do mesh.p.Scale=mesh.scale*size end
            entry.p.Color=entry.source.Color
            entry.p.CFrame=camera.CFrame*frame*CFrame.new(entry.offset.Position*size)*entry.offset.Rotation
            entry.p.Transparency=(alive and not articulated) and entry.transparency or 1
            entry.p.LocalTransparencyModifier=0
        else avatarDirty=true;entry.p.Transparency=1 end
    end
end
-- The choker stays outside the first-person view; this invisible target guides the pin-pull pose.
local RING_AT=CFrame.new(.05,-.635,-1.026)*CFrame.Angles(0,math.pi/2,0)
local pinPart=part(viewmodel,"Pin",Vector3.one*.01,Color3.fromRGB(205,210,218));pinPart.Transparency=1
local pinRing={}
for i=0,15 do
    local a,b=i/16*math.pi*2,(i+1)/16*math.pi*2
    local p0,p1=Vector3.new(0,math.cos(a)*.028,math.sin(a)*.028),Vector3.new(0,math.cos(b)*.028,math.sin(b)*.028)
    local seg=part(viewmodel,"PinRing",Vector3.new(.009,.009,(p1-p0).Magnitude+.003),Color3.fromRGB(205,210,218))
    seg.Material=Enum.Material.Metal
    table.insert(pinRing,{p=seg,offset=CFrame.lookAt((p0+p1)/2,p1)})
end
local holdOrb=part(viewmodel,"HoldOrb",Vector3.one*.16,C.Colors.Blue,nil,Enum.PartType.Ball)
local boot=part(viewmodel,"Boot",Vector3.new(.2,.16,.5),Color3.fromRGB(28,26,30),nil);boot.Material=Enum.Material.SmoothPlastic;boot.Transparency=1
-- Where the ring sits relative to the hooking hand, and the elbow-out hooking pose.
local PIN_IN_HAND=CFrame.new(-.03,.17,-.07)*CFrame.Angles(0,math.pi/2,0)
local HOOK=CFrame.Angles(-.15,-.2,1.25)
local function scaleHand(h,s) h.scale=s end
-- Zenitsu's sheathed katana. In the sword frame -Z runs from the tsuba toward the pommel, +Z into the saya.
-- One camera-local left-hip anchor is shared by idle, draw, attacks and resheath.
local ZEN_SAYA=CFrame.lookAt(Vector3.new(-.48,-.88,-1.10),Vector3.new(-.48,-.88,-1.10)+Vector3.new(.78,.30,-.55).Unit)
local katana={saya={},hilt={}}
local gold=Color3.fromRGB(201,162,74)
piece(katana.saya,"Saya",Vector3.new(.07,.085,1.45),CFrame.new(0,0,.76),Color3.fromRGB(43,34,51))
piece(katana.saya,"Koiguchi",Vector3.new(.08,.095,.08),CFrame.new(0,0,.06),gold,Enum.Material.Metal)
piece(katana.saya,"Kojiri",Vector3.new(.08,.095,.06),CFrame.new(0,0,1.46),gold,Enum.Material.Metal)
piece(katana.hilt,"Tsuba",Vector3.new(.026,.21,.21),CFrame.Angles(0,math.pi/2,0),Color3.fromRGB(42,37,34),Enum.Material.Metal,Enum.PartType.Cylinder)
piece(katana.hilt,"Tsuka",Vector3.new(.055,.065,.52),CFrame.new(0,0,-.28),Color3.fromRGB(241,234,216))
piece(katana.hilt,"Kashira",Vector3.new(.065,.075,.035),CFrame.new(0,0,-.55),gold,Enum.Material.Metal)
piece(katana.hilt,"Blade",Vector3.new(.014,.075,1.48),CFrame.new(0,-.005,.77),Color3.fromRGB(227,233,240),Enum.Material.Metal).drawnOnly=true
piece(katana.hilt,"Edge",Vector3.new(.018,.02,1.44),CFrame.new(0,-.035,.77),C.Colors.Thunder,Enum.Material.Neon).drawnOnly=true
local function place(list,frame) for _,entry in list do entry.p.CFrame=camera.CFrame*frame*entry.offset end end
local GRIP,SAYA=CFrame.new(0,-.01,-.24),CFrame.new(0,-.01,.32)
local RIGHT_UP,LEFT_UP=Vector3.new(-.4,.6,-.5).Unit,Vector3.new(.5,.65,-.4).Unit
-- Camera-space frame at `position` whose +Y (palm toward fingers) points along `up`.
local function armFrame(position,up)
    local side=up:Cross(Vector3.zAxis);if side.Magnitude<.01 then side=Vector3.xAxis end
    return CFrame.fromMatrix(position,side.Unit,up)
end

-- Same tilted cut planes and three-point hilt paths as preview/app.js.
local CUT_AXIS=Vector3.new(.42,.9,0).Unit
local SIDE_AXIS=Vector3.new(1,-.12,0).Unit
local SWORD_ORDER={"UP","DN","MID","DN"}
local SWORD_SWING={
    UP={axis=CUT_AXIS,points={Vector3.new(-.4,-.45,-.8),Vector3.new(-.05,-.3,-.95),Vector3.new(.4,-.05,-1)},a=-78,b=72,r0=0,r1=.7},
    DN={axis=CUT_AXIS,points={Vector3.new(.44,0,-.82),Vector3.new(.1,-.12,-.98),Vector3.new(-.28,-.34,-.9)},a=130,b=-18,r0=math.pi,r1=math.pi+.7},
    MID={axis=SIDE_AXIS,points={Vector3.new(-.4,-.1,-.62),Vector3.new(0,-.06,-.84),Vector3.new(.42,-.1,-.62)},a=-82,b=78,r0=math.pi,r1=math.pi},
}
local function swordKind(combo) return SWORD_ORDER[(combo-1)%#SWORD_ORDER+1] end
local function bladeAt(theta,axis) return (-Vector3.zAxis*math.cos(theta)+axis*math.sin(theta)).Unit end
local function swingAt(kind,u,pre)
    local k=SWORD_SWING[kind];local a,b,c=k.points[1],k.points[2],k.points[3]
    local control=b*2-(a+c)*.5
    local pos=a*(1-u)^2+control*(2*(1-u)*u)+c*u*u
    local theta=math.rad(k.a+(k.b-k.a)*u)-math.sign(k.b-k.a)*(pre or 0)
    return {pos=pos,dir=bladeAt(theta,k.axis),roll=k.r0+(k.r1-k.r0)*u,len=1}
end
local function swordSwingPose(kind,wind,strike,recovery,nextKind)
    local k=SWORD_SWING[kind]
    if recovery>0 then
        local ending,following=swingAt(kind,1),swingAt(nextKind,0)
        if nextKind=="UP" then following.roll+=math.pi*2 end
        local nextSwing=SWORD_SWING[nextKind]
        local dir=k.axis==nextSwing.axis and bladeAt(math.rad(k.b+(nextSwing.a-k.b)*recovery),k.axis) or ending.dir:Lerp(following.dir,recovery).Unit
        return {pos=ending.pos:Lerp(following.pos,recovery),dir=dir,roll=ending.roll+(following.roll-ending.roll)*recovery,len=1}
    end
    local pose=swingAt(kind,strike,.3*wind*(1-strike))
    pose.pos+=(k.points[1]-k.points[3]).Unit*(.1*wind*(1-strike))
    return pose
end
local function swordFrame(pos,dir,roll)
    -- Shortest rotation from blade +Z, matching Three.js setFromUnitVectors(BACK,dir).
    dir=dir.Unit;local dot=math.clamp(Vector3.zAxis:Dot(dir),-1,1);local axis=Vector3.zAxis:Cross(dir)
    local rotation=CFrame.identity
    if axis.Magnitude>.0001 then rotation=CFrame.fromAxisAngle(axis.Unit,math.acos(dot))
    elseif dot<0 then rotation=CFrame.Angles(0,math.pi,0) end
    return CFrame.new(pos)*rotation*CFrame.Angles(0,0,roll or 0)
end
local function swordGrip(hilt,offset,shoulder,roll)
    local at=(hilt*offset).Position
    return armFrame(at,(at-shoulder).Unit)*CFrame.Angles(0,(roll or 0)*.5,0)
end

local gui=Instance.new("ScreenGui");gui.Name="InfinityHUD";gui.ResetOnSpawn=false;gui.IgnoreGuiInset=true;gui.Parent=player:WaitForChild("PlayerGui")
local techniqueFlash=Instance.new("Frame");techniqueFlash.Name="TechniqueFlash";techniqueFlash.Size=UDim2.fromScale(1,1)
techniqueFlash.BackgroundTransparency=1;techniqueFlash.BorderSizePixel=0;techniqueFlash.ZIndex=30;techniqueFlash.Parent=gui
local function flashTechnique(color,strength)
    techniqueFlash.BackgroundColor3=color;techniqueFlash.BackgroundTransparency=1-strength
    Tween:Create(techniqueFlash,TweenInfo.new(.24),{BackgroundTransparency=1}):Play()
end
local function label(parent,text,size,pos,dim,color)
    local t=Instance.new("TextLabel");t.BackgroundTransparency=1;t.Text=text;t.Font=Enum.Font.GothamMedium;t.TextSize=size
    t.TextColor3=color or Color3.fromRGB(230,237,249);t.Position=pos;t.Size=dim;t.Parent=parent;return t
end
label(gui,"∞  INFINITY  /  SKILL LAB",19,UDim2.fromOffset(30,28),UDim2.fromOffset(380,32)).TextXAlignment=Enum.TextXAlignment.Left
local nameLabel=label(gui,"",13,UDim2.fromOffset(30,60),UDim2.fromOffset(380,28),Color3.fromRGB(144,169,195));nameLabel.TextXAlignment=Enum.TextXAlignment.Left
local cross=label(gui,"+",22,UDim2.fromScale(.5,.5),UDim2.fromOffset(22,22));cross.AnchorPoint=Vector2.new(.5,.5)
local title=label(gui,"",30,UDim2.fromScale(.5,.3),UDim2.fromOffset(560,45));title.AnchorPoint=Vector2.new(.5,.5)
local subtitle=label(gui,"",13,UDim2.fromScale(.5,.3)+UDim2.fromOffset(0,38),UDim2.fromOffset(560,28));subtitle.AnchorPoint=Vector2.new(.5,.5)
local health=label(gui,"",14,UDim2.new(0,30,1,-105),UDim2.fromOffset(250,30));health.TextXAlignment=Enum.TextXAlignment.Left
local energy=label(gui,"",13,UDim2.new(0,30,1,-73),UDim2.fromOffset(250,26),C.Colors.Blue);energy.TextXAlignment=Enum.TextXAlignment.Left
local panel=Instance.new("Frame");panel.Size=UDim2.fromOffset(480,70);panel.Position=UDim2.new(.5,0,1,-105);panel.AnchorPoint=Vector2.new(.5,0);panel.BackgroundTransparency=1;panel.Parent=gui
local scale=Instance.new("UIScale");scale.Parent=panel
local function inputDirection(skill)
    if skill~="Dash" then return camera.CFrame.LookVector end
    local forward=camera.CFrame.LookVector*Vector3.new(1,0,1)
    if forward.Magnitude<.01 then forward=Vector3.new(0,0,-1) end
    forward=forward.Unit
    local right=forward:Cross(Vector3.yAxis)
    local move=forward*((UIS:IsKeyDown(Enum.KeyCode.W) and 1 or 0)-(UIS:IsKeyDown(Enum.KeyCode.S) and 1 or 0))
        +right*((UIS:IsKeyDown(Enum.KeyCode.D) and 1 or 0)-(UIS:IsKeyDown(Enum.KeyCode.A) and 1 or 0))
    local h=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if move.Magnitude<.1 and h then move=h.MoveDirection*Vector3.new(1,0,1) end
    return move.Magnitude>.1 and move.Unit or forward
end
local buttons={}
for i=1,4 do
    local b=Instance.new("TextButton");b.Position=UDim2.fromOffset((i-1)*122,0);b.Size=UDim2.fromOffset(114,70)
    b.BackgroundColor3=Color3.fromRGB(14,21,34);b.BackgroundTransparency=.12;b.TextColor3=Color3.fromRGB(236,243,255)
    b.Font=Enum.Font.GothamMedium;b.TextSize=14;b.Parent=panel
    local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,10);corner.Parent=b
    local stroke=Instance.new("UIStroke");stroke.Thickness=1;stroke.Parent=b
    local entry={b=b,stroke=stroke};buttons[i]=entry
    b.Activated:Connect(function() if entry.skill then
        if current()=="Shanks" and entry.skill=="EnGarde" then enGardeUntil=time()+C.EnGarde.Window end
        action:FireServer(entry.skill,inputDirection(entry.skill),camera.CFrame.Position)
    end end)
end
local comboLabel=label(gui,"",26,UDim2.fromScale(.5,.62),UDim2.fromOffset(420,40),Color3.fromRGB(255,224,176));comboLabel.AnchorPoint=Vector2.new(.5,.5)
comboLabel.Font=Enum.Font.GothamBold;comboLabel.TextStrokeTransparency=.35;comboLabel.TextStrokeColor3=Color3.fromRGB(255,122,46)
local hint=label(gui,"",12,UDim2.new(.5,0,1,-26),UDim2.fromOffset(620,22),Color3.fromRGB(144,163,187));hint.AnchorPoint=Vector2.new(.5,0)
local blackout=Instance.new("Frame");blackout.Size=UDim2.fromScale(1,1);blackout.BackgroundColor3=Color3.new(0,0,0)
blackout.BackgroundTransparency=1;blackout.BorderSizePixel=0;blackout.ZIndex=10;blackout.Parent=gui
local picker=Instance.new("Frame");picker.Size=UDim2.fromOffset(810,34);picker.Position=UDim2.new(1,-30,0,28);picker.AnchorPoint=Vector2.new(1,0);picker.BackgroundTransparency=1;picker.Parent=gui
local pickButtons={}
local PICK_NAMES={Kizaru="키자루",Gojo="고죠",Zenitsu="젠이츠",Reze="레제",Shanks="샹크스",Doraemon="도라에몽",Pain="페인",AllMight="올마이트",Okkotsu="옷코츠"}
for i,name in {"Gojo","Zenitsu","Reze","Shanks","Doraemon","Pain","AllMight","Okkotsu","Kizaru"} do
    local b=Instance.new("TextButton");b.Size=UDim2.fromOffset(86,34);b.Position=UDim2.fromOffset((i-1)*90,0)
    b.Font=Enum.Font.GothamMedium;b.TextSize=13;b.Text=i.."  "..PICK_NAMES[name];b.Parent=picker
    local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,6);corner.Parent=b
    b.Activated:Connect(function() selectRemote:FireServer(name) end)
    pickButtons[name]=b
end
local function announce(name,sub)
    title.Text=name;subtitle.Text=sub;title.TextTransparency=0;subtitle.TextTransparency=0
    task.delay(2,function() tween(title,.6,{TextTransparency=1});tween(subtitle,.6,{TextTransparency=1}) end)
end
PainClient.init({viewmodel=viewmodel,gui=gui,commonLook=commonLook,announce=announce,blur=blur})
AllMightClient.init({viewmodel=viewmodel,gui=gui,commonLook=commonLook,announce=announce})
KizaruClient.init({viewmodel=viewmodel,gui=gui,commonLook=commonLook,announce=announce})
OkkotsuClient.init({viewmodel=viewmodel,gui=gui,commonLook=commonLook,announce=announce})
local function applyKit()
    local name=current();local kit=KITS[name]
    comboLabel.TextColor3=name=="Okkotsu" and Color3.fromRGB(239,181,222) or Color3.fromRGB(255,224,176)
    dora.rotorUntil=0
    nameLabel.Text=kit.title;hint.Text="M1 기본공격 · CTRL 슬라이딩   /   "..kit.hint
    energy.TextColor3=name=="Okkotsu" and colorOf("ReverseCursed") or name=="Zenitsu" and C.Colors.Thunder or name=="Reze" and C.Colors.Bomb or name=="Pain" and colorOf("ShinraTensei") or name=="AllMight" and colorOf("OneForAll") or C.Colors.Blue
    GojoHands.reset();PainClient.reset();AllMightClient.reset();OkkotsuClient.reset();KizaruClient.reset()
    for i,slot in kit.slots do
        local entry=buttons[i];entry.skill=slot[1];entry.key=slot[2];entry.name=slot[3]
        entry.stroke.Color=colorOf(slot[1]);if slot[1]=="Dash" then entry.stroke.Color=Color3.fromRGB(85,103,139) end
    end
    for pickName,b in pickButtons do
        local on=pickName==name
        b.BackgroundColor3=on and Color3.fromRGB(219,234,240) or Color3.fromRGB(14,21,34);b.TextColor3=on and Color3.fromRGB(16,34,54) or Color3.fromRGB(200,214,228)
    end
    for _,h in {left,right} do
        h.scale=kit.handScale
    end
    clearCastVFX();finishFlameTurn();stopGojoCharge(player.UserId)
    cast=nil;holdState=nil;melee=nil;sliding=nil;rushView=nil;attackQueued=false;drawnUntil=0;zenBasicUntil=0;zenReadyPose=nil;zenSheathPlayed=true;blackout.BackgroundTransparency=1;enGardeUntil=0
end
applyKit()
player:GetAttributeChangedSignal("Character"):Connect(applyKit)
local function requestBasic()
    local n=time()
    if current()=="Shanks" and enGardeUntil>n then action:FireServer("ShanksSlash",camera.CFrame.LookVector,camera.CFrame.Position);enGardeUntil=0;return end
    if melee then
        if melee.duration-(n-melee.start)<=.15 then attackQueued=true end
        return
    end
    if cast or holdState or sliding or (current()=="Pain" and PainClient.busy()) or (current()=="AllMight" and AllMightClient.busy()) or (current()=="Okkotsu" and OkkotsuClient.busy()) or (current()=="Kizaru" and KizaruClient.busy()) then return end
    action:FireServer("BasicAttack",camera.CFrame.LookVector,camera.CFrame.Position)
end
local function requestSlide()
    if (cast and cast.kind~="Dash") or holdState or melee or sliding or (current()=="Pain" and PainClient.busy()) or (current()=="AllMight" and AllMightClient.busy()) or (current()=="Okkotsu" and OkkotsuClient.busy()) or (current()=="Kizaru" and KizaruClient.busy()) then return end
    local h=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if h and h.FloorMaterial==Enum.Material.Air then slideBufferedUntil=time()+.18;return end
    action:FireServer("Slide",camera.CFrame.LookVector,camera.CFrame.Position)
end
local attackButton=Instance.new("TextButton");attackButton.Name="BasicAttackButton"
attackButton.Size=UDim2.fromOffset(100,46);attackButton.Position=UDim2.new(1,-118,1,-174)
attackButton.Text="M1  기본공격";attackButton.TextSize=13;attackButton.Font=Enum.Font.GothamMedium
attackButton.BackgroundColor3=Color3.fromRGB(24,36,48);attackButton.TextColor3=Color3.fromRGB(235,243,250);attackButton.Parent=gui
local attackCorner=Instance.new("UICorner");attackCorner.CornerRadius=UDim.new(0,8);attackCorner.Parent=attackButton
attackButton.Activated:Connect(requestBasic)
local slideButton=attackButton:Clone();slideButton.Name="SlideButton";slideButton.Position=UDim2.new(1,-118,1,-226)
slideButton.Text="CTRL  슬라이딩";slideButton.Parent=gui;slideButton.Activated:Connect(requestSlide)
UIS.InputBegan:Connect(function(input,processed)
    if input.UserInputType==Enum.UserInputType.MouseButton2 and current()=="Shanks" and enGardeUntil>time() then
        action:FireServer("ShanksParry",camera.CFrame.LookVector,camera.CFrame.Position);enGardeUntil=0;return
    end
    if processed then return end
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.KeyCode==Enum.KeyCode.ButtonR2 then requestBasic();return end
    if input.KeyCode==Enum.KeyCode.LeftControl or input.KeyCode==Enum.KeyCode.RightControl or input.KeyCode==Enum.KeyCode.ButtonB then requestSlide();return end
    local pick=({[Enum.KeyCode.One]="Gojo",[Enum.KeyCode.Two]="Zenitsu",[Enum.KeyCode.Three]="Reze",[Enum.KeyCode.Four]="Shanks",[Enum.KeyCode.Five]="Doraemon",[Enum.KeyCode.Six]="Pain",[Enum.KeyCode.Seven]="AllMight",[Enum.KeyCode.Nine]="Kizaru",[Enum.KeyCode.Eight]="Okkotsu"})[input.KeyCode]
    if pick then selectRemote:FireServer(pick);return end
    local slot=({[Enum.KeyCode.Q]=1,[Enum.KeyCode.E]=2,[Enum.KeyCode.R]=3,[Enum.KeyCode.LeftShift]=4})[input.KeyCode]
    if slot then
        if current()=="Shanks" and slot==2 then enGardeUntil=time()+C.EnGarde.Window end
        action:FireServer(buttons[slot].skill,inputDirection(buttons[slot].skill),camera.CFrame.Position)
    end
end)
action.OnClientEvent:Connect(function(s) state=s end)
UIS.JumpRequest:Connect(function()
    local movementRush=rushView and rushView.locomotion
    if sliding or movementRush or (cast and cast.kind=="Dash") then
        action:FireServer("MoveJump",camera.CFrame.LookVector,camera.CFrame.Position)
        sliding=nil
        if cast and cast.kind=="Dash" then clearCastVFX();cast=nil end
        if movementRush then rushView=nil end
        local m=player.Character;local h=m and m:FindFirstChildOfClass("Humanoid");local r=m and m:FindFirstChild("HumanoidRootPart")
        if h and r and h.FloorMaterial~=Enum.Material.Air then
            local v=r.AssemblyLinearVelocity;local flat=v*Vector3.new(1,0,1)
            if flat.Magnitude>C.Slide.StartSpeed then flat=flat.Unit*C.Slide.StartSpeed end
            r.AssemblyLinearVelocity=flat+Vector3.yAxis*v.Y
            h.Jump=true;h:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

event.OnClientEvent:Connect(function(kind,data)
    if string.sub(kind,1,6)=="Kizaru" then KizaruClient.onEvent(kind,data);return end
    if string.sub(kind,1,7)=="Okkotsu" then OkkotsuClient.onEvent(kind,data);return end
    if string.sub(kind,1,4)=="Pain" then PainClient.onEvent(kind,data);return end
    if string.sub(kind,1,8)=="AllMight" then AllMightClient.onEvent(kind,data);return end
    if kind=="Rush" then
        if data.owner==player.UserId then
            rushView={start=data.start,duration=data.duration,from=data.from,to=data.to,locomotion=data.locomotion}
            sound(C.SoundIds.Sword,camera.CFrame.Position,.3,1.8,.55)
        end
    elseif kind=="BasicAttack" then
        bodyMotion(data,false)
        if data.owner==player.UserId then
            melee=data;attackQueued=false
            if data.kit=="Zenitsu" then
                zenReadyPose=nil
                zenBasicUntil=data.start+data.duration+C.ZenBasicAttack.ComboReset
                zenGuardSign=data.combo+1
                zenSheathPlayed=false
            end
        end
        if data.kit=="Zenitsu" and data.draw then sound("rbxasset://sounds/swordunsheath.wav",data.position,.4,.8,.8) end
        task.delay(math.max(0,data.start+data.windup-time()),function()
            local owner=Players:GetPlayerByUserId(data.owner);local root=owner and owner.Character and owner.Character:FindFirstChild("HumanoidRootPart")
            if not root then return end
            sound("rbxasset://sounds/swordslash.wav",root.Position,.4,data.kit=="Zenitsu" and 1.25 or .75,.8)
            if data.kit=="Zenitsu" then
                local origin=root.Position+Vector3.yAxis
                local flat=Vector3.new(data.direction.X,0,data.direction.Z);flat=flat.Magnitude>.05 and flat.Unit or Vector3.new(0,0,-1)
                local side=flat:Cross(Vector3.yAxis)
                bolt(origin+flat*2+side*2,origin+flat*4-side*2,C.Colors.Thunder,.07,.14)
            end
        end)
    elseif kind=="MeleeHit" then
        burst(data.position,Color3.fromRGB(235,243,250),1.4)
        sound("rbxasset://sounds/swordlunge.wav",data.position,.5,((data.kit=="Zenitsu" and data.combo==4) or (data.kit~="Zenitsu" and data.combo==3)) and .6 or .85,.8)
        if data.owner==player.UserId then
            if melee then melee.hitUntil=time()+.065;melee.hitAge=melee.windup+melee.swing*.6 end
            cross.Text="×";task.delay(.15,function() cross.Text="+" end)
        end
    elseif kind=="ShanksEnGarde" then
        if data.owner==player.UserId then enGardeUntil=data.untilTime end
        announce("赤髪の剣技","E 자세 · 좌클릭 내지르기 / 우클릭 1초 무적 반격");sound("rbxasset://sounds/swordslash.wav",data.position,.4,.65,.8)
    elseif kind=="ShanksSlash" then
        if data.owner==player.UserId then cast={kind="ShanksSlash",start=data.start or time(),length=.8,hold=.1,direction=data.direction,orbs={}} end
        local owner=Players:GetPlayerByUserId(data.owner);local root=owner and owner.Character and owner.Character:FindFirstChild("HumanoidRootPart")
        if root then burst(root.Position+data.direction*3,C.Colors.Haki,2);sound("rbxasset://sounds/swordslash.wav",root.Position,.7,.6,.8) end
    elseif kind=="ShanksParry" then
        if data.owner==player.UserId then enGardeUntil=0 end
        if data.owner==player.UserId then cast={kind="ShanksParry",start=time(),length=data.duration,hold=.1,direction=camera.CFrame.LookVector,orbs={}} end
        announce("패기 반격","1초간 공격 무시 · 공격을 받아내면 앞찌르기");sound("rbxasset://sounds/swordslash.wav",data.position,.5,.4,1)
    elseif kind=="ShanksCounter" then
        burst(data.position,C.Colors.Haki,3);sound("rbxasset://sounds/swordlunge.wav",data.position,.8,.5,.8)
    elseif kind=="HakiAwaken" then
        announce("覇王色の覇気","패왕색 패기 · 시야가 흔들린 뒤 주변 적을 압박한다");blur.Size=12;tween(blur,.5,{Size=0})
    elseif kind=="HakiPulse" then
        burst(data.position,C.Colors.Haki,data.radius);if data.owner==player.UserId then sound("rbxasset://sounds/electronicpingshort.wav",data.position,.6,.55,.5) end
    elseif kind=="DivineDeparture" then
        kamusariWave(data.from,data.to,data.width);blur.Size=9;tween(blur,.25,{Size=0});sound("rbxasset://sounds/swordslash.wav",data.from,.8,.45,1)
    elseif kind=="Slide" then
        bodyMotion(data,true)
        sound("rbxasset://sounds/swordlunge.wav",data.position,.35,.6,1)
        if data.owner==player.UserId then sliding=data;melee=nil;attackQueued=false;if cast and cast.kind=="Dash" then clearCastVFX();cast=nil end;rushView=nil end
        temporary(data.duration,function(age)
            local owner=Players:GetPlayerByUserId(data.owner);local root=owner and owner.Character and owner.Character:FindFirstChild("HumanoidRootPart")
            if root and (root.Parent:GetAttribute("SlidingUntil") or 0)>time() and age>(data.nextDust or 0) then
                data.nextDust=age+.08
                burst(root.Position-Vector3.yAxis*2.7-data.direction*1.5,Color3.fromRGB(122,137,147),.65)
            end
        end,function() end)
    elseif kind=="SlideEnd" then
        if bodyMoves[data.owner] then bodyMoves[data.owner].cleanup() end
        if data.owner==player.UserId then sliding=nil end
    elseif kind=="Cast" then
        if ZEN_DRAWS[data.kind] then zenDrawBody(data) end
        if data.kind=="Blue" or data.kind=="Red" or data.kind=="Purple" or data.kind=="Domain" then
            stopGojoCharge(data.owner)
            if data.kind=="Purple" or data.kind=="Domain" then gojoCharge(data.owner,data.kind,data.position,data.windup) end
        end
        if data.kind=="AnywhereDoor" then
            local flat=Vector3.new(data.direction.X,0,data.direction.Z);flat=flat.Magnitude>.01 and flat.Unit or Vector3.new(0,0,-1)
            local frame=CFrame.lookAt(data.position-Vector3.yAxis*3+flat*3,data.position-Vector3.yAxis*3+flat*4)
            local door,leaf=dora.makeDoor(effects);door:ScaleTo(1.6)
            temporary(3,function(age)
                local ageFromCast=time()-data.start
                dora.show(door,ageFromCast>=1.45 and ageFromCast<2.8)
                door:PivotTo(frame);leaf:PivotTo(frame*CFrame.new(-1.52,.16,-.08)*CFrame.Angles(0,-1.65*smoothstep((ageFromCast-1.72)/.4),0))
            end,function() dora.parts[door]=nil;dora.parts[leaf]=nil;door:Destroy() end)
        end
        if data.kind=="Blue" then task.delay(.42,function() sound(9114427347,data.position,.75,1,2) end) end
        if data.kind=="Purple" or data.kind=="Domain" then sound(9112775414,data.position,.35,.8,3) end
        if data.kind=="Detonation" then
            -- Danger zone: a ring at the blast radius that pulses faster as the fuse runs out.
            local ring=part(effects,"DetonationWarning",Vector3.new(.15,C.Detonation.Radius*2,C.Detonation.Radius*2),C.Colors.Bomb,CFrame.new(data.position-Vector3.new(0,2.85,0))*CFrame.Angles(0,0,math.pi/2),Enum.PartType.Cylinder)
            ring.Transparency=.8
            local length=data.windup
            temporary(length,function(age)
                local owner=Players:GetPlayerByUserId(data.owner);local root=owner and owner.Character and owner.Character:FindFirstChild("HumanoidRootPart")
                if root then ring.CFrame=CFrame.new(root.Position-Vector3.new(0,2.85,0))*CFrame.Angles(0,0,math.pi/2) end
                ring.Transparency=.55+.35*math.sin(age*(4+age*age*3))
            end,function() ring:Destroy() end)
        end
        if data.owner==player.UserId then
            holdState=nil;clearCastVFX()
            if data.kind=="Dash" then sliding=nil end
            local length=data.windup or C[data.kind].Windup or .2
            cast={kind=data.kind,start=(data.kind=="Purple" or DORA_KINDS[data.kind] or ZEN_DRAWS[data.kind]) and data.start or time(),direction=data.direction,length=length,phase=data.phase,orbs={},hold=data.kind=="Purple" and C.Purple.Recovery or ZEN_DRAWS[data.kind] and (C[data.kind].RushDuration+.15) or data.kind=="Kick" and .32 or DORA_KINDS[data.kind] and (C[data.kind].Recovery or .35) or .15}
            if data.kind=="Purple" then
                local cfg=C.Purple
                cast.orbs={orb((camera.CFrame*CFrame.new(-2.2,.1,-cfg.OrbDistance)).Position,C.Colors.Blue,cfg.ChargeRadius),orb((camera.CFrame*CFrame.new(2.2,.1,-cfg.OrbDistance)).Position,C.Colors.Red,cfg.ChargeRadius)}
                local m=player.Character;local h=m and m:FindFirstChildOfClass("Humanoid")
                if h then h:ChangeState(Enum.HumanoidStateType.Freefall) end
                announce("虚式 • 茈","아오 + 아카  /  무라사키")
            elseif data.kind=="Domain" then announce("領域展開","무량공처 · UNLIMITED VOID")
            elseif data.kind=="Blue" then announce("術式順転 • 蒼","아오 · 인력")
            elseif data.kind=="Red" then announce("術式反転 • 赫","아카 · 척력")
            elseif data.kind=="Thunderclap" then announce("雷の呼吸 • 壱ノ型","벽력일섬 · 고정 발도")
            elseif data.kind=="Godspeed" then announce("霹靂一閃 • 神速","신속 · 이번 생 1회 · 이동속도 영구 −30%")
            elseif data.kind=="FlameGod" then announce("雷の呼吸 • 漆ノ型","화뢰신 · 火雷神 · 벽력일섬을 초월한 발도")
            elseif data.kind=="BombDevil" then announce("レゼ","쵸커의 핀을 당긴다")
            elseif data.kind=="Kick" then announce("爆弾の悪魔","오른손을 뻗고 0.8초 뒤 전방 폭발")
            elseif data.kind=="Detonation" then announce("大爆発","4초 퓨즈 · 점점 느려지며 범위가 몸을 따라온다 · HP 12%")
            elseif data.kind=="Pocket" then announce("四次元ポケット","도구가 나올 때까지 뒤적이는 중… · 랜덤 선택")
            elseif data.kind=="BambooCopter" then announce("タケコプター","주머니에서 꺼내 머리에 꽂는다 · 3초 비행")
            elseif data.kind=="AnywhereDoor" then announce("どこでもドア","문을 열고 전방으로 이동") end
        else
            if data.kind=="Purple" then showPurpleCharge(data) else burst(data.position,colorOf(data.kind),3) end
        end
    elseif kind=="Thunderclap" then
        local below=Vector3.new(0,-2.4,0)
        bolt(data.from+below,data.to+below,C.Colors.Thunder,.5,.6)
        bolt(data.from+below*.4,data.to+below*1.1,Color3.fromRGB(255,244,196),.22,.45)
        burst(data.from,C.Colors.Thunder,5);burst(data.to,C.Colors.Thunder,4)
        local travel=data.to-data.from
        local heading=travel.Magnitude>.05 and travel.Unit or Vector3.new(0,0,-1)
        for _,fraction in {.22,.75} do
            local at=data.from:Lerp(data.to,fraction)
            skyStrike(at+below,false)
            local center=at+Vector3.new(0,-1.25,0)
            local frame=CFrame.lookAt(center,center+heading)
            for _,piece in {
                {Vector3.new(1.15,1.25,.45),Vector3.new(0,0,0),Enum.PartType.Block},
                {Vector3.one*.58,Vector3.new(0,1,0),Enum.PartType.Ball},
                {Vector3.new(.25,1.05,.3),Vector3.new(-.78,.03,0),Enum.PartType.Block},
                {Vector3.new(.25,1.05,.3),Vector3.new(.78,.03,0),Enum.PartType.Block},
                {Vector3.new(.32,1.05,.34),Vector3.new(-.32,-1.1,0),Enum.PartType.Block},
                {Vector3.new(.32,1.05,.34),Vector3.new(.32,-1.1,0),Enum.PartType.Block},
            } do
                local ghost=part(effects,"ThunderAfterimage",piece[1],Color3.fromRGB(255,237,130),frame*CFrame.new(piece[2]),piece[3])
                ghost.Material=Enum.Material.Neon;ghost.Transparency=.68;ghost.CanCollide=false
                tween(ghost,.72,{Transparency=1});Debris:AddItem(ghost,.75)
            end
        end
        sound("rbxasset://sounds/electronicpingshort.mp3",data.from,.52,1.5,.65)
        if data.owner==player.UserId then
            local cfg=C[data.technique or "Thunderclap"]
            zenBasicUntil=time()+cfg.RushDuration+.15+cfg.DrawHold;zenGuardSign=2;zenSheathPlayed=false
            drawnUntil=0;fovKickUntil=time()+cfg.RushDuration;blur.Size=data.technique=="Godspeed" and 24 or 14
        end
    elseif kind=="Strike" then
        skyStrike(data.position,data.big)
    elseif kind=="FlameGod" then
        dragon(data.from,data.to)
        bolt(data.from-Vector3.new(0,2.4,0),data.to-Vector3.new(0,2.4,0),Color3.fromRGB(255,248,220),.6,.5)
        burst(data.from,C.Colors.Thunder,8)
        if data.owner==player.UserId then
            zenBasicUntil=time()+C.FlameGod.RushDuration+.15+C.FlameGod.DrawHold
            zenGuardSign=2;zenSheathPlayed=false;drawnUntil=0;blur.Size=20
        end
    elseif kind=="DoraItem" then
        if data.owner==player.UserId and cast and cast.kind=="Pocket" then
            cast.item=data.item
            local names={SmallLight="스몰라이트!",AirCannon="공기포!",Dorayaki="단팥빵!"}
            announce(names[data.item],"주머니에서 꺼낸 도구를 사용합니다")
            sound("rbxasset://sounds/electronicpingshort.wav",data.position,.45,1.4,.2)
        end
    elseif kind=="DoraHeal" then announce("단팥빵","체력 +"..math.floor(data.amount+.5));sound("rbxasset://sounds/electronicpingshort.wav",camera.CFrame.Position,.35,.9,.15)
    elseif kind=="DoraShrink" then
        local from=data.from
        if data.owner==player.UserId and dora.tools.SmallLight then from=(dora.tools.SmallLight:GetPivot()*CFrame.new(0,0,-.17)).Position end
        local origin=part(effects,"LightOrigin",Vector3.one*.01,Color3.new(1,1,1),CFrame.new(from));origin.Transparency=1
        local target=part(effects,"LightTarget",Vector3.one*.01,Color3.new(1,1,1),CFrame.new(data.position));target.Transparency=1
        local a=Instance.new("Attachment");a.Parent=origin;local b=Instance.new("Attachment");b.Parent=target
        local beam=Instance.new("Beam");beam.Attachment0=a;beam.Attachment1=b;beam.FaceCamera=true;beam.Width0=.08;beam.Width1=1.2
        beam.Color=ColorSequence.new(Color3.fromRGB(255,245,167));beam.Transparency=NumberSequence.new(.45);beam.LightEmission=.4;beam.Parent=origin
        Debris:AddItem(origin,.3);Debris:AddItem(target,.3)
        sound("rbxasset://sounds/electronicpingshort.wav",data.position,.4,1.8,.3)
    elseif kind=="DoraCannon" then
        local from=data.from;if data.owner==player.UserId then from=(dora.tools.AirCannon:GetPivot()*CFrame.new(0,0,-.17)).Position end
        for i=0,3 do
            local at=from;local puff=part(effects,"AirPressure",Vector3.new(.18,.18,.05),Color3.fromRGB(224,248,255),CFrame.lookAt(at,at+data.direction),Enum.PartType.Ball)
            puff.Material=Enum.Material.SmoothPlastic;puff.Transparency=.55
            tween(puff,.25+i*.04,{CFrame=CFrame.lookAt(at+data.direction*(10+i*3),at+data.direction*(11+i*3)),Size=Vector3.new(2+i*.3,2+i*.3,.1),Transparency=1});Debris:AddItem(puff,.4)
        end
        sound("rbxasset://sounds/impact_generic.mp3",from,.7,.65,.3)
    elseif kind=="DoraWallHit" then burst(data.position,Color3.fromRGB(220,239,246),4);sound("rbxasset://sounds/impact_generic.mp3",data.position,.6,.8,.3)
    elseif kind=="DoraFlight" then
        local owner=Players:GetPlayerByUserId(data.owner);local rotor=owner and owner.Character and owner.Character:FindFirstChild("DoraemonRotorMotor",true)
        if rotor then temporary(data.duration,function(age) if rotor.Parent then rotor.Transform=CFrame.Angles(0,time()*38,0) end end,function() if rotor.Parent then rotor.Transform=CFrame.identity end end) end
        if data.owner==player.UserId then dora.rotorUntil=time()+data.duration;local rotorSound=Instance.new("Sound");rotorSound.SoundId="rbxasset://sounds/action_falling.ogg";rotorSound.Looped=true;rotorSound.PlaybackSpeed=1.4;rotorSound.Volume=.12;rotorSound.Parent=camera;rotorSound:Play();Debris:AddItem(rotorSound,data.duration);announce("대나무 헬리콥터","3초 비행 · WASD 이동 / SPACE 상승 / CTRL 하강") end
    elseif kind=="DoraDoor" then
        if data.owner==player.UserId then announce("어디로든 문","문을 통과해 이동했습니다");fovKickUntil=time()+.2 end
        sound("rbxasset://sounds/electronicpingshort.wav",data.to,.5,.8,.3)
    elseif kind=="BombDevil" then
        -- The head goes off: a huge blast for everyone; for Reze herself the world cuts to black and slowly returns.
        blast(data.position,14)
        burst(data.position-Vector3.new(0,4,0),C.Colors.Bomb,22)
        if data.owner==player.UserId then
            blackout.BackgroundTransparency=0;blur.Size=36
            task.delay(.3,function()
                Tween:Create(blackout,TweenInfo.new(data.blackout-.3,Enum.EasingStyle.Sine,Enum.EasingDirection.In),{BackgroundTransparency=1}):Play()
            end)
            task.delay(data.blackout*.6,function()
                announce("爆弾の悪魔","폭탄의 악마 · 지속 무제한"..(data.healed>0 and " · HP +"..data.healed or "").."  /  R 다시 = 대폭발")
            end)
        end
    elseif kind=="RezeRise" then
        if data.owner==player.UserId then rezeAirUntil=time()+C.Rampage.AirWindow end
        blast(data.position-Vector3.new(0,2.5,0),7)
        burst(data.position-Vector3.new(0,2.2,0),C.Colors.Bomb,12)
        if data.owner==player.UserId then fovKickUntil=time()+.45;blur.Size=18 end
    elseif kind=="RezeSlam" then
        if data.owner==player.UserId then rezeAirUntil=0 end
        blast(data.position,data.radius)
        local forward=Vector3.new(data.direction.X,0,data.direction.Z);forward=forward.Magnitude>.05 and forward.Unit or Vector3.new(0,0,-1)
        local side=forward:Cross(Vector3.yAxis);local center=data.position+Vector3.new(0,.15,0)
        bolt(center-side*2-forward*2,center+forward*2,C.Colors.Bomb,.28,.5)
        bolt(center+forward*2,center+side*2-forward*2,Color3.fromRGB(255,235,204),.28,.5)
        if data.owner==player.UserId then rezeLookUntil=time()+.2;fovKickUntil=time()+.25;blur.Size=20 end
    elseif kind=="HandBlast" then
        blast(data.to,data.radius)
        local direction=data.to-data.from
        if direction.Magnitude>.1 then bolt(data.from+Vector3.yAxis*1.5,data.to,C.Colors.Bomb,.16,.3) end
        if data.owner==player.UserId then fovKickUntil=time()+.18;blur.Size=12 end
    elseif kind=="Detonation" then
        -- Everything goes off: staggered blasts across the whole radius; Reze's sight flashes white and she is human again.
        blast(data.position,data.radius*.5)
        for k=1,10 do
            task.delay(k*.04,function()
                local angle=math.random()*math.pi*2;local distance=math.random()*data.radius*.85
                blast(data.position+Vector3.new(math.cos(angle)*distance,.5,math.sin(angle)*distance),data.radius*.22)
            end)
        end
        local ring=part(effects,"BlastRing",Vector3.new(.4,.4,.4),C.Colors.Bomb,CFrame.new(data.position-Vector3.new(0,2.8,0))*CFrame.Angles(0,0,math.pi/2),Enum.PartType.Cylinder)
        tween(ring,.7,{Size=Vector3.new(.4,data.radius*2.2,data.radius*2.2),Transparency=1});Debris:AddItem(ring,.8)
        if data.owner==player.UserId then
            blackout.BackgroundColor3=Color3.new(1,1,1);blackout.BackgroundTransparency=0;blur.Size=40
            task.delay(.15,function()
                Tween:Create(blackout,TweenInfo.new(1.1,Enum.EasingStyle.Sine),{BackgroundTransparency=1}):Play()
                task.delay(1.2,function() blackout.BackgroundColor3=Color3.new(0,0,0) end)
            end)
            announce("人間に戻る","인간으로 돌아온다 · 폭탄의 악마 재사용 20초")
        end
    elseif kind=="BombRecoil" then
        if data.owner==player.UserId then
            if data.phase=="air" then
                bombRecoil={start=data.start,phase="air",direction=data.direction};clearCastVFX();cast=nil;melee=nil;sliding=nil;attackQueued=false
            elseif bombRecoil then
                bombRecoil.phase="skid";bombRecoil.land=data.start
                sound("rbxasset://sounds/impact_generic.mp3",camera.CFrame.Position,.55,.7,1)
                sound("rbxasset://sounds/action_footsteps_plastic.mp3",camera.CFrame.Position,.4,.6,C.Detonation.SkidDuration)
            end
        end
        if data.phase=="skid" then
            bodyMotion({owner=data.owner,start=data.start,duration=C.Detonation.SkidDuration},true)
            temporary(C.Detonation.SkidDuration,function(age)
                local owner=Players:GetPlayerByUserId(data.owner);local root=owner and owner.Character and owner.Character:FindFirstChild("HumanoidRootPart")
                if root and (root.Parent:GetAttribute("BombRecoilUntil") or 0)>time() and age>(data.nextDust or 0) then
                    data.nextDust=age+.06
                    for _,side in {-1,1} do burst(root.Position-Vector3.yAxis*2.6+root.CFrame.RightVector*side*.85,Color3.fromRGB(132,123,113),.5) end
                end
            end,function() end)
        end
    elseif kind=="BombRecoilEnd" then
        if data.owner==player.UserId then bombRecoil=nil end
        if bodyMoves[data.owner] then bodyMoves[data.owner].cleanup() end
    elseif kind=="Impulse" then
        local m=player.Character;local h=m and m:FindFirstChildOfClass("Humanoid");local root=m and m:FindFirstChild("HumanoidRootPart")
        if h and root then
            h:ChangeState(Enum.HumanoidStateType.Freefall);root.AssemblyLinearVelocity=data.velocity
            fovKickUntil=time()+.2;blur.Size=12
        end
    elseif kind=="Knockback" then
        local m=player.Character;local h=m and m:FindFirstChildOfClass("Humanoid");local root=m and m:FindFirstChild("HumanoidRootPart")
        if h and root then h:ChangeState(Enum.HumanoidStateType.FallingDown);root.AssemblyLinearVelocity=data.velocity end
    elseif kind=="Recoil" then
        announce("반동","다리가 버티지 못한다 · HP -"..data.damage.." · 이동 속도 저하 "..data.duration.."초")
    elseif kind=="Hold" then
        gojoCharge(data.owner,data.kind,data.position,data.duration)
        -- Blue or Red held with an arm raised; the server fires it (or Purple) when the hold ends.
        if data.owner==player.UserId then
            holdState={kind=data.kind,start=time(),duration=data.duration}
            local blue=data.kind=="Blue"
            announce(blue and "術式順転 • 蒼  ·  대기" or "術式反転 • 赫  ·  대기",(blue and "E 아카" or "Q 아오").." → 무라사키   /   "..(blue and "Q" or "E").." 다시 → 즉시 발사")
        else
            burst(data.position,colorOf(data.kind),2)
        end
    elseif kind=="Blue" then
        stopGojoCharge(data.owner)
        local from=data.from or data.position
        local model=orb(from,C.Colors.Blue,1.1);model.Name="BlueAttraction"
        model:ScaleTo(.2)
        if blueOrbs[data.owner] then blueOrbs[data.owner]:Destroy() end
        blueOrbs[data.owner]=model
        sound("rbxasset://sounds/volume_slider.ogg",from,.65,1.8,.8)
        local arrived=false;local nextEmber=0
        temporary(data.duration,function(age)
            if not model.Parent then return end
            local u=math.clamp(age/(data.travel or .6),0,1)
            local at=from:Lerp(data.position,smoothstep(u))
            model:ScaleTo(.2+.8*smoothstep(u));model:PivotTo(CFrame.new(at)*CFrame.Angles(0,age*.8,age*.3))
            if u>=1 and not arrived then
                arrived=true;burst(at,C.Colors.Blue,5);purpleRing(at,camera.CFrame.LookVector,1,C.Colors.Blue)
                local s=sound(C.SoundIds.Charge,at,.25,.6,2);s.Name="GojoBluePull"
                if data.owner==player.UserId then flashTechnique(C.Colors.Blue,.12) end
            end
            if age>nextEmber and u>=1 then
                nextEmber=age+.09
                local direction=Vector3.new(math.random()-.5,math.random()-.5,math.random()-.5).Unit
                local ember=part(effects,"BlueInwardEmber",Vector3.one*.09,C.Colors.Blue,CFrame.new(at+direction*(3+math.random()*4)),Enum.PartType.Ball)
                tween(ember,.3,{Position=at,Transparency=1});Debris:AddItem(ember,.35)
            end
        end,function() if blueOrbs[data.owner]==model then model:Destroy();blueOrbs[data.owner]=nil end end)
    elseif kind=="BlueEnd" then
        if blueOrbs[data.owner] then blueOrbs[data.owner]:Destroy();blueOrbs[data.owner]=nil end
    elseif kind=="Projectile" then
        stopGojoCharge(data.owner);gojoRelease(data.kind,data.position)
        purpleRing(data.position,data.direction,data.kind=="Purple" and 3 or 1.2,C.Colors[data.kind])
        purpleRing(data.position,data.direction,data.kind=="Purple" and 1.6 or .7,Color3.new(1,1,1))
        if data.owner==player.UserId then
            flashTechnique(C.Colors[data.kind],data.kind=="Purple" and .28 or .18)
            if cast and cast.kind==data.kind then cast.fired=true;cast.fireAt=time();if data.kind=="Red" then cast.hold=.5 end end
        end
        if data.kind=="Purple" then
            if data.owner==player.UserId and cast and cast.kind=="Purple" then
                clearCastVFX();cast.fired=true;cast.fireAt=time();blur.Size=5
            end
            purpleRing(data.position,data.direction,C.Purple.VisualRadius)
        end
        local radius=data.kind=="Purple" and C.Purple.VisualRadius or 1.2
        local model=orb(data.position,C.Colors[data.kind],radius)
        if data.kind=="Purple" then model.Name="HollowPurpleProjectile";model.PrimaryPart.Color=Color3.fromRGB(227,192,255) end
        shots[data.id]={model=model,position=data.position,direction=data.direction,speed=data.speed,born=time(),life=data.range/data.speed,kind=data.kind}
        burst(data.position,C.Colors[data.kind],radius*2)
    elseif kind=="ProjectileEnd" then
        gojoRelease(data.kind,data.position)
        local shot=shots[data.id];if shot then shot.model:Destroy();shots[data.id]=nil end
        burst(data.position,C.Colors[data.kind],8)
    elseif kind=="Hit" then
        local anchor=part(effects,"DamagePoint",Vector3.one*.1,Color3.new(1,1,1),CFrame.new(data.position+Vector3.new(0,3,0)))
        anchor.Transparency=1
        local bill=Instance.new("BillboardGui");bill.Size=UDim2.fromOffset(110,50);bill.AlwaysOnTop=true;bill.Parent=anchor
        local txt=label(bill,tostring(data.damage),24,UDim2.fromScale(0,0),UDim2.fromScale(1,1))
        tween(anchor,.8,{Position=anchor.Position+Vector3.new(0,3,0)});tween(txt,.8,{TextTransparency=1});Debris:AddItem(anchor,.9)
        if data.owner==player.UserId then cross.Text="×";task.delay(.12,function() cross.Text="+" end) end
    elseif kind=="Domain" then
        stopGojoCharge(data.owner);gojoRelease("Domain",data.position)
        if data.owner==player.UserId then flashTechnique(Color3.fromRGB(180,218,255),.35) end
        local center=data.position;local r=data.radius
        local dome=part(effects,"UnlimitedVoid",Vector3.one*.1,Color3.new(0,0,0),CFrame.new(center),Enum.PartType.Ball)
        dome.Material=Enum.Material.Neon;dome.Transparency=0
        dome.CastShadow=false
        local backdrop={}
        local size=r*2.4
        for _,axis in {Vector3.xAxis,Vector3.yAxis,Vector3.zAxis} do
            for _,sign in {-1,1} do
                local wall=part(effects,"VoidBackdrop",Vector3.new(size,size,.2),Color3.new(0,0,0),CFrame.lookAt(center+axis*sign*(r*1.2),center))
                wall.Material=Enum.Material.Neon;wall.CastShadow=false;wall.Transparency=1
                table.insert(backdrop,wall)
            end
        end
        tween(dome,.7,{Size=Vector3.one*r*2})
        local stars={}
        for i=1,90 do
            local direction=Vector3.new(math.random()-.5,math.random()-.5,math.random()-.5).Unit
            local position=center+direction*(r-1)
            local p=part(effects,"VoidStar",Vector3.new(.08,math.random()*3+.4,.08),Color3.fromRGB(148,199,255),CFrame.new(position))
            table.insert(stars,p)
        end
        burst(center,Color3.fromRGB(187,219,255),r)
        local ambience=Instance.new("Sound")
        ambience.Name="UnlimitedVoidInside";ambience.SoundId=DOMAIN_SOUND_IDS.Inside
        ambience.Looped=true;ambience.Volume=.12;ambience.PlaybackSpeed=.62;ambience.Parent=camera
        local cleaned=false
        local effect=temporary(data.duration,function(age)
            local inside=(camera.CFrame.Position-center).Magnitude<r
            if inside and not ambience.IsPlaying then ambience:Play() elseif not inside and ambience.IsPlaying then ambience:Stop() end
            for _,wall in backdrop do wall.Transparency=inside and 0 or 1 end
            dome.CFrame=CFrame.new(center)*CFrame.Angles(0,age*.035,0)
            for i,p in stars do p.Transparency=.25+math.sin(age*2+i)*.23 end
        end,function()
            if cleaned then return end
            cleaned=true
            ambience:Stop();ambience:Destroy()
            for _,wall in backdrop do wall:Destroy() end
            tween(dome,.6,{Transparency=1});Debris:AddItem(dome,.7)
            for _,p in stars do tween(p,.5,{Transparency=1});Debris:AddItem(p,.6) end
            domainViews[data.id]=nil
        end)
        domainViews[data.id]={effect=effect}
    elseif kind=="DomainEnd" then
        local view=domainViews[data.id]
        if view then
            view.effect.cleanup()
            view.effect.cleanup=function() end
            view.effect.duration=-1
            domainViews[data.id]=nil
        end
        local broken=data.reason=="shattered"
        sound(broken and DOMAIN_SOUND_IDS.Break or DOMAIN_SOUND_IDS.End,data.position,broken and .8 or .55,broken and .85 or .55,1.2)
        if broken and data.owner==player.UserId then announce("領域崩壊","영역이 깨졌다 · 더 늦게 펼친 영역이 승리") end
    elseif kind=="DomainClashLost" then
        sound(DOMAIN_SOUND_IDS.Break,data.position,.6,.8,1)
    end
end)

Run:BindToRenderStep("RezeChinReset",Enum.RenderPriority.Camera.Value-1,function()
    if camera==workspace.CurrentCamera then camera.CFrame*=commonViewOffset:Inverse() end
    commonViewOffset=CFrame.identity
    if chinOffset~=0 and camera==workspace.CurrentCamera then
        camera.CFrame*=CFrame.Angles(chinOffset,0,0)
    end
    chinOffset=0
end)
Run:BindToRenderStep("GojoView",Enum.RenderPriority.Camera.Value+1,function(dt)
    camera=workspace.CurrentCamera;viewmodel.Parent=camera
    if avatarDirty then rebuildAvatarArms() end
    local n=time();local bob=0
    local zen=current()=="Zenitsu"
    local shanks=current()=="Shanks"
    local reze=current()=="Reze"
    local isDora=current()=="Doraemon"
    for _,tool in dora.tools do dora.show(tool,false) end
    local doraTool,doraToolFrame=nil,nil
    local doraPeek=0
    local pinShown=cast and cast.kind=="BombDevil"
    local kickSwing,kickLift,kickUp,kickYaw,kickRoll=-1,0,0,0,0
    local pinGrabbed,pinHooked,chinTilt,handSize=false,false,0,KITS[current()].handScale
    local look=camera.CFrame.LookVector;local flat=Vector3.new(look.X,0,look.Z)
    local neckFrame=CFrame.lookAt(camera.CFrame.Position,camera.CFrame.Position+(flat.Magnitude>.01 and flat.Unit or Vector3.new(0,0,-1)))
    local doraFrame=neckFrame
    local l=CFrame.new(-.64,-.78,-1.15)*CFrame.Angles(.12,.08,-.08)
    local r=CFrame.new(.64,-.78,-1.15)*CFrame.Angles(.12,-.08,.08)
    local viewRatio=math.min(1,camera.ViewportSize.X/camera.ViewportSize.Y)
    local sheathing=zen and not cast and not melee and not sliding and zenBasicUntil>0 and n>zenBasicUntil and n<zenBasicUntil+C.ZenBasicAttack.Sheath
    local sheathAge=sheathing and (n-zenBasicUntil)/C.ZenBasicAttack.Sheath or 0
    local present=.28*smoothstep(sheathAge/.18)*(1-smoothstep((sheathAge-.85)/.15))
    local zenScabbard=CFrame.new(ZEN_SAYA.Position*Vector3.new(viewRatio,1,1)+Vector3.yAxis*present)*ZEN_SAYA.Rotation
    local swordPos,swordDir=zenScabbard.Position,-zenScabbard.ZVector
    local push,lean=0,0
    local castSword=nil
    local twoHandK=0
    local desiredFov=72;blur.Size=math.max(0,blur.Size-dt*24)
    local m=player.Character;local h=m and m:FindFirstChildOfClass("Humanoid")
    if slideBufferedUntil>0 and h then
        if n>slideBufferedUntil then slideBufferedUntil=0
        elseif h.FloorMaterial~=Enum.Material.Air then slideBufferedUntil=0;requestSlide() end
    end
    dora.show(dora.pocket,isDora and h and h.Health>0)
    local transformed=reze and m and (m:GetAttribute("BombDevilUntil") or 0)>n
    if melee and (not h or h.Health<=0) then melee=nil;attackQueued=false end
    if sliding and (not h or h.Health<=0 or n-sliding.start>=sliding.duration) then sliding=nil end
    if ((current()=="Gojo" and (holdState or (cast and (cast.kind=="Red" or cast.kind=="Purple")))) or (isDora and (cast or dora.rotorUntil>n))) and n>=nextAimAt then
        nextAimAt=n+1/20
        local flightInput=Vector3.zero
        if isDora and h then flightInput=h.MoveDirection+Vector3.yAxis*((UIS:IsKeyDown(Enum.KeyCode.Space) and 1 or 0)-((UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.RightControl)) and 1 or 0)) end
        aimRemote:FireServer(camera.CFrame.LookVector,camera.CFrame.Position,flightInput)
    end
    if cast and not (h and h.Health>0) then clearCastVFX();finishFlameTurn();cast=nil end
    if cast then
        local a=n-cast.start;local u=math.clamp(a/cast.length,0,1)
        if cast.kind=="Blue" then
            local snap=smoothstep((a-.25)/.16)
            r=CFrame.new(.34,-.57,-1.05-.18*snap)*CFrame.Angles(-.2,-.3,.05)
        elseif cast.kind=="Red" then
            local thrust=smoothstep(a/C.Red.Windup)
            r=CFrame.new(.1,-.2,-.67-.25*thrust)*CFrame.Angles(-.35*thrust,0,.12)
            if cast.fired then
                local kick=math.exp(-(n-cast.fireAt)*6)
                desiredFov=72+10*kick;commonLook(CFrame.new(0,0,.22*kick)*CFrame.Angles(.05*kick,0,0))
            end
        elseif cast.kind=="Purple" then
            local cfg=C.Purple
            local angle=smoothstep(a/cfg.RiseDuration)*math.pi*2
            local spread=1-smoothstep((a-cfg.Windup*.5)/(cfg.MergeAt-cfg.Windup*.5))
            local radius=.45*spread
            l=CFrame.new(-.24-math.cos(angle)*radius,-.36-math.sin(angle)*radius*.8,-.82)*CFrame.Angles(-.35,-.35,-angle*.2)
            r=CFrame.new(.24+math.cos(angle)*radius,-.36+math.sin(angle)*radius*.8,-.82)*CFrame.Angles(-.35,.35,angle*.2)
            desiredFov=72-8*smoothstep(a/cfg.RiseDuration)
            -- The spheres orbit in clear view, then become one visible Purple at the launch point.
            local focus=camera.CFrame
            local center=(focus*CFrame.new(0,0,-cfg.OrbDistance)).Position
            if not cast.fired then
                if a>.5*cfg.RiseDuration and n>=(cast.nextEmber or 0) then
                    cast.nextEmber=n+.04
                    local color=math.random()<.5 and C.Colors.Blue or C.Colors.Red
                    local direction=Vector3.new(math.random()-.5,math.random()-.5,math.random()-.5).Unit
                    local ember=part(effects,"PurpleGather",Vector3.one*.1,color,CFrame.new(center+direction*(4+math.random()*3)),Enum.PartType.Ball)
                    tween(ember,.3,{Position=center,Transparency=1});Debris:AddItem(ember,.35)
                    if cast.merged then bolt(center,center+direction*3,C.Colors.Purple,.035,.15) end
                end
                if a<cfg.MergeAt then
                    for i,o in cast.orbs do
                        local side=i==1 and -1 or 1
                        o:PivotTo(focus*CFrame.new(side*2.2*spread*math.cos(angle),.45+side*1.8*spread*math.sin(angle),-cfg.OrbDistance))
                    end
                else
                    if not cast.merged then
                        for _,o in cast.orbs do o:Destroy() end;cast.orbs={}
                        cast.merged=orb(center,C.Colors.Purple,cfg.MergedRadius)
                        cast.merged.Name="HollowPurpleCharge";cast.merged.PrimaryPart.Color=Color3.fromRGB(227,192,255)
                        burst(center,C.Colors.Purple,3);purpleRing(center,focus.LookVector,1)
                        sound("rbxasset://sounds/volume_slider.ogg",center,.55,.65,1.3);flashTechnique(C.Colors.Purple,.12)
                    end
                    local charge=smoothstep((a-cfg.MergeAt)/(cfg.Windup-cfg.MergeAt))
                    cast.merged:ScaleTo(.8+1.1*charge);cast.merged:PivotTo(CFrame.new(center)*focus.Rotation)
                    l=l:Lerp(CFrame.new(-.4,-.36,-.72)*CFrame.Angles(.2,.15,-.35),charge)
                    r=r:Lerp(CFrame.new(.06,-.18,-1.03)*CFrame.Angles(-.45,0,.12),charge)
                end
            else
                -- Follow through only after the server's Projectile event confirms the release.
                local since=n-cast.fireAt
                local thrust=smoothstep(since/.08);local recoil=smoothstep((since-.08)/.18)
                l=CFrame.new(-.42,-.37,-.75)*CFrame.Angles(.2,.15,-.35)
                r=CFrame.new(.06+.14*recoil,-.18-.14*recoil,-.87-.35*thrust+.58*recoil)*CFrame.Angles(-.45+.5*recoil,0,.12)
                local kick=1-smoothstep(since/cfg.Recovery)
                desiredFov=72+12*kick;camera.CFrame*=CFrame.Angles(.035*kick,0,0)
            end
        elseif cast.kind=="Haki" then
            local charge=1-smoothstep(a/.5);r=CFrame.new(.32,-.45-.18*charge,-.86)*CFrame.Angles(-.65*charge,-.2,.5*charge)
            l=CFrame.new(-.45,-.55,-.8);blur.Size=math.sin(math.clamp(a/.5,0,1)*math.pi)*10;desiredFov=72-5*charge
        elseif cast.kind=="DivineDeparture" then
            castSword=swordSwingPose("DN",smoothstep(a/2.5),smoothstep((a-2.5)/.12),smoothstep((a-2.65)/.35),"MID")
            local pull=smoothstep(a/2.5);local strike=smoothstep((a-2.5)/.12);r=CFrame.new(.38-.3*strike,-.48+.2*strike,-.65+.35*pull-.72*strike)*CFrame.Angles(-.8+.35*strike,-.2,.65-.5*strike)
            l=CFrame.new(-.48,-.58,-.72);desiredFov=67-5*pull+12*strike;camera.CFrame*=CFrame.Angles(-.03*strike,0,0)
            if a<cast.length then
                blur.Size=math.max(blur.Size,math.sin(math.clamp(a/cast.length,0,1)*math.pi)*5)
                local sparkStep=math.floor(a*17)
                if cast.lastSpark~=sparkStep then
                    cast.lastSpark=sparkStep
                    local aim=camera.CFrame.LookVector;local side=camera.CFrame.RightVector;local up=camera.CFrame.UpVector
                    for eye=-1,1,2 do
                        local seed=camera.CFrame:PointToWorldSpace(Vector3.new(eye*.09,.065,-.75))
                        local finish=seed+aim*(.06+math.random()*.06)+side*((math.random()-.5)*.14)+up*((math.random()-.5)*.1)
                        bolt(seed,finish,Color3.fromRGB(255,24,52),.012,.13)
                    end
                end
            end
        elseif cast.kind=="ShanksParry" then
            castSword={pos=Vector3.new(.1,-.25,-.82),dir=Vector3.new(.12,.94,-.3).Unit,roll=.2}
            local guard=smoothstep(a/.18)*(1-smoothstep((a-.82)/.18));r=CFrame.new(.34+.18*guard,-.42+.12*guard,-.72)*CFrame.Angles(-.45*guard,-.2,.8*guard)
            l=CFrame.new(-.46,-.58,-.78);desiredFov=72-3*guard
        elseif cast.kind=="ShanksSlash" then
            local prep=smoothstep(a/.25);local cut=smoothstep((a-.25)/.18);local recovery=smoothstep((a-.5)/.3)
            castSword=a<.25 and swingAt("DN",0,.55*prep) or swordSwingPose("DN",1,cut,recovery,"MID")
            local rise=smoothstep(a/.18);local swing=smoothstep((a-.18)/.16);r=CFrame.new(.28-.18*swing,-.4+.1*rise,-.55-.38*rise)*CFrame.Angles(-.5,-.25,.72-1.25*swing)
            l=CFrame.new(-.46,-.58,-.78);desiredFov=69+8*swing;camera.CFrame*=CFrame.Angles(-.025*rise,0,-.035*swing)
        elseif cast.kind=="Domain" then
            local seal=smoothstep(a/.7)
            l=CFrame.new(-.38+.28*seal,-.48+.28*seal,-.8+.08*seal)*CFrame.Angles(.1-seal,.2+.2*seal,-.3+.6*seal)
            r=CFrame.new(.38-.28*seal,-.42+.25*seal,-.8+.1*seal)*CFrame.Angles(.05-seal,-.25-.15*seal,.3-.6*seal)
            blur.Size=math.sin(u*math.pi)*5;desiredFov=72-10*smoothstep(u)
            if a<cast.length and n>=(cast.nextRipple or 0) then
                cast.nextRipple=n+.4
                local root=m and m:FindFirstChild("HumanoidRootPart")
                if root then purpleRing(root.Position-Vector3.yAxis*2.7,Vector3.yAxis,4+4*u,Color3.fromRGB(145,201,255)) end
            end
        elseif cast.kind=="Dash" then desiredFov=84
        elseif ZEN_DRAWS[cast.kind] then
            -- Fold forward, right hand on the hilt and left hand at the scabbard mouth.
            local cfg=C[cast.kind]
            local prep=smoothstep(a/cast.length)
            local travel=math.clamp((a-cast.length)/cfg.RushDuration,0,1)
            local extract=smoothstep(travel/.72)
            local slash=smoothstep((travel-.85)/.15)
            lean=(cast.kind=="Godspeed" and .35 or .50)*prep*(1-.7*extract)
            -- The scabbard stays at the left hip, pointing down/back to the left.
            local mouth=zenScabbard
            -- First pull straight out of the mouth; only swing once the tip clears it.
            local extracted=mouth*CFrame.new(0,0,-1.48*extract)
            local finish={pos=Vector3.new(.08,-.24,-1.12),dir=Vector3.new(-.55,.50,-.67).Unit,roll=-.15}
            local follow=swordFrame(finish.pos,finish.dir,finish.roll)
            local frame=extracted:Lerp(follow,slash)
            castSword={frame=frame,pos=frame.Position,dir=frame.ZVector,roll=-.15*slash}
            zenReadyPose=finish
            push=0;twoHandK=smoothstep((travel-.65)/.20)
            desiredFov=72-10*prep+24*extract
            if m and a<cast.length and math.random()<dt*25 then
                local root=m:FindFirstChild("HumanoidRootPart")
                if root then local foot=root.Position-Vector3.yAxis*2.8;bolt(foot,foot+Vector3.yAxis*(1+math.random()),C.Colors.Thunder,.06,.12) end
            end
        elseif cast.kind=="BombDevil" then
            -- Beats over the windup: chin down while the right arm rises elbow-out to the choker (to .45), fingers hook
            -- the ring and hold (.45-.62), a hard yank out to the right with a metallic ting (.62-.72), the socket fizzes.
            local w=cast.length
            local function smooth(x) x=math.clamp(x,0,1);return x*x*(3-2*x) end
            local reach,pull=smooth((a-.04*w)/(w*.41)),smooth((a-w*.62)/(w*.1))
            pinHooked=a>=w*.45 and a<w*.62
            pinGrabbed=a>=w*.62
            if a<w then chinTilt=smooth(a/(w*.35)) end
            handSize=1-.38*reach
            local view=camera.CFrame*CFrame.Angles(-CHIN_DIP*chinTilt,0,0)
            local ringLocal=view:ToObjectSpace(neckFrame*RING_AT).Position
            local atRing=ringLocal-HOOK:VectorToWorldSpace(PIN_IN_HAND.Position*handSize)
            local jitter=pinHooked and math.sin(a*70)*.003 or 0
            local idle,out=Vector3.new(.42,-.5,-.88),Vector3.new(.56,-.2,-.62)
            local position=idle:Lerp(atRing,reach):Lerp(out,pull)+Vector3.new(jitter,jitter,0)
            local rotation=CFrame.Angles(.1,-.2,.3):Lerp(HOOK,reach):Lerp(CFrame.Angles(-.05,-.3,.7),pull)
            r=CFrame.new(position)*rotation.Rotation
            l=l*CFrame.new(0,-.12*chinTilt,0)
            if pull>0 and not cast.pinged then
                cast.pinged=true
                local root=m and m:FindFirstChild("HumanoidRootPart")
                if root then sound("rbxasset://sounds/electronicpingshort.wav",root.Position,.6,1.7,1) end
            end
            desiredFov=72-3*reach+3*pull
        elseif DORA_KINDS[cast.kind] then
            local down=smoothstep(a/.18)*(1-smoothstep((a-.98)/.36));doraPeek=down
            local search=smoothstep((a-.32)/.12)*(1-smoothstep((a-.94)/.1));local pull=smoothstep((a-.98)/.34)
            local eyePitch=math.asin(math.clamp(look.Y,-1,1));local dip=(math.min(eyePitch,-.88)-eyePitch)*down
            commonLook(CFrame.Angles(dip,0,0));desiredFov=72-down;handSize=.72
            local function hand(at,side)
                local position=camera.CFrame:PointToObjectSpace(doraFrame:PointToWorldSpace(at))
                local shoulder=camera.CFrame:PointToObjectSpace(doraFrame:PointToWorldSpace(Vector3.new(side*.43,-.36,-.05)))
                return CFrame.lookAt(position,shoulder)*CFrame.Angles(math.pi/2,0,0)
            end
            local leftAt=Vector3.new(-.38,-.43,-.48):Lerp(Vector3.new(-.26,-.68,-.32),smoothstep((a-.12)/.2))
            local rightAt=Vector3.new(.38,-.44,-.5):Lerp(Vector3.new(.045+math.sin(a*24)*.075*search,-.755+math.sin(a*28)*.045*search,-.43+math.cos(a*24)*.035*search),smoothstep((a-.21)/.16)):Lerp(Vector3.new(.22,-.49,-.56),pull)
            l=hand(leftAt,-1);r=hand(rightAt,1)
            dora.lip.Size=Vector3.new(.57,.018,.025+.012*search)
            if a>.35 and a<.94 and math.floor((a-.35)/.17)>(cast.rustle or -1) then
                cast.rustle=math.floor((a-.35)/.17);sound("rbxasset://sounds/action_footsteps_plastic.mp3",camera.CFrame.Position,.12,1.8,.09)
            end
            local tool=cast.kind=="Pocket" and cast.item or cast.kind=="BambooCopter" and "Copter" or cast.kind=="AnywhereDoor" and "Door"
            if a>=.98 and tool then
                local at=camera.CFrame:PointToObjectSpace(doraFrame:PointToWorldSpace(rightAt+Vector3.new(0,.06,-.03))):Lerp(Vector3.new(.3,-.22,-.65),smoothstep((a-.98)/.36))
                if tool=="Copter" then at=at:Lerp(Vector3.new(.55,.72,-.72),smoothstep((a-1.5)/.5));if a>=C.BambooCopter.Windup then at=at:Lerp(Vector3.new(.37,-.33,-.865),smoothstep((a-C.BambooCopter.Windup)/.35));tool=nil end
                elseif tool=="Dorayaki" then at=at:Lerp(Vector3.new(.08,-.08,-.17),smoothstep((a-1.57)/.18)*(1-smoothstep((a-1.87)/.2)))
                elseif tool=="AirCannon" and a>=C.Pocket.Windup then at+=Vector3.zAxis*.1*(1-smoothstep((a-C.Pocket.Windup)/.18))
                elseif tool=="Door" and a>=1.45 then tool=nil end
                if cast.kind=="Pocket" and a>1.9 then at=at:Lerp(Vector3.new(.5,-.7,-.6),smoothstep((a-1.9)/.3)) end
                r=CFrame.new(at+Vector3.new(.01,-.09,.065))*CFrame.Angles(.2,0,.1)
                doraTool=tool;doraToolFrame=CFrame.new(at)*CFrame.Angles(tool=="SmallLight" and -math.pi/2 or tool=="Dorayaki" and .3 or 0,0,-.12)
            end
            if a>1.45 then l=l:Lerp(CFrame.new(-.4,-.48,-.8)*CFrame.Angles(.1,.1,-.2),smoothstep((a-1.45)/.4)) end
        elseif cast.kind=="Rampage" then
            if cast.phase=="Dive" then
                l=CFrame.new(-.42,-.5,-.66)*CFrame.Angles(.25,0,-.2);r=CFrame.new(.42,-.5,-.66)*CFrame.Angles(.25,0,.2)
                desiredFov=80;camera.CFrame*=CFrame.Angles(-math.rad(12)*smoothstep(a/.12),0,0)
            else
                local crouch=smoothstep(a/.4)*(1-smoothstep((a-.4)/.16))
                l=CFrame.new(-.48,-.55-.28*crouch,-.68)*CFrame.Angles(.35*crouch,0,-.2)
                r=CFrame.new(.48,-.52-.3*crouch,-.66)*CFrame.Angles(.45*crouch,0,.24)
                lean=.55*crouch;desiredFov=68+10*smoothstep((a-.4)/.18)
                if cast.phase~="Dive" and a>=.4 and m then local root=m:FindFirstChild("HumanoidRootPart");if root then local flat=Vector3.new(cast.direction.X,0,cast.direction.Z);if flat.Magnitude>.05 and math.random()<dt*15 then burst(root.Position-flat.Unit*1.5,C.Colors.Bomb,.8) end end end
            end
        elseif cast.kind=="Kick" then
            local raise=smoothstep(a/.2)
            r=CFrame.new(.32,-.48+.42*raise,-.82-.45*raise)*CFrame.Angles(-.75*raise,-.12,.22*raise)
            l=CFrame.new(-.42,-.5,-.8)*CFrame.Angles(.08,0,-.2)
            desiredFov=70-4*raise
        elseif cast.kind=="Detonation" then
            -- Keep moving while the fuse slows her down and the tracked danger zone closes in.
            local shake=(a/cast.length)^2*.02
            l=CFrame.new(-.16,-.2,-.66)*CFrame.Angles(.1,.7,-.5);r=CFrame.new(.16,-.2,-.66)*CFrame.Angles(.1,-.7,.5)
            camera.CFrame*=CFrame.new((math.random()-.5)*shake*2,(math.random()-.5)*shake*2,0)
            desiredFov=72-12*(a/cast.length)
        end
        if a>=cast.length+cast.hold then clearCastVFX();cast=nil end
    end
    if chinTilt>0 then chinOffset=CHIN_DIP*chinTilt;camera.CFrame*=CFrame.Angles(-chinOffset,0,0) end
    if n<rezeLookUntil then camera.CFrame*=CFrame.Angles(-math.rad(24)*(1-smoothstep(1-(rezeLookUntil-n)/.2)),0,0) end
    if kickSwing>=0 then camera.CFrame*=CFrame.Angles(0,kickYaw,kickRoll) end
    if flameTurn then
        local turn=flameTurn
        if not (turn.root.Parent and turn.humanoid.Parent and turn.humanoid.Health>0) then
            finishFlameTurn()
        elseif not turn.start then
            -- The RemoteEvent can arrive before the replicated teleport. Wait for the body AND forward view
            -- to reach the destination before starting a camera-only turnaround.
            local delta=(turn.root.Position-turn.destination)*Vector3.new(1,0,1)
            local viewDelta=(camera.CFrame.Position-turn.root.Position)*Vector3.new(1,0,1)
            if delta.Magnitude<=1.5 and viewDelta.Magnitude<=3 then
                turn.arrivedAt=turn.arrivedAt or n
                if n-turn.arrivedAt>=.08 then
                    turn.start=n
                    turn.cameraRotation=camera.CFrame.Rotation
                    turn.cameraOffset=camera.CFrame.Position-turn.root.Position
                    turn.humanoidOffset=turn.humanoid.CameraOffset
                    turn.fov=camera.FieldOfView
                    camera.CameraType=Enum.CameraType.Scriptable
                end
            else turn.arrivedAt=nil end
            if n-turn.requested>1 then finishFlameTurn() end
        else
            local elapsed=n-turn.start
            local amount=smoothstep(elapsed/.65)
            local yaw=CFrame.fromAxisAngle(Vector3.yAxis,math.pi*amount)
            turn.humanoid.AutoRotate=false
            camera.CFrame=CFrame.new(turn.root.Position+turn.cameraOffset+turn.humanoid.CameraOffset-turn.humanoidOffset)*yaw*turn.cameraRotation
            camera.Focus=CFrame.new(turn.root.Position)
            desiredFov=turn.fov+(72-turn.fov)*amount+3*math.sin(amount*math.pi)
            blur.Size=18*(1-amount)
            if elapsed>=.65 then finishFlameTurn() end
        end
    end
    -- Slide: tuck the arms, lower the view, then stand back up as horizontal speed decays.
    if sliding then
        local a=n-sliding.start
        local crouch=smoothstep(a/.12)*(1-smoothstep((a-sliding.duration+.18)/.18))
        lean=math.max(lean,C.Slide.CameraDip/1.3*crouch)
        l=CFrame.new(-.5,-.65,-.72)*CFrame.Angles(.4,.25,-.45)
        r=CFrame.new(.5,-.65,-.72)*CFrame.Angles(.4,-.25,.45)
        commonLook(CFrame.Angles(-.05*crouch,0,.045*crouch))
        desiredFov=72+12*crouch;swordPos+=Vector3.new(0,.15*crouch,0)
    end
    if melee then
        local a=(melee.hitUntil and n<melee.hitUntil) and melee.hitAge or n-melee.start
        local wind=smoothstep(a/melee.windup);local strike=smoothstep((a-melee.windup)/melee.swing)
        local recovery=smoothstep((a-melee.windup-melee.swing)/(melee.duration-melee.windup-melee.swing))
        local sign=melee.combo%2==0 and -1 or 1
        local guard=CFrame.new(sign*.5,-.38,-.8)*CFrame.Angles(.1,-sign*.2,sign*.12)
        local prep=CFrame.new(sign*.7,melee.combo==3 and -.75 or -.34,-.48)*CFrame.Angles(.3,-sign*.5,sign*.25)
        local contact=CFrame.new(sign*.06,melee.combo==3 and -.06 or -.24,-1.52)*CFrame.Angles(-.2,0,-sign*.12)
        local fist=guard:Lerp(prep,wind):Lerp(contact,strike):Lerp(guard,recovery)
        if not zen then
            if melee.combo==2 then l=fist;r=CFrame.new(.48,-.4,-.8) else r=fist;l=CFrame.new(-.48,-.4,-.8) end
        end
        commonLook(CFrame.Angles(-.03*strike*(1-recovery),sign*(-.04*wind+.09*strike)*(1-recovery),-sign*.045*strike*(1-recovery)))
        desiredFov=72-2*wind+6*strike*(1-recovery)
        if zen or shanks then
            local kind,nextKind=swordKind(melee.combo),swordKind(melee.combo+1)
            local pose
            melee.hiltFrame=nil
            if zen and melee.draw and a<melee.windup then
                local draw=smoothstep(a/(melee.windup*.72));local turn=smoothstep((a/melee.windup-.72)/.28)
                local ready=swingAt(kind,0)
                local extracted=zenScabbard*CFrame.new(0,0,-1.48*draw)
                local frame=extracted:Lerp(swordFrame(ready.pos,ready.dir,ready.roll),turn)
                melee.hiltFrame=frame
                pose={pos=frame.Position,dir=frame.ZVector,roll=ready.roll*turn,len=draw}
                twoHandK=smoothstep((a/melee.windup-.65)/.25)
            else pose=swordSwingPose(kind,wind,strike,recovery,nextKind);twoHandK=1 end
            melee.hiltAt=pose.pos;melee.bladeDir=pose.dir;melee.bladeRoll=pose.roll;melee.drawProgress=pose.len
        end
        if n-melee.start>=melee.duration then
            melee=nil
            if attackQueued then attackQueued=false;requestBasic() end
        end
    end
    -- Skid after a Rampage that hit nothing: drop low and recover.
    if n<slideUntil then lean=math.max(lean,.9*math.clamp((slideUntil-n)/.55,0,1)) end
    -- Block hands fly apart, then brace low as the blast carries the body backwards. Keep looking at the blast.
    if bombRecoil then
        if not reze or not h or h.Health<=0 or n-bombRecoil.start>C.Detonation.RecoilAirLimit+C.Detonation.SkidDuration+C.Detonation.StandDuration+.3 then
            bombRecoil=nil
        else
            local a=n-bombRecoil.start;local skid=bombRecoil.phase=="skid"
            local groundAge=skid and n-bombRecoil.land or 0
            local stand=skid and smoothstep((groundAge-C.Detonation.SkidDuration)/C.Detonation.StandDuration) or 0
            local kick=1-smoothstep(a/.22);local brace=smoothstep(a/.18)*(1-stand)
            l=CFrame.new(-.64-.23*kick,-.78+.55*kick+.24*brace,-1.15+.28*kick)*CFrame.Angles(-.5*kick,.2,-.65*kick-.2*brace)
            r=CFrame.new(.64+.23*kick,-.78+.55*kick+.24*brace,-1.15+.28*kick)*CFrame.Angles(-.5*kick,-.2,.65*kick+.2*brace)
            lean=skid and .9*(1-stand) or -.12*kick
            local landKick=skid and math.exp(-groundAge*17)*.075 or 0
            local offset=CFrame.Angles(.12*kick-landKick,0,.025*math.sin(a*24)*math.exp(-a*5))
            camera.CFrame*=offset;commonViewOffset*=offset
            desiredFov=72+16*math.exp(-a*3)+4*brace
            fovKickUntil=0
        end
    end
    -- Both Gojo techniques charge in the right hand, matching their release hand.
    local holdHand=nil
    if holdState then
        if n-holdState.start>holdState.duration+1 then holdState=nil
        else
            local k=math.clamp((n-holdState.start)/.25,0,1)
            if holdState.kind=="Blue" then
                r=CFrame.new(.34,-.57,-1.05)*CFrame.Angles(-.2,-.3,.05)
            else
                r=CFrame.new(.3,-.42+.3*k,-.8)*CFrame.Angles(.35*k,0,.3-.22*k)
            end
            holdHand=r
        end
    end
    -- Tendo Pain arms, camera work and overlays; also hides sealed bodies and frees held ones for every kit.
    local isPain=current()=="Pain"
    local painOut=PainClient.render(dt,{isPain=isPain,melee=melee,sliding=sliding~=nil,moving=h~=nil and h.MoveDirection.Magnitude>.1,alive=h~=nil and h.Health>0})
    if painOut and PainClient.busy() then desiredFov=painOut.fov end
    -- All Might: custom arms and camera; the buff adds FOV on top of whatever else is happening.
    local isAllMight=current()=="AllMight"
    local mightOut=AllMightClient.render(dt,{isAllMight=isAllMight,melee=melee,moving=h~=nil and h.MoveDirection.Magnitude>.1,alive=h~=nil and h.Health>0,sliding=sliding~=nil})
    if mightOut then
        if AllMightClient.busy() then desiredFov=mightOut.fov end
        desiredFov+=mightOut.fovAdd
    end
    local kizaruOut=KizaruClient.render(dt,current()=="Kizaru",h~=nil and h.Health>0)
    if kizaruOut then l=kizaruOut.left;r=kizaruOut.right;desiredFov=kizaruOut.fov end
    local isOkkotsu=current()=="Okkotsu"
    local okkotsuOut=OkkotsuClient.render(dt,{isOkkotsu=isOkkotsu,alive=h~=nil and h.Health>0,melee=melee,moving=h~=nil and h.MoveDirection.Magnitude>.1,sliding=sliding~=nil})
    if okkotsuOut and OkkotsuClient.busy() then desiredFov=okkotsuOut.fov end
    if rushView then
        local u=(n-rushView.start)/(rushView.duration+.12)
        if u>=1 or not h or h.Health<=0 then rushView=nil
        else
            local k=math.sin(math.clamp(u,0,1)*math.pi)
            desiredFov=math.max(desiredFov,72+16*k);blur.Size=math.max(blur.Size,2*k)
            commonLook(CFrame.Angles(-.025*k,0,.008*math.sin(u*12)*k))
            if n>=(rushView.nextStreak or 0) then
                rushView.nextStreak=n+.035
                for _,side in {-1,1} do
                    local at=camera.CFrame*CFrame.new(side*(1.2+math.random()*.5),(math.random()-.5)*1.6,-3)
                    local streak=part(effects,"RushSpeedLine",Vector3.new(.015,.015,2),Color3.fromRGB(210,234,255),at)
                    streak.Transparency=.55;tween(streak,.12,{CFrame=at*CFrame.new(0,0,3),Transparency=1});Debris:AddItem(streak,.15)
                end
            end
        end
    end
    if n<fovKickUntil then desiredFov=94 end
    if h then h.CameraOffset=h.CameraOffset:Lerp(Vector3.new(0,-1.3*lean,0),1-math.exp(-dt*14)) end
    camera.FieldOfView+=(desiredFov-camera.FieldOfView)*math.min(1,dt*8)
    local width=camera.ViewportSize.X;scale.Scale=math.min(1,(width-28)/480)
    local handScale=math.min(1,camera.ViewportSize.X/camera.ViewportSize.Y)
    local zenIdleDraw=zen and not melee and not cast and not sliding and zenBasicUntil>0 and n<zenBasicUntil+C.ZenBasicAttack.Sheath
    local zenSkillDraw=zen and cast and ZEN_DRAWS[cast.kind] and smoothstep((n-cast.start-cast.length)/(C[cast.kind].RushDuration*.72))
    local drawn=n<drawnUntil or (zen and (melee~=nil or zenIdleDraw or (zenSkillDraw and zenSkillDraw>.001)))
    local zenSheath=zenIdleDraw and smoothstep((n-zenBasicUntil)/C.ZenBasicAttack.Sheath) or 0
    local zenInsertion=smoothstep((zenSheath-.3)/.7)
    local bladeFraction=shanks and 1 or zenSkillDraw or (zen and melee and melee.drawProgress) or (zenIdleDraw and (1-zenInsertion)) or (drawn and 1 or 0)
    local alive=h and h.Health>0
    local posed=kizaruOut~=nil or zen or shanks or cast~=nil or melee~=nil or sliding~=nil or holdHand~=nil or bombRecoil~=nil
    local leftFrame,rightFrame=l,r
    local zenHilt,zenSaya
    if zen or shanks then
        local sword=zen and zenScabbard or CFrame.lookAt(swordPos*Vector3.new(handScale,1,1),swordPos*Vector3.new(handScale,1,1)+swordDir)
        local hilt=sword*CFrame.new(0,0,-push)
        if drawn then hilt=swordFrame(Vector3.new(.32*handScale,-.38,-.92),Vector3.new(-.75,.06,-.66),0) end
        if shanks then hilt=swordFrame(Vector3.new(.34,-.42,-.8),Vector3.new(-.5,.34,-.8),0) end
        if zenIdleDraw then
            local cfg=C.ZenBasicAttack
            local sheathe=zenSheath
            local guard=zenReadyPose or swingAt(swordKind(zenGuardSign),0)
            local held=swordFrame(guard.pos,guard.dir,guard.roll)
            local aligned=sword*CFrame.new(0,0,-1.48)
            hilt=sheathe<.3 and held:Lerp(aligned,smoothstep(sheathe/.3)) or aligned:Lerp(sword,zenInsertion)
            twoHandK=1-smoothstep(sheathe/.25)
            if sheathe>0 and not zenSheathPlayed then
                zenSheathPlayed=true
                local root=m and m:FindFirstChild("HumanoidRootPart")
                if root then sound("rbxasset://sounds/swordunsheath.wav",root.Position,.32,.9,.9) end
            end
        end
        if melee and melee.hiltAt then hilt=melee.hiltFrame or swordFrame(melee.hiltAt,melee.bladeDir,melee.bladeRoll) end
        if castSword then hilt=castSword.frame or swordFrame(castSword.pos,castSword.dir,castSword.roll) end
        zenHilt=hilt;zenSaya=sword
        place(katana.saya,sword);place(katana.hilt,hilt)
        if melee and n-melee.start>=melee.windup and n-melee.start<=melee.windup+melee.swing then
            local tip=(camera.CFrame*hilt*CFrame.new(0,0,1.45)).Position
            if melee.lastTip and (tip-melee.lastTip).Magnitude>.01 then
                local delta=tip-melee.lastTip
                local trail=part(effects,"SwordCutTrail",Vector3.new(.025,.025,delta.Magnitude),shanks and C.Colors.Haki or C.Colors.Thunder,CFrame.lookAt((tip+melee.lastTip)/2,tip))
                trail.Transparency=.35;tween(trail,.14,{Transparency=1});Debris:AddItem(trail,.16)
            end
            melee.lastTip=tip
        end
        if zen and not shanks then
            for _,entry in katana.hilt do
                if entry.drawnOnly then
                    entry.p.Size=Vector3.new(entry.size.X,entry.size.Y,math.max(.01,entry.size.Z*bladeFraction))
                    entry.p.CFrame=camera.CFrame*hilt*CFrame.new(0,entry.offset.Position.Y,.04+entry.size.Z*bladeFraction*.5)
                end
            end
        end
        for _,entry in katana.hilt do entry.p.Transparency=(not alive or (entry.drawnOnly and bladeFraction<=.01)) and 1 or 0 end
        for _,entry in katana.saya do entry.p.Transparency=(zen and sheathing and alive) and 0 or 1 end
        for _,entry in katana.hilt do if entry.p.Name=="Edge" then entry.p.Color=shanks and C.Colors.Haki or C.Colors.Thunder end end
        if shanks then
            local roll=(castSword and castSword.roll) or (melee and melee.bladeRoll) or 0
            rightFrame=swordGrip(hilt,GRIP,Vector3.new(.4,-.78,.3),roll)
            leftFrame=armFrame((sword*SAYA).Position,LEFT_UP)
        end
    else
        scaleHand(right,handSize);scaleHand(left,isDora and handSize or 1)
        if holdHand then
            holdOrb.CFrame=camera.CFrame*CFrame.new(holdHand.Position*Vector3.new(handScale,1,1))*holdHand.Rotation*CFrame.new(0,.3,0)
            holdOrb.Color=C.Colors[holdState.kind];holdOrb.Size=Vector3.one*(.16+math.sin(n*14)*.015)
        end
        leftFrame=(isDora and cast and DORA_KINDS[cast.kind]) and l or CFrame.new(l.Position*Vector3.new(handScale,1,1))*l.Rotation
        -- While pulling the pin the hand must meet the ring exactly, so the narrow-screen squeeze is skipped.
        rightFrame=(pinShown or (isDora and cast and DORA_KINDS[cast.kind])) and r or CFrame.new(r.Position*Vector3.new(handScale,1,1))*r.Rotation
        if pinShown then
            pinPart.CFrame=pinGrabbed and camera.CFrame*r*CFrame.new(PIN_IN_HAND.Position*handSize)*PIN_IN_HAND.Rotation or neckFrame*RING_AT*CFrame.Angles(0,0,pinHooked and math.sin(n*50)*.15 or 0)
        end
    end
    dora.pocket:PivotTo(doraFrame)
    local avatarTorso=m and (m:FindFirstChild("UpperTorso") or m:FindFirstChild("Torso"))
    if avatarTorso then dora.shirt.Color=avatarTorso.Color end
    local torsoEntries=dora.torsoEntries or {};dora.shirt.Transparency=#torsoEntries>0 and 1 or 0
    local shirtFrame=doraFrame*CFrame.new(0,-1.05,-.1)
    for _,entry in torsoEntries do
        local size=Vector3.new(.46,.46,.28);entry.p.Size=entry.size*size
        for _,mesh in entry.meshes do mesh.p.Scale=mesh.scale*size end
        entry.p.CFrame=shirtFrame*CFrame.new(entry.offset.Position*Vector3.new(.46,.46,0))*entry.offset.Rotation
        entry.p.Color=entry.source.Color;entry.p.Transparency=(isDora and alive) and entry.source.Transparency or 1
    end
    if doraTool and dora.tools[doraTool] then dora.show(dora.tools[doraTool],true);dora.tools[doraTool]:PivotTo(camera.CFrame*doraToolFrame) end
    local gojoPose=GojoHands.render(dt,{active=current()=="Gojo" or zen,kit=current(),hilt=zenHilt,saya=zenSaya,twoHand=twoHandK,alive=alive,character=m,left=leftFrame,right=rightFrame,cast=cast,hold=holdState,melee=melee,sliding=sliding~=nil})
    if gojoPose then leftFrame=gojoPose.left;rightFrame=gojoPose.right end
    -- The third-person signature weapon must not overlap the separate first-person blade.
    if m then
        local head=m:FindFirstChild("Head")
        local firstPerson=head and (camera.CFrame.Position-head.Position).Magnitude<2.5
        for _,v in m:GetDescendants() do
            if v:IsA("BasePart") and v:GetAttribute("Outfit") then v.LocalTransparencyModifier=firstPerson and 1 or 0 end
        end
    end
    showAvatarArm(left,leftFrame,posed,alive and not shanks and not isPain and not isAllMight and not isOkkotsu)
    showAvatarArm(right,rightFrame,posed,alive and not isPain and not isAllMight and not isOkkotsu)
    local pinVisible=pinShown and pinGrabbed and h and h.Health>0 and chinTilt>0
    for _,entry in pinRing do entry.p.CFrame=pinPart.CFrame*entry.offset;entry.p.Transparency=pinVisible and 0 or 1 end
    if kickSwing>=0 then
        local sw=kickSwing
        boot.CFrame=camera.CFrame*CFrame.new(1.05*(1-2*sw)*.8,-.9+.4*kickLift+.45*kickUp,-.5-.25*kickLift-.5*kickUp)*CFrame.Angles(-.3*kickLift-.5*kickUp,-1.3+2.6*sw,(.55-1.1*sw)*.6)
        boot.Transparency=(h and h.Health>0) and 0 or 1
    else boot.Transparency=1 end
    local domainSeal=cast and cast.kind=="Domain" and n-cast.start<cast.length
    if gojoPose and holdHand then holdOrb.CFrame=camera.CFrame*CFrame.new(gojoPose.focus) end
    if domainSeal then
        local seal=gojoPose and gojoPose.seal or Vector3.new(0,-.08,-.8)
        holdOrb.CFrame=camera.CFrame*CFrame.new(seal+Vector3.new(0,0,-.09));holdOrb.Color=Color3.fromRGB(145,201,255);holdOrb.Size=Vector3.one*(.08+.08*smoothstep((n-cast.start)/cast.length))
    end
    holdOrb.Transparency=domainSeal and 1 or ((holdHand and not zen and h and h.Health>0) and .15 or 1)
    for _,orbModel in blueOrbs do if orbModel.Parent then orbModel:PivotTo(orbModel:GetPivot()*CFrame.Angles(0,dt*.5,dt*.2)) end end
    for id,shot in shots do
        shot.position+=shot.direction*shot.speed*dt
        shot.model:PivotTo(CFrame.lookAt(shot.position,shot.position+shot.direction))
        if shot.kind=="Purple" and n>=(shot.nextTrail or 0) then
            shot.nextTrail=n+.08
            local trail=part(effects,"PurpleTrail",Vector3.one*2,C.Colors.Purple,CFrame.new(shot.position),Enum.PartType.Ball)
            trail.Transparency=.5;tween(trail,.3,{Size=Vector3.one*.2,Transparency=1});Debris:AddItem(trail,.35)
        end
        if n-shot.born>shot.life then shot.model:Destroy();shots[id]=nil end
    end
    for i=#activeEffects,1,-1 do
        local e=activeEffects[i];local age=n-e.start
        if age>e.duration then e.cleanup();table.remove(activeEffects,i) else e.update(age) end
    end
    local slowed=m and (m:GetAttribute("SlowedUntil") or 0)-n or 0
    local slideCooldown=math.max(0,(state.cooldowns.Slide or 0)-n)
    slideButton.Text=sliding and "슬라이딩 중" or slideCooldown>0 and string.format("CTRL  %.1f",slideCooldown) or "CTRL  슬라이딩"
    slideButton.BackgroundTransparency=slideCooldown>0 and .5 or .12
    attackButton.Text=melee and string.format("%d / %d  %s",melee.combo,(zen or shanks) and 4 or 3,attackQueued and "연계 대기" or "기본공격") or "M1  기본공격"
    for _,entry in buttons do
        local cooldown=math.max(0,(state.cooldowns[entry.skill] or 0)-n)
        if entry.skill=="Dash" and slowed>0 then cooldown=math.max(cooldown,slowed) end
        local text=entry.name
        local held=state.holdKind or ""
        if entry.key=="R" and reze then entry.skill=transformed and "Detonation" or "BombDevil";entry.name=transformed and "대폭발" or "폭탄의 악마";entry.stroke.Color=colorOf(entry.skill) end
        if held~="" and (entry.skill=="Blue" or entry.skill=="Red") then
            if entry.skill==held then text=entry.name.." 발사";cooldown=0 else text="무라사키" end
        end
        if entry.skill=="Godspeed" and state.godspeedUsed then text="사용 완료 · 속도 −30%" end
        if entry.skill=="Rampage" and transformed then
            local ready=rezeAirUntil-n
            text=ready>0 and string.format("Q  내려찍기  %.1f",ready) or "Q  상승 폭발"
            if ready>0 then cooldown=0 end
        elseif entry.skill=="Kick" then
            text="오른손 폭발"
        end
        if reze and not transformed and (entry.skill=="Rampage" or entry.skill=="Kick") then text=entry.name.." (변신 필요)";cooldown=math.max(cooldown,.001) end
        entry.b.Text=entry.key.."\n"..text..(cooldown>0 and string.format("  %.1f",cooldown) or "")
        entry.stroke.Thickness=((painOut and painOut.combo and (entry.key=="Q" or entry.key=="R") and cooldown<=0) or (mightOut and mightOut.rReady and entry.key=="R" and cooldown<=0)) and 3 or 1
        entry.b.TextTransparency=doraPeek>.08 and .75 or 0
        entry.b.BackgroundTransparency=doraPeek>.08 and .9 or cooldown>0 and .5 or .12
    end
    do
        local ready=rezeAirUntil-n
        if current()=="Reze" and ready>0 and transformed then
            comboLabel.Text=string.format("Q  공중에서 내려찍기   %.1f",ready)
            comboLabel.TextTransparency=.1+.25*math.abs(math.sin(n*9))
        elseif painOut and painOut.combo then
            comboLabel.Text=painOut.combo;comboLabel.TextTransparency=.1+.25*math.abs(math.sin(n*9))
        elseif mightOut and mightOut.combo then
            comboLabel.Text=mightOut.combo;comboLabel.TextTransparency=mightOut.rReady and .1+.25*math.abs(math.sin(n*9)) or .15
        elseif isDora and dora.rotorUntil>n then
            comboLabel.Text=string.format("대나무 헬리콥터   %.1f초 · SPACE ↑ / CTRL ↓",dora.rotorUntil-n);comboLabel.TextTransparency=0
        else comboLabel.Text="" end
    end
    health.Text=h and string.format("HP  %d / %d",h.Health,h.MaxHealth) or "RESPAWNING"
    local locked=m and (m:GetAttribute("DomainLockedUntil") or 0)>n
    energy.Text=locked and "영역 안 · 이동 가능 / 스킬 봉인"
        or bombRecoil and (bombRecoil.phase=="air" and "폭압 반동 · 뒤로 튕겨나는 중" or "폭압 반동 · 착지 슬라이딩 후 자세 회복")
        or slowed>0 and string.format("반동 · 이동 속도 저하 · 대시 불가  %.1f", slowed)
        or reze and transformed and "폭탄의 악마 · 지속 무제한 · Q 상승/내려찍기 · E 오른손 폭발 · R 대폭발"
        or reze and "인간 · M1 기본공격 · CTRL 슬라이딩 · SHIFT 대시 · R 변신"
        or (okkotsuOut and okkotsuOut.weakened and string.format("공격력 -30%% · 반전술식 후유증  %.1f초",okkotsuOut.weakened))
        or string.format("%s   %d%%",KITS[current()].energy,state.energy)
    local alive=h and h.Health>0
    for _,entry in katana.saya do entry.p.Transparency=(alive and zen and sheathing) and 0 or 1 end
    for _,entry in katana.hilt do entry.p.Transparency=(alive and (zen or shanks) and ((drawn and (not entry.drawnOnly or bladeFraction>.02)) or shanks or not entry.drawnOnly)) and 0 or 1 end
end)
player.CharacterAdded:Connect(function()
    clearCastVFX();GojoHands.reset();PainClient.reset();AllMightClient.reset();OkkotsuClient.reset();KizaruClient.reset()
    finishFlameTurn()
    dora.rotorUntil=0;cast=nil;melee=nil;sliding=nil;bombRecoil=nil;attackQueued=false;rezeAirUntil=0;rezeLookUntil=0;blur.Size=0;drawnUntil=0;zenBasicUntil=0;zenReadyPose=nil;zenSheathPlayed=true;blackout.BackgroundTransparency=1
end)
