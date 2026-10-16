-- Tendo Pain world effects, run on every client from the server's PainFX events.
-- Nothing here touches gameplay: positions come from the server, and every part is non-collidable, pooled where
-- it is spawned in numbers (rocks, dust) and cleaned up by its own timer.
local RunService=game:GetService("RunService")
local Debris=game:GetService("Debris")
local Lighting=game:GetService("Lighting")
local RS=game:GetService("ReplicatedStorage")
local P=require(RS:WaitForChild("PainAbilityConfig"))
local COLORS=P.Colors

local VFX={}
-- Built-in placeholders. Replace with uploaded ids (low resonance, gravity drone, rock clack, final blast).
VFX.Sounds={
    Hum={id="rbxasset://sounds/action_falling.mp3",speed=.32},
    Boom={id="rbxasset://sounds/impact_generic.mp3",speed=.42},
    Thud={id="rbxasset://sounds/impact_generic.mp3",speed=.3},
    Stab={id="rbxasset://sounds/swordlunge.wav",speed=1.35},
    Clack={id="rbxasset://sounds/impact_generic.mp3",speed=1.7},
    Drone={id="rbxasset://sounds/action_falling.mp3",speed=.22},
    Whoosh={id="rbxasset://sounds/swordslash.wav",speed=.55},
}
local folder=Instance.new("Folder");folder.Name="PainFX";folder.Parent=workspace
local active={}
local function clock() return workspace:GetServerTimeNow() end
local function smoothstep(x) x=math.clamp(x,0,1);return x*x*(3-2*x) end
VFX.smoothstep=smoothstep
-- One update list for every effect; each one has a hard lifetime so nothing outlives its skill.
local function run(duration,update,cleanup,start)
    local e={start=start or clock(),duration=duration,update=update,cleanup=cleanup}
    table.insert(active,e);return e
end
VFX.run=run
RunService.RenderStepped:Connect(function(dt)
    local n=clock()
    for i=#active,1,-1 do
        local e=active[i];local age=n-e.start
        if age>e.duration or e.dead then
            table.remove(active,i)
            if e.cleanup then local ok,err=pcall(e.cleanup);if not ok then warn("PainVFX cleanup",err) end end
        elseif age>=0 then
            local ok,err=pcall(e.update,age,dt);if not ok then warn("PainVFX",err);e.dead=true end
        end
    end
end)
local function part(name,size,color,cf,shape,material)
    local p=Instance.new("Part");p.Name=name;p.Size=size;p.Color=color;p.CFrame=cf or CFrame.identity
    p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
    p.Material=material or Enum.Material.Neon;p.Shape=shape or Enum.PartType.Block;p.Parent=folder
    return p
end
VFX.part=part
function VFX.sound(name,position,volume,duration,speedScale)
    local cue=VFX.Sounds[name];if not cue then return end
    local holder=part("PainSound",Vector3.one*.1,Color3.new(),CFrame.new(position));holder.Transparency=1
    local s=Instance.new("Sound");s.SoundId=cue.id;s.Volume=volume or .6;s.PlaybackSpeed=cue.speed*(speedScale or 1)
    s.RollOffMinDistance=12;s.RollOffMaxDistance=220;s.Parent=holder;s:Play()
    Debris:AddItem(holder,duration or 3)
    return s
end

---------------------------------------------------------------- pools
-- Rocks and dust puffs are reused: a released part is parked out of sight instead of destroyed.
local pools={Rock={},Dust={}}
local PARK=CFrame.new(0,-5000,0)
local function acquire(kind)
    local list=pools[kind]
    local p=table.remove(list)
    if not p then
        if kind=="Rock" then p=part("PainRock",Vector3.one,COLORS.Rock,PARK,Enum.PartType.Block,Enum.Material.Slate)
        else p=part("PainDust",Vector3.one,COLORS.Dust,PARK,Enum.PartType.Ball,Enum.Material.SmoothPlastic) end
    end
    p.Transparency=0;return p
end
local function release(kind,p)
    if not p or not p.Parent then return end
    p.Transparency=1;p.CFrame=PARK
    if #pools[kind]<220 then table.insert(pools[kind],p) else p:Destroy() end
end
local function rock(size,cf,shade)
    local p=acquire("Rock");p.Size=size;p.CFrame=cf
    local k=shade or math.random()
    p.Color=COLORS.Rock:Lerp(Color3.fromRGB(70,64,60),k*.7)
    p.Shape=math.random()<.35 and Enum.PartType.Ball or Enum.PartType.Block
    return p
