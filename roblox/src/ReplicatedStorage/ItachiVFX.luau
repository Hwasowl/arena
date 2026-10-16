-- Uchiha Itachi world effects, run on every client from the server's Itachi* events: real flapping crows, feathers,
-- the black Amaterasu field, Susanoo with the Yata Mirror and the Totsuka Blade, the seal, eye glow and bowed heads.
-- Nothing here touches gameplay: positions come from the server, every part is anchored and non-collidable, crows and
-- flames are pooled, distant fields draw fewer flames, and each effect has a hard lifetime.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Debris=game:GetService("Debris")
local RS=game:GetService("ReplicatedStorage")
local I=require(RS:WaitForChild("ItachiConfig"))
local COLORS=I.Colors

local VFX={}
VFX.Sounds=I.Sounds
local folder=Instance.new("Folder");folder.Name="ItachiFX";folder.Parent=workspace
VFX.folder=folder
local active={}
local function clock() return workspace:GetServerTimeNow() end
local function smoothstep(x) x=math.clamp(x,0,1);return x*x*(3-2*x) end
local function window(a,from,to) return math.clamp((a-from)/(to-from),0,1) end
local function bump(a,from,to) local k=window(a,from,to);return math.sin(k*math.pi) end
VFX.smoothstep=smoothstep;VFX.window=window;VFX.bump=bump
local function run(duration,update,cleanup,start)
    local e={start=start or clock(),duration=duration,update=update,cleanup=cleanup}
    table.insert(active,e);return e
end
VFX.run=run
local function part(name,size,color,cf,shape,material)
    local p=Instance.new("Part");p.Name=name;p.Size=size;p.Color=color;p.CFrame=cf or CFrame.identity
    p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
    p.Material=material or Enum.Material.Neon;p.Shape=shape or Enum.PartType.Block;p.Parent=folder
    return p
end
VFX.part=part
function VFX.sound(name,position,volume,duration,speedScale)
    local cue=VFX.Sounds[name];if not cue then return end
    local holder=part("ItachiSound",Vector3.one*.1,Color3.new(),CFrame.new(position));holder.Transparency=1
    local s=Instance.new("Sound");s.SoundId=cue.id;s.Volume=volume or .6;s.PlaybackSpeed=cue.speed*(speedScale or 1)
    s.RollOffMinDistance=14;s.RollOffMaxDistance=260;s.Parent=holder;s:Play()
    Debris:AddItem(holder,duration or 3)
    return s,holder
end
local function rootOf(model) return model and model:FindFirstChild("HumanoidRootPart") end
VFX.rootOf=rootOf
local PARK=CFrame.new(0,-5000,0)
-- Level of detail: effects far from the camera draw fewer pieces.
local function detail(position)
    local cam=workspace.CurrentCamera
    local d=cam and (cam.CFrame.Position-position).Magnitude or 0
    return d>140 and .3 or d>80 and .6 or 1
end
VFX.detail=detail

---------------------------------------------------------------- crows and feathers
-- A crow: body, head, beak, tail, two wings that flap about the shoulder line, two red eyes. Pooled.
local crowPool={}
local function buildCrow()
    local m=Instance.new("Model");m.Name="ItachiCrow"
    local function cp(name,size,color,shape,material)
        local p=part(name,size,color,PARK,shape,material or Enum.Material.SmoothPlastic);p.Parent=m;return p
    end
    local c={model=m}
    c.body=cp("Body",Vector3.new(.55,.5,1.1),COLORS.Crow,Enum.PartType.Ball)
    c.head=cp("Head",Vector3.new(.38,.38,.38),COLORS.Crow,Enum.PartType.Ball)
    c.beak=cp("Beak",Vector3.new(.1,.1,.32),Color3.fromRGB(30,30,34))
    c.tail=cp("Tail",Vector3.new(.42,.05,.6),COLORS.Crow)
    c.wl=cp("Wing",Vector3.new(1.3,.05,.55),COLORS.Crow);c.wr=cp("Wing",Vector3.new(1.3,.05,.55),COLORS.Crow)
    c.el=cp("Eye",Vector3.one*.07,COLORS.Red,Enum.PartType.Ball,Enum.Material.Neon);c.er=cp("Eye",Vector3.one*.07,COLORS.Red,Enum.PartType.Ball,Enum.Material.Neon)
    m.Parent=folder
    return c
end
local function acquireCrow() return table.remove(crowPool) or buildCrow() end
local function releaseCrow(c)
    for _,p in c.model:GetChildren() do p.CFrame=PARK end
    table.insert(crowPool,c)
end
-- Places a crow at `cf` (looking along -Z) with wings at `flap` radians and an overall `size`.
local function poseCrow(c,cf,flap,size)
    local s=size or 1
    local function at(p,offset,base) p.CFrame=cf*CFrame.new(offset*s)*(base or CFrame.identity) end
    for _,p in {c.body,c.head,c.beak,c.tail,c.wl,c.wr,c.el,c.er} do
        local base=p:GetAttribute("BaseSize");if not base then base=p.Size;p:SetAttribute("BaseSize",base) end
        p.Size=base*s
    end
    at(c.body,Vector3.zero);at(c.head,Vector3.new(0,.12,-.6));at(c.beak,Vector3.new(0,.08,-.86),CFrame.Angles(-.15,0,0))
    at(c.tail,Vector3.new(0,.04,.75),CFrame.Angles(.15,0,0))
    c.wl.CFrame=cf*CFrame.new(-.18*s,.12*s,-.05*s)*CFrame.Angles(0,0,flap)*CFrame.new(-.6*s,0,0)
    c.wr.CFrame=cf*CFrame.new(.18*s,.12*s,-.05*s)*CFrame.Angles(0,0,-flap)*CFrame.new(.6*s,0,0)
    at(c.el,Vector3.new(-.13,.2,-.72));at(c.er,Vector3.new(.13,.2,-.72))
end
-- One crow following path(u) for `life` seconds, facing its direction of travel and flapping.
function VFX.crow(path,life,size,flapRate,start)
    local c=acquireCrow();local last=path(0);local rate=flapRate or 22;local seed=math.random()*6
    return run(life,function(a)
        local u=a/life;local p=path(u)
        local dir=p-last;last=p
        local cf=dir.Magnitude>.001 and CFrame.lookAt(p,p+dir) or CFrame.new(p)
        poseCrow(c,cf,math.sin(a*rate+seed)*.9,size)
    end,function() releaseCrow(c) end,start)
