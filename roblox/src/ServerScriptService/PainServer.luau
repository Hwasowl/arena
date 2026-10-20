-- Tendo Pain: server-side judgement for Shinra Tensei (Q), Bansho Ten'in (E) and Chibaku Tensei (R).
-- Required by Combat.server.luau, which owns the shared player state (cooldowns, busy time, generation) and
-- passes its helpers in through Pain.init. Clients only send the key and their camera ray; targets, damage,
-- range, cooldowns and status effects are all decided here, from server positions.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local P=require(RS:WaitForChild("PainAbilityConfig"))

local Pain={}
local ctx
local KIT={};for _,skill in P.Kit do KIT[skill]=true end
local movers={}      -- [victim model] = forced movement in progress
local pulls={}       -- [caster player] = Bansho Ten'in in progress
local chibakus={}    -- [caster player] = Chibaku Tensei in progress
local waves={}       -- Shinra Tensei fronts that still erase projectiles

local function smoothstep(x) x=math.clamp(x,0,1);return x*x*(3-2*x) end
local function flat(v,fallback)
    local f=Vector3.new(v.X,0,v.Z)
    return f.Magnitude>.05 and f.Unit or fallback or Vector3.new(0,0,-1)
end
local function alive(t) return t.m.Parent and t.r.Parent and t.h.Parent and t.h.Health>0 end
-- World geometry only: every character, the caster and the moved body are excluded, non-collidable parts ignored.
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
    local hit=workspace:Raycast(position+Vector3.yAxis*4,Vector3.yAxis*-120,params)
    return hit and hit.Position or nil
end
-- How far the root sits above the floor it stands on (dummies 3.65, R15 avatars about 3).
local function hipOf(t,params)
    local floor=groundBelow(t.r.Position,params)
    return floor and math.clamp(t.r.Position.Y-floor.Y,1.5,6) or 3
end
local function stillCaster(p,s,m)
    local current=ctx.character(p)
    return ctx.states[p]==s and current==m and s.painGeneration==s.generation and ctx.kitOf(p)=="Pain"
end
-- Caster speed factor for a while; Combat.updateSpeed reads it every Heartbeat.
local function slowSelf(m,h,factor,duration)
    m:SetAttribute("PainSpeedFactor",factor);m:SetAttribute("PainSpeedUntil",ctx.clock()+duration);ctx.updateSpeed(m,h)
    task.delay(duration+.05,function() if m.Parent and h.Parent then ctx.updateSpeed(m,h) end end)
end

---------------------------------------------------------------- forced movement
-- Anchored training targets are moved kinematically; anything physical (players, NPCs) is pulled by a
-- server-created AlignPosition that its network owner simulates. Either way every step is blockcast against
-- world geometry first, so nobody is dragged through a wall, and a missing floor ends the move early.
local function releaseMover(model,keepHeld)
    local mv=movers[model];if not mv then return end
    movers[model]=nil
    if mv.align then mv.align:Destroy() end
    if mv.attachment then mv.attachment:Destroy() end
    if model.Parent and not keepHeld then model:SetAttribute("PainHeldUntil",0) end
    if mv.t.r.Parent and mv.t.r.Anchored and mv.rotation then mv.t.r.CFrame=CFrame.new(mv.t.r.Position)*mv.rotation end
