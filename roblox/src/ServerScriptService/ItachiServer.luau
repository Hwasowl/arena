-- Uchiha Itachi: server-side judgement for the Crow Clone passive, Tsukuyomi (Q), Amaterasu (E) and Susanoo (R).
-- Required by Combat.server.luau, which owns the shared player state (cooldowns, busy time, generation) and passes
-- its helpers in through Itachi.init. Clients send only the key and their camera ray; the dodge roll, targets, line
-- of sight, the ground under Amaterasu, every damage tick, the bind and the seal are decided here.
-- Status priority on a victim: Seal > Tsukuyomi bind > Amaterasu slow. A sealed body cannot be bound or burned.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local I=require(RS:WaitForChild("ItachiConfig"))

local Itachi={}
local ctx
local KIT={};for _,skill in I.Kit do KIT[skill]=true end
local rng=Random.new()
local crowReady={}    -- [player] = clock time the passive can fire again
local binds={}        -- [caster player] = {t, start} Tsukuyomi in progress
local fields={}       -- list of Amaterasu fields
local ultras={}       -- [caster player] = Susanoo in progress
local sealed={}       -- [victim model] = {t, align, attachment, home, owner}

local function smoothstep(x) x=math.clamp(x,0,1);return x*x*(3-2*x) end
local function flat(v,fallback)
    local f=Vector3.new(v.X,0,v.Z)
    return f.Magnitude>.05 and f.Unit or fallback or Vector3.new(0,0,-1)
end
local function alive(t) return t and t.m.Parent and t.r.Parent and t.h.Parent and t.h.Health>0 end
local function now() return ctx.clock() end
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
local function groundBelow(position,params,depth)
    local hit=workspace:Raycast(position+Vector3.yAxis*3,Vector3.yAxis*-(depth or 200),params)
    return hit
end
local function hipOf(t)
    local hip=t.h.HipHeight+(t.r.Size.Y/2)
    return t.h.RigType==Enum.HumanoidRigType.R6 and 3 or math.max(2,hip)
end
local function stillCaster(p,s,m,generation)
    return ctx.states[p]==s and ctx.character(p)==m and s.generation==generation and ctx.kitOf(p)=="Itachi"
end
local function setUntil(m,attribute,untilTime)
    if m and m.Parent then m:SetAttribute(attribute,untilTime) end
end
local function heldByOthers(m,n)
    return (m:GetAttribute("PainHeldUntil") or 0)>n or (m:GetAttribute("AllMightHeldUntil") or 0)>n
end
local function isSealed(m,n) return (m:GetAttribute("ItachiSealedUntil") or 0)>n end
local function headOf(t) local head=t.m:FindFirstChild("Head");return head and head.Position or t.r.Position+Vector3.yAxis*1.5 end
local function lineOfSight(from,to,params)
    return workspace:Raycast(from,to-from,params)==nil
end
-- A spot is safe when there is floor under it, no wall in the way, nothing solid inside it and nobody on it.
local function safeSpot(from,to,params,except)
    local path=to-from
    if path.Magnitude>.1 and workspace:Blockcast(CFrame.new(from),Vector3.new(2.2,3.6,2.2),path,params) then return nil end
    local floor=groundBelow(to,params,14);if not floor then return nil end
    local under=groundBelow(from,params,14)
    local hip=under and from.Y-under.Position.Y or 3
    local stand=Vector3.new(to.X,floor.Position.Y+hip,to.Z)
    local overlap=OverlapParams.new();overlap.FilterType=Enum.RaycastFilterType.Exclude;overlap.FilterDescendantsInstances=params.FilterDescendantsInstances;overlap.RespectCanCollide=true
    if #workspace:GetPartBoundsInBox(CFrame.new(stand),Vector3.new(2.4,4.4,2.4),overlap)>0 then return nil end
    for _,t in ctx.targets(except) do
        if (Vector3.new(t.r.Position.X,0,t.r.Position.Z)-Vector3.new(stand.X,0,stand.Z)).Magnitude<I.CrowClone.ClearRadius then return nil end
    end
    return stand
end

