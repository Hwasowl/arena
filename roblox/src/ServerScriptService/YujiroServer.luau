-- Yujiro Hanma: server-side judgement for 지상 최강의 생물 (Q, counter stance), 오거 러시 (E) and 오거의 심판 (R).
-- Required by Combat.server.luau, which owns the shared player state (cooldowns, busy time, generation) and passes its
-- helpers in through Yujiro.init. Clients send only the key and their camera ray; the read, the frontal arc, targets,
-- line of sight, every hit, every hold and every safe landing spot are decided here, from server positions and clocks.
-- Every body this module moves (the caster during a dash or a step-in, every victim) is moved by a server-created
-- AlignPosition or, for anchored training targets, kinematically; every step is blockcast against the world first.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local Y=require(RS:WaitForChild("YujiroConfig"))

local Yujiro={}
local ctx
local KIT={};for _,skill in Y.Kit do KIT[skill]=true end
local counters={}     -- [caster player] = Q in progress
local rushes={}       -- [caster player] = E in progress
local ultras={}       -- [caster player] = R in progress
local movers={}       -- [victim model] = forced hold / movement owned by one caster
local drives={}       -- [caster player] = constraint moving the caster

local function smoothstep(x) x=math.clamp(x,0,1);return x*x*(3-2*x) end
local function easeOut(x,power) x=math.clamp(x,0,1);return 1-(1-x)^(power or 2) end
local function window(a,from,to) return math.clamp((a-from)/(to-from),0,1) end
local function bump(a,from,to) return math.sin(window(a,from,to)*math.pi) end
local function flat(v,fallback)
    local f=Vector3.new(v.X,0,v.Z)
    return f.Magnitude>.05 and f.Unit or fallback or Vector3.new(0,0,-1)
end
local function alive(t) return t~=nil and t.m.Parent~=nil and t.r.Parent~=nil and t.h.Parent~=nil and t.h.Health>0 end
local function now() return ctx.clock() end
-- World geometry only: every character is excluded and non-collidable parts are ignored.
local function worldParams()
    local list={}
    for _,t in ctx.targets(nil) do table.insert(list,t.m) end
    for _,p in Players:GetPlayers() do if p.Character then table.insert(list,p.Character) end end
    local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances=list;params.RespectCanCollide=true
    return params
end
local function groundBelow(position,params,depth)
    local hit=workspace:Raycast(position+Vector3.yAxis*3,Vector3.yAxis*-(depth or 60),params)
    return hit and hit.Position or nil
end
local function hipOf(t,params)
    local floor=groundBelow(t.r.Position,params,12)
    return floor and math.clamp(t.r.Position.Y-floor.Y,1.5,6) or 3
end
local function headOf(t) local head=t.m:FindFirstChild("Head");return head and head.Position or t.r.Position+Vector3.yAxis*1.5 end
local function lineOfSight(from,to,params) return workspace:Raycast(from,to-from,params)==nil end
local function stillCaster(p,s,m,generation)
    return ctx.states[p]==s and ctx.character(p)==m and s.generation==generation and ctx.kitOf(p)=="Yujiro"
end
local function attr(m,name) return m:GetAttribute(name) or 0 end
-- Any hold that is not ours: a body in someone else's grip (or seal) cannot be grabbed or countered into a knock.
local function heldElsewhere(m,n)
    return attr(m,"PainHeldUntil")>n or attr(m,"AllMightHeldUntil")>n or attr(m,"ItachiHeldUntil")>n
        or attr(m,"ItachiSealedUntil")>n or attr(m,"YujiroHeldUntil")>n
end
-- Bodies in the middle of their own ultimate resist displacement.
local function guardedElsewhere(m,n)
    return attr(m,"PainGuardUntil")>n or attr(m,"AllMightGuardUntil")>n or attr(m,"ItachiGuardUntil")>n or attr(m,"YujiroGuardUntil")>n
end
local function setPose(m,pose,n,side)
    if m and m.Parent then m:SetAttribute("YujiroPose",pose);m:SetAttribute("YujiroPoseAt",n);m:SetAttribute("YujiroPoseSide",side or 1) end
end
local function hold(t,untilTime)
    if t.m.Parent then t.m:SetAttribute("YujiroHeldUntil",math.max(attr(t.m,"YujiroHeldUntil"),untilTime)) end
end
local function unhold(t)
    if t.m.Parent then t.m:SetAttribute("YujiroHeldUntil",0);setPose(t.m,"",now()) end
    if t.h.Parent then ctx.updateSpeed(t.m,t.h) end
end
-- A spot is safe when there is floor under it and nothing solid inside the body's box.
local function safeStand(position,hip,params)
    local floor=groundBelow(position,params,40);if not floor then return nil end
    local stand=Vector3.new(position.X,floor.Y+hip,position.Z)
    local overlap=OverlapParams.new();overlap.FilterType=Enum.RaycastFilterType.Exclude
    overlap.FilterDescendantsInstances=params.FilterDescendantsInstances;overlap.RespectCanCollide=true
    if #workspace:GetPartBoundsInBox(CFrame.new(stand),Vector3.new(2.2,hip*2-.4,2.2),overlap)>0 then return nil end
    return stand
