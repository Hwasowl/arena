local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local Debris=game:GetService("Debris")
local C=require(RS:WaitForChild("GojoConfig"))
local Pain=require(script.Parent:WaitForChild("PainServer"))
local AllMight=require(script.Parent:WaitForChild("AllMightServer"))
local Itachi=require(script.Parent:WaitForChild("ItachiServer"))
local remote=Instance.new("RemoteEvent");remote.Name="GojoAction";remote.Parent=RS
local fx=Instance.new("RemoteEvent");fx.Name="GojoFX";fx.Parent=RS
local selectRemote=Instance.new("RemoteEvent");selectRemote.Name="SelectCharacter";selectRemote.Parent=RS
local aimRemote=Instance.new("RemoteEvent");aimRemote.Name="GojoAim";aimRemote.Parent=RS
local states, blues, projectiles, domains, flights={},{},{},{},{}
local domainCastOrder=0
local doraScales,doraKnockbacks={},{}
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
    if p.Parent then remote:FireClient(p,{energy=s.energy,cooldowns=s.cooldowns,blueUntil=s.blueUntil or 0,charges=s.charges,chargesUntil=s.chargesUntil,comboUntil=s.comboUntil or 0,holdKind=s.hold and s.hold.kind or "",holdUntil=s.hold and s.hold.untilTime or 0}) end
end
local function validVector(v)
    return typeof(v)=="Vector3" and v.X==v.X and v.Y==v.Y and v.Z==v.Z and v.Magnitude>.9 and v.Magnitude<1.1
end
-- Camera samples have their own rate limit so aiming cannot swallow skill inputs.
local function rememberAim(s,m,direction,origin)
    if not validVector(direction) then return end
    local head=m:FindFirstChild("Head")
    s.aimDirection=direction.Unit;s.aimAt=clock()
    s.aimOrigin=head and typeof(origin)=="Vector3" and (origin-head.Position).Magnitude<=12 and origin or nil
end
aimRemote.OnServerEvent:Connect(function(p,direction,origin,flightInput)
    local s=states[p];if not s or (kitOf(p)~="Gojo" and kitOf(p)~="Doraemon") then return end
    local n=clock()
    if n-(s.lastAimRequest or 0)<1/30 or (not s.hold and not s.doraFlight and n>=s.busyUntil) then return end
    s.lastAimRequest=n
    local m=character(p);if m then rememberAim(s,m,direction,origin) end
    if s.doraFlight and typeof(flightInput)=="Vector3" and flightInput.X==flightInput.X and flightInput.Y==flightInput.Y and flightInput.Z==flightInput.Z and flightInput.Magnitude<=1.75 then s.doraFlight.input=flightInput;s.doraFlight.inputAt=n end
end)
local function releaseAim(s,m,r,fallback)
    local head=m:FindFirstChild("Head")
    local eye=head and head.Position or r.Position+Vector3.yAxis*1.5
    local fresh=s.aimAt and clock()-s.aimAt<.5
    local direction=fresh and s.aimDirection or fallback
    local origin=fresh and s.aimOrigin
    if not origin or (origin-eye).Magnitude>12 then origin=eye end
    return direction,origin
end
local function rayParams(m)
    local p=RaycastParams.new();p.FilterType=Enum.RaycastFilterType.Exclude;p.FilterDescendantsInstances={m};return p
end
local function damage(owner,t,amount,kind)
    if not t.m.Parent or t.h.Health<=0 then return end
    local victim=Players:GetPlayerFromCharacter(t.m)
    local victimState=victim and states[victim]
    if victimState and (victimState.parryUntil or 0)>clock() then
        victimState.parryHit=true
        return
    end
    -- Itachi's Crow Clone: rolled here, before anything lands. A dodged hit deals nothing at all.
    if Itachi.tryDodge(owner,t,kind) then return end
    local dealt=amount
    -- Pain takes less damage while holding Chibaku Tensei.
    if (t.m:GetAttribute("PainGuardUntil") or 0)>clock() then dealt*=.7 end
    local attacker=owner.Character
    if attacker and (attacker:GetAttribute("DoraDamageUntil") or 0)>clock() then dealt*=.7 end
    -- One For All: buffed basic attacks hit harder, a buffed All Might takes less.
    dealt*=AllMight.damageFactor(attacker,t.m,kind)
    -- Susanoo's Yata Mirror takes 60% off frontal hits.
    dealt*=Itachi.damageFactor(attacker,t.m,kind)
    t.h:TakeDamage(dealt);fx:FireAllClients("Hit",{position=t.r.Position,damage=math.floor(dealt+.5),owner=owner.UserId})
end
local function cancelBlue(p,s)
    s.blueUntil=0
    if blues[p] then blues[p]=nil;fx:FireAllClients("BlueEnd",{owner=p.UserId}) end
end
-- WalkSpeed is derived from timed attributes so overlapping roots and slows never leave a stale speed behind.
local function updateSpeed(m,h)
    local n=clock();local speed=BASE_SPEED
    if (m:GetAttribute("SlowedUntil") or 0)>n then speed*=C.FlameGod.SlowFactor end
    local fuseStart=m:GetAttribute("DetonationSlowStart") or 0
    local fuseEnd=m:GetAttribute("DetonationSlowUntil") or 0
    if fuseEnd>n and fuseStart>0 then
        local progress=math.clamp((n-fuseStart)/(fuseEnd-fuseStart),0,1)
        speed*=1-(1-C.Detonation.SlowAtEnd)*progress
    end
    if (m:GetAttribute("PainSpeedUntil") or 0)>n then speed*=m:GetAttribute("PainSpeedFactor") or 1 end
    speed*=AllMight.speedFactor(m,n)
    speed*=Itachi.speedFactor(m,n)
    if (m:GetAttribute("RootedUntil") or 0)>n then speed=0 end
    if (m:GetAttribute("SlidingUntil") or 0)>n then speed=0 end
    local bombRecoil=(m:GetAttribute("BombRecoilUntil") or 0)>n
    if bombRecoil then speed=0 end
    -- Pain's victims are carried by the server (no walking, no jumping); Pain cannot jump while casting.
    local held=(m:GetAttribute("PainHeldUntil") or 0)>n or AllMight.held(m,n) or Itachi.held(m,n)
    if held then speed=0 end
    h.WalkSpeed=speed
    if h:GetAttribute("BaseJumpPower")==nil then h:SetAttribute("BaseJumpPower",h.JumpPower);h:SetAttribute("BaseJumpHeight",h.JumpHeight) end
    local noJump=held or bombRecoil or (m:GetAttribute("PainNoJumpUntil") or 0)>n or AllMight.noJump(m,n) or Itachi.noJump(m,n)
    h.JumpPower=noJump and 0 or h:GetAttribute("BaseJumpPower");h.JumpHeight=noJump and 0 or h:GetAttribute("BaseJumpHeight")