---------------------------------------------------------------- passive: Crow Clone
-- Called by Combat.damage before anything is dealt. Returns true when the hit is cancelled entirely.
function Itachi.tryDodge(owner,t,kind)
    if not ctx or not I.CrowClone.Dodgeable[kind or ""] then return false end
    local victim=Players:GetPlayerFromCharacter(t.m)
    if not victim or ctx.kitOf(victim)~="Itachi" or not alive(t) then return false end
    local n=now()
    if (crowReady[victim] or 0)>n or heldByOthers(t.m,n) or isSealed(t.m,n) then return false end
    if rng:NextNumber()>=I.CrowClone.Chance then return false end
    local cfg=I.CrowClone
    crowReady[victim]=n+cfg.InternalCooldown
    -- Back means away from whoever struck; then back-left/right, then straight left/right. No safe spot: stay put.
    local attacker=owner and owner.Character and owner.Character:FindFirstChild("HumanoidRootPart")
    local away=attacker and flat(t.r.Position-attacker.Position,-t.r.CFrame.LookVector) or -flat(t.r.CFrame.LookVector)
    local side=away:Cross(Vector3.yAxis).Unit
    local params=worldParams()
    local from=t.r.Position;local to=nil
    for _,d in {away,(away+side*.7).Unit,(away-side*.7).Unit,side,-side} do
        for _,dist in {cfg.Distance,cfg.Distance*.66} do
            to=safeSpot(from,from+d*dist,params,t.m);if to then break end
        end
        if to then break end
    end
    t.m:SetAttribute("ItachiCrowUntil",n+cfg.Total)
    t.m:SetAttribute("ItachiGuardUntil",math.max(t.m:GetAttribute("ItachiGuardUntil") or 0,n+cfg.Total)) -- the cancelled hit's push/grab
    ctx.fx:FireAllClients("ItachiCrow",{owner=victim.UserId,start=n,from=from,to=to or from,moved=to~=nil,attacker=attacker and attacker.Position or nil})
    if to then
        local m,generation=t.m,ctx.states[victim] and ctx.states[victim].generation
        local rotation=t.r.CFrame.Rotation
        task.delay(cfg.MoveFrom+(cfg.MoveTo-cfg.MoveFrom)*.5,function()
            local s=ctx.states[victim]
            if not s or s.generation~=generation or victim.Character~=m or not alive(t) then return end
            t.r.AssemblyLinearVelocity=Vector3.zero
            m:PivotTo(CFrame.new(to)*rotation)
        end)
    end
    return true
end

---------------------------------------------------------------- Q: Tsukuyomi
local function releaseBind(p,reason)
    local b=binds[p];if not b then return end
    binds[p]=nil
    local m=b.t.m
    if m.Parent then
        if (m:GetAttribute("ItachiTsukuyomiUntil") or 0)>0 then m:SetAttribute("ItachiTsukuyomiUntil",0) end
        if not isSealed(m,now()) then m:SetAttribute("ItachiHeldUntil",0) end
        if b.t.h.Parent then ctx.updateSpeed(m,b.t.h) end
    end
    ctx.fx:FireAllClients("ItachiTsukuyomiEnd",{owner=p.UserId,target=m,reason=reason})
