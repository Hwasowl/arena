-- All Might on the client: huge first-person arms (blue suit, red/white bands, muscled forearms, yellow gloves with
-- jointed fingers), camera work for each technique (including the short Plus Ultra cinematic), screen overlays
-- and shouts, the buff timer, and the local side of being smashed, carried or launched.
-- Gojo.client.luau owns input and the shared HUD; it forwards AllMight* events here and asks for the arm pose every
-- frame. All judgement stays on the server.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local Lighting=game:GetService("Lighting")
local A=require(RS:WaitForChild("AllMightConfig"))
local VFX=require(RS:WaitForChild("AllMightVFX"))
local COLORS=A.Colors
local player=Players.LocalPlayer
local smoothstep=VFX.smoothstep
local function clock() return workspace:GetServerTimeNow() end
local function easeOut(x,power) x=math.clamp(x,0,1);return 1-(1-x)^(power or 2) end
local function window(a,from,to) return math.clamp((a-from)/(to-from),0,1) end

local AllMightClient={}
local env
local cast=nil            -- the local player's own technique in progress
local buffStart,buffUntil,fatigueUntil=0,0,0
local auras={}            -- [owner userId] = buff aura effect
local heldApplied=false
local shake={untilTime=0,power=0,duration=.1}
local freeze={at=0,length=0}   -- hitstop: local animation time stops for `length` at `at`
local comboUntil=0
local revealed={}         -- own body parts shown during the cinematic

---------------------------------------------------------------- arms
-- Hand frame: origin at the wrist, +Y toward the knuckles, palm facing -Z, back of the hand +Z.
-- The forearm runs from the wrist along -Y; the upper arm joins the elbow to a shoulder point in camera space.
local arms={}
local GLOVE,BLUE,MUSCLE=COLORS.Glove,COLORS.Blue,Color3.fromRGB(64,106,218)
local function vmPart(model,name,size,color,shape,material)
    local p=Instance.new("Part");p.Name=name;p.Size=size;p.Color=color;p.Shape=shape or Enum.PartType.Block
    p.Material=material or Enum.Material.SmoothPlastic;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
    p.CastShadow=false;p.Transparency=1;p.Parent=model
    return p
end
local FINGERS={ -- x along the knuckles from the thumb side; three phalanx lengths
    {x=.078,a=.1,b=.07,c=.056},{x=.027,a=.108,b=.076,c=.06},{x=-.024,a=.102,b=.072,c=.056},{x=-.072,a=.086,b=.06,c=.05},
}
local FOREARM=.95
local MUSCLES={ -- forearm bulges in the hand frame (x is mirrored by side): extensor, brachioradialis, flexor
    {at=Vector3.new(.03,-.38,.1),size=Vector3.new(.25,.46,.2)},
    {at=Vector3.new(.1,-.66,.07),size=Vector3.new(.3,.56,.27)},
    {at=Vector3.new(-.08,-.6,-.06),size=Vector3.new(.27,.52,.24)},
}
local function buildArm(side)
    local m=Instance.new("Model");m.Name=side>0 and "AllMightRightArm" or "AllMightLeftArm";m.Parent=env.viewmodel
    local a={side=side,thumbSide=side>0 and -1 or 1,model=m,fingers={},muscles={}}
    a.palm=vmPart(m,"Glove",Vector3.new(.25,.25,.13),GLOVE)
    a.cuff=vmPart(m,"GloveCuff",Vector3.new(.2,.32,.32),GLOVE,Enum.PartType.Cylinder)
    a.knuckles=vmPart(m,"Knuckles",Vector3.new(.25,.06,.11),Color3.fromRGB(240,190,30))
    for i,f in FINGERS do
        a.fingers[i]={def=f,a=vmPart(m,"Finger",Vector3.new(.058,f.a,.058),GLOVE),b=vmPart(m,"Finger",Vector3.new(.054,f.b,.054),GLOVE),
            c=vmPart(m,"Finger",Vector3.new(.05,f.c,.05),GLOVE)}
    end
    a.thumb={a=vmPart(m,"Thumb",Vector3.new(.064,.09,.064),GLOVE),b=vmPart(m,"Thumb",Vector3.new(.058,.075,.058),GLOVE)}
    a.forearm=vmPart(m,"Forearm",Vector3.new(FOREARM,.27,.27),BLUE,Enum.PartType.Cylinder)
    a.white=vmPart(m,"WhiteBand",Vector3.new(.07,.31,.31),COLORS.White,Enum.PartType.Cylinder)
    a.red=vmPart(m,"RedBand",Vector3.new(.06,.3,.3),COLORS.Red,Enum.PartType.Cylinder)
    for i,spec in MUSCLES do a.muscles[i]={spec=spec,p=vmPart(m,"ForearmMuscle",spec.size,MUSCLE,Enum.PartType.Ball)} end
    a.elbow=vmPart(m,"Elbow",Vector3.one*.33,BLUE,Enum.PartType.Ball)
    a.upper=vmPart(m,"UpperArm",Vector3.new(1,.4,.4),BLUE,Enum.PartType.Cylinder)
    a.bicep=vmPart(m,"Bicep",Vector3.new(.5,.46,.6),MUSCLE,Enum.PartType.Ball)
    a.stripe=vmPart(m,"RedStripe",Vector3.new(.08,.44,.44),COLORS.Red,Enum.PartType.Cylinder)
    a.deltoid=vmPart(m,"Deltoid",Vector3.new(.8,.72,.8),BLUE,Enum.PartType.Ball)
    a.glow=Instance.new("PointLight");a.glow.Color=COLORS.Gold;a.glow.Range=3;a.glow.Brightness=0;a.glow.Parent=a.palm
    return a
end
local function handFrame(position,fingerDir,palmNormal)
    local y=fingerDir.Unit
    local z=-(palmNormal-y*palmNormal:Dot(y))
    if z.Magnitude<.01 then z=Vector3.zAxis end
    z=z.Unit
    return CFrame.fromMatrix(position,y:Cross(z),y,z)
