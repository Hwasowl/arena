-- All Might world effects, run on every client from the server's AllMight* events. Wind pressure, shockwaves,
-- dust, cracks and debris only: nothing here is a beam. Nothing touches gameplay either: positions come from the
-- server, every part is anchored and non-collidable, rocks and dust are pooled, and each effect has a hard lifetime.
local RunService=game:GetService("RunService")
local Debris=game:GetService("Debris")
local RS=game:GetService("ReplicatedStorage")
local A=require(RS:WaitForChild("AllMightConfig"))
local COLORS=A.Colors

local VFX={}
-- Built-in placeholders. Replace with uploaded ids (heartbeat, roar, "SMASH!", "PLUS ULTRA!!!", wind, impact).
VFX.Sounds={
    Heartbeat={id="rbxasset://sounds/impact_generic.mp3",speed=.38},
    Roar={id="rbxasset://sounds/action_falling.mp3",speed=.45},
    Exhale={id="rbxasset://sounds/action_falling.mp3",speed=.7},
    Rumble={id="rbxasset://sounds/action_falling.mp3",speed=.25},
    Wind={id="rbxasset://sounds/swordslash.wav",speed=.42},
    Whoosh={id="rbxasset://sounds/swordslash.wav",speed=.7},
    Impact={id="rbxasset://sounds/impact_generic.mp3",speed=.5},
    Boom={id="rbxasset://sounds/impact_generic.mp3",speed=.34},
    Thud={id="rbxasset://sounds/impact_generic.mp3",speed=.8},
    Bump={id="rbxasset://sounds/impact_generic.mp3",speed=1.1},
    -- Voice lines: no voice assets ship with the place, so these are stand-ins; the words are shown on screen.
    VoiceSmashLead={id="rbxasset://sounds/electronicpingshort.mp3",speed=.5},
    VoiceSmash={id="rbxasset://sounds/impact_generic.mp3",speed=.62},
    VoicePlus={id="rbxasset://sounds/electronicpingshort.mp3",speed=.45},
    VoiceUltra={id="rbxasset://sounds/impact_generic.mp3",speed=.4},
}
local folder=Instance.new("Folder");folder.Name="AllMightFX";folder.Parent=workspace
local active={}
local function clock() return workspace:GetServerTimeNow() end
local function smoothstep(x) x=math.clamp(x,0,1);return x*x*(3-2*x) end
VFX.smoothstep=smoothstep
VFX.folder=folder
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
            if e.cleanup then local ok,err=pcall(e.cleanup);if not ok then warn("AllMightVFX cleanup",err) end end
        elseif age>=0 then
            local ok,err=pcall(e.update,age,dt);if not ok then warn("AllMightVFX",err);e.dead=true end
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
    local holder=part("AllMightSound",Vector3.one*.1,Color3.new(),CFrame.new(position));holder.Transparency=1
    local s=Instance.new("Sound");s.SoundId=cue.id;s.Volume=volume or .6;s.PlaybackSpeed=cue.speed*(speedScale or 1)
    s.RollOffMinDistance=14;s.RollOffMaxDistance=260;s.Parent=holder;s:Play()
    Debris:AddItem(holder,duration or 3)
    return s
end

---------------------------------------------------------------- pools
local pools={Rock={},Dust={},Streak={}}
local PARK=CFrame.new(0,-5000,0)
local function acquire(kind)
    local p=table.remove(pools[kind])
    if not p then
        if kind=="Rock" then p=part("AllMightRock",Vector3.one,COLORS.Rock,PARK,Enum.PartType.Block,Enum.Material.Slate)
        elseif kind=="Dust" then p=part("AllMightDust",Vector3.one,COLORS.Dust,PARK,Enum.PartType.Ball,Enum.Material.SmoothPlastic)
        else p=part("AllMightStreak",Vector3.one,COLORS.Wind,PARK,Enum.PartType.Block,Enum.Material.Neon) end
    end
    p.Transparency=0;return p