end
local function tsukuyomi(p,s,m,h,r,aim,aimOrigin)
    local cfg=I.Tsukuyomi;local n=now()
    local head=m:FindFirstChild("Head")
    local origin=head and head.Position or r.Position+Vector3.yAxis*1.5
    if typeof(aimOrigin)=="Vector3" and (aimOrigin-origin).Magnitude<=12 then origin=aimOrigin end
    local params=worldParams()
    local best,bestAngle=nil,math.rad(cfg.Angle)
    for _,t in ctx.targets(m) do
        local to=headOf(t)-origin;local dist=to.Magnitude
        if dist<=cfg.Range and dist>.5 and not isSealed(t.m,n) and (t.m:GetAttribute("ItachiTsukuyomiUntil") or 0)<=n then
            local angle=math.acos(math.clamp(to.Unit:Dot(aim),-1,1))
            if angle<=bestAngle and lineOfSight(origin,headOf(t),params) then best=t;bestAngle=angle end
        end
    end
    if not best then
        s.cooldowns.Tsukuyomi=n+cfg.FailCooldown
        ctx.fx:FireClient(p,"ItachiTsukuyomiFail",{owner=p.UserId})
        return
    end
    s.cooldowns.Tsukuyomi=n+cfg.Cooldown;s.busyUntil=n+cfg.Busy
    m:SetAttribute("ItachiCastSpeed",cfg.CasterSpeed);m:SetAttribute("ItachiCastSpeedUntil",n+cfg.End)
    local t=best;local generation=s.generation
    binds[p]={t=t,start=n}
    ctx.fx:FireAllClients("ItachiTsukuyomi",{owner=p.UserId,target=t.m,start=n})
    task.delay(cfg.Eye,function()
        if binds[p]==nil or binds[p].t~=t then return end
        if not stillCaster(p,s,m,generation) or not alive(t) then releaseBind(p,"lost");return end
        t.m:SetAttribute("ItachiTsukuyomiUntil",n+cfg.End)
        t.m:SetAttribute("ItachiHeldUntil",math.max(t.m:GetAttribute("ItachiHeldUntil") or 0,n+cfg.End))
        ctx.updateSpeed(t.m,t.h)
    end)
    task.delay(cfg.Wave,function()
        if binds[p]==nil or binds[p].t~=t then return end
        if not stillCaster(p,s,m,generation) or not alive(t) then releaseBind(p,"lost");return end
        ctx.damage(p,t,cfg.Damage,"Genjutsu")
    end)
    task.delay(cfg.End,function() if binds[p] and binds[p].t==t then releaseBind(p,"done") end end)
end

---------------------------------------------------------------- E: Amaterasu
-- The flame edge is irregular; clients draw the same shape from the same seed.
function Itachi.edge(seed,angle)
    return .82+.1*math.sin(angle*3+seed)+.06*math.sin(angle*7+seed*2.3)+.04*math.sin(angle*13+seed*.7)
end
local function fieldRadius(f,age)
    local cfg=I.Amaterasu
    if age<cfg.Ignite then return 0 end
    if age<cfg.Spread then return cfg.StartRadius end
    if age<cfg.BurnEnd then return cfg.StartRadius+(cfg.Radius-cfg.StartRadius)*smoothstep((age-cfg.Spread)/(cfg.Full-cfg.Spread)) end
    return cfg.Radius*(1-smoothstep((age-cfg.BurnEnd)/(cfg.Gone-cfg.BurnEnd)))
end
local function amaterasu(p,s,m,h,r,aim,aimOrigin)
    local cfg=I.Amaterasu;local n=now()
    local head=m:FindFirstChild("Head")
    local origin=head and head.Position or r.Position+Vector3.yAxis*1.5
    if typeof(aimOrigin)=="Vector3" and (aimOrigin-origin).Magnitude<=12 then origin=aimOrigin end
    -- Characters are not excluded: a body in the centre of the screen blocks the floor behind it.
    local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={m};params.RespectCanCollide=true
    local hit=workspace:Raycast(origin,aim*cfg.Range,params)
    local reason=nil
    if not hit then reason="range"
    else
        local model=hit.Instance:FindFirstAncestorOfClass("Model")
        if model and model:FindFirstChildOfClass("Humanoid") then reason="blocked"
        elseif hit.Normal.Y<math.cos(math.rad(cfg.MaxSlope)) then reason="wall" end
    end
    if reason then
        s.cooldowns.Amaterasu=n+cfg.FailCooldown
        ctx.fx:FireClient(p,"ItachiAmaterasuFail",{owner=p.UserId,reason=reason})
        return
    end
    s.cooldowns.Amaterasu=n+cfg.Cooldown;s.busyUntil=n+cfg.Busy
    m:SetAttribute("ItachiCastSpeed",cfg.CasterSpeed);m:SetAttribute("ItachiCastSpeedUntil",n+cfg.Spread)
    local seed=rng:NextNumber(0,math.pi*2)
    local f={owner=p,ownerModel=m,center=hit.Position,start=n,seed=seed,hits={},params=worldParams()}
    table.insert(fields,f)
    ctx.fx:FireAllClients("ItachiAmaterasu",{owner=p.UserId,center=hit.Position,normal=hit.Normal,start=n,seed=seed})