end
-- pose: {frame, curl (0..1 or per finger, thumb 5th), flex 0..1, shoulder Vector3, glow 0..1}
local ALONG=CFrame.Angles(0,0,math.pi/2)
local function poseArm(a,pose,visible)
    local cam=workspace.CurrentCamera.CFrame
    local world=cam*pose.frame
    local function put(p,cf) p.CFrame=cf;p.Transparency=visible and 0 or 1 end
    local flex=math.clamp(pose.flex or 0,0,1)
    put(a.palm,world*CFrame.new(0,.12,0))
    put(a.cuff,world*CFrame.new(0,-.07,0)*ALONG)
    put(a.knuckles,world*CFrame.new(0,.25,.01))
    for i,f in a.fingers do
        local d=f.def
        local c=math.clamp(type(pose.curl)=="table" and pose.curl[i] or pose.curl or 0,0,1)
        local base=world*CFrame.new(d.x*a.thumbSide,.25,0)
        local pa=base*CFrame.Angles(-c*1.5,0,0)
        put(f.a,pa*CFrame.new(0,d.a/2,0))
        local pb=pa*CFrame.new(0,d.a,0)*CFrame.Angles(-c*1.65,0,0)
        put(f.b,pb*CFrame.new(0,d.b/2,0))
        local pc=pb*CFrame.new(0,d.b,0)*CFrame.Angles(-c*1.1,0,0)
        put(f.c,pc*CFrame.new(0,d.c/2,0))
    end
    local tc=math.clamp(type(pose.curl)=="table" and pose.curl[5] or pose.curl or 0,0,1)
    local thumb=world*CFrame.new(a.thumbSide*.11,.07,-.03)*CFrame.Angles(0,0,-a.thumbSide*(.85-.7*tc))*CFrame.Angles(-.3-tc*.75,0,0)
    put(a.thumb.a,thumb*CFrame.new(0,.045,0))
    local tip=thumb*CFrame.new(0,.09,0)*CFrame.Angles(-tc*.9,a.thumbSide*tc*.5,0)
    put(a.thumb.b,tip*CFrame.new(0,.037,0))
    -- Forearm with the suit's white and red bands; the muscles swell as the fist clenches.
    put(a.forearm,world*CFrame.new(0,-FOREARM/2-.05,0)*ALONG)
    put(a.white,world*CFrame.new(0,-.2,0)*ALONG)
    put(a.red,world*CFrame.new(0,-.28,0)*ALONG)
    for _,mu in a.muscles do
        mu.p.Size=mu.spec.size*(1+.2*flex)
        put(mu.p,world*CFrame.new(mu.spec.at.X*a.side,mu.spec.at.Y,mu.spec.at.Z*(1+.25*flex)))
    end
    local elbow=(world*CFrame.new(0,-FOREARM-.05,0)).Position
    local shoulder=(cam*CFrame.new(pose.shoulder or Vector3.new(a.side*.95,-1.05,.12))).Position
    put(a.elbow,CFrame.new(elbow))
    local span=shoulder-elbow
    local mid=elbow+span*.5
    if span.Magnitude>.05 then
        a.upper.Size=Vector3.new(span.Magnitude+.12,.4,.4)
        put(a.upper,CFrame.lookAt(mid,shoulder)*CFrame.Angles(0,math.pi/2,0))
        local side=cam.RightVector*a.side
        a.bicep.Size=Vector3.new(.5,.46,.62)*(1+.22*flex)
        put(a.bicep,CFrame.lookAt(elbow+span*.42+cam.UpVector*.1,shoulder)*CFrame.new(0,0,0)*CFrame.Angles(0,math.pi/2,0)*CFrame.new(0,.06,0))
        put(a.stripe,CFrame.lookAt(elbow+span*.72,shoulder)*CFrame.Angles(0,math.pi/2,0))
        put(a.deltoid,CFrame.new(shoulder+side*.05+cam.UpVector*(.06+.06*flex)))
    end
    a.glow.Brightness=(pose.glow or 0)*3
end
local function fist(position,forward,palm,curl,flex,shoulder,glow)
    return {frame=handFrame(position,forward,palm),curl=curl or 1,flex=flex or 0,shoulder=shoulder,glow=glow}
end
-- Blends two poses (positions, directions, curls, shoulder).
local function blend(p,q,t)
    if t<=0 then return p elseif t>=1 then return q end
    local curl
    if type(p.curl)=="table" or type(q.curl)=="table" then
        curl={}
        for i=1,5 do
            local x=type(p.curl)=="table" and p.curl[i] or p.curl
            local y=type(q.curl)=="table" and q.curl[i] or q.curl
            curl[i]=x+(y-x)*t
        end
    else curl=p.curl+(q.curl-p.curl)*t end
    local sp=p.shoulder or Vector3.zero;local sq=q.shoulder or Vector3.zero
    return {frame=p.frame:Lerp(q.frame,t),curl=curl,flex=(p.flex or 0)+((q.flex or 0)-(p.flex or 0))*t,
        shoulder=(p.shoulder and q.shoulder) and sp:Lerp(sq,t) or q.shoulder or p.shoulder,glow=(p.glow or 0)+((q.glow or 0)-(p.glow or 0))*t}
end
-- Fingers close one after another: index first, then middle, ring, little, thumb last.
local function rollingCurl(k,from,to)
    local out={}
    for i=1,5 do out[i]=from+(to-from)*smoothstep((k-(i-1)*.12)/.5) end
    return out
end

