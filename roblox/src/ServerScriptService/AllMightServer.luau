-- All Might: server-side judgement for One For All: Full Power (Q), United States of Smash (E) and Plus Ultra (R).
-- Required by Combat.server.luau, which owns the shared player state (cooldowns, busy time, generation) and
-- passes its helpers in through AllMight.init. Clients only send the key and their camera ray; targets, damage,
-- dashes, captures, launches, cooldowns and the buff are all decided here, from server positions.
-- Every character this module moves (the caster during a dash or the Plus Ultra jump, every victim) is moved by a
-- server-created constraint or, for anchored training targets, kinematically; every step is blockcast first.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local A=require(RS:WaitForChild("AllMightConfig"))

local AllMight={}
local ctx
local KIT={};for _,skill in A.Kit do KIT[skill]=true end
local movers={}       -- [victim model] = forced movement in progress
local drives={}       -- [caster player] = constraint moving the caster
local buffs={}        -- [caster player] = token of the current One For All
local smashes={}      -- [caster player] = United States of Smash in progress
local ultras={}       -- [caster player] = Plus Ultra in progress

local function smoothstep(x) x=math.clamp(x,0,1);return x*x*(3-2*x) end
local function easeOut(x,power) x=math.clamp(x,0,1);return 1-(1-x)^(power or 2) end
local function flat(v,fallback)
    local f=Vector3.new(v.X,0,v.Z)
    return f.Magnitude>.05 and f.Unit or fallback or Vector3.new(0,0,-1)
end
local function alive(t) return t and t.m.Parent and t.r.Parent and t.h.Parent and t.h.Health>0 end
-- World geometry only: every character is excluded and non-collidable parts are ignored.
local function worldParams(extra)
    local list={}
    for _,t in ctx.targets(nil) do table.insert(list,t.m) end
    for _,p in Players:GetPlayers() do if p.Character then table.insert(list,p.Character) end end
    if extra then for _,v in extra do table.insert(list,v) end end
    local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances=list;params.RespectCanCollide=true
    return params
end
local function groundBelow(position,params)
    local hit=workspace:Raycast(position+Vector3.yAxis*4,Vector3.yAxis*-200,params)
    return hit and hit.Position or nil
end
local function hipOf(t,params)
    local floor=groundBelow(t.r.Position,params)
    return floor and math.clamp(t.r.Position.Y-floor.Y,1.5,6) or 3
end
local function stillCaster(p,s,m)
    return ctx.states[p]==s and ctx.character(p)==m and s.amGeneration==s.generation and ctx.kitOf(p)=="AllMight"
end
local function buffed(m) return m~=nil and (m:GetAttribute("AllMightBuffUntil") or 0)>ctx.clock() end
-- Caster speed factor for a while; Combat.updateSpeed reads it every Heartbeat.
local function slowSelf(m,h,factor,duration)
    m:SetAttribute("AllMightSpeedFactor",factor);m:SetAttribute("AllMightSpeedUntil",ctx.clock()+duration);ctx.updateSpeed(m,h)
    task.delay(duration+.05,function() if m.Parent and h.Parent then ctx.updateSpeed(m,h) end end)
end
-- Line of sight from the caster's chest to a body, ignoring every character.
local function visible(from,t,params)
    local hit=workspace:Raycast(from,t.r.Position-from,params)
    return not hit
end
-- First valid body in a corridor ahead of `origin`: in front, within `reach`, `width` to the side, in sight.
local function firstAhead(m,origin,direction,reach,width,params,skip)
    local best,bestAlong=nil,math.huge
    for _,t in ctx.targets(m) do
        if not (skip and skip[t.m]) then
            local rel=t.r.Position-origin
            local along=rel:Dot(direction)
            local side=Vector3.new(rel.X,0,rel.Z)-direction*along
            if along>-1 and along<=reach and side.Magnitude<=width and math.abs(rel.Y)<8 and along<bestAlong and visible(origin,t,params) then
                best=t;bestAlong=along
            end
        end
    end
    return best,bestAlong
end

---------------------------------------------------------------- moving the caster
-- A server-created AlignPosition that the caster's own client simulates; released as soon as the move ends.
local function driveCaster(p,r)
    local d=drives[p]
    if d and d.align.Parent and d.root==r then return d end
    if d then d.align:Destroy();d.attachment:Destroy() end
    local attachment=Instance.new("Attachment");attachment.Name="AllMightDriveAttachment";attachment.Parent=r
    local align=Instance.new("AlignPosition");align.Name="AllMightDrive";align.Mode=Enum.PositionAlignmentMode.OneAttachment
    align.Attachment0=attachment;align.Position=r.Position;align.ApplyAtCenterOfMass=true;align.RigidityEnabled=false
    align.MaxForce=math.max(30000,r.AssemblyMass*workspace.Gravity*30);align.MaxVelocity=320;align.Responsiveness=90
    align.Parent=r
    d={align=align,attachment=attachment,root=r,last=r.Position}
    drives[p]=d
    return d