end
-- Inside: within the irregular edge, not behind a wall from the centre, feet on (or within the flame height of)
-- floor that belongs to the field (slopes and steps up to StepHeight). Airborne bodies above the flames are safe.
local function insideField(f,t,radius)
    local cfg=I.Amaterasu
    local d=t.r.Position-f.center
    local horizontal=Vector3.new(d.X,0,d.Z)
    if horizontal.Magnitude>radius*Itachi.edge(f.seed,math.atan2(d.Z,d.X)) then return false end
    local floor=groundBelow(t.r.Position,f.params,40)
    local feet=t.r.Position.Y-hipOf(t)
    if not floor or math.abs(floor.Position.Y-f.center.Y)>cfg.StepHeight then return false end
    if feet-floor.Position.Y>cfg.FlameHeight then return false end
    local from=f.center+Vector3.yAxis*1.5
    local to=Vector3.new(t.r.Position.X,floor.Position.Y+1.5,t.r.Position.Z)
    return horizontal.Magnitude<1 or lineOfSight(from,to,f.params)
end
local function stepFields(n)
    local cfg=I.Amaterasu
    for i=#fields,1,-1 do
        local f=fields[i];local age=n-f.start
        if age>=cfg.Gone then table.remove(fields,i)
        elseif age>=cfg.Ignite and age<cfg.BurnEnd then
            local radius=fieldRadius(f,age)
            for _,t in ctx.targets(f.ownerModel) do
                if not isSealed(t.m,n) and insideField(f,t,radius) then
                    local h=f.hits[t.m]
                    if not h then
                        h={ticks=0,next=n+cfg.Tick};f.hits[t.m]=h
                        ctx.damage(f.owner,t,cfg.EntryDamage,"DoT")
                    elseif not h.next then h.next=n+cfg.Tick
                    elseif n>=h.next and h.ticks<cfg.MaxTicks then
                        h.ticks+=1;h.next=n+cfg.Tick
                        ctx.damage(f.owner,t,cfg.TickDamage,"DoT")
                    end
                    t.m:SetAttribute("ItachiSlowUntil",n+.25)
                    t.m:SetAttribute("ItachiBurnUntil",n+.3)
                elseif f.hits[t.m] then f.hits[t.m].next=nil end   -- ticks stop while outside
            end
        end
    end
end

---------------------------------------------------------------- R: Susanoo
local function handPoint(u)
    return (u.base*CFrame.new(I.Susanoo.Hand)).Position
end
local function freeVictim(model,position)
    local v=sealed[model];if not v then return end
    sealed[model]=nil
    if v.align then v.align:Destroy() end
    if v.attachment then v.attachment:Destroy() end
    if model.Parent then
        model:SetAttribute("ItachiSealedUntil",0);model:SetAttribute("ItachiHeldUntil",0)
        if position and v.t.r.Parent then v.t.r.AssemblyLinearVelocity=Vector3.zero;model:PivotTo(CFrame.new(position)*v.rotation) end
        if v.t.h.Parent then ctx.updateSpeed(model,v.t.h) end
    end
end
local function moveVictim(v,position)
    if v.t.r.Anchored then v.t.r.CFrame=CFrame.new(position)*v.rotation
    elseif v.align then v.align.Position=position end
end
local function captureVictim(u,t)
    local v={t=t,owner=u.p,home=t.r.Position,rotation=t.r.CFrame.Rotation}
    ctx.flights[t.m]=nil;ctx.doraKnockbacks[t.m]=nil
    if not t.r.Anchored then
        local attachment=Instance.new("Attachment");attachment.Name="ItachiSealAttachment";attachment.Parent=t.r
        local align=Instance.new("AlignPosition");align.Name="ItachiSeal";align.Mode=Enum.PositionAlignmentMode.OneAttachment
        align.Attachment0=attachment;align.Position=t.r.Position;align.MaxForce=math.max(30000,t.r.AssemblyMass*workspace.Gravity*30)
        align.MaxVelocity=120;align.Responsiveness=60;align.Parent=t.r
        v.attachment=attachment;v.align=align
    end
    sealed[t.m]=v
    -- A Tsukuyomi bind on the same body yields to the seal.
    for caster,b in binds do if b.t.m==t.m then releaseBind(caster,"sealed") end end
    return v