---------------------------------------------------------------- screen
local overlay={}
local function makeShout(parent,size,color,stroke)
    local l=Instance.new("TextLabel");l.AnchorPoint=Vector2.new(.5,.5);l.Position=UDim2.fromScale(.5,.42);l.Size=UDim2.fromScale(1,.2)
    l.BackgroundTransparency=1;l.Font=Enum.Font.GothamBlack;l.TextScaled=true;l.TextColor3=color;l.TextStrokeColor3=stroke
    l.TextStrokeTransparency=0;l.TextTransparency=1;l.ZIndex=7;l.Text="";l.Parent=parent
    local c=Instance.new("UITextSizeConstraint");c.MaxTextSize=size;c.Parent=l
    return l
end
local function buildOverlay()
    local frame=Instance.new("Frame");frame.Name="AllMightOverlay";frame.Size=UDim2.fromScale(1,1);frame.BackgroundTransparency=1;frame.ZIndex=4;frame.Parent=env.gui
    overlay.root=frame
    overlay.edges={}
    for i,spec in {{UDim2.fromScale(1,.32),UDim2.fromScale(0,0),90},{UDim2.fromScale(1,.32),UDim2.fromScale(0,.68),-90},{UDim2.fromScale(.26,1),UDim2.fromScale(0,0),0},{UDim2.fromScale(.26,1),UDim2.fromScale(.74,0),180}} do
        local e=Instance.new("Frame");e.Size=spec[1];e.Position=spec[2];e.BackgroundColor3=Color3.fromRGB(8,6,4);e.BorderSizePixel=0;e.BackgroundTransparency=1;e.ZIndex=4;e.Parent=frame
        local g=Instance.new("UIGradient");g.Rotation=spec[3];g.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)});g.Parent=e
        overlay.edges[i]=e
    end
    -- Speed lines: thin bars around the centre that slide outward.
    overlay.lines={}
    for i=1,28 do
        local l=Instance.new("Frame");l.AnchorPoint=Vector2.new(.5,.5);l.BorderSizePixel=0;l.BackgroundColor3=COLORS.Wind
        l.BackgroundTransparency=1;l.ZIndex=5;l.Size=UDim2.fromOffset(3,120);l.Parent=frame
        overlay.lines[i]={f=l,angle=(i-1)/28*math.pi*2+math.random()*.15,seed=math.random()}
    end
    overlay.flash=Instance.new("Frame");overlay.flash.Size=UDim2.fromScale(1,1);overlay.flash.BackgroundColor3=Color3.new(1,1,1)
    overlay.flash.BackgroundTransparency=1;overlay.flash.BorderSizePixel=0;overlay.flash.ZIndex=6;overlay.flash.Parent=frame
    overlay.shout=makeShout(frame,110,COLORS.Gold,Color3.fromRGB(120,40,8))
    overlay.sub=makeShout(frame,40,Color3.new(1,1,1),Color3.fromRGB(30,40,90));overlay.sub.Position=UDim2.fromScale(.5,.56);overlay.sub.Size=UDim2.fromScale(1,.07)
    overlay.grade=Instance.new("ColorCorrectionEffect");overlay.grade.Name="AllMightGrade";overlay.grade.Parent=Lighting
end
local shoutState={text="",start=0,life=0,sub=""}
local function shout(text,life,sub,color)
    shoutState={text=text,start=clock(),life=life,sub=sub or "",color=color or COLORS.Gold}
end
local function setOverlay(vignette,lines,linesColor,flash,flashColor,contrast,lineCenter)
    for _,e in overlay.edges do e.BackgroundTransparency=1-math.clamp(vignette,0,1) end
    local vp=workspace.CurrentCamera.ViewportSize
    local n=clock()
    local cx,cy=(lineCenter or Vector2.new(.5,.5)).X,(lineCenter or Vector2.new(.5,.5)).Y
    for _,l in overlay.lines do
        if lines>.01 then
            local travel=(n*2.2+l.seed)%1
            local radius=(.28+.5*travel)*math.max(vp.X,vp.Y)*.5
            local x=cx*vp.X+math.cos(l.angle)*radius;local y=cy*vp.Y+math.sin(l.angle)*radius
            l.f.Position=UDim2.fromOffset(x,y);l.f.Rotation=math.deg(l.angle)+90
            l.f.Size=UDim2.fromOffset(2+3*lines,60+160*lines*travel)
            l.f.BackgroundColor3=linesColor or COLORS.Wind
            l.f.BackgroundTransparency=1-math.clamp(lines*(1-travel)*.9,0,1)
        else l.f.BackgroundTransparency=1 end
    end
    overlay.flash.BackgroundColor3=flashColor or Color3.new(1,1,1)
    overlay.flash.BackgroundTransparency=1-math.clamp(flash,0,.95)
    overlay.grade.Contrast=contrast or 0;overlay.grade.Saturation=(contrast or 0)*.3
    -- Shouts punch in big and settle.
    local age=n-shoutState.start
    if shoutState.text~="" and age<shoutState.life then
        local inK=easeOut(age/.12,3);local out=smoothstep((age-shoutState.life+.35)/.35)
        overlay.shout.Text=shoutState.text;overlay.shout.TextColor3=shoutState.color
        overlay.shout.Size=UDim2.fromScale(1,.2*(1.6-.6*inK));overlay.shout.TextTransparency=out;overlay.shout.TextStrokeTransparency=out
        overlay.sub.Text=shoutState.sub;overlay.sub.TextTransparency=shoutState.sub~="" and out or 1;overlay.sub.TextStrokeTransparency=overlay.sub.TextTransparency
    else
        overlay.shout.TextTransparency=1;overlay.shout.TextStrokeTransparency=1;overlay.sub.TextTransparency=1;overlay.sub.TextStrokeTransparency=1
    end
end
local function kick(power,duration) if power>=shake.power or clock()>shake.untilTime then shake.power=power;shake.untilTime=clock()+duration;shake.duration=duration end end
local function stop(at,length) freeze.at=at;freeze.length=length end
-- Local animation time with hitstop applied: the pose holds still during a freeze.
local function animTime(n,start)
    local a=n-start
    local fa=freeze.at-start
    if a>fa and fa>=0 then a=math.max(fa,a-freeze.length) end
    return a
