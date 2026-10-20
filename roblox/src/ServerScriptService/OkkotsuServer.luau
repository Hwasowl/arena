-- All targeting, costs, hit windows and cancellation are authoritative here.
local RS=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
local K=require(RS:WaitForChild("OkkotsuConfig"))
local O={};local ctx;local active={};local known={}
for _,name in K.Kit do known[name]=true end
local function interrupted(p,a)
    local m,h=ctx.character(p)
    local n=ctx.clock()
    return ctx.states[p]~=a.s or a.s.generation~=a.generation or m~=a.m or not h or ctx.kitOf(p)~="Okkotsu"
        or (m:GetAttribute("DomainLockedUntil") or 0)>n or (m:GetAttribute("PainHeldUntil") or 0)>n
        or ctx.held(m,n)
end
local function sight(m,from,toward,target)
    local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={m};params.RespectCanCollide=true
    local hit=workspace:Raycast(from,toward-from,params)
    return not hit or (target and hit.Instance:IsDescendantOf(target))
end
local function emit(p,kind,data)
    data.owner=p.UserId;ctx.fx:FireAllClients("Okkotsu"..kind,data)
end
local function valid(p,a) return active[p]==a and not interrupted(p,a) end
local function hit(p,t,amount)
    local before=t.h.Health;ctx.damage(p,t,amount,"Okkotsu")
    return t.h.Health<before
end
local function eye(r) return r.Position+Vector3.yAxis*1.3 end
local function flatAim(aim)
    local v=Vector3.new(aim.X,0,aim.Z)
    return v.Magnitude>.01 and v.Unit or Vector3.new(0,0,-1)
end
local function findTarget(m,r,aim)
    local best,score=nil,math.huge;local forward=flatAim(aim)
    for _,t in ctx.targets(m) do
        local raw=t.r.Position-r.Position;local delta=Vector3.new(raw.X,0,raw.Z);local d=delta.Magnitude
        local dot=d>.01 and delta.Unit:Dot(forward) or 1
        if d<=K.RikaStrike.Range and dot>=math.cos(math.rad(K.RikaStrike.AimAngle)) and dot>0 and d<score and sight(m,eye(r),t.r.Position,t.m) then best=t;score=d end
    end
    return best