end
local function startMover(t,owner,spec)
    if not alive(t) then return end
    if (t.m:GetAttribute("PainGuardUntil") or 0)>ctx.clock() then return end -- Chibaku caster resists displacement
    if (t.m:GetAttribute("AllMightGuardUntil") or 0)>ctx.clock() then return end -- so does a Plus Ultra caster
    if (t.m:GetAttribute("ItachiGuardUntil") or 0)>ctx.clock() then return end -- and Susanoo, or a crow clone mid-dodge
    if (t.m:GetAttribute("YujiroGuardUntil") or 0)>ctx.clock() or (t.m:GetAttribute("YujiroHeldUntil") or 0)>ctx.clock() then return end -- Ogre's Judgment / Yujiro's grip
    local old=movers[t.m]
    local rotation=old and old.rotation or t.r.CFrame.Rotation
    if old then releaseMover(t.m,true) end
    ctx.flights[t.m]=nil;ctx.doraKnockbacks[t.m]=nil
    local mv={t=t,owner=owner,start=ctx.clock(),last=t.r.Position,rotation=rotation,params=worldParams({owner and owner.Character})}
    for k,v in spec do mv[k]=v end
    if not t.r.Anchored then
        local attachment=Instance.new("Attachment");attachment.Name="PainForceAttachment";attachment.Parent=t.r
        local align=Instance.new("AlignPosition");align.Name="PainForce";align.Mode=Enum.PositionAlignmentMode.OneAttachment
        align.Attachment0=attachment;align.Position=t.r.Position;align.ApplyAtCenterOfMass=true;align.RigidityEnabled=false
        align.MaxForce=math.max(20000,t.r.AssemblyMass*workspace.Gravity*20);align.MaxVelocity=260;align.Responsiveness=60
        align.Parent=t.r
        mv.attachment=attachment;mv.align=align
        -- Hand the body to the server so the constraint is not fought by a stale client prediction.
        pcall(function() if not Players:GetPlayerFromCharacter(t.m) then t.r:SetNetworkOwner(nil) end end)
    end
    movers[t.m]=mv
    return mv
end
-- Moves the body toward `desired`; returns the reached position and the wall hit, if any.
local function drive(mv,desired,lean)
    local t=mv.t
    local from=mv.t.r.Anchored and mv.last or t.r.Position
    local step=desired-from
    local hit=nil
    if step.Magnitude>.001 then
        hit=workspace:Blockcast(CFrame.new(from),Vector3.new(1.8,2.6,1.8),step,mv.params)
        if hit then desired=from+step.Unit*math.max(0,hit.Distance-.1) end
    end
    if t.r.Anchored then
        local rotation=mv.rotation
        if lean then rotation=CFrame.lookAt(Vector3.zero,lean.direction).Rotation*CFrame.Angles(lean.pitch,0,0) end
        t.m:PivotTo(CFrame.new(desired)*rotation)
    elseif mv.align then
        mv.align.Position=desired
    end
    mv.last=desired
    return desired,hit
end

---------------------------------------------------------------- Q: Shinra Tensei
local function knockback(p,t,center,power)
    local cfg=P.ShinraTensei
    local direction=flat(t.r.Position-center,flat(t.r.CFrame.LookVector))
    local distance=cfg.KnockMin+(cfg.KnockMax-cfg.KnockMin)*power
    local lift=cfg.LiftMin+(cfg.LiftMax-cfg.LiftMin)*power
    local params=worldParams({p.Character})
    local from=t.r.Position
    local hip=hipOf(t,params)
    -- Never fling anyone past the edge: shorten the throw until there is floor under the landing point.
    while distance>2 and not groundBelow(from+direction*distance,params) do distance-=2 end
    if not startMover(t,p,{kind="Knock",from=from,direction=direction,distance=distance,lift=lift,duration=cfg.FlightTime,hip=hip,wallDamage=cfg.WallDamage}) then return end
    t.m:SetAttribute("PainHeldUntil",ctx.clock()+cfg.FlightTime)
    ctx.fx:FireAllClients("PainKnock",{owner=p.UserId,model=t.m,from=from,direction=direction,distance=distance,duration=cfg.FlightTime})