end
local function feather(position,velocity,life)
    local p=part("ItachiFeather",Vector3.new(.08,.02,.5),COLORS.Crow,CFrame.new(position)*CFrame.Angles(math.random()*6,math.random()*6,0),nil,Enum.Material.SmoothPlastic)
    local v=velocity;local spin=Vector3.new(math.random()-.5,math.random()-.5,math.random()-.5)*6
    run(life,function(a,dt)
        v=v*(1-dt*1.8)+Vector3.new(math.sin(a*5)*.6,-1.2,0)*dt
        p.CFrame=(p.CFrame+v*dt)*CFrame.Angles(spin.X*dt,spin.Y*dt,spin.Z*dt)
        p.Transparency=smoothstep((a-life*.6)/(life*.4))
    end,function() p:Destroy() end)
end
VFX.feather=feather
function VFX.feathers(center,count,spread,life)
    count=math.max(1,math.floor(count*detail(center)))
    for _=1,count do
        local o=Vector3.new(math.random()-.5,math.random()-.5,math.random()-.5)*spread
        feather(center+o,o.Unit*(1+math.random()*3)+Vector3.yAxis*math.random()*2,life or 1.2)
    end
end

---------------------------------------------------------------- bodies
-- Hides (1) or shows (0) a character for this client; `reveal` lets feet come back first (0..1 from the floor up).
function VFX.setBodyAlpha(model,alpha,reveal)
    local root=rootOf(model);if not root then return end
    local floorY=root.Position.Y-3;local top=root.Position.Y+2.6
    for _,v in model:GetDescendants() do
        if (v:IsA("BasePart") and v.Name~="HumanoidRootPart") or v:IsA("Decal") then
            local a=alpha
            if reveal and v:IsA("BasePart") then
                local h=(v.Position.Y-floorY)/(top-floorY)
                a=h<=reveal*1.15-.05 and 0 or 1
            end
            v.LocalTransparencyModifier=a
        end
    end
end
-- Mangekyo glow on the third-person eyes.
function VFX.eyeGlow(model,level)
    if not model then return end
    for _,v in model:GetDescendants() do
        if v:IsA("PointLight") and v.Name=="ItachiEyeGlow" then v.Brightness=.25+3.5*level;v.Range=2.5+5*level end
    end
end

---------------------------------------------------------------- passive: Crow Clone
-- 0-.1 flinch and feathers; .1-.25 the body breaks into crows; .25-.45 they fly to the new spot;
-- .45-.65 they spiral back and the body reforms feet first; the eyes flash; .65-.85 recovery.
function VFX.crowClone(model,data)
    local cfg=I.CrowClone;local start=data.start
    local from,to=data.from,data.to
    VFX.sound("Caw",from,.8,2);VFX.sound("Flutter",from,.6,2)
    VFX.feathers(from+Vector3.yAxis*.5,14,2.5,1)
    local n=math.max(6,math.floor(16*detail(from)))
    for i=1,n do
        local ang=i/n*math.pi*2;local h=-2+(i%5)*1
        local burst=from+Vector3.new(math.cos(ang)*2.5,h+1.5,math.sin(ang)*2.5)
        local seed=math.random()*6
        VFX.crow(function(u)
            -- burst out (0-.25 of life), fly (.25-.6), spiral down onto the new spot (.6-1)
            local k1=smoothstep(u/.25);local k2=smoothstep((u-.25)/.35);local k3=smoothstep((u-.6)/.4)
            local a=from:Lerp(burst,k1)
            local b=a:Lerp(to+(burst-from)*.8+Vector3.yAxis*1.2,k2)+Vector3.yAxis*math.sin(k2*math.pi)*2
            local spiral=to+Vector3.new(math.cos(ang+u*9+seed)*(1.6*(1-k3)+.2),-2.4+3.6*(1-k3)+(i%5)*.5*(1-k3),math.sin(ang+u*9+seed)*(1.6*(1-k3)+.2))
            return b:Lerp(spiral,k3)
        end,cfg.Reform-cfg.Break,.75+math.random()*.35,24,start+cfg.Break)
    end
    run(cfg.Total+.05,function(a)
        if a<cfg.Break then VFX.setBodyAlpha(model,0)
        elseif a<cfg.MoveTo then VFX.setBodyAlpha(model,1)
        elseif a<cfg.Reform then VFX.setBodyAlpha(model,0,smoothstep(window(a,cfg.MoveTo,cfg.Reform)))
        else VFX.setBodyAlpha(model,0) end
        VFX.eyeGlow(model,bump(a,cfg.Reform-.05,cfg.Total))
    end,function() VFX.setBodyAlpha(model,0);VFX.eyeGlow(model,0) end,start)
    task.delay(math.max(0,start+cfg.MoveTo-clock()),function() VFX.sound("Flutter",to,.6,2,.8) end)
end

---------------------------------------------------------------- Q: Tsukuyomi (what everyone sees)
-- The caster's eyes flare; at the wave a red ring runs from the outstretched hand to the victim, whose head bows.
function VFX.tsukuyomi(model,data)
    local cfg=I.Tsukuyomi;local start=data.start
    local root=rootOf(model);local target=data.target
    if root then VFX.sound("Eye",root.Position,.7,2) end
    run(cfg.End,function(a)
        VFX.eyeGlow(model,.3+.7*window(a,cfg.Prep,cfg.Eye))
    end,function() VFX.eyeGlow(model,0) end,start)
    task.delay(math.max(0,start+cfg.Wave-.18-clock()),function()
        local r=rootOf(model);local tr=rootOf(target);if not r or not tr then return end
        local from=r.Position+Vector3.yAxis*1;local to=tr.Position+Vector3.yAxis*1
        local ring=part("ItachiWave",Vector3.new(.2,2,2),COLORS.Red,CFrame.new(from),Enum.PartType.Cylinder)
        run(.2,function(a)
            local u=a/.2;local p=from:Lerp(to,u)
            ring.CFrame=CFrame.lookAt(p,to)*CFrame.Angles(0,math.pi/2,0);ring.Size=Vector3.new(.2,1+3*u,1+3*u);ring.Transparency=.2+.5*u
        end,function() ring:Destroy() end)
        VFX.sound("Wave",to,.7,2)
    end)