end

---------------------------------------------------------------- events
local function ownerOf(data)
    local owner=Players:GetPlayerByUserId(data.owner)
    return owner and owner.Character,owner==player
end
local function rootOf(model) return model and model:FindFirstChild("HumanoidRootPart") end
function AllMightClient.onEvent(kind,data)
    local model,mine=ownerOf(data)
    local root=rootOf(model)
    if kind=="AllMightPowerCast" then
        VFX.powerCast(model,data)
        if root then VFX.sound("Heartbeat",root.Position,.6,1.2) end
        if mine then cast={kind="Power",start=data.start,prep=data.prep,open=data.open} end
    elseif kind=="AllMightPowerOn" then
        if auras[data.owner] then auras[data.owner].dead=true end
        auras[data.owner]=VFX.powerAura(model,data.untilTime)
        if mine then buffStart=data.start;buffUntil=data.untilTime end
    elseif kind=="AllMightPowerOff" then
        if auras[data.owner] then auras[data.owner].dead=true;auras[data.owner]=nil end
        VFX.powerOff(model)
        if mine then
            buffUntil=0
            if data.fatigue>0 then fatigueUntil=clock()+data.fatigue;env.announce("ONE FOR ALL","힘이 빠진다 · 이동 속도 -15% "..data.fatigue.."초") end
        end
    elseif kind=="AllMightSmashCast" then
        VFX.smashCast(model,data)
        if mine then cast={kind="Smash",start=data.start,buffed=data.buffed} end
    elseif kind=="AllMightSmashDash" then
        VFX.smashDash(model,data)
    elseif kind=="AllMightSmashContact" then
        if mine and cast and cast.kind=="Smash" then cast.contact=data.target end
    elseif kind=="AllMightSmashBump" then
        VFX.bump(data)
        if mine and cast and cast.kind=="Smash" then cast.bump=data.start;kick(.05,.2) end
    elseif kind=="AllMightSmashImpact" then
        VFX.smashImpact(data)
        if mine and cast and cast.kind=="Smash" then
            cast.impact=data.start;cast.hit=data.hit
            if data.hit then
                stop(data.start,.08);kick(.12,.4);comboUntil=data.start+A.UnitedStatesOfSmash.PunchEnd+A.UnitedStatesOfSmash.Hold+A.UnitedStatesOfSmash.Return-A.UnitedStatesOfSmash.Impact
                shout("SMASH!",1,"UNITED STATES OF SMASH",data.buffed and COLORS.Gold or Color3.new(1,1,1))
                VFX.sound("VoiceSmash",data.position,1,2)
            else kick(.03,.15) end
        else
            local me=rootOf(player.Character)
            if me and (me.Position-data.position).Magnitude<40 then kick(.04,.3) end
        end
    elseif kind=="AllMightSmashEnd" then
        if mine and cast and cast.kind=="Smash" then cast.ended=clock() end
    elseif kind=="AllMightKnock" then
        VFX.knockTrail(data.model,data.duration,data.heavy)
        if data.model==player.Character then kick(data.heavy and .08 or .03,.3) end
    elseif kind=="AllMightWallHit" then
        VFX.wallHit(data.position,data.normal)
    elseif kind=="AllMightUltraCast" then
        VFX.ultraCast(model,data)
        if root then VFX.sound("Rumble",root.Position,.6,1.2,1.4) end
        if mine then cast={kind="Ultra",start=data.start,direction=data.direction,buffed=data.buffed};comboUntil=0 end
    elseif kind=="AllMightUltraDash" then
        VFX.ultraDash(model,data)
        if mine and cast and cast.kind=="Ultra" then cast.dash=data.start end
    elseif kind=="AllMightUltraFail" then
        VFX.ultraFail(data)
        if mine and cast and cast.kind=="Ultra" then cast.fail=data.start;env.announce("PLUS ULTRA","돌진 경로에 적이 없다 · 재사용 대기 30초") end
    elseif kind=="AllMightUltraContact" then
        if mine and cast and cast.kind=="Ultra" then cast.contact=data.start;cast.target=data.target end
        VFX.ultraChase(model,data.target,A.PlusUltra.Uppercut,data.start+A.PlusUltra.Lift)
    elseif kind=="AllMightUltraPunch" then
        VFX.ultraPunch(data)
        if mine then
            if data.index==1 then kick(.1,.35);stop(data.start,.05) else kick(.05,.2) end
        end
    elseif kind=="AllMightUltraUppercut" then
        VFX.ultraUppercut(data,data.target)
        if mine and cast and cast.kind=="Ultra" then
            cast.uppercut=data.start;cast.apex=data.apex
            stop(data.start,.12);kick(.16,.55)
            shout("PLUS ULTRA!!!",1.6,"",COLORS.Gold)
            VFX.sound("VoiceUltra",data.position,1,3)
        else
            local me=rootOf(player.Character)
            if me and (me.Position-data.position).Magnitude<90 then kick(.07,.5) end
        end
    elseif kind=="AllMightUltraApex" then
        VFX.ultraApex(data.position)
        if mine and cast and cast.kind=="Ultra" then cast.apexAt=data.start end
    elseif kind=="AllMightUltraLand" then
        VFX.ultraLand(data.position)
        if mine then kick(.06,.3) end
    elseif kind=="AllMightUltraLost" or kind=="AllMightUltraEnd" then
        if mine and cast and cast.kind=="Ultra" and data.reason~="finished" then cast.ended=clock() end
    end
end

