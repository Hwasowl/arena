-- Yujiro Hanma world effects, run on every client from the server's Yujiro* events: white air shockwaves, dust, floor
-- cracks and rocks, afterimages, the Demon Back (배면귀: the back muscles contracting into a demon face, built from
-- parts that follow the torso, never a decal), and the third-person body poses of casters and victims (stance, rush,
-- arms spread, lift, folded / turned / dangling / lying victims) for everyone watching.
-- Nothing here touches gameplay: positions come from the server, every part is anchored and non-collidable, dust and
-- rocks are pooled, and each effect has a hard lifetime. No beams, no energy explosions.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Debris=game:GetService("Debris")
local RS=game:GetService("ReplicatedStorage")
local Y=require(RS:WaitForChild("YujiroConfig"))
local COLORS=Y.Colors

local VFX={}
VFX.Sounds=Y.Sounds
local folder=Instance.new("Folder");folder.Name="YujiroFX";folder.Parent=workspace
VFX.folder=folder
local active={}
local function clock() return workspace:GetServerTimeNow() end
local function smoothstep(x) x=math.clamp(x,0,1);return x*x*(3-2*x) end
local function window(a,from,to) return math.clamp((a-from)/(to-from),0,1) end
local function bump(a,from,to) return math.sin(window(a,from,to)*math.pi) end
local function easeOut(x,power) x=math.clamp(x,0,1);return 1-(1-x)^(power or 2) end
VFX.smoothstep=smoothstep;VFX.window=window;VFX.bump=bump;VFX.easeOut=easeOut
local function run(duration,update,cleanup,start)
    local e={start=start or clock(),duration=duration,update=update,cleanup=cleanup}
    table.insert(active,e);return e
end
VFX.run=run
local function part(name,size,color,cf,shape,material)
    local p=Instance.new("Part");p.Name=name;p.Size=size;p.Color=color;p.CFrame=cf or CFrame.identity
    p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
    p.Material=material or Enum.Material.SmoothPlastic;p.Shape=shape or Enum.PartType.Block;p.Parent=folder
    return p
end
VFX.part=part
function VFX.sound(name,position,volume,duration,speedScale)
    local cue=VFX.Sounds[name];if not cue or not position then return end
    local holder=part("YujiroSound",Vector3.one*.1,Color3.new(),CFrame.new(position));holder.Transparency=1
    local s=Instance.new("Sound");s.SoundId=cue.id;s.Volume=volume or .6;s.PlaybackSpeed=cue.speed*(speedScale or 1)
    s.RollOffMinDistance=14;s.RollOffMaxDistance=260;s.Parent=holder;s:Play()
    Debris:AddItem(holder,duration or 3)
    return s