end
-- Back on safe ground: where it was struck, else in front of the caster, else beside the caster.
local function releaseSpot(u,v)
    local params=worldParams()
    local home=v.home
    local floor=groundBelow(home,params,30)
    if floor then
        local spot=Vector3.new(home.X,floor.Position.Y+hipOf(v.t),home.Z)
        local overlap=OverlapParams.new();overlap.FilterType=Enum.RaycastFilterType.Exclude;overlap.FilterDescendantsInstances=params.FilterDescendantsInstances;overlap.RespectCanCollide=true
        if #workspace:GetPartBoundsInBox(CFrame.new(spot),Vector3.new(2.4,4.4,2.4),overlap)==0 then return spot end
    end
    local front=u.base.Position+u.direction*6
    local f2=groundBelow(front,params,30)
    if f2 then return Vector3.new(front.X,f2.Position.Y+hipOf(v.t),front.Z) end
    return u.base.Position+u.direction*3
end
local function endUltra(p,reason)
    local u=ultras[p];if not u then return end
    ultras[p]=nil
    local m=u.model
    if m.Parent then
        for _,attribute in {"ItachiGuardUntil","ItachiMirrorUntil","ItachiLockUntil"} do m:SetAttribute(attribute,0) end
        if u.h.Parent then ctx.updateSpeed(m,u.h) end
    end
    if u.victim then
        local v=sealed[u.victim.t.m]
        if v then freeVictim(u.victim.t.m,alive(v.t) and releaseSpot(u,v) or nil) end
    end
    ctx.fx:FireAllClients("ItachiSusanooEnd",{owner=p.UserId,reason=reason})
end
local function firstAhead(m,origin,direction,reach,width,params)
    local best,bestAlong=nil,math.huge
    for _,t in ctx.targets(m) do
        local rel=t.r.Position-origin;local along=rel:Dot(direction)
        local side=Vector3.new(rel.X,0,rel.Z)-direction*along
        if along>0 and along<=reach and side.Magnitude<=width and math.abs(rel.Y)<10 and along<bestAlong and not isSealed(t.m,now())
            and lineOfSight(origin,t.r.Position,params) then best=t;bestAlong=along end
    end
    return best
end
local function susanoo(p,s,m,h,r,aim)
    local cfg=I.Susanoo;local n=now()
    s.cooldowns.Susanoo=n+cfg.Cooldown;s.busyUntil=n+cfg.End
    local direction=flat(aim,flat(r.CFrame.LookVector))
    local base=CFrame.lookAt(r.Position,r.Position+direction)
    m:SetAttribute("ItachiLockUntil",n+cfg.End)
    m:SetAttribute("ItachiGuardUntil",math.max(m:GetAttribute("ItachiGuardUntil") or 0,n+cfg.End))
    m:SetAttribute("ItachiMirrorFrom",n+cfg.Mirror);m:SetAttribute("ItachiMirrorUntil",n+cfg.MirrorBreak)
    ctx.updateSpeed(m,h)
    ultras[p]={p=p,s=s,model=m,h=h,r=r,start=n,direction=direction,base=base,generation=s.generation,flags={}}
    ctx.fx:FireAllClients("ItachiSusanoo",{owner=p.UserId,start=n,direction=direction,position=r.Position})