end
-- A soft dust puff that drifts, grows and fades.
function VFX.dust(position,size,velocity,life,color)
    local p=acquire("Dust");p.Size=Vector3.one*size*.5;p.CFrame=CFrame.new(position);p.Color=color or COLORS.Dust;p.Transparency=.45
    local grow=size*(1.4+math.random()*.6)
    run(life,function(age)
        local u=age/life
        p.CFrame=CFrame.new(position+velocity*life*(1-(1-u)^2))
        p.Size=Vector3.one*(size*.5+(grow-size*.5)*smoothstep(u))
        p.Transparency=.45+.55*u
    end,function() release("Dust",p) end)
end
-- Thin neon ring built from segments, posed by `update(u)` -> (center, radius, transparency, axisCFrame).
local function ring(segments,thickness,color)
    local list={}
    for i=1,segments do list[i]=part("PainRing",Vector3.one*thickness,color) end
    local function pose(frame,radius,transparency)
        for i,p in list do
            local a=(i-1)*math.pi*2/#list;local b=i*math.pi*2/#list
            local from=(frame*CFrame.new(math.cos(a)*radius,0,math.sin(a)*radius)).Position
            local to=(frame*CFrame.new(math.cos(b)*radius,0,math.sin(b)*radius)).Position
            p.Size=Vector3.new(thickness,thickness,(to-from).Magnitude+thickness)
            p.CFrame=CFrame.lookAt((from+to)/2,to);p.Transparency=transparency
        end
    end
    local function destroy() for _,p in list do p:Destroy() end end
    return pose,destroy
end
VFX.ring=ring
-- Flying debris: ballistic arc with spin, fading out before it is returned to the pool.
local function throwRock(position,velocity,size,life,gravity)
    local p=rock(Vector3.new(size,size*(.6+math.random()*.5),size*(.7+math.random()*.4)),CFrame.new(position))
    local spin=CFrame.Angles(math.random()*6,math.random()*6,math.random()*6)
    local axis=Vector3.new(math.random()-.5,math.random()-.5,math.random()-.5).Unit
    local g=gravity or 90;local floor=position.Y-size
    run(life,function(age)
        local at=position+velocity*age-Vector3.yAxis*.5*g*age*age
        if at.Y<floor then at=Vector3.new(at.X,floor,at.Z) end
        p.CFrame=CFrame.new(at)*CFrame.fromAxisAngle(axis,age*8)*spin
        p.Transparency=smoothstep((age-life*.6)/(life*.4))
    end,function() release("Rock",p) end)
end
VFX.throwRock=throwRock
local function groundAt(position)
    local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={folder,workspace.CurrentCamera};params.RespectCanCollide=true
    local hit=workspace:Raycast(position+Vector3.yAxis*3,Vector3.yAxis*-60,params)
    return hit and hit.Position or position-Vector3.yAxis*3
end
VFX.groundAt=groundAt
local function scorch(position,radius,life,color)
    local p=part("PainScorch",Vector3.new(.06,radius*2,radius*2),color or Color3.fromRGB(38,34,32),CFrame.new(position+Vector3.yAxis*.04)*CFrame.Angles(0,0,math.pi/2),Enum.PartType.Cylinder,Enum.Material.Slate)
    p.Transparency=.25
    run(life,function(age) p.Transparency=.25+.75*smoothstep((age-life*.7)/(life*.3)) end,function() p:Destroy() end)
    return p
end