end
local function releaseCaster(p)
    local d=drives[p];if not d then return end
    drives[p]=nil
    d.align:Destroy();d.attachment:Destroy()
    -- Hand the momentum back gently: never leave the caster flying sideways after a dash.
    if d.root.Parent then
        local v=d.root.AssemblyLinearVelocity
        d.root.AssemblyLinearVelocity=Vector3.new(v.X*.15,math.min(v.Y,0),v.Z*.15)
    end
end
-- Moves the caster toward `desired`, stopping short of walls; returns the reached point and the wall hit.
local function moveCaster(p,r,desired,params)
    local d=driveCaster(p,r)
    local from=d.last
    local step=desired-from
    local hit=nil
    if step.Magnitude>.001 then
        hit=workspace:Blockcast(CFrame.new(from),Vector3.new(2.6,4.2,2.6),step,params)
        if hit then desired=from+step.Unit*math.max(0,hit.Distance-.15) end
    end
    d.align.Position=desired;d.last=desired
    return desired,hit
end

---------------------------------------------------------------- moving victims
local function releaseMover(model,keepHeld)
    local mv=movers[model];if not mv then return end
    movers[model]=nil
    if mv.align then mv.align:Destroy() end
    if mv.attachment then mv.attachment:Destroy() end
    if model.Parent and not keepHeld then model:SetAttribute("AllMightHeldUntil",0) end
    if mv.t.r.Parent and mv.t.r.Anchored and mv.rotation then mv.t.r.CFrame=CFrame.new(mv.t.r.Position)*mv.rotation end
end
local function guarded(model)
    local n=ctx.clock()
    return (model:GetAttribute("AllMightGuardUntil") or 0)>n or (model:GetAttribute("PainGuardUntil") or 0)>n or (model:GetAttribute("ItachiGuardUntil") or 0)>n
end
local function startMover(t,owner,spec)
    if not alive(t) or guarded(t.m) then return end
    -- One For All shrugs off light pushes (the E shockwave on bystanders).
    if spec.light and buffed(t.m) then return end
    local old=movers[t.m]
    local rotation=old and old.rotation or t.r.CFrame.Rotation
    if old then releaseMover(t.m,true) end
    ctx.flights[t.m]=nil;ctx.doraKnockbacks[t.m]=nil
    local mv={t=t,owner=owner,start=ctx.clock(),last=t.r.Position,rotation=rotation,params=worldParams({owner and owner.Character})}
    for k,v in spec do mv[k]=v end
    if not t.r.Anchored then
        local attachment=Instance.new("Attachment");attachment.Name="AllMightForceAttachment";attachment.Parent=t.r
        local align=Instance.new("AlignPosition");align.Name="AllMightForce";align.Mode=Enum.PositionAlignmentMode.OneAttachment
        align.Attachment0=attachment;align.Position=t.r.Position;align.ApplyAtCenterOfMass=true;align.RigidityEnabled=false
        align.MaxForce=math.max(25000,t.r.AssemblyMass*workspace.Gravity*25);align.MaxVelocity=420;align.Responsiveness=70
        align.Parent=t.r
        mv.attachment=attachment;mv.align=align
        pcall(function() if not Players:GetPlayerFromCharacter(t.m) then t.r:SetNetworkOwner(nil) end end)
    end
    movers[t.m]=mv
    return mv
end
-- Moves a body toward `desired`; `lean` bends anchored targets (direction faced, pitch of the torso).
local function drive(mv,desired,lean)
    local t=mv.t
    local from=t.r.Anchored and mv.last or t.r.Position
    local step=desired-from
    local hit=nil
    if step.Magnitude>.001 and not mv.free then
        hit=workspace:Blockcast(CFrame.new(from),Vector3.new(1.8,2.6,1.8),step,mv.params)
        if hit then desired=from+step.Unit*math.max(0,hit.Distance-.1) end
    end
    if t.r.Anchored then
        local rotation=mv.rotation
        if lean then rotation=CFrame.lookAt(Vector3.zero,lean.direction).Rotation*CFrame.Angles(lean.pitch,0,lean.roll or 0) end
        t.m:PivotTo(CFrame.new(desired)*rotation)
    elseif mv.align then
        mv.align.Position=desired
    end
    mv.last=desired
    return desired,hit