end
function O.init(c) ctx=c end
function O.handles(skill) return known[skill]==true end
function O.request(p,s,m,h,r,skill,aim)
    local n=ctx.clock();local cfg=K[skill]
    if not cfg or s.busyUntil>n or s.slide or (s.cooldowns[skill] or 0)>n or s.energy<cfg.Cost or (m:GetAttribute("RootedUntil") or 0)>n then return end
    local duration=cfg.Duration or cfg.Windup+cfg.Recovery
    local a={s=s,m=m,r=r,generation=s.generation,skill=skill,untilTime=n+duration,aim=aim,position=eye(r)}
    if skill=="ReverseCursed" and h.Health>=h.MaxHealth then return end
    s.energy-=cfg.Cost;s.cooldowns[skill]=n+cfg.Cooldown;s.busyUntil=n+duration
    active[p]=a
    m:SetAttribute("OkkotsuCastUntil",n+duration);m:SetAttribute("OkkotsuSpeed",skill=="PureLove" and .25 or .55);ctx.updateSpeed(m,h)
    emit(p,"Cast",{skill=skill,start=n,duration=duration,position=a.position,direction=aim})
    if skill=="ReverseCursed" then
        task.delay(cfg.Windup,function()
            if not valid(p,a) then return end
            local before=h.Health
            h.Health=math.min(h.MaxHealth,h.Health+h.MaxHealth*cfg.Heal)
            m:SetAttribute("OkkotsuWeakenedUntil",ctx.clock()+cfg.WeakenDuration)
            emit(p,"Heal",{position=eye(r),healed=h.Health-before,untilTime=ctx.clock()+cfg.WeakenDuration})
            ctx.sendState(p,s)
        end)
    elseif skill=="RikaStrike" then
        local target=findTarget(m,r,aim);a.target=target
        task.delay(cfg.Commit,function()
            if not valid(p,a) then return end
            -- Open a nearby rift first; the committed target can still move out before the swing lands.
            local center=target and target.m.Parent and target.r.Position+Vector3.yAxis*1.1 or r.Position+flatAim(aim)*cfg.Range
            local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={m};params.RespectCanCollide=true
            local wall=workspace:Raycast(eye(r),center-eye(r),params)
            if wall and (not target or not wall.Instance:IsDescendantOf(target.m)) then center=wall.Position-flatAim(aim)*.5;a.target=nil end
            local forward=flatAim(aim)
            local right=forward:Cross(Vector3.yAxis).Unit
            local portal=eye(r)+forward*2.1+right*1.35+Vector3.yAxis*1.4
            a.center=center;a.portal=portal
            emit(p,"Mark",{position=center,portal=portal,direction=forward,delay=cfg.Windup-cfg.Commit})
        end)
        task.delay(cfg.Windup,function()
            if not valid(p,a) or not a.center then return end
            emit(p,"Claw",{position=a.center,portal=a.portal,direction=flatAim(aim)})
            local t=a.target;local forward=flatAim(aim)
            if t and t.m.Parent and t.h.Health>0 then
                local raw=t.r.Position-r.Position;local delta=Vector3.new(raw.X,0,raw.Z);local d=delta.Magnitude;local dot=d>.01 and delta.Unit:Dot(forward) or 1
                if d<=cfg.Range and dot>=math.cos(math.rad(cfg.AimAngle)) and dot>0 and sight(m,eye(r),t.r.Position,t.m) then
                    if hit(p,t,cfg.Damage) then local left=Vector3.yAxis:Cross(forward).Unit;ctx.launch(t,left*cfg.Knockback+Vector3.yAxis*cfg.Lift) end
                end
            end
        end)
    else
        task.delay(cfg.LockAt,function()
            if valid(p,a) then a.position=eye(r);emit(p,"Lock",{position=a.position,direction=aim,delay=cfg.Windup-cfg.LockAt}) end
        end)
        task.delay(cfg.Windup,function()
            if not valid(p,a) then return end
            local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.RespectCanCollide=true
            local exclude={m};for _,t in ctx.targets(m) do table.insert(exclude,t.m) end;params.FilterDescendantsInstances=exclude
            local wall=workspace:Raycast(a.position,aim*cfg.Range,params)
            local distance=wall and wall.Distance or cfg.Range
            emit(p,"Beam",{position=a.position,direction=aim,distance=distance})
            for _,t in ctx.targets(m) do
                local delta=t.r.Position-a.position;local along=delta:Dot(aim)
                if along>0 and along<distance and (delta-aim*along).Magnitude<cfg.Width/2+1 and sight(m,a.position,t.r.Position,t.m) then
                    if hit(p,t,cfg.Damage) then ctx.launch(t,aim*45+Vector3.yAxis*14) end
                end
            end
        end)
    end
    ctx.sendState(p,s)
end
local function finish(p,fullReset)
    local a=active[p];active[p]=nil
    local m=p.Character
    if m then if fullReset then m:SetAttribute("OkkotsuWeakenedUntil",0) end;m:SetAttribute("OkkotsuCastUntil",0);local h=m:FindFirstChildOfClass("Humanoid");if h then ctx.updateSpeed(m,h) end end
    if a then emit(p,"End",{skill=a.skill}) end
end
function O.reset(p) finish(p,true) end
function O.damageFactor(attacker)
    return attacker and (attacker:GetAttribute("OkkotsuWeakenedUntil") or 0)>ctx.clock() and K.ReverseCursed.DamageFactor or 1
end
Run.Heartbeat:Connect(function()
    if not ctx then return end
    for p,a in active do
        if interrupted(p,a) or ctx.clock()>=a.untilTime then
            if ctx.states[p]==a.s then a.s.busyUntil=math.min(a.s.busyUntil,ctx.clock()) end
            finish(p,false)
        end
    end
end)
return O