---------------------------------------------------------------- per frame
local function lookToward(camera,point,k,maxPitch)
    local d=camera.CFrame:VectorToObjectSpace((point-camera.CFrame.Position).Unit)
    local yaw=math.atan2(-d.X,-d.Z);local pitch=math.clamp(math.atan2(d.Y,math.sqrt(d.X*d.X+d.Z*d.Z)),-maxPitch,maxPitch)
    return CFrame.Angles(0,yaw*k,0)*CFrame.Angles(pitch*k,0,0)
end
-- Shows (or hides again) the caster's own body for the cinematic shots.
local function revealBody(m,on)
    if on and m then
        for _,v in m:GetDescendants() do
            if v:IsA("BasePart") and v.Name~="HumanoidRootPart" then v.LocalTransparencyModifier=0;revealed[v]=true end
        end
    else
        for v in revealed do if v.Parent then v.LocalTransparencyModifier=1 end end
        table.clear(revealed)
    end
end
local cinemaParams=RaycastParams.new();cinemaParams.FilterType=Enum.RaycastFilterType.Exclude;cinemaParams.RespectCanCollide=true
-- A pulled-back side view framing both bodies; the camera never goes through walls.
local function cinematicFrame(camera,me,target,direction)
    local mid=(me.Position+target.Position)/2
    local side=direction:Cross(Vector3.yAxis).Unit
    local want=me.Position+side*9-direction*7+Vector3.yAxis*2
    local list={VFX.folder,camera}
    for _,p in Players:GetPlayers() do if p.Character then table.insert(list,p.Character) end end
    table.insert(list,target.Parent)
    cinemaParams.FilterDescendantsInstances=list
    local from=me.Position+Vector3.yAxis*1.5
    local hit=workspace:Raycast(from,want-from,cinemaParams)
    if hit then want=from+(want-from).Unit*math.max(1.5,hit.Distance-1) end
    return CFrame.lookAt(want,mid+Vector3.yAxis*1.5)