end
local function hold(t,untilTime) if t.m.Parent then t.m:SetAttribute("AllMightHeldUntil",untilTime) end end
-- A knock arc that never ends past the arena edge, shortened until there is floor under the landing point.
local function knock(owner,t,direction,distance,lift,duration,wallDamage,light)
    local params=worldParams({owner and owner.Character})
    local from=t.r.Position
    while distance>2 and not groundBelow(from+direction*distance,params) do distance-=2 end
    local mv=startMover(t,owner,{kind="Knock",from=from,direction=direction,distance=distance,lift=lift,duration=duration,hip=hipOf(t,params),wallDamage=wallDamage,light=light})
    if not mv then return end
    hold(t,ctx.clock()+duration+.1)
    ctx.fx:FireAllClients("AllMightKnock",{model=t.m,from=from,direction=direction,distance=distance,duration=duration,heavy=not light})
    return mv
end
-- Drops a body straight onto the floor below it (or below `fallback`), then keeps it down for a moment.
local function dropToFloor(t,owner,fallback,down)
    local params=worldParams({owner and owner.Character})
    local floor=groundBelow(t.r.Position,params) or (fallback and groundBelow(fallback,params)) or fallback
    if not floor then releaseMover(t.m);return end
    local hip=movers[t.m] and movers[t.m].hip or hipOf(t,params)
    local height=math.max(1,t.r.Position.Y-floor.Y)
    local duration=math.max(A.PlusUltra.FallMin,math.sqrt(2*height/workspace.Gravity)+.1)
    local mv=startMover(t,nil,{kind="Fall",from=t.r.Position,to=floor+Vector3.yAxis*hip,duration=duration,hip=hip,free=true})
    if mv then hold(t,ctx.clock()+duration+(down or 0)) else releaseMover(t.m) end
    return duration
end

---------------------------------------------------------------- Q: One For All: Full Power
local function powerOff(p,m,h,reason,fatigue)
    buffs[p]=nil
    if m and m.Parent then
        m:SetAttribute("AllMightBuffUntil",0)
        if fatigue and h and h.Parent and h.Health>0 then slowSelf(m,h,A.OneForAll.FatigueFactor,A.OneForAll.FatigueDuration) end
        if h and h.Parent then ctx.updateSpeed(m,h) end
    end
    ctx.fx:FireAllClients("AllMightPowerOff",{owner=p.UserId,reason=reason,fatigue=fatigue and A.OneForAll.FatigueDuration or 0})
end
local function oneForAll(p,s,m,h,r)
    local cfg=A.OneForAll;local n=ctx.clock()
    s.cooldowns.OneForAll=n+cfg.Cooldown
    s.busyUntil=n+cfg.Prep
    m:SetAttribute("AllMightNoJumpUntil",n+cfg.Prep)
    slowSelf(m,h,cfg.PrepSpeed,cfg.Prep)
    local token={}
    buffs[p]=token
    ctx.fx:FireAllClients("AllMightPowerCast",{owner=p.UserId,start=n,prep=cfg.Prep,open=cfg.Open,position=r.Position})
    task.delay(cfg.Prep,function()
        if buffs[p]~=token then return end
        if not stillCaster(p,s,m) then buffs[p]=nil;return end
        local on=ctx.clock()
        m:SetAttribute("AllMightBuffUntil",on+cfg.Duration);ctx.updateSpeed(m,h)
        ctx.fx:FireAllClients("AllMightPowerOn",{owner=p.UserId,start=on,untilTime=on+cfg.Duration,position=r.Position})
        task.delay(cfg.Duration,function()
            if buffs[p]~=token then return end
            if stillCaster(p,s,m) then powerOff(p,m,h,"expired",true) else buffs[p]=nil end
        end)
    end)
end

---------------------------------------------------------------- E: United States of Smash
local function endSmash(p,reason)
    local e=smashes[p];if not e then return end
    smashes[p]=nil
    releaseCaster(p)
    if e.target and movers[e.target.m] and movers[e.target.m].kind=="Hold" then releaseMover(e.target.m) end
    if reason~="finished" then ctx.fx:FireAllClients("AllMightSmashEnd",{owner=p.UserId,reason=reason}) end
end
local function smash(p,s,m,h,r,aim)
    local cfg=A.UnitedStatesOfSmash;local n=ctx.clock()
    local direction=flat(aim,flat(r.CFrame.LookVector))
    s.cooldowns.UnitedStatesOfSmash=n+cfg.Cooldown
    s.busyUntil=n+cfg.PunchEnd+cfg.Hold+cfg.Return
    m:SetAttribute("AllMightNoJumpUntil",n+cfg.PunchEnd+cfg.Hold)
    slowSelf(m,h,0,cfg.Crouch)
    local e={owner=p,state=s,model=m,humanoid=h,root=r,start=n,direction=direction,params=worldParams({m}),hit={}}
    smashes[p]=e
    ctx.fx:FireAllClients("AllMightSmashCast",{owner=p.UserId,start=n,direction=direction,position=r.Position,buffed=buffed(m)})
