-- Tendo Pain on the client: first-person Akatsuki arms (sleeves, red clouds, black nails, moving fingers),
-- camera work for each technique, screen overlays, and the local side of being pulled, thrown or sealed.
-- Gojo.client.luau owns input and the shared HUD; it forwards Pain* events here and asks for the arm pose
-- every frame. All judgement stays on the server.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local P=require(RS:WaitForChild("PainAbilityConfig"))
local VFX=require(RS:WaitForChild("PainVFX"))
local COLORS=P.Colors
local player=Players.LocalPlayer
local smoothstep=VFX.smoothstep
local function clock() return workspace:GetServerTimeNow() end

local PainClient={}
local env
local cast=nil          -- the local player's own technique in progress
local chibakuViews={}   -- [owner userId] = VFX handle
local sealed={}         -- [model] = true while hidden inside a sphere
local heldApplied=false
local comboUntil=0
local shake={untilTime=0,power=0}
local afterBlurUntil=0

---------------------------------------------------------------- arms
-- Hand frame: origin at the wrist, +Y toward the fingertips, palm facing -Z, back of the hand +Z.
-- The thumb sits on -X for the right hand and +X for the left (palm forward, as seen from behind).
local arms={}
local function vmPart(model,name,size,color,shape,material)
    local p=Instance.new("Part");p.Name=name;p.Size=size;p.Color=color;p.Shape=shape or Enum.PartType.Block
    p.Material=material or Enum.Material.SmoothPlastic;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
    p.CastShadow=false;p.Transparency=1;p.Parent=model
    return p
end
local FINGERS={ -- x offset along the knuckles from the thumb side, proximal/distal length, spread angle
    {x=.056,a=.078,b=.062,spread=.12},{x=.019,a=.084,b=.066,spread=.03},{x=-.019,a=.078,b=.062,spread=-.06},{x=-.054,a=.064,b=.05,spread=-.16},
}
local function buildArm(side)
    local m=Instance.new("Model");m.Name=side>0 and "PainRightArm" or "PainLeftArm";m.Parent=env.viewmodel
    local thumbSide=side>0 and -1 or 1
    local a={side=side,thumbSide=thumbSide,model=m,fingers={}}
    a.sleeve=vmPart(m,"Sleeve",Vector3.new(.86,.27,.27),COLORS.Sleeve,Enum.PartType.Cylinder)
    a.cuff=vmPart(m,"SleeveCuff",Vector3.new(.12,.34,.34),COLORS.Sleeve,Enum.PartType.Cylinder)
    a.lining=vmPart(m,"SleeveLining",Vector3.new(.02,.3,.3),Color3.fromRGB(150,22,32),Enum.PartType.Cylinder)
    a.clouds={}
    for i=1,2 do
        local rim,cloud={}, {}
        for j=1,3 do
            rim[j]=vmPart(m,"CloudRim",Vector3.new(.012,.085,.085),COLORS.CloudRim,Enum.PartType.Cylinder)
            cloud[j]=vmPart(m,"Cloud",Vector3.new(.014,.07,.07),COLORS.Cloud,Enum.PartType.Cylinder)
        end
        a.clouds[i]={rim=rim,cloud=cloud}
    end
    a.palm=vmPart(m,"Palm",Vector3.new(.17,.19,.06),COLORS.Skin)
    a.wrist=vmPart(m,"Wrist",Vector3.new(.13,.1,.075),COLORS.Skin)
    for i,f in FINGERS do
        a.fingers[i]={def=f,prox=vmPart(m,"Finger",Vector3.new(.036,f.a,.036),COLORS.Skin),dist=vmPart(m,"Finger",Vector3.new(.033,f.b,.033),COLORS.Skin),
            nail=vmPart(m,"Nail",Vector3.new(.03,.026,.01),COLORS.Nail,nil,Enum.Material.Glass)}
    end
    a.thumb={prox=vmPart(m,"Thumb",Vector3.new(.04,.07,.04),COLORS.Skin),dist=vmPart(m,"Thumb",Vector3.new(.036,.058,.036),COLORS.Skin),
        nail=vmPart(m,"Nail",Vector3.new(.032,.026,.01),COLORS.Nail,nil,Enum.Material.Glass)}
    return a