end
-- info: {isAllMight, melee, sliding, moving, alive}. Returns {fov, fovAdd, combo, rReady} for Gojo.client.
function AllMightClient.render(dt,info)
    local n=clock()
    local camera=workspace.CurrentCamera
    if not arms.right then return end
    AllMightClient.updateVictims(n)
    local m=player.Character
    if not info.isAllMight then
        poseArm(arms.right,fist(Vector3.zero,Vector3.yAxis,-Vector3.zAxis),false);poseArm(arms.left,fist(Vector3.zero,Vector3.yAxis,-Vector3.zAxis),false)
        setOverlay(0,0,nil,0,nil,0);cast=nil;revealBody(nil,false)
        return nil
    end
    local out={fov=72,fovAdd=0}
    local vignette,lines,linesColor,flash,flashColor,contrast=0,0,nil,0,nil,0
    local lineCenter=nil
    local buffed=n<buffUntil
    local visible=info.alive
    -- Idle: loosely clenched fists low at both sides, a slow breath. Running: the body leans and the arms pump.
    local t=n
    local swing=info.moving and math.sin(t*(buffed and 11 or 9)) or 0
    local breathe=math.sin(t*1.6)*.012
    local run=info.moving and 1 or 0
    local function restFor(side)
        local s=swing*side
        local pos=Vector3.new(side*.56,-.66+breathe-.05*run+.06*math.max(0,s)*run,-.98-.24*s*run)
        return fist(pos,Vector3.new(-side*.12,.42+.2*s*run,-1),Vector3.new(-side,-.25,0),.72,.15,Vector3.new(side*.98,-1.06+.04*run,.14+.12*s*run))
    end
    local R,L=restFor(1),restFor(-1)
    if info.moving and not cast then env.commonLook(CFrame.new(0,-.12*run,0)*CFrame.Angles(-.035*run,0,swing*.006)) end
    if buffed then
        R.glow=.6+.3*math.sin(n*14);L.glow=R.glow
        out.fovAdd=7*smoothstep((n-buffStart)/.4)*smoothstep((buffUntil-n)/.4)
        vignette=.08
    end
    -- Shared M1 punches: heavy straight punches, alternating fists, with the shoulder driving through.
    if info.melee and not cast then
        local me=info.melee;local a=n-me.start
        local wind=smoothstep(a/me.windup);local strike=smoothstep((a-me.windup)/me.swing)
        local back=smoothstep((a-me.windup-me.swing)/math.max(.05,me.duration-me.windup-me.swing))
        local side=me.combo%2==0 and -1 or 1
        local rest=side>0 and R or L
        local cock=fist(Vector3.new(side*.7,-.6,-.62),Vector3.new(-side*.15,.2,-1),Vector3.new(-side*.3,-1,0),1,.7,Vector3.new(side*1.05,-1.0,.3))
        local hit=fist(Vector3.new(side*.12,-.3,-1.5),Vector3.new(0,.05,-1),Vector3.new(0,-1,0),1,1,Vector3.new(side*.78,-.86,-.25))
        local pose=blend(blend(blend(rest,cock,wind),hit,strike),rest,back)
        if side>0 then R=pose else L=pose end
        out.fovAdd+=5*strike*(1-back)
    end
    if info.sliding then
        R.frame=R.frame*CFrame.new(0,-.1,.1);L.frame=L.frame*CFrame.new(0,-.1,.1)
    end
    if cast and not info.alive then cast=nil end
    local cinematic=0
    if cast then
        local a=animTime(n,cast.start)
        if cast.kind=="Power" then
            ---------------------------------------------------------------- Q
            local cfg=A.OneForAll
            local gather=easeOut(a/cfg.Open,2.2)
            local open=easeOut((a-cfg.Open)/.18,3)
            local settle=smoothstep((a-cfg.Prep)/.35)
            -- 0–0.45: right fist to the chest, left fist to the waist, fingers closing one by one.
            local chestR=fist(Vector3.new(.2,-.4,-.66),Vector3.new(-.6,.5,-.45),Vector3.new(-.4,-.1,-1),rollingCurl(gather,.7,1),gather,Vector3.new(.82,-.98,.02))
            local waistL=fist(Vector3.new(-.42,-.86,-.72),Vector3.new(.2,.6,-.7),Vector3.new(.9,-.2,0),rollingCurl(gather,.7,1),gather,Vector3.new(-.82,-1.1,.05))
            -- 0.45–0.85: arms thrown wide, chest open.
            local wideR=fist(Vector3.new(1.05,-.36,-.86),Vector3.new(.6,.55,-.55),Vector3.new(0,-.6,-1),1,1,Vector3.new(1.08,-.95,.2),1)
            local wideL=fist(Vector3.new(-1.05,-.36,-.86),Vector3.new(-.6,.55,-.55),Vector3.new(0,-.6,-1),1,1,Vector3.new(-1.08,-.95,.2),1)
            R=blend(blend(blend(R,chestR,gather),wideR,open),R,settle)
            L=blend(blend(blend(L,waistL,gather),wideL,open),L,settle)
            local tremble=(1-open)*gather*.006
            R.frame=CFrame.new(math.sin(n*57)*tremble,math.cos(n*49)*tremble,0)*R.frame
            -- Camera: dips while gathering, rises and widens fast when the chest opens.
            local dip=gather*(1-open)
            env.commonLook(CFrame.new(0,-.35*dip+.25*open*(1-settle),0)*CFrame.Angles(-.08*dip+.05*open*(1-settle),0,0))
            out.fov=72-6*dip+24*open*(1-smoothstep((a-cfg.Open-.15)/.5))+7*settle
            vignette=.5*dip+.15*open*(1-settle)
            flash=.35*open*(1-smoothstep((a-cfg.Open)/.25));flashColor=COLORS.Gold
            lines=open*(1-settle)*.8;linesColor=COLORS.Gold
            if a>=cfg.Open and not cast.roared then
                cast.roared=true;kick(.06,.35)
                shout("ONE FOR ALL — FULL POWER",1.6,"10초 · 이동 +35% · 기본공격 +25% · E +20% · 받는 피해 -15%")
            end
            if a>cfg.Prep+.4 then cast=nil end
        elseif cast.kind=="Smash" then
            ---------------------------------------------------------------- E
            local cfg=A.UnitedStatesOfSmash
            local crouch=easeOut(a/cfg.Crouch,2)
            local dash=window(a,cfg.Crouch,cfg.DashEnd)
            local draw=easeOut((a-cfg.DashEnd)/(cfg.WindEnd-cfg.DashEnd),2)
            local punch=easeOut((a-cfg.WindEnd)/(cfg.Impact-cfg.WindEnd),3.2)
            local holdEnd=cfg.PunchEnd+cfg.Hold
            local back=smoothstep((a-holdEnd)/cfg.Return)
            local gold=cast.buffed and 1 or .6
            -- Right arm cocked back with the fist at the screen's right; left arm forward as a guard.
            local cocked=fist(Vector3.new(.74,-.4,-.62),Vector3.new(-.25,.35,-1),Vector3.new(-.3,-1,0),1,.8,Vector3.new(1.08,-.98,.32),.5*gold)
            local drawn=fist(Vector3.new(.92,-.3,-.4),Vector3.new(-.4,.4,-.9),Vector3.new(-.2,-1,0),1,1,Vector3.new(1.15,-.92,.45),gold)
            local thrown=fist(Vector3.new(.04,-.2,-1.55),Vector3.new(0,.06,-1),Vector3.new(0,-1,0),1,1,Vector3.new(.62,-.82,-.42),gold)
            local guard=fist(Vector3.new(-.36,-.5,-1.0),Vector3.new(.25,.5,-1),Vector3.new(.8,-.4,0),.9,.5,Vector3.new(-.95,-1.04,.05))
            local tuck=fist(Vector3.new(-.62,-.72,-.6),Vector3.new(.2,.6,-.7),Vector3.new(.9,-.2,0),1,.6,Vector3.new(-1.0,-1.0,.3))
            R=blend(blend(blend(blend(R,cocked,crouch),drawn,draw),thrown,punch),R,back)
            L=blend(blend(blend(L,guard,crouch),tuck,punch),L,back)
            -- Camera: low crouch, narrow view; the dash widens it; the wind-up twists right; the punch swings left.
            local low=crouch*(1-back)
            local twist=.14*draw*(1-punch)-.1*punch*(1-back)
            env.commonLook(CFrame.new(0,-.9*low,0)*CFrame.Angles(-.03*low,twist,-.05*draw*(1-punch)+.04*punch*(1-back)))
            out.fov=72-8*crouch*(1-dash)+16*dash*(1-draw)-6*draw*(1-punch)+18*punch*(1-smoothstep((a-cfg.Impact)/.4))
            out.fov=out.fov*(1-back)+72*back
            vignette=.55*crouch*(1-dash)+.35*draw*(1-punch)
            lines=(dash>0 and dash<1 and not cast.bump) and .9 or 0
            if cast.impact and cast.hit then
                local k=1-smoothstep((n-cast.impact-.08)/.3)
                flash=math.max(flash,.85*k);lines=math.max(lines,k)
                contrast=.35*k
            end
            if a>=cfg.DashEnd+.02 and not cast.called and not cast.bump then
                cast.called=true
                shout("UNITED STATES OF...",cfg.Impact-cfg.DashEnd+.1,"",COLORS.Gold)
                if m and rootOf(m) then VFX.sound("VoiceSmashLead",rootOf(m).Position,.9,1.5) end
            end
            -- Steam off the extended arm while it is held out.
            if cast.impact and not cast.steamed then
                cast.steamed=true
                VFX.steam(function() return (camera.CFrame*CFrame.new(.1,-.2,-1.6)).Position end,cfg.Hold+.2,.05)
            end
            if cast.bump then
                local k=n-cast.bump
                R=blend(R,fist(Vector3.new(.3,-.35,-.9),Vector3.new(-.1,.3,-1),Vector3.new(0,-1,0),1,.6),smoothstep(k/.06)*(1-smoothstep((k-.1)/.3)))
                if k>.45 then cast=nil end
            elseif a>holdEnd+cfg.Return+.05 or (cast.ended and n-cast.ended>.3) then cast=nil end
        elseif cast.kind=="Ultra" then
            ---------------------------------------------------------------- R
            local cfg=A.PlusUltra
            local gather=easeOut(a/cfg.Windup,2)
            local dashK=cast.dash and window(n,cast.dash,cast.dash+cfg.DashTime) or 0
            local raised=fist(Vector3.new(.42,-.06,-.8),Vector3.new(-.15,.8,-.6),Vector3.new(-.8,-.1,-.5),rollingCurl(gather,.7,1),1,Vector3.new(.95,-.9,0),.8)
            local drawnBack=fist(Vector3.new(.84,-.42,-.42),Vector3.new(-.4,.35,-.9),Vector3.new(-.2,-1,0),1,1,Vector3.new(1.12,-.95,.42),1)
            R=blend(blend(R,raised,gather),drawnBack,easeOut(dashK/.4,2))
            L=blend(L,fist(Vector3.new(-.5,-.62,-.82),Vector3.new(.2,.5,-1),Vector3.new(.8,-.4,0),1,.7,Vector3.new(-1,-1.02,.1)),gather)
            local look=CFrame.Angles(-.12*gather*(1-dashK),0,0)
            out.fov=72-8*gather*(1-dashK)+22*easeOut(dashK,2)
            vignette=.45*gather*(1-dashK)
            lines=dashK>0 and dashK<1 and 1 or 0;linesColor=COLORS.Speed
            if cast.fail then
                local k=n-cast.fail
                R=blend(R,fist(Vector3.new(.3,-.7,-.7),Vector3.new(0,.2,-1),Vector3.new(0,-1,0),.8,.3),smoothstep(k/.2))
                look=look*CFrame.Angles(-.08*math.sin(math.clamp(k/.5,0,1)*math.pi),0,.05*math.sin(math.clamp(k/.5,0,1)*math.pi))
                lines=0
                if k>.7 then cast=nil end
            end
            if cast and cast.contact then
                local c=animTime(n,cast.contact)
                local targetRoot=rootOf(cast.target)
                local punch1=easeOut(c/cfg.Punch1,3)
                local chase=window(c,cfg.Lift,cfg.ChaseEnd)
                local wind=window(c,cfg.ChaseEnd,cfg.WindEnd)
                local upper=easeOut((c-cfg.WindEnd)/(cfg.Uppercut-cfg.WindEnd),3)
                local sky=window(c,cfg.Uppercut+.15,cfg.Settle)
                local lower=smoothstep((c-cfg.Settle-.35)/(cfg.End-cfg.Settle-.35))
                local first=fist(Vector3.new(.05,-.2,-1.5),Vector3.new(0,.08,-1),Vector3.new(0,-1,0),1,1,Vector3.new(.62,-.82,-.42),1)
                local under=fist(Vector3.new(.62,-1.0,-.62),Vector3.new(-.2,.9,-.3),Vector3.new(-.9,0,-.3),1,.8,Vector3.new(1.0,-1.15,.2),.8)
                local jab=fist(Vector3.new(.22,-.12,-1.3),Vector3.new(-.05,.55,-.8),Vector3.new(-.2,-.6,-.6),1,1,Vector3.new(.7,-.85,-.3),.9)
                local coiled=fist(Vector3.new(.88,-.72,-.36),Vector3.new(-.3,.7,-.6),Vector3.new(-.6,-.5,0),1,1,Vector3.new(1.18,-1.0,.45),1)
                local skyward=fist(Vector3.new(.24,.34,-.86),Vector3.new(-.05,1,-.15),Vector3.new(-.6,0,-.8),1,1,Vector3.new(.7,-.6,-.1),1)
                local jabK=math.sin(window(c,cfg.Punch2-.1,cfg.Punch2+.12)*math.pi)
                local pose=blend(R,first,punch1)
                pose=blend(pose,under,smoothstep(window(c,cfg.Lift-.1,cfg.Lift+.25)))
                pose=blend(pose,jab,jabK)
                pose=blend(pose,coiled,easeOut(wind/.6,2))
                pose=blend(pose,skyward,upper)
                pose=blend(pose,restFor(1),lower)
                R=pose
                L=blend(L,fist(Vector3.new(-.6,-.78,-.66),Vector3.new(.2,.6,-.7),Vector3.new(.9,-.2,0),1,.8,Vector3.new(-1.05,-1.0,.3)),math.min(1,punch1+wind))
                -- Camera: assist toward the target while chasing, a short cinematic for the wind-up and the
                -- uppercut, then first person again looking up as the target becomes a light in the sky.
                look=CFrame.identity
                local assist=smoothstep(window(c,cfg.Lift-.1,cfg.Lift+.3))*(1-smoothstep(window(c,cfg.Uppercut+.15,cfg.Uppercut+.45)))
                if targetRoot and assist>0 then look=lookToward(camera,targetRoot.Position+Vector3.yAxis*.5,.55*assist,1.1) end
                local skyLook=smoothstep(window(c,cfg.Uppercut+.1,cfg.Uppercut+.5))*(1-smoothstep(window(c,cfg.Settle+.2,cfg.End)))
                if skyLook>0 then
                    local point=targetRoot and targetRoot.Position or cast.apex
                    if cast.apexAt and cast.apex then point=cast.apex end
                    if point then look=look*lookToward(camera,point,skyLook,1.4) end
                end
                cinematic=smoothstep(window(c,cfg.ChaseEnd-.05,cfg.ChaseEnd+.3))*(1-smoothstep(window(c,cfg.Uppercut+.08,cfg.Uppercut+.42)))
                local fov=94-14*chase-14*wind+30*upper
                fov=fov*(1-sky)+76*sky
                out.fov=fov*(1-lower)+72*lower
                vignette=.4*wind*(1-upper)+.2*chase
                lines=math.max(chase*.7*(1-wind),upper*(1-sky))
                linesColor=c>=cfg.Uppercut and COLORS.Gold or COLORS.Wind
                if c>=cfg.Lift and c<cfg.ChaseEnd then lineCenter=Vector2.new(.5,.2) end
                local f1=1-smoothstep((c-cfg.Punch1)/.25)
                if c>=cfg.Punch1 then flash=math.max(flash,.75*f1);flashColor=Color3.new(1,1,1);lines=math.max(lines,f1) end
                if cast.uppercut then
                    local k=1-smoothstep((n-cast.uppercut-.12)/.4)
                    flash=math.max(flash,.95*k);flashColor=Color3.fromRGB(255,240,190);contrast=.5*k
                end
                if c>=cfg.ChaseEnd and not cast.plus then
                    cast.plus=true
                    shout("PLUS...",cfg.Uppercut-cfg.ChaseEnd+.05,"",COLORS.Gold)
                    if m and rootOf(m) then VFX.sound("Heartbeat",rootOf(m).Position,.9,1.2);VFX.sound("VoicePlus",rootOf(m).Position,.9,1.5) end
                end
                if cast.uppercut and not cast.steamed then
                    cast.steamed=true
                    VFX.steam(function() return (camera.CFrame*CFrame.new(.24,.3,-.9)).Position end,cfg.End-cfg.Uppercut,.06)
                end
                if c>cfg.End+.1 then cast=nil end
            end
            if cast then env.commonLook(look) end
            if cast and cast.ended and n-cast.ended>.4 then cast=nil end
        end
    end
    -- The cinematic shot blends from the first-person camera and back; the body is shown only while it lasts.
    if cinematic>.001 and cast and cast.target and m and rootOf(m) and rootOf(cast.target) then
        local shot=cinematicFrame(camera,rootOf(m),rootOf(cast.target),cast.direction or Vector3.new(0,0,-1))
        local blended=camera.CFrame:Lerp(shot,smoothstep(cinematic))
        env.commonLook(camera.CFrame:Inverse()*blended)
        revealBody(m,cinematic>.25)
        if cinematic>.25 then visible=false end
    elseif next(revealed) then revealBody(nil,false) end
    -- Camera shake, decaying over its duration.
    if n<shake.untilTime then
        local k=(shake.untilTime-n)/math.max(.01,shake.duration)
        local p=shake.power*k
        env.commonLook(CFrame.new((math.random()-.5)*p*4,(math.random()-.5)*p*4,0)*CFrame.Angles((math.random()-.5)*p,(math.random()-.5)*p,(math.random()-.5)*p*.6))
    end
    if n<fatigueUntil then vignette=math.max(vignette,.25*(fatigueUntil-n)/1.2) end
    -- Narrow screens squeeze the arms inward, as for the other kits.
    local squeeze=math.min(1,camera.ViewportSize.X/math.max(1,camera.ViewportSize.Y))
    local function narrow(pose)
        local f=pose.frame
        pose.frame=CFrame.new(f.Position*Vector3.new(math.max(.72,squeeze),1,1))*f.Rotation
        if pose.shoulder then pose.shoulder=pose.shoulder*Vector3.new(math.max(.8,squeeze),1,1) end
        return pose
    end
    poseArm(arms.right,narrow(R),visible)
    poseArm(arms.left,narrow(L),visible)
    setOverlay(vignette,lines,linesColor,flash,flashColor,contrast,lineCenter)
    -- Never draw our own hair or suit pieces into the first-person view (the cinematic shows the whole body).
    if m and cinematic<=.25 then
        for _,v in m:GetChildren() do if v:IsA("BasePart") and string.sub(v.Name,1,8)=="AllMight" then v.LocalTransparencyModifier=1 end end
    end
    local rWindow=n<comboUntil
    if rWindow then out.combo="SMASH 적중 · 지금 R  PLUS ULTRA로 연계"
    elseif buffed then out.combo=string.format("ONE FOR ALL  ·  FULL POWER   %.1f초",buffUntil-n) end
    out.rReady=rWindow
    return out