end
local function smashImpact(p,e,n)
    local cfg=A.UnitedStatesOfSmash
    local m,r=e.model,e.root
    e.impactAt=n
    releaseCaster(p)
    local t=e.target
    local factor=buffed(m) and A.OneForAll.SmashDamage or 1
    if t and alive(t) and (t.r.Position-r.Position).Magnitude<=cfg.ContactReach+cfg.StopDistance+3 then
        local point=t.r.Position
        if movers[t.m] and movers[t.m].kind=="Hold" then releaseMover(t.m,true) end
        e.hit[t.m]=true
        ctx.damage(p,t,cfg.Damage*factor,"Melee")
        local direction=flat(t.r.Position-r.Position,e.direction)
        if alive(t) then knock(p,t,direction,cfg.Knockback,cfg.KnockLift,cfg.KnockTime,cfg.WallDamage) end
        -- The shockwave: everyone else near the point of impact, once each, pushed away from it.
        for _,other in ctx.targets(m) do
            if not e.hit[other.m] and (other.r.Position-point).Magnitude<=cfg.ShockRadius then
                e.hit[other.m]=true
                ctx.damage(p,other,cfg.ShockDamage*factor,"Shockwave")
                if alive(other) then knock(p,other,flat(other.r.Position-point,direction),cfg.ShockKnock,2.5,.35,nil,true) end
            end
        end
        ctx.fx:FireAllClients("AllMightSmashImpact",{owner=p.UserId,start=n,hit=true,target=t.m,position=point,direction=direction,
            buffed=factor>1,radius=cfg.ShockRadius})
    else
        e.target=nil
        ctx.fx:FireAllClients("AllMightSmashImpact",{owner=p.UserId,start=n,hit=false,position=r.Position+e.direction*4,direction=e.direction,
            buffed=factor>1,radius=cfg.ShockRadius*.6})
    end
end
local function stepSmash(p,e,n)
    local cfg=A.UnitedStatesOfSmash
    local s,m,r=e.state,e.model,e.root
    if not stillCaster(p,s,m) then endSmash(p,"interrupted");return end
    local age=n-e.start
    if age<cfg.Crouch then return end
    if age<cfg.DashEnd and not e.contact and not e.whiff then
        if not e.from then
            e.from=r.Position;driveCaster(p,r).last=r.Position
            ctx.fx:FireAllClients("AllMightSmashDash",{owner=p.UserId,start=n,from=e.from,direction=e.direction,distance=cfg.DashDistance})
        end
        local u=(age-cfg.Crouch)/(cfg.DashEnd-cfg.Crouch)
        local desired=e.from+e.direction*cfg.DashDistance*easeOut(u,1.7)
        local reached,wall=moveCaster(p,r,desired,e.params)
        local t=firstAhead(m,reached+Vector3.yAxis*.5,e.direction,cfg.ContactReach,cfg.PathWidth,e.params)
        if t then
            e.contact=n;e.target=t
            local stop=Vector3.new(t.r.Position.X,reached.Y,t.r.Position.Z)-e.direction*cfg.StopDistance
            local blocked=workspace:Blockcast(CFrame.new(reached),Vector3.new(2.6,4.2,2.6),stop-reached,e.params)
            e.stop=blocked and reached or stop
            moveCaster(p,r,e.stop,e.params)
            local mv=startMover(t,p,{kind="Hold"})
            if mv then hold(t,e.start+cfg.Impact+.15) end
            ctx.fx:FireAllClients("AllMightSmashContact",{owner=p.UserId,start=n,target=t.m,position=t.r.Position})
        elseif wall and (reached-e.from).Magnitude<cfg.DashDistance-1 then
            -- A wall cuts the dash short: a heavy bump, no punch, a shorter cooldown.
            releaseCaster(p)
            s.cooldowns.UnitedStatesOfSmash=n+cfg.BumpCooldown
            s.busyUntil=n+.45;m:SetAttribute("AllMightNoJumpUntil",n+.45)
            slowSelf(m,e.humanoid,.6,.5)
            smashes[p]=nil
            ctx.fx:FireAllClients("AllMightSmashBump",{owner=p.UserId,start=n,position=reached+e.direction*1.3,normal=wall.Normal})
            ctx.sendState(p,s)
        end
        return
    end
    if not e.contact and not e.whiff then
        -- Nobody on the path: the punch still lands on empty air, and the cooldown is halved.
        e.whiff=true;releaseCaster(p)
        s.cooldowns.UnitedStatesOfSmash=e.start+cfg.WhiffCooldown;ctx.sendState(p,s)
    end
    if e.contact and not e.impactAt then
        if e.stop then moveCaster(p,r,e.stop,e.params) end
        if e.target and not alive(e.target) then e.target=nil end
    end
    if age>=cfg.Impact and not e.impactAt then smashImpact(p,e,n) end
    if age>=cfg.PunchEnd+cfg.Hold+cfg.Return and not e.slowed then
        e.slowed=true
        slowSelf(m,e.humanoid,cfg.SlowFactor,cfg.SlowDuration)
        smashes[p]=nil
    end