end
local function setTimed(m,h,attribute,duration)
    m:SetAttribute(attribute,math.max(m:GetAttribute(attribute) or 0,clock()+duration));updateSpeed(m,h)
    task.delay(duration+.05,function() if m.Parent and h.Parent then updateSpeed(m,h) end end)
end
-- A server-created constraint lifts the actual character, while its network owner simulates it smoothly.
-- A one-shot server velocity is unreliable for player-owned characters and falls before Purple releases.
local function clearDoraFlight(s)
    local flight=s.doraFlight;if not flight then return end
    flight.velocity:Destroy();flight.attachment:Destroy()
    if flight.model.Parent then flight.model:SetAttribute("DoraCopterUntil",0) end
    s.doraFlight=nil
end
local function clearPurpleHover(s)
    local hover=s.purpleHover
    if not hover then return end
    s.purpleHover=nil
    hover.alignment:Destroy();hover.attachment:Destroy()
end
local function beginPurpleHover(s,m,h,r)
    clearPurpleHover(s)
    local cfg=C.Purple
    local ceiling=workspace:Blockcast(r.CFrame,Vector3.new(3,5,3),Vector3.yAxis*cfg.RiseHeight,rayParams(m))
    local height=ceiling and math.max(0,math.min(cfg.RiseHeight,ceiling.Distance-.5)) or cfg.RiseHeight
    local duration=cfg.Windup+cfg.Recovery
    local attachment=Instance.new("Attachment");attachment.Name="PurpleHoverAttachment";attachment.Parent=r
    local alignment=Instance.new("AlignPosition")
    alignment.Name="PurpleHover";alignment.Mode=Enum.PositionAlignmentMode.OneAttachment
    alignment.Attachment0=attachment;alignment.Position=r.Position+Vector3.yAxis*height
    alignment.ApplyAtCenterOfMass=true;alignment.RigidityEnabled=false
    alignment.MaxForce=math.max(10000,r.AssemblyMass*workspace.Gravity*10)
    alignment.MaxVelocity=cfg.RiseHeight/cfg.RiseDuration;alignment.Responsiveness=35
    alignment.Parent=r
    local hover={alignment=alignment,attachment=attachment}
    s.purpleHover=hover
    setTimed(m,h,"RootedUntil",duration)
    Debris:AddItem(alignment,duration+.1);Debris:AddItem(attachment,duration+.1)
    task.delay(duration,function() if s.purpleHover==hover then clearPurpleHover(s) end end)
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
    if (t.m:GetAttribute("PainGuardUntil") or 0)>clock() then return end -- Chibaku Tensei: strong stagger resistance
    velocity=AllMight.filterKnockback(t.m,velocity);if not velocity then return end -- Plus Ultra guard / One For All
    velocity=Itachi.filterKnockback(t.m,velocity);if not velocity then return end -- Susanoo / a crow clone's cancelled hit
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
local function delayed(p,s,m,delaySeconds,callback,allowDomainClash)
    local generation=s.generation
    task.delay(delaySeconds,function()
        local current=character(p)
        if states[p]==s and generation==s.generation and current==m and (allowDomainClash or (m:GetAttribute("DomainLockedUntil") or 0)<=clock()) then callback() end
    end)
end
local function endDomain(d,reason)
    for i=#domains,1,-1 do if domains[i]==d then table.remove(domains,i);break end end
    for _,t in d.captured do
        if t.m.Parent and t.m:GetAttribute("DomainLockId")==d.id then
            t.m:SetAttribute("DomainLockId",nil)
            t.m:SetAttribute("DomainLockedUntil",0)
        end
    end
    fx:FireAllClients("DomainEnd",{id=d.id,owner=d.owner.UserId,position=d.center,radius=C.Domain.Radius,reason=reason})
end
local function canCounterDomain(m,n)
    for _,d in domains do
        if n-d.activatedAt<=C.Domain.ClashWindow then
            for _,t in d.captured do if t.m==m then return true end end
        end
    end
    return false
end
-- Starts a technique whose cost and cooldown are already paid: windup, busy time, the Cast broadcast, then the effect.
local function stopSlide(p,s)
    local slide=s.slide
    if not slide then return end
    s.slide=nil
    slide.velocity:Destroy();slide.attachment:Destroy()
    if slide.model.Parent and slide.humanoid.Parent then
        slide.model:SetAttribute("SlidingUntil",0)
        slide.humanoid.AutoRotate=slide.autoRotate
        updateSpeed(slide.model,slide.humanoid)
        if slide.root.Parent then
            local v=slide.root.AssemblyLinearVelocity;local horizontal=v*Vector3.new(1,0,1)
            if horizontal.Magnitude>BASE_SPEED then slide.root.AssemblyLinearVelocity=horizontal.Unit*BASE_SPEED+Vector3.yAxis*v.Y end
        end
    end
    fx:FireAllClients("SlideEnd",{owner=p.UserId})
end
-- Detonation's own recoil: server physics, then a grounded braking skid. No extra damage or invulnerability.
local function clearBombRecoil(p,s)
    local b=s.bombRecoil;if not b then return end
    s.bombRecoil=nil;b.velocity:Destroy();b.attachment:Destroy()
    if b.model.Parent and b.humanoid.Parent then
        b.model:SetAttribute("BombRecoilUntil",0);b.humanoid.AutoRotate=b.autoRotate;updateSpeed(b.model,b.humanoid)
    end
    if b.root.Parent then
        local v=b.root.AssemblyLinearVelocity;b.root.AssemblyLinearVelocity=Vector3.yAxis*v.Y
        if not b.root.Anchored then pcall(function() b.root:SetNetworkOwnershipAuto() end) end
    end
    s.busyUntil=math.min(s.busyUntil,clock())
    fx:FireAllClients("BombRecoilEnd",{owner=p.UserId})
