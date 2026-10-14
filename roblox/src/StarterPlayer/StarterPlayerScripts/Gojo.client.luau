local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local Tween=game:GetService("TweenService")
local Debris=game:GetService("Debris")
local Lighting=game:GetService("Lighting")
local player=Players.LocalPlayer
local C=require(RS:WaitForChild("GojoConfig"))
local action=RS:WaitForChild("GojoAction")
local aimRemote=RS:WaitForChild("GojoAim")
local nextAimAt=0
local event=RS:WaitForChild("GojoFX")
local selectRemote=RS:WaitForChild("SelectCharacter")
local camera=workspace.CurrentCamera
local effects=Instance.new("Folder");effects.Name="LocalGojoFX";effects.Parent=workspace
local viewmodel=Instance.new("Model");viewmodel.Name="GojoViewmodel";viewmodel.Parent=camera
local blur=Instance.new("BlurEffect");blur.Size=0;blur.Parent=Lighting
local state={energy=100,cooldowns={},blueUntil=0,charges=0,chargesUntil=0}
local cast=nil
local flameTurn=nil
local chinOffset=0
local CHIN_DIP=math.rad(7)
local holdState=nil
local slideUntil=0
local drawnUntil,fovKickUntil=0,0
local blueOrbs,shots,activeEffects={},{},{}
local function smoothstep(x) x=math.clamp(x,0,1);return x*x*(3-2*x) end
local clock=workspace.GetServerTimeNow
local function time() return clock(workspace) end
local KITS={
    Gojo={title="五条 悟  ·  고죠 사토루",energy="CURSED ENERGY",hint="Q / E 3초 대기 · 그 안에 다른 쪽 = 무라사키 · 같은 키 = 즉시 발사   /   SHIFT 대시   /   1 · 2 · 3 캐릭터",
        handScale=1,
        slots={{"Blue","Q","아오"},{"Red","E","아카"},{"Domain","R","영역전개"},{"Dash","SHIFT","대시"}}},
    Zenitsu={title="我妻 善逸  ·  아가츠마 젠이츠",energy="BREATH",hint="Q → E  전집중 후 벽력일섬 즉시 ×3   /   SHIFT 대시   /   1 · 2 · 3 캐릭터",
        handScale=1,
        slots={{"Breath","Q","전집중 호흡"},{"Thunderclap","E","벽력일섬"},{"FlameGod","R","화뢰신"},{"Dash","SHIFT","대시"}}},
    Reze={title="レゼ  ·  레제",energy="GUNPOWDER",hint="R 변신(무제한) → Q 폭주대시 → 바로 E = 연계 폭발 킥 · R 다시 = 4초 뒤 대폭발   /   SHIFT 대시   /   1 · 2 · 3 캐릭터",
        handScale=1,
        slots={{"Rampage","Q","폭주대시"},{"Kick","E","폭발 킥"},{"BombDevil","R","폭탄의 악마"},{"Dash","SHIFT","대시"}}},
}
local BOMB_KINDS={BombDevil=true,Rampage=true,Kick=true,Detonation=true}
local function current() local name=player:GetAttribute("Character");return KITS[name] and name or "Gojo" end
local function colorOf(kind) return C.Colors[kind] or (BOMB_KINDS[kind] and C.Colors.Bomb) or ((kind=="Thunderclap" or kind=="Breath" or kind=="FlameGod") and C.Colors.Thunder) or C.Colors.Purple end
local function part(parent,name,size,color,cf,shape)
    local p=Instance.new("Part");p.Name=name;p.Size=size;p.Color=color;p.CFrame=cf or CFrame.identity
    p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
    p.Material=Enum.Material.Neon;p.Shape=shape or Enum.PartType.Block;p.Parent=parent
    return p
end
local function tween(obj,duration,properties)
    Tween:Create(obj,TweenInfo.new(duration,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),properties):Play()
end
local function sound(id,position,volume,speed,duration)
    local holder=part(effects,"SoundPoint",Vector3.one*.1,Color3.new(1,1,1),CFrame.new(position))
    holder.Transparency=1
    local s=Instance.new("Sound");s.SoundId=type(id)=="string" and id or "rbxassetid://"..id;s.Volume=volume;s.PlaybackSpeed=speed or 1
    s.RollOffMaxDistance=90;s.RollOffMinDistance=8;s.Parent=holder;s:Play()
    Debris:AddItem(holder,duration or 3)