end

---------------------------------------------------------------- R: Plus Ultra
local function endUltra(p,reason)
    local u=ultras[p];if not u then return end
    ultras[p]=nil
    releaseCaster(p)
    local t=u.target
    if t and movers[t.m] and movers[t.m].kind=="Ultra" then
        -- Never leave the target hanging: it falls to the floor below (or back where the fight started).
        if alive(t) then dropToFloor(t,nil,u.base,A.PlusUltra.KnockedDown) else releaseMover(t.m) end
    end
    if u.model.Parent then u.model:SetAttribute("AllMightGuardUntil",0);u.model:SetAttribute("AllMightNoJumpUntil",0) end
    if u.humanoid.Parent then ctx.updateSpeed(u.model,u.humanoid) end
    ctx.fx:FireAllClients("AllMightUltraEnd",{owner=p.UserId,reason=reason})
end
local function plusUltra(p,s,m,h,r,aim)
    local cfg=A.PlusUltra;local n=ctx.clock()
    local direction=flat(aim,flat(r.CFrame.LookVector))
    local total=cfg.Windup+cfg.DashTime+cfg.End+.2
    s.cooldowns.PlusUltra=n+cfg.Cooldown
    s.busyUntil=n+total
    m:SetAttribute("AllMightGuardUntil",n+total)
    m:SetAttribute("AllMightNoJumpUntil",n+total)
    slowSelf(m,h,cfg.WindupSpeed,cfg.Windup)
    local u={owner=p,state=s,model=m,humanoid=h,root=r,start=n,direction=direction,params=worldParams({m}),hit={},damaged={}}
    if ultras[p] then endUltra(p,"replaced") end
    ultras[p]=u
    ctx.fx:FireAllClients("AllMightUltraCast",{owner=p.UserId,start=n,direction=direction,position=r.Position,buffed=buffed(m)})
end
local function ultraFail(p,u,n,position)
    local s=u.state
    ultras[p]=nil
    releaseCaster(p)
    s.cooldowns.PlusUltra=u.start+A.PlusUltra.FailCooldown
    s.busyUntil=n+.6
    if u.model.Parent then u.model:SetAttribute("AllMightGuardUntil",0);u.model:SetAttribute("AllMightNoJumpUntil",n+.6) end
    slowSelf(u.model,u.humanoid,.5,.6)
    ctx.fx:FireAllClients("AllMightUltraFail",{owner=p.UserId,start=n,position=position,direction=u.direction})
    ctx.sendState(p,s)
end
-- Where the caster and the target should be `c` seconds after contact.
local function ultraPose(u,c)
    local cfg=A.PlusUltra
    local d=u.direction
    local base=u.base                 -- caster's floor point at contact
    local hip=u.casterHip
    local caster,target
    local lift=easeOut((c-cfg.Punch1)/(cfg.Lift-cfg.Punch1),2)
    local chase=easeOut((c-cfg.Lift)/(cfg.ChaseEnd-cfg.Lift),2.2)
    local hang=math.clamp((c-cfg.ChaseEnd)/(cfg.Uppercut-cfg.ChaseEnd),0,1)
    -- Caster: planted, then a jump that follows the target up, a hang while winding up, the uppercut's own lift,
    -- and a fall back onto the floor.
    local up=cfg.CasterChase*chase+.8*hang
    if c>=cfg.Uppercut then
        local rise=easeOut((c-cfg.Uppercut)/.18,2)*2.2
        local fall=math.clamp((c-cfg.Uppercut-.22)/(cfg.LandAt-cfg.Uppercut-.22),0,1)
        up=(cfg.CasterChase+.8+rise)*(1-fall*fall)
    end
    caster=base+d*(2.2*chase)+Vector3.yAxis*(hip+up)
    -- Target: lifted by the first punch, carried ahead of and above the caster, then launched.
    local tUp=cfg.LiftHeight*lift+(cfg.ChaseHeight-cfg.LiftHeight)*chase+1.2*hang
    target=u.contactPoint+d*(2.6*lift+1.6*chase)+Vector3.yAxis*tUp
    if c>=cfg.Launch then
        local k=math.clamp((c-cfg.Launch)/(cfg.Apex-cfg.Launch),0,1)
        local from=u.launchFrom or target
        target=from+d*7*k+Vector3.yAxis*(u.apexRise or 100)*k*k
    end
    return caster,target