end
local function release(kind,p)
    if not p or not p.Parent then return end
    p.Transparency=1;p.CFrame=PARK
    if #pools[kind]<240 then table.insert(pools[kind],p) else p:Destroy() end
end
local function groundAt(position)
    local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={folder,workspace.CurrentCamera};params.RespectCanCollide=true
    local hit=workspace:Raycast(position+Vector3.yAxis*3,Vector3.yAxis*-80,params)
    return hit and hit.Position or position-Vector3.yAxis*3,hit and hit.Normal or Vector3.yAxis
end
VFX.groundAt=groundAt
-- A soft dust puff that drifts, grows and fades.
function VFX.dust(position,size,velocity,life,color,startAlpha)
    local p=acquire("Dust");p.Size=Vector3.one*size*.5;p.CFrame=CFrame.new(position);p.Color=color or COLORS.Dust
    local a0=startAlpha or .4;p.Transparency=a0
    local grow=size*(1.5+math.random()*.7)
    run(life,function(age)
        local u=age/life
        p.CFrame=CFrame.new(position+velocity*life*(1-(1-u)^2.5))
        p.Size=Vector3.one*(size*.5+(grow-size*.5)*smoothstep(u))
        p.Transparency=a0+(1-a0)*u
    end,function() release("Dust",p) end)
end
-- Ballistic debris with spin, fading out before it is returned to the pool.
function VFX.rock(position,velocity,size,life,gravity)
    local p=acquire("Rock");p.Size=Vector3.new(size,size*(.5+math.random()*.5),size*(.7+math.random()*.4))
    p.Color=COLORS.Rock:Lerp(Color3.fromRGB(70,64,58),math.random()*.7)
    local spin=CFrame.Angles(math.random()*6,math.random()*6,math.random()*6)
    local axis=Vector3.new(math.random()-.5,math.random()-.5,math.random()-.5).Unit
    local g=gravity or 110;local floor=position.Y-1
    run(life,function(age)
        local at=position+velocity*age-Vector3.yAxis*.5*g*age*age
        if at.Y<floor then at=Vector3.new(at.X,floor,at.Z) end
        p.CFrame=CFrame.new(at)*CFrame.fromAxisAngle(axis,age*9)*spin
        p.Transparency=smoothstep((age-life*.65)/(life*.35))
    end,function() release("Rock",p) end)
end
-- A short white wind streak: a thin stretched neon bar sliding along `direction` and fading.
function VFX.streak(position,direction,length,speed,life,color,width)
    local p=acquire("Streak");p.Color=color or COLORS.Wind
    local w=width or .08
    run(life,function(age)
        local u=age/life
        local at=position+direction*speed*age
        p.Size=Vector3.new(w,w,length*(1-.5*u))
        p.CFrame=CFrame.lookAt(at,at+direction)
        p.Transparency=.25+.75*u
    end,function() release("Streak",p) end)
end
-- Thin ring made of segments; pose(frame, radius, transparency, thickness).
local function ring(segments,thickness,color,material)
    local list={}
    for i=1,segments do list[i]=part("AllMightRing",Vector3.one*thickness,color,PARK,nil,material) end
    local function pose(frame,radius,transparency,width)
        local w=width or thickness
        for i,p in list do
            local a=(i-1)*math.pi*2/#list;local b=i*math.pi*2/#list
            local from=(frame*CFrame.new(math.cos(a)*radius,0,math.sin(a)*radius)).Position
            local to=(frame*CFrame.new(math.cos(b)*radius,0,math.sin(b)*radius)).Position
            p.Size=Vector3.new(w,w*.5,(to-from).Magnitude+w*.5)
            p.CFrame=CFrame.lookAt((from+to)/2,to);p.Transparency=transparency
        end
    end
    local function destroy() for _,p in list do p:Destroy() end end
    return pose,destroy