end
local function temporary(seconds,update,cleanup)
    table.insert(activeEffects,{start=time(),duration=seconds,update=update,cleanup=cleanup})
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
    for _,o in cast.orbs do o:Destroy() end
    cast.orbs={}
    if cast.merged then cast.merged:Destroy();cast.merged=nil end
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
local function purpleRing(position,direction,radius)
    -- A hollow expanding ring keeps the sphere and targets visible through the pressure wave.
    local frame=CFrame.lookAt(position,position+direction)
    local ring=Instance.new("Model");ring.Name="PurplePressureRing";ring.Parent=effects
    local segments={}
    for i=1,24 do segments[i]=part(ring,"Arc",Vector3.one*.07,C.Colors.Purple) end
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
                o:PivotTo(focus*CFrame.new(side*2.2*spread*math.cos(angle),.1+side*1.5*spread*math.sin(angle),-cfg.OrbDistance))
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
    local dragonFrom=from-flat*10+side*5+Vector3.yAxis*7
    local dragonTo=to-flat*12+side*5+Vector3.yAxis*7
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
    -- Above the straight dash, on the caster's right: after looking back it sits in the upper left.
    for i=0,count do
        local t=i/count
        points[i]=pathPoint(t,0)
    end
    local grow=.45
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
    left.avatar={};right.avatar={}
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
    -- Only arms are rendered. Hidden torso/root/legs would still form a humanoid
    -- collider even with state evaluation disabled, so remove them and all joints.
    local armParts={}
    for _,hd in {left,right} do for _,entry in hd.avatar do armParts[entry.p]=true end end
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
    local size=.42*hd.scale
    for _,entry in hd.avatar do
        if entry.source.Parent then
            entry.p.Size=entry.size*size
            for _,mesh in entry.meshes do mesh.p.Scale=mesh.scale*size end
            entry.p.Color=entry.source.Color
            entry.p.CFrame=camera.CFrame*frame*CFrame.new(entry.offset.Position*size)*entry.offset.Rotation
            entry.p.Transparency=alive and entry.transparency or 1
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
local katana={saya={},hilt={}}
local gold=Color3.fromRGB(201,162,74)
piece(katana.saya,"Saya",Vector3.new(.07,.085,1.45),CFrame.new(0,0,.76),Color3.fromRGB(43,34,51))
piece(katana.saya,"Koiguchi",Vector3.new(.08,.095,.08),CFrame.new(0,0,.06),gold,Enum.Material.Metal)
piece(katana.saya,"Kojiri",Vector3.new(.08,.095,.06),CFrame.new(0,0,1.46),gold,Enum.Material.Metal)
piece(katana.hilt,"Tsuba",Vector3.new(.026,.21,.21),CFrame.Angles(0,math.pi/2,0),Color3.fromRGB(42,37,34),Enum.Material.Metal,Enum.PartType.Cylinder)
piece(katana.hilt,"Tsuka",Vector3.new(.055,.065,.4),CFrame.new(0,0,-.22),Color3.fromRGB(241,234,216))
piece(katana.hilt,"Kashira",Vector3.new(.065,.075,.035),CFrame.new(0,0,-.43),gold,Enum.Material.Metal)
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

local gui=Instance.new("ScreenGui");gui.Name="InfinityHUD";gui.ResetOnSpawn=false;gui.IgnoreGuiInset=true;gui.Parent=player:WaitForChild("PlayerGui")
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
local buttons={}
for i=1,4 do
    local b=Instance.new("TextButton");b.Position=UDim2.fromOffset((i-1)*122,0);b.Size=UDim2.fromOffset(114,70)
    b.BackgroundColor3=Color3.fromRGB(14,21,34);b.BackgroundTransparency=.12;b.TextColor3=Color3.fromRGB(236,243,255)
    b.Font=Enum.Font.GothamMedium;b.TextSize=14;b.Parent=panel
    local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,10);corner.Parent=b
    local stroke=Instance.new("UIStroke");stroke.Thickness=1;stroke.Parent=b
    local entry={b=b,stroke=stroke};buttons[i]=entry
    b.Activated:Connect(function() if entry.skill then action:FireServer(entry.skill,camera.CFrame.LookVector,camera.CFrame.Position) end end)
end
local comboLabel=label(gui,"",26,UDim2.fromScale(.5,.62),UDim2.fromOffset(420,40),Color3.fromRGB(255,224,176));comboLabel.AnchorPoint=Vector2.new(.5,.5)
comboLabel.Font=Enum.Font.GothamBold;comboLabel.TextStrokeTransparency=.35;comboLabel.TextStrokeColor3=Color3.fromRGB(255,122,46)
local hint=label(gui,"",12,UDim2.new(.5,0,1,-26),UDim2.fromOffset(620,22),Color3.fromRGB(144,163,187));hint.AnchorPoint=Vector2.new(.5,0)
local blackout=Instance.new("Frame");blackout.Size=UDim2.fromScale(1,1);blackout.BackgroundColor3=Color3.new(0,0,0)
blackout.BackgroundTransparency=1;blackout.BorderSizePixel=0;blackout.ZIndex=10;blackout.Parent=gui
local picker=Instance.new("Frame");picker.Size=UDim2.fromOffset(320,34);picker.Position=UDim2.new(1,-30,0,28);picker.AnchorPoint=Vector2.new(1,0);picker.BackgroundTransparency=1;picker.Parent=gui
local pickButtons={}
local PICK_NAMES={Gojo="고죠",Zenitsu="젠이츠",Reze="레제"}
for i,name in {"Gojo","Zenitsu","Reze"} do
    local b=Instance.new("TextButton");b.Size=UDim2.fromOffset(100,34);b.Position=UDim2.fromOffset((i-1)*110,0)
    b.Font=Enum.Font.GothamMedium;b.TextSize=13;b.Text=i.."  "..PICK_NAMES[name];b.Parent=picker
    local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,6);corner.Parent=b
    b.Activated:Connect(function() selectRemote:FireServer(name) end)
    pickButtons[name]=b