end

---------------------------------------------------------------- moving the caster
local function driveCaster(p,r)
    local d=drives[p]
    if d and d.align.Parent and d.root==r then return d end
    if d then d.align:Destroy();d.attachment:Destroy() end
    local attachment=Instance.new("Attachment");attachment.Name="YujiroDriveAttachment";attachment.Parent=r
    local align=Instance.new("AlignPosition");align.Name="YujiroDrive";align.Mode=Enum.PositionAlignmentMode.OneAttachment
    align.Attachment0=attachment;align.Position=r.Position;align.ApplyAtCenterOfMass=true;align.RigidityEnabled=false
    align.MaxForce=math.max(30000,r.AssemblyMass*workspace.Gravity*30);align.MaxVelocity=260;align.Responsiveness=90
    align.Parent=r
    d={align=align,attachment=attachment,root=r,last=r.Position}
    drives[p]=d
    return d
end
local function releaseCaster(p)
    local d=drives[p];if not d then return end
    drives[p]=nil
    d.align:Destroy();d.attachment:Destroy()
    if d.root.Parent then
        local v=d.root.AssemblyLinearVelocity
        d.root.AssemblyLinearVelocity=Vector3.new(v.X*.1,math.min(v.Y,0),v.Z*.1)
    end
end
-- Moves the caster toward `desired`, stopping short of walls; returns the reached point and the wall hit.
local function moveCaster(p,r,desired,params)
    local d=driveCaster(p,r)
    local from=d.last
    local step=desired-from
    local hit=nil
    if step.Magnitude>.001 then
        hit=workspace:Blockcast(CFrame.new(from),Vector3.new(2.4,4,2.4),step,params)
        if hit then desired=from+step.Unit*math.max(0,hit.Distance-.15) end
    end
    d.align.Position=desired;d.last=desired
    return desired,hit
end

---------------------------------------------------------------- moving victims
local function releaseMover(model)
    local mv=movers[model];if not mv then return end
    movers[model]=nil
    if mv.align then mv.align:Destroy() end
    if mv.attachment then mv.attachment:Destroy() end
    if mv.t.r.Parent then
        if mv.t.r.Anchored then mv.t.r.CFrame=CFrame.new(mv.t.r.Position)*mv.rotation
        else mv.t.r.AssemblyLinearVelocity=Vector3.zero end
    end
end
local function startMover(t,owner,kind)
    if not alive(t) then return nil end
    local old=movers[t.m]
    if old and old.owner~=owner then return nil end
    local rotation=old and old.rotation or t.r.CFrame.Rotation
    if old then releaseMover(t.m) end
    if ctx.flights then ctx.flights[t.m]=nil end
    if ctx.doraKnockbacks then ctx.doraKnockbacks[t.m]=nil end
    local mv={t=t,owner=owner,kind=kind,start=now(),last=t.r.Position,rotation=rotation,params=worldParams()}
    if not t.r.Anchored then
        local attachment=Instance.new("Attachment");attachment.Name="YujiroForceAttachment";attachment.Parent=t.r
        local align=Instance.new("AlignPosition");align.Name="YujiroForce";align.Mode=Enum.PositionAlignmentMode.OneAttachment
        align.Attachment0=attachment;align.Position=t.r.Position;align.ApplyAtCenterOfMass=true;align.RigidityEnabled=false
        align.MaxForce=math.max(25000,t.r.AssemblyMass*workspace.Gravity*25);align.MaxVelocity=200;align.Responsiveness=70
        align.Parent=t.r
        mv.attachment=attachment;mv.align=align
        pcall(function() if not Players:GetPlayerFromCharacter(t.m) then t.r:SetNetworkOwner(nil) end end)
    end
    movers[t.m]=mv
    return mv
end
-- Moves a held body toward `desired` (never through walls unless `free`); `face` turns anchored targets.
local function drive(mv,desired,face,free)
    local t=mv.t
    local from=t.r.Anchored and mv.last or t.r.Position
    local step=desired-from
    if step.Magnitude>.001 and not free then
        local hit=workspace:Blockcast(CFrame.new(from),Vector3.new(1.8,2.6,1.8),step,mv.params)
        if hit then desired=from+step.Unit*math.max(0,hit.Distance-.1) end
    end
    if t.r.Anchored then
        local rotation=face and CFrame.lookAt(Vector3.zero,flat(face)).Rotation or mv.rotation
        t.m:PivotTo(CFrame.new(desired)*rotation)
    elseif mv.align then
        mv.align.Position=desired
    end
    mv.last=desired
    return desired
