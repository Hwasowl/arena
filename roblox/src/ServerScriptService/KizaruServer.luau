-- Costs, committed aim, collision and every hit are server-authoritative.
local C=require(game:GetService("ReplicatedStorage"):WaitForChild("GojoConfig"))
local Run=game:GetService("RunService")
local M={};local ctx;local active={}
local skills={LightLaser=true,LightKick=true,LightJewels=true,LightMirror=true}
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
local function beam(p,a,offset,spread)
    if not valid(p,a) then return end
    local cfg=C[a.skill];local origin=a.r.Position+Vector3.yAxis*1.3+offset;local dir=(a.aim+spread).Unit
    local wall=workspace:Raycast(origin,dir*cfg.Range,params(a.m,true));local distance=wall and wall.Distance or cfg.Range
    emit(p,"Beam",{position=origin,direction=dir,distance=distance,skill=a.skill})
    for _,t in ctx.targets(a.m) do
        local delta=t.r.Position-origin;local along=delta:Dot(dir)
        if along>0 and along<distance and (delta-dir*along).Magnitude<cfg.Width then
            local hit=workspace:Raycast(origin,t.r.Position-origin,params(a.m,false))
            if not hit or hit.Instance:IsDescendantOf(t.m) then
                ctx.damage(p,t,cfg.Damage,a.skill)
                if a.skill=="LightKick" then ctx.launch(t,dir*55+Vector3.yAxis*16) end
            end
        end
    end
end
function M.request(p,s,m,h,r,skill,aim)
    local cfg=C[skill];local n=ctx.clock()
    if not cfg or s.busyUntil>n or s.slide or s.hold or s.energy<cfg.Cost or (s.cooldowns[skill] or 0)>n or (m:GetAttribute("RootedUntil") or 0)>n then return end
    local flat=Vector3.new(aim.X,0,aim.Z);if skill=="LightMirror" and flat.Magnitude<.01 then return end
    s.energy-=cfg.Cost;s.cooldowns[skill]=n+cfg.Cooldown;s.busyUntil=n+cfg.Duration
    local a={s=s,m=m,r=r,skill=skill,aim=aim,generation=s.generation,untilTime=n+cfg.Duration};active[p]=a
    m:SetAttribute("KizaruCastUntil",a.untilTime);ctx.updateSpeed(m,h)
    emit(p,"Cast",{skill=skill,start=n,duration=cfg.Duration,position=r.Position,direction=aim})
    if skill=="LightJewels" then
        for i=0,11 do task.delay(cfg.Windup+i*.085,function() beam(p,a,Vector3.new(i%2==0 and -.38 or .38,.25,0),Vector3.new(math.sin(i*2.4)*.055,math.cos(i*2.4)*.035,0)) end) end
    elseif skill=="LightMirror" then
        task.delay(cfg.Windup,function()
            if not valid(p,a) then return end
            local dir=flat.Unit;local origin=r.Position
            local hit=workspace:Blockcast(r.CFrame,Vector3.new(3,4,3),dir*cfg.Range,params(m,false))
            local distance=hit and math.max(0,hit.Distance-.6) or cfg.Range
            r.CFrame+=dir*distance;r.AssemblyLinearVelocity=Vector3.zero
            emit(p,"Beam",{skill=skill,position=origin,direction=dir,distance=distance})
        end)
    else task.delay(cfg.Windup,function() beam(p,a,Vector3.zero,Vector3.zero) end) end
    ctx.sendState(p,s)
end
function M.reset(p)
    active[p]=nil;local m=p.Character
    if m then m:SetAttribute("KizaruCastUntil",0);local h=m:FindFirstChildOfClass("Humanoid");if h and ctx then ctx.updateSpeed(m,h) end end
    if ctx then emit(p,"End",{}) end
end
Run.Heartbeat:Connect(function()
    if not ctx then return end
    for p,a in active do if not valid(p,a) or ctx.clock()>=a.untilTime then
        if ctx.states[p]==a.s then a.s.busyUntil=math.min(a.s.busyUntil,ctx.clock()) end
        M.reset(p)
    end end
end)
return M