end
local function ultraShock(p,u,center,n)
    local cfg=A.PlusUltra
    for _,t in ctx.targets(u.model) do
        if t.m~=(u.target and u.target.m) and not u.hit[t.m] then
            local d=t.r.Position-center
            if Vector3.new(d.X,0,d.Z).Magnitude<=cfg.ShockRadius and math.abs(d.Y)<=cfg.ShockHeight then
                u.hit[t.m]=true
                ctx.damage(p,t,cfg.ShockDamage,"Shockwave")
                if alive(t) then ctx.launch(t,flat(d,u.direction)*42+Vector3.yAxis*26) end
            end
        end
    end
end
local function stepUltra(p,u,n)
    local cfg=A.PlusUltra
    local s,m,r=u.state,u.model,u.root
    if not stillCaster(p,s,m) then endUltra(p,"interrupted");return end
    local age=n-u.start
    if age<cfg.Windup then return end
    -- Dash: the first body on the path becomes the target. An empty path is known at launch and stops short.
    if not u.contact then
        if not u.from then
            u.from=r.Position;driveCaster(p,r).last=r.Position
            local floor=groundBelow(r.Position,u.params)
            u.casterHip=floor and math.clamp(r.Position.Y-floor.Y,1.5,6) or 3
            local any=firstAhead(m,r.Position+Vector3.yAxis*.5,u.direction,cfg.DashDistance+cfg.ContactReach,cfg.PathWidth,u.params)
            u.empty=any==nil
            u.limit=u.empty and cfg.DashDistance*cfg.FailDistance or cfg.DashDistance
            ctx.fx:FireAllClients("AllMightUltraDash",{owner=p.UserId,start=n,from=u.from,direction=u.direction,distance=u.limit,empty=u.empty})
        end
        local k=math.clamp((age-cfg.Windup)/cfg.DashTime,0,1)
        local along=u.empty and u.limit*easeOut(k,2.4) or u.limit*easeOut(k,1.5)
        local reached,wall=moveCaster(p,r,u.from+u.direction*along,u.params)
        local t=not u.empty and firstAhead(m,reached+Vector3.yAxis*.5,u.direction,cfg.ContactReach,cfg.PathWidth,u.params) or nil
        if t then
            u.contact=n;u.target=t
            local stop=Vector3.new(t.r.Position.X,reached.Y,t.r.Position.Z)-u.direction*cfg.StopDistance
            local blocked=workspace:Blockcast(CFrame.new(reached),Vector3.new(2.6,4.2,2.6),stop-reached,u.params)
            stop=blocked and reached or stop
            local floor=groundBelow(stop,u.params)
            u.base=floor or stop-Vector3.yAxis*u.casterHip
            u.contactPoint=t.r.Position
            u.targetHip=hipOf(t,u.params)
            -- Leave room for the launch under any roof: the apex never pokes through the ceiling.
            local roof=workspace:Raycast(t.r.Position+Vector3.yAxis*3,Vector3.yAxis*(cfg.ChaseHeight+cfg.ApexHeight),u.params)
            u.roof=roof and roof.Position.Y or nil
            local mv=startMover(t,p,{kind="Ultra",free=false})
            if not mv then ultraFail(p,u,n,reached);return end
            hold(t,n+.3)
            s.busyUntil=n+cfg.End+.05
            m:SetAttribute("AllMightGuardUntil",n+cfg.End);m:SetAttribute("AllMightNoJumpUntil",n+cfg.End)
            ctx.fx:FireAllClients("AllMightUltraContact",{owner=p.UserId,start=n,target=t.m,position=t.r.Position,direction=u.direction})
            ctx.sendState(p,s)
        elseif k>=1 or (wall and (reached-u.from).Magnitude<u.limit-1) then
            ultraFail(p,u,n,reached)
        end
        return
    end
    local c=n-u.contact
    local t=u.target
    if not alive(t) then
        -- The target died (or left): drop safely back to the floor and finish early.
        u.target=nil
        ctx.fx:FireAllClients("AllMightUltraLost",{owner=p.UserId,start=n})
        -- Let go of the caster too: an airborne caster simply falls under gravity.
        endUltra(p,"lost")
        return
    end
    -- Hits, once each.
    if c>=cfg.Punch1 and not u.damaged[1] then
        u.damaged[1]=true;ctx.damage(p,t,cfg.Damage1,"Ultimate")
        ctx.fx:FireAllClients("AllMightUltraPunch",{owner=p.UserId,start=n,index=1,target=t.m,position=t.r.Position,direction=u.direction})
    end
    if c>=cfg.Punch2 and not u.damaged[2] then
        u.damaged[2]=true;ctx.damage(p,t,cfg.Damage2,"Ultimate")
        ctx.fx:FireAllClients("AllMightUltraPunch",{owner=p.UserId,start=n,index=2,target=t.m,position=t.r.Position,direction=u.direction})
    end
    if c>=cfg.Uppercut and not u.damaged[3] then
        u.damaged[3]=true
        u.launchFrom=t.r.Anchored and (movers[t.m] and movers[t.m].last) or t.r.Position
        local ceiling=u.roof and (u.roof-6-u.launchFrom.Y) or cfg.ApexHeight
        u.apexRise=math.clamp(math.min(cfg.ApexHeight,ceiling),8,cfg.ApexHeight)
        ctx.damage(p,t,cfg.Damage3,"Ultimate")
        ultraShock(p,u,Vector3.new(r.Position.X,u.base.Y,r.Position.Z),n)
        ctx.fx:FireAllClients("AllMightUltraUppercut",{owner=p.UserId,start=n,target=t.m,position=u.launchFrom,ground=u.base,
            direction=u.direction,apex=u.launchFrom+u.direction*7+Vector3.yAxis*u.apexRise,launch=cfg.Apex-cfg.Launch,radius=cfg.ShockRadius})
        if not alive(t) then return end
    end
    local casterAt,targetAt=ultraPose(u,c)
    if c<cfg.LandAt then moveCaster(p,r,casterAt,u.params)
    elseif not u.landed then
        u.landed=true;releaseCaster(p)
        ctx.fx:FireAllClients("AllMightUltraLand",{owner=p.UserId,start=n,position=u.base})
    end
    local mv=movers[t.m]
    if c<cfg.Apex then
        if not mv or mv.kind~="Ultra" then endUltra(p,"resisted");return end
        hold(t,n+.3)
        -- The body bends: arched back after the first punch, folded up around the uppercut.
        local pitch=c<cfg.Uppercut and -.9*smoothstep((c-cfg.Punch1)/.2) or .9-1.6*smoothstep((c-cfg.Uppercut)/.3)
        mv.free=c>=cfg.Launch
        drive(mv,targetAt,{direction=-u.direction,pitch=pitch,roll=c>=cfg.Launch and math.sin(c*14)*.5 or 0})
    elseif not u.released then
        -- The last ring bursts at the apex; from there the body falls back onto safe ground under its own weight.
        u.released=true
        ctx.fx:FireAllClients("AllMightUltraApex",{owner=p.UserId,start=n,position=mv and mv.last or t.r.Position})
        releaseMover(t.m,true)
        dropToFloor(t,nil,u.base,cfg.KnockedDown)
    end
    if c>=cfg.End then
        ultras[p]=nil
        if m.Parent then m:SetAttribute("AllMightGuardUntil",0);m:SetAttribute("AllMightNoJumpUntil",0) end
        ctx.updateSpeed(m,u.humanoid)
        ctx.fx:FireAllClients("AllMightUltraEnd",{owner=p.UserId,reason="finished"})
    end