end
-- Lets go of a body on safe ground: where it is, else `fallback`, else `last`. Never inside a wall or mid-air.
local function setDown(t,fallback,last)
    local mv=movers[t.m]
    local params=mv and mv.params or worldParams()
    local hip=mv and mv.hip or hipOf(t,params)
    local spot=safeStand(t.r.Anchored and (mv and mv.last or t.r.Position) or t.r.Position,hip,params)
        or (fallback and safeStand(fallback,hip,params)) or (last and safeStand(last,hip,params))
    local rotation=mv and mv.rotation or t.r.CFrame.Rotation
    releaseMover(t.m)
    if spot and alive(t) then
        t.r.AssemblyLinearVelocity=Vector3.zero
        t.m:PivotTo(CFrame.new(spot)*rotation)
    end
end
-- A short knock along the floor with a small hop, then the mover lets go (stagger is the hold attribute).
local function knock(owner,t,direction,distance,lift,duration)
    if guardedElsewhere(t.m,now()) then return end
    local params=worldParams()
    local from=t.r.Position
    while distance>2 and not groundBelow(from+direction*distance,params,30) do distance-=2 end
    local mv=startMover(t,owner,"Knock");if not mv then return end
    mv.from=from;mv.direction=direction;mv.distance=distance;mv.lift=lift;mv.duration=duration;mv.hip=hipOf(t,params)
    return mv
end

---------------------------------------------------------------- Q: 지상 최강의 생물
local function endCounter(p,reason)
    local c=counters[p];if not c then return end
    counters[p]=nil
    releaseCaster(p)
    local m=c.m
    if m.Parent then
        m:SetAttribute("YujiroLockUntil",0);m:SetAttribute("YujiroNoJumpUntil",0);m:SetAttribute("YujiroSlowUntil",0)
        if c.h.Parent then ctx.updateSpeed(m,c.h) end
    end
    ctx.fx:FireAllClients("YujiroCounterEnd",{owner=p.UserId,reason=reason})
end
local function counterStart(p,s,m,h,r)
    local cfg=Y.OgreCounter;local n=now()
    s.cooldowns.OgreCounter=n+cfg.Cooldown;s.busyUntil=n+cfg.FailEnd
    m:SetAttribute("YujiroLockUntil",n+cfg.WindowEnd)
    m:SetAttribute("YujiroNoJumpUntil",n+cfg.FailEnd)
    ctx.updateSpeed(m,h)
    counters[p]={p=p,s=s,m=m,h=h,r=r,start=n,generation=s.generation}
    ctx.fx:FireAllClients("YujiroCounter",{owner=p.UserId,start=n,position=r.Position})
end
local function frontal(r,point,arc)
    local to=Vector3.new(point.X-r.Position.X,0,point.Z-r.Position.Z)
    if to.Magnitude<.3 then return true end
    return to.Unit:Dot(flat(r.CFrame.LookVector))>=math.cos(math.rad(arc))
end
-- Called by Combat.damage before anything is dealt. A counterable frontal hit inside the window is cancelled
-- entirely and starts the counter on the attacker. Returns true when the hit must deal nothing.
function Yujiro.tryCounter(owner,t,kind)
    if not ctx then return false end
    local cfg=Y.OgreCounter
    local victim=Players:GetPlayerFromCharacter(t.m)
    local c=victim and counters[victim]
    if not c or c.read or c.failed or not cfg.Counterable[kind or ""] then return false end
    local n=now();local a=n-c.start
    if a<cfg.Entry or a>cfg.WindowEnd or not stillCaster(victim,c.s,c.m,c.generation) then return false end
    local attacker=owner and owner.Character
    if not attacker or attacker==t.m then return false end
    local ah=attacker:FindFirstChildOfClass("Humanoid");local ar=attacker:FindFirstChild("HumanoidRootPart")
    if not ah or not ar or ah.Health<=0 or not frontal(c.r,ar.Position,cfg.Arc) then return false end
    -- The read: one per use. The attacker is caught mid-swing and cannot act until the stagger ends.
    c.read=n;c.attacker={m=attacker,h=ah,r=ar};c.attackerPlayer=owner
    c.s.busyUntil=n+cfg.End
    c.m:SetAttribute("YujiroLockUntil",n+cfg.End);c.m:SetAttribute("YujiroNoJumpUntil",n+cfg.End)
    ctx.updateSpeed(c.m,c.h)
    hold(c.attacker,n+cfg.Hit+cfg.Stagger);ctx.updateSpeed(attacker,ah)
    -- Step in toward the attacker (never through walls), stopping StepTo in front of it.
    local to=flat(ar.Position-c.r.Position,flat(c.r.CFrame.LookVector))
    local gap=Vector3.new(ar.Position.X-c.r.Position.X,0,ar.Position.Z-c.r.Position.Z).Magnitude
    local advance=math.clamp(gap-cfg.StepTo,0,cfg.StepMax)
    c.direction=to;c.from=c.r.Position;c.stand=c.r.Position+to*advance;c.params=worldParams()
    ctx.fx:FireAllClients("YujiroCounterRead",{owner=victim.UserId,start=n,attacker=attacker,position=ar.Position,from=c.r.Position,direction=to,kind=kind})
    return true
