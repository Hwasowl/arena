-- Costs, committed aim, collision and every hit are server-authoritative.
-- LightKick: gather light -> light-speed rush -> kick that blows the target away.
-- LightJewels: crouch -> leap high -> volley from the air -> fall back down.
local C=require(game:GetService("ReplicatedStorage"):WaitForChild("GojoConfig"))
local Run=game:GetService("RunService")
local M={};local ctx;local active={}
local skills={LightLaser=true,LightKick=true,LightJewels=true,LightMirror=true}
local DASH_TIME=.05
function M.init(c) ctx=c end
function M.handles(skill) return skills[skill]==true end
local function emit(p,kind,data) data.owner=p.UserId;ctx.fx:FireAllClients("Kizaru"..kind,data) end
local function valid(p,a)
    local m,h=ctx.character(p);local n=ctx.clock()
    return active[p]==a and ctx.states[p]==a.s and a.generation==a.s.generation and m==a.m and h and ctx.kitOf(p)=="Kizaru"
        and (m:GetAttribute("DomainLockedUntil") or 0)<=n and (m:GetAttribute("PainHeldUntil") or 0)<=n and not ctx.held(m,n)
end
local function params(m,excludeTargets)
    local rp=RaycastParams.new();rp.FilterType=Enum.RaycastFilterType.Exclude;rp.RespectCanCollide=true
    local list={m};if excludeTargets then for _,t in ctx.targets(m) do table.insert(list,t.m) end end;rp.FilterDescendantsInstances=list;return rp
end
local function flatOf(v,fallback)
    local f=Vector3.new(v.X,0,v.Z);if f.Magnitude<.01 then f=Vector3.new(fallback.X,0,fallback.Z) end;return f.Unit
end
-- Jewels are fired from the air: steer each shot to the target nearest the committed aim, else angle down at the ground.
local function airAim(a,origin)
    local flat=flatOf(a.aim,a.r.CFrame.LookVector);local best,bestAngle;local cfg=C.LightJewels
    for _,t in ctx.targets(a.m) do
        local d=t.r.Position+Vector3.yAxis-origin
        if d.Magnitude<=cfg.Range then
            local angle=math.acos(math.clamp(flatOf(d,flat):Dot(flat),-1,1))
            if angle<.62 and (not bestAngle or angle<bestAngle) then best=d.Unit;bestAngle=angle end
        end
    end
    return best or (flat*math.cos(.49)-Vector3.yAxis*math.sin(.49)).Unit
end
local function beam(p,a,offset,spread)
    if not valid(p,a) then return end
    local cfg=C[a.skill];local origin=a.r.Position+Vector3.yAxis*1.3+offset
    local base=a.skill=="LightJewels" and airAim(a,origin) or a.aim;local dir=(base+spread).Unit
    local wall=workspace:Raycast(origin,dir*cfg.Range,params(a.m,true));local distance=wall and wall.Distance or cfg.Range
    emit(p,"Beam",{position=origin,direction=dir,distance=distance,skill=a.skill})
    for _,t in ctx.targets(a.m) do
        local delta=t.r.Position-origin;local along=delta:Dot(dir)
        if along>0 and along<distance and (delta-dir*along).Magnitude<cfg.Width then
            local hit=workspace:Raycast(origin,t.r.Position-origin,params(a.m,false))
            if not hit or hit.Instance:IsDescendantOf(t.m) then ctx.damage(p,t,cfg.Damage,a.skill) end
        end
    end
end
-- Rush toward the nearest target in front (or a short way ahead) over DASH_TIME, then kick it away.
local function startDash(p,a)
    if not valid(p,a) then return end
    local cfg=C.LightKick;local r=a.r;local origin=r.Position;local dir=flatOf(a.aim,r.CFrame.LookVector)
    local target,near
    for _,t in ctx.targets(a.m) do
        local d=Vector3.new(t.r.Position.X-origin.X,0,t.r.Position.Z-origin.Z);local along=d:Dot(dir)
        if along>1 and along<cfg.Range and (d-dir*along).Magnitude<cfg.Width and (not near or along<near) then
            local los=workspace:Raycast(origin,t.r.Position-origin,params(a.m,true))
            if not los then target=t;near=along end
        end
    end
    local want=target and math.max(0,near-2.6) or cfg.Range*.35
    local hit=workspace:Blockcast(r.CFrame,Vector3.new(3,4,3),dir*want,params(a.m,true))
    local distance=hit and math.max(0,hit.Distance-.6) or want
    local to=origin+dir*distance
    a.dash={from=r.CFrame,to=CFrame.lookAt(to,to+dir),start=ctx.clock(),dir=dir,target=target}
    emit(p,"Dash",{from=origin,to=to,direction=dir,start=a.dash.start,time=DASH_TIME})