end
local function shinraTensei(p,s,m,h,r,aim)
    local cfg=P.ShinraTensei;local n=ctx.clock()
    s.cooldowns.ShinraTensei=n+cfg.Cooldown
    s.busyUntil=n+cfg.Windup+cfg.WaveTime+cfg.Recovery
    m:SetAttribute("PainNoJumpUntil",n+cfg.Windup+cfg.WaveTime+cfg.Recovery)
    slowSelf(m,h,cfg.CastSpeed,cfg.Windup+cfg.WaveTime+cfg.Recovery)
    ctx.fx:FireAllClients("PainShinraCast",{owner=p.UserId,start=n,position=r.Position,direction=aim})
    task.delay(cfg.Windup,function()
        if not stillCaster(p,s,m) then return end
        local center=r.Position
        local fired=ctx.clock()
        ctx.fx:FireAllClients("PainShinraWave",{owner=p.UserId,start=fired,position=center,radius=cfg.Radius,duration=cfg.WaveTime})
        table.insert(waves,{owner=p,center=center,start=fired})
        local hit={}
        -- Each victim is struck when the front reaches it; nearer bodies go first and fly farther.
        for _,t in ctx.targets(m) do
            local distance=(t.r.Position-center).Magnitude
            if distance<=cfg.Radius and not hit[t.m] then
                hit[t.m]=true
                local power=1-math.clamp(distance/cfg.Radius,0,1)
                task.delay(cfg.WaveTime*distance/cfg.Radius,function()
                    if not alive(t) then return end
                    ctx.damage(p,t,cfg.Damage,"Shockwave")
                    if alive(t) then knockback(p,t,center,power) end
                end)
            end
        end
        -- After the push: defenceless (busy) for Recovery, then a lingering slow.
        task.delay(cfg.WaveTime+cfg.Recovery,function()
            if stillCaster(p,s,m) then slowSelf(m,h,cfg.SlowFactor,cfg.SlowDuration);ctx.sendState(p,s) end
        end)
    end)
end

---------------------------------------------------------------- E: Bansho Ten'in
local function cancelPull(p,reason)
    local pull=pulls[p];if not pull then return end
    pulls[p]=nil
    if pull.target and movers[pull.target.m] and movers[pull.target.m].kind=="Pull" then releaseMover(pull.target.m) end
    ctx.fx:FireAllClients("PainBanshoCancel",{owner=p.UserId,target=pull.target and pull.target.m,reason=reason})
end
local function pickTarget(m,origin,aim)
    local cfg=P.BanshoTenin
    local best,bestAngle=nil,math.huge
    local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={m};params.RespectCanCollide=true
    local cosLimit=math.cos(math.rad(cfg.AimAngle))
    for _,t in ctx.targets(m) do
        local delta=t.r.Position-origin
        local distance=delta.Magnitude
        if distance>1 and distance<=cfg.Range then
            local cosine=delta.Unit:Dot(aim)
            if cosine>=cosLimit then
                local sight=workspace:Raycast(origin,delta,params)
                if not sight or sight.Instance:IsDescendantOf(t.m) then
                    local angle=math.acos(math.clamp(cosine,-1,1))+distance*.0005
                    if angle<bestAngle then best=t;bestAngle=angle end
                end
            end
        end
    end
    return best
end
local function banshoStrike(p,s,m,r,pull)
    local cfg=P.BanshoTenin
    local t=pull.target
    pulls[p]=nil
    if not stillCaster(p,s,m) or not alive(t) or (t.r.Position-r.Position).Magnitude>cfg.StopDistance+4 then
        if movers[t.m] then releaseMover(t.m) end
        ctx.fx:FireAllClients("PainBanshoCancel",{owner=p.UserId,target=t.m,reason="lost"})
        return
    end
    ctx.damage(p,t,cfg.StrikeDamage,"Melee")
    ctx.fx:FireAllClients("PainBanshoStrike",{owner=p.UserId,target=t.m,position=t.r.Position})
    if alive(t) then
        local direction=flat(t.r.Position-r.Position,flat(r.CFrame.LookVector))
        local params=worldParams({m})
        startMover(t,p,{kind="Strike",from=t.r.Position,direction=direction,distance=cfg.StrikeKnock,lift=.8,duration=cfg.StrikeKnockTime,hip=hipOf(t,params)})
        t.m:SetAttribute("PainHeldUntil",ctx.clock()+math.max(cfg.Stun,cfg.StrikeKnockTime))
    end