end
local function stepCounter(p,c,n)
    local cfg=Y.OgreCounter
    if not stillCaster(p,c.s,c.m,c.generation) or c.h.Health<=0 then endCounter(p,"interrupted");return end
    local a=n-c.start
    if not c.read then
        if a>=cfg.WindowEnd and not c.failed then
            -- No read: a short slowed recovery; the stance has used up its cooldown.
            c.failed=n
            c.m:SetAttribute("YujiroLockUntil",0)
            c.m:SetAttribute("YujiroSlowUntil",c.start+cfg.FailEnd);c.m:SetAttribute("YujiroSlowFactor",cfg.FailSpeed)
            ctx.updateSpeed(c.m,c.h)
            ctx.fx:FireAllClients("YujiroCounterFail",{owner=p.UserId,start=n})
        end
        if a>=cfg.FailEnd then endCounter(p,"failed") end
        return
    end
    local k=n-c.read
    if k<cfg.Hit and c.stand then
        local u=easeOut(window(k,cfg.Snap*.5,cfg.Hit),2)
        moveCaster(p,c.r,c.from:Lerp(c.stand,u),c.params)
    end
    if k>=cfg.Hit and not c.hit then
        c.hit=true
        releaseCaster(p)
        local t=c.attacker
        local landed=false
        if alive(t) and (t.r.Position-c.r.Position).Magnitude<=cfg.Reach then
            landed=true
            ctx.damage(p,t,cfg.Damage,"Melee")
            if alive(t) then
                knock(p,t,flat(t.r.Position-c.r.Position,c.direction),cfg.Knockback,cfg.KnockLift,cfg.KnockTime)
                hold(t,n+cfg.Stagger);ctx.updateSpeed(t.m,t.h)
                setPose(t.m,"Uppercut",n)
            end
        end
        ctx.fx:FireAllClients("YujiroCounterHit",{owner=p.UserId,start=n,target=t and t.m or nil,landed=landed,
            position=t and t.r.Parent and t.r.Position or c.r.Position+c.direction*3,direction=c.direction})
    end
    if k>=cfg.End then
        local m=c.m
        counters[p]=nil
        releaseCaster(p)
        if m.Parent then
            m:SetAttribute("YujiroLockUntil",0);m:SetAttribute("YujiroNoJumpUntil",0)
            m:SetAttribute("YujiroBuffUntil",n+cfg.BuffDuration)
            ctx.updateSpeed(m,c.h)
        end
        ctx.fx:FireAllClients("YujiroCounterEnd",{owner=p.UserId,reason="done",buffUntil=n+cfg.BuffDuration})
    end
end

---------------------------------------------------------------- E: 오거 러시
local function endRush(p,reason)
    local e=rushes[p];if not e then return end
    rushes[p]=nil
    releaseCaster(p)
    local t=e.target
    if e.linked and t and e.holding then
        if movers[t.m] and movers[t.m].owner==p then setDown(t,e.home,nil) end
        unhold(t)
    end
    local m=e.m
    if m.Parent then m:SetAttribute("YujiroLockUntil",0);if e.h.Parent then ctx.updateSpeed(m,e.h) end end
    ctx.fx:FireAllClients("YujiroRushEnd",{owner=p.UserId,reason=reason})
end
local function firstAhead(m,origin,direction,reach,width,params)
    local best,bestAlong=nil,math.huge
    local n=now()
    for _,t in ctx.targets(m) do
        local rel=t.r.Position-origin;local along=rel:Dot(direction)
        local side=Vector3.new(rel.X,0,rel.Z)-direction*along
        if along>-.5 and along<=reach and side.Magnitude<=width and math.abs(rel.Y)<6 and along<bestAlong
            and not heldElsewhere(t.m,n) and lineOfSight(origin,t.r.Position,params) then best=t;bestAlong=along end
    end
    return best,bestAlong
end
local function rushStart(p,s,m,h,r,aim)
    local cfg=Y.OgreRush;local n=now()
    local direction=flat(aim,flat(r.CFrame.LookVector))
    s.cooldowns.OgreRush=n+cfg.Cooldown;s.busyUntil=n+cfg.End
    m:SetAttribute("YujiroLockUntil",n+cfg.End);ctx.updateSpeed(m,h)
    rushes[p]={p=p,s=s,m=m,h=h,r=r,start=n,direction=direction,generation=s.generation,params=worldParams(),flags={}}
    ctx.fx:FireAllClients("YujiroRush",{owner=p.UserId,start=n,direction=direction,position=r.Position})