end
VFX.ring=ring
-- An expanding ring around `axis` (Vector3 normal) through `center`.
function VFX.shockRing(center,axis,radius,life,color,thickness,segments,delayTime)
    local pose,destroy=ring(segments or 28,thickness or .5,color or COLORS.Wind)
    local up=axis.Unit
    local right=math.abs(up.Y)<.95 and up:Cross(Vector3.yAxis).Unit or Vector3.xAxis
    local frame=CFrame.fromMatrix(center,right,up)
    pose(frame,.1,1)
    run(life,function(age)
        local u=age/life
        pose(frame,radius*(1-(1-u)^3),.1+.9*u*u,(thickness or .5)*(1-.6*u))
    end,destroy,clock()+(delayTime or 0))
end
-- A translucent sphere that blows outward (the air pressure front).
function VFX.pressure(center,radius,life,color,startAlpha)
    local p=part("AllMightPressure",Vector3.one*.5,color or COLORS.Wind,CFrame.new(center),Enum.PartType.Ball,Enum.Material.ForceField)
    local a0=startAlpha or .2
    run(life,function(age)
        local u=age/life
        p.Size=Vector3.one*radius*2*(1-(1-u)^3);p.Transparency=a0+(1-a0)*u
    end,function() p:Destroy() end)
end
-- Short-lived bright light, the "flash" others see.
function VFX.flash(position,brightness,range,life,color)
    local holder=part("AllMightFlash",Vector3.one*.1,Color3.new(),CFrame.new(position));holder.Transparency=1
    local light=Instance.new("PointLight");light.Color=color or Color3.new(1,1,1);light.Range=range;light.Brightness=brightness;light.Parent=holder
    run(life,function(age) light.Brightness=brightness*(1-age/life) end,function() holder:Destroy() end)
end
-- Radial cracks on the floor: dark thin slabs from the center, with a scorched disc that fades after `life`.
function VFX.cracks(center,radius,count,life,direction,bias)
    local floor,normal=groundAt(center)
    local parts={}
    local disc=part("AllMightCrater",Vector3.new(.06,radius*.55,radius*.55),Color3.fromRGB(58,52,46),CFrame.new(floor+normal*.03)*CFrame.Angles(0,0,math.pi/2),Enum.PartType.Cylinder,Enum.Material.Slate)
    table.insert(parts,disc)
    for i=1,count do
        local a=i/count*math.pi*2+math.random()*.4
        local d=Vector3.new(math.cos(a),0,math.sin(a))
        local length=radius*(.45+math.random()*.55)
        if direction and bias then
            local along=math.max(0,d:Dot(direction))
            length*=1+along*bias
        end
        -- Two kinked segments per crack.
        local mid=floor+d*length*.5+Vector3.new(-d.Z,0,d.X)*(math.random()-.5)*length*.15
        local tip=floor+d*length
        for j,seg in {{floor+d*radius*.12,mid},{mid,tip}} do
            local from,to=seg[1],seg[2]
            local p=part("AllMightCrack",Vector3.new(.22-j*.06,.06,(to-from).Magnitude),Color3.fromRGB(34,30,28),
                CFrame.lookAt((from+to)/2+normal*.05,to+normal*.05),nil,Enum.Material.Slate)
            p.Size=Vector3.new(0,.06,0);table.insert(parts,p)
            local full=Vector3.new(.24-j*.07,.06,(to-from).Magnitude)
            local growStart=(j-1)*.05
            run(.12,function(age) local u=smoothstep(age/.12);p.Size=Vector3.new(full.X,.06,full.Z*u);p.CFrame=CFrame.lookAt(from:Lerp(to,u*.5)+normal*.05,to+normal*.05) end,nil,clock()+growStart)
        end
    end
    run(life,function(age)
        local fade=smoothstep((age-life*.75)/(life*.25))
        for _,p in parts do p.Transparency=fade end
    end,function() for _,p in parts do p:Destroy() end end)
    return floor