end
local function beginBombRecoil(p,s,m,h,r)
    clearBombRecoil(p,s)
    local cfg=C.Detonation;local n=clock()
    local back=-r.CFrame.LookVector*Vector3.new(1,0,1);back=back.Magnitude>.01 and back.Unit or Vector3.zAxis
    local attachment=Instance.new("Attachment");attachment.Name="BombRecoilAttachment";attachment.Parent=r
    local velocity=Instance.new("LinearVelocity");velocity.Name="BombRecoilVelocity";velocity.Attachment0=attachment
    velocity.RelativeTo=Enum.ActuatorRelativeTo.World;velocity.VelocityConstraintMode=Enum.VelocityConstraintMode.Vector
    velocity.ForceLimitsEnabled=true;velocity.ForceLimitMode=Enum.ForceLimitMode.PerAxis
    velocity.MaxAxesForce=Vector3.new(1,0,1)*math.max(10000,r.AssemblyMass*1500)
    velocity.VectorVelocity=back*cfg.RecoilSpeed;velocity.Parent=r
    pcall(function() r:SetNetworkOwner(nil) end)
    local autoRotate=h.AutoRotate
    h:ChangeState(Enum.HumanoidStateType.Freefall);h.AutoRotate=false
    r.AssemblyLinearVelocity=back*cfg.RecoilSpeed+Vector3.yAxis*cfg.RecoilLift
    s.bombRecoil={model=m,humanoid=h,root=r,attachment=attachment,velocity=velocity,direction=back,start=n,autoRotate=autoRotate,params=rayParams(m)}
    s.busyUntil=n+cfg.RecoilAirLimit+cfg.SkidDuration+cfg.StandDuration
    m:SetAttribute("BombRecoilUntil",s.busyUntil);updateSpeed(m,h)
    Debris:AddItem(velocity,cfg.RecoilAirLimit+cfg.SkidDuration+cfg.StandDuration+.5)
    Debris:AddItem(attachment,cfg.RecoilAirLimit+cfg.SkidDuration+cfg.StandDuration+.5)
    fx:FireAllClients("BombRecoil",{owner=p.UserId,start=n,phase="air",direction=back})
end
local function updateBombRecoil(p,s,n,dt)
    local b=s.bombRecoil;if not b then return end
    local m,h,r=b.model,b.humanoid,b.root;local cfg=C.Detonation
    if p.Character~=m or not m.Parent or not r.Parent or h.Health<=0 or (m:GetAttribute("RootedUntil") or 0)>n
        or (m:GetAttribute("DomainLockedUntil") or 0)>n or (m:GetAttribute("PainHeldUntil") or 0)>n then clearBombRecoil(p,s);return end
    local age=n-b.start
    local speed=b.blocked and 0 or (b.land and cfg.SkidSpeed*(1-math.clamp((n-b.land)/cfg.SkidDuration,0,1))^2 or cfg.RecoilSpeed)
    if speed>0 and workspace:Blockcast(r.CFrame,Vector3.new(2.5,2.5,2.5),b.direction*(speed*dt+1),b.params) then
        b.blocked=true;speed=0;r.AssemblyLinearVelocity=Vector3.yAxis*r.AssemblyLinearVelocity.Y
    end
    b.velocity.VectorVelocity=b.direction*speed
    local ground=workspace:Raycast(r.Position,-Vector3.yAxis*(h.HipHeight+r.Size.Y/2+.45),b.params)
    if not b.land and age>.12 and ((ground and r.AssemblyLinearVelocity.Y<=1) or age>=cfg.RecoilAirLimit) then
        if not ground then clearBombRecoil(p,s);return end
        b.land=n
        fx:FireAllClients("BombRecoil",{owner=p.UserId,start=n,phase="skid",direction=b.direction})
    end
    if b.land and n-b.land>=cfg.SkidDuration+cfg.StandDuration then clearBombRecoil(p,s) end
end
local function basicAttack(p,s,m,h,r,direction)
    local kit=kitOf(p)
    local cfg=kit=="Zenitsu" and C.ZenBasicAttack or C.BasicAttack;local n=clock()
    local chained=(s.basicUntil or 0)>n
    local combo=chained and (s.basicCombo or 0)%#cfg.Windups+1 or 1
    local windup=cfg.Windups[combo];local duration=windup+cfg.Swing+cfg.Recoveries[combo]
    s.basicCombo=combo;s.basicUntil=n+duration+cfg.ComboReset;s.busyUntil=n+duration
    fx:FireAllClients("BasicAttack",{owner=p.UserId,kit=kit,combo=combo,draw=kit=="Zenitsu" and not chained,start=n,windup=windup,swing=cfg.Swing,duration=duration,position=r.Position,direction=direction})
    delayed(p,s,m,windup+cfg.Swing*.5,function()
        if (m:GetAttribute("RootedUntil") or 0)>clock() then return end
        local origin=r.Position+Vector3.yAxis*.5
        local nearest,closest=nil,math.huge
        for _,t in targets(m) do
            local delta=t.r.Position-origin;local along=delta:Dot(direction)
            if along>0 and along<=cfg.Reach and (delta-direction*along).Magnitude<=cfg.Width and delta.Magnitude<closest then
                local obstruction=workspace:Raycast(origin,delta,rayParams(m))
                if not obstruction or obstruction.Instance:IsDescendantOf(t.m) then nearest=t;closest=delta.Magnitude end
            end
        end
        if nearest then
            damage(p,nearest,cfg.Damages[combo],"Basic")
            if combo==#cfg.Windups then
                local flat=Vector3.new(direction.X,0,direction.Z)
                flat=flat.Magnitude>.05 and flat.Unit or Vector3.new(0,0,-1)
                launch(nearest,flat*cfg.Knockback*AllMight.knockbackFactor(m)+Vector3.yAxis*cfg.Lift)
            end
            fx:FireAllClients("MeleeHit",{owner=p.UserId,position=nearest.r.Position,combo=combo,kit=kit})
        end
    end)
end
local function beginSlide(p,s,m,h,r)
    local cfg=C.Slide;local n=clock()
    local horizontal=r.AssemblyLinearVelocity*Vector3.new(1,0,1)
    if h.FloorMaterial==Enum.Material.Air or horizontal.Magnitude<cfg.MinSpeed or (m:GetAttribute("SlowedUntil") or 0)>n then return end
    if (s.cooldowns.Slide or 0)>n or s.energy<cfg.Cost then return end
    local direction=horizontal.Unit
    if workspace:Blockcast(r.CFrame,Vector3.new(2.5,2.5,2.5),direction*2.5,rayParams(m)) then return end
    local attachment=Instance.new("Attachment");attachment.Name="SlideAttachment";attachment.Parent=r
    local velocity=Instance.new("LinearVelocity");velocity.Name="SlideVelocity";velocity.Attachment0=attachment
    velocity.RelativeTo=Enum.ActuatorRelativeTo.World;velocity.VelocityConstraintMode=Enum.VelocityConstraintMode.Vector
    velocity.ForceLimitsEnabled=true;velocity.ForceLimitMode=Enum.ForceLimitMode.PerAxis
    velocity.MaxAxesForce=Vector3.new(1,0,1)*math.max(10000,r.AssemblyMass*1500)
    velocity.VectorVelocity=direction*cfg.StartSpeed;velocity.Parent=r
    s.slide={model=m,humanoid=h,root=r,attachment=attachment,velocity=velocity,direction=direction,start=n,autoRotate=h.AutoRotate}
    s.energy-=cfg.Cost;s.cooldowns.Slide=n+cfg.Cooldown;s.busyUntil=n+cfg.Duration;s.basicUntil=0
    m:SetAttribute("SlidingUntil",n+cfg.Duration);h.AutoRotate=false;updateSpeed(m,h)
    Debris:AddItem(velocity,cfg.Duration+.2);Debris:AddItem(attachment,cfg.Duration+.2)
    fx:FireAllClients("Slide",{owner=p.UserId,start=n,duration=cfg.Duration,position=r.Position,direction=direction})
    sendState(p,s)