---------------------------------------------------------------- Q: Shinra Tensei
-- A refracting, nearly clear sphere (Glass + ForceField shells) that sweeps outward, a white rim on the floor,
-- grey dust riding the front and stones thrown off the ground.
function VFX.shinraWave(center,radius,duration)
    local floor=groundAt(center)
    local glass=part("ShinraRefraction",Vector3.one,Color3.fromRGB(226,232,255),CFrame.new(center),Enum.PartType.Ball,Enum.Material.Glass)
    glass.Transparency=.86;glass.Reflectance=.08
    local shimmer=part("ShinraShimmer",Vector3.one,Color3.fromRGB(205,190,255),CFrame.new(center),Enum.PartType.Ball,Enum.Material.ForceField)
    shimmer.Transparency=.35
    local poseFloor,destroyFloor=ring(48,.35,Color3.fromRGB(250,250,255))
    local poseBand,destroyBand=ring(40,.18,Color3.fromRGB(230,226,255))
    local life=duration+.45
    run(life,function(age)
        local u=smoothstep(age/duration)
        local r=math.max(.5,radius*(1-(1-math.clamp(age/duration,0,1))^2.4))
        local fade=smoothstep((age-duration)/(life-duration))
        glass.Size=Vector3.one*r*2;shimmer.Size=Vector3.one*r*1.96
        glass.Transparency=.86+.14*fade;shimmer.Transparency=.35+.65*math.max(fade,u*.5)
        poseFloor(CFrame.new(floor+Vector3.yAxis*.2),r,.15+.85*fade)
        poseBand(CFrame.new(center),r*.98,.55+.45*fade)
    end,function() glass:Destroy();shimmer:Destroy();destroyFloor();destroyBand() end)
    -- Dust rides the front: puffs spawn on the ring and are carried out past it.
    for i=1,28 do
        local a=i/28*math.pi*2+math.random()*.2
        local direction=Vector3.new(math.cos(a),0,math.sin(a))
        task.delay(math.random()*.06,function()
            VFX.dust(floor+direction*2+Vector3.yAxis*.8,2.4,direction*(radius*1.6)+Vector3.yAxis*2,.9+math.random()*.5)
        end)
    end
    -- Loose stones and grit are blasted off the floor around Pain.
    for _=1,20 do
        local a=math.random()*math.pi*2;local d=1.5+math.random()*6
        local direction=Vector3.new(math.cos(a),0,math.sin(a))
        throwRock(floor+direction*d+Vector3.yAxis*.4,direction*(45+math.random()*45)+Vector3.yAxis*(8+math.random()*18),.25+math.random()*.7,1.3)
    end
    scorch(floor,4.5,2.5,Color3.fromRGB(70,66,72))
    VFX.sound("Boom",center,1,3)
    VFX.sound("Whoosh",center,.6,2)
end
function VFX.wallHit(position,normal)
    local n=typeof(normal)=="Vector3" and normal or Vector3.yAxis
    for _=1,10 do
        local spread=(n+Vector3.new(math.random()-.5,math.random()*.8,math.random()-.5)).Unit
        throwRock(position,spread*(18+math.random()*20),.3+math.random()*.45,.9)
    end
    for _=1,4 do VFX.dust(position,2.2,(n+Vector3.new(math.random()-.5,.4,math.random()-.5))*6,.8) end
    local crack=part("PainWallCrack",Vector3.new(.08,4,4),Color3.fromRGB(30,28,30),CFrame.lookAt(position-n*.05,position-n*2)*CFrame.Angles(0,math.pi/2,0),Enum.PartType.Cylinder,Enum.Material.Slate)
    crack.Transparency=.3
    run(2.2,function(age) crack.Transparency=.3+.7*smoothstep((age-1.5)/.7) end,function() crack:Destroy() end)
    VFX.sound("Thud",position,.9,2)
end
-- Dust trail behind a thrown body.
function VFX.knockTrail(model,duration)
    local root=model:FindFirstChild("HumanoidRootPart");if not root then return end
    local nextPuff=0
    run(duration,function(age)
        if age>=nextPuff and root.Parent then
            nextPuff=age+.05
            VFX.dust(root.Position-Vector3.yAxis*1.5,1.3,Vector3.new(math.random()-.5,.6,math.random()-.5)*2,.55)
        end
    end)
end

---------------------------------------------------------------- E: Bansho Ten'in
-- Faint Rinnegan rings that lock onto the chosen target for a moment.
function VFX.aimRings(model,duration)
    local root=model:FindFirstChild("HumanoidRootPart");if not root then return end
    local rings={}
    for i=1,3 do local pose,destroy=ring(28,.08,COLORS.Rinnegan);rings[i]={pose=pose,destroy=destroy} end
    run(duration,function(age)
        local u=age/duration
        local cam=workspace.CurrentCamera
        local facing=CFrame.lookAt(root.Position,cam.CFrame.Position)*CFrame.Angles(math.pi/2,0,0)
        for i,r in rings do
            local radius=(1+i*.7)*(1.25-.25*smoothstep(age/.2))
            r.pose(facing*CFrame.Angles(0,age*(i%2==0 and -2 or 2),0),radius,.25+.75*smoothstep((u-.6)/.4))
        end
    end,function() for _,r in rings do r.destroy() end end)