end
local function stepRush(p,e,n)
    local cfg=Y.OgreRush
    if not stillCaster(p,e.s,e.m,e.generation) or e.h.Health<=0 then endRush(p,"interrupted");return end
    local a=n-e.start
    if a<cfg.Crouch then return end
    local r=e.r
    if not e.from then
        e.from=r.Position;driveCaster(p,r).last=r.Position
        local t,along=firstAhead(e.m,r.Position,e.direction,cfg.Distance+cfg.Stop,cfg.Width,e.params)
        e.target=t
        e.limit=t and math.clamp(along-cfg.Stop,0,cfg.Distance) or cfg.Distance
        ctx.fx:FireAllClients("YujiroRushDash",{owner=p.UserId,start=n,from=e.from,direction=e.direction,distance=e.limit,target=t and t.m or nil})
    end
    if a<cfg.DashEnd then
        local u=easeOut(window(a,cfg.Crouch,cfg.DashEnd),1.8)
        moveCaster(p,r,e.from+e.direction*e.limit*u,e.params)
        return
    end
    if not e.linked and not e.whiff then
        local t=e.target
        local gap=t and alive(t) and Vector3.new(t.r.Position.X-r.Position.X,0,t.r.Position.Z-r.Position.Z).Magnitude or math.huge
        if t and gap<=cfg.Stop+2 and not heldElsewhere(t.m,n) then
            e.linked=true;e.home=t.r.Position;e.stand=drives[p] and drives[p].last or r.Position
            -- A body in the middle of its own ultimate takes the blows but is not pinned.
            if not guardedElsewhere(t.m,n) then
                local mv=startMover(t,p,"Hold")
                if mv then mv.hip=hipOf(t,mv.params);e.holding=true;hold(t,n+.3);ctx.updateSpeed(t.m,t.h) end
            end
            ctx.fx:FireAllClients("YujiroRushLink",{owner=p.UserId,start=e.start,target=t.m,position=t.r.Position,direction=e.direction})
        else
            e.whiff=true;e.target=nil
            releaseCaster(p)
            e.s.busyUntil=e.start+cfg.WhiffEnd;e.m:SetAttribute("YujiroLockUntil",e.start+cfg.WhiffEnd)
            ctx.fx:FireAllClients("YujiroRushWhiff",{owner=p.UserId,start=n,position=r.Position,direction=e.direction})
            ctx.sendState(p,e.s)
        end
    end
    if e.whiff then
        if a>=cfg.WhiffEnd then endRush(p,"whiff") end
        return
    end
    if e.stand and not e.stopped then moveCaster(p,r,e.stand,e.params) end
    local t=e.target
    if not e.stopped then
        local reason=nil
        if not alive(t) then reason="dead"
        elseif (t.r.Position-e.home).Magnitude>cfg.Escape then reason="escaped" end
        if reason then
            e.stopped=n
            local mv=movers[t.m]
            if mv and mv.owner==p then releaseMover(t.m) end
            if t.m.Parent and e.holding then unhold(t) end
            e.holding=false
            releaseCaster(p)
            e.s.busyUntil=math.min(e.s.busyUntil,n+.35);e.m:SetAttribute("YujiroLockUntil",n+.35)
            ctx.fx:FireAllClients("YujiroRushStop",{owner=p.UserId,start=n,reason=reason})
            ctx.sendState(p,e.s)
        end
    end
    if not e.stopped then
        if e.holding then hold(t,n+.3) end
        local mv=movers[t.m]
        -- The axe kick drives the body down: it sinks a little and stays low until the recovery ends.
        if mv and mv.owner==p then
            local sink=e.flags[3] and .9*easeOut(window(a,cfg.Blows[3].Time,cfg.Blows[3].Time+.08),2) or 0
            drive(mv,e.home-Vector3.yAxis*sink,-e.direction,true)
        end
        for i,b in cfg.Blows do
            if a>=b.Time and not e.flags[i] then
                e.flags[i]=true
                ctx.damage(p,t,b.Damage,b.Kind)
                setPose(t.m,b.Name=="Body" and "Fold" or b.Name=="Hook" and "Turn" or "Down",n,b.Name=="Hook" and -1 or 1)
                ctx.fx:FireAllClients("YujiroRushHit",{owner=p.UserId,start=e.start,index=i,target=t.m,position=t.r.Position,direction=e.direction})
                if not alive(t) then break end
            end
        end
    end
    if a>=cfg.End or (e.stopped and n>=e.stopped+.35) then endRush(p,e.stopped and "stopped" or "done") end
end

---------------------------------------------------------------- R: 오거의 심판
local function endUltra(p,reason)
    local u=ultras[p];if not u then return end
    ultras[p]=nil
    releaseCaster(p)
    local t=u.target
    if t then
        local mv=movers[t.m]
        if mv and mv.owner==p then
            if alive(t) then setDown(t,u.home,u.stand and u.stand+u.direction*Y.OgreJudgment.Hold) else releaseMover(t.m) end
        end
        if t.m.Parent then unhold(t) end
    end
    local m=u.m
    if m.Parent then
        for _,attribute in {"YujiroLockUntil","YujiroGuardUntil","YujiroNoJumpUntil"} do m:SetAttribute(attribute,0) end
        if u.h.Parent then ctx.updateSpeed(m,u.h) end
    end
    ctx.fx:FireAllClients("YujiroJudgmentEnd",{owner=p.UserId,reason=reason,target=t and t.m or nil})