end
local function announce(name,sub)
    title.Text=name;subtitle.Text=sub;title.TextTransparency=0;subtitle.TextTransparency=0
    task.delay(2,function() tween(title,.6,{TextTransparency=1});tween(subtitle,.6,{TextTransparency=1}) end)
end
local function applyKit()
    local name=current();local kit=KITS[name]
    nameLabel.Text=kit.title;hint.Text=kit.hint
    energy.TextColor3=name=="Zenitsu" and C.Colors.Thunder or name=="Reze" and C.Colors.Bomb or C.Colors.Blue
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
    clearCastVFX();finishFlameTurn()
    cast=nil;holdState=nil;drawnUntil=0;blackout.BackgroundTransparency=1
end
applyKit()
player:GetAttributeChangedSignal("Character"):Connect(applyKit)
UIS.InputBegan:Connect(function(input,processed)
    if processed then return end
    local pick=({[Enum.KeyCode.One]="Gojo",[Enum.KeyCode.Two]="Zenitsu",[Enum.KeyCode.Three]="Reze"})[input.KeyCode]
    if pick then selectRemote:FireServer(pick);return end
    local slot=({[Enum.KeyCode.Q]=1,[Enum.KeyCode.E]=2,[Enum.KeyCode.R]=3,[Enum.KeyCode.LeftShift]=4})[input.KeyCode]
    if slot then action:FireServer(buttons[slot].skill,camera.CFrame.LookVector,camera.CFrame.Position) end
end)
action.OnClientEvent:Connect(function(s) state=s end)