end
-- One smash: every character in the frontal arc, within range and height, in sight and not sealed, is hit once.
local function smash(p,u,i,strike)
    local cfg=I.Susanoo
    local origin=u.r.Position;local params=worldParams()
    local hits={}
    for _,t in ctx.targets(u.model) do
        local rel=t.r.Position-origin;local planar=Vector3.new(rel.X,0,rel.Z)
        if planar.Magnitude<=cfg.StrikeRange and math.abs(rel.Y)<=cfg.StrikeHeight and not isSealed(t.m,now())
            and (planar.Magnitude<1 or planar.Unit:Dot(u.direction)>=math.cos(math.rad(strike.Arc)))
            and lineOfSight(origin+Vector3.yAxis*2,t.r.Position,params) then
            ctx.damage(p,t,strike.Damage,"Ultimate")
            if alive(t) then
                local out=planar.Magnitude>1 and planar.Unit or u.direction
                ctx.launch(t,out*strike.Out+Vector3.yAxis*strike.Up)
            end
            table.insert(hits,t.m)
        end
    end
    ctx.fx:FireAllClients("ItachiSusanooSmash",{owner=p.UserId,start=u.start,index=i,targets=hits,
        point=origin+u.direction*(i==3 and 10 or 12)})
end
local function stepUltra(p,u,n)
    local cfg=I.Susanoo;local a=n-u.start
    if not stillCaster(p,u.s,u.model,u.generation) or u.h.Health<=0 then endUltra(p,"caster");return end
    if a>=cfg.End then endUltra(p,"done");return end
    local f=u.flags
    for i,strike in cfg.Strikes do
        if a>=strike.Time and not f["smash"..i] then f["smash"..i]=true;smash(p,u,i,strike) end
    end
    if a>=cfg.Thrust and not f.pick then
        f.pick=true
        local origin=u.r.Position
        u.target=firstAhead(u.model,origin,u.direction,cfg.Reach,cfg.Width,worldParams())
        ctx.fx:FireAllClients("ItachiSusanooThrust",{owner=p.UserId,start=u.start,target=u.target and u.target.m or nil})
    end
    if a>=cfg.Tip and not f.tip then
        f.tip=true
        local t=u.target
        if t and alive(t) and (t.r.Position-u.r.Position).Magnitude<=cfg.Reach+5 then
            local point=t.r.Position
            ctx.damage(p,t,cfg.Damage1,"Ultimate")
            if alive(t) then
                u.victim=captureVictim(u,t)
                t.m:SetAttribute("ItachiHeldUntil",u.start+cfg.Seal+cfg.SealFor+.1);ctx.updateSpeed(t.m,t.h)
            end
            ctx.fx:FireAllClients("ItachiSusanooHit",{owner=p.UserId,target=t.m,point=point,start=u.start})
        else
            u.target=nil
            ctx.fx:FireAllClients("ItachiSusanooMiss",{owner=p.UserId,start=u.start})
        end
    end
    local v=u.victim
    if v then
        local t=v.t
        if not alive(t) then freeVictim(t.m,nil);u.victim=nil;return end
        local hand=handPoint(u)
        local tip=v.home+Vector3.yAxis*1.5
        local into=hand:Lerp(tip,cfg.SealPoint)
        local lift=smoothstep((a-cfg.Tip)/(cfg.StrikeEnd-cfg.Tip))
        local draw=smoothstep((a-cfg.StrikeEnd)/(cfg.Seal-cfg.StrikeEnd))
        local suck=smoothstep((a-cfg.Seal)/(cfg.SealEnd-cfg.Seal))
        local pos=(v.home+Vector3.yAxis*cfg.LiftHeight*lift):Lerp(into,draw*.45)
        pos=pos:Lerp(into,suck)
        moveVictim(v,pos)
        if a>=cfg.SealHit and not f.d2 then f.d2=true;ctx.damage(p,t,cfg.Damage2,"Ultimate") end
        if a>=cfg.SealEnd and not f.gone and alive(t) then
            f.gone=true
            t.m:SetAttribute("ItachiSealedUntil",u.start+cfg.Seal+cfg.SealFor)
            ctx.fx:FireAllClients("ItachiSusanooSealed",{owner=p.UserId,target=t.m,point=into})
        end
    end
end
local function stepSealed(n)
    for model,v in sealed do
        if not model.Parent or not v.t.r.Parent then sealed[model]=nil
        elseif not ultras[v.owner] then freeVictim(model,alive(v.t) and v.home or nil) end
    end
end