end
local function banshoTenin(p,s,m,h,r,aim,origin)
    local cfg=P.BanshoTenin;local n=ctx.clock()
    local head=m:FindFirstChild("Head")
    local eye=head and head.Position or r.Position+Vector3.yAxis*1.5
    if typeof(origin)~="Vector3" or (origin-eye).Magnitude>12 then origin=eye end
    local t=pickTarget(m,origin,aim)
    if not t then
        s.cooldowns.BanshoTenin=n+cfg.MissCooldown;s.busyUntil=n+cfg.MissRecovery
        ctx.fx:FireAllClients("PainBanshoMiss",{owner=p.UserId,start=n,direction=aim})
        return
    end
    s.cooldowns.BanshoTenin=n+cfg.Cooldown
    s.busyUntil=n+cfg.Windup+cfg.PullTimeMax+cfg.StrikeDelay+cfg.Recovery
    m:SetAttribute("PainNoJumpUntil",n+cfg.Windup+cfg.PullTimeMax+cfg.StrikeDelay)
    ctx.fx:FireAllClients("PainBanshoCast",{owner=p.UserId,start=n,target=t.m,direction=aim,windup=cfg.Windup})
    local pull={target=t,start=n}
    pulls[p]=pull
    task.delay(cfg.Windup,function()
        if pulls[p]~=pull then return end
        if not stillCaster(p,s,m) or not alive(t) then cancelPull(p,"lost");return end
        local distance=(t.r.Position-r.Position).Magnitude
        local duration=math.clamp(cfg.PullTimeMax*distance/cfg.Range,cfg.PullTimeMin,cfg.PullTimeMax)
        local params=worldParams({m})
        local mv=startMover(t,p,{kind="Pull",caster=r,from=t.r.Position,duration=duration,hip=hipOf(t,params),pull=pull})
        if not mv then cancelPull(p,"resisted");return end
        pull.mover=mv
        s.busyUntil=ctx.clock()+duration+cfg.StrikeDelay+cfg.Recovery
        ctx.fx:FireAllClients("PainBanshoPull",{owner=p.UserId,target=t.m,start=ctx.clock(),duration=duration})
    end)
end

---------------------------------------------------------------- R: Chibaku Tensei
local function fibonacciDirection(i,count)
    local y=1-(i-.5)/count*2;local radius=math.sqrt(math.max(0,1-y*y));local a=i*2.39996
    return Vector3.new(math.cos(a)*radius,y,math.sin(a)*radius)
end
local function endChibaku(p,reason)
    local c=chibakus[p];if not c then return end
    chibakus[p]=nil
    for model,v in c.captured do
        if model.Parent then model:SetAttribute("PainSealedUntil",0) end
        if v.t and alive(v.t) and not c.burst then
            -- Interrupted: drop everyone back to the floor below them, nobody is left hanging in the air.
            local floor=groundBelow(v.t.r.Position,c.params)
            releaseMover(model,true)
            if floor then
                startMover(v.t,nil,{kind="Fall",from=v.t.r.Position,to=floor+Vector3.yAxis*v.hip,duration=.6})
                model:SetAttribute("PainHeldUntil",ctx.clock()+.6)
            else releaseMover(model) end
        end
    end
    if c.model.Parent then c.model:SetAttribute("PainGuardUntil",0) end
    ctx.fx:FireAllClients("PainChibakuEnd",{owner=p.UserId,reason=reason})
end
local function chibakuTensei(p,s,m,h,r,aim)
    local cfg=P.ChibakuTensei;local n=ctx.clock()
    s.cooldowns.ChibakuTensei=n+cfg.Cooldown
    s.busyUntil=n+cfg.Duration
    m:SetAttribute("PainGuardUntil",n+cfg.Duration)
    m:SetAttribute("PainNoJumpUntil",n+cfg.Duration)
    ctx.setTimed(m,h,"RootedUntil",cfg.Duration)
    local params=worldParams({m})
    local forward=flat(aim,flat(r.CFrame.LookVector))
    local floor=groundBelow(r.Position,params)
    local groundY=floor and floor.Y or r.Position.Y-3
    local center=Vector3.new(r.Position.X,groundY,r.Position.Z)+forward*cfg.CoreForward
    local below=groundBelow(center,params);if below then center=below end
    local core=center+Vector3.yAxis*cfg.CoreHeight
    -- Keep the core under any roof that would cap it.
    local roof=workspace:Raycast(center+Vector3.yAxis*2,Vector3.yAxis*(cfg.CoreHeight+cfg.SphereRadius),params)
    if roof then core=Vector3.new(core.X,math.max(center.Y+12,roof.Position.Y-cfg.SphereRadius-2),core.Z) end
    local seed=math.random(1,2^30)
    local c={owner=p,state=s,model=m,humanoid=h,root=r,start=n,center=center,core=core,captured={},count=0,ticks=0,params=params,seed=seed}
    if chibakus[p] then endChibaku(p,"replaced") end
    chibakus[p]=c
    ctx.fx:FireAllClients("PainChibakuCast",{owner=p.UserId,start=n,origin=r.Position,core=core,center=center,radius=cfg.Radius,seed=seed,rocks=cfg.Rocks,sphere=cfg.SphereRadius})