end

---------------------------------------------------------------- E: Amaterasu
-- Flames are pooled: a black core spike and a dark red halo slightly larger behind it. Never orange.
local flamePool={}
local function acquireFlame()
    local f=table.remove(flamePool)
    if not f then
        f={core=part("ItachiFlame",Vector3.one,COLORS.Black,PARK,Enum.PartType.Ball,Enum.Material.SmoothPlastic),
            halo=part("ItachiFlameHalo",Vector3.one,COLORS.Crimson,PARK,Enum.PartType.Ball,Enum.Material.Neon)}
        f.halo.Transparency=.55
    end
    return f
end
local function releaseFlame(f) f.core.CFrame=PARK;f.halo.CFrame=PARK;table.insert(flamePool,f) end
local function edge(seed,angle)
    return .82+.1*math.sin(angle*3+seed)+.06*math.sin(angle*7+seed*2.3)+.04*math.sin(angle*13+seed*.7)
end
VFX.edge=edge
local function fieldRadius(age)
    local cfg=I.Amaterasu
    if age<cfg.Ignite then return 0 end
    if age<cfg.Spread then return cfg.StartRadius*smoothstep(window(age,cfg.Ignite,cfg.Ignite+.12)) end
    if age<cfg.BurnEnd then return cfg.StartRadius+(cfg.Radius-cfg.StartRadius)*smoothstep(window(age,cfg.Spread,cfg.Full)) end
    return cfg.Radius*(1-smoothstep(window(age,cfg.BurnEnd,cfg.Gone)))
end
VFX.fieldRadius=fieldRadius
local fieldsByKey={}
function VFX.amaterasu(data)
    local cfg=I.Amaterasu;local start=data.start;local center=data.center;local seed=data.seed
    local key=tostring(data.owner)..":"..tostring(start)
    local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.RespectCanCollide=true
    local list={folder};for _,p in Players:GetPlayers() do if p.Character then table.insert(list,p.Character) end end
    params.FilterDescendantsInstances=list
    -- Flame spots on a jittered grid inside the edge, each on real floor and not behind a wall from the centre.
    local spots={}
    local step=1.7/math.sqrt(detail(center))
    for x=-cfg.Radius,cfg.Radius,step do
        for z=-cfg.Radius,cfg.Radius,step do
            local o=Vector3.new(x+(math.random()-.5)*step,0,z+(math.random()-.5)*step)
            local d=o.Magnitude;local ang=math.atan2(o.Z,o.X)
            if d<=cfg.Radius*edge(seed,ang) then
                local floor=workspace:Raycast(center+o+Vector3.yAxis*(cfg.StepHeight+1),Vector3.yAxis*-(cfg.StepHeight*2+2),params)
                if floor and math.abs(floor.Position.Y-center.Y)<=cfg.StepHeight and floor.Normal.Y>.6 then
                    local blocked=d>1 and workspace:Raycast(center+Vector3.yAxis*1.5,Vector3.new(o.X,floor.Position.Y-center.Y,o.Z),params)
                    if not blocked then
                        local edgeK=d/(cfg.Radius*edge(seed,ang))
                        table.insert(spots,{pos=floor.Position,d=d/edge(seed,ang),h=(1.2+math.random()*3.8)*(1-.45*edgeK),w=.5+math.random()*.6,ph=math.random()*6})
                    end
                end
            end
        end
    end
    -- Faint black marker where the eye looks, before ignition.
    local marker=part("ItachiMarker",Vector3.new(.05,3,3),COLORS.Black,CFrame.new(center+Vector3.yAxis*.05)*CFrame.Angles(0,0,math.pi/2),Enum.PartType.Cylinder,Enum.Material.SmoothPlastic)
    marker.Transparency=.5
    local scorch=part("ItachiScorch",Vector3.new(.06,1,1),Color3.fromRGB(12,8,8),CFrame.new(center+Vector3.yAxis*.04)*CFrame.Angles(0,0,math.pi/2),Enum.PartType.Cylinder,Enum.Material.SmoothPlastic)
    scorch.Transparency=1
    local glow=part("ItachiFieldGlow",Vector3.new(.08,1,1),COLORS.Blood,CFrame.new(center+Vector3.yAxis*.06)*CFrame.Angles(0,0,math.pi/2),Enum.PartType.Cylinder)
    glow.Transparency=1
    local ash=Instance.new("ParticleEmitter");ash.Color=ColorSequence.new(Color3.fromRGB(30,26,26));ash.LightEmission=0
    ash.Size=NumberSequence.new(.6,1.6);ash.Transparency=NumberSequence.new(.4,1);ash.Lifetime=NumberRange.new(1.2,2.2)
    ash.Speed=NumberRange.new(2,5);ash.SpreadAngle=Vector2.new(25,25);ash.Rate=0;ash.Parent=glow
    local sparks=Instance.new("ParticleEmitter");sparks.Color=ColorSequence.new(COLORS.Ember,COLORS.Crimson);sparks.LightEmission=1
    sparks.Size=NumberSequence.new(.14,0);sparks.Lifetime=NumberRange.new(.5,1);sparks.Speed=NumberRange.new(4,9);sparks.SpreadAngle=Vector2.new(35,35)
    sparks.Rate=0;sparks.Parent=glow
    local light=Instance.new("PointLight");light.Color=COLORS.Crimson;light.Brightness=0;light.Range=24;light.Parent=glow
    -- Black fire: tongues from the fire texture drawn dark (no light emission) with a crimson licking rim on top.
    local fireBed=part("ItachiFireBed",Vector3.new(1,.2,1),COLORS.Black,CFrame.new(center+Vector3.yAxis*.3));fireBed.Transparency=1
    local blackFire=Instance.new("ParticleEmitter");blackFire.Texture="rbxasset://textures/particles/fire_main.dds"
    blackFire.Color=ColorSequence.new(COLORS.Black,Color3.fromRGB(20,4,6));blackFire.LightEmission=0;blackFire.LightInfluence=0
    blackFire.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,1.6),NumberSequenceKeypoint.new(.5,2.4),NumberSequenceKeypoint.new(1,0)})
    blackFire.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.6),NumberSequenceKeypoint.new(.2,.05),NumberSequenceKeypoint.new(1,1)})
    blackFire.Lifetime=NumberRange.new(.5,1);blackFire.Speed=NumberRange.new(3,6);blackFire.Acceleration=Vector3.yAxis*4
    blackFire.RotSpeed=NumberRange.new(-40,40);blackFire.Rotation=NumberRange.new(-20,20);blackFire.SpreadAngle=Vector2.new(8,8)
    blackFire.EmissionDirection=Enum.NormalId.Top;blackFire.Rate=0;blackFire.Parent=fireBed
    local rimFire=blackFire:Clone();rimFire.Color=ColorSequence.new(COLORS.Crimson,COLORS.Blood);rimFire.LightEmission=.4
    rimFire.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,1.1),NumberSequenceKeypoint.new(1,0)});rimFire.Parent=fireBed
    local burn=nil
    local flames={}
    local e=run(cfg.Gone+.05,function(a)
        marker.Transparency=a<cfg.Ignite and .45+.2*math.sin(a*20) or 1
        if a>=cfg.Ignite and not flames.lit then
            flames.lit=true
            VFX.sound("Ignite",center,.9,3)
            local s;s,burn=VFX.sound("Burn",center,.5,cfg.Gone-cfg.Ignite+.2);if s then s.Looped=true end
        end
        local r=fieldRadius(a)
        local fade=a>=cfg.BurnEnd and 1-smoothstep(window(a,cfg.BurnEnd,cfg.Gone)) or 1
        for i,s in spots do
            local on=a>=cfg.Ignite and s.d<=r
            local f=flames[i]
            if on then
                if not f then f=acquireFlame();flames[i]=f;s.born=a end
                local grow=smoothstep((a-s.born)/.25)
                local flick=.75+.25*math.sin(a*9+s.ph)+.12*math.sin(a*23+s.ph*2)
                local h=s.h*grow*flick*fade
                local w=s.w*(1+.15*math.sin(a*7+s.ph))
                f.core.Size=Vector3.new(w,math.max(.05,h),w);f.core.CFrame=CFrame.new(s.pos+Vector3.yAxis*h*.5)*CFrame.Angles(0,a*1.2+s.ph,math.sin(a*5+s.ph)*.12)
                f.halo.Size=Vector3.new(w*1.35,math.max(.05,h*1.12),w*1.35);f.halo.CFrame=f.core.CFrame*CFrame.new(0,-h*.04,0)
                f.halo.Transparency=.5+.2*math.sin(a*11+s.ph)
            elseif f then releaseFlame(f);flames[i]=nil end
        end
        local k=r/cfg.Radius
        scorch.Size=Vector3.new(.06,r*2.1+.01,r*2.1+.01);scorch.Transparency=a<cfg.Ignite and 1 or .15+.6*(1-fade)
        glow.Size=Vector3.new(.08,r*2.3+.01,r*2.3+.01);glow.Transparency=a<cfg.Ignite and 1 or .82-.1*math.sin(a*6)
        light.Brightness=a<cfg.Ignite and 0 or (2+.6*math.sin(a*13))*fade
        ash.Rate=a>=cfg.Ignite and 30*k*fade*detail(center) or 0
        sparks.Rate=a>=cfg.Ignite and 40*k*fade*detail(center) or 0
        fireBed.Size=Vector3.new(r*1.7+.1,.2,r*1.7+.1)
        blackFire.Rate=a>=cfg.Ignite and (40+120*k)*fade*detail(center) or 0
        rimFire.Rate=a>=cfg.Ignite and (15+45*k)*fade*detail(center) or 0
        if burn then local s=burn:FindFirstChildOfClass("Sound");if s then s.Volume=.55*fade end end
    end,function()
        for i,f in flames do if type(i)=="number" then releaseFlame(f) end end
        marker:Destroy();scorch:Destroy();glow:Destroy();fireBed:Destroy()
        if burn then burn:Destroy() end
        fieldsByKey[key]=nil
    end,start)
    fieldsByKey[key]=e
    -- Heat haze is a short, local camera shake handled by ItachiClient during the spread.
    return e