end
-- Builds a hand frame from where the fingers point and which way the palm faces.
local function handFrame(position,fingerDir,palmNormal)
    local y=fingerDir.Unit
    local z=-(palmNormal-y*palmNormal:Dot(y))
    if z.Magnitude<.01 then z=Vector3.zAxis end
    z=z.Unit
    local x=y:Cross(z)
    return CFrame.fromMatrix(position,x,y,z)
end
PainClient.handFrame=handFrame
-- curl: 0 straight .. 1 fist. claw bends only the fingertips. spread fans the fingers.
local function poseArm(a,frame,curl,claw,spread,visible,perFinger)
    local cam=workspace.CurrentCamera.CFrame
    local world=cam*frame
    local function put(p,cf) p.CFrame=cf;p.Transparency=visible and 0 or 1 end
    local alongArm=CFrame.Angles(0,0,math.pi/2)
    put(a.sleeve,world*CFrame.new(0,-.5,.02)*alongArm)
    put(a.cuff,world*CFrame.new(0,-.1,.01)*alongArm)
    put(a.lining,world*CFrame.new(0,-.035,.01)*alongArm)
    -- Two red clouds with white rims on the top of the sleeve (the side facing the camera).
    -- The discs face +Z of the hand frame; in the disc frame -X points into the sleeve.
    for i,c in a.clouds do
        local base=world*CFrame.new(a.side*(i==2 and .04 or -.02),-.3-i*.22,.137)*CFrame.Angles(0,math.pi/2,0)
        for j=1,3 do
            local offset=({Vector3.new(0,0,0),Vector3.new(0,.045,-.04),Vector3.new(0,-.035,.045)})[j]
            put(c.rim[j],base*CFrame.new(-.002,offset.Y,offset.Z))
            put(c.cloud[j],base*CFrame.new(-.009,offset.Y,offset.Z))
        end
    end
    put(a.wrist,world*CFrame.new(0,.0,0))
    put(a.palm,world*CFrame.new(0,.1,0))
    for i,f in a.fingers do
        local d=f.def
        local c=math.clamp(perFinger and perFinger[i] or curl,0,1)
        local base=world*CFrame.new(d.x*a.thumbSide,.195,0)
        local prox=base*CFrame.Angles(0,0,-a.thumbSide*d.spread*(spread or 0))*CFrame.Angles(-c*1.5,0,0)
        put(f.prox,prox*CFrame.new(0,d.a/2,0))
        local dist=prox*CFrame.new(0,d.a,0)*CFrame.Angles(-(c*1.25+(claw or 0)*.95),0,0)
        put(f.dist,dist*CFrame.new(0,d.b/2,0))
        put(f.nail,dist*CFrame.new(0,d.b-.014,.018))
    end
    local tc=math.clamp(perFinger and perFinger[5] or curl,0,1)
    local thumb=world*CFrame.new(a.thumbSide*.08,.06,-.015)*CFrame.Angles(0,0,-a.thumbSide*(.8-.55*tc))*CFrame.Angles(-.35-tc*.5,0,0)
    put(a.thumb.prox,thumb*CFrame.new(0,.035,0))
    local tip=thumb*CFrame.new(0,.07,0)*CFrame.Angles(-tc*.9,0,0)
    put(a.thumb.dist,tip*CFrame.new(0,.029,0))
    put(a.thumb.nail,tip*CFrame.new(0,.046,.02))
end
-- The chakra receiver: a black rod with ringed segments, held in the left fist.
local rod={}
local function buildRod()
    local m=Instance.new("Model");m.Name="ChakraReceiver";m.Parent=env.viewmodel
    rod.shaft=vmPart(m,"Shaft",Vector3.new(.034,.034,1.15),Color3.fromRGB(16,15,20),nil,Enum.Material.Metal)
    rod.tip=vmPart(m,"Tip",Vector3.new(.022,.022,.16),Color3.fromRGB(30,28,36),nil,Enum.Material.Metal)
    rod.rings={}
    for i=1,5 do rod.rings[i]=vmPart(m,"Ring",Vector3.new(.012,.05,.05),Color3.fromRGB(40,38,48),Enum.PartType.Cylinder,Enum.Material.Metal) end