end
-- Dust thrown into a ring along the floor (and a few chunks of debris).
function VFX.dustRing(center,radius,count,life,rocks,direction)
    local floor=groundAt(center)
    for i=1,count do
        local a=i/count*math.pi*2+math.random()*.3
        local d=Vector3.new(math.cos(a),0,math.sin(a))
        local push=direction and (1+math.max(0,d:Dot(direction))*1.4) or 1
        VFX.dust(floor+d*radius*.25+Vector3.yAxis*.6,2.2+math.random()*1.6,d*radius*push*.9+Vector3.yAxis*(1+math.random()*2),life*(.8+math.random()*.4))
    end
    for _=1,rocks or 0 do
        local a=math.random()*math.pi*2
        local d=Vector3.new(math.cos(a),0,math.sin(a))
        if direction and math.random()<.65 then d=(direction+d*.55).Unit end
        VFX.rock(floor+d*1.5+Vector3.yAxis*.6,d*(18+math.random()*26)+Vector3.yAxis*(14+math.random()*20),.35+math.random()*.7,1.2+math.random()*.6)
    end
end
-- Gold sparks: small neon bits shot from `center`.
function VFX.sparks(center,count,speed,life,color)
    for _=1,count do
        local d=Vector3.new(math.random()-.5,math.random()-.2,math.random()-.5).Unit
        VFX.streak(center,d,.35+math.random()*.4,speed*(.5+math.random()*.7),life*(.6+math.random()*.6),color or COLORS.Spark,.06)
    end
end
-- Steam wisps rising from a point for `life`.
function VFX.steam(getPosition,life,rate)
    local nextAt=0
    run(life,function(age)
        if age<nextAt then return end
        nextAt=age+(rate or .07)
        local at=getPosition();if not at then return end
        VFX.dust(at+Vector3.new(math.random()-.5,0,math.random()-.5)*.4,.7+math.random()*.4,Vector3.new(math.random()-.5,2.4,math.random()-.5),.8,COLORS.Steam,.55)
    end)
end

---------------------------------------------------------------- character helpers
local function rootOf(model) return model and model:FindFirstChild("HumanoidRootPart") end
local function limb(model,names) for _,n in names do local p=model and model:FindFirstChild(n);if p then return p end end end
-- Attaches an emitter to a part; returned so the caller can stop it.
local function emitter(parent,color,rate,speed,size,life,lightEmission)
    local e=Instance.new("ParticleEmitter");e.Color=ColorSequence.new(color);e.Rate=rate
    e.Speed=NumberRange.new(speed*.5,speed);e.Lifetime=NumberRange.new(life*.6,life);e.SpreadAngle=Vector2.new(180,180)
    e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,size),NumberSequenceKeypoint.new(1,0)})
    e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.1),NumberSequenceKeypoint.new(1,1)})
    e.LightEmission=lightEmission or 1;e.Parent=parent
    return e
end
VFX.emitter=emitter

---------------------------------------------------------------- Q: One For All: Full Power
-- Prep: sparks and steam on the arms, then (at Open) the ring and dust from the feet.
function VFX.powerCast(model,data)
    local root=rootOf(model);if not root then return end
    local arms={limb(model,{"RightLowerArm","Right Arm"}),limb(model,{"LeftLowerArm","Left Arm"})}
    local emitters={}
    for _,arm in arms do
        if arm then
            table.insert(emitters,emitter(arm,COLORS.Spark,14,4,.18,.35))
            table.insert(emitters,emitter(arm,COLORS.Steam,10,2,.6,.8,0))
        end
    end
    run(data.prep+.1,function(age)
        for _,e in emitters do if e.LightEmission>0 then e.Rate=14+40*smoothstep((age-data.open)/.2) end end
    end,function() for _,e in emitters do e.Enabled=false;Debris:AddItem(e,1) end end,data.start)
    task.delay(math.max(0,data.start+data.open-clock()),function()
        if not root.Parent then return end
        local feet=groundAt(root.Position)
        VFX.shockRing(feet+Vector3.yAxis*.3,Vector3.yAxis,16,.55,COLORS.Wind,.6,32)
        VFX.shockRing(feet+Vector3.yAxis*.5,Vector3.yAxis,11,.45,COLORS.Gold,.35,28,.05)
        VFX.dustRing(feet,14,16,.9,6)
        VFX.sparks(root.Position+Vector3.yAxis,24,26,.5)
        VFX.flash(root.Position,4,18,.35,COLORS.Gold)
        VFX.sound("Roar",root.Position,.9,2.5)
    end)