end
-- While a body is dragged: a refracting bubble around it, purple streaks flowing off its back and air
-- rings collapsing onto it; grit at Pain's feet is drawn forward.
function VFX.pullField(model,casterModel,duration)
    local root=model:FindFirstChild("HumanoidRootPart");if not root then return end
    local casterRoot=casterModel and casterModel:FindFirstChild("HumanoidRootPart")
    local bubble=part("BanshoRefraction",Vector3.one*6,Color3.fromRGB(220,214,255),root.CFrame,Enum.PartType.Ball,Enum.Material.Glass)
    bubble.Transparency=.9
    local shimmer=part("BanshoShimmer",Vector3.one*6,COLORS.Rinnegan,root.CFrame,Enum.PartType.Ball,Enum.Material.ForceField)
    shimmer.Transparency=.55
    local poseRing,destroyRing=ring(24,.07,COLORS.Rinnegan)
    local nextStreak,nextGrit=0,0
    run(duration,function(age)
        if not root.Parent then return end
        local pulse=1+math.sin(age*30)*.06
        bubble.CFrame=root.CFrame;shimmer.CFrame=root.CFrame
        bubble.Size=Vector3.one*6*pulse;shimmer.Size=Vector3.one*5.6*pulse
        local toward=casterRoot and (casterRoot.Position-root.Position) or root.CFrame.LookVector
        toward=toward.Magnitude>.1 and toward.Unit or Vector3.zAxis
        -- A collapsing ring every 0.15 s.
        local k=(age%.15)/.15
        poseRing(CFrame.lookAt(root.Position,root.Position+toward)*CFrame.Angles(math.pi/2,0,0),5*(1-k)+.4,.2+.8*k)
        if age>=nextStreak then
            nextStreak=age+.025
            local side=Vector3.new(math.random()-.5,math.random()-.5,math.random()-.5)*2.4
            local from=root.Position+side
            local streak=part("BanshoStreak",Vector3.new(.08,.08,1.4),COLORS.Rinnegan,CFrame.lookAt(from,from-toward))
            streak.Transparency=.2
            run(.28,function(a)
                local u=a/.28
                streak.CFrame=CFrame.lookAt(from-toward*u*6,from-toward*(u*6+1))
                streak.Transparency=.2+.8*u
            end,function() streak:Destroy() end)
        end
        if casterRoot and casterRoot.Parent and age>=nextGrit and age<.6 then
            nextGrit=age+.04
            local forward=(root.Position-casterRoot.Position)*Vector3.new(1,0,1)
            forward=forward.Magnitude>.1 and forward.Unit or casterRoot.CFrame.LookVector
            local from=casterRoot.Position-Vector3.yAxis*2.6+Vector3.new(math.random()-.5,0,math.random()-.5)*5
            local p=rock(Vector3.one*(.18+math.random()*.2),CFrame.new(from))
            run(.4,function(a)
                local u=a/.4
                p.CFrame=CFrame.new(from+forward*u*u*7+Vector3.yAxis*math.sin(u*math.pi)*1.2)*CFrame.Angles(a*9,a*7,0)
                p.Transparency=smoothstep((u-.6)/.4)
            end,function() release("Rock",p) end)
        end
    end,function() bubble:Destroy();shimmer:Destroy();destroyRing() end)
end
function VFX.stabImpact(position,direction)
    local d=typeof(direction)=="Vector3" and direction.Magnitude>.1 and direction.Unit or Vector3.zAxis
    local flash=part("BanshoImpact",Vector3.one*.6,Color3.new(1,1,1),CFrame.new(position),Enum.PartType.Ball)
    run(.18,function(age) local u=age/.18;flash.Size=Vector3.one*(.6+3.4*u);flash.Transparency=u end,function() flash:Destroy() end)
    local poseRing,destroyRing=ring(20,.1,Color3.fromRGB(235,235,245))
    run(.25,function(age) poseRing(CFrame.lookAt(position,position+d)*CFrame.Angles(math.pi/2,0,0),.5+5*age/.25,age/.25) end,destroyRing)
    for _=1,8 do
        local spread=(d+Vector3.new(math.random()-.5,math.random()-.5,math.random()-.5)*.9).Unit
        local spark=part("BanshoSpark",Vector3.new(.06,.06,.7),Color3.fromRGB(30,24,40),CFrame.lookAt(position,position+spread))
        run(.22,function(age) spark.CFrame=CFrame.lookAt(position+spread*age*30,position+spread*(age*30+1));spark.Transparency=age/.22 end,function() spark:Destroy() end)
    end
    VFX.sound("Stab",position,.9,1.5)
    VFX.sound("Thud",position,.5,1.5,1.6)