end
local function poseRod(frame,grow,visible)
    local cam=workspace.CurrentCamera.CFrame
    local length=1.15*grow
    local function put(p,cf,t) p.CFrame=cam*cf;p.Transparency=visible and (t or 0) or 1 end
    rod.shaft.Size=Vector3.new(.034,.034,math.max(.01,length))
    put(rod.shaft,frame*CFrame.new(0,0,-length/2+.25))
    put(rod.tip,frame*CFrame.new(0,0,-length+.17))
    for i,r in rod.rings do put(r,frame*CFrame.new(0,0,.15-length*(i/6))*CFrame.Angles(0,math.pi/2,0),grow<i/6 and 1 or 0) end
end

---------------------------------------------------------------- screen
local overlay={}
local function buildOverlay()
    local gui=env.gui
    local frame=Instance.new("Frame");frame.Name="PainOverlay";frame.Size=UDim2.fromScale(1,1);frame.BackgroundTransparency=1;frame.ZIndex=4;frame.Parent=gui
    overlay.root=frame
    -- Vignette from four gradient edges.
    overlay.edges={}
    for i,spec in {{UDim2.fromScale(1,.3),UDim2.fromScale(0,0),90},{UDim2.fromScale(1,.3),UDim2.fromScale(0,.7),-90},{UDim2.fromScale(.25,1),UDim2.fromScale(0,0),0},{UDim2.fromScale(.25,1),UDim2.fromScale(.75,0),180}} do
        local e=Instance.new("Frame");e.Size=spec[1];e.Position=spec[2];e.BackgroundColor3=Color3.fromRGB(6,2,14);e.BorderSizePixel=0;e.BackgroundTransparency=1;e.ZIndex=4;e.Parent=frame
        local g=Instance.new("UIGradient");g.Rotation=spec[3];g.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)});g.Parent=e
        overlay.edges[i]=e
    end
    -- Faint Rinnegan rings over the whole view: the caster's eyes flaring.
    overlay.rings={}
    for i=1,4 do
        local r=Instance.new("Frame");r.AnchorPoint=Vector2.new(.5,.5);r.Position=UDim2.fromScale(.5,.5);r.SizeConstraint=Enum.SizeConstraint.RelativeYY
        r.Size=UDim2.fromScale(.35+i*.22,.35+i*.22);r.BackgroundTransparency=1;r.ZIndex=4;r.Parent=frame
        local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(.5,0);corner.Parent=r
        local stroke=Instance.new("UIStroke");stroke.Color=COLORS.Rinnegan;stroke.Thickness=2+i;stroke.Transparency=1;stroke.Parent=r
        overlay.rings[i]=stroke
    end
    overlay.flash=Instance.new("Frame");overlay.flash.Size=UDim2.fromScale(1,1);overlay.flash.BackgroundColor3=Color3.new(1,1,1)
    overlay.flash.BackgroundTransparency=1;overlay.flash.BorderSizePixel=0;overlay.flash.ZIndex=5;overlay.flash.Parent=frame
end
local function setOverlay(vignette,rings,flash)
    for _,e in overlay.edges do e.BackgroundTransparency=1-math.clamp(vignette,0,1) end
    for i,s in overlay.rings do s.Transparency=1-math.clamp(rings*(1.1-i*.18),0,1) end
    overlay.flash.BackgroundTransparency=1-math.clamp(flash,0,.9)
end
local function kick(power,duration) if power>=shake.power or clock()>shake.untilTime then shake.power=power;shake.untilTime=clock()+duration;shake.duration=duration end end

---------------------------------------------------------------- events
local function ownerModel(data)
    local owner=Players:GetPlayerByUserId(data.owner)
    return owner and owner.Character,owner==player