end

---------------------------------------------------------------- per-frame movement
local function stepMover(model,mv,n)
    local t=mv.t
    if not alive(t) then releaseMover(model);return end
    local age=n-mv.start
    if mv.kind=="Knock" then
        local u=math.clamp(age/mv.duration,0,1)
        local along=1-(1-u)^2.4
        local height=mv.lift*4*u*(1-u)
        local desired=mv.from+mv.direction*mv.distance*along+Vector3.yAxis*height
        local _,hit=drive(mv,desired,{direction=-mv.direction,pitch=(mv.light and -.3 or -.75)*math.sin(u*math.pi)})
        if hit and not mv.walled then
            mv.walled=true
            if mv.wallDamage and mv.owner then ctx.damage(mv.owner,t,mv.wallDamage,"Environment") end
            ctx.fx:FireAllClients("AllMightWallHit",{position=mv.last,normal=hit.Normal})
            local floor=groundBelow(mv.last,mv.params)
            mv.kind="Fall";mv.start=n;mv.from=mv.last;mv.to=floor and floor+Vector3.yAxis*mv.hip or mv.last;mv.duration=.25
            hold(t,n+.45)
            return
        end
        if u>=1 then releaseMover(model,true) end
    elseif mv.kind=="Fall" then
        local u=math.clamp(age/mv.duration,0,1)
        drive(mv,mv.from:Lerp(mv.to,u*u),{direction=mv.rotation.LookVector,pitch=-.6*(1-u)})
        if u>=1 then releaseMover(model,true) end
    elseif mv.kind=="Hold" then
        drive(mv,mv.last)
        if age>3 then releaseMover(model) end
    elseif mv.kind=="Ultra" then
        -- Driven by stepUltra; this only guards against an orphaned capture.
        local owner=mv.owner
        if not owner or not ultras[owner] or ultras[owner].target~=t then
            dropToFloor(t,nil,mv.last,0)
        end
    end