end
-- While buffed: gold sparks and wind on the arms; afterimages and dust while running.
function VFX.powerAura(model,untilTime)
    local root=rootOf(model);if not root then return end
    local emitters={}
    for _,names in {{"RightLowerArm","Right Arm"},{"LeftLowerArm","Left Arm"},{"RightHand"},{"LeftHand"}} do
        local arm=limb(model,names)
        if arm then table.insert(emitters,emitter(arm,COLORS.Gold,18,3,.14,.4)) end
    end
    local light=Instance.new("PointLight");light.Color=COLORS.Gold;light.Range=8;light.Brightness=.8;light.Parent=root
    local nextGhost,nextDust=0,0
    local handle=run(math.max(0,untilTime-clock())+.05,function(age)
        if not root.Parent then return end
        local speed=(root.AssemblyLinearVelocity*Vector3.new(1,0,1)).Magnitude
        light.Brightness=.6+.3*math.sin(age*12)
        if speed>8 and age>=nextGhost then
            nextGhost=age+.09
            -- Afterimage: a pale gold silhouette left behind and fading.
            local ghost=part("AllMightAfterimage",Vector3.new(2.6,3.6,1.3),COLORS.Gold,root.CFrame*CFrame.new(0,.3,0),Enum.PartType.Block,Enum.Material.ForceField)
            run(.3,function(a) ghost.Transparency=.55+.45*(a/.3) end,function() ghost:Destroy() end)
        end
        if speed>8 and age>=nextDust then
            nextDust=age+.12
            local feet=groundAt(root.Position)
            local back=-(root.AssemblyLinearVelocity*Vector3.new(1,0,1)).Unit
            VFX.dust(feet+Vector3.yAxis*.4,1.4,back*3+Vector3.yAxis,.5)
        end
    end,function()
        for _,e in emitters do e.Enabled=false;Debris:AddItem(e,1) end
        light:Destroy()
    end)
    return handle
end
function VFX.powerOff(model)
    local root=rootOf(model);if not root then return end
    VFX.steam(function() return root.Parent and root.Position+Vector3.yAxis*1.5 or nil end,1.1,.06)
    VFX.sound("Exhale",root.Position,.6,2)
end

---------------------------------------------------------------- E: United States of Smash
function VFX.smashCast(model,data)
    local root=rootOf(model);if not root then return end
    local hand=limb(model,{"RightHand","Right Arm"})
    local gold=hand and emitter(hand,data.buffed and COLORS.Gold or COLORS.Spark,data.buffed and 40 or 22,2,.2,.3)
    if gold then Debris:AddItem(gold,A.UnitedStatesOfSmash.Impact) end
    VFX.sound("Rumble",root.Position,.5,1.5)
end
function VFX.smashDash(model,data)
    local root=rootOf(model)
    local from,dir=data.from,data.direction
    VFX.sound("Wind",from,.8,1.5)
    local floor=groundAt(from)
    VFX.dustRing(floor,6,8,.6,2,-dir)
    local side=dir:Cross(Vector3.yAxis)
    -- White pressure streaks around the body along the dash, and dust kicked up behind.
    local nextAt=0
    run(.4,function(age)
        if age<nextAt or not root or not root.Parent then return end
        nextAt=age+.03
        local at=root.Position
        for _=1,3 do
            local o=side*(math.random()-.5)*4+Vector3.yAxis*(math.random()-.3)*3.5
            VFX.streak(at+o+dir*2,-dir,3+math.random()*3,40,.18)
        end
        VFX.dust(groundAt(at)+Vector3.yAxis*.4,1.2,-dir*4+Vector3.yAxis*1.5,.5)
    end,nil,data.start)