end
local function judgmentStart(p,s,m,h,r,aim,aimOrigin)
    local cfg=Y.OgreJudgment;local n=now()
    s.cooldowns.OgreJudgment=n+cfg.Cooldown;s.busyUntil=n+cfg.End
    local head=m:FindFirstChild("Head")
    local origin=head and head.Position or r.Position+Vector3.yAxis*1.5
    if typeof(aimOrigin)=="Vector3" and (aimOrigin-origin).Magnitude<=12 then origin=aimOrigin end
    m:SetAttribute("YujiroLockUntil",n+cfg.End);m:SetAttribute("YujiroGuardUntil",n+cfg.End);m:SetAttribute("YujiroNoJumpUntil",n+cfg.End)
    ctx.updateSpeed(m,h)
    if ultras[p] then endUltra(p,"replaced") end
    local direction=flat(aim,flat(r.CFrame.LookVector))
    ultras[p]={p=p,s=s,m=m,h=h,r=r,start=n,aim=aim,origin=origin,direction=direction,generation=s.generation,flags={},params=worldParams()}
    ctx.fx:FireAllClients("YujiroJudgment",{owner=p.UserId,start=n,direction=direction,position=r.Position})
end
-- Capture: nearest body within Range and Angle of the view centre at cast start, in sight, not held by anyone.
local function capture(u,n)
    local cfg=Y.OgreJudgment
    local best,bestDist=nil,math.huge
    local cosMax=math.cos(math.rad(cfg.Angle))
    for _,t in ctx.targets(u.m) do
        if not heldElsewhere(t.m,n) and not guardedElsewhere(t.m,n) then
            for _,point in {headOf(t),t.r.Position} do
                local to=point-u.origin;local dist=to.Magnitude
                if dist<=cfg.Range and dist>.5 and dist<bestDist and to.Unit:Dot(u.aim)>=cosMax and lineOfSight(u.origin,point,u.params) then
                    best=t;bestDist=dist;break
                end
            end
        end
    end
    return best
end
-- Where the target should be `a` seconds into the cast (after the grab).
local function victimPoint(u,a)
    local cfg=Y.OgreJudgment
    local d=u.direction
    local grip=u.stand+d*cfg.Hold+Vector3.yAxis*(u.targetHip-u.casterHip)
    if a<cfg.DashEnd then return u.home end
    if a<cfg.Release then
        -- Recoil on each blow, then the two-hand lift.
        local recoil=0
        for i,hit in cfg.Hits do if i<#cfg.Hits then recoil+=.35*bump(a,hit.Time,hit.Time+.16) end end
        local lift=cfg.LiftHeight*smoothstep(window(a,cfg.LiftFrom,cfg.LiftTo))
        return grip+d*recoil+Vector3.yAxis*lift
    end
    local high=grip+Vector3.yAxis*cfg.LiftHeight
    local throwTo=u.throwTo or high+d*cfg.ThrowDistance
    if a<cfg.Final then
        local k=window(a,cfg.Release,cfg.Final)
        return high:Lerp(throwTo,easeOut(k,1.6))+Vector3.yAxis*.8*math.sin(k*math.pi)
    end
    local floor=u.floorAt or throwTo
    return throwTo:Lerp(floor,easeOut(window(a,cfg.Final,cfg.Final+.1),2))