end
local function capture(c,t)
    local cfg=P.ChibakuTensei
    c.count+=1
    local hip=hipOf(t,c.params)
    c.captured[t.m]={t=t,index=c.count,dir=fibonacciDirection((c.count-1)%8+1,8),hip=hip,from=nil}
    t.m:SetAttribute("PainHeldUntil",c.start+cfg.Burst+.1)
    ctx.fx:FireAllClients("PainChibakuCapture",{owner=c.owner.UserId,target=t.m})
end
local function stepChibaku(p,c,n)
    local cfg=P.ChibakuTensei
    local age=n-c.start
    if not stillCaster(p,c.state,c.model) then endChibaku(p,"interrupted");return end
    if age>=cfg.FieldStart and age<cfg.Formed-.5 then
        for _,t in ctx.targets(c.model) do
            if not c.captured[t.m] then
                local d=t.r.Position-c.center
                if Vector3.new(d.X,0,d.Z).Magnitude<=cfg.Radius and (t.m:GetAttribute("PainGuardUntil") or 0)<=n then capture(c,t) end
            end
        end
    end
    -- Two pulses of damage while the victims are being dragged up.
    while c.ticks<#cfg.TickTimes and age>=cfg.TickTimes[c.ticks+1] do
        c.ticks+=1
        for _,v in c.captured do if alive(v.t) then ctx.damage(p,v.t,cfg.TickDamage,"DoT") end end
    end
    for model,v in c.captured do
        local t=v.t
        if not alive(t) then
            if movers[model] then releaseMover(model) end
            if model.Parent then model:SetAttribute("PainSealedUntil",0) end
            c.captured[model]=nil
        elseif age<cfg.Burst then
            t.m:SetAttribute("PainHeldUntil",c.start+cfg.Burst+.1)
            local mv=movers[model]
            if not mv or mv.kind~="Field" then mv=startMover(t,p,{kind="Field",chibaku=c,from=t.r.Position,capturedAt=age}) end
            if not mv then c.captured[model]=nil
            elseif age>=cfg.Formed and not v.sealed then
                v.sealed=true;model:SetAttribute("PainSealedUntil",c.start+cfg.Burst)
            end
        end
    end
    if age>=cfg.Burst and not c.burst then
        c.burst=true
        ctx.fx:FireAllClients("PainChibakuBurst",{owner=p.UserId,core=c.core,start=c.start+cfg.Burst})
        for model,v in c.captured do
            local t=v.t
            if model.Parent then model:SetAttribute("PainSealedUntil",0) end
            if alive(t) then
                ctx.damage(p,t,cfg.FinalDamage,"Ultimate")
                releaseMover(model,true)
                if alive(t) then
                    -- Fall straight down onto the floor beneath, then lie knocked down for a moment.
                    local floor=groundBelow(t.r.Position,c.params) or groundBelow(c.center,c.params) or c.center
                    local fallTime=math.sqrt(2*math.max(1,t.r.Position.Y-floor.Y)/workspace.Gravity)+.1
                    startMover(t,nil,{kind="Fall",from=t.r.Position,to=floor+Vector3.yAxis*v.hip,duration=fallTime})
                    model:SetAttribute("PainHeldUntil",n+fallTime+cfg.KnockedDown)
                end
            end
        end
    end
    if age>=cfg.Duration then
        chibakus[p]=nil
        if c.model.Parent then c.model:SetAttribute("PainGuardUntil",0) end
        slowSelf(c.model,c.humanoid,cfg.SlowFactor,cfg.SlowDuration)
        ctx.fx:FireAllClients("PainChibakuEnd",{owner=p.UserId,reason="finished"})
    end