end
function PainClient.onEvent(kind,data)
    local model,mine=ownerModel(data)
    local root=model and model:FindFirstChild("HumanoidRootPart")
    if kind=="PainShinraCast" then
        VFX.eyeFlare(model,1,.9)
        if root then VFX.sound("Hum",root.Position,.8,2) end
        if mine then cast={kind="Shinra",start=data.start};env.announce("神羅天征","신라천정 · 반경 25 · 손바닥을 펴는 순간 밀어낸다") end
    elseif kind=="PainShinraWave" then
        VFX.shinraWave(data.position,data.radius,data.duration)
        if mine then kick(.05,.12) end
        local me=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not mine and me and (me.Position-data.position).Magnitude<data.radius*1.6 then kick(.02,.2) end
    elseif kind=="PainKnock" then
        VFX.knockTrail(data.model,data.duration)
        if data.model==player.Character then kick(.04,.25) end
    elseif kind=="PainWallHit" then
        VFX.wallHit(data.position,data.normal)
    elseif kind=="PainBanshoCast" then
        VFX.eyeFlare(model,1,.9)
        VFX.aimRings(data.target,.6)
        if root then VFX.sound("Whoosh",root.Position,.5,1.5) end
        if mine then cast={kind="Bansho",start=data.start,target=data.target,windup=data.windup};env.announce("万象天引","만상천인 · 대상을 끌어당겨 차크라 수신기로 찌른다") end
    elseif kind=="PainBanshoMiss" then
        if mine then cast={kind="BanshoMiss",start=data.start};env.announce("万象天引","조준 범위 안에 보이는 대상이 없다") end
    elseif kind=="PainBanshoPull" then
        VFX.pullField(data.target,model,data.duration+.15)
        if mine and cast and cast.kind=="Bansho" then cast.pullStart=data.start;cast.pullDuration=data.duration end
    elseif kind=="PainBanshoStrike" then
        local direction=root and (data.position-root.Position) or Vector3.zAxis
        VFX.stabImpact(data.position,direction)
        if mine and cast and cast.kind=="Bansho" then cast.strike=clock();kick(.035,.1);comboUntil=clock()+1.8 end
    elseif kind=="PainBanshoCancel" then
        if mine and cast and cast.kind=="Bansho" then cast.cancel=clock() end
    elseif kind=="PainChibakuCast" then
        VFX.eyeFlare(model,2,6.3)
        if chibakuViews[data.owner] then chibakuViews[data.owner].stop("replaced") end
        local originFn=nil
        if mine then
            cast={kind="Chibaku",start=data.start,core=data.core}
            originFn=function() return (workspace.CurrentCamera.CFrame*CFrame.new(0,-.28,-.66)).Position end
            env.announce("地爆天星","지폭천성 · 중력 핵 · 바위와 적을 끌어모아 봉인한다")
        end
        chibakuViews[data.owner]=VFX.chibaku(data,{originFn=originFn})
        if root then for i=0,2 do task.delay(i*.4,function() VFX.sound("Thud",root.Position,.8,1.5,.8) end) end end
    elseif kind=="PainChibakuCapture" then
        if data.target==player.Character then env.announce("地爆天星","중력장에 붙잡혔다 · 이동·점프 불가") end
    elseif kind=="PainChibakuBurst" then
        if mine then kick(.09,.45);if cast then cast.burst=clock() end end
        local me=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not mine and me and (me.Position-data.core).Magnitude<120 then kick(.04,.4) end
    elseif kind=="PainChibakuEnd" then
        local view=chibakuViews[data.owner]
        if view and data.reason~="finished" then view.stop(data.reason) end
        chibakuViews[data.owner]=nil
        if mine then afterBlurUntil=clock()+1;if cast and cast.kind=="Chibaku" and data.reason~="finished" then cast=nil end end
    end
end

---------------------------------------------------------------- per frame
local ZERO5={0,0,0,0,0}
local function restPose(side,bob,moving)
    local x=side*.36
    local sway=moving and math.sin(clock()*9)*.018*side or 0
    local pos=Vector3.new(x+sway*.5,-.6+bob,-.8)
    return handFrame(pos,Vector3.new(-side*.18,.82,-.55),Vector3.new(-side*.9,-.1,-.4)),.5,.15,0