end
function VFX.endAmaterasu(owner,start)
    local e=fieldsByKey[tostring(owner)..":"..tostring(start)]
    if e then e.dead=true end
end
-- Small black flames at the feet of anyone standing in a field (ItachiBurnUntil), on every client.
local feet={}
local function feetFire(model,on)
    local f=feet[model]
    if on and not f then
        local root=rootOf(model);if not root then return end
        local holder=part("ItachiFeetFire",Vector3.new(2.4,.2,2.4),COLORS.Black,root.CFrame*CFrame.new(0,-2.8,0));holder.Transparency=1
        local em=Instance.new("ParticleEmitter");em.Color=ColorSequence.new(COLORS.Black,COLORS.Crimson);em.LightEmission=0
        em.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.5),NumberSequenceKeypoint.new(1,0)});em.Transparency=NumberSequence.new(.1,1)
        em.Lifetime=NumberRange.new(.3,.6);em.Speed=NumberRange.new(2,4);em.SpreadAngle=Vector2.new(15,15);em.Rate=30
        em.EmissionDirection=Enum.NormalId.Top;em.Parent=holder
        feet[model]={holder=holder,root=root}
    elseif not on and f then f.holder:Destroy();feet[model]=nil end
end

---------------------------------------------------------------- R: Susanoo
-- A translucent red chakra skeleton built in stages around the caster: ribs one by one, spine, shoulders, arms, hands
-- and head; the Yata Mirror on the left hand; the Totsuka Blade from red-gold liquid in the right hand.
local function chakraPart(name,size,shape,color)
    local p=part(name,size,color or COLORS.Red,PARK,shape,Enum.Material.ForceField);p.Transparency=1
    return p
end
local function neonPart(name,size,shape,color)
    local p=part(name,size,color or COLORS.Red,PARK,shape,Enum.Material.Neon);p.Transparency=1
    return p