end
local function kick(p,a)
    local cfg=C.LightKick;local d=a.dash;local r=a.r;local hitAny=false
    for _,t in ctx.targets(a.m) do
        local delta=t.r.Position-r.Position;local flat=Vector3.new(delta.X,0,delta.Z);local along=flat:Dot(d.dir)
        if t==d.target or (along>-1 and along<4.5 and (flat-d.dir*along).Magnitude<3 and math.abs(delta.Y)<5) then
            ctx.damage(p,t,cfg.Damage,a.skill);ctx.launch(t,d.dir*95+Vector3.yAxis*55);hitAny=true
        end
    end
    emit(p,"Kick",{position=r.Position+d.dir*2,direction=d.dir,hit=hitAny})
end
local function ceilingHeight(r,m)
    local cfg=C.LightJewels;local hit=workspace:Raycast(r.Position,Vector3.yAxis*cfg.Height,params(m,true))
    return hit and math.max(0,hit.Distance-4) or cfg.Height
end
function M.request(p,s,m,h,r,skill,aim)
    local cfg=C[skill];local n=ctx.clock()
    if not cfg or s.busyUntil>n or s.slide or s.hold or s.energy<cfg.Cost or (s.cooldowns[skill] or 0)>n or (m:GetAttribute("RootedUntil") or 0)>n then return end
    local flat=Vector3.new(aim.X,0,aim.Z);if skill=="LightMirror" and flat.Magnitude<.01 then return end
    s.energy-=cfg.Cost;s.cooldowns[skill]=n+cfg.Cooldown;s.busyUntil=n+cfg.Duration
    local a={s=s,m=m,r=r,skill=skill,aim=aim,generation=s.generation,untilTime=n+cfg.Duration,start=n};active[p]=a
    m:SetAttribute("KizaruCastUntil",a.untilTime);ctx.updateSpeed(m,h)
    emit(p,"Cast",{skill=skill,start=n,duration=cfg.Duration,position=r.Position,direction=aim})
    if skill=="LightJewels" then
        a.groundY=r.Position.Y;a.height=ceilingHeight(r,m)
        task.delay(cfg.Windup,function()
            if valid(p,a) then emit(p,"Rise",{position=r.Position,height=a.height}) end
        end)
        for i=0,11 do task.delay(cfg.Shoot+i*cfg.Gap,function() beam(p,a,Vector3.new(i%2==0 and -.38 or .38,.25,0),Vector3.new(math.sin(i*2.4)*.055,math.cos(i*2.4)*.035,0)) end) end
    elseif skill=="LightMirror" then
        task.delay(cfg.Windup,function()
            if not valid(p,a) then return end
            local dir=flat.Unit;local origin=r.Position
            local hit=workspace:Blockcast(r.CFrame,Vector3.new(3,4,3),dir*cfg.Range,params(m,false))
            local distance=hit and math.max(0,hit.Distance-.6) or cfg.Range
            r.CFrame+=dir*distance;r.AssemblyLinearVelocity=Vector3.zero
            emit(p,"Beam",{skill=skill,position=origin,direction=dir,distance=distance})
        end)
    elseif skill=="LightKick" then task.delay(cfg.Windup,function() startDash(p,a) end)
    else task.delay(cfg.Windup,function() beam(p,a,Vector3.zero,Vector3.zero) end) end
    ctx.sendState(p,s)
end
function M.reset(p)
    active[p]=nil;local m=p.Character
    if m then m:SetAttribute("KizaruCastUntil",0);local h=m:FindFirstChildOfClass("Humanoid");if h and ctx then ctx.updateSpeed(m,h) end end
    if ctx then emit(p,"End",{}) end
end
local function ease(x) x=math.clamp(x,0,1);return x*x*(3-2*x) end
Run.Heartbeat:Connect(function()
    if not ctx then return end
    for p,a in active do
        if not valid(p,a) or ctx.clock()>=a.untilTime then
            if ctx.states[p]==a.s then a.s.busyUntil=math.min(a.s.busyUntil,ctx.clock()) end
            M.reset(p)
        else
            local n=ctx.clock();local r=a.r
            if a.dash and not a.dash.done then
                local u=math.clamp((n-a.dash.start)/DASH_TIME,0,1)
                r.CFrame=a.dash.from:Lerp(a.dash.to,u);r.AssemblyLinearVelocity=Vector3.zero
                if u>=1 then a.dash.done=true;kick(p,a) end
            elseif a.skill=="LightJewels" then
                local cfg=C.LightJewels;local e=n-a.start
                local up=math.clamp((e-cfg.Windup)/cfg.Rise,0,1);local rise=1-(1-up)*(1-up)
                local dn=math.clamp((e-cfg.Hover)/cfg.Fall,0,1)
                local y=a.groundY+a.height*rise*(1-dn*dn)
                if e>=cfg.Windup then
                    local v=r.AssemblyLinearVelocity
                    r.CFrame=CFrame.new(r.Position.X,y,r.Position.Z)*r.CFrame.Rotation;r.AssemblyLinearVelocity=Vector3.new(v.X,0,v.Z)
                    if dn>=1 and not a.landed then a.landed=true;emit(p,"Land",{position=Vector3.new(r.Position.X,a.groundY,r.Position.Z)}) end
                end
            end
        end
    end
end)
return M