end
-- Returns the screen-space look offset that turns the camera toward a world point by `k`.
local function lookToward(camera,point,k,maxPitch)
    local d=camera.CFrame:VectorToObjectSpace((point-camera.CFrame.Position).Unit)
    local yaw=math.atan2(-d.X,-d.Z);local pitch=math.clamp(math.atan2(d.Y,math.sqrt(d.X*d.X+d.Z*d.Z)),-maxPitch,maxPitch)
    return CFrame.Angles(0,yaw*k,0)*CFrame.Angles(pitch*k,0,0)
end
-- info: {melee, sliding, moving, alive, humanoid}. Returns {fov, lean, combo} for Gojo.client.
function PainClient.render(dt,info)
    local n=clock()
    local camera=workspace.CurrentCamera
    if not arms.right then return end
    local isPain=info.isPain
    local out={fov=72,lean=0}
    local vignette,ringGlow,flash=0,0,0
    -- Victims (any kit): sealed bodies are hidden, held bodies lose control locally.
    PainClient.updateVictims(n,info)
    if not isPain then
        poseArm(arms.right,CFrame.identity,0,0,0,false);poseArm(arms.left,CFrame.identity,0,0,0,false);poseRod(CFrame.identity,0,false)
        setOverlay(0,0,0);cast=nil
        return nil
    end
    local bob=info.moving and math.abs(math.sin(n*9))*.025 or math.sin(n*1.8)*.006
    local rF,rCurl,rClaw,rSpread=restPose(1,bob,info.moving)
    local lF,lCurl,lClaw,lSpread=restPose(-1,bob,info.moving)
    local rStagger,lStagger=nil,nil
    local rodFrame,rodGrow=nil,0
    local visible=info.alive
    -- Shared M1 punches and the slide still work: fists follow Gojo.client's melee timing.
    if info.melee then
        local m=info.melee;local a=n-m.start
        local wind=smoothstep(a/m.windup);local strike=smoothstep((a-m.windup)/m.swing)
        local recovery=smoothstep((a-m.windup-m.swing)/(m.duration-m.windup-m.swing))
        local sign=m.combo%2==0 and -1 or 1
        local guard=Vector3.new(sign*.42,-.42,-.78);local prep=Vector3.new(sign*.6,m.combo==3 and -.7 or -.38,-.5)
        local contact=Vector3.new(sign*.06,m.combo==3 and -.1 or -.26,-1.35)
        local fist=guard:Lerp(prep,wind):Lerp(contact,strike):Lerp(guard,recovery)
        local frame=handFrame(fist,Vector3.new(-sign*.1,.25,-1),Vector3.new(-sign*.6,-.8,0))
        if sign>0 then rF=frame;rCurl=1;rClaw=0 else lF=frame;lCurl=1;lClaw=0 end
    end
    if info.sliding then
        rF=rF*CFrame.new(0,-.1,.08)*CFrame.Angles(.4,0,0);lF=lF*CFrame.new(0,-.1,.08)*CFrame.Angles(.4,0,0)
    end
    if cast and not info.alive then cast=nil end
    if cast then
        local a=n-cast.start
        if cast.kind=="Shinra" then
            local cfg=P.ShinraTensei
            local raise=smoothstep(a/cfg.Windup)
            local push=smoothstep((a-cfg.Windup)/.07)
            local settle=smoothstep((a-cfg.Windup-cfg.WaveTime)/cfg.Recovery)
            -- Chest height, palm turning forward, then a hard push and a slow lowering.
            local chest=Vector3.new(.2,-.36,-.6);local thrust=Vector3.new(.12,-.24,-1.05)
            local restPos=rF.Position
            local pos=restPos:Lerp(chest,raise):Lerp(thrust,push)
            pos=pos:Lerp(restPos,settle)
            local fingers=Vector3.new(-.18,.82,-.55):Lerp(Vector3.new(0,1,-.12),raise):Lerp(Vector3.new(0,1,.05),push)
            local palm=Vector3.new(-.9,-.1,-.4):Lerp(Vector3.new(0,0,-1),raise)
            if settle>0 then fingers=fingers:Lerp(Vector3.new(-.18,.82,-.55),settle);palm=palm:Lerp(Vector3.new(-.9,-.1,-.4),settle) end
            rF=handFrame(pos,fingers,palm)
            -- Fingers open one by one: index, middle, ring, pinky, then the thumb; the push spreads them flat.
            rStagger={}
            for i=1,5 do
                local open=smoothstep((a-.06-.07*(i-1))/.1)
                rStagger[i]=(.85-.65*open)*(1-push)*(1-settle)+.5*settle
            end
            rCurl=.5;rClaw=0;rSpread=math.min(1,raise*.5+push)*(1-settle)
            lF=lF*CFrame.new(-.03,-.06*raise*(1-settle),.04)
            -- Head bows, the view narrows and darkens until the push, then a kick and a slow recovery.
            local bow=raise*(1-settle)
            env.commonLook(CFrame.Angles(-math.rad(6)*bow,0,0))
            out.fov=72-8*raise+22*push*(1-smoothstep((a-cfg.Windup)/.35))
            if a>=cfg.Windup then out.fov=math.max(out.fov,72+20*(1-smoothstep((a-cfg.Windup)/.35))) end
            vignette=.45*raise*(1-push*.6)*(1-settle);ringGlow=raise*(1-settle)*.6+push*(1-settle)*.4
            flash=.18*(1-smoothstep((a-cfg.Windup)/.12))*push
            if a>cfg.Windup+cfg.WaveTime+cfg.Recovery+.1 then cast=nil end
        elseif cast.kind=="Bansho" or cast.kind=="BanshoMiss" then
            local cfg=P.BanshoTenin
            local target=cast.target and cast.target:FindFirstChild("HumanoidRootPart")
            local toward=target and camera.CFrame:VectorToObjectSpace((target.Position-camera.CFrame.Position).Unit) or Vector3.new(0,0,-1)
            local reach=smoothstep(a/(cast.kind=="BanshoMiss" and .14 or cfg.Windup))
            local retract=0
            if cast.kind=="BanshoMiss" then retract=smoothstep((a-.18)/.17)
            elseif cast.cancel then retract=smoothstep((n-cast.cancel)/.25)
            elseif cast.strike then retract=smoothstep((n-cast.strike-.15)/.35) end
            -- Right arm shoots out toward the target, palm open and fingers bent to grab.
            local out1=Vector3.new(.24,-.2,-.98)+Vector3.new(toward.X,toward.Y,0)*.25
            local held=Vector3.new(.3,-.27,-.74)
            local pullK=cast.pullStart and smoothstep((n-cast.pullStart)/(cast.pullDuration or .6)) or 0
            local pos=rF.Position:Lerp(out1,reach):Lerp(held,pullK*.6)
            pos=pos:Lerp(rF.Position,retract)
            local tremble=cast.pullStart and not cast.strike and Vector3.new(math.sin(n*61),math.cos(n*53),0)*.006 or Vector3.zero
            rF=handFrame(pos+tremble,(toward+Vector3.new(0,.9,0)):Lerp(Vector3.new(-.18,.82,-.55),retract),toward:Lerp(Vector3.new(-.9,-.1,-.4),retract))
            rCurl=.1+.25*pullK+.25*retract;rClaw=(.55+.25*pullK)*(1-retract);rSpread=1-retract
            env.commonLook(CFrame.new(0,0,-.28*reach*(1-pullK)*(1-retract)))
            out.fov=72-4*reach+6*pullK
            ringGlow=.35*reach*(1-retract)
            -- Left hand: the receiver forms as the body arrives, then a straight stab forward.
            if cast.kind=="Bansho" and cast.pullStart and not cast.cancel then
                local arriveAt=cast.pullStart+(cast.pullDuration or .6)
                local form=smoothstep((n-(arriveAt-.3))/.25)
                local stab=cast.strike and smoothstep((n-cast.strike)/.07) or 0
                local back=cast.strike and smoothstep((n-cast.strike-.12)/.3) or 0
                local gone=cast.strike and smoothstep((n-cast.strike-.3)/.2) or 0
                local ready=Vector3.new(-.32,-.36,-.68);local hit=Vector3.new(-.06,-.24,-1.18)
                local lp=lF.Position:Lerp(ready,form):Lerp(hit,stab):Lerp(lF.Position,back)
                lF=handFrame(lp,Vector3.new(.25,.15,-1):Lerp(Vector3.new(.05,.25,-1),stab),Vector3.new(1,-.2,0))
                lCurl=.95;lClaw=0;lSpread=0
                rodFrame=CFrame.lookAt(lp+Vector3.new(.01,.07,0),lp+Vector3.new(.01,.07,0)+Vector3.new(.08,.04,-1):Lerp(Vector3.new(.03,.06,-1),stab))
                rodGrow=form*(1-gone)
                if stab>0 then env.commonLook(CFrame.new(0,0,-.32*stab*(1-back))) end
                if cast.strike then out.fov=out.fov+8*stab*(1-back) end
            end
            local done=(cast.kind=="BanshoMiss" and a>.4) or (cast.cancel and n-cast.cancel>.3) or (cast.strike and n-cast.strike>.6) or a>3
            if done then cast=nil end
        elseif cast.kind=="Chibaku" then
            local cfg=P.ChibakuTensei
            local gather=smoothstep(a/cfg.Gather)
            local lift=smoothstep((a-cfg.Gather)/(cfg.Launch-cfg.Gather))
            local lower=smoothstep((a-cfg.Burst)/.9)
            local strain=smoothstep((a-cfg.FieldStart)/1.5)*(1-lower)
            local tremble=Vector3.new(math.sin(n*47),math.cos(n*41),0)*.006*strain
            -- Both hands come up and cup the forming core, then lift it to the sky and stay raised.
            local cupR,cupL=Vector3.new(.11,-.33,-.62),Vector3.new(-.11,-.33,-.62)
            local upR,upL=Vector3.new(.24,-.02,-.66),Vector3.new(-.24,-.02,-.66)
            local rp=rF.Position:Lerp(cupR,gather):Lerp(upR,lift)
            local lp=lF.Position:Lerp(cupL,gather):Lerp(upL,lift)
            rp=rp:Lerp(rF.Position,lower);lp=lp:Lerp(lF.Position,lower)
            local fingersCup=Vector3.new(0,.6,-.8);local fingersUp=Vector3.new(0,.35,-1)
            rF=handFrame(rp+tremble,fingersCup:Lerp(fingersUp,lift):Lerp(Vector3.new(-.18,.82,-.55),lower),Vector3.new(-1,0,0):Lerp(Vector3.new(-.2,1,-.3),lift):Lerp(Vector3.new(-.9,-.1,-.4),lower))
            lF=handFrame(lp-tremble,fingersCup:Lerp(fingersUp,lift):Lerp(Vector3.new(.18,.82,-.55),lower),Vector3.new(1,0,0):Lerp(Vector3.new(.2,1,-.3),lift):Lerp(Vector3.new(.9,-.1,-.4),lower))
            rCurl=.35*(1-lift)+.12*lift+.38*lower;lCurl=rCurl;rClaw=.3+.4*strain;lClaw=rClaw;rSpread=lift*(1-lower);lSpread=rSpread
            -- Look up slowly while gathering, follow the core into the sky, come back to aiming at 1.9 s.
            local look=CFrame.Angles(math.rad(7)*gather*(1-lift),0,0)
            local follow=math.sin(math.clamp((a-cfg.Gather)/1.1,0,1)*math.pi)
            if follow>0 and cast.core then look=look*lookToward(camera,cast.core,follow*.85,1.2) end
            local shakeRoll=strain*.004*math.sin(n*31)
            env.commonLook(look*CFrame.Angles(shakeRoll,0,shakeRoll))
            out.fov=72-6*gather*(1-lift)+4*strain
            if a>=cfg.FieldStart and not cast.waveKick then cast.waveKick=true;kick(.03,.25) end
            vignette=.25*gather+.2*strain-.4*lower;ringGlow=.5*gather+.4*strain
            if cast.burst then flash=.6*(1-smoothstep((n-cast.burst)/.35)) end
            if a>cfg.Duration+.2 then cast=nil end
        end
    end
    if n<afterBlurUntil then
        local k=(afterBlurUntil-n)
        env.blur.Size=math.max(env.blur.Size,10*k);vignette=math.max(vignette,.3*k)
    end
    -- Camera shake (positional and angular), decaying over its duration.
    if n<shake.untilTime then
        local k=(shake.untilTime-n)/math.max(.01,shake.duration or .1)
        local p=shake.power*k
        env.commonLook(CFrame.new((math.random()-.5)*p*4,(math.random()-.5)*p*4,0)*CFrame.Angles((math.random()-.5)*p,(math.random()-.5)*p,(math.random()-.5)*p))
    end
    -- Narrow screens squeeze the arms inward, as for the other kits.
    local squeeze=math.min(1,camera.ViewportSize.X/math.max(1,camera.ViewportSize.Y))
    local function narrow(f) return CFrame.new(f.Position*Vector3.new(math.max(.72,squeeze),1,1))*f.Rotation end
    poseArm(arms.right,narrow(rF),rCurl,rClaw,rSpread,visible,rStagger)
    poseArm(arms.left,narrow(lF),lCurl,lClaw,lSpread,visible,lStagger)
    poseRod(rodFrame and narrow(rodFrame) or CFrame.identity,rodGrow,visible and rodFrame~=nil and rodGrow>.01)
    setOverlay(vignette,ringGlow,flash)
    out.combo=n<comboUntil and "만상천인 적중 · 이어서 Q 신라천정 / R 지폭천성" or nil
    return out