end
local function perform(p,s,m,h,r,kind,direction,instant,thunderCharge,thunderEnhanced)
    local n=clock()
    local rezeDive=kind=="Rampage" and (s.rezeAirUntil or 0)>n
    local windup=kind=="Rampage" and rezeDive and .05 or C[kind].Windup or .2
    if kind=="Kick" then windup+=C.Kick.Fuse end
    s.busyUntil=n+(kind=="FlameGod" and C.FlameGod.Duration or kind=="BombDevil" and windup+C.BombDevil.Blackout or kind=="Purple" and windup+C.Purple.Recovery or windup)
    if kind=="Purple" then cancelBlue(p,s);beginPurpleHover(s,m,h,r) end
    fx:FireAllClients("Cast",{owner=p.UserId,kind=kind,position=r.Position,direction=direction,start=n,windup=windup,charge=thunderCharge,enhanced=thunderEnhanced,phase=rezeDive and "Dive" or "Rise"})
    if kind=="Haki" then
        local cfg=C.Haki
        s.busyUntil=n+cfg.Windup+cfg.Tick*cfg.Pulses
        delayed(p,s,m,cfg.Windup,function()
            fx:FireAllClients("HakiAwaken",{owner=p.UserId,position=r.Position,duration=cfg.Tick*cfg.Pulses})
            for pulse=1,cfg.Pulses do
                task.delay((pulse-1)*cfg.Tick,function()
                    if p.Character~=m or not m.Parent or h.Health<=0 then return end
                    for _,t in targets(m) do
                        if (t.r.Position-r.Position).Magnitude<=cfg.Radius then damage(p,t,cfg.Damage,"Status") end
                    end
                    fx:FireAllClients("HakiPulse",{owner=p.UserId,position=r.Position,radius=cfg.Radius,pulse=pulse})
                end)
            end
        end)
    elseif kind=="DivineDeparture" then
        local cfg=C.DivineDeparture
        s.busyUntil=n+cfg.Windup+.55
        delayed(p,s,m,cfg.Windup,function()
            local origin=r.Position+Vector3.yAxis*1.5
            local finish=origin+direction*cfg.Distance
            local ray=workspace:Blockcast(CFrame.lookAt(origin,origin+direction),Vector3.new(cfg.Width,4,cfg.Width),direction*cfg.Distance,rayParams(m))
            if ray then finish=origin+direction*math.max(0,ray.Distance-.5) end
            for _,t in targets(m) do
                local along=math.clamp((t.r.Position-origin):Dot(direction),0,(finish-origin).Magnitude)
                if (origin+direction*along-t.r.Position).Magnitude<=cfg.Width then damage(p,t,cfg.Damage,"Projectile") end
            end
            fx:FireAllClients("DivineDeparture",{owner=p.UserId,from=origin,to=finish,width=cfg.Width})
        end)
    elseif kind=="Blue" then
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
        delayed(p,s,m,C[kind].Windup,function()
            local cfgShot=C[kind]
            -- Lock the current camera ray at release, after the windup and Purple's ascent.
            local eye
            direction,eye=releaseAim(s,m,r,direction)
            local offset=kind=="Purple" and cfgShot.OrbDistance or 1.6
            local obstruction=not cfgShot.PierceWorld and workspace:Raycast(eye,direction*offset,rayParams(m))
            if obstruction then offset=math.max(0,obstruction.Distance-.1) end
            local origin=eye+direction*offset
            local id=tostring(p.UserId)..":"..tostring(clock())
            table.insert(projectiles,{id=id,owner=p,model=m,position=origin,direction=direction,kind=kind,distance=0,hit={}})
            fx:FireAllClients("Projectile",{id=id,owner=p.UserId,position=origin,direction=direction,kind=kind,speed=cfgShot.Speed,range=cfgShot.Range})
        end)
    elseif kind=="Domain" then
        domainCastOrder+=1
        local castOrder=domainCastOrder
        delayed(p,s,m,C.Domain.Windup,function()
            local flat=Vector3.new(direction.X,0,direction.Z)
            if flat.Magnitude<.05 then flat=Vector3.new(0,0,-1) end
            local center=r.Position+flat.Unit*14
            -- Compare cast order, not callback order: a delayed older callback cannot reclaim a newer domain.
            for i=#domains,1,-1 do
                local other=domains[i]
                if (other.center-center).Magnitude<C.Domain.Radius*2 then
                    if other.castOrder>castOrder then
                        fx:FireAllClients("DomainClashLost",{owner=p.UserId,position=center})
                        return
                    end
                    endDomain(other,"shattered")
                end
            end
            local activatedAt=clock()
            local d={id=tostring(p.UserId)..":"..tostring(castOrder),owner=p,model=m,center=center,
                castOrder=castOrder,activatedAt=activatedAt,expires=activatedAt+C.Domain.Duration,nextTick=activatedAt,captured={}}
            for _,t in targets(m) do
                if (t.r.Position-center).Magnitude<C.Domain.Radius then
                    table.insert(d.captured,t)
                    t.m:SetAttribute("DomainLockId",d.id)
                    t.m:SetAttribute("DomainLockedUntil",d.expires)
                end
            end
            table.insert(domains,d)
            fx:FireAllClients("Domain",{id=d.id,owner=p.UserId,position=center,radius=C.Domain.Radius,duration=C.Domain.Duration})
        end,true)
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
        local charged=math.clamp(thunderCharge or 0,0,cfg.MaxCharge)
        local distance=cfg.MinDistance+(cfg.Distance-cfg.MinDistance)*charged/cfg.MaxCharge
        delayed(p,s,m,windup,function()
            local start,finish,victims=dashStrike(m,r,flat,distance,cfg.Width)
            for _,t in victims do damage(p,t,cfg.Damage,"Dash") end
            fx:FireAllClients("Thunderclap",{owner=p.UserId,from=start,to=finish,charged=charged,distance=distance})
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
                for _,t in victims do damage(p,t,cfg.Damage,"Ultimate") end
            end)
            -- The cut lands after the turn; recoil follows just after the user sees the result.
            task.delay(cfg.RecoilDelay,function()
                if p.Character~=m or not m.Parent or not h.Parent or h.Health<=0 then return end
                if h.Health>1 then h.Health=math.max(1,h.Health-cfg.SelfDamage) end
                setTimed(m,h,"SlowedUntil",cfg.SlowDuration)
                fx:FireClient(p,"Recoil",{damage=cfg.SelfDamage,duration=cfg.SlowDuration})
            end)
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
                    damage(p,t,cfg.Damage,"Explosion")
                    local power=1-.5*distance/cfg.Radius
                    launch(t,outward(center,t,r.CFrame.LookVector)*cfg.Knockback*power+Vector3.new(0,cfg.Lift*power,0))
                end
            end
        end)
    elseif kind=="Detonation" then
        local cfg=C.Detonation
        -- The warning follows the player while movement eases down through the fuse.
        m:SetAttribute("DetonationSlowStart",n);m:SetAttribute("DetonationSlowUntil",n+windup);updateSpeed(m,h)
        task.delay(windup+.05,function()
            if m.Parent and h.Parent then m:SetAttribute("DetonationSlowStart",0);m:SetAttribute("DetonationSlowUntil",0);updateSpeed(m,h) end
        end)
        delayed(p,s,m,windup,function()
            local center=r.Position
            fx:FireAllClients("Detonation",{owner=p.UserId,position=center,radius=cfg.Radius})
            for _,t in targets(m) do
                local distance=(t.r.Position-center).Magnitude
                if distance<=cfg.Radius then
                    damage(p,t,cfg.Damage,"Ultimate")
                    local power=1-.55*distance/cfg.Radius
                    launch(t,outward(center,t,r.CFrame.LookVector)*cfg.Knockback*power+Vector3.new(0,cfg.Lift*power,0))
                end
            end
            m:SetAttribute("BombDevilUntil",0)
            s.cooldowns.BombDevil=clock()+C.BombDevil.Recharge
            beginBombRecoil(p,s,m,h,r)
            sendState(p,s)
        end)
    elseif kind=="Rampage" then
        local cfg=C.Rampage
        if rezeDive then
            delayed(p,s,m,windup,function()
                r.AssemblyLinearVelocity=Vector3.new(r.AssemblyLinearVelocity.X,-cfg.DiveSpeed,r.AssemblyLinearVelocity.Z)
                local height=math.max(0,r.Position.Y-3);local gravity=workspace.Gravity
                local impactDelay=math.max(cfg.SlamDelay,(-cfg.DiveSpeed+math.sqrt(cfg.DiveSpeed^2+2*gravity*height))/gravity)
                task.delay(impactDelay,function()
                    if p.Character~=m or not m.Parent or h.Health<=0 then return end
                    local center=Vector3.new(r.Position.X,math.max(0,r.Position.Y-2.5),r.Position.Z)
                    fx:FireAllClients("RezeSlam",{owner=p.UserId,position=center,radius=cfg.Radius,direction=direction})
                    for _,t in targets(m) do
                        local delta=t.r.Position-center
                        if Vector3.new(delta.X,delta.Y*.65,delta.Z).Magnitude<=cfg.Radius then
                            damage(p,t,cfg.Damage,"Explosion");launch(t,outward(center,t,direction)*cfg.Knockback+Vector3.yAxis*cfg.Lift)
                        end
                    end
                end)
                s.rezeAirUntil=0
            end)
        else
            delayed(p,s,m,windup,function()
                local flat=Vector3.new(direction.X,0,direction.Z)
                if flat.Magnitude<.05 then flat=r.CFrame.LookVector*Vector3.new(1,0,1) end
                flat=flat.Unit
                r.AssemblyLinearVelocity=flat*cfg.RiseForwardSpeed+Vector3.yAxis*cfg.RiseSpeed
                s.rezeAirUntil=clock()+cfg.AirWindow
                fx:FireAllClients("RezeRise",{owner=p.UserId,position=r.Position,radius=4})
                sendState(p,s)
            end)
        end
    elseif kind=="Pocket" then
        local cfg=C.Pocket
        s.busyUntil=n+cfg.Windup+cfg.Recovery
        local item=({"SmallLight","AirCannon","Dorayaki"})[math.random(1,3)]
        delayed(p,s,m,cfg.DrawTime,function() fx:FireAllClients("DoraItem",{owner=p.UserId,item=item,position=r.Position}) end)
        delayed(p,s,m,cfg.Windup,function()
            local aim,origin=releaseAim(s,m,r,direction)
            if item=="Dorayaki" then
                local healed=math.min(cfg.Heal,h.MaxHealth-h.Health);h.Health+=healed
                fx:FireClient(p,"DoraHeal",{amount=healed});return
            end
            local params=rayParams(m);local first=workspace:Raycast(origin,aim*cfg.Range,params)
            local best,closest=nil,math.huge
            for _,t in targets(m) do
                local delta=t.r.Position-origin;local along=delta:Dot(aim)
                local sight=workspace:Raycast(origin,t.r.Position-origin,params)
                if along>0 and along<=cfg.Range and (delta-aim*along).Magnitude<=3
                    and (not sight or sight.Instance:IsDescendantOf(t.m)) and along<closest then best=t;closest=along end
            end
            local finish=best and best.r.Position or first and first.Position or origin+aim*cfg.Range
            if item=="SmallLight" then
                if best then
                    local victim=best.m;local record=doraScales[victim]
                    if not record then record={generation=0,scale=victim:GetScale()};doraScales[victim]=record end
                    record.generation+=1;local generation=record.generation
                    victim:SetAttribute("DoraDamageUntil",clock()+cfg.ShrinkDuration)
                    pcall(function() victim:ScaleTo(record.scale*cfg.ShrinkScale) end)
                    task.delay(cfg.ShrinkDuration,function()
                        if doraScales[victim]==record and record.generation==generation then
                            if victim.Parent then pcall(function() victim:ScaleTo(record.scale) end);victim:SetAttribute("DoraDamageUntil",0) end
                            doraScales[victim]=nil
                        end
                    end)
                end
                fx:FireAllClients("DoraShrink",{owner=p.UserId,from=origin,position=finish,duration=cfg.ShrinkDuration})
            else
                if best then
                    damage(p,best,cfg.CannonDamage,"Projectile")
                    local flat=Vector3.new(aim.X,0,aim.Z);flat=flat.Magnitude>.01 and flat.Unit or r.CFrame.LookVector
                    local excluded={m};for _,other in targets(nil) do table.insert(excluded,other.m) end
                    local wallParams=rayParams(m);wallParams.FilterDescendantsInstances=excluded
                    doraKnockbacks[best.m]={t=best,owner=p,from=best.r.CFrame,direction=flat,start=clock(),last=0,params=wallParams}
                    flights[best.m]=nil;setTimed(best.m,best.h,"RootedUntil",cfg.CannonTime+.05)
                end
                fx:FireAllClients("DoraCannon",{owner=p.UserId,from=origin,to=finish,direction=aim})
            end
        end)
    elseif kind=="BambooCopter" then
        local cfg=C.BambooCopter;s.busyUntil=n+cfg.Windup+cfg.Recovery
        delayed(p,s,m,cfg.Windup,function()
            local attachment=Instance.new("Attachment");attachment.Name="DoraFlightAttachment";attachment.Parent=r
            local velocity=Instance.new("LinearVelocity");velocity.Name="DoraFlight";velocity.Attachment0=attachment
            velocity.RelativeTo=Enum.ActuatorRelativeTo.World;velocity.MaxForce=math.max(10000,r.AssemblyMass*workspace.Gravity*8)
            velocity.VectorVelocity=Vector3.yAxis*cfg.VerticalSpeed;velocity.Parent=r
            s.doraFlight={model=m,root=r,attachment=attachment,velocity=velocity,start=clock(),input=Vector3.zero,inputAt=clock()}
            Debris:AddItem(velocity,cfg.Duration+.1);Debris:AddItem(attachment,cfg.Duration+.1)
            h:ChangeState(Enum.HumanoidStateType.Freefall);m:SetAttribute("DoraCopterUntil",clock()+cfg.Duration)
            fx:FireAllClients("DoraFlight",{owner=p.UserId,position=r.Position,duration=cfg.Duration})
        end)
    elseif kind=="AnywhereDoor" then
        local cfg=C.AnywhereDoor;s.busyUntil=n+cfg.Windup+cfg.Recovery
        delayed(p,s,m,cfg.Windup,function()
            local flat=Vector3.new(direction.X,0,direction.Z)
            if flat.Magnitude<.05 then flat=r.CFrame.LookVector*Vector3.new(1,0,1) end
            flat=flat.Unit
            local result=workspace:Blockcast(r.CFrame,Vector3.new(3,4,3),flat*cfg.Distance,rayParams(m))
            local distance=result and math.max(0,result.Distance-1) or cfg.Distance
            local from=r.Position;r.CFrame=CFrame.lookAt(from+flat*distance,from+flat*(distance+1))
            fx:FireAllClients("DoraDoor",{owner=p.UserId,from=from,to=r.Position,direction=flat})
        end)
    elseif kind=="Kick" then
        local cfg=C.Kick
        local flat=Vector3.new(direction.X,0,direction.Z)
        if flat.Magnitude<.05 then flat=r.CFrame.LookVector*Vector3.new(1,0,1) end
        flat=flat.Unit
        delayed(p,s,m,windup,function()
            local from=r.Position
            local center=from+flat*cfg.Reach+Vector3.new(0,1.5,0)
            fx:FireAllClients("HandBlast",{owner=p.UserId,from=from,to=center,radius=cfg.Radius})
            for _,t in targets(m) do
                if (t.r.Position-center).Magnitude<=cfg.Radius then
                    damage(p,t,cfg.Damage,"Explosion");launch(t,flat*cfg.Knockback+Vector3.new(0,cfg.Lift,0))
                end
            end
        end)
    end