end
-- Victim side: the server moves the body; locally the humanoid stops fighting it.
function AllMightClient.updateVictims(n)
    local m=player.Character;local h=m and m:FindFirstChildOfClass("Humanoid")
    if not h then return end
    local held=(m:GetAttribute("AllMightHeldUntil") or 0)>n
    if held~=heldApplied then
        heldApplied=held
        h.PlatformStand=held
        h:SetStateEnabled(Enum.HumanoidStateType.Jumping,not held)
        if not held then h:ChangeState(Enum.HumanoidStateType.GettingUp) end
    end
    -- Runs after PainClient each frame, so it decides jumping with every kit's locks in view.
    local locked=held or (m:GetAttribute("AllMightNoJumpUntil") or 0)>n or (m:GetAttribute("PainNoJumpUntil") or 0)>n or (m:GetAttribute("PainHeldUntil") or 0)>n
    h:SetStateEnabled(Enum.HumanoidStateType.Jumping,not locked)
end
function AllMightClient.busy() return cast~=nil end
function AllMightClient.buffed() return clock()<buffUntil end
function AllMightClient.reset()
    cast=nil;comboUntil=0;shake.untilTime=0;freeze.length=0;buffUntil=0;fatigueUntil=0
    revealBody(nil,false)
    if overlay.root then setOverlay(0,0,nil,0,nil,0) end
end
function AllMightClient.init(environment)
    env=environment
    arms.right=buildArm(1);arms.left=buildArm(-1)
    buildOverlay()
    UIS.WindowFocusReleased:Connect(function() shake.untilTime=0 end)
end
return AllMightClient
