local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local C=require(RS:WaitForChild("GojoConfig"))
local remote=Instance.new("RemoteEvent");remote.Name="GojoAction";remote.Parent=RS
local fx=Instance.new("RemoteEvent");fx.Name="GojoFX";fx.Parent=RS
local selectRemote=Instance.new("RemoteEvent");selectRemote.Name="SelectCharacter";selectRemote.Parent=RS
local states, blues, projectiles, domains, flights={},{},{},{},{}
local kits={}
for name,list in C.Kits do kits[name]={};for _,skill in list do kits[name][skill]=true end end
local function kitOf(p) local name=p:GetAttribute("Character");return kits[name] and name or "Gojo" end
local BASE_SPEED=game:GetService("StarterPlayer").CharacterWalkSpeed
local now=workspace.GetServerTimeNow
local function clock() return now(workspace) end
local function character(p)
    local m=p.Character
    local h=m and m:FindFirstChildOfClass("Humanoid")
    local r=m and m:FindFirstChild("HumanoidRootPart")
    if h and r and h.Health>0 then return m,h,r end
end
local function targets(exclude)
    local out={}
    for _,m in workspace:GetChildren() do
        if m:IsA("Model") and m~=exclude then
            local h=m:FindFirstChildOfClass("Humanoid");local r=m:FindFirstChild("HumanoidRootPart")
            if h and r and h.Health>0 then table.insert(out,{m=m,h=h,r=r}) end
        end
    end
    return out
end
local function sendState(p,s)
    if p.Parent then remote:FireClient(p,{energy=s.energy,cooldowns=s.cooldowns,blueUntil=s.blueUntil or 0,charges=s.charges,chargesUntil=s.chargesUntil,comboUntil=s.comboUntil or 0,anchorUntil=s.anchor and s.anchor.untilTime or 0,holdKind=s.hold and s.hold.kind or "",holdUntil=s.hold and s.hold.untilTime or 0}) end
end
local function validVector(v)
    return typeof(v)=="Vector3" and v.X==v.X and v.Y==v.Y and v.Z==v.Z and v.Magnitude>.9 and v.Magnitude<1.1
end
local function rayParams(m)
    local p=RaycastParams.new();p.FilterType=Enum.RaycastFilterType.Exclude;p.FilterDescendantsInstances={m};return p
end
local function damage(owner,t,amount)
    if not t.m.Parent or t.h.Health<=0 then return end
    t.h:TakeDamage(amount);fx:FireAllClients("Hit",{position=t.r.Position,damage=amount,owner=owner.UserId})
end
local function cancelBlue(p,s)
    s.blueUntil=0
    if blues[p] then blues[p]=nil;fx:FireAllClients("BlueEnd",{owner=p.UserId}) end
end
-- WalkSpeed is derived from timed attributes so overlapping roots and slows never leave a stale speed behind.
local function updateSpeed(m,h)
    local n=clock();local speed=BASE_SPEED
    if (m:GetAttribute("SlowedUntil") or 0)>n then speed*=C.FlameGod.SlowFactor end
    if (m:GetAttribute("RootedUntil") or 0)>n then speed=0 end
    h.WalkSpeed=speed
end
local function setTimed(m,h,attribute,duration)
    m:SetAttribute(attribute,math.max(m:GetAttribute(attribute) or 0,clock()+duration));updateSpeed(m,h)
    task.delay(duration+.05,function() if m.Parent and h.Parent then updateSpeed(m,h) end end)
end
-- Shared by Thunderclap and FlameGod: dash along `flat`, stopping short of walls, and return who stood on the path.
local function dashStrike(m,r,flat,distance,width)
    local start=r.Position
    local result=workspace:Blockcast(r.CFrame,Vector3.new(3,4,3),flat*distance,rayParams(m))
    local travelled=result and math.max(0,result.Distance-.5) or distance
    local finish=start+flat*travelled
    r.CFrame=CFrame.lookAt(finish,finish+flat)
    local victims={}
    for _,t in targets(m) do
        local along=math.clamp((t.r.Position-start):Dot(flat),0,travelled)
        if (start+flat*along-t.r.Position).Magnitude<=width then table.insert(victims,t) end
    end
    return start,finish,victims