end

---------------------------------------------------------------- R: Chibaku Tensei
-- Driven entirely by the server start time and seed, so every client builds the same rocks on the same beat.
local function fib(i,count)
    local y=1-(i-.5)/count*2;local r=math.sqrt(math.max(0,1-y*y));local a=i*2.39996
    return Vector3.new(math.cos(a)*r,y,math.sin(a)*r)
end
local function makeCore(radius)
    local m=Instance.new("Model");m.Name="ChibakuCore";m.Parent=folder
    local core=part("Core",Vector3.one*radius*2,Color3.fromRGB(4,3,8),nil,Enum.PartType.Ball,Enum.Material.SmoothPlastic);core.Parent=m
    local halo=part("Halo",Vector3.one*radius*2.5,COLORS.RinneganDeep,nil,Enum.PartType.Ball,Enum.Material.ForceField);halo.Transparency=.3;halo.Parent=m
    local light=Instance.new("PointLight");light.Color=COLORS.Rinnegan;light.Brightness=4;light.Range=radius*14;light.Parent=core
    local rings={}
    for i=1,3 do local pose,destroy=ring(36,.09*radius,COLORS.Rinnegan);rings[i]={pose=pose,destroy=destroy} end
    local handle={model=m,core=core,halo=halo,light=light}
    function handle.pose(cf,scale,age,fade)
        core.CFrame=cf;halo.CFrame=cf
        core.Size=Vector3.one*radius*2*scale;halo.Size=Vector3.one*radius*2.6*scale*(1+math.sin(age*6)*.05)
        halo.Transparency=.3+.7*fade;core.Transparency=fade
        for i,r in rings do
            local tilt=CFrame.Angles(i*1.1,age*(1.4+i*.5),i*.7)
            r.pose(cf*tilt,radius*scale*(1.5+i*.35),.15+i*.15+(1-(.15+i*.15))*fade)
        end
    end
    function handle.destroy() for _,r in rings do r.destroy() end;m:Destroy() end
    return handle