event.OnClientEvent:Connect(function(kind,data)
    if kind=="Cast" then
        if data.kind=="Blue" then task.delay(.42,function() sound(9114427347,data.position,.75,1,2) end) end
        if data.kind=="Purple" or data.kind=="Domain" then sound(9112775414,data.position,.35,.8,3) end
        if data.kind=="Detonation" then
            -- Danger zone: a ring at the blast radius that pulses faster as the fuse runs out.
            local ring=part(effects,"DetonationWarning",Vector3.new(.15,C.Detonation.Radius*2,C.Detonation.Radius*2),C.Colors.Bomb,CFrame.new(data.position-Vector3.new(0,2.85,0))*CFrame.Angles(0,0,math.pi/2),Enum.PartType.Cylinder)
            ring.Transparency=.8
            local length=data.windup
            temporary(length,function(age) ring.Transparency=.55+.35*math.sin(age*(4+age*age*3)) end,function() ring:Destroy() end)
        end
        if data.kind=="Breath" then
            -- Lightning falls around the breathing swordsman, visible to everyone.
            local look=Vector3.new(data.direction.X,0,data.direction.Z);look=look.Magnitude>.05 and look.Unit or Vector3.new(0,0,-1)
            local side=look:Cross(Vector3.yAxis)
            for _,at in {.35,.85,1.35} do
                task.delay(at,function()
                    skyStrike(data.position-Vector3.new(0,3,0)+look*(8+math.random()*10)+side*(math.random()-.5)*16,false)
                end)
            end
        end
        if data.owner==player.UserId then
            holdState=nil;clearCastVFX()
            local length=data.windup or C[data.kind].Windup or .2
            cast={kind=data.kind,start=data.kind=="Purple" and data.start or time(),direction=data.direction,length=length,orbs={},hold=data.kind=="Purple" and C.Purple.Recovery or data.kind=="Kick" and .2 or .15}
            if data.kind=="Purple" then
                local cfg=C.Purple
                cast.orbs={orb((camera.CFrame*CFrame.new(-2.2,.1,-cfg.OrbDistance)).Position,C.Colors.Blue,cfg.ChargeRadius),orb((camera.CFrame*CFrame.new(2.2,.1,-cfg.OrbDistance)).Position,C.Colors.Red,cfg.ChargeRadius)}
                local m=player.Character;local h=m and m:FindFirstChildOfClass("Humanoid")
                if h then h:ChangeState(Enum.HumanoidStateType.Freefall) end
                announce("虚式 • 茈","아오 + 아카  /  무라사키")
            elseif data.kind=="Domain" then announce("領域展開","무량공처 · UNLIMITED VOID")
            elseif data.kind=="Blue" then announce("術式順転 • 蒼","아오 · 인력")
            elseif data.kind=="Red" then announce("術式反転 • 赫","아카 · 척력")
            elseif data.kind=="Thunderclap" then announce("雷の呼吸 • 壱ノ型",length>.1 and "벽력일섬 · 자세를 낮춘다" or "벽력일섬 · 즉시 발동")
            elseif data.kind=="Breath" then announce("全集中の呼吸","전집중 호흡 · 이후 벽력일섬 즉시 ×"..C.Breath.Charges)
            elseif data.kind=="FlameGod" then announce("雷の呼吸 • 漆ノ型","화뢰신 · 火雷神 · 벽력일섬을 초월한 발도")
            elseif data.kind=="BombDevil" then announce("レゼ","쵸커의 핀을 당긴다")
            elseif data.kind=="Kick" then announce("爆裂蹴","폭발 킥")
            elseif data.kind=="Detonation" then announce("大爆発","4초 뒤 광역 대폭발 · 체력 12% 소모") end
        else
            if data.kind=="Purple" then showPurpleCharge(data) else burst(data.position,colorOf(data.kind),3) end
        end
    elseif kind=="Thunderclap" then
        local below=Vector3.new(0,-2.4,0)
        bolt(data.from+below,data.to+below,C.Colors.Thunder,.5,.6)
        bolt(data.from+below*.4,data.to+below*1.1,Color3.fromRGB(255,244,196),.22,.45)
        burst(data.from,C.Colors.Thunder,5);burst(data.to,C.Colors.Thunder,4)
        if data.owner==player.UserId then drawnUntil=time()+.4;fovKickUntil=time()+.25;blur.Size=18 end
    elseif kind=="Strike" then
        skyStrike(data.position,data.big)
    elseif kind=="FlameGod" then
        dragon(data.from,data.to)
        bolt(data.from-Vector3.new(0,2.4,0),data.to-Vector3.new(0,2.4,0),Color3.fromRGB(255,248,220),.6,.5)
        burst(data.from,C.Colors.Thunder,8)
        if data.owner==player.UserId then
            drawnUntil=time()+.8;blur.Size=18
            local m=player.Character;local root=m and m:FindFirstChild("HumanoidRootPart")
            local h=m and m:FindFirstChildOfClass("Humanoid")
            if root and h then
                finishFlameTurn()
                flameTurn={requested=time(),destination=data.to,root=root,humanoid=h,autoRotate=h.AutoRotate,
                    cameraType=camera.CameraType}
                h.AutoRotate=false
            end
        end
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
    elseif kind=="Rampage" then
        -- Blast under the feet, then a line of gunpowder along the path that chain-detonates after the delay.
        local below=Vector3.new(0,-2.8,0)
        blast(data.from+below*.7,6)
        local dir=data.to-data.from;local length=dir.Magnitude
        local grains={}
        if length>.5 then
            local unit=dir.Unit;local side=unit:Cross(Vector3.yAxis)
            for i=0,math.floor(length/2) do
                local at=data.from+below+unit*i*2+side*(math.random()-.5)*1.2
                local grain=part(effects,"Gunpowder",Vector3.new(1.1,.08,1.1)*(.6+math.random()*.6),Color3.fromRGB(32,28,26),CFrame.new(at)*CFrame.Angles(0,math.random()*6,0))
                grain.Material=Enum.Material.Sand
                local ember=part(effects,"Ember",Vector3.one*.16,C.Colors.Bomb,CFrame.new(at+Vector3.new(0,.12,0)),Enum.PartType.Ball)
                Debris:AddItem(grain,data.delay+3);Debris:AddItem(ember,data.delay+3)
                table.insert(grains,{grain,ember,at})
            end
        end
        task.delay(data.delay,function()
            for i,g in grains do
                task.delay(i*.03,function()
                    g[1]:Destroy();g[2]:Destroy()
                    if i%2==1 then blast(g[3]+Vector3.new(0,1.2,0),5) end
                end)
            end
        end)
        if data.owner==player.UserId then
            fovKickUntil=time()+.2;blur.Size=14
            if data.slide then slideUntil=time()+.55 end
            announce("連携","E 폭발 킥으로 연계! · "..C.Kick.ComboWindow.."초")
        end
    elseif kind=="Kick" then
        -- Explosive kick: a flaming streak along the combo dash, then the blast.
        if data.combo then
            bolt(data.from-Vector3.new(0,2.2,0),data.to-Vector3.new(0,2.2,0),C.Colors.Bomb,.45,.45)
            bolt(data.from-Vector3.new(0,1.2,0),data.to-Vector3.new(0,1.2,0),Color3.fromRGB(255,236,190),.18,.35)
        end
        blast(data.to,data.radius)
        -- Crescent slash sweeping right to left at hip height, drawn one segment at a time.
        do
            local forward=Vector3.new(data.to.X-data.from.X,0,data.to.Z-data.from.Z)
            forward=forward.Magnitude>.1 and forward.Unit or Vector3.new(0,0,-1)
            local radius=data.combo and 5.5 or 4.2
            local center=data.from+Vector3.new(0,-.8,0)
            local count=12;local points={}
            for i=0,count do
                local angle=math.rad(75-150*i/count)
                points[i]=center+CFrame.fromAxisAngle(Vector3.yAxis,angle):VectorToWorldSpace(forward)*radius
            end
            for i=1,count do
                task.delay(i*.012,function()
                    local a,b=points[i-1],points[i]
                    local seg=part(effects,"KickArc",Vector3.new(data.combo and .45 or .3,.16,(b-a).Magnitude+.3),C.Colors.Bomb,CFrame.lookAt((a+b)/2,b))
                    tween(seg,.3,{Transparency=1,Size=Vector3.new(.05,.05,seg.Size.Z)});Debris:AddItem(seg,.35)
                end)
            end
        end
        if data.owner==player.UserId then
            fovKickUntil=time()+(data.combo and .3 or .15);blur.Size=data.combo and 20 or 10
            if data.combo then announce("連携","폭주 연계 · 폭발 킥") end
        end
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
        -- Blue or Red held with an arm raised; the server fires it (or Purple) when the hold ends.
        if data.owner==player.UserId then
            holdState={kind=data.kind,start=time(),duration=data.duration}
            local blue=data.kind=="Blue"
            announce(blue and "術式順転 • 蒼  ·  대기" or "術式反転 • 赫  ·  대기",(blue and "E 아카" or "Q 아오").." → 무라사키   /   "..(blue and "Q" or "E").." 다시 → 즉시 발사")
        else
            burst(data.position,colorOf(data.kind),2)
        end
    elseif kind=="Blue" then
        local model=orb(data.position,C.Colors.Blue,1.1)
        if blueOrbs[data.owner] then blueOrbs[data.owner]:Destroy() end
        blueOrbs[data.owner]=model
        burst(data.position,C.Colors.Blue,5)
        task.delay(data.duration,function() if blueOrbs[data.owner]==model then model:Destroy();blueOrbs[data.owner]=nil end end)
    elseif kind=="BlueEnd" then
        if blueOrbs[data.owner] then blueOrbs[data.owner]:Destroy();blueOrbs[data.owner]=nil end
    elseif kind=="Projectile" then
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
        temporary(data.duration,function(age)
            local inside=(camera.CFrame.Position-center).Magnitude<r
            for _,wall in backdrop do wall.Transparency=inside and 0 or 1 end
            dome.CFrame=CFrame.new(center)*CFrame.Angles(0,age*.035,0)
            for i,p in stars do p.Transparency=.25+math.sin(age*2+i)*.23 end
        end,function()
            for _,wall in backdrop do wall:Destroy() end
            tween(dome,.6,{Transparency=1});Debris:AddItem(dome,.7)
            for _,p in stars do tween(p,.5,{Transparency=1});Debris:AddItem(p,.6) end
        end)
    end
end)