end
local function stepUltra(p,u,n)
    local cfg=Y.OgreJudgment
    if not stillCaster(p,u.s,u.m,u.generation) or u.h.Health<=0 then endUltra(p,"caster");return end
    local a=n-u.start
    if a>=cfg.End then endUltra(p,"done");return end
    if a<cfg.Capture then return end
    if u.failed then
        if a>=cfg.FailEnd then endUltra(p,"failed") end
        return
    end
    if not u.target then
        local t=capture(u,n)
        if not t then
            u.failed=n
            u.s.cooldowns.OgreJudgment=u.start+cfg.FailCooldown;u.s.busyUntil=u.start+cfg.FailEnd
            u.m:SetAttribute("YujiroLockUntil",u.start+cfg.FailEnd);u.m:SetAttribute("YujiroGuardUntil",u.start+cfg.FailEnd)
            u.m:SetAttribute("YujiroNoJumpUntil",u.start+cfg.FailEnd)
            ctx.fx:FireAllClients("YujiroJudgmentFail",{owner=p.UserId,start=u.start})
            ctx.sendState(p,u.s)
            return
        end
        local mv=startMover(t,p,"Judgment")
        if not mv then
            u.failed=n;u.s.cooldowns.OgreJudgment=u.start+cfg.FailCooldown;u.s.busyUntil=u.start+cfg.FailEnd
            ctx.fx:FireAllClients("YujiroJudgmentFail",{owner=p.UserId,start=u.start});ctx.sendState(p,u.s)
            return
        end
        u.target=t;u.home=t.r.Position
        mv.hip=hipOf(t,u.params)
        u.casterHip=hipOf({m=u.m,h=u.h,r=u.r},u.params);u.targetHip=mv.hip
        u.direction=flat(t.r.Position-u.r.Position,u.direction)
        u.from=u.r.Position;driveCaster(p,u.r).last=u.r.Position
        local stand=t.r.Position-u.direction*cfg.Hold
        u.stand=Vector3.new(stand.X,t.r.Position.Y-u.targetHip+u.casterHip,stand.Z)
        hold(t,n+.3);ctx.updateSpeed(t.m,t.h)
        ctx.fx:FireAllClients("YujiroJudgmentCapture",{owner=p.UserId,start=u.start,target=t.m,position=t.r.Position,direction=u.direction})
    end
    local t=u.target
    if not alive(t) then endUltra(p,t.m.Parent and "target" or "left");return end
    local mv=movers[t.m]
    if not mv or mv.owner~=p then endUltra(p,"lost");return end
    -- The caster: dash to the grab, stand, then step into the final punch.
    if a<cfg.DashEnd then
        local reached=moveCaster(p,u.r,u.from:Lerp(u.stand,easeOut(window(a,cfg.Capture,cfg.DashEnd),2.2)),u.params)
        if a>=cfg.DashEnd-.02 then u.stand=reached end
    elseif a<cfg.Final+.1 then
        if not u.grabbed then
            u.grabbed=true;u.stand=drives[p] and drives[p].last or u.r.Position
            ctx.fx:FireAllClients("YujiroJudgmentGrab",{owner=p.UserId,start=u.start,target=t.m,position=t.r.Position})
        end
        moveCaster(p,u.r,u.stand+u.direction*cfg.StepIn*easeOut(window(a,cfg.WindTo,cfg.Final),2),u.params)
    elseif not u.landed then
        u.landed=true;releaseCaster(p)
    end
    -- The throw path is fixed once at the release: shortened until it is clear of walls and has floor under it.
    if a>=cfg.Release and not u.throwTo then
        local high=(mv.last or t.r.Position)
        local distance=cfg.ThrowDistance
        local hit=workspace:Blockcast(CFrame.new(high),Vector3.new(1.8,2.6,1.8),u.direction*distance,u.params)
        if hit then distance=math.max(0,hit.Distance-.3) end
        while distance>.5 and not groundBelow(high+u.direction*distance,u.params,30) do distance-=.5 end
        u.throwTo=high+u.direction*distance-Vector3.yAxis*(cfg.LiftHeight-cfg.ThrowHeight)
        setPose(t.m,"Thrown",n)
        ctx.fx:FireAllClients("YujiroJudgmentThrow",{owner=p.UserId,start=u.start,target=t.m,from=high,to=u.throwTo})
    end
    if a>=cfg.Final and not u.floorAt then
        local floor=groundBelow(u.throwTo or t.r.Position,u.params,40)
        u.floorAt=floor and floor+Vector3.yAxis*math.min(1.1,mv.hip) or (u.throwTo or t.r.Position)
    end
    -- Hits, once each, on the clock from the cast start.
    for i,hit in cfg.Hits do
        if a>=hit.Time and not u.flags[i] then
            u.flags[i]=true
            local final=i==#cfg.Hits
            ctx.damage(p,t,hit.Damage,"Ultimate")
            setPose(t.m,final and "Lie" or hit.Name=="Body" and "Fold" or hit.Name=="Slap" and "Turn" or "Rock",n,(i%2==0) and -1 or 1)
            ctx.fx:FireAllClients("YujiroJudgmentHit",{owner=p.UserId,start=u.start,index=i,name=hit.Name,final=final,target=t.m,
                position=t.r.Position,direction=u.direction,ground=final and u.floorAt or nil})
            if not alive(t) then endUltra(p,"target");return end
        end
    end
    if a>=cfg.LiftFrom and a<cfg.Release and not u.flags.lift then u.flags.lift=true;setPose(t.m,"Dangle",n) end
    -- The body: held in the grip, lifted, thrown, driven into the floor, then left lying there.
    local downUntil=cfg.Final+.1+cfg.Down
    if a<downUntil then
        hold(t,n+.3)
        drive(mv,victimPoint(u,a),-u.direction,a>=cfg.Release and a<cfg.Final+.12)
    elseif not u.released then
        u.released=true
        setDown(t,u.floorAt,u.home)
        unhold(t)
    end
end