end
local ultras={}
function VFX.susanoo(model,data)
    local cfg=I.Susanoo;local start=data.start;local owner=data.owner
    local s={parts={},model=model,flags={},direction=data.direction}
    ultras[owner]=s
    local function add(p,stage,at,dur,offset,alpha)
        table.insert(s.parts,{p=p,stage=stage,at=at,dur=dur,offset=offset,alpha=alpha or .25});return p
    end
    local H=cfg.Height/14
    -- Six rib pairs, one pair after another: each rib is three segments curving from the spine around to the front.
    for i=0,5 do
        for _,side in {-1,1} do
            local y=(9.2-i*1.05)*H;local r=(4.2-math.abs(i-2)*.2)*H
            for seg=0,2 do
                local theta=math.rad(30+seg*45)
                local mid=Vector3.new(side*math.sin(theta)*r,y,math.cos(theta)*r*.7+.6*H)
                local tangent=Vector3.new(side*math.cos(theta),0,-math.sin(theta)*.7)
                local p=chakraPart("SusanooRib",Vector3.new(.3,.3,r*.85),Enum.PartType.Block)
                add(p,"ribs",cfg.Ribs+i*.07,.15,CFrame.lookAt(mid,mid+tangent))
            end
        end
    end
    for i=0,7 do add(chakraPart("SusanooSpine",Vector3.new(1.1,.85,1)*H,Enum.PartType.Block),"spine",cfg.Upper+i*.03,.15,CFrame.new(0,(1.6+i*1.4)*H,2.8*H)) end
    add(chakraPart("SusanooTorso",Vector3.new(12,10,8)*H,Enum.PartType.Ball),"torso",1.0,.25,CFrame.new(0,12*H,1.2*H),.55)
    add(chakraPart("SusanooHead",Vector3.new(4.2,4.6,4.2)*H,Enum.PartType.Ball),"head",1.15,.2,CFrame.new(0,19*H,.6*H))
    add(chakraPart("SusanooNose",Vector3.new(.6,.6,3)*H,Enum.PartType.Block),"head",1.17,.2,CFrame.new(0,18.8*H,-2.6*H))
    add(chakraPart("SusanooJaw",Vector3.new(3.2,1.2,2.4)*H,Enum.PartType.Block),"head",1.19,.2,CFrame.new(0,16.9*H,-.4*H))
    for _,x in {-1,1} do add(chakraPart("SusanooHorn",Vector3.new(.5,3,.5)*H,Enum.PartType.Block),"head",1.21,.2,CFrame.new(x*1.4*H,21.6*H,1*H)*CFrame.Angles(-.45,0,x*.4)) end
    s.eyes={}
    for _,x in {-1,1} do local e=neonPart("SusanooEye",Vector3.new(.7,.35,.2)*H,Enum.PartType.Block,COLORS.Gold);table.insert(s.eyes,{p=e,offset=CFrame.new(x*.9*H,19.3*H,-2*H)}) end
    -- Arms: shoulder ball, upper arm, forearm, hand with four fingers and a thumb. Posed every frame.
    local function arm(side)
        local a={side=side}
        a.shoulder=add(chakraPart("SusanooShoulder",Vector3.one*3*H,Enum.PartType.Ball),"arms",.95,.15,nil)
        a.upper=add(chakraPart("SusanooArm",Vector3.new(1.5,7,1.5)*H,Enum.PartType.Block),"arms",1.0,.15,nil)
        a.fore=add(chakraPart("SusanooArm",Vector3.new(1.3,6.5,1.3)*H,Enum.PartType.Block),"arms",1.05,.15,nil)
        a.hand=add(chakraPart("SusanooHand",Vector3.new(2.6,2.8,1.1)*H,Enum.PartType.Block),"hands",1.1,.15,nil)
        a.fingers={}
        for f=1,4 do table.insert(a.fingers,add(chakraPart("SusanooFinger",Vector3.new(.45,1.8,.45)*H,Enum.PartType.Block),"hands",1.12+f*.02,.12,nil)) end
        a.thumb=add(chakraPart("SusanooThumb",Vector3.new(.5,1.4,.5)*H,Enum.PartType.Block),"hands",1.2,.12,nil)
        return a
    end
    s.L=arm(-1);s.R=arm(1)
    -- Chakra burns: red Fire on the big parts and rising flame tongues from the torso.
    s.fires={}
    for _,e in s.parts do
        local big=e.stage=="torso" or e.stage=="head" and e.p.Name=="SusanooHead" or e.p.Name=="SusanooShoulder" or e.p.Name=="SusanooArm" or e.p.Name=="SusanooHand"
        if big then
            local f=Instance.new("Fire");f.Color=Color3.fromRGB(255,60,30);f.SecondaryColor=COLORS.Crimson
            f.Size=math.clamp(e.p.Size.Magnitude*.45,2,18);f.Heat=12;f.Enabled=false;f.Parent=e.p
            table.insert(s.fires,{f=f,e=e})
        end
    end
    s.flames=Instance.new("ParticleEmitter");s.flames.Texture="rbxasset://textures/particles/fire_main.dds"
    s.flames.Color=ColorSequence.new(Color3.fromRGB(255,120,60),COLORS.Crimson);s.flames.LightEmission=1
    s.flames.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,3*H),NumberSequenceKeypoint.new(1,0)});s.flames.Transparency=NumberSequence.new(.2,1)
    s.flames.Lifetime=NumberRange.new(.5,.9);s.flames.Speed=NumberRange.new(4,8);s.flames.Acceleration=Vector3.yAxis*6;s.flames.SpreadAngle=Vector2.new(40,40)
    s.flames.EmissionDirection=Enum.NormalId.Top;s.flames.Rate=0
    for _,e in s.parts do if e.stage=="torso" then s.flames.Parent=e.p end end
    -- Yata Mirror: a gold rim and a red flowing face, carried by the left hand.
    s.mirrorFace=chakraPart("YataMirror",Vector3.new(.3,11,11)*H,Enum.PartType.Cylinder,Color3.fromRGB(255,90,60))
    s.mirrorRim=neonPart("YataMirrorRim",Vector3.new(.25,11.8,11.8)*H,Enum.PartType.Cylinder,COLORS.Gold)
    -- Totsuka Blade: a red-gold neon core with a pointed tip, and liquid blobs that gather into it.
    s.blade=neonPart("TotsukaBlade",Vector3.new(.8,.8,1),Enum.PartType.Block,Color3.fromRGB(255,60,30))
    s.bladeGlow=chakraPart("TotsukaGlow",Vector3.new(1.6,1.6,1),Enum.PartType.Block,COLORS.Gold)
    s.tip=neonPart("TotsukaTip",Vector3.new(.6,.6,1.6),Enum.PartType.Block,COLORS.Gold)
    s.blobs={}
    for i=1,10 do table.insert(s.blobs,{p=neonPart("TotsukaLiquid",Vector3.one*.9,Enum.PartType.Ball,i%2==0 and COLORS.Gold or COLORS.Red),o=Vector3.new(math.random()-.5,math.random()-.5,math.random()-.5)*8}) end
    local trailOn=false
    local hum=nil
    local root0=rootOf(model)
    if root0 then VFX.sound("Eye",root0.Position,.8,2);local snd;snd,hum=VFX.sound("Hum",root0.Position,.5,cfg.End+.3);if snd then snd.Looped=true end end
    s.effect=run(cfg.End+.1,function(a)
        local root=rootOf(model);if not root then return end
        local flatDir=s.direction or Vector3.new(0,0,-1)
        local base=CFrame.lookAt(root.Position-Vector3.yAxis*3,root.Position-Vector3.yAxis*3+flatDir)
        local function lerp(x,y,t) return x+(y-x)*t end
        local lower=smoothstep(window(a,cfg.SealEnd,cfg.SealEnd+.55))
        local st=cfg.Strikes
        local lean=(-.12*smoothstep(window(a,cfg.Aim,cfg.Thrust))-.1*bump(a,st[1].Windup,st[1].Time+.2)-.16*bump(a,st[3].Windup+.1,st[3].Time+.25))*(1-lower)
        -- Right-arm keys for the three smashes before the blade: {time, shoulder pitch, elbow, yaw (+ = left), roll, body twist}.
        local K={{0,.25,.45,0,.15,0},{st[1].Windup,.25,.45,0,.15,0},{st[1].Windup+.17,.15,1.9,-.25,.2,-.25},{st[1].Time,1.5,.05,-.05,.12,.1},
            {st[2].Windup,1.0,.5,-.3,.3,0},{st[2].Windup+.18,1.35,.25,-1.05,.55,-.35},{st[2].Time,1.35,.2,1.0,.4,.35},
            {st[3].Windup,1.1,.6,.3,.2,0},{st[3].Windup+.2,2.9,.5,0,.1,0},{st[3].Time,.95,.05,0,.1,0},{cfg.Blade,.25,.45,0,.15,0}}
        local key={.25,.45,0,.15,0}
        if a<cfg.Blade then
            local i=1;while i<#K-1 and a>=K[i+1][1] do i+=1 end
            local k0,k1=K[i],K[i+1];local u=window(a,k0[1],k1[1])
            local hitKey=k1[1]==st[1].Time or k1[1]==st[2].Time or k1[1]==st[3].Time
            u=hitKey and 1-(1-u)^3 or smoothstep(u)
            for j=1,5 do key[j]=lerp(k0[j+1],k1[j+1],u) end
        end
        local twist=key[5]*(1-lower)
        local body=base*CFrame.Angles(0,twist,0)*CFrame.Angles(lean,0,0)
        local fadeAll=smoothstep(window(a,cfg.End-.8,cfg.End-.3));local ribsFade=smoothstep(window(a,cfg.End-.4,cfg.End-.05))
        for _,e in s.parts do
            local k=smoothstep(window(a,e.at,e.at+e.dur))*(e.stage=="ribs" and 1-ribsFade or 1-fadeAll)
            e.p.Transparency=1-(1-e.alpha)*k
            if e.offset then e.p.CFrame=body*e.offset end
            e.k=k
            if e.stage=="ribs" and k>0 and not e.played then e.played=true;if math.random()<.35 then VFX.sound("Crack",root.Position,.35,1,1.3) end end
        end
        for _,e in s.eyes do e.p.CFrame=body*e.offset;e.p.Transparency=1-smoothstep(window(a,1.2,1.35))*(1-fadeAll) end
        for _,f in s.fires do f.f.Enabled=(f.e.k or 0)>.4 and a<cfg.End-.4 end
        s.flames.Rate=a>=1.0 and a<cfg.End-.4 and 60*detail(root.Position) or 0
        if a>=.95 and not s.flags.ring then
            s.flags.ring=true
            local ring=part("SusanooRing",Vector3.new(.1,2,2),COLORS.Red,CFrame.new(root.Position-Vector3.yAxis*2.9)*CFrame.Angles(0,0,math.pi/2),Enum.PartType.Cylinder)
            run(.9,function(b) local k=b/.9;ring.Size=Vector3.new(.1,4+22*k,4+22*k);ring.Transparency=.2+.8*k end,function() ring:Destroy() end)
        end
        -- Arm angles (positive pitch swings a hanging arm forward).
        local mUp=smoothstep(window(a,cfg.Mirror,cfg.Mirror+.4))*(1-smoothstep(window(a,cfg.SealEnd+.15,cfg.SealEnd+.6)))
        local raise=smoothstep(window(a,cfg.Blade,cfg.Blade+.5));local pull=smoothstep(window(a,cfg.Aim,cfg.Thrust))
        local thrust=1-(1-window(a,cfg.Thrust,cfg.Thrust+.25))^4
        local rSh,rEl,rYaw,rRoll=key[1],key[2],key[3],key[4]
        if a>=cfg.Blade then
            rSh=lerp(lerp(lerp(.25,1,raise),.25,pull),1.55,thrust);rEl=lerp(lerp(lerp(.45,1.5,raise),1.9,pull),.05,thrust)
            rYaw=-.35*pull*(1-thrust);rRoll=.15
        end
        rSh=lerp(rSh,.25,lower);rEl=lerp(rEl,.45,lower);rYaw=lerp(rYaw,0,lower);rRoll=lerp(rRoll,.15,lower)
        local poses={[-1]={sh=.25+.95*mUp,el=.45-.1*mUp,yaw=0,roll=-.15+.3*mUp},[1]={sh=rSh,el=rEl,yaw=rYaw,roll=rRoll}}
        for _,A in {s.L,s.R} do
            local P=poses[A.side]
            local sh=body*CFrame.new(A.side*7.4*H,13.4*H,1*H)*CFrame.Angles(0,P.yaw,0)*CFrame.Angles(P.sh,0,P.roll*A.side)
            A.shoulder.CFrame=sh
            A.upper.CFrame=sh*CFrame.new(0,-3.5*H,0)
            local el=sh*CFrame.new(0,-7*H,0)*CFrame.Angles(P.el,0,0)
            A.fore.CFrame=el*CFrame.new(0,-3.25*H,0)
            local hand=el*CFrame.new(0,-6.9*H,0)
            A.hand.CFrame=hand
            for f,fp in A.fingers do fp.CFrame=hand*CFrame.new((-1.5+f)*.6*H*A.side,-2*H,-.1)*CFrame.Angles(.35,0,0) end
            A.thumb.CFrame=hand*CFrame.new(A.side*1.5*H,-.6*H,-.4*H)*CFrame.Angles(0,0,A.side*.8)
            A.handFrame=hand
        end
        -- Mirror on the left hand, its face turned forward; ripples when hit.
        local mk=smoothstep(window(a,cfg.Mirror+.1,cfg.Mirror+.5))*(1-smoothstep(window(a,cfg.SealEnd+.15,cfg.SealEnd+.45)))
        -- Thinner while the right arm smashes through the space in front of it.
        mk*=1-.7*smoothstep(window(a,cfg.Smash-.1,cfg.Smash+.1))*(1-smoothstep(window(a,cfg.Blade-.1,cfg.Blade+.2)))
        -- The cylinder's axis (X) is turned along the forearm, so the face looks where the arm points.
        local mf=s.L.handFrame*CFrame.new(0,-3.2*H,-1.4*H)*CFrame.Angles(0,0,math.pi/2)*CFrame.Angles(a*.6,0,0)
        s.mirrorFace.CFrame=mf;s.mirrorRim.CFrame=mf*CFrame.new(.05,0,0)
        s.mirrorFace.Transparency=1-.6*mk;s.mirrorRim.Transparency=1-.85*mk
        if a>=cfg.Mirror+.2 and not s.flags.mirror then s.flags.mirror=true;VFX.sound("Mirror",root.Position,.8,2) end
        if a>=cfg.MirrorBreak and not s.flags.mirrorBreak then
            s.flags.mirrorBreak=true
            for _=1,math.floor(30*detail(mf.Position)) do
                local o=Vector3.new(math.random()-.5,math.random()-.5,math.random()-.5)*10*H
                local m=part("MirrorShard",Vector3.one*(.3+math.random()*.4),COLORS.Red,CFrame.new(mf.Position+o),Enum.PartType.Ball)
                local v=o.Unit*(2+math.random()*4)+Vector3.yAxis*2
                run(.9,function(b,dt) m.CFrame+=v*dt;m.Transparency=b/.9 end,function() m:Destroy() end)
            end
        end
        -- Blade: liquid gathers in the right hand, forms, then extends on the thrust to the target (or the reach).
        local hand=s.R.handFrame*CFrame.new(0,-2.2*H,0)
        local gather=window(a,cfg.Blade,cfg.Blade+.4);local form=smoothstep(window(a,cfg.Blade+.3,cfg.Aim))
        for _,b in s.blobs do
            local on=gather>0 and form<1
            b.p.Transparency=on and .1+.8*form or 1
            b.p.CFrame=CFrame.new(hand.Position+b.o*(1-smoothstep(gather)))
            b.p.Size=Vector3.one*(.5+.8*(1-form))*2*H
        end
        if a>=cfg.Blade and not s.flags.liquid then s.flags.liquid=true;VFX.sound("Seal",hand.Position,.5,2,1.5) end
        local aimPoint=hand.Position+flatDir*20+Vector3.yAxis*(4*(1-pull))
        local tr=rootOf(s.target)
        if tr and a>=cfg.Thrust then aimPoint=tr.Position+Vector3.yAxis*1
        elseif a>=cfg.Thrust then aimPoint=root.Position+flatDir*cfg.Reach end
        local full=(aimPoint-hand.Position).Magnitude
        local len=12*H*form
        if a>=cfg.Thrust then len=lerp(12*H,full,1-(1-window(a,cfg.Thrust,cfg.Tip))^3) end
        if not tr and a>=cfg.Tip then len=lerp(full,12*H,smoothstep(window(a,cfg.Tip+.1,cfg.StrikeEnd+.2))) end
        if tr and a>=cfg.Seal then len=lerp(full,9*H,smoothstep(window(a,cfg.SealEnd,cfg.SealEnd+.35))) end
        local bk=form*(1-smoothstep(window(a,cfg.SealEnd,cfg.SealEnd+.35)))
        local dir=CFrame.lookAt(hand.Position,aimPoint)
        s.blade.Size=Vector3.new(.7+.15*math.sin(a*11),.7+.15*math.sin(a*11),math.max(.05,len));s.blade.CFrame=dir*CFrame.new(0,0,-len/2)
        s.bladeGlow.Size=Vector3.new(1.7,1.7,math.max(.05,len));s.bladeGlow.CFrame=s.blade.CFrame
        s.tip.CFrame=dir*CFrame.new(0,0,-len-.8)*CFrame.Angles(0,0,math.pi/4)
        s.blade.Transparency=1-bk;s.bladeGlow.Transparency=1-.6*bk;s.tip.Transparency=1-bk
        if a>=cfg.Thrust and a<cfg.Tip+.1 then
            trailOn=true
            local p=hand.Position:Lerp(aimPoint,math.random())
            local sp=part("TotsukaTrail",Vector3.one*(.4+math.random()*.5),math.random()<.3 and COLORS.Gold or COLORS.Red,CFrame.new(p),Enum.PartType.Ball)
            run(.3,function(b) sp.Transparency=b/.3 end,function() sp:Destroy() end)
        elseif trailOn then trailOn=false end
        -- The sealed body is drawn into the blade: red-gold vortex rings around it.
        if tr and a>=cfg.StrikeEnd and a<cfg.SealEnd+.2 then
            if math.random()<.5 then
                local ring=part("SealVortex",Vector3.new(.1,4,4),math.random()<.5 and COLORS.Gold or COLORS.Red,CFrame.new(tr.Position),Enum.PartType.Cylinder)
                local spin=math.random()*6
                run(.5,function(b) local k=b/.5;ring.CFrame=CFrame.new(tr.Position)*CFrame.Angles(spin+b*10,b*6,math.pi/2);ring.Size=Vector3.new(.1,5*(1-k)+.3,5*(1-k)+.3);ring.Transparency=k end,function() ring:Destroy() end)
            end
        end
        VFX.eyeGlow(model,1-fadeAll)
        if hum then local snd=hum:FindFirstChildOfClass("Sound");if snd then snd.Volume=.5*(1-fadeAll) end end
    end,function()
        for _,e in s.parts do e.p:Destroy() end
        for _,e in s.eyes do e.p:Destroy() end
        s.mirrorFace:Destroy();s.mirrorRim:Destroy();s.blade:Destroy();s.bladeGlow:Destroy();s.tip:Destroy()
        for _,b in s.blobs do b.p:Destroy() end
        if hum then hum:Destroy() end
        VFX.eyeGlow(model,0)
        if ultras[owner]==s then ultras[owner]=nil end
    end,start)
    return s