Run:BindToRenderStep("RezeChinReset",Enum.RenderPriority.Camera.Value-1,function()
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
    local reze=current()=="Reze"
    local pinShown=cast and cast.kind=="BombDevil"
    local kickSwing,kickLift,kickUp,kickYaw,kickRoll=-1,0,0,0,0
    local pinGrabbed,pinHooked,chinTilt,handSize=false,false,0,KITS[current()].handScale
    local look=camera.CFrame.LookVector;local flat=Vector3.new(look.X,0,look.Z)
    local neckFrame=CFrame.lookAt(camera.CFrame.Position,camera.CFrame.Position+(flat.Magnitude>.01 and flat.Unit or Vector3.new(0,0,-1)))
    local l=CFrame.new(-.64,-.78,-1.15)*CFrame.Angles(.12,.08,-.08)
    local r=CFrame.new(.64,-.78,-1.15)*CFrame.Angles(.12,-.08,.08)
    local swordPos,swordDir=Vector3.new(-.05,-.5+bob,-1.12),Vector3.new(.8,.25,-.55).Unit
    local push,lean=0,0
    local desiredFov=72;blur.Size=math.max(0,blur.Size-dt*24)
    local m=player.Character;local h=m and m:FindFirstChildOfClass("Humanoid")
    local transformed=reze and m and (m:GetAttribute("BombDevilUntil") or 0)>n
    if current()=="Gojo" and (holdState or (cast and (cast.kind=="Red" or cast.kind=="Purple"))) and n>=nextAimAt then
        nextAimAt=n+1/20
        aimRemote:FireServer(camera.CFrame.LookVector,camera.CFrame.Position)
    end
    if cast and not (h and h.Health>0) then clearCastVFX();finishFlameTurn();cast=nil end
    if cast then
        local a=n-cast.start;local u=math.clamp(a/cast.length,0,1)
        if cast.kind=="Blue" then
            r=CFrame.new(.25,-.28,-.7)*CFrame.Angles(-.2,0,.25+math.sin(a*70)*.025)
        elseif cast.kind=="Red" then r=CFrame.new(.17,-.25,-.85)*CFrame.Angles(-.5,0,.2)
        elseif cast.kind=="Purple" then
            local cfg=C.Purple
            local angle=smoothstep(a/cfg.RiseDuration)*math.pi*2
            local spread=1-smoothstep((a-cfg.Windup*.5)/(cfg.MergeAt-cfg.Windup*.5))
            local radius=.4*spread
            l=CFrame.new(-.08-math.cos(angle)*radius,-.12-math.sin(angle)*radius,-.87)*CFrame.Angles(-.2,.25,-angle*.25)
            r=CFrame.new(.08+math.cos(angle)*radius,-.12+math.sin(angle)*radius,-.87)*CFrame.Angles(-.2,-.25,angle*.25)
            desiredFov=72-8*smoothstep(a/cfg.RiseDuration)
            -- The spheres orbit in clear view, then become one visible Purple at the launch point.
            local focus=camera.CFrame
            local center=(focus*CFrame.new(0,0,-cfg.OrbDistance)).Position
            if not cast.fired then
                if a<cfg.MergeAt then
                    for i,o in cast.orbs do
                        local side=i==1 and -1 or 1
                        o:PivotTo(focus*CFrame.new(side*2.2*spread*math.cos(angle),.1+side*1.5*spread*math.sin(angle),-cfg.OrbDistance))
                    end
                else
                    if not cast.merged then
                        for _,o in cast.orbs do o:Destroy() end;cast.orbs={}
                        cast.merged=orb(center,C.Colors.Purple,cfg.MergedRadius)
                        cast.merged.Name="HollowPurpleCharge";cast.merged.PrimaryPart.Color=Color3.fromRGB(227,192,255)
                        burst(center,C.Colors.Purple,3);purpleRing(center,focus.LookVector,1)
                    end
                    local charge=smoothstep((a-cfg.MergeAt)/(cfg.Windup-cfg.MergeAt))
                    cast.merged:ScaleTo(.8+.4*charge);cast.merged:PivotTo(CFrame.new(center)*focus.Rotation)
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
        elseif cast.kind=="Domain" then
            l=CFrame.new(-.1,-.15+(1-u)*-.35,-.7)*CFrame.Angles(-.15,0,-.12)
            r=CFrame.new(.1,-.15+(1-u)*-.35,-.7)*CFrame.Angles(-.15,0,.12)
            blur.Size=math.sin(u*math.pi)*13;desiredFov=66
        elseif cast.kind=="Dash" then desiredFov=84
        elseif (cast.kind=="Thunderclap" or cast.kind=="FlameGod") and cast.length>.1 then
            -- Crouched draw stance with static crackling at the feet; the seventh form sinks lower and crackles harder.
            local god=cast.kind=="FlameGod"
            local recovery=god and smoothstep((a-cast.length)/.3) or 0
            lean=math.clamp(a/(god and .3 or .5),0,1)*(god and 1.3 or 1)*(1-recovery)
            swordPos+=Vector3.new(0,-.06,.08)*lean;desiredFov=god and (62+10*recovery) or 68
            if m and math.random()<dt*(god and 40 or 14) then
                local root=m:FindFirstChild("HumanoidRootPart")
                if root then
                    local foot=root.Position+root.CFrame.LookVector*(2+math.random()*2)+Vector3.new((math.random()-.5)*3,-2.9,(math.random()-.5)*3)
                    bolt(foot,foot+Vector3.new((math.random()-.5)*1.2,1+math.random()*2,(math.random()-.5)*1.2),C.Colors.Thunder,.06,.12)
                end
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
        elseif cast.kind=="Rampage" then
            -- Arms flung back by the blast under the feet.
            local k=math.clamp(a/math.max(cast.length,.05),0,1)
            l=CFrame.new(-.6,-.62-.2*k,-.62)*CFrame.Angles(.6*k,.2,-.4);r=CFrame.new(.6,-.62-.2*k,-.62)*CFrame.Angles(.6*k,-.2,.4)
            desiredFov=90
        elseif cast.kind=="Kick" then
            -- Roundhouse: the right foot is lifted and held for ~0.3s while the body coils right, then the leg whips
            -- across the view from right to left and the camera turns with it.
            local function smooth(x) x=math.clamp(x,0,1);return x*x*(3-2*x) end
            local lift=smooth(a/.3);local sw=smooth((a-.3)/.16);local up=math.sin(sw*math.pi)
            kickLift=lift*(1-sw);kickSwing=sw;kickUp=up
            kickYaw=(-.34*lift*(1-sw)+.46*sw)*(1-smooth((a-.55)/.3));kickRoll=-.1*up+.04*lift*(1-sw)
            lean=(.25*lift*(1-sw)+.55*up);desiredFov=78-6*lift*(1-sw)+8*up
            l=CFrame.new(-.6,-.62,-.62)*CFrame.Angles(.4,.2,-.4);r=CFrame.new(.6-.2*sw,-.62,-.62)*CFrame.Angles(.4,-.2,.4)
        elseif cast.kind=="Detonation" then
            -- Hands clenched before the face while the fuse burns; the view shudders harder every second.
            local shake=(a/cast.length)^2*.02
            l=CFrame.new(-.16,-.2,-.66)*CFrame.Angles(.1,.7,-.5);r=CFrame.new(.16,-.2,-.66)*CFrame.Angles(.1,-.7,.5)
            camera.CFrame*=CFrame.new((math.random()-.5)*shake*2,(math.random()-.5)*shake*2,0)
            desiredFov=66-8*(a/cast.length)
        elseif cast.kind=="Breath" then
            push=.05*math.clamp(a/.4,0,1);swordPos+=Vector3.new(0,math.sin(a*3.2)*.02,0);desiredFov=66
        end
        if a>=cast.length+cast.hold then clearCastVFX();cast=nil end
    end
    if chinTilt>0 then chinOffset=CHIN_DIP*chinTilt;camera.CFrame*=CFrame.Angles(-chinOffset,0,0) end
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
    -- Skid after a Rampage that hit nothing: drop low and recover.
    if n<slideUntil then lean=math.max(lean,.9*math.clamp((slideUntil-n)/.55,0,1)) end
    -- Hold: Blue raises the right arm, Red the left, with the technique gathering in the palm.
    local holdHand=nil
    if holdState then
        if n-holdState.start>holdState.duration+1 then holdState=nil
        else
            local k=math.clamp((n-holdState.start)/.25,0,1)
            if holdState.kind=="Blue" then r=CFrame.new(.3,-.42+.3*k,-.8)*CFrame.Angles(.35*k,0,.3-.22*k);holdHand=r
            else l=CFrame.new(-.3,-.42+.3*k,-.8)*CFrame.Angles(.35*k,0,-.3+.22*k);holdHand=l end
        end
    end
    if n<fovKickUntil then desiredFov=94 end
    if h then h.CameraOffset=h.CameraOffset:Lerp(Vector3.new(0,-1.3*lean,0),math.min(1,dt*10)) end
    camera.FieldOfView+=(desiredFov-camera.FieldOfView)*math.min(1,dt*8)
    local width=camera.ViewportSize.X;scale.Scale=math.min(1,(width-28)/480)
    local handScale=math.min(1,camera.ViewportSize.X/camera.ViewportSize.Y)
    local drawn=n<drawnUntil
    local alive=h and h.Health>0
    local posed=zen or cast~=nil or holdHand~=nil
    local leftFrame,rightFrame=l,r
    if zen then
        swordPos*=Vector3.new(handScale,1,1)
        local sword=CFrame.lookAt(swordPos,swordPos+swordDir)
        local hilt=sword*CFrame.new(0,0,-push)
        if drawn then
            local at=Vector3.new(.32*handScale,-.38,-.92);hilt=CFrame.lookAt(at,at-Vector3.new(-.75,.06,-.66))
        end
        place(katana.saya,sword);place(katana.hilt,hilt)
        rightFrame=armFrame((hilt*GRIP).Position,RIGHT_UP)
        leftFrame=armFrame((sword*SAYA).Position,LEFT_UP)
    else
        scaleHand(right,handSize)
        if holdHand then
            holdOrb.CFrame=camera.CFrame*CFrame.new(holdHand.Position*Vector3.new(handScale,1,1))*holdHand.Rotation*CFrame.new(0,.3,0)
            holdOrb.Color=C.Colors[holdState.kind];holdOrb.Size=Vector3.one*(.16+math.sin(n*14)*.015)
        end
        leftFrame=CFrame.new(l.Position*Vector3.new(handScale,1,1))*l.Rotation
        -- While pulling the pin the hand must meet the ring exactly, so the narrow-screen squeeze is skipped.
        rightFrame=pinShown and r or CFrame.new(r.Position*Vector3.new(handScale,1,1))*r.Rotation
        if pinShown then
            pinPart.CFrame=pinGrabbed and camera.CFrame*r*CFrame.new(PIN_IN_HAND.Position*handSize)*PIN_IN_HAND.Rotation or neckFrame*RING_AT*CFrame.Angles(0,0,pinHooked and math.sin(n*50)*.15 or 0)
        end
    end
    showAvatarArm(left,leftFrame,posed,alive)
    showAvatarArm(right,rightFrame,posed,alive)
    local pinVisible=pinShown and pinGrabbed and h and h.Health>0 and chinTilt>0
    for _,entry in pinRing do entry.p.CFrame=pinPart.CFrame*entry.offset;entry.p.Transparency=pinVisible and 0 or 1 end
    if kickSwing>=0 then
        local sw=kickSwing
        boot.CFrame=camera.CFrame*CFrame.new(1.05*(1-2*sw)*.8,-.9+.4*kickLift+.45*kickUp,-.5-.25*kickLift-.5*kickUp)*CFrame.Angles(-.3*kickLift-.5*kickUp,-1.3+2.6*sw,(.55-1.1*sw)*.6)
        boot.Transparency=(h and h.Health>0) and 0 or 1
    else boot.Transparency=1 end
    holdOrb.Transparency=(holdHand and not zen and h and h.Health>0) and .15 or 1
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
    local charged=zen and (state.charges or 0)>0 and (state.chargesUntil or 0)>n
    local slowed=m and (m:GetAttribute("SlowedUntil") or 0)-n or 0
    for _,entry in buttons do
        local cooldown=(entry.skill=="Thunderclap" and charged) and 0 or math.max(0,(state.cooldowns[entry.skill] or 0)-n)
        if entry.skill=="Dash" and slowed>0 then cooldown=math.max(cooldown,slowed) end
        local text=entry.name
        local held=state.holdKind or ""
        if entry.key=="R" and reze then entry.skill=transformed and "Detonation" or "BombDevil";entry.name=transformed and "대폭발" or "폭탄의 악마";entry.stroke.Color=colorOf(entry.skill) end
        if held~="" and (entry.skill=="Blue" or entry.skill=="Red") then
            if entry.skill==held then text=entry.name.." 발사";cooldown=0 else text="무라사키" end
        end
        if entry.skill=="Thunderclap" and charged then text=string.format("벽력일섬 ×%d",state.charges) end
        if entry.skill=="Kick" then
            local ready=(state.comboUntil or 0)-n
            if transformed and ready>0 then
                text=string.format("연계 킥!  %.1f",ready);cooldown=0
                entry.stroke.Thickness=3;entry.stroke.Color=Color3.fromRGB(255,224,176)
                entry.b.BackgroundColor3=Color3.fromRGB(70,30,12)
            else
                entry.stroke.Thickness=1;entry.stroke.Color=colorOf("Kick");entry.b.BackgroundColor3=Color3.fromRGB(14,21,34)
            end
        end
        if reze and not transformed and (entry.skill=="Rampage" or entry.skill=="Kick") then text=entry.name.." (변신 필요)";cooldown=math.max(cooldown,.001) end
        entry.b.Text=entry.key.."\n"..text..(cooldown>0 and string.format("  %.1f",cooldown) or "")
        entry.b.BackgroundTransparency=cooldown>0 and .5 or .12
    end
    do
        local ready=(state.comboUntil or 0)-n
        if current()=="Reze" and ready>0 and transformed then
            comboLabel.Text=string.format("E  연계 킥!   %.1f",ready)
            comboLabel.TextTransparency=.1+.25*math.abs(math.sin(n*9))
        else comboLabel.Text="" end
    end
    health.Text=h and string.format("HP  %d / %d",h.Health,h.MaxHealth) or "RESPAWNING"
    local locked=m and (m:GetAttribute("DomainLockedUntil") or 0)>n
    energy.Text=locked and "영역 안 · 이동 가능 / 스킬 봉인"
        or slowed>0 and string.format("반동 · 이동 속도 저하 · 대시 불가  %.1f", slowed)
        or reze and transformed and "폭탄의 악마 · 지속 무제한 · 기본 스킬 HP 3% · R 대폭발"
        or reze and "변신 전 · R 폭탄의 악마 / SHIFT 대시만 사용 가능"
        or string.format("%s   %d%%",KITS[current()].energy,state.energy)
    local alive=h and h.Health>0
    for _,entry in katana.saya do entry.p.Transparency=(alive and zen) and 0 or 1 end
    for _,entry in katana.hilt do entry.p.Transparency=(alive and zen and (drawn or not entry.drawnOnly)) and 0 or 1 end
end)
player.CharacterAdded:Connect(function()
    clearCastVFX()
    finishFlameTurn()
    cast=nil;blur.Size=0;drawnUntil=0;blackout.BackgroundTransparency=1
end)