end
function VFX.smashImpact(data)
    local cfg=A.UnitedStatesOfSmash
    local at,dir=data.position,data.direction
    local scale=data.buffed and 1.25 or 1
    local tint=data.buffed and COLORS.Gold or COLORS.Wind
    VFX.flash(at,data.hit and 10 or 4,30*scale,.25)
    VFX.pressure(at,(data.hit and 7 or 4)*scale,.35,COLORS.Wind,.1)
    VFX.shockRing(at,dir,9*scale,.4,COLORS.Wind,.7,30)
    VFX.shockRing(at+dir*2,dir,13*scale,.5,tint,.45,30,.04)
    if data.hit then
        VFX.shockRing(groundAt(at)+Vector3.yAxis*.3,Vector3.yAxis,cfg.ShockRadius*scale,.5,COLORS.Wind,.6,36)
        VFX.cracks(at,8*scale,12,4,dir,1.3)
        VFX.dustRing(at,10*scale,18,1.1,data.buffed and 16 or 12,dir)
        VFX.sound("Impact",at,1,2)
        VFX.sound("Boom",at,.9,2.5)
    end
    -- A cone of wind pressure that keeps going past the target.
    for i=1,(data.hit and 22 or 12) do
        local spread=Vector3.new(math.random()-.5,(math.random()-.5)*.6,math.random()-.5)*.7
        local d=(dir+spread).Unit
        VFX.streak(at+d*1.5,d,4+math.random()*5,70+math.random()*40,.32,i%3==0 and tint or COLORS.Wind,.12)
    end
    if data.buffed then VFX.sparks(at,28,34,.45,COLORS.Gold) end
    VFX.sound("Wind",at,.7,1.5,1.2)
end
function VFX.bump(data)
    VFX.flash(data.position,2,10,.15)
    VFX.dustRing(data.position,4,8,.6,3)
    VFX.sound("Bump",data.position,.7,1)
end
function VFX.wallHit(position,normal)
    VFX.shockRing(position,normal,5,.3,COLORS.Wind,.35,20)
    for _=1,10 do
        local d=(normal+Vector3.new(math.random()-.5,math.random()-.2,math.random()-.5)).Unit
        VFX.rock(position,d*(14+math.random()*16),.3+math.random()*.5,1)
    end
    VFX.dust(position,3,normal*4,.9)
    VFX.sound("Thud",position,.8,1.5)
end
-- White air trail behind a body that was punched away; rings for heavy hits.
function VFX.knockTrail(model,duration,heavy)
    local root=rootOf(model);if not root then return end
    local nextAt=0;local last=root.Position
    run(duration+.1,function(age)
        if not root.Parent or age<nextAt then return end
        nextAt=age+.025
        local at=root.Position;local v=at-last;last=at
        if v.Magnitude>.05 then
            VFX.streak(at,-v.Unit,v.Magnitude*3+1.5,4,.25,COLORS.Wind,heavy and .3 or .14)
            if heavy and math.random()<.3 then VFX.dust(at,1,Vector3.zero,.35,COLORS.Wind,.6) end
        end
    end)
end

---------------------------------------------------------------- R: Plus Ultra
-- Windup: gold sparks and white air drawn into the right fist, dust and pebbles pushed outward from the feet.
function VFX.ultraCast(model,data)
    local root=rootOf(model);if not root then return end
    local cfg=A.PlusUltra
    local hand=limb(model,{"RightHand","Right Arm"})
    local nextAt=0
    VFX.sound("Rumble",root.Position,.8,2,.8)
    local feet=groundAt(root.Position)
    VFX.dustRing(feet,7,14,cfg.Windup+.4,10)
    run(cfg.Windup,function(age)
        if age<nextAt or not root.Parent then return end
        nextAt=age+.035
        local fist=hand and hand.Position or root.Position+Vector3.yAxis
        for _=1,2 do
            local d=Vector3.new(math.random()-.5,math.random()-.5,math.random()-.5).Unit
            local from=fist+d*(3+math.random()*2)
            VFX.streak(from,-d,.6+math.random()*.6,10,.3,math.random()<.5 and COLORS.Gold or COLORS.Wind,.07)
        end
    end,nil,data.start)