end
local function releaseThunder(p,s,aim)
    local hold=s.thunderHold
    if not hold then return end
    s.thunderHold=nil
    local m,h,r=character(p)
    if m~=hold.model or hold.generation~=s.generation then return end
    m:SetAttribute("RootedUntil",0);updateSpeed(m,h)
    local n=clock()
    if (m:GetAttribute("DomainLockedUntil") or 0)>n then s.busyUntil=0;sendState(p,s);return end
    local charged=math.clamp(n-hold.start,0,C.Thunderclap.MaxCharge)
    local enhanced=s.charges>0 and s.chargesUntil>n
    if enhanced then
        s.charges-=1
        if s.charges<=0 then
            s.chargesUntil=0
            s.cooldowns.Thunderclap=n+C.Thunderclap.Cooldown
        else
            s.cooldowns.Thunderclap=n+C.Thunderclap.ChainCooldown
        end
    else
        if s.energy<C.Thunderclap.Cost then s.busyUntil=0;sendState(p,s);return end
        s.energy-=C.Thunderclap.Cost;s.cooldowns.Thunderclap=n+C.Thunderclap.Cooldown
    end
    s.busyUntil=0
    local direction=validVector(aim) and aim.Unit or hold.direction
    perform(p,s,m,h,r,"Thunderclap",direction,false,charged,enhanced)
    s.busyUntil=n+C.Thunderclap.Windup+.45
    sendState(p,s)