end

---------------------------------------------------------------- per-frame movement
local function stepMover(model,mv,n,dt)
    local t=mv.t
    if not alive(t) then releaseMover(model);return end
    local age=n-mv.start
    if mv.kind=="Knock" or mv.kind=="Strike" then
        local u=math.clamp(age/mv.duration,0,1)
        local along=1-(1-u)^2.2
        local height=mv.lift*4*u*(1-u)
        local desired=mv.from+mv.direction*mv.distance*along+Vector3.yAxis*height
        local _,hit=drive(mv,desired,{direction=-mv.direction,pitch=-.5*math.sin(u*math.pi)})
        if hit and not mv.walled then
            mv.walled=true
            if mv.wallDamage and mv.owner then ctx.damage(mv.owner,t,mv.wallDamage,"Environment") end
            ctx.fx:FireAllClients("PainWallHit",{position=mv.last,normal=hit.Normal})
            -- Stop dead against the wall, then slide down to the floor below.
            local floor=groundBelow(mv.last,mv.params)
            local landing=floor and floor+Vector3.yAxis*mv.hip or mv.last
            mv.kind="Fall";mv.start=n;mv.from=mv.last;mv.to=landing;mv.duration=.25
            return
        end
        if u>=1 then releaseMover(model,true) end
    elseif mv.kind=="Fall" then
        local u=math.clamp(age/mv.duration,0,1)
        drive(mv,mv.from:Lerp(mv.to,u*u))
        if u>=1 then releaseMover(model,true) end
    elseif mv.kind=="Pull" then
        local cfg=P.BanshoTenin
        local pull=mv.pull
        local caster=mv.caster
        local p=mv.owner
        if pulls[p]~=pull or not caster.Parent then releaseMover(model);return end
        local s=ctx.states[p]
        if not s or not stillCaster(p,s,caster.Parent) then cancelPull(p,"lost");return end
        if (t.r.Position-caster.Position).Magnitude>cfg.LeashRange then cancelPull(p,"range");return end
        local u=math.clamp(age/mv.duration,0,1)
        local direction=flat(caster.Position-mv.from)
        local stop=Vector3.new(caster.Position.X,mv.from.Y,caster.Position.Z)-direction*cfg.StopDistance
        local floor=groundBelow(stop,mv.params)
        if floor then stop=floor+Vector3.yAxis*mv.hip end
        -- Accelerates hard, eases off over the last stretch; the feet leave the ground on the way.
        local along=smoothstep(u^.6)
        local hover=cfg.Lift*smoothstep(u/.15)*(1-smoothstep((u-.85)/.15))
        local desired=mv.from:Lerp(stop,along)+Vector3.yAxis*hover
        t.m:SetAttribute("PainHeldUntil",n+.25)
        local _,hit=drive(mv,desired,{direction=direction,pitch=.35*math.sin(math.min(1,u*1.3)*math.pi)})
        if hit then cancelPull(p,"blocked");return end
        if u>=1 and not pull.arrived then
            pull.arrived=true
            t.m:SetAttribute("PainHeldUntil",n+cfg.StrikeDelay+.1)
            task.delay(cfg.StrikeDelay,function()
                if pulls[p]==pull then banshoStrike(p,s,caster.Parent,caster,pull) end
            end)
        end
    elseif mv.kind=="Field" then
        local cfg=P.ChibakuTensei
        local c=mv.chibaku
        local v=c.captured[model];if not v or chibakus[mv.owner]~=c then releaseMover(model);return end
        local age2=n-c.start
        if age2<cfg.LiftStart then
            -- Still on the ground: dragged slowly toward the point under the core.
            local toward=flat(c.center-t.r.Position,Vector3.zero)
            local desired=mv.last+toward*4*dt
            drive(mv,Vector3.new(desired.X,mv.from.Y,desired.Z))
            v.from=mv.last
        else
            v.from=v.from or mv.last
            local liftAt=math.max(cfg.LiftStart,mv.capturedAt or 0)
            local u=math.clamp((age2-liftAt)/math.max(.6,cfg.Formed-liftAt),0,1)
            local squeeze=1-.35*smoothstep((age2-cfg.Formed)/(cfg.CompressEnd-cfg.Formed))
            local slot=c.core+v.dir*cfg.SealRadius*squeeze
            -- Rise on a loose spiral around the core's axis rather than a straight line.
            local base=v.from:Lerp(slot,u^1.5)
            local swirl=(1-u)*math.sin(u*math.pi)*6
            local around=Vector3.new(math.cos(u*5+v.index),0,math.sin(u*5+v.index))*swirl
            -- Inside the field the target is carried with the rocks; only the sphere stops it, not the arena.
            if t.r.Anchored then
                t.m:PivotTo(CFrame.new(base+around)*mv.rotation*CFrame.Angles(math.sin(n*9+v.index)*.4,n*1.5,math.cos(n*7+v.index)*.4))
                mv.last=base+around
            elseif mv.align then mv.align.Position=base+around;mv.last=base+around end
        end
    end