end
-- Knockback. Players own their own physics, so their client applies the impulse; anchored training targets
-- follow a server-simulated arc in the Heartbeat loop; any other unanchored rig takes the velocity directly.
local function launch(t,velocity)
    local victim=Players:GetPlayerFromCharacter(t.m)
    if victim then fx:FireClient(victim,"Knockback",{velocity=velocity})
    elseif t.r.Anchored then
        local f=flights[t.m]
        flights[t.m]={t=t,velocity=velocity,ground=f and f.ground or t.r.Position.Y}
    else t.r.AssemblyLinearVelocity=velocity end
end
local function outward(from,t,fallback)
    local delta=t.r.Position-from;delta=Vector3.new(delta.X,0,delta.Z)
    return delta.Magnitude>.1 and delta.Unit or fallback
end
local function devil(m) return (m:GetAttribute("BombDevilUntil") or 0)>clock() end
local function delayed(p,s,m,delaySeconds,callback)
    local generation=s.generation
    task.delay(delaySeconds,function()
        local current=character(p)
        if states[p]==s and generation==s.generation and current==m and (m:GetAttribute("DomainLockedUntil") or 0)<=clock() then callback() end
    end)
end
-- Starts a technique whose cost and cooldown are already paid: windup, busy time, the Cast broadcast, then the effect.
local function perform(p,s,m,h,r,kind,direction,instant)
    local n=clock()
    local windup=instant and C.Thunderclap.InstantWindup or C[kind].Windup or .2
    s.busyUntil=n+(kind=="FlameGod" and C.FlameGod.Duration or kind=="BombDevil" and windup+C.BombDevil.Blackout or windup)
    fx:FireAllClients("Cast",{owner=p.UserId,kind=kind,position=r.Position,direction=direction,start=n,windup=windup})
    if kind=="Blue" then
        cancelBlue(p,s)
        local desired=r.Position+direction*C.Blue.Range
        local result=workspace:Raycast(r.Position,direction*C.Blue.Range,rayParams(m))
        if result then desired=result.Position-direction*2 end
        desired=Vector3.new(desired.X,math.max(2,desired.Y),desired.Z)
        delayed(p,s,m,C.Blue.Windup,function()
            s.blueUntil=clock()+C.Blue.Duration;blues[p]={position=desired,untilTime=s.blueUntil,model=m}
            fx:FireAllClients("Blue",{owner=p.UserId,position=desired,duration=C.Blue.Duration});sendState(p,s)
        end)
    elseif kind=="Red" or kind=="Purple" then
        if kind=="Purple" then h:ChangeState(Enum.HumanoidStateType.Jumping);r.AssemblyLinearVelocity=Vector3.new(r.AssemblyLinearVelocity.X,42,r.AssemblyLinearVelocity.Z) end
        delayed(p,s,m,C[kind].Windup,function()
            local cfgShot=C[kind];local origin=r.Position+direction*3
            local id=tostring(p.UserId)..":"..tostring(clock())
            table.insert(projectiles,{id=id,owner=p,model=m,position=origin,direction=direction,kind=kind,distance=0,hit={}})
            fx:FireAllClients("Projectile",{id=id,owner=p.UserId,position=origin,direction=direction,kind=kind,speed=cfgShot.Speed,range=cfgShot.Range})
        end)
    elseif kind=="Domain" then
        delayed(p,s,m,C.Domain.Windup,function()
            local flat=Vector3.new(direction.X,0,direction.Z)
            if flat.Magnitude<.05 then flat=Vector3.new(0,0,-1) end
            local center=r.Position+flat.Unit*14
            local d={owner=p,model=m,center=center,expires=clock()+C.Domain.Duration,nextTick=clock(),captured={}}
            for _,t in targets(m) do
                if (t.r.Position-center).Magnitude<C.Domain.Radius then
                    table.insert(d.captured,t)
                    t.m:SetAttribute("DomainLockedUntil",math.max(t.m:GetAttribute("DomainLockedUntil") or 0,d.expires))
                end
            end
            table.insert(domains,d)
            fx:FireAllClients("Domain",{owner=p.UserId,position=center,radius=C.Domain.Radius,duration=C.Domain.Duration})
        end)
    elseif kind=="Dash" then
        local flat=Vector3.new(direction.X,0,direction.Z)
        if flat.Magnitude<.05 then flat=r.CFrame.LookVector*Vector3.new(1,0,1) end
        flat=flat.Unit
        local result=workspace:Blockcast(r.CFrame,Vector3.new(3,4,3),flat*C.Dash.Distance,rayParams(m))
        local distance=result and math.max(0,result.Distance-.5) or C.Dash.Distance
        r.CFrame+=flat*distance
    elseif kind=="Thunderclap" then
        local cfg=C.Thunderclap
        local flat=Vector3.new(direction.X,0,direction.Z)
        if flat.Magnitude<.05 then flat=r.CFrame.LookVector*Vector3.new(1,0,1) end
        flat=flat.Unit
        -- Crouched stance: rooted in place during the long windup.
        if windup>.1 then setTimed(m,h,"RootedUntil",windup) end
        delayed(p,s,m,windup,function()
            local start,finish,victims=dashStrike(m,r,flat,cfg.Distance,cfg.Width)
            for _,t in victims do damage(p,t,cfg.Damage) end
            fx:FireAllClients("Thunderclap",{owner=p.UserId,from=start,to=finish})
        end)
    elseif kind=="Breath" then
        delayed(p,s,m,C.Breath.Windup,function()
            s.charges=C.Breath.Charges;s.chargesUntil=clock()+C.Breath.ChargeWindow;sendState(p,s)
            fx:FireAllClients("Strike",{position=r.Position-Vector3.new(0,3,0),big=true})
        end)
    elseif kind=="FlameGod" then
        local cfg=C.FlameGod
        local flat=Vector3.new(direction.X,0,direction.Z)
        if flat.Magnitude<.05 then flat=r.CFrame.LookVector*Vector3.new(1,0,1) end
        flat=flat.Unit
        setTimed(m,h,"RootedUntil",windup)
        delayed(p,s,m,windup,function()
            local start,finish,victims=dashStrike(m,r,flat,cfg.Distance,cfg.Width)
            fx:FireAllClients("FlameGod",{owner=p.UserId,from=start,to=finish})
            -- Too fast to see: the cuts land only after the user is already past.
            task.delay(cfg.HitDelay,function()
                for _,t in victims do damage(p,t,cfg.Damage) end
            end)
            -- Recoil: the legs give out. Self-damage never kills.
            if h.Health>1 then h.Health=math.max(1,h.Health-cfg.SelfDamage) end
            setTimed(m,h,"SlowedUntil",cfg.SlowDuration)
            fx:FireClient(p,"Recoil",{damage=cfg.SelfDamage,duration=cfg.SlowDuration})
        end)
    elseif kind=="BombDevil" then
        local cfg=C.BombDevil
        -- Rooted from the pin pull until her own sight returns.
        setTimed(m,h,"RootedUntil",windup+cfg.Blackout)
        delayed(p,s,m,windup,function()
            local center=r.Position
            -- No time limit: the transformation lasts until Detonation (or death) ends it.
            m:SetAttribute("BombDevilUntil",1e12)
            local healed=math.max(0,math.min(h.MaxHealth,h.Health+h.MaxHealth*cfg.Heal)-h.Health)
            if healed>0 then h.Health+=healed end
            fx:FireAllClients("BombDevil",{owner=p.UserId,position=center+Vector3.new(0,1.5,0),blackout=cfg.Blackout,healed=math.floor(healed+.5)})
            for _,t in targets(m) do
                local distance=(t.r.Position-center).Magnitude
                if distance<=cfg.Radius then
                    damage(p,t,cfg.Damage)
                    local power=1-.5*distance/cfg.Radius
                    launch(t,outward(center,t,r.CFrame.LookVector)*cfg.Knockback*power+Vector3.new(0,cfg.Lift*power,0))
                end
            end
        end)
    elseif kind=="Detonation" then
        local cfg=C.Detonation
        -- The fuse hair burns down for Windup seconds (free to move, other skills locked), then everything goes off.
        delayed(p,s,m,windup,function()
            local center=r.Position
            fx:FireAllClients("Detonation",{owner=p.UserId,position=center,radius=cfg.Radius})
            for _,t in targets(m) do
                local distance=(t.r.Position-center).Magnitude
                if distance<=cfg.Radius then
                    damage(p,t,cfg.Damage)
                    local power=1-.55*distance/cfg.Radius
                    launch(t,outward(center,t,r.CFrame.LookVector)*cfg.Knockback*power+Vector3.new(0,cfg.Lift*power,0))
                end
            end
            -- Back to human; the transformation can be used again after the recharge.
            m:SetAttribute("BombDevilUntil",0)
            s.cooldowns.BombDevil=clock()+C.BombDevil.Recharge
            sendState(p,s)
        end)
    elseif kind=="Rampage" then
        local cfg=C.Rampage
        local flat=Vector3.new(direction.X,0,direction.Z)
        if flat.Magnitude<.05 then flat=r.CFrame.LookVector*Vector3.new(1,0,1) end
        flat=flat.Unit
        delayed(p,s,m,windup,function()
            local start,finish,victims=dashStrike(m,r,flat,cfg.Distance,cfg.Width)
            for _,t in victims do
                damage(p,t,cfg.Damage);launch(t,flat*14+Vector3.new(0,cfg.Launch,0))
            end
            -- Missed everything: she skids on a little further instead of stopping dead.
            local slide=#victims==0
            if slide then r.AssemblyLinearVelocity=flat*cfg.SlideSpeed end
            fx:FireAllClients("Rampage",{owner=p.UserId,from=start,to=finish,delay=cfg.TrailDelay,slide=slide})
            s.comboDir=flat;s.comboUntil=clock()+C.Kick.ComboWindow;sendState(p,s)
            -- The gunpowder left on the path goes off on its own, even if Reze has moved on or died.
            local length=(finish-start).Magnitude
            task.delay(cfg.TrailDelay,function()
                for _,t in targets(m) do
                    local along=math.clamp((t.r.Position-start):Dot(flat),0,length)
                    if (start+flat*along-t.r.Position).Magnitude<=cfg.TrailRadius then
                        damage(p,t,cfg.TrailDamage);launch(t,Vector3.new(0,cfg.TrailLift,0))
                    end
                end
            end)
        end)
    elseif kind=="Anchor" then
        local cfg=C.Anchor
        -- The wire is shot along the crosshair. Level geometry is found with a raycast (floors never hold); enemies are
        -- found by how close the ray passes to them, because training rigs are not collidable. The nearer of the two wins.
        local origin=r.Position+Vector3.new(0,1.5,0)
        local params=rayParams(m);params.RespectCanCollide=true
        local world=workspace:Raycast(origin,direction*cfg.Range,params)
        local limit=world and world.Distance or cfg.Range
        local point,distance,victim
        if world and world.Normal.Y<.85 then point=world.Position;distance=world.Distance end
        for _,t in targets(m) do
            local to=t.r.Position+Vector3.new(0,.5,0)-origin
            local along=to:Dot(direction)
            if along>0 and along<=limit and (distance==nil or along<distance) and (to-direction*along).Magnitude<=3 then
                point=t.r.Position;distance=along;victim=t
            end
        end
        s.reel=nil;s.anchor=nil;s.comboUntil=0
        delayed(p,s,m,cfg.Windup,function()
            if point then
                s.anchor={point=point,victim=victim,untilTime=clock()+cfg.Duration}
            else
                -- Nothing to hold: the gas is gone and the next attempt has to wait.
                s.cooldowns.Anchor=clock()+cfg.MissCooldown
            end
            fx:FireAllClients("Anchor",{owner=p.UserId,from=origin,point=point or origin+direction*cfg.Range,hit=point~=nil,speed=cfg.WireSpeed})
            sendState(p,s)
        end)
    elseif kind=="Reel" then
        local cfg=C.Reel
        local a=s.anchor
        local distance=(a.point-r.Position).Magnitude
        local travel=math.max(.3,(distance-cfg.StopDistance)/(cfg.Speed*.82))
        local untilTime=n+math.min(cfg.MaxTime,travel+.4)
        s.reel={point=a.point,victim=a.victim,untilTime=untilTime}
        -- The Spin window: from the first pull until Grace seconds after the flight ends.
        s.comboUntil=untilTime+C.Spin.Grace
        fx:FireAllClients("Reel",{owner=p.UserId,point=a.point,speed=cfg.Speed,ramp=cfg.Ramp,stop=cfg.StopDistance,maxTime=cfg.MaxTime})
    elseif kind=="Spin" then
        local cfg=C.Spin
        -- The wire is let go; the client keeps the flight's momentum through the whole turn.
        s.reel=nil;s.anchor=nil;s.comboUntil=0
        s.busyUntil=n+windup+cfg.Rotation+cfg.Recovery
        delayed(p,s,m,windup,function()
            fx:FireAllClients("Spin",{owner=p.UserId,position=r.Position,radius=cfg.Radius,rotation=cfg.Rotation})
        end)
        delayed(p,s,m,windup+cfg.Rotation*.9,function()
            local center=r.Position
            local struck=0
            for _,t in targets(m) do
                if (t.r.Position-center).Magnitude<=cfg.Radius then
                    struck+=1
                    damage(p,t,cfg.Damage);launch(t,outward(center,t,r.CFrame.LookVector)*cfg.Knockback+Vector3.new(0,cfg.Lift,0))
                end
            end
            fx:FireAllClients("SpinHit",{owner=p.UserId,position=center,radius=cfg.Radius,struck=struck})
            -- Landing stagger: all that spinning leaves the user rooted for a moment.
            setTimed(m,h,"RootedUntil",cfg.Recovery)
        end)
    elseif kind=="Burst" then
        local cfg=C.Burst
        s.reel=nil;s.anchor=nil;s.comboUntil=0
        fx:FireAllClients("Burst",{owner=p.UserId,position=r.Position,direction=direction})
        fx:FireClient(p,"Impulse",{velocity=direction*cfg.Impulse+Vector3.new(0,cfg.Impulse*cfg.Lift,0)})
    elseif kind=="Kick" then
        local cfg=C.Kick
        -- Combo: Rampage ended moments ago, so the kick keeps flying along its direction.
        local combo=(s.comboUntil or 0)>n and s.comboDir~=nil
        local flat=Vector3.new(direction.X,0,direction.Z)
        if flat.Magnitude<.05 then flat=r.CFrame.LookVector*Vector3.new(1,0,1) end
        flat=combo and s.comboDir or flat.Unit
        s.comboUntil=0
        delayed(p,s,m,windup,function()
            local struck={}
            local from=r.Position
            local center,radius,damageAmount,knock,lift
            if combo then
                local _,finish,victims=dashStrike(m,r,flat,cfg.ComboDistance,cfg.Width)
                for _,t in victims do struck[t.m]=t end
                center=finish+flat*2.5;radius=cfg.ComboRadius;damageAmount=cfg.ComboDamage;knock=cfg.ComboKnockback;lift=cfg.ComboLift
            else
                center=from+flat*cfg.Reach;radius=cfg.Radius;damageAmount=cfg.Damage;knock=cfg.Knockback;lift=cfg.Lift
            end
            for _,t in targets(m) do
                if (t.r.Position-center).Magnitude<=radius then struck[t.m]=t end
            end
            fx:FireAllClients("Kick",{owner=p.UserId,from=from,to=center,combo=combo,radius=radius})
            for _,t in struck do
                damage(p,t,damageAmount);launch(t,flat*knock+Vector3.new(0,lift,0))
            end
        end)
    end