end
remote.OnServerEvent:Connect(function(p,skill,aim,aimOrigin)
    local s=states[p];if not s then return end
    if skill=="ThunderclapStart" or skill=="ThunderclapRelease" then
        if kitOf(p)~="Zenitsu" or not validVector(aim) then return end
        if skill=="ThunderclapRelease" then releaseThunder(p,s,aim);return end
        local n=clock()
        local m,h,r=character(p);if not m or s.thunderHold or s.busyUntil>n or s.hold or s.slide then return end
        if (m:GetAttribute("DomainLockedUntil") or 0)>n or (m:GetAttribute("PainHeldUntil") or 0)>n or AllMight.held(m,n) or Itachi.held(m,n) then return end
        local enhanced=s.charges>0 and s.chargesUntil>n
        if (s.cooldowns.Thunderclap or 0)>n or (not enhanced and s.energy<C.Thunderclap.Cost) then return end
        local hold={start=n,model=m,generation=s.generation,direction=aim.Unit}
        s.thunderHold=hold;s.busyUntil=n+C.Thunderclap.MaxCharge+.4
        setTimed(m,h,"RootedUntil",C.Thunderclap.MaxCharge+.05)
        fx:FireAllClients("ThunderCharge",{owner=p.UserId,position=r.Position,start=n,duration=C.Thunderclap.MaxCharge,enhanced=enhanced})
        task.delay(C.Thunderclap.MaxCharge,function()
            if s.thunderHold==hold then releaseThunder(p,s,hold.direction) end
        end)
        return
    end
    if skill=="SlideCancel" then
        if s.slide then stopSlide(p,s);s.busyUntil=clock() end
        return
    end
    local n=clock()
    if n-s.lastRequest<.1 then return end;s.lastRequest=n
    local shanksAction=kitOf(p)=="Shanks" and (skill=="ShanksSlash" or skill=="ShanksParry")
    if type(skill)~="string" or (skill~="BasicAttack" and skill~="Slide" and not kits[kitOf(p)][skill] and not shanksAction) or not validVector(aim) then return end
    local m,h,r=character(p);if not m then return end
    if (m:GetAttribute("DomainLockedUntil") or 0)>n and not (skill=="Domain" and canCounterDomain(m,n)) then return end
    -- Held by Pain (pulled, thrown, sealed), All Might (smashed, carried, launched) or Itachi (Tsukuyomi, sealed):
    -- no attacks, dashes or skills. Susanoo locks its own caster too.
    if (m:GetAttribute("PainHeldUntil") or 0)>n or AllMight.held(m,n) or Itachi.held(m,n) then return end
    if (m:GetAttribute("ItachiLockUntil") or 0)>n then return end
    if skill=="Thunderclap" then return end
    if Pain.handles(skill) then
        if kitOf(p)=="Pain" then Pain.request(p,s,m,h,r,skill,aim.Unit,aimOrigin) end
        return
    end
    if AllMight.handles(skill) then
        if kitOf(p)=="AllMight" then AllMight.request(p,s,m,h,r,skill,aim.Unit) end
        return
    end
    if Itachi.handles(skill) then
        if kitOf(p)=="Itachi" then Itachi.request(p,s,m,h,r,skill,aim.Unit,aimOrigin) end
        return
    end
    if skill=="BasicAttack" or skill=="Slide" then
        if s.busyUntil>n or s.hold or (m:GetAttribute("RootedUntil") or 0)>n then return end
        if skill=="BasicAttack" then basicAttack(p,s,m,h,r,aim.Unit) else beginSlide(p,s,m,h,r) end
        return
    end
    rememberAim(s,m,aim,aimOrigin)
    if kitOf(p)=="Shanks" and skill=="ShanksSlash" then
        local cfg=C.EnGarde
        if s.enGardeUntil<=n or s.busyUntil>n then return end
        s.enGardeUntil=0;s.busyUntil=n+.55
        fx:FireAllClients("ShanksSlash",{owner=p.UserId,start=n,direction=aim.Unit})
        task.delay(.2,function()
            if p.Character~=m or not m.Parent or h.Health<=0 then return end
            local flat=Vector3.new(aim.X,0,aim.Z);if flat.Magnitude<.05 then flat=Vector3.new(0,0,-1) end;flat=flat.Unit
            r.AssemblyLinearVelocity=flat*65+Vector3.yAxis*16
            local start=r.Position
            task.delay(.08,function()
                if p.Character~=m or not m.Parent then return end
                local finish=r.Position
                for _,t in targets(m) do
                    local path=finish-start;local along=path.Magnitude>0 and math.clamp((t.r.Position-start):Dot(path.Unit),0,path.Magnitude) or 0
                    if (start+path.Unit*along-t.r.Position).Magnitude<=cfg.SlashWidth then damage(p,t,cfg.SlashDamage,"Weapon") end
                end
            end)
        end)
        return
    elseif kitOf(p)=="Shanks" and skill=="ShanksParry" then
        local cfg=C.EnGarde
        if s.enGardeUntil<=n or s.busyUntil>n then return end
        s.enGardeUntil=0;s.parryUntil=n+cfg.ParryWindow;s.parryHit=false;s.busyUntil=n+cfg.ParryWindow
        fx:FireAllClients("ShanksParry",{owner=p.UserId,start=n,duration=cfg.ParryWindow})
        task.delay(cfg.ParryWindow,function()
            s.parryUntil=0
            if p.Character~=m or not m.Parent or h.Health<=0 then return end
            if s.parryHit then
                local look=r.CFrame.LookVector;local origin=r.Position+Vector3.yAxis*1.5;local best,dist=nil,math.huge
                for _,t in targets(m) do
                    local delta=t.r.Position-origin;local along=delta:Dot(look)
                    if along>0 and along<=cfg.CounterReach and (delta-look*along).Magnitude<=3 and along<dist then best=t;dist=along end
                end
                if best then damage(p,best,cfg.CounterDamage,"Weapon") end
                fx:FireAllClients("ShanksCounter",{owner=p.UserId,position=origin+look*math.min(dist,cfg.CounterReach)})
            else fx:FireAllClients("ShanksParryEnd",{owner=p.UserId}) end
        end)
        return
    end
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
    local rezeDive=skill=="Rampage" and (s.rezeAirUntil or 0)>n
    if s.busyUntil>n then return end
    s.basicUntil=0
    if (skill=="Rampage" or skill=="Kick" or skill=="Detonation") and not devil(m) then return end
    if skill=="EnGarde" then
        if s.enGardeUntil>n then return end
        local cfg=C.EnGarde
        if (s.cooldowns[skill] or 0)>n or s.energy<cfg.Cost or s.busyUntil>n then return end
        s.energy-=cfg.Cost;s.cooldowns[skill]=n+cfg.Cooldown;s.enGardeUntil=n+cfg.Window
        fx:FireAllClients("ShanksEnGarde",{owner=p.UserId,untilTime=s.enGardeUntil})
        sendState(p,s);return
    end
    if skill=="Rampage" and not rezeDive and (s.rezeAirUntil or 0)>0 then s.rezeAirUntil=0 end
    if skill=="BombDevil" and devil(m) then return end
    if skill=="Dash" and (m:GetAttribute("SlowedUntil") or 0)>n then return end
    local cfg=C[skill]
    local instant=false
    if instant then
        s.charges-=1
    else
        if ((s.cooldowns[skill] or 0)>n and not rezeDive) or s.energy<cfg.Cost then return end
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
                local direction=releaseAim(s,cm,cr,aim.Unit)
                perform(p,s,cm,ch,cr,skill,direction,false)
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
    clearPurpleHover(s);clearDoraFlight(s);Pain.reset(p);AllMight.reset(p);Itachi.reset(p)
    stopSlide(p,s);clearBombRecoil(p,s);s.basicUntil=0;s.basicCombo=0
    s.generation+=1;s.cooldowns={};s.charges=0;s.chargesUntil=0;s.hold=nil;s.thunderHold=nil;s.comboUntil=0;s.rezeAirUntil=0;s.enGardeUntil=0;s.parryUntil=0;s.parryHit=false;cancelBlue(p,s)
    if p.Character then p.Character:SetAttribute("BombDevilUntil",0) end
    p:SetAttribute("Character",name);sendState(p,s)
end)
local sync=0
RunService.Heartbeat:Connect(function(dt)
    local n=clock();sync+=dt
    for model,k in doraKnockbacks do
        local t=k.t;local progress=math.clamp((n-k.start)/C.Pocket.CannonTime,0,1);local distance=C.Pocket.CannonDistance*progress
        if not model.Parent or not t.r.Parent or t.h.Health<=0 then doraKnockbacks[model]=nil
        else
            local previous=k.from.Position+k.direction*k.last;local step=distance-k.last
            local wall=step>.001 and workspace:Blockcast(CFrame.new(previous),Vector3.new(1.5,2.8,1.5),k.direction*step,k.params)
            local travelled=wall and k.last+math.max(0,wall.Distance-.08) or distance
            local position=k.from.Position+k.direction*travelled+Vector3.yAxis*(wall and 0 or math.sin(progress*math.pi)*.8)
            model:PivotTo(CFrame.new(position)*k.from.Rotation);t.r.AssemblyLinearVelocity=Vector3.zero;k.last=travelled
            if wall or progress>=1 then
                doraKnockbacks[model]=nil
                if wall then damage(k.owner,t,C.Pocket.CannonWallDamage-C.Pocket.CannonDamage,"Environment");fx:FireAllClients("DoraWallHit",{position=position,owner=k.owner.UserId}) end
            end
        end
    end
    for p,s in states do
        local speedModel,speedHumanoid=character(p)
        if speedModel then
            updateSpeed(speedModel,speedHumanoid)
            local flight=s.doraFlight
            if flight then
                local age=n-flight.start
                if speedModel~=flight.model or speedHumanoid.Health<=0 or age>=C.BambooCopter.Duration or kitOf(p)~="Doraemon" or (speedModel:GetAttribute("DomainLockedUntil") or 0)>n then
                    clearDoraFlight(s)
                else
                    local input=n-flight.inputAt<.35 and flight.input or Vector3.zero
                    local horizontal=Vector3.new(input.X,0,input.Z);if horizontal.Magnitude>1 then horizontal=horizontal.Unit end
                    local vertical=age<.4 and C.BambooCopter.VerticalSpeed or math.clamp(input.Y,-1,1)*C.BambooCopter.VerticalSpeed
                    if (speedModel:GetAttribute("RootedUntil") or 0)>n then horizontal=Vector3.zero;vertical=0 end
                    flight.velocity.VectorVelocity=horizontal*C.BambooCopter.FlySpeed+Vector3.yAxis*vertical
                end
            end
            if kitOf(p)=="Doraemon" and (speedModel:GetAttribute("DoraCopterUntil") or 0)>n then
                local rotor=speedModel:FindFirstChild("DoraemonRotorMotor",true)
                if rotor then rotor.Transform=CFrame.Angles(0,n*32,0) end
            end
        end
        updateBombRecoil(p,s,n,dt)
        local slide
        if slide then
            local age=n-slide.start
            local m,h,r=slide.model,slide.humanoid,slide.root
            if p.Character~=m or not m.Parent or not r.Parent or h.Health<=0 or age>=C.Slide.Duration
                or (m:GetAttribute("DomainLockedUntil") or 0)>n or (m:GetAttribute("RootedUntil") or 0)>n
                or (age>.08 and h.FloorMaterial==Enum.Material.Air)
                or workspace:Blockcast(r.CFrame,Vector3.new(2.5,2.5,2.5),slide.direction*math.max(1.5,C.Slide.StartSpeed*dt+.5),rayParams(m)) then
                stopSlide(p,s);s.busyUntil=n
            else
                local u=math.clamp(age/C.Slide.Duration,0,1)
                slide.velocity.VectorVelocity=slide.direction*(C.Slide.EndSpeed+(C.Slide.StartSpeed-C.Slide.EndSpeed)*(1-u)^2)
            end
        end
        local regen=C.EnergyRegen
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
        -- Hollow Purple travels through arena geometry, like the reference; victims still receive one hit.
        -- Its wide damage radius used to clip a nearby pillar and delete it immediately after release.
        local hitWorld=not cfg.PierceWorld and workspace:Spherecast(shot.position,cfg.WorldRadius or cfg.Radius,step,rayParams(shot.model)) or nil
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
                shot.hit[t.m]=true;damage(shot.owner,t,cfg.Damage,shot.kind=="Purple" and "Ultimate" or "Projectile")
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
            endDomain(d,n>=d.expires and "expired" or "owner_lost")
        else
            for _,t in d.captured do
                if t.m.Parent and t.h.Health>0 then
                    local delta=t.r.Position-d.center
                    if delta.Magnitude>C.Domain.Radius-2 then t.r.CFrame=CFrame.new(d.center+delta.Unit*(C.Domain.Radius-2))*t.r.CFrame.Rotation end
                    if n>=d.nextTick then damage(d.owner,t,C.Domain.Damage,"DoT") end
                end
            end
            if n>=d.nextTick then d.nextTick=n+C.Domain.Tick end
        end
    end
end)
Pain.init({fx=fx,states=states,clock=clock,character=character,targets=targets,damage=damage,updateSpeed=updateSpeed,setTimed=setTimed,
    sendState=sendState,flights=flights,doraKnockbacks=doraKnockbacks,projectiles=projectiles,kitOf=kitOf})