end
-- Victim side: the server moves the body; locally we stop the humanoid from fighting it.
function PainClient.updateVictims(n,info)
    local m=player.Character;local h=m and m:FindFirstChildOfClass("Humanoid")
    if h then
        local held=(m:GetAttribute("PainHeldUntil") or 0)>n
        if held~=heldApplied then
            heldApplied=held
            h.PlatformStand=held
            h:SetStateEnabled(Enum.HumanoidStateType.Jumping,not held)
            if not held then h:ChangeState(Enum.HumanoidStateType.GettingUp) end
        end
        local noJump=(m:GetAttribute("PainNoJumpUntil") or 0)>n
        if not held then h:SetStateEnabled(Enum.HumanoidStateType.Jumping,not noJump) end
    end
    -- Bodies sealed inside a Chibaku sphere are hidden from everyone else; the server still owns them normally.
    for _,model in workspace:GetChildren() do
        if model:IsA("Model") and model~=player.Character then
            local hide=(model:GetAttribute("PainSealedUntil") or 0)>n
            if hide~=(sealed[model]==true) then
                sealed[model]=hide or nil
                for _,v in model:GetDescendants() do if v:IsA("BasePart") or v:IsA("Decal") then v.LocalTransparencyModifier=hide and 1 or 0 end end
            end
        end
    end
    for model in sealed do if not model.Parent then sealed[model]=nil end end
    -- Never draw our own Rinnegan or sleeves into the first-person view.
    if m and info and info.isPain then
        for _,v in m:GetChildren() do if v:IsA("BasePart") and (v.Name=="PainRinnegan" or v.Name=="PainSleeve" or v.Name=="PainCloud" or v.Name=="PainCloudRim" or v.Name=="PainNails") then v.LocalTransparencyModifier=1 end end
    end
end
function PainClient.busy() return cast~=nil end
function PainClient.reset()
    cast=nil;comboUntil=0;shake.untilTime=0;afterBlurUntil=0
    if overlay.root then setOverlay(0,0,0) end
end
function PainClient.init(environment)
    env=environment
    arms.right=buildArm(1);arms.left=buildArm(-1)
    buildRod();buildOverlay()
    UIS.WindowFocusReleased:Connect(function() shake.untilTime=0 end)
end
return PainClient