end
function VFX.ultraDash(model,data)
    local root=rootOf(model)
    local from,dir=data.from,data.direction
    VFX.cracks(from,6,10,5,-dir,.8)
    VFX.dustRing(from,8,16,.9,8,-dir)
    VFX.shockRing(groundAt(from)+Vector3.yAxis*.3,Vector3.yAxis,9,.4,COLORS.Wind,.5,28)
    VFX.sound("Boom",from,.9,2,1.2);VFX.sound("Wind",from,.9,1.5)
    local side=dir:Cross(Vector3.yAxis)
    local nextAt=0
    run(A.PlusUltra.DashTime,function(age)
        if age<nextAt or not root or not root.Parent then return end
        nextAt=age+.025
        for _=1,4 do
            local o=side*(math.random()-.5)*6+Vector3.yAxis*(math.random()-.3)*4
            VFX.streak(root.Position+o+dir*3,-dir,5+math.random()*5,60,.2,math.random()<.4 and COLORS.Speed or COLORS.Wind,.1)
        end
        VFX.dust(groundAt(root.Position)+Vector3.yAxis*.4,1.6,-dir*6+Vector3.yAxis*2,.6)
    end,nil,data.start)
end
function VFX.ultraFail(data)
    VFX.dustRing(data.position,5,10,.8,4,data.direction)
    VFX.sound("Thud",data.position,.6,1)
end
-- Wind around both bodies during the air chase.
function VFX.ultraChase(owner,target,duration,start)
    local a,b=rootOf(owner),rootOf(target)
    local nextAt=0
    run(duration,function(age)
        if age<nextAt then return end
        nextAt=age+.04
        for _,r in {a,b} do
            if r and r.Parent then
                local o=Vector3.new(math.random()-.5,0,math.random()-.5)*4
                VFX.streak(r.Position+o-Vector3.yAxis*2,Vector3.yAxis,4+math.random()*3,-30,.22,COLORS.Wind,.08)
            end
        end
    end,nil,start)
end
function VFX.ultraPunch(data)
    local at,dir=data.position,data.direction
    if data.index==1 then
        VFX.flash(at,12,40,.3)
        VFX.pressure(at,9,.4,COLORS.Wind,.05)
        VFX.shockRing(at,dir,12,.45,COLORS.Wind,.8,32)
        VFX.shockRing(at,dir,7,.35,COLORS.Wind,.5,24,.05)
        VFX.dustRing(at,9,16,1,10,dir)
        VFX.cracks(at,7,10,6,dir,1)
        VFX.sound("Impact",at,1,2);VFX.sound("Boom",at,.8,2,1.3)
    else
        VFX.flash(at,6,24,.2)
        VFX.shockRing(at,(dir+Vector3.yAxis*1.2).Unit,6,.3,COLORS.Wind,.45,24)
        VFX.sound("Impact",at,.8,1.5,1.3)
    end
    for i=1,(data.index==1 and 20 or 10) do
        local d=(dir+Vector3.new(math.random()-.5,math.random()*.5,math.random()-.5)*.8).Unit
        VFX.streak(at,d,4+math.random()*4,60,.3,COLORS.Wind,.12)
    end