AllMight.init({fx=fx,states=states,clock=clock,character=character,targets=targets,damage=damage,updateSpeed=updateSpeed,
    sendState=sendState,flights=flights,doraKnockbacks=doraKnockbacks,launch=launch,kitOf=kitOf})
Itachi.init({fx=fx,states=states,clock=clock,character=character,targets=targets,damage=damage,updateSpeed=updateSpeed,
    sendState=sendState,flights=flights,doraKnockbacks=doraKnockbacks,kitOf=kitOf,launch=launch})
local function joined(p)
    local s={energy=100,cooldowns={},blueUntil=0,busyUntil=0,lastRequest=0,generation=0,charges=0,chargesUntil=0,enGardeUntil=0,parryUntil=0,parryHit=false};states[p]=s
    local function reset()
        stopSlide(p,s);clearBombRecoil(p,s);s.basicUntil=0;s.basicCombo=0
        clearPurpleHover(s);clearDoraFlight(s)
        s.generation+=1;s.energy=100;s.cooldowns={};s.busyUntil=0;s.charges=0;s.chargesUntil=0;s.hold=nil;s.thunderHold=nil;s.comboUntil=0;s.rezeAirUntil=0;cancelBlue(p,s)
        local m=p.Character;local h=m and m:WaitForChild("Humanoid")
        if h then h.Died:Connect(function() stopSlide(p,s);clearBombRecoil(p,s);clearPurpleHover(s);clearDoraFlight(s);s.generation+=1;Pain.reset(p);AllMight.reset(p);Itachi.reset(p);s.hold=nil;s.comboUntil=0;s.basicUntil=0;cancelBlue(p,s) end) end
    end
    p.CharacterAdded:Connect(reset);if p.Character then task.spawn(reset) end
end
Players.PlayerAdded:Connect(joined);for _,p in Players:GetPlayers() do joined(p) end
Players.PlayerRemoving:Connect(function(p) if states[p] then stopSlide(p,states[p]);clearBombRecoil(p,states[p]);clearPurpleHover(states[p]);clearDoraFlight(states[p]);cancelBlue(p,states[p]) end;states[p]=nil end)