end
-- One smash landing: a burst of red flame and gold light at the fist (the hammer splits the ground with a ring),
-- and a flash on everyone it hit.
function VFX.susanooSmash(owner,index,point,targets)
    local s=ultras[owner]
    local at=point
    if s and s.R.handFrame and index~=3 then at=s.R.handFrame.Position end
    if index==3 then
        local ring=part("SusanooQuake",Vector3.new(.1,4,4),COLORS.Red,CFrame.new(point-Vector3.yAxis*2.8)*CFrame.Angles(0,0,math.pi/2),Enum.PartType.Cylinder)
        run(.6,function(b) local k=b/.6;ring.Size=Vector3.new(.1,4+30*k,4+30*k);ring.Transparency=.15+.85*k end,function() ring:Destroy() end)
    end
    local burst=part("SusanooSmash",Vector3.one*3,COLORS.Gold,CFrame.new(at),Enum.PartType.Ball)
    local fire=part("SusanooSmashFire",Vector3.one*4,COLORS.Red,CFrame.new(at),Enum.PartType.Ball)
    local big=index==3 and 1.5 or 1
    run(.4,function(b) local k=b/.4;burst.Size=Vector3.one*(3+9*k)*big;burst.Transparency=.1+.9*k;fire.Size=Vector3.one*(4+14*k)*big;fire.Transparency=.3+.7*k end,function() burst:Destroy();fire:Destroy() end)
    for _,m in targets or {} do
        local r=rootOf(m)
        if r then
            local f=part("SusanooSmashHit",Vector3.one*2,Color3.fromRGB(255,200,140),CFrame.new(r.Position),Enum.PartType.Ball)
            run(.3,function(b) local k=b/.3;f.Size=Vector3.one*(2+5*k);f.Transparency=k;f.Color=COLORS.Gold:Lerp(COLORS.Red,k) end,function() f:Destroy() end)
        end
    end
    VFX.sound("Impact",at,1,2,index==3 and .8 or 1)