---------------------------------------------------------------- loop
RunService.Heartbeat:Connect(function()
    if not ctx then return end
    local n=now()
    stepFields(n)
    for p,u in ultras do stepUltra(p,u,n) end
    stepSealed(n)
end)
Players.PlayerRemoving:Connect(function(p)
    releaseBind(p,"left");endUltra(p,"left");crowReady[p]=nil
    for i=#fields,1,-1 do if fields[i].owner==p then table.remove(fields,i) end end
end)

---------------------------------------------------------------- hooks used by Combat
function Itachi.init(context) ctx=context end
function Itachi.handles(skill) return KIT[skill]==true end
function Itachi.speedFactor(m,n)
    local factor=1
    if (m:GetAttribute("ItachiSlowUntil") or 0)>n then factor*=I.Amaterasu.Slow end
    if (m:GetAttribute("ItachiCastSpeedUntil") or 0)>n then factor*=m:GetAttribute("ItachiCastSpeed") or 1 end
    if (m:GetAttribute("ItachiLockUntil") or 0)>n then factor=0 end
    return factor
end
function Itachi.held(m,n) return (m:GetAttribute("ItachiHeldUntil") or 0)>n or isSealed(m,n) end
function Itachi.noJump(m,n) return Itachi.held(m,n) or (m:GetAttribute("ItachiLockUntil") or 0)>n end
-- Susanoo's Yata Mirror: hits from the front lose 60%. Clients show a red ripple on the mirror.
function Itachi.damageFactor(attacker,victim,kind)
    local n=now()
    if (victim:GetAttribute("ItachiMirrorUntil") or 0)<=n or (victim:GetAttribute("ItachiMirrorFrom") or math.huge)>n then return 1 end
    local vr=victim:FindFirstChild("HumanoidRootPart");local ar=attacker and attacker:FindFirstChild("HumanoidRootPart")
    if not vr or not ar then return 1 end
    local to=flat(ar.Position-vr.Position);local facing=flat(vr.CFrame.LookVector)
    if to:Dot(facing)<math.cos(math.rad(I.Susanoo.MirrorArc)) then return 1 end
    local owner=Players:GetPlayerFromCharacter(victim)
    if owner then ctx.fx:FireAllClients("ItachiMirrorHit",{owner=owner.UserId,from=ar.Position}) end
    return 1-I.Susanoo.MirrorReduction
end
-- Susanoo (and a crow clone mid-dodge) is not staggered.
function Itachi.filterKnockback(victim,velocity)
    if (victim:GetAttribute("ItachiGuardUntil") or 0)>now() then return nil end
    return velocity
end
function Itachi.guarded(model) return (model:GetAttribute("ItachiGuardUntil") or 0)>now() end
-- Called by Combat after the request passed its own checks (kit, rate limit, domain lock, alive, not held).
function Itachi.request(p,s,m,h,r,skill,aim,aimOrigin)
    local n=now()
    if s.busyUntil>n or s.slide or (m:GetAttribute("RootedUntil") or 0)>n or (m:GetAttribute("ItachiCrowUntil") or 0)>n then return end
    if (s.cooldowns[skill] or 0)>n then return end
    s.basicUntil=0
    if skill=="Tsukuyomi" then tsukuyomi(p,s,m,h,r,aim,aimOrigin)
    elseif skill=="Amaterasu" then amaterasu(p,s,m,h,r,aim,aimOrigin)
    elseif skill=="Susanoo" then susanoo(p,s,m,h,r,aim) end
    ctx.sendState(p,s)
end
-- Character change, respawn or death: every bind, field, Susanoo and seal this player owns ends at once.
function Itachi.reset(p)
    releaseBind(p,"reset");endUltra(p,"reset")
    for i=#fields,1,-1 do
        if fields[i].owner==p then ctx.fx:FireAllClients("ItachiAmaterasuEnd",{owner=p.UserId,start=fields[i].start});table.remove(fields,i) end
    end
    for model,v in sealed do if v.owner==p then freeVictim(model,alive(v.t) and v.home or nil) end end
    local m=p.Character
    if m then
        for _,attribute in {"ItachiCrowUntil","ItachiGuardUntil","ItachiMirrorUntil","ItachiMirrorFrom","ItachiLockUntil","ItachiCastSpeedUntil"} do m:SetAttribute(attribute,0) end
    end
end
return Itachi