end
RunService.Heartbeat:Connect(function(dt)
    if not ctx then return end
    local n=ctx.clock()
    for model,mv in movers do stepMover(model,mv,n,dt) end
    for p,c in chibakus do stepChibaku(p,c,n) end
    -- The Shinra Tensei front erases small projectiles it sweeps over.
    for i=#waves,1,-1 do
        local w=waves[i];local age=n-w.start
        local front=P.ShinraTensei.Radius*math.clamp(age/P.ShinraTensei.WaveTime,0,1)
        for j=#ctx.projectiles,1,-1 do
            local shot=ctx.projectiles[j]
            if shot.owner~=w.owner and P.ShinraTensei.ProjectileKinds[shot.kind] and (shot.position-w.center).Magnitude<=front+2 then
                ctx.fx:FireAllClients("ProjectileEnd",{id=shot.id,position=shot.position,kind=shot.kind})
                table.remove(ctx.projectiles,j)
            end
        end
        if age>P.ShinraTensei.WaveTime then table.remove(waves,i) end
    end
end)
Players.PlayerRemoving:Connect(function(p)
    cancelPull(p,"left");endChibaku(p,"left")
    for model,mv in movers do if mv.owner==p and mv.kind~="Fall" then releaseMover(model) end end
end)

---------------------------------------------------------------- entry points used by Combat
function Pain.init(context) ctx=context end
function Pain.handles(skill) return KIT[skill]==true end
-- Called by Combat after the request passed its own checks (kit, rate limit, domain lock, alive).
function Pain.request(p,s,m,h,r,skill,aim,origin)
    local n=ctx.clock()
    if s.busyUntil>n or s.slide or (m:GetAttribute("RootedUntil") or 0)>n or (m:GetAttribute("PainHeldUntil") or 0)>n then return end
    if (s.cooldowns[skill] or 0)>n then return end
    s.painGeneration=s.generation
    s.basicUntil=0
    if skill=="ShinraTensei" then shinraTensei(p,s,m,h,r,aim)
    elseif skill=="BanshoTenin" then banshoTenin(p,s,m,h,r,aim,origin)
    elseif skill=="ChibakuTensei" then chibakuTensei(p,s,m,h,r,aim) end
    ctx.sendState(p,s)
end
-- Character change, respawn or death: drop whatever this player was holding.
function Pain.reset(p)
    cancelPull(p,"reset");endChibaku(p,"reset")
    local m=p.Character
    if m then
        for _,attribute in {"PainSpeedUntil","PainNoJumpUntil","PainGuardUntil"} do m:SetAttribute(attribute,0) end
    end
end
return Pain