end
function VFX.susanooThrust(owner,target)
    local s=ultras[owner];if not s then return end
    s.target=target
    local root=rootOf(s.model);if root then VFX.sound("Thrust",root.Position,.9,2) end
end
function VFX.susanooHit(owner,point)
    VFX.sound("Impact",point,1,2)
    local flash=part("TotsukaFlash",Vector3.one*2,Color3.fromRGB(255,240,200),CFrame.new(point),Enum.PartType.Ball)
    run(.35,function(a) local k=a/.35;flash.Size=Vector3.one*(2+8*k);flash.Transparency=k;flash.Color=COLORS.Gold:Lerp(COLORS.Red,k) end,function() flash:Destroy() end)
end
function VFX.susanooMiss(owner)
    local s=ultras[owner];if not s then return end
    s.target=nil
end
function VFX.susanooEnd(owner,early)
    local s=ultras[owner];if not s then return end
    if early then s.effect.dead=true end
end
function VFX.mirrorHit(owner)
    local s=ultras[owner];if not s then return end
    local cf=s.mirrorFace.CFrame
    local ring=part("MirrorRipple",Vector3.new(.1,4,4),COLORS.Red,cf,Enum.PartType.Cylinder)
    run(.45,function(a) local k=a/.45;ring.CFrame=cf*CFrame.new(-.3,0,0);ring.Size=Vector3.new(.1,4+10*k,4+10*k);ring.Transparency=.1+.9*k end,function() ring:Destroy() end)
    VFX.sound("Mirror",cf.Position,.8,2,1.4)