---------------------------------------------------------------- per-frame movement
local function stepMover(model,mv,n)
    local t=mv.t
    if not alive(t) then releaseMover(model);return end
    if mv.kind=="Knock" then
        local u=math.clamp((n-mv.start)/mv.duration,0,1)
        local desired=mv.from+mv.direction*mv.distance*easeOut(u,2.4)+Vector3.yAxis*mv.lift*4*u*(1-u)
        drive(mv,desired,-mv.direction,false)
        if u>=1 then releaseMover(model) end
    else
        -- Holds are driven by their owner's step; an orphaned one is let go on safe ground.
        local owner=mv.owner
        local alive_=owner and ((mv.kind=="Hold" and rushes[owner] and rushes[owner].target==t)
            or (mv.kind=="Judgment" and ultras[owner] and ultras[owner].target==t))
        if not alive_ then setDown(t,nil,nil);unhold(t) end
    end
end
RunService.Heartbeat:Connect(function()
    if not ctx then return end
    local n=now()
    for p,c in counters do stepCounter(p,c,n) end
    for p,e in rushes do stepRush(p,e,n) end
    for p,u in ultras do stepUltra(p,u,n) end
    for model,mv in movers do stepMover(model,mv,n) end
end)
Players.PlayerRemoving:Connect(function(p)
    endCounter(p,"left");endRush(p,"left");endUltra(p,"left")
    for model,mv in movers do if mv.owner==p then releaseMover(model) end end
end)

---------------------------------------------------------------- hooks used by Combat
function Yujiro.init(context) ctx=context end
function Yujiro.handles(skill) return KIT[skill]==true end
function Yujiro.speedFactor(m,n)
    if attr(m,"YujiroLockUntil")>n then return 0 end
    if attr(m,"YujiroSlowUntil")>n then return m:GetAttribute("YujiroSlowFactor") or 1 end
    return 1
end
function Yujiro.held(m,n) return attr(m,"YujiroHeldUntil")>n end
function Yujiro.locked(m,n) return attr(m,"YujiroLockUntil")>n end
function Yujiro.noJump(m,n) return Yujiro.held(m,n) or attr(m,"YujiroLockUntil")>n or attr(m,"YujiroNoJumpUntil")>n end
-- Outgoing: +15% basic attacks right after a counter. Incoming: -70% from the front while the stance waits (any kind,
-- countered or not: the counter itself cancels the hit before this runs), -30% for the whole of Ogre's Judgment.
function Yujiro.damageFactor(attacker,victim,kind)
    local n=now();local factor=1
    if kind=="Basic" and attacker and attr(attacker,"YujiroBuffUntil")>n then factor*=Y.OgreCounter.BasicDamage end
    if attr(victim,"YujiroGuardUntil")>n then factor*=Y.OgreJudgment.DamageTaken end
    local owner=Players:GetPlayerFromCharacter(victim)
    local c=owner and counters[owner]
    if c and not c.read and not c.failed and c.m==victim then
        local a=n-c.start
        local ar=attacker and attacker:FindFirstChild("HumanoidRootPart")
        if a>=Y.OgreCounter.Entry and a<=Y.OgreCounter.WindowEnd and ar and frontal(c.r,ar.Position,Y.OgreCounter.Arc) then
            factor*=1-Y.OgreCounter.Reduction
            ctx.fx:FireAllClients("YujiroCounterBlock",{owner=owner.UserId,from=ar.Position})
        end
    end
    return factor
end
-- Ogre's Judgment: the caster is not staggered.
function Yujiro.filterKnockback(victim,velocity)
    if attr(victim,"YujiroGuardUntil")>now() then return nil end
    return velocity
end
function Yujiro.guarded(model) return attr(model,"YujiroGuardUntil")>now() end
-- Called by Combat after the request passed its own checks (kit, rate limit, domain lock, alive, not held).
function Yujiro.request(p,s,m,h,r,skill,aim,aimOrigin)
    local n=now()
    if s.busyUntil>n or s.slide or attr(m,"RootedUntil")>n or attr(m,"YujiroLockUntil")>n then return end
    if (s.cooldowns[skill] or 0)>n then return end
    s.basicUntil=0
    if skill=="OgreCounter" then counterStart(p,s,m,h,r)
    elseif skill=="OgreRush" then rushStart(p,s,m,h,r,aim)
    elseif skill=="OgreJudgment" then judgmentStart(p,s,m,h,r,aim,aimOrigin) end
    ctx.sendState(p,s)
end
-- Character change, respawn or death: every stance, rush, ultimate and hold this player owns ends at once.
function Yujiro.reset(p)
    endCounter(p,"reset");endRush(p,"reset");endUltra(p,"reset")
    for model,mv in movers do
        if mv.owner==p then
            if alive(mv.t) then setDown(mv.t,nil,nil);unhold(mv.t) else releaseMover(model) end
        end
    end
    local m=p.Character
    if m then
        -- Holds placed on this player by someone else are theirs to release; only our own casting state is cleared.
        for _,attribute in {"YujiroLockUntil","YujiroGuardUntil","YujiroNoJumpUntil","YujiroSlowUntil","YujiroBuffUntil"} do m:SetAttribute(attribute,0) end
    end
end
return Yujiro