end
VFX.makeCore=makeCore
function VFX.chibaku(data,options)
    local cfg=P.ChibakuTensei
    local start=data.start
    local random=Random.new(data.seed)
    local center,core=data.center,data.core
    local R=data.sphere or cfg.SphereRadius
    local handle={stopped=false}
    local holdOrigin=options and options.originFn
    -- Core: born at the caster's hands, rises to the sky point, hangs there until the burst.
    local coreFx=makeCore(1.6)
    local fieldPose,fieldDestroy=ring(72,.35,COLORS.Rinnegan)
    local innerPose,innerDestroy=ring(56,.2,COLORS.RinneganDeep)
    -- Packed interior that grows as the rocks arrive, so the core disappears behind real mass.
    local packed=part("ChibakuPacked",Vector3.one,Color3.fromRGB(86,79,72),CFrame.new(core),Enum.PartType.Ball,Enum.Material.Slate)
    packed.Transparency=1
    -- Rocks: each leaves its own spot on the ground, spirals up and locks onto the growing sphere.
    local rocks={}
    for i=1,data.rocks or cfg.Rocks do
        local layer=i/(data.rocks or cfg.Rocks)
        local size=1+random:NextNumber()^1.6*3.2+layer*2.4
        local a=random:NextNumber()*math.pi*2;local d=8+random:NextNumber()*(math.min(cfg.Radius,38)-8)
        local from=groundAt(center+Vector3.new(math.cos(a)*d,0,math.sin(a)*d))+Vector3.yAxis*(size*.3-.4)
        local dir=fib(((i*37)%(data.rocks or cfg.Rocks))+1,data.rocks or cfg.Rocks)
        local launch=cfg.DebrisStart+layer*1.25+random:NextNumber()*.25
        local flight=.55+1.25*(size-1)/6.6
        rocks[i]={size=Vector3.new(size,size*(.55+random:NextNumber()*.4),size*(.7+random:NextNumber()*.4)),from=from,dir=dir,
            radius=R*(.5+.5*layer)-size*.25,launch=launch,arrive=math.min(cfg.Formed+.05,launch+flight),
            swirl=(random:NextNumber()<.5 and -1 or 1)*(1+random:NextNumber()*1.2),
            spin=CFrame.Angles(random:NextNumber()*6,random:NextNumber()*6,random:NextNumber()*6),shade=random:NextNumber(),
            angle=a,distance=d,burst=dir*(45+random:NextNumber()*55)+Vector3.yAxis*random:NextNumber()*25}
    end
    -- Cracks of leaking purple light on the finished sphere.
    local cracks={}
    for i=1,14 do
        local dir=fib(i*5%14+1,14)
        local tangent=dir:Cross(Vector3.new(random:NextNumber()-.5,random:NextNumber()-.5,random:NextNumber()-.5)).Unit
        cracks[i]={dir=dir,tangent=tangent,length=3+random:NextNumber()*5,part=part("ChibakuCrack",Vector3.new(.25,.25,.1),COLORS.Rinnegan,CFrame.new(core))}
        cracks[i].part.Transparency=1
    end
    local nextDust,nextPebble,clacks,clackWindow=0,0,0,0
    local drone=nil
    local pebbles={}
    local cleaned=false
    local function cleanup()
        if cleaned then return end
        cleaned=true
        coreFx.destroy();fieldDestroy();innerDestroy();packed:Destroy()
        for _,c in cracks do c.part:Destroy() end
        for _,r in rocks do if r.part then release("Rock",r.part);r.part=nil end end
        for _,p in pebbles do release("Rock",p.part) end
        if drone then drone:Stop();drone.Parent:Destroy() end
    end
    handle.effect=run(cfg.Duration+.2,function(age,dt)
        local n=age
        -- Core path.
        local corePos
        if n<cfg.Gather then
            corePos=holdOrigin and holdOrigin() or data.origin+Vector3.yAxis*1.5
            -- The caster sees it between the palms in the viewmodel, so it starts tiny there.
            coreFx.pose(CFrame.new(corePos),holdOrigin and .02+.03*smoothstep(n/cfg.Gather) or .2+.25*smoothstep(n/cfg.Gather),n,0)
        elseif n<cfg.Launch then
            local u=(n-cfg.Gather)/(cfg.Launch-cfg.Gather)
            local from=holdOrigin and holdOrigin() or data.origin+Vector3.yAxis*1.5
            corePos=from:Lerp(core,1-(1-u)^2)
            coreFx.pose(CFrame.new(corePos),holdOrigin and .05+.95*u*u or .45+.55*u,n,0)
        elseif n<cfg.Burst then
            corePos=core
            coreFx.pose(CFrame.new(core),1+.08*math.sin(n*8),n,0)
        else
            corePos=core;coreFx.pose(CFrame.new(core),1,n,1)
        end
        -- Pebbles lift around Pain while the hands gather.
        if n<cfg.Launch and n>=nextPebble then
            nextPebble=n+.06
            local a=math.random()*math.pi*2;local d=2+math.random()*5
            local from=groundAt(data.origin+Vector3.new(math.cos(a)*d,0,math.sin(a)*d))
            local p=rock(Vector3.one*(.2+math.random()*.35),CFrame.new(from))
            table.insert(pebbles,{part=p,from=from,born=n})
        end
        for i=#pebbles,1,-1 do
            local pb=pebbles[i];local a=n-pb.born
            if a>1.6 then release("Rock",pb.part);table.remove(pebbles,i)
            else pb.part.CFrame=CFrame.new(pb.from+Vector3.yAxis*(a*a*1.6+a*.8))*CFrame.Angles(a*3,a*2,0);pb.part.Transparency=smoothstep((a-1.1)/.5) end
        end
        -- Gravity field on the floor: two purple rings at the edge, pulsing until the burst.
        if n>=cfg.FieldStart and n<cfg.Burst+.4 then
            local grow=smoothstep((n-cfg.FieldStart)/.45)
            local fade=smoothstep((n-cfg.Burst)/.4)
            fieldPose(CFrame.new(center+Vector3.yAxis*.25),cfg.Radius*grow,.35+.4*math.abs(math.sin(n*3))+.25*fade)
            innerPose(CFrame.new(center+Vector3.yAxis*.22),cfg.Radius*grow*(1-((n*.6)%1)),.55+.45*fade)
            if not drone then
                drone=VFX.sound("Drone",core,.9,cfg.Duration)
                if drone then drone.Looped=true end
            end
        else fieldPose(CFrame.new(center-Vector3.yAxis*500),1,1);innerPose(CFrame.new(center-Vector3.yAxis*500),1,1) end
        -- Sand and dust rise inside the field.
        if n>=cfg.FieldStart and n<cfg.Formed and n>=nextDust then
            nextDust=n+.035
            local a=math.random()*math.pi*2;local d=math.random()*cfg.Radius*.85
            local from=groundAt(center+Vector3.new(math.cos(a)*d,0,math.sin(a)*d))
            VFX.dust(from+Vector3.yAxis,1.5+math.random()*2,(core-from).Unit*(8+math.random()*10),1.4)
        end
        -- Rocks.
        local packedFill=0;local arrived=0
        local squeeze=1-.18*smoothstep((n-5.35)/.25)
        for i,r in rocks do
            if n>=r.launch and n<cfg.Burst then
                if not r.part then
                    r.part=rock(r.size,CFrame.new(r.from)*r.spin,r.shade)
                    if r.size.X>3 then scorch(r.from,r.size.X*.7,cfg.CraterTime*.8) end
                    if i%4==0 then VFX.dust(r.from+Vector3.yAxis,r.size.X,Vector3.yAxis*4,.9) end
                end
                local u=math.clamp((n-r.launch)/(r.arrive-r.launch),0,1)
                local target=core+r.dir*r.radius*squeeze
                -- Spiral: interpolate in a cylinder around the core's vertical axis.
                local rel0=r.from-core;local rel1=target-core
                local a0=math.atan2(rel0.Z,rel0.X);local a1=math.atan2(rel1.Z,rel1.X)
                local d0=Vector3.new(rel0.X,0,rel0.Z).Magnitude;local d1=Vector3.new(rel1.X,0,rel1.Z).Magnitude
                local eu=u*u*(3-2*u)
                local angle=a0+(math.atan2(math.sin(a1-a0),math.cos(a1-a0)))*eu+r.swirl*math.sin(u*math.pi)*.9
                local radial=d0+(d1-d0)*eu
                local height=rel0.Y+(rel1.Y-rel0.Y)*(u^1.35)
                local at=core+Vector3.new(math.cos(angle)*radial,height,math.sin(angle)*radial)
                local tumble=(1-u)*n*4
                r.part.CFrame=CFrame.new(at)*CFrame.Angles(tumble,tumble*.7,0)*r.spin
                if u>=1 then
                    arrived+=1
                    if not r.landed then
                        r.landed=true
                        if clacks<10 or n>clackWindow then
                            if n>clackWindow then clackWindow=n+.12;clacks=0 end
                            clacks+=1;VFX.sound("Clack",at,.35,1,.8+math.random()*.5)
                        end
                        if i%3==0 then VFX.dust(at,1.6,(at-core).Unit*3,.6) end
                    end
                end
            end
        end
        if n>=cfg.DebrisStart and n<cfg.Burst then
            packedFill=smoothstep((n-cfg.DebrisStart)/(cfg.Formed-cfg.DebrisStart))
            packed.Transparency=packedFill>.02 and 0 or 1
            packed.Size=Vector3.one*(R*1.7*packedFill+.1)*squeeze
            packed.CFrame=CFrame.new(core)*CFrame.Angles(0,n*.3,0)
        end
        -- Silence, then purple light leaks through spreading cracks.
        for i,c in cracks do
            local grow=smoothstep((n-4.9-i*.025)/.35)
            if grow>0 and n<cfg.Burst then
                local from=core+c.dir*(R*squeeze+.15)
                local len=c.length*grow
                c.part.Size=Vector3.new(.3,.3,len)
                c.part.CFrame=CFrame.lookAt(from,from+c.tangent)*CFrame.new(0,0,-len/2)
                c.part.Transparency=.1
            else c.part.Transparency=1 end
        end
        coreFx.light.Brightness=n<4.9 and 4 or 4+20*smoothstep((n-4.9)/.6)
        -- Burst.
        if n>=cfg.Burst and not handle.burst then
            handle.burst=true
            packed.Transparency=1
            local e=Instance.new("Explosion");e.Position=core;e.BlastRadius=24;e.BlastPressure=0;e.DestroyJointRadiusPercent=0
            e.ExplosionType=Enum.ExplosionType.NoCraters;e.Parent=folder
            VFX.sound("Boom",core,1,4,.7);VFX.sound("Thud",core,1,4,.6)
            for _,r in rocks do
                if r.part then
                    local p=r.part;r.part=nil
                    local from=p.Position;local velocity=r.burst*(.6+math.random()*.5)
                    local spin=CFrame.Angles(math.random()*6,math.random()*6,0);local axis=Vector3.new(math.random()-.5,math.random()-.5,math.random()-.5).Unit
                    local life=2+math.random()*1.4
                    run(life,function(a)
                        local at=from+velocity*a-Vector3.yAxis*35*a*a
                        local floorY=center.Y+r.size.Y*.3
                        if at.Y<floorY then at=Vector3.new(at.X,floorY,at.Z) end
                        p.CFrame=CFrame.new(at)*CFrame.fromAxisAngle(axis,a*5)*spin
                        p.Transparency=smoothstep((a-life*.55)/(life*.45))
                    end,function() release("Rock",p) end)
                end
            end
            for _=1,22 do
                local dir=Vector3.new(math.random()-.5,math.random()-.5,math.random()-.5).Unit
                throwRock(core+dir*R*.6,dir*(30+math.random()*50),.8+math.random()*1.6,2.4,40)
            end
            local shell=part("ChibakuBurst",Vector3.one*R*2,COLORS.Rinnegan,CFrame.new(core),Enum.PartType.Ball,Enum.Material.ForceField)
            local flash=part("ChibakuFlash",Vector3.one*R,Color3.fromRGB(240,226,255),CFrame.new(core),Enum.PartType.Ball)
            run(.7,function(a)
                local u=a/.7
                shell.Size=Vector3.one*(R*2+70*smoothstep(u));shell.Transparency=u
                flash.Size=Vector3.one*(R+20*u);flash.Transparency=.2+.8*smoothstep(u*1.6)
            end,function() shell:Destroy();flash:Destroy() end)
            -- Dust ring rolling out across the floor beneath the blast, and a temporary crater.
            for i=1,26 do
                local a=i/26*math.pi*2;local dir=Vector3.new(math.cos(a),0,math.sin(a))
                VFX.dust(center+dir*4+Vector3.yAxis*2,7,dir*30+Vector3.yAxis*2,2.6,Color3.fromRGB(150,140,128))
            end
            scorch(center,16,cfg.CraterTime)
            for i=1,14 do
                local a=i/14*math.pi*2;local at=groundAt(center+Vector3.new(math.cos(a),0,math.sin(a))*15.5)
                local p=rock(Vector3.new(2.2,1.2,1.8),CFrame.new(at)*CFrame.Angles(0,a,.3))
                run(cfg.CraterTime,function(t) p.Transparency=smoothstep((t-cfg.CraterTime+1.2)/1.2) end,function() release("Rock",p) end)
            end
            if drone then drone:Stop() end
        end
    end,cleanup,start)
    -- Interrupted: rocks drop out of the sky and everything fades.
    function handle.stop(reason)
        if handle.stopped or handle.burst then return end
        handle.stopped=true
        for _,r in rocks do
            if r.part then
                local p=r.part;r.part=nil
                local from=p.Position
                run(1.2,function(a)
                    local at=from-Vector3.yAxis*35*a*a;if at.Y<center.Y then at=Vector3.new(at.X,center.Y,at.Z) end
                    p.CFrame=CFrame.new(at);p.Transparency=smoothstep((a-.5)/.7)
                end,function() release("Rock",p) end)
            end
        end
        handle.effect.dead=true
    end
    return handle
end
-- Brighten a caster's Rinnegan for a moment (strength 1 for Q/E, 2 for R).
function VFX.eyeFlare(model,strength,duration)
    if not model then return end
    local lights,parts={},{}
    for _,v in model:GetDescendants() do
        if v:IsA("PointLight") and v.Name=="PainEyeGlow" then table.insert(lights,v) end
        if v:IsA("BasePart") and v.Name=="PainRinnegan" and v.Material==Enum.Material.Neon then table.insert(parts,{p=v,color=v.Color}) end
    end
    run(duration,function(age)
        local k=math.sin(math.clamp(age/duration,0,1)*math.pi)
        for _,l in lights do l.Brightness=.4+6*strength*k;l.Range=3+6*strength*k end
        for _,e in parts do e.p.Color=e.color:Lerp(Color3.fromRGB(255,240,255),.6*k) end
    end,function()
        for _,l in lights do l.Brightness=.4;l.Range=3 end
        for _,e in parts do if e.p.Parent then e.p.Color=e.color end end
    end)
end
VFX.Lighting=Lighting
return VFX