end
remote.OnServerEvent:Connect(function(p,skill,aim)
    local s=states[p];if not s then return end
    local n=clock()
    if n-s.lastRequest<.1 then return end;s.lastRequest=n
    if type(skill)~="string" or not kits[kitOf(p)][skill] or not validVector(aim) then return end
    local m,h,r=character(p);if not m then return end
    if (m:GetAttribute("DomainLockedUntil") or 0)>n then return end
    -- During a hold: the other of Blue/Red fuses both into Purple (paying its own cost), the same one fires at once.
    local hold=s.hold
    if hold and (skill=="Blue" or skill=="Red") then
        if s.busyUntil>n then return end
        if skill~=hold.kind then
            if (s.cooldowns[skill] or 0)>n or s.energy<C[skill].Cost then return end
            s.energy-=C[skill].Cost;s.cooldowns[skill]=n+C[skill].Cooldown
        end
        s.hold=nil
        perform(p,s,m,h,r,skill==hold.kind and skill or "Purple",aim.Unit,false)
        sendState(p,s);return
    end
    if hold and skill~="Dash" then return end
    if s.busyUntil>n then return end
    if (skill=="Rampage" or skill=="Kick" or skill=="Detonation") and not devil(m) then return end
    if skill=="BombDevil" and devil(m) then return end
    if skill=="Dash" and (m:GetAttribute("SlowedUntil") or 0)>n then return end
    -- Levi: Reel needs a held anchor, and Spin only works while flying on one (the window Reel opens).
    if skill=="Reel" and not (s.anchor and s.anchor.untilTime>n) then return end
    if skill=="Spin" and (s.comboUntil or 0)<=n then return end
    local cfg=C[skill]
    local instant=skill=="Thunderclap" and s.charges>0 and s.chargesUntil>n
    if instant then
        s.charges-=1
    else
        if (s.cooldowns[skill] or 0)>n or s.energy<cfg.Cost then return end
        s.energy-=cfg.Cost;s.cooldowns[skill]=n+cfg.Cooldown
    end
    -- Reze pays in health, never lethally.
    if cfg.HpCost and h.Health>1 then h.Health=math.max(1,h.Health-h.MaxHealth*cfg.HpCost) end
    -- Gojo: Blue and Red are held with an arm raised for up to Hold.Duration seconds instead of firing at once.
    if skill=="Blue" or skill=="Red" then
        local hold={kind=skill,untilTime=n+C.Hold.Duration}
        s.hold=hold
        fx:FireAllClients("Hold",{owner=p.UserId,kind=skill,position=r.Position,duration=C.Hold.Duration})
        local generation=s.generation
        task.delay(C.Hold.Duration,function()
            if s.hold~=hold or generation~=s.generation then return end
            s.hold=nil
            local cm,ch,cr=character(p)
            if cm==m and (m:GetAttribute("DomainLockedUntil") or 0)<=clock() then
                -- No fresh aim on a timeout: fire where the character faces (it turns with the first-person camera).
                perform(p,s,cm,ch,cr,skill,cr.CFrame.LookVector,false)
            end
            sendState(p,s)
        end)
        sendState(p,s);return
    end
    perform(p,s,m,h,r,skill,aim.Unit,instant)
    sendState(p,s)
end)
selectRemote.OnServerEvent:Connect(function(p,name)
    local s=states[p]
    if not s or type(name)~="string" or not kits[name] or kitOf(p)==name or s.busyUntil>clock() then return end
    s.generation+=1;s.cooldowns={};s.charges=0;s.chargesUntil=0;s.hold=nil;s.anchor=nil;s.reel=nil;s.comboUntil=0;cancelBlue(p,s)
    if p.Character then p.Character:SetAttribute("BombDevilUntil",0) end
    p:SetAttribute("Character",name);sendState(p,s)
end)
local sync=0
RunService.Heartbeat:Connect(function(dt)
    local n=clock();sync+=dt
    for p,s in states do
        local regen=C.EnergyRegen
        if kitOf(p)=="Levi" then
            -- Gas refills much faster on solid ground than in the air.
            local _,ch,cr=character(p)
            if ch and ch.FloorMaterial~=Enum.Material.Air then regen*=C.GasGroundRegen end
            local reel=s.reel
            if reel and cr then
                local distance=(reel.point-cr.Position).Magnitude
                if distance<=C.Reel.StopDistance+2 or n>=reel.untilTime then
                    s.reel=nil;s.anchor=nil;s.comboUntil=n+C.Spin.Grace
                    local arrived=distance<=C.Reel.StopDistance+3
                    local victim=reel.victim
                    if arrived and victim and victim.m.Parent and victim.h.Health>0 and (victim.r.Position-cr.Position).Magnitude<=C.Reel.ArrivalRadius then
                        damage(p,victim,C.Reel.ArrivalDamage);launch(victim,outward(cr.Position,victim,cr.CFrame.LookVector)*30+Vector3.new(0,28,0))
                    end
                    fx:FireAllClients("ReelEnd",{owner=p.UserId,arrived=arrived,position=cr.Position})
                    sendState(p,s)
                end
            elseif reel then s.reel=nil end
            if s.anchor and not s.reel and n>s.anchor.untilTime then
                s.anchor=nil;fx:FireAllClients("ReelEnd",{owner=p.UserId,arrived=false})
                sendState(p,s)
            end
        end
        s.energy=math.min(C.MaxEnergy,s.energy+regen*dt)
        if sync>=.15 then sendState(p,s) end
    end
    if sync>=.15 then sync=0 end
    for p,b in blues do
        if n>b.untilTime or not b.model.Parent then
            if states[p] then cancelBlue(p,states[p]) else blues[p]=nil end
        else
            for _,t in targets(b.model) do
                local delta=b.position-t.r.Position;local distance=delta.Magnitude
                if distance<C.Blue.Radius and distance>2 then
                    local step=delta.Unit*math.min(C.Blue.PullSpeed*dt,distance-2)
                    local obstacle=workspace:Raycast(t.r.Position,step,rayParams(t.m))
                    if not obstacle then t.r.CFrame+=step end
                end
            end
        end
    end
    for i=#projectiles,1,-1 do
        local shot=projectiles[i];local cfg=C[shot.kind];local step=shot.direction*cfg.Speed*dt
        local hitWorld=workspace:Spherecast(shot.position,cfg.Radius,step,rayParams(shot.model))
        local segmentLength=step.Magnitude
        if hitWorld then
            local hitModel=hitWorld.Instance:FindFirstAncestorOfClass("Model")
            if not (hitModel and hitModel:FindFirstChildOfClass("Humanoid")) then segmentLength=hitWorld.Distance end
        end
        local travel=shot.direction*segmentLength
        for _,t in targets(shot.model) do
            local projection=math.clamp((t.r.Position-shot.position):Dot(shot.direction),0,segmentLength)
            local closest=shot.position+shot.direction*projection
            if not shot.hit[t.m] and (t.r.Position-closest).Magnitude<=cfg.Radius+2 then
                shot.hit[t.m]=true;damage(shot.owner,t,cfg.Damage)
                if shot.kind=="Red" and not t.r.Anchored then t.r.AssemblyLinearVelocity+=shot.direction*34 end
            end
        end
        shot.position+=travel;shot.distance+=segmentLength
        if shot.distance>=cfg.Range or segmentLength<step.Magnitude-.001 then
            fx:FireAllClients("ProjectileEnd",{id=shot.id,position=shot.position,kind=shot.kind});table.remove(projectiles,i)
        end
    end
    -- Knocked-back training targets: ballistic arc until they land back on their starting height; walls stop drift.
    for model,f in flights do
        local root=f.t.r
        if not model.Parent or not root.Parent then
            flights[model]=nil
        else
            f.velocity-=Vector3.new(0,workspace.Gravity*dt,0)
            local step=f.velocity*dt
            local wall=workspace:Raycast(root.Position,Vector3.new(step.X,0,step.Z),rayParams(model))
            if wall then step=Vector3.new(0,step.Y,0);f.velocity=Vector3.new(0,f.velocity.Y,0) end
            local position=root.Position+step
            if position.Y<=f.ground and f.velocity.Y<0 then position=Vector3.new(position.X,f.ground,position.Z);flights[model]=nil end
            root.CFrame=CFrame.new(position)*root.CFrame.Rotation
        end
    end
    for i=#domains,1,-1 do
        local d=domains[i]
        if n>=d.expires or not d.model.Parent then
            for _,t in d.captured do
                if t.m.Parent and (t.m:GetAttribute("DomainLockedUntil") or 0)<=d.expires then t.m:SetAttribute("DomainLockedUntil",0) end
            end
            table.remove(domains,i)
        else
            for _,t in d.captured do
                if t.m.Parent and t.h.Health>0 then
                    local delta=t.r.Position-d.center
                    if delta.Magnitude>C.Domain.Radius-2 then t.r.CFrame=CFrame.new(d.center+delta.Unit*(C.Domain.Radius-2))*t.r.CFrame.Rotation end
                    if n>=d.nextTick then damage(d.owner,t,C.Domain.Damage) end
                end
            end
            if n>=d.nextTick then d.nextTick=n+C.Domain.Tick end
        end
    end
end)
local function joined(p)
    local s={energy=100,cooldowns={},blueUntil=0,busyUntil=0,lastRequest=0,generation=0,charges=0,chargesUntil=0};states[p]=s
    local function reset()
        s.generation+=1;s.energy=100;s.cooldowns={};s.busyUntil=0;s.charges=0;s.chargesUntil=0;s.hold=nil;s.anchor=nil;s.reel=nil;s.comboUntil=0;cancelBlue(p,s)
        local m=p.Character;local h=m and m:WaitForChild("Humanoid")
        if h then h.Died:Connect(function() s.generation+=1;s.hold=nil;s.anchor=nil;s.reel=nil;s.comboUntil=0;cancelBlue(p,s) end) end
    end
    p.CharacterAdded:Connect(reset);if p.Character then task.spawn(reset) end
end
Players.PlayerAdded:Connect(joined);for _,p in Players:GetPlayers() do joined(p) end
Players.PlayerRemoving:Connect(function(p) if states[p] then cancelBlue(p,states[p]) end;states[p]=nil end)