end
RunService.Heartbeat:Connect(function()
    if not ctx then return end
    local n=ctx.clock()
    for p,e in smashes do stepSmash(p,e,n) end
    for p,u in ultras do stepUltra(p,u,n) end
    for model,mv in movers do stepMover(model,mv,n) end
end)
Players.PlayerRemoving:Connect(function(p)
    endSmash(p,"left");endUltra(p,"left");buffs[p]=nil
    for model,mv in movers do if mv.owner==p and mv.kind~="Fall" then releaseMover(model) end end
end)

---------------------------------------------------------------- hooks used by Combat
function AllMight.init(context) ctx=context end
function AllMight.handles(skill) return KIT[skill]==true end
-- Walk speed factor from the buff, the prep/recovery slows and fatigue.
function AllMight.speedFactor(m,n)
    local factor=1
    if (m:GetAttribute("AllMightBuffUntil") or 0)>n then factor*=A.OneForAll.MoveSpeed end
    if (m:GetAttribute("AllMightSpeedUntil") or 0)>n then factor*=m:GetAttribute("AllMightSpeedFactor") or 1 end
    return factor
end
function AllMight.held(m,n) return (m:GetAttribute("AllMightHeldUntil") or 0)>n end
function AllMight.noJump(m,n) return (m:GetAttribute("AllMightNoJumpUntil") or 0)>n end
-- Outgoing basic attacks hit harder while buffed; incoming damage is reduced while buffed.
function AllMight.damageFactor(attacker,victim,kind)
    local factor=1
    if kind=="Basic" and buffed(attacker) then factor*=A.OneForAll.BasicDamage end
    if buffed(victim) then factor*=A.OneForAll.DamageTaken end
    return factor
end
function AllMight.knockbackFactor(attacker) return buffed(attacker) and A.OneForAll.BasicKnockback or 1 end
-- Combat.launch asks first: Plus Ultra casters are not staggered, buffed ones ignore light pushes.
function AllMight.filterKnockback(victim,velocity)
    if (victim:GetAttribute("AllMightGuardUntil") or 0)>ctx.clock() then return nil end
    if buffed(victim) then
        if velocity.Magnitude<A.OneForAll.LightKnockback then return nil end
        return velocity*A.OneForAll.HeavyKeep
    end
    return velocity
end
-- Called by Combat after the request passed its own checks (kit, rate limit, domain lock, alive, not held).
function AllMight.request(p,s,m,h,r,skill,aim)
    local n=ctx.clock()
    -- E -> R: once the smash has landed, Plus Ultra may cancel its follow-through (once per smash).
    local e=smashes[p]
    local cancel=skill=="PlusUltra" and e and e.impactAt and n-e.impactAt>=A.UnitedStatesOfSmash.RCancelFrom
    if (s.busyUntil>n and not cancel) or s.slide or (m:GetAttribute("RootedUntil") or 0)>n then return end
    if (s.cooldowns[skill] or 0)>n then return end
    if cancel then
        smashes[p]=nil;releaseCaster(p)
        m:SetAttribute("AllMightSpeedUntil",0)
    end
    s.amGeneration=s.generation
    s.basicUntil=0
    if skill=="OneForAll" then oneForAll(p,s,m,h,r)
    elseif skill=="UnitedStatesOfSmash" then smash(p,s,m,h,r,aim)
    elseif skill=="PlusUltra" then plusUltra(p,s,m,h,r,aim) end
    ctx.sendState(p,s)
end
-- Character change, respawn or death: the buff ends at once and everything this player held is released.
function AllMight.reset(p)
    endSmash(p,"reset");endUltra(p,"reset")
    local m=p.Character
    if buffs[p] then powerOff(p,m,nil,"reset",false) end
    if m then
        for _,attribute in {"AllMightBuffUntil","AllMightSpeedUntil","AllMightNoJumpUntil","AllMightGuardUntil"} do m:SetAttribute(attribute,0) end
    end
    for model,mv in movers do if mv.owner==p and mv.kind~="Fall" then releaseMover(model) end end
end
return AllMight