end
local function rootOf(model) return model and model:FindFirstChild("HumanoidRootPart") end
VFX.rootOf=rootOf
local function torsoOf(model) return model and (model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")) end
local function modelOf(userId) local p=Players:GetPlayerByUserId(userId);return p and p.Character end
local PARK=CFrame.new(0,-5000,0)

---------------------------------------------------------------- pooled pieces
local pools={Rock={},Dust={},Streak={}}
local function acquire(kind)
    local p=table.remove(pools[kind])
    if not p then
        if kind=="Rock" then p=part("YujiroRock",Vector3.one,COLORS.Rock,PARK,Enum.PartType.Block,Enum.Material.Slate)
        elseif kind=="Dust" then p=part("YujiroDust",Vector3.one,COLORS.Dust,PARK,Enum.PartType.Ball)
        else p=part("YujiroStreak",Vector3.one,COLORS.White,PARK,Enum.PartType.Block,Enum.Material.Neon) end
    end
    p.Transparency=0;return p
end
local function release(kind,p)
    if not p or not p.Parent then return end
    p.Transparency=1;p.CFrame=PARK
    if #pools[kind]<200 then table.insert(pools[kind],p) else p:Destroy() end
end
local groundParams=RaycastParams.new();groundParams.FilterType=Enum.RaycastFilterType.Exclude;groundParams.RespectCanCollide=true
local function groundAt(position)
    local list={folder,workspace.CurrentCamera}
    for _,pl in Players:GetPlayers() do if pl.Character then table.insert(list,pl.Character) end end
    groundParams.FilterDescendantsInstances=list
    local hit=workspace:Raycast(position+Vector3.yAxis*3,Vector3.yAxis*-60,groundParams)
    return hit and hit.Position or position-Vector3.yAxis*3,hit and hit.Normal or Vector3.yAxis
end
VFX.groundAt=groundAt
function VFX.dust(position,size,velocity,life,color,startAlpha)
    local p=acquire("Dust");p.Size=Vector3.one*size*.5;p.CFrame=CFrame.new(position);p.Color=color or COLORS.Dust
    local a0=startAlpha or .45;p.Transparency=a0
    local grow=size*(1.5+math.random()*.7)
    run(life,function(age)
        local u=age/life
        p.CFrame=CFrame.new(position+velocity*life*(1-(1-u)^2.5))
        p.Size=Vector3.one*(size*.5+(grow-size*.5)*smoothstep(u))
        p.Transparency=a0+(1-a0)*u
    end,function() release("Dust",p) end)
end
function VFX.rock(position,velocity,size,life)
    local p=acquire("Rock");p.Size=Vector3.new(size,size*(.5+math.random()*.5),size*(.7+math.random()*.4))
    local spin=CFrame.Angles(math.random()*6,math.random()*6,math.random()*6)
    local axis=Vector3.new(math.random()-.5,math.random()-.5,math.random()-.5).Unit
    local floor=position.Y-1
    run(life,function(age)
        local at=position+velocity*age-Vector3.yAxis*55*age*age
        if at.Y<floor then at=Vector3.new(at.X,floor,at.Z) end
        p.CFrame=CFrame.new(at)*CFrame.fromAxisAngle(axis,age*9)*spin
        p.Transparency=smoothstep((age-life*.65)/(life*.35))
    end,function() release("Rock",p) end)
end
function VFX.streak(position,direction,length,speed,life,color,width)
    local p=acquire("Streak");p.Color=color or COLORS.White
    local w=width or .07
    run(life,function(age)
        local u=age/life
        local at=position+direction*speed*age
        p.Size=Vector3.new(w,w,length*(1-.5*u))
        p.CFrame=CFrame.lookAt(at,at+direction)
        p.Transparency=.3+.7*u
    end,function() release("Streak",p) end)
end
-- A thin ring of segments; pose(frame, radius, transparency, width).
local function ring(segments,thickness,color)
    local list={}
    for i=1,segments do list[i]=part("YujiroRing",Vector3.one*thickness,color,PARK,nil,Enum.Material.Neon) end
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
-- An expanding white air ring around `axis` through `center`.
function VFX.shockRing(center,axis,radius,life,thickness,segments,delayTime,color)
    local pose,destroy=ring(segments or 26,thickness or .4,color or COLORS.White)
    local up=axis.Unit
    local right=math.abs(up.Y)<.95 and up:Cross(Vector3.yAxis).Unit or Vector3.xAxis
    local frame=CFrame.fromMatrix(center,right,up)
    pose(frame,.1,1)
    run(life,function(age)
        local u=age/life
        pose(frame,radius*(1-(1-u)^3),.15+.85*u*u,(thickness or .4)*(1-.6*u))
    end,destroy,clock()+(delayTime or 0))
end
-- A translucent sphere of displaced air.
function VFX.pressure(center,radius,life,startAlpha)
    local p=part("YujiroPressure",Vector3.one*.5,COLORS.White,CFrame.new(center),Enum.PartType.Ball,Enum.Material.ForceField)
    local a0=startAlpha or .25
    run(life,function(age) local u=age/life;p.Size=Vector3.one*radius*2*(1-(1-u)^3);p.Transparency=a0+(1-a0)*u end,function() p:Destroy() end)
end
function VFX.flash(position,brightness,range,life)
    local holder=part("YujiroFlash",Vector3.one*.1,Color3.new(),CFrame.new(position));holder.Transparency=1
    local light=Instance.new("PointLight");light.Color=Color3.new(1,1,1);light.Range=range;light.Brightness=brightness;light.Parent=holder
    run(life,function(age) light.Brightness=brightness*(1-age/life) end,function() holder:Destroy() end)
end
-- Radial cracks on the floor with a dark dent in the middle; fades after `life`.
function VFX.cracks(center,radius,count,life)
    local floor,normal=groundAt(center)
    local parts={}
    local disc=part("YujiroCrater",Vector3.new(.06,radius*.5,radius*.5),Color3.fromRGB(58,52,46),CFrame.new(floor+normal*.03)*CFrame.Angles(0,0,math.pi/2),Enum.PartType.Cylinder,Enum.Material.Slate)
    table.insert(parts,disc)
    for i=1,count do
        local a=i/count*math.pi*2+math.random()*.4
        local d=Vector3.new(math.cos(a),0,math.sin(a))
        local length=radius*(.45+math.random()*.55)
        local mid=floor+d*length*.5+Vector3.new(-d.Z,0,d.X)*(math.random()-.5)*length*.18
        local tip=floor+d*length
        for j,seg in {{floor+d*radius*.1,mid},{mid,tip}} do
            local from,to=seg[1],seg[2]
            local full=Vector3.new(.26-j*.07,.06,(to-from).Magnitude)
            local p=part("YujiroCrack",Vector3.new(full.X,.06,.05),COLORS.Crack,CFrame.lookAt(from+normal*.05,to+normal*.05),nil,Enum.Material.Slate)
            table.insert(parts,p)
            run(.12,function(age)
                local u=smoothstep(age/.12)
                p.Size=Vector3.new(full.X,.06,math.max(.05,full.Z*u));p.CFrame=CFrame.lookAt(from:Lerp(to,u*.5)+normal*.05,to+normal*.05)
            end,nil,clock()+(j-1)*.05)
        end
    end
    run(life,function(age)
        local fade=smoothstep((age-life*.75)/(life*.25))
        for _,p in parts do p.Transparency=fade end
    end,function() for _,p in parts do p:Destroy() end end)
    return floor
end
function VFX.dustRing(center,radius,count,life,rocks)
    local floor=groundAt(center)
    for i=1,count do
        local a=i/count*math.pi*2+math.random()*.3
        local d=Vector3.new(math.cos(a),0,math.sin(a))
        VFX.dust(floor+d*radius*.2+Vector3.yAxis*.6,2+math.random()*1.4,d*radius*.9+Vector3.yAxis*(.8+math.random()*1.6),life*(.8+math.random()*.4))
    end
    for _=1,rocks or 0 do
        local a=math.random()*math.pi*2
        local d=Vector3.new(math.cos(a),0,math.sin(a))
        VFX.rock(floor+d*1.2+Vector3.yAxis*.6,d*(10+math.random()*16)+Vector3.yAxis*(12+math.random()*16),.3+math.random()*.6,1.1+math.random()*.5)
    end
end
-- Faint red copies of the body left behind along a dash.
function VFX.afterimage(model,life)
    if not model then return end
    local copies={}
    for _,v in model:GetChildren() do
        if v:IsA("BasePart") and v.Name~="HumanoidRootPart" and v.Transparency<1 and #copies<16 then
            local p=part("YujiroAfterimage",v.Size,COLORS.Red,v.CFrame,nil,Enum.Material.ForceField)
            p.Transparency=.4;table.insert(copies,p)
        end
    end
    run(life,function(age) for _,p in copies do p.Transparency=.4+.6*(age/life) end end,function() for _,p in copies do p:Destroy() end end)
end

---------------------------------------------------------------- the Demon Back (배면귀)
-- Muscle relief on the back of the torso (+Z is the back in the torso's frame), mirrored left/right:
-- trapezius "horns", angry brow ridges, sunken eye grooves, cheek masses, the spine as the nose, the lats as the jaw
-- and a dark grimace groove. Each piece: name, size (fractions of the torso), offset (fractions), roll, groove?
local DEMON={
    {"Horn",Vector3.new(.2,.42,.2),Vector3.new(.36,.5,.48),.55,false,true},
    {"Brow",Vector3.new(.36,.1,.16),Vector3.new(.2,.24,.5),-.38,false,true},
    {"EyeGroove",Vector3.new(.2,.08,.06),Vector3.new(.2,.13,.56),-.2,true,true},
    {"Cheek",Vector3.new(.3,.22,.18),Vector3.new(.25,-.02,.5),.1,false,true},
    {"Lat",Vector3.new(.34,.38,.2),Vector3.new(.33,-.28,.48),-.15,false,true},
    {"Nose",Vector3.new(.1,.36,.16),Vector3.new(0,.04,.52),0,false,false},
    {"Mouth",Vector3.new(.5,.06,.05),Vector3.new(0,-.24,.57),0,true,false},
    {"Fang",Vector3.new(.06,.12,.05),Vector3.new(.13,-.2,.57),.15,true,true},
    {"Jaw",Vector3.new(.6,.14,.16),Vector3.new(0,-.4,.5),0,false,false},
}
local demons={}   -- [model] = {parts, open, close}
local function buildDemon(model)
    local torso=torsoOf(model);if not torso then return nil end
    local base=torso.Color:Lerp(COLORS.SkinDeep,.4)
    local d={model=model,torso=torso,parts={}}
    for _,spec in DEMON do
        local sides=spec[6] and {-1,1} or {1}
        for _,side in sides do
            local p=part("YujiroDemon"..spec[1],Vector3.one*.05,spec[5] and COLORS.Shadow or base,PARK,
                (spec[1]=="Cheek" or spec[1]=="Lat" or spec[1]=="Horn") and Enum.PartType.Ball or Enum.PartType.Block)
            p.Transparency=1
            table.insert(d.parts,{p=p,spec=spec,side=side})
        end
    end
    return d
end
-- Opens at `open`, holds, closes at `close` (server clock). Replaces any earlier one on the same body.
function VFX.demonBack(model,open,close)
    if not model then return end
    local old=demons[model];if old and old.effect then old.effect.dead=true end
    local d=buildDemon(model);if not d then return end
    demons[model]=d
    local life=close-open+.6
    d.close=close
    d.effect=run(life,function(age)
        local torso=d.torso
        if not torso.Parent then return end
        local size=torso.Size
        -- Contracting: the masses rise out of the back over .5 s with a short tremble, then settle into the face.
        local k=easeOut(age/.5,2.2)*(1-smoothstep((clock()-d.close)/.4))
        local tremble=(1-smoothstep((age-.3)/.4))*.03
        for i,e in d.parts do
            local spec=e.spec
            local s=spec[2]*Vector3.new(size.X,size.Y,size.Z*2)*(.2+.8*k)
            -- On the back surface (+Z); the dark grooves sit slightly proud so they read as lines across the masses.
            local off=Vector3.new(spec[3].X*size.X*e.side,spec[3].Y*size.Y,size.Z*.5+(spec[3].Z-.5)*size.Z+s.Z*.3*k)
            e.p.Size=Vector3.new(math.max(.05,s.X),math.max(.05,s.Y),math.max(.05,s.Z))
            e.p.CFrame=torso.CFrame*CFrame.new(off+Vector3.new(math.sin(age*60+i)*tremble,0,0))*CFrame.Angles(0,0,spec[4]*e.side)
            e.p.Transparency=k>.02 and 0 or 1
        end
    end,function()
        for _,e in d.parts do e.p:Destroy() end
        if demons[model]==d then demons[model]=nil end
    end,open)
end
function VFX.closeDemon(model)
    local d=demons[model];if d then d.close=math.min(d.close,clock()) end
end

---------------------------------------------------------------- body poses (third person, every client)
-- Joint offsets are written to Motor6D.Transform after animation each frame (R15 joint names). Victim poses come
-- from the server's YujiroPose attributes; caster poses from the cast timeline.
local casts={}    -- [model] = {kind, start, read, side}
function VFX.setCast(model,info) if model then casts[model]=info end end
function VFX.clearCast(model,kind) if model and casts[model] and (not kind or casts[model].kind==kind) then casts[model]=nil end end
local JOINTS={Neck="Neck",Waist="Waist",Root="Root",RS="RightShoulder",LS="LeftShoulder",RH="RightHip",LH="LeftHip",RE="RightElbow",LE="LeftElbow"}
local function A(x,y,z) return CFrame.Angles(x or 0,y or 0,z or 0) end
local function victimPose(pose,age,side)
    local o={}
    local hit=easeOut(age/.08,2)
    if pose=="Fold" then
        local k=hit*(1-smoothstep((age-.3)/.25))
        o.Waist=A(-.7*k);o.Neck=A(-.35*k);o.RS=A(.5*k,0,.2*k);o.LS=A(.5*k,0,-.2*k)
    elseif pose=="Turn" or pose=="Rock" then
        local hold=pose=="Turn" and .3 or .12
        local k=hit*(1-smoothstep((age-hold)/.22))
        o.Neck=A(.15*k,side*.9*k,side*.25*k);o.Waist=A(0,side*.3*k,0)
    elseif pose=="Uppercut" then
        local k=hit*(1-smoothstep((age-.45)/.35))
        o.Neck=A(.7*k);o.Waist=A(.35*k);o.RS=A(0,0,.6*k);o.LS=A(0,0,-.6*k)
    elseif pose=="Down" then
        local k=hit
        o.Root=CFrame.new(0,-1.1*k,0)*A(-.35*k);o.Waist=A(-.75*k);o.Neck=A(-.4*k);o.RH=A(1.2*k);o.LH=A(1.2*k)
    elseif pose=="Dangle" then
        local k=smoothstep(age/.3);local sway=math.sin(age*7)*.12*k
        o.Neck=A(-.45*k);o.RS=A(.1+sway,0,.12*k);o.LS=A(.1-sway,0,-.12*k);o.RH=A(.25*k+sway);o.LH=A(.25*k-sway);o.Waist=A(-.15*k)
    elseif pose=="Thrown" then
        local k=smoothstep(age/.15)
        o.Waist=A(.4*k);o.Neck=A(.5*k);o.RS=A(0,0,1.1*k);o.LS=A(0,0,-1.1*k);o.RH=A(-.3*k);o.LH=A(.3*k)
    elseif pose=="Lie" then
        local k=easeOut(age/.1,2)
        o.Root=A(1.45*k);o.Neck=A(.3*k);o.RS=A(0,0,1.2*k);o.LS=A(0,0,-1.2*k);o.RH=A(0,0,.2*k);o.LH=A(0,0,-.2*k)
    end
    return o
end
local function casterPose(c,n)
    local o={}
    local a=n-c.start
    if c.kind=="Counter" then
        -- Upright, right hand by the waist, left hand forward, head tilted; on the read the right uppercut.
        local k=smoothstep(a/Y.OgreCounter.Entry)
        local endK=c.read and 1-smoothstep(window(n-c.read,Y.OgreCounter.PunchEnd,Y.OgreCounter.End)) or (c.ended and 1-smoothstep((n-c.ended)/.3) or 1)
        k*=endK
        o.Waist=A(.08*k);o.Neck=A(0,0,.18*k);o.RS=A(.25*k,0,.18*k);o.LS=A(1.15*k,0,-.15*k);o.LE=A(.5*k)
        if c.read then
            local r=n-c.read
            local up=easeOut(window(r,.15,.3),3)*(1-smoothstep(window(r,.5,.9)))
            o.RS=o.RS:Lerp(A(2.6,0,.1),up);o.Neck=A(0,.3*bump(r,0,.2),0)
            o.LS=o.LS:Lerp(A(1.2,0,.4),bump(r,0,.15))
        end
    elseif c.kind=="Rush" then
        local cfg=Y.OgreRush
        local crouch=smoothstep(a/cfg.Crouch)*(1-smoothstep(window(a,cfg.AxeEnd,cfg.End)))
        o.Root=CFrame.new(0,-.5*crouch,0);o.Waist=A(-.3*crouch)
        o.LS=A(1.3*bump(a,cfg.DashEnd,cfg.BodyEnd),0,.3*bump(a,cfg.DashEnd,cfg.BodyEnd))
        o.RS=A(1.5*bump(a,cfg.BodyEnd,cfg.HookEnd),0,.6*bump(a,cfg.BodyEnd,cfg.HookEnd))
        local raise=easeOut(window(a,cfg.HookEnd,1.15),2);local chop=easeOut(window(a,1.15,cfg.Blows[3].Time),3)
        local back=smoothstep(window(a,cfg.AxeEnd,cfg.End))
        o.RH=A((2.3*raise-2.1*chop)*(1-back))
    elseif c.kind=="Judgment" then
        local cfg=Y.OgreJudgment
        local spread=smoothstep(window(a,cfg.Serious,cfg.Serious+.25))*(1-smoothstep(window(a,cfg.Open,cfg.Open+.2)))
        o.Neck=A(-.35*smoothstep(window(a,0,cfg.Serious))*(1-spread));o.Waist=A(.12*spread)
        o.RS=A(-.2*spread,0,1.35*spread);o.LS=A(-.2*spread,0,-1.35*spread)
        if c.captured then
            local grab=smoothstep(window(a,cfg.DashEnd-.15,cfg.DashEnd))*(1-smoothstep(window(a,cfg.LiftFrom-.1,cfg.LiftFrom)))
            o.LS=o.LS*A(1.4*grab)
            local punch=0
            for i,hit in cfg.Hits do if i<#cfg.Hits then punch=math.max(punch,bump(a,hit.Time-.1,hit.Time+.12)) end end
            o.RS=o.RS*A(1.5*punch,0,.2*punch)
            local lift=smoothstep(window(a,cfg.LiftFrom,cfg.LiftTo))*(1-smoothstep(window(a,cfg.Release-.05,cfg.Release+.08)))
            o.RS=o.RS*A(2.6*lift);o.LS=o.LS*A(2.6*lift)
            local wind=smoothstep(window(a,cfg.WindFrom+.1,cfg.WindTo))*(1-easeOut(window(a,cfg.WindTo,cfg.Final),3))
            local final=easeOut(window(a,cfg.WindTo,cfg.Final),3)*(1-smoothstep(window(a,cfg.Final+.4,cfg.End)))
            o.RS=o.RS*A(-.9*wind+1.6*final,0,.4*wind);o.Waist=o.Waist*A(-.25*final,.35*wind-.25*final,0)
        end
    end
    return o
end
local applied={}   -- [model] = {joint name -> current CFrame}
local function jointOf(model,name)
    local j=model:FindFirstChild(name,true)
    return j and j:IsA("Motor6D") and j or nil
end
local function applyPoses(dt)
    local n=clock()
    local wanted={}
    for model,c in casts do
        if not model.Parent then casts[model]=nil
        else wanted[model]=casterPose(c,n) end
    end
    for _,model in workspace:GetChildren() do
        if model:IsA("Model") then
            local pose=model:GetAttribute("YujiroPose")
            if pose and pose~="" and (model:GetAttribute("YujiroHeldUntil") or 0)>n-.3 then
                local o=victimPose(pose,n-(model:GetAttribute("YujiroPoseAt") or n),model:GetAttribute("YujiroPoseSide") or 1)
                local w=wanted[model] or {};for k,v in o do w[k]=v end;wanted[model]=w
            end
        end
    end
    for model,o in wanted do applied[model]=applied[model] or {} end
    for model,cur in applied do
        local o=wanted[model] or {}
        local any=false
        if model.Parent then
            for key,name in JOINTS do
                local target=o[key] or CFrame.identity
                local now_=(cur[key] or CFrame.identity):Lerp(target,math.min(1,dt*18))
                local small=(now_.Position.Magnitude<.002) and (math.abs(now_.LookVector.Z+1)<.0005) and (math.abs(now_.UpVector.Y-1)<.0005)
                if small and not o[key] then
                    if cur[key] then local j=jointOf(model,name);if j then j.Transform=CFrame.identity end end
                    cur[key]=nil
                else
                    cur[key]=now_;any=true
                    local j=jointOf(model,name);if j then j.Transform=now_ end
                end
            end
        end
        if not any then applied[model]=nil end
    end
end

---------------------------------------------------------------- techniques (every client)
function VFX.counterStance(model,data)
    local root=rootOf(model);if not root then return end
    VFX.setCast(model,{kind="Counter",start=data.start})
    local floor=groundAt(root.Position)
    for i=1,8 do
        local a=i/8*math.pi*2
        VFX.dust(floor+Vector3.new(math.cos(a),.4,math.sin(a))*1.2,1.2,Vector3.new(math.cos(a),.2,math.sin(a))*3,.7,nil,.6)
    end
    VFX.sound("Laugh",root.Position,.55,2)
end
function VFX.counterRead(model,data)
    local c=model and casts[model]
    if c and c.kind=="Counter" then c.read=data.start end
    local root=rootOf(model);if not root then return end
    local at=root.Position:Lerp(data.position,.5)+Vector3.yAxis*1.2
    for _=1,10 do
        local d=Vector3.new(math.random()-.5,math.random()-.3,math.random()-.5).Unit
        VFX.streak(at,d,.5,22,.18,COLORS.White,.05)
    end
    VFX.flash(at,4,10,.15)
    VFX.sound("Parry",at,.9,2)
end
function VFX.counterHit(data)
    local at=data.position+Vector3.yAxis*1.4
    local dir=data.direction or Vector3.zAxis
    if data.landed then
        VFX.shockRing(at,dir+Vector3.yAxis*.8,6,.35,.35,24)
        VFX.shockRing(at,dir+Vector3.yAxis*.8,3.5,.25,.25,18,.05)
        VFX.pressure(at,3,.3,.3)
        VFX.flash(at,6,16,.2)
        for _=1,8 do VFX.streak(at,(Vector3.yAxis+dir*.6+Vector3.new(math.random()-.5,0,math.random()-.5)).Unit,1.2,30,.25) end
        VFX.sound("Heavy",at,1,2)
    else
        VFX.sound("Swing",at,.7,1.5)
    end
end
function VFX.counterEnd(model) local c=model and casts[model];if c and c.kind=="Counter" then c.ended=c.ended or clock() end
    task.delay(.35,function() VFX.clearCast(model,"Counter") end)
end
function VFX.counterBlock(model,from)
    local root=rootOf(model);if not root then return end
    local at=root.Position+(Vector3.new(from.X,root.Position.Y,from.Z)-root.Position).Unit*1.4+Vector3.yAxis*1.2
    for _=1,5 do VFX.streak(at,Vector3.new(math.random()-.5,math.random()-.5,math.random()-.5).Unit,.35,14,.15,COLORS.White,.04) end
    VFX.sound("Punch",at,.5,1,1.4)
end
function VFX.rushStart(model,data)
    local root=rootOf(model);if not root then return end
    VFX.setCast(model,{kind="Rush",start=data.start})
    local floor=groundAt(root.Position)
    for i=1,6 do VFX.dust(floor+Vector3.new(math.random()-.5,.4,math.random()-.5)*2,1.4,-data.direction*2+Vector3.yAxis,.6) end
end
function VFX.rushDash(model,data)
    if not model then return end
    VFX.sound("Dash",data.from,.8,1.5)
    local last=0
    run(Y.OgreRush.DashEnd-Y.OgreRush.Crouch,function(age)
        if age-last<.05 then return end
        last=age
        VFX.afterimage(model,.25)
        local root=rootOf(model)
        if root then
            local floor=groundAt(root.Position)
            VFX.dust(floor+Vector3.yAxis*.5,1.3,-data.direction*4+Vector3.yAxis*1.2,.5)
        end
    end,nil,data.start)
end
function VFX.rushHit(data)
    local at=data.position;local dir=data.direction
    if data.index==1 then
        VFX.pressure(at,1.6,.2,.4);VFX.dust(at,1,dir*2,.3,COLORS.White,.5)
        VFX.sound("Punch",at,.9,1.5,.9)
    elseif data.index==2 then
        local head=at+Vector3.yAxis*1.5
        VFX.shockRing(head,dir:Cross(Vector3.yAxis),4.5,.3,.3,22)
        VFX.pressure(head,2.4,.25,.35)
        for _=1,6 do VFX.streak(head,(dir:Cross(Vector3.yAxis)*-1+Vector3.new(0,math.random()-.5,math.random()-.5)*.6).Unit,1,24,.2) end
        VFX.sound("Heavy",head,.9,1.5,1.2)
    else
        VFX.cracks(at,6,9,3)
        VFX.dustRing(at,6,12,1,4)
        VFX.shockRing(groundAt(at)+Vector3.yAxis*.3,Vector3.yAxis,7,.4,.4,26)
        VFX.sound("Heavy",at,1,2,.8)
    end
end
function VFX.rushEnd(model) task.delay(.2,function() VFX.clearCast(model,"Rush") end) end
function VFX.judgment(model,data)
    local root=rootOf(model);if not root then return end
    local cfg=Y.OgreJudgment
    VFX.setCast(model,{kind="Judgment",start=data.start})
    VFX.demonBack(model,data.start+cfg.Serious,data.start+cfg.End)
    VFX.sound("Heartbeat",root.Position,.8,2)
    task.delay(math.max(0,data.start+.25-clock()),function() if root.Parent then VFX.sound("Laugh",root.Position,.7,2,.85) end end)
    -- .5: the back opens with a low boom and a radial push of dust along the floor (no energy blast).
    task.delay(math.max(0,data.start+cfg.Serious-clock()),function()
        if not root.Parent then return end
        local floor=groundAt(root.Position)
        VFX.sound("Boom",root.Position,.9,3,.8)
        for i=1,20 do
            local a=i/20*math.pi*2
            local d=Vector3.new(math.cos(a),0,math.sin(a))
            VFX.dust(floor+d*1.5+Vector3.yAxis*.4,1.6+math.random(),d*14+Vector3.yAxis*.6,.9,nil,.5)
        end
        VFX.shockRing(floor+Vector3.yAxis*.25,Vector3.yAxis,14,.6,.25,30,0,COLORS.Dust)
    end)
end
function VFX.judgmentCapture(model,data)
    local c=model and casts[model];if c and c.kind=="Judgment" then c.captured=true end
    local last=0
    run(Y.OgreJudgment.DashEnd-Y.OgreJudgment.Capture,function(age)
        if age-last<.06 then return end
        last=age;VFX.afterimage(model,.22)
    end,nil,data.start+Y.OgreJudgment.Capture)
end
function VFX.judgmentHit(data)
    local at=data.position;local dir=data.direction or Vector3.zAxis
    if data.final then
        local ground=data.ground or groundAt(at)
        VFX.flash(ground+Vector3.yAxis*2,9,40,.35)
        VFX.shockRing(at+Vector3.yAxis*.5,dir,8,.35,.5,30)
        VFX.shockRing(ground+Vector3.yAxis*.3,Vector3.yAxis,18,.7,.6,36,.03)
        VFX.pressure(ground+Vector3.yAxis*1,7,.45,.25)
        VFX.cracks(ground,16,16,6)
        VFX.dustRing(ground,14,24,1.8,16)
        VFX.sound("Boom",ground,1,4,.7);VFX.sound("Heavy",ground,1,3,.6)
    elseif data.name=="Body" then
        VFX.pressure(at,1.8,.22,.4);VFX.sound("Punch",at,1,1.5,.85)
    elseif data.name=="Slap" then
        VFX.shockRing(at+Vector3.yAxis*1.5,dir:Cross(Vector3.yAxis),3.5,.25,.25,20);VFX.sound("Slap",at,1,1.5)
    else
        VFX.pressure(at+Vector3.yAxis*.8,1.2,.15,.45);VFX.sound("Punch",at,.8,1,1.1+math.random()*.2)
    end
end
function VFX.judgmentEnd(model,early)
    if early then VFX.closeDemon(model) end
    task.delay(.3,function() VFX.clearCast(model,"Judgment") end)
end

RunService.RenderStepped:Connect(function(dt)
    local n=clock()
    for i=#active,1,-1 do
        local e=active[i];local age=n-e.start
        if age>e.duration or e.dead then
            table.remove(active,i)
            if e.cleanup then local ok,err=pcall(e.cleanup);if not ok then warn("YujiroVFX cleanup",err) end end
        elseif age>=0 then
            local ok,err=pcall(e.update,age,dt);if not ok then warn("YujiroVFX",err);e.dead=true end
        end
    end
    local ok,err=pcall(applyPoses,dt);if not ok then warn("YujiroVFX poses",err) end
    for model in demons do if not model.Parent then VFX.closeDemon(model) end end
end)
VFX.modelOf=modelOf
return VFX