end

---------------------------------------------------------------- per-frame state shared by every kit
-- Bodies in a seal are hidden; Tsukuyomi victims bow their heads; feet burn inside Amaterasu.
local sealedShown={}
local neckBow={}
RunService.RenderStepped:Connect(function(dt)
    local n=clock()
    for i=#active,1,-1 do
        local e=active[i];local age=n-e.start
        if age>e.duration or e.dead then
            table.remove(active,i)
            if e.cleanup then local ok,err=pcall(e.cleanup);if not ok then warn("ItachiVFX cleanup",err) end end
        elseif age>=0 then
            local ok,err=pcall(e.update,age,dt);if not ok then warn("ItachiVFX",err);e.dead=true end
        end
    end
    for _,model in workspace:GetChildren() do
        if model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") then
            local hide=(model:GetAttribute("ItachiSealedUntil") or 0)>n
            if hide~=(sealedShown[model]==true) then
                sealedShown[model]=hide or nil
                for _,v in model:GetDescendants() do if (v:IsA("BasePart") and v.Name~="HumanoidRootPart") or v:IsA("Decal") then v.LocalTransparencyModifier=hide and 1 or 0 end end
            end
            feetFire(model,(model:GetAttribute("ItachiBurnUntil") or 0)>n)
            local bow=(model:GetAttribute("ItachiTsukuyomiUntil") or 0)>n
            local neck=model:FindFirstChild("Neck",true)
            if neck and neck:IsA("Motor6D") then
                local k=neckBow[model] or 0
                k+=((bow and 1 or 0)-k)*math.min(1,dt*10);neckBow[model]=k>.001 and k or nil
                if k>.001 then neck.Transform=CFrame.Angles(-.45*k,0,0) end
            end
        end
    end
    for model,f in feet do
        if not model.Parent then f.holder:Destroy();feet[model]=nil else f.holder.CFrame=f.root.CFrame*CFrame.new(0,-2.8,0) end
    end
    for model in sealedShown do if not model.Parent then sealedShown[model]=nil end end
end)
return VFX