end
-- The uppercut: flash, circular shockwave, a white/gold wind column along the punch, the ground shockwave,
-- and the launched body's trail with rings left behind it all the way to the apex.
function VFX.ultraUppercut(data,targetModel)
    local cfg=A.PlusUltra
    local at,ground=data.position,data.ground
    VFX.flash(at,16,70,.45,Color3.fromRGB(255,246,214))
    VFX.pressure(at,14,.5,COLORS.Wind,0)
    VFX.shockRing(at,Vector3.yAxis,16,.5,COLORS.Wind,1,36)
    VFX.shockRing(at,Vector3.yAxis,10,.4,COLORS.Gold,.6,30,.04)
    VFX.shockRing(at,(data.direction+Vector3.yAxis*2).Unit,12,.5,COLORS.Wind,.7,30,.08)
    VFX.shockRing(ground+Vector3.yAxis*.3,Vector3.yAxis,data.radius,.6,COLORS.Wind,.7,40)
    VFX.cracks(ground,12,16,7)
    VFX.dustRing(ground,16,24,1.6,18)
    VFX.sparks(at,40,40,.6,COLORS.Gold)
    VFX.sound("Boom",at,1,3,.85);VFX.sound("Impact",at,1,2,.7);VFX.sound("Wind",at,1,2,.6)
    -- Wind column: stacked translucent cylinders rising along the punch, white with a gold core.
    local column={}
    for i=1,6 do
        local c=part("AllMightColumn",Vector3.new(1,5,5),i%2==0 and COLORS.Gold or COLORS.Wind,CFrame.new(at),Enum.PartType.Cylinder,Enum.Material.ForceField)
        column[i]=c
    end
    run(.9,function(age)
        local u=age/.9
        for i,c in column do
            local h=(i-1)*9+40*smoothstep(u*1.4)
            local r=(i%2==0 and 2.4 or 4.2)*(1-u*.5)
            c.Size=Vector3.new(9,r*2,r*2)
            c.CFrame=CFrame.new(at+Vector3.yAxis*h)*CFrame.Angles(0,age*6,math.pi/2)
            c.Transparency=.35+.65*u
        end
    end,function() for _,c in column do c:Destroy() end end)
    -- Rings left behind the rising body, more and more spaced as it accelerates.
    local root=rootOf(targetModel)
    local nextRing=0;local last=root and root.Position or at
    run(data.launch,function(age)
        if not root or not root.Parent then return end
        local pos=root.Position
        local v=pos-last;last=pos
        if v.Magnitude>.05 then VFX.streak(pos,-v.Unit,v.Magnitude*2.5+2,6,.35,COLORS.Wind,.45) end
        if age>=nextRing then
            nextRing=age+.11
            VFX.shockRing(pos-Vector3.yAxis*2,Vector3.yAxis,5+age*4,.45,math.random()<.3 and COLORS.Gold or COLORS.Wind,.5,24)
        end
    end)
end
-- The final ring at the apex, and a small star of light.
function VFX.ultraApex(position)
    VFX.shockRing(position,Vector3.yAxis,26,.7,COLORS.Wind,1.2,40)
    VFX.shockRing(position,Vector3.yAxis,18,.6,COLORS.Gold,.7,32,.06)
    VFX.shockRing(position,Vector3.zAxis,14,.5,COLORS.Wind,.6,28,.1)
    VFX.pressure(position,10,.5,COLORS.Wind,0)
    VFX.flash(position,20,120,.6,Color3.fromRGB(255,250,230))
    local star=part("AllMightStar",Vector3.one*3,Color3.new(1,1,1),CFrame.new(position),Enum.PartType.Ball)
    run(.8,function(age) local u=age/.8;star.Size=Vector3.one*(3+6*u);star.Transparency=u end,function() star:Destroy() end)
    VFX.sound("Boom",position,.8,3,1.4)
end
function VFX.ultraLand(position)
    VFX.cracks(position,10,14,6)
    VFX.dustRing(position,12,20,1.8,10)
    VFX.shockRing(position+Vector3.yAxis*.3,Vector3.yAxis,12,.5,COLORS.Wind,.6,32)
    VFX.sound("Thud",position,1,2,.6)
end
return VFX
