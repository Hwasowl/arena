-- Yujiro Hanma on the client: huge bare first-person arms (deltoid, biceps, forearm muscle masses and veins, jointed
-- fingers: fist, open palm, claw grab, palm strike, two-hand lift) and a first-person leg for the axe kick; camera work
-- for each technique (including the Ogre's Judgment cinematic: rear shot of the Demon Back opening, side shot before
-- the final punch), screen grade and overlays, hitstop, and the victim's side (the view from Yujiro's grip).
-- Gojo.client.luau owns input and the shared HUD; it forwards Yujiro* events here and asks for the arm pose every
-- frame. All judgement stays on the server. The camera is only ever offset per frame through env.commonLook (undone
-- by Gojo.client every frame), the FOV is returned to Gojo.client, and the colour grade is rewritten every frame, so
-- nothing can stay stuck after a cinematic, a death, a reset or a character switch.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local Lighting=game:GetService("Lighting")
local Y=require(RS:WaitForChild("YujiroConfig"))
local VFX=require(RS:WaitForChild("YujiroVFX"))
local COLORS=Y.Colors
local player=Players.LocalPlayer
local smoothstep,window,bump,easeOut=VFX.smoothstep,VFX.window,VFX.bump,VFX.easeOut
local function clock() return workspace:GetServerTimeNow() end
local function lerp(a,b,t) return a+(b-a)*t end

local YujiroClient={}
local env
local cast=nil            -- own technique in progress: {kind, start, ...}
local victim=nil          -- something being done to us: {kind="Judgment"|"Rush", start, caster}
local combo={untilTime=0,text=""}
local shake={untilTime=0,power=0,duration=.1}
local freeze={at=0,length=0}   -- hitstop / slowdown: own animation time stops for `length` at `at`
local revealed={}
local buffUntil=0
-- Comfort setting (player attribute "Comfort"): weaker shakes and flashes.
local function comfort() return player:GetAttribute("Comfort")==true end
local function kick(power,duration)
    power*=comfort() and .3 or 1
    if power>=shake.power or clock()>shake.untilTime then shake.power=power;shake.untilTime=clock()+duration;shake.duration=duration end
end
local function stop(at,length) freeze.at=at;freeze.length=length end
local function animTime(n,start)
    local a=n-start
    local fa=freeze.at-start
    if a>fa and fa>=0 then a=math.max(fa,a-freeze.length) end
    return a
end

---------------------------------------------------------------- arms and leg
-- Hand frame: origin at the wrist, +Y toward the knuckles, palm facing -Z, back of the hand +Z.
-- The forearm runs from the wrist along -Y; the upper arm joins the elbow to a shoulder point in camera space.
local arms={}
local leg=nil
local SKIN,DEEP,MUSCLE,VEIN,NAIL=COLORS.Skin,COLORS.SkinDeep,COLORS.Muscle,COLORS.Vein,COLORS.Nail
local function vmPart(model,name,size,color,shape)
    local p=Instance.new("Part");p.Name=name;p.Size=size;p.Color=color;p.Shape=shape or Enum.PartType.Block
    p.Material=Enum.Material.SmoothPlastic;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
    p.CastShadow=false;p.Transparency=1;p.Parent=model
    return p
end
local FINGERS={{x=.082,a=.104,b=.072,c=.058},{x=.028,a=.112,b=.078,c=.062},{x=-.025,a=.106,b=.074,c=.058},{x=-.075,a=.088,b=.062,c=.05}}
local FOREARM=1.0
local MUSCLES={ -- forearm masses in the hand frame (x mirrored by side): extensors, brachioradialis, flexors
    {at=Vector3.new(.04,-.36,.11),size=Vector3.new(.27,.48,.22)},
    {at=Vector3.new(.11,-.68,.08),size=Vector3.new(.34,.6,.3)},
    {at=Vector3.new(-.09,-.62,-.07),size=Vector3.new(.3,.56,.27)},
}
local VEINS={ -- thin raised veins along the forearm: from, to (hand frame)
    {Vector3.new(.05,-.12,.13),Vector3.new(.09,-.5,.17)},{Vector3.new(.09,-.5,.17),Vector3.new(.04,-.86,.16)},
    {Vector3.new(-.06,-.2,.12),Vector3.new(-.02,-.62,.15)},
}
local function buildArm(side)
    local m=Instance.new("Model");m.Name=side>0 and "YujiroRightArm" or "YujiroLeftArm";m.Parent=env.viewmodel
    local a={side=side,thumbSide=side>0 and -1 or 1,model=m,fingers={},muscles={},veins={}}
    a.palm=vmPart(m,"Palm",Vector3.new(.27,.27,.14),SKIN)
    a.heel=vmPart(m,"PalmHeel",Vector3.new(.24,.12,.16),DEEP,Enum.PartType.Ball)
    a.knuckles=vmPart(m,"Knuckles",Vector3.new(.27,.07,.12),DEEP)
    for i,f in FINGERS do
        a.fingers[i]={def=f,a=vmPart(m,"Finger",Vector3.new(.064,f.a,.064),SKIN),b=vmPart(m,"Finger",Vector3.new(.06,f.b,.06),SKIN),
            c=vmPart(m,"Finger",Vector3.new(.055,f.c,.055),SKIN),nail=vmPart(m,"Nail",Vector3.new(.044,.022,.016),NAIL)}
    end
    a.thumb={a=vmPart(m,"Thumb",Vector3.new(.07,.095,.07),SKIN),b=vmPart(m,"Thumb",Vector3.new(.064,.08,.064),SKIN)}
    a.wrist=vmPart(m,"Wrist",Vector3.new(.22,.3,.28),SKIN,Enum.PartType.Cylinder)
    a.forearm=vmPart(m,"Forearm",Vector3.new(FOREARM,.3,.3),SKIN,Enum.PartType.Cylinder)
    for i,spec in MUSCLES do a.muscles[i]={spec=spec,p=vmPart(m,"ForearmMuscle",spec.size,MUSCLE,Enum.PartType.Ball)} end
    for i,v in VEINS do a.veins[i]={from=v[1],to=v[2],p=vmPart(m,"Vein",Vector3.new(.026,.026,.3),VEIN,Enum.PartType.Cylinder)} end
    a.elbow=vmPart(m,"Elbow",Vector3.one*.36,SKIN,Enum.PartType.Ball)
    a.upper=vmPart(m,"UpperArm",Vector3.new(1,.44,.44),SKIN,Enum.PartType.Cylinder)
    a.bicep=vmPart(m,"Bicep",Vector3.new(.56,.5,.66),MUSCLE,Enum.PartType.Ball)
    a.tricep=vmPart(m,"Tricep",Vector3.new(.5,.42,.5),DEEP,Enum.PartType.Ball)
    a.deltoid=vmPart(m,"Deltoid",Vector3.new(.86,.78,.86),MUSCLE,Enum.PartType.Ball)
    return a
end
local function buildLeg()
    local m=Instance.new("Model");m.Name="YujiroLeg";m.Parent=env.viewmodel
    local pants=Color3.fromRGB(44,42,50)
    return {model=m,thigh=vmPart(m,"Thigh",Vector3.new(1.15,.62,.62),pants,Enum.PartType.Cylinder),knee=vmPart(m,"Knee",Vector3.one*.6,pants,Enum.PartType.Ball),
        shin=vmPart(m,"Shin",Vector3.new(1.1,.5,.5),pants,Enum.PartType.Cylinder),ankle=vmPart(m,"Ankle",Vector3.one*.44,SKIN,Enum.PartType.Ball),
        foot=vmPart(m,"Foot",Vector3.new(.46,.32,.95),Color3.fromRGB(30,26,24))}
end
local function handFrame(position,fingerDir,palmNormal)
    local y=fingerDir.Unit
    local z=-(palmNormal-y*palmNormal:Dot(y))
    if z.Magnitude<.01 then z=Vector3.zAxis end
    z=z.Unit
    return CFrame.fromMatrix(position,y:Cross(z),y,z)
end
local ALONG=CFrame.Angles(0,0,math.pi/2)
-- pose: {frame, curl (0..1 or per finger, thumb 5th), flex 0..1 (muscles swell), spread 0..1 (claw), shoulder}
local function poseArm(a,pose,visible)
    local cam=workspace.CurrentCamera.CFrame
    local world=cam*pose.frame
    local function put(p,cf) p.CFrame=cf;p.Transparency=visible and 0 or 1 end
    local flex=math.clamp(pose.flex or 0,0,1);local spread=math.clamp(pose.spread or 0,0,1)
    put(a.palm,world*CFrame.new(0,.13,0))
    put(a.heel,world*CFrame.new(0,.05,-.04))
    put(a.knuckles,world*CFrame.new(0,.27,.01))
    for i,f in a.fingers do
        local d=f.def
        local c=math.clamp(type(pose.curl)=="table" and pose.curl[i] or pose.curl or 0,0,1)
        local fan=(i-2.5)*.12*spread*a.thumbSide
        local base=world*CFrame.new(d.x*a.thumbSide*(1+.25*spread),.27,0)*CFrame.Angles(0,0,fan)
        -- A claw bends the last two joints more than the first.
        local pa=base*CFrame.Angles(-c*(1.5-.7*spread),0,0)
        put(f.a,pa*CFrame.new(0,d.a/2,0))
        local pb=pa*CFrame.new(0,d.a,0)*CFrame.Angles(-c*(1.6+.2*spread),0,0)
        put(f.b,pb*CFrame.new(0,d.b/2,0))
        local pc=pb*CFrame.new(0,d.b,0)*CFrame.Angles(-c*(1.1+.3*spread),0,0)
        put(f.c,pc*CFrame.new(0,d.c/2,0))
        put(f.nail,pc*CFrame.new(0,d.c-.012,.022))
    end
    local tc=math.clamp(type(pose.curl)=="table" and pose.curl[5] or pose.curl or 0,0,1)
    local thumb=world*CFrame.new(a.thumbSide*.12,.08,-.035)*CFrame.Angles(0,0,-a.thumbSide*(.85-.7*tc+.25*spread))*CFrame.Angles(-.3-tc*.75,0,0)
    put(a.thumb.a,thumb*CFrame.new(0,.048,0))
    local tip=thumb*CFrame.new(0,.095,0)*CFrame.Angles(-tc*.9,a.thumbSide*tc*.5,0)
    put(a.thumb.b,tip*CFrame.new(0,.04,0))
    put(a.wrist,world*CFrame.new(0,-.06,0)*ALONG)
    put(a.forearm,world*CFrame.new(0,-FOREARM/2-.05,0)*ALONG)
    for _,mu in a.muscles do
        mu.p.Size=mu.spec.size*(1+.22*flex)
        put(mu.p,world*CFrame.new(mu.spec.at.X*a.side,mu.spec.at.Y,mu.spec.at.Z*(1+.25*flex)))
    end
    for _,v in a.veins do
        local from=Vector3.new(v.from.X*a.side,v.from.Y,v.from.Z*(1+.3*flex));local to=Vector3.new(v.to.X*a.side,v.to.Y,v.to.Z*(1+.3*flex))
        local wf=(world*CFrame.new(from)).Position;local wt=(world*CFrame.new(to)).Position
        v.p.Size=Vector3.new((wt-wf).Magnitude,.024+.014*flex,.024+.014*flex)
        put(v.p,CFrame.lookAt((wf+wt)/2,wt)*CFrame.Angles(0,math.pi/2,0))
    end
    local elbow=(world*CFrame.new(0,-FOREARM-.05,0)).Position
    local shoulder=(cam*CFrame.new(pose.shoulder or Vector3.new(a.side*1.0,-1.08,.14))).Position
    put(a.elbow,CFrame.new(elbow))
    local span=shoulder-elbow
    if span.Magnitude>.05 then
        a.upper.Size=Vector3.new(span.Magnitude+.12,.44,.44)
        put(a.upper,CFrame.lookAt(elbow+span*.5,shoulder)*CFrame.Angles(0,math.pi/2,0))
        a.bicep.Size=Vector3.new(.56,.5,.66)*(1+.25*flex)
        put(a.bicep,CFrame.lookAt(elbow+span*.42+cam.UpVector*.12,shoulder)*CFrame.Angles(0,math.pi/2,0)*CFrame.new(0,.06,0))
        put(a.tricep,CFrame.lookAt(elbow+span*.4-cam.UpVector*.1,shoulder)*CFrame.Angles(0,math.pi/2,0))
        put(a.deltoid,CFrame.new(shoulder+cam.RightVector*a.side*.06+cam.UpVector*(.06+.06*flex)))
    else
        for _,p in {a.upper,a.bicep,a.tricep,a.deltoid} do put(p,CFrame.new(0,-5000,0)) end
    end
end
-- The axe-kick leg in camera space: hip -> knee -> ankle -> foot; `lift` is the thigh angle from straight down
-- (radians, toward the front), `bend` the knee.
local function poseLeg(lift,bend,visible)
    local cam=workspace.CurrentCamera.CFrame
    local hip=Vector3.new(.38,-2.25,.05)
    local thighDir=CFrame.Angles(lift,0,0)*Vector3.new(0,-1,0)
    local knee=hip+thighDir*1.15
    local shinDir=CFrame.Angles(lift-bend,0,0)*Vector3.new(0,-1,0)
    local ankle=knee+shinDir*1.1
    local function put(p,cf) p.CFrame=cam*cf;p.Transparency=visible and 0 or 1 end
    put(leg.thigh,CFrame.lookAt((hip+knee)/2,knee)*CFrame.Angles(0,math.pi/2,0))
    put(leg.knee,CFrame.new(knee))
    put(leg.shin,CFrame.lookAt((knee+ankle)/2,ankle)*CFrame.Angles(0,math.pi/2,0))
    put(leg.ankle,CFrame.new(ankle))
    -- The heel leads the chop: the foot points forward of the shin.
    local footDir=CFrame.Angles(lift-bend+1.4,0,0)*Vector3.new(0,-1,0)
    put(leg.foot,CFrame.lookAt(ankle+footDir*.35,ankle+footDir))
end
local function fist(position,fingers,palm,curl,flex,shoulder,spread)
    return {frame=handFrame(position,fingers,palm),curl=curl or 1,flex=flex or 0,shoulder=shoulder,spread=spread or 0}
end
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
    return {frame=p.frame:Lerp(q.frame,t),curl=curl,flex=(p.flex or 0)+((q.flex or 0)-(p.flex or 0))*t,spread=(p.spread or 0)+((q.spread or 0)-(p.spread or 0))*t,
        shoulder=(p.shoulder and q.shoulder) and sp:Lerp(sq,t) or q.shoulder or p.shoulder}
end
-- Poses (camera space; x right, y up, -z forward).
local function REST(side,breathe,s,run)
    s=s or 0;run=run or 0
    return fist(Vector3.new(side*.6,-.72+(breathe or 0)+.06*math.max(0,s)*run,-.98-.22*s*run),Vector3.new(-side*.12,.42,-1),Vector3.new(-side,-.25,0),.78,.25,Vector3.new(side*1.02,-1.08,.14))
end
local function LOW(side) return fist(Vector3.new(side*.62,-1.28,-.72),Vector3.new(-side*.05,-.2,-1),Vector3.new(-side,0,0),.55,.2,Vector3.new(side*1.0,-1.12,.12)) end
local function GUARD(side) return fist(Vector3.new(side*.36,-.36,-.9),Vector3.new(-side*.12,.9,-.4),Vector3.new(-side*.4,0,1),1,.6,Vector3.new(side*.95,-1.0,.05)) end
local function JAB(side) return fist(Vector3.new(side*.12,-.24,-1.55),Vector3.new(0,.05,-1),Vector3.new(0,-1,0),1,1,Vector3.new(side*.72,-.84,-.32)) end
local function LIFT(side) return fist(Vector3.new(side*.4,.3,-1.25),Vector3.new(side*.08,.3,-1),Vector3.new(0,1,0),.35,1,Vector3.new(side*.85,-.72,-.12),.3) end
local function PUSH(side) return fist(Vector3.new(side*.36,.0,-1.7),Vector3.new(0,.7,-.8),Vector3.new(0,.3,-1),.1,1,Vector3.new(side*.75,-.8,-.4)) end
-- Q
local WAIST_R=fist(Vector3.new(.62,-1.02,-.55),Vector3.new(-.1,.55,-.8),Vector3.new(-1,0,-.2),1,.6,Vector3.new(1.02,-1.12,.22))
local FRONT_L=fist(Vector3.new(-.24,-.44,-1.08),Vector3.new(.15,.95,-.35),Vector3.new(.15,-.1,-1),.15,.45,Vector3.new(-.92,-1.0,0))
local DEFLECT_L=fist(Vector3.new(-.9,-.22,-.88),Vector3.new(-.6,.8,-.25),Vector3.new(-.6,0,-.8),.2,.9,Vector3.new(-1.08,-.95,.1))
local COCK_R=fist(Vector3.new(.55,-1.08,-.7),Vector3.new(-.2,.8,-.5),Vector3.new(-.6,0,.6),1,.9,Vector3.new(1.06,-1.12,.26))
local UPPER_R=fist(Vector3.new(.1,.14,-1.28),Vector3.new(-.05,1,-.45),Vector3.new(-.3,0,1),1,1,Vector3.new(.7,-.74,-.26))
-- E
local BODY_L=fist(Vector3.new(-.08,-.62,-1.52),Vector3.new(.05,-.05,-1),Vector3.new(1,0,0),1,1,Vector3.new(-.74,-.96,-.32))
local HOOK_COCK_R=fist(Vector3.new(1.02,-.3,-.72),Vector3.new(-.6,.2,-.8),Vector3.new(-.3,-1,0),1,.9,Vector3.new(1.12,-.95,.26))
local HOOK_HIT_R=fist(Vector3.new(-.12,-.2,-1.32),Vector3.new(-1,.05,-.35),Vector3.new(0,-1,0),1,1,Vector3.new(.76,-.85,-.22))
local HOOK_FOLLOW_R=fist(Vector3.new(-.62,-.26,-1.0),Vector3.new(-1,0,.15),Vector3.new(0,-1,0),1,.8,Vector3.new(.62,-.9,-.1))
-- R
local CLAW_L=fist(Vector3.new(-.18,-.3,-1.6),Vector3.new(.02,.15,-1),Vector3.new(.2,-.6,-.75),.4,1,Vector3.new(-.74,-.86,-.36),1)
local GRIP_L=fist(Vector3.new(-.16,-.26,-1.38),Vector3.new(.08,.35,-1),Vector3.new(.3,-.6,-.7),.88,1,Vector3.new(-.78,-.9,-.24),.6)
local BODY_R=fist(Vector3.new(.08,-.64,-1.52),Vector3.new(-.05,-.05,-1),Vector3.new(-1,0,0),1,1,Vector3.new(.74,-.96,-.32))
local SLAP_FROM=fist(Vector3.new(1.05,-.08,-.88),Vector3.new(-.3,.9,-.3),Vector3.new(-1,0,-.2),.05,.8,Vector3.new(1.12,-.92,.22))
local SLAP_TO=fist(Vector3.new(-.32,-.06,-1.22),Vector3.new(-.2,.9,-.4),Vector3.new(-1,0,-.1),.05,1,Vector3.new(.68,-.86,-.26))
local WIND_R=fist(Vector3.new(1.08,-.26,-.34),Vector3.new(-.4,.4,-.9),Vector3.new(-.2,-1,0),1,1,Vector3.new(1.2,-.9,.52))
local FINAL_R=fist(Vector3.new(.05,-.48,-1.62),Vector3.new(0,-.28,-1),Vector3.new(0,-1,0),1,1,Vector3.new(.6,-.84,-.46))

---------------------------------------------------------------- screen
local overlay={}
local function frame(parent,name,size,position,color,z)
    local f=Instance.new("Frame");f.Name=name;f.Size=size;f.Position=position or UDim2.new();f.BackgroundColor3=color or Color3.new()
    f.BackgroundTransparency=1;f.BorderSizePixel=0;f.ZIndex=z or 4;f.Parent=parent
    return f
end
local function buildOverlay()
    local root=frame(env.gui,"YujiroOverlay",UDim2.fromScale(1,1));overlay.root=root
    overlay.edges={}
    for i,spec in {{UDim2.fromScale(1,.34),UDim2.fromScale(0,0),90},{UDim2.fromScale(1,.34),UDim2.fromScale(0,.66),-90},{UDim2.fromScale(.28,1),UDim2.fromScale(0,0),0},{UDim2.fromScale(.28,1),UDim2.fromScale(.72,0),180}} do
        local e=frame(root,"Edge",spec[1],spec[2],Color3.fromRGB(10,2,2))
        local g=Instance.new("UIGradient");g.Rotation=spec[3];g.Transparency=NumberSequence.new(0,1);g.Parent=e
        overlay.edges[i]=e
    end
    overlay.red=frame(root,"Pressure",UDim2.fromScale(1,1),nil,COLORS.Pressure,5)
    overlay.flash=frame(root,"Flash",UDim2.fromScale(1,1),nil,Color3.new(1,1,1),6)
    local label=Instance.new("TextLabel");label.AnchorPoint=Vector2.new(.5,0);label.Position=UDim2.fromScale(.5,.12);label.Size=UDim2.fromOffset(560,30)
    label.BackgroundTransparency=1;label.Font=Enum.Font.GothamBold;label.TextSize=16;label.TextColor3=Color3.fromRGB(255,222,214)
    label.TextStrokeTransparency=.4;label.Text="";label.ZIndex=9;label.Parent=root
    overlay.label=label
    local shout=Instance.new("TextLabel");shout.AnchorPoint=Vector2.new(.5,.5);shout.Position=UDim2.fromScale(.5,.3);shout.Size=UDim2.fromScale(1,.12)
    shout.BackgroundTransparency=1;shout.Font=Enum.Font.GothamBlack;shout.TextScaled=true;shout.TextColor3=Color3.fromRGB(255,236,230)
    shout.TextStrokeColor3=COLORS.HairDeep;shout.TextStrokeTransparency=1;shout.TextTransparency=1;shout.ZIndex=9;shout.Parent=root
    local c=Instance.new("UITextSizeConstraint");c.MaxTextSize=64;c.Parent=shout
    overlay.shout=shout
    overlay.grade=Instance.new("ColorCorrectionEffect");overlay.grade.Name="YujiroGrade";overlay.grade.Parent=Lighting
end
-- o: {vignette, red, flash, grey (desaturation 0..1), label, shout}
local function setOverlay(o)
    for _,e in overlay.edges do e.BackgroundTransparency=1-math.clamp(o.vignette or 0,0,1) end
    overlay.red.BackgroundTransparency=1-math.clamp(o.red or 0,0,.6)
    overlay.flash.BackgroundTransparency=1-math.clamp((o.flash or 0)*(comfort() and .5 or 1),0,.95)
    overlay.label.Text=o.label or "";overlay.label.TextTransparency=o.label and 0 or 1;overlay.label.TextStrokeTransparency=o.label and .4 or 1
    overlay.shout.Text=o.shout or "";overlay.shout.TextTransparency=o.shout and (o.shoutFade or 0) or 1;overlay.shout.TextStrokeTransparency=o.shout and (o.shoutFade or 0) or 1
    local grey=math.clamp(o.grey or 0,0,1)
    overlay.grade.Saturation=-.85*grey;overlay.grade.Contrast=.25*grey+(o.contrast or 0);overlay.grade.Brightness=-.05*grey
    overlay.grade.TintColor=Color3.new(1,1,1):Lerp(Color3.fromRGB(255,214,206),math.clamp(o.tint or 0,0,1))
end

---------------------------------------------------------------- events
local function ownerOf(data)
    local owner=Players:GetPlayerByUserId(data.owner)
    return owner and owner.Character,owner==player
end
function YujiroClient.onEvent(kind,data)
    local model,mine=ownerOf(data)
    local me=player.Character
    local myRoot=VFX.rootOf(me)
    if kind=="YujiroCounter" then
        VFX.counterStance(model,data)
        if mine then cast={kind="Counter",start=data.start};combo.untilTime=0 end
    elseif kind=="YujiroCounterRead" then
        VFX.counterRead(model,data)
        if mine and cast and cast.kind=="Counter" then
            cast.read=data.start;cast.attacker=data.attacker
            stop(data.start,Y.OgreCounter.Slowdown);kick(.05,.15)
        end
        if data.attacker==me and me then kick(.06,.2) end
    elseif kind=="YujiroCounterHit" then
        VFX.counterHit(data)
        if mine and cast and cast.kind=="Counter" then cast.hit=data.start;cast.landed=data.landed;if data.landed then kick(.12,.35) end end
        if data.target==me and me and data.landed then victim={kind="Counter",start=data.start,caster=model};kick(.16,.4) end
    elseif kind=="YujiroCounterFail" then
        if mine and cast and cast.kind=="Counter" then cast.failed=data.start end
    elseif kind=="YujiroCounterEnd" then
        VFX.counterEnd(model)
        if mine then
            if cast and cast.kind=="Counter" then cast.ended=clock() end
            if data.buffUntil then buffUntil=data.buffUntil;combo={untilTime=data.buffUntil,text="반격 성공 · 기본공격 +15%"} end
        end
    elseif kind=="YujiroCounterBlock" then
        VFX.counterBlock(model,data.from)
        if mine then kick(.03,.12) end
    elseif kind=="YujiroRush" then
        VFX.rushStart(model,data)
        if mine then cast={kind="Rush",start=data.start,direction=data.direction} end
    elseif kind=="YujiroRushDash" then
        VFX.rushDash(model,data)
        if mine and cast and cast.kind=="Rush" then cast.dash=data.start end
    elseif kind=="YujiroRushLink" then
        if mine and cast and cast.kind=="Rush" then cast.target=data.target end
        if data.target==me and me then victim={kind="Rush",start=data.start,caster=model} end
    elseif kind=="YujiroRushHit" then
        VFX.rushHit(data)
        if mine then kick(data.index==3 and .14 or .07,data.index==3 and .4 or .2);if data.index==3 then stop(data.start+Y.OgreRush.Blows[3].Time,.05) end end
        if data.target==me and me then kick(data.index==3 and .18 or .1,.3);if victim then victim.lastHit=clock();victim.hitIndex=data.index end end
    elseif kind=="YujiroRushWhiff" then
        if mine and cast and cast.kind=="Rush" then cast.whiff=data.start end
    elseif kind=="YujiroRushStop" then
        if mine and cast and cast.kind=="Rush" then cast.stopped=data.start end
        if victim and victim.kind=="Rush" and victim.caster==model then victim=nil end
    elseif kind=="YujiroRushEnd" then
        VFX.rushEnd(model)
        if mine and cast and cast.kind=="Rush" then cast.ended=clock() end
        if victim and victim.kind=="Rush" and victim.caster==model then victim=nil end
    elseif kind=="YujiroJudgment" then
        VFX.judgment(model,data)
        if mine then cast={kind="Judgment",start=data.start,direction=data.direction};combo.untilTime=0 end
    elseif kind=="YujiroJudgmentFail" then
        VFX.closeDemon(model)
        if mine and cast and cast.kind=="Judgment" then cast.failed=clock();env.announce("오거의 심판","25스터드 · 시야 중앙 15° 안에 잡을 대상이 없다 · 재사용 30초") end
    elseif kind=="YujiroJudgmentCapture" then
        VFX.judgmentCapture(model,data)
        if mine and cast and cast.kind=="Judgment" then cast.target=data.target;cast.direction=data.direction end
        if data.target==me and me then victim={kind="Judgment",start=data.start,caster=model} end
    elseif kind=="YujiroJudgmentHit" then
        VFX.judgmentHit(data)
        if mine and cast and cast.kind=="Judgment" then
            if data.final then stop(data.start+Y.OgreJudgment.Final,Y.OgreJudgment.Hitstop);kick(.3,.7);cast.finalAt=clock() else kick(.05,.15) end
        end
        if data.target==me and me then kick(data.final and .35 or .1,data.final and .7 or .2);if victim then victim.lastHit=clock() end end
        if data.final and myRoot and not mine and data.target~=me and (myRoot.Position-data.position).Magnitude<45 then kick(.08,.5) end
    elseif kind=="YujiroJudgmentEnd" then
        VFX.judgmentEnd(model,data.reason~="done")
        if mine and cast and cast.kind=="Judgment" then cast.ended=clock() end
        if victim and victim.kind=="Judgment" and victim.caster==model then victim.ended=clock() end
    end
end

---------------------------------------------------------------- render
local function lookToward(camera,point,k,maxPitch)
    local d=camera.CFrame:VectorToObjectSpace((point-camera.CFrame.Position).Unit)
    local yaw=math.atan2(-d.X,-d.Z);local pitch=math.clamp(math.atan2(d.Y,math.sqrt(d.X*d.X+d.Z*d.Z)),-(maxPitch or 1.2),maxPitch or 1.2)
    return CFrame.Angles(0,yaw*k,0)*CFrame.Angles(pitch*k,0,0)
end
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
-- A shot around the caster that never goes through walls: swings to the clearest angle when blocked.
local function shot(camera,root,offset,look)
    local list={VFX.folder,camera}
    for _,p in Players:GetPlayers() do if p.Character then table.insert(list,p.Character) end end
    cinemaParams.FilterDescendantsInstances=list
    local from=root.Position+Vector3.yAxis*1.5
    local best,bestLen=offset.Unit,-1
    for _,ang in {0,.45,-.45,.9,-.9} do
        local want=CFrame.Angles(0,ang,0)*offset
        local hit=workspace:Raycast(from,want,cinemaParams)
        local len=hit and math.max(1.5,hit.Distance-1) or want.Magnitude
        if len>bestLen+.01 then best=want.Unit;bestLen=len end
        if len>=want.Magnitude*.85 then break end
    end
    return CFrame.lookAt(from+best*bestLen,look)
end
local function headOf(model) local h=model and model:FindFirstChild("Head");return h and h.Position or (VFX.rootOf(model) and VFX.rootOf(model).Position+Vector3.yAxis*1.5) end
-- info: {isYujiro, melee, sliding, moving, alive}. Returns {fov, fovAdd, combo, ready, victim} for Gojo.client.
function YujiroClient.render(dt,info)
    local n=clock()
    local camera=workspace.CurrentCamera
    if not arms.right then return end
    YujiroClient.updateVictims(n)
    local m=player.Character
    local o={vignette=0,red=0,flash=0,grey=0,tint=0,contrast=0,label=nil}
    local out={fov=72,fovAdd=0}
    ---------------------------------------------------------------- things done to us (any kit)
    if victim then
        local cfg=Y.OgreJudgment
        local a=n-victim.start
        local casterHead=headOf(victim.caster)
        if victim.kind=="Judgment" then
            if a>cfg.End+.3 or (victim.ended and n-victim.ended>.25) or not info.alive then victim=nil
            else
                -- Up close on Yujiro, the floor dropping away during the lift, then flat on our back looking up.
                local held=smoothstep(window(a,cfg.Capture,cfg.Capture+.2))
                local lie=smoothstep(window(a,cfg.Final,cfg.Final+.12))*(1-smoothstep(window(a,cfg.Final+.1+cfg.Down,cfg.Final+.3+cfg.Down)))
                local lift=smoothstep(window(a,cfg.LiftFrom,cfg.LiftTo))*(1-smoothstep(window(a,cfg.Release,cfg.Final)))
                if casterHead and held>0 then env.commonLook(lookToward(camera,casterHead,.85*held*(1-lie),1)) end
                env.commonLook(CFrame.Angles(-.35*lift,0,.1*bump(a,cfg.Release,cfg.Final))*CFrame.Angles(.9*lie,0,.5*lie))
                if lie>0 then env.commonLook(CFrame.new(0,-1.6*lie,0)) end
                o.vignette=.55*held;o.red=.12*held
                o.flash=.8*(1-smoothstep((n-(victim.lastHit or -10))/.25))*(a>=cfg.Final and 1 or .35)
                o.label=a<cfg.Final+.1 and "오거의 심판 · 붙잡혔다" or "쓰러졌다"
                out.fov=72-6*held+10*bump(a,cfg.Final-.05,cfg.Final+.4);out.victim=true
            end
        elseif victim.kind=="Rush" then
            local rcfg=Y.OgreRush
            if a>rcfg.End+.2 or not info.alive then victim=nil
            else
                local k=smoothstep(window(a,rcfg.DashEnd,rcfg.DashEnd+.1))*(1-smoothstep(window(a,rcfg.AxeEnd,rcfg.End)))
                if casterHead then env.commonLook(lookToward(camera,casterHead,.7*k,1)) end
                local fold=bump(a,rcfg.Blows[1].Time,rcfg.Blows[1].Time+.25);local turn=bump(a,rcfg.Blows[2].Time,rcfg.Blows[2].Time+.3)
                local down=smoothstep(window(a,rcfg.Blows[3].Time,rcfg.Blows[3].Time+.08))*(1-smoothstep(window(a,rcfg.AxeEnd,rcfg.End)))
                env.commonLook(CFrame.new(0,-1.2*down,0)*CFrame.Angles(-.35*fold-.5*down,.6*turn,.15*turn))
                o.vignette=.45*k;o.flash=.5*(1-smoothstep((n-(victim.lastHit or -10))/.2))
                out.fov=72;out.victim=true
            end
        elseif victim.kind=="Counter" then
            if a>.8 then victim=nil
            else
                env.commonLook(CFrame.Angles(.45*bump(a,0,.6),0,.08*bump(a,0,.5)))
                o.flash=.6*(1-smoothstep(a/.2));o.vignette=.3*bump(a,0,.8)
            end
        end
    end
    if not info.isYujiro then
        poseArm(arms.right,REST(1),false);poseArm(arms.left,REST(-1),false);poseLeg(0,0,false)
        cast=nil;revealBody(nil,false)
        if n<shake.untilTime and out.victim then
            local k=(shake.untilTime-n)/math.max(.01,shake.duration);local p=shake.power*k
            env.commonLook(CFrame.new((math.random()-.5)*p*4,(math.random()-.5)*p*4,0)*CFrame.Angles((math.random()-.5)*p,(math.random()-.5)*p,0))
        end
        setOverlay(o)
        return (out.victim or victim) and out or nil
    end
    ---------------------------------------------------------------- own techniques
    local visible=info.alive
    local legLift,legBend,legShown=0,0,false
    local breathe=math.sin(n*1.5)*.012
    local swing=info.moving and math.sin(n*8.5) or 0
    local run=info.moving and 1 or 0
    local R,L=REST(1,breathe,swing,run),REST(-1,breathe,-swing,run)
    if info.moving and not cast then env.commonLook(CFrame.new(0,-.1*run,0)*CFrame.Angles(-.03*run,0,swing*.006)) end
    -- Shared M1: heavy straight punches, alternating fists, shoulder driving through.
    if info.melee and not cast then
        local me=info.melee;local a=n-me.start
        local wind=smoothstep(a/me.windup);local strike=easeOut((a-me.windup)/me.swing,3)
        local back=smoothstep((a-me.windup-me.swing)/math.max(.05,me.duration-me.windup-me.swing))
        local side=me.combo%2==0 and -1 or 1
        local rest=side>0 and R or L
        local cock=fist(Vector3.new(side*.72,-.6,-.6),Vector3.new(-side*.15,.2,-1),Vector3.new(-side*.3,-1,0),1,.8,Vector3.new(side*1.08,-1.0,.3))
        local p=blend(blend(blend(rest,cock,wind),JAB(side),strike),rest,back)
        if side>0 then R=p else L=p end
        out.fovAdd+=4*strike*(1-back)
    end
    if info.sliding then R.frame=R.frame*CFrame.new(0,-.1,.1);L.frame=L.frame*CFrame.new(0,-.1,.1) end
    if not info.alive then cast=nil end
    local cinematic,shotCF=0,nil
    if cast then
        local a=animTime(n,cast.start)
        if cast.kind=="Counter" then
            ---------------------------------------------------------------- Q
            local cfg=Y.OgreCounter
            local entry=smoothstep(window(a,0,cfg.Entry))
            local stance=blend(R,WAIST_R,entry);local front=blend(L,FRONT_L,entry)
            -- Entry: stop, stand a little upright, head tilted; the camera dips and the edges darken.
            local look=CFrame.new(0,-.12*bump(a,0,cfg.Entry*1.6),0)*CFrame.Angles(.02*entry-.05*bump(a,0,cfg.Entry*1.6),0,.06*entry)
            o.vignette=.35*entry;o.contrast=.08*entry
            if not cast.read then
                local idle=math.sin(n*2.2)*.012
                stance.frame=CFrame.new(0,idle,0)*stance.frame;front.frame=CFrame.new(0,idle*.6,0)*front.frame
                if a>=cfg.Entry and a<cfg.WindowEnd then o.label="지상 최강의 생물 · 정면 피해 −70% · 직접 공격을 읽는다" end
                if cast.failed then
                    -- No read: the hands drop and the body sags for the slowed recovery.
                    local f=smoothstep(window(n-cast.failed,0,cfg.FailRecovery))
                    stance=blend(stance,LOW(1),f);front=blend(front,LOW(-1),f)
                    look=look*CFrame.new(0,-.15*f,0)*CFrame.Angles(-.06*f,0,-.06*entry*f)
                    o.vignette=.2*(1-f)
                end
                R,L=stance,front
                if (cast.ended and n-cast.ended>.05) or a>cfg.FailEnd+.1 then cast=nil end
            else
                local k=animTime(n,cast.read)
                -- 0-.15 the head snaps to the attacker and the left arm sweeps it aside; .15-.3 the right uppercut;
                -- hold to .5, lower by .9.
                local deflect=easeOut(window(k,0,cfg.Snap),3)*(1-smoothstep(window(k,cfg.Hit,cfg.PunchEnd+.2)))
                local cock=smoothstep(window(k,0,cfg.Snap))
                local up=easeOut(window(k,cfg.Snap,cfg.Hit),3.2)
                local lower=smoothstep(window(k,cfg.PunchEnd,cfg.End))
                R=blend(blend(blend(stance,COCK_R,cock),UPPER_R,up),REST(1,breathe),lower)
                L=blend(blend(front,DEFLECT_L,deflect),REST(-1,breathe),lower)
                local attackerHead=headOf(cast.attacker)
                local snap=easeOut(window(k,0,.08),3)*(1-lower)
                look=CFrame.Angles(0,0,.08*bump(k,0,cfg.Snap))
                if attackerHead then look=look*lookToward(camera,attackerHead,.75*snap,.6) end
                -- The punch pushes the view forward and up; then a shake.
                local push=bump(k,cfg.Hit-.05,cfg.PunchEnd+.1)
                look=look*CFrame.new(0,.1*push,-.45*push)*CFrame.Angles(.05*push,0,0)
                out.fov=72-4*deflect+12*bump(k,cfg.Hit-.04,cfg.PunchEnd)
                if cast.landed then
                    o.flash=math.max(o.flash,.6*(1-smoothstep(window(k,cfg.Hit,cfg.Hit+.2))))
                    o.shout=k<cfg.End and "!" or nil;o.shoutFade=smoothstep(window(k,cfg.PunchEnd,cfg.End))
                end
                o.vignette=.3*(1-lower)
                if k>cfg.End+.15 or (cast.ended and n-cast.ended>.2) then cast=nil end
            end
            env.commonLook(look)
        elseif cast.kind=="Rush" then
            ---------------------------------------------------------------- E
            local cfg=Y.OgreRush
            local crouch=easeOut(window(a,0,cfg.Crouch),2)*(1-smoothstep(window(a,cfg.Crouch,cfg.Crouch+.12)))
            local dash=window(a,cfg.Crouch,cfg.DashEnd)
            local guard=smoothstep(window(a,0,cfg.Crouch))
            local recover=smoothstep(window(a,cfg.AxeEnd,cfg.End))
            local gR,gL=blend(R,GUARD(1),guard),blend(L,GUARD(-1),guard)
            local look=CFrame.new(0,-.7*crouch,0)*CFrame.Angles(-.06*crouch,0,0)
            out.fov=72-6*crouch+18*(dash>0 and dash<1 and 1 or 0)*bump(a,cfg.Crouch,cfg.DashEnd+.1)
            o.vignette=.4*crouch+.25*(dash>0 and dash<1 and 1 or 0)
            if cast.whiff then
                local w=n-cast.whiff
                gR=blend(gR,LOW(1),smoothstep(w/.2));gL=blend(gL,LOW(-1),smoothstep(w/.2))
                look=look*CFrame.Angles(-.08*bump(w,0,.35),0,.05*bump(w,0,.35))
                R,L=gR,gL
                if w>.4 or (cast.ended and n-cast.ended>.1) then cast=nil end
            else
                -- .5-.7 left body blow (hit .62), .7-.95 right hook to the face (hit .84), .95-1.35 axe kick (hit 1.21).
                local b1=cfg.Blows[1].Time;local b2=cfg.Blows[2].Time;local b3=cfg.Blows[3].Time
                local body=easeOut(window(a,cfg.DashEnd+.02,b1),3)*(1-smoothstep(window(a,b1+.02,cfg.BodyEnd+.08)))
                local hookCock=smoothstep(window(a,cfg.BodyEnd-.05,b2-.08));local hookHit=easeOut(window(a,b2-.08,b2),3)
                local hookFollow=smoothstep(window(a,b2,cfg.HookEnd));local hookBack=smoothstep(window(a,cfg.HookEnd,cfg.HookEnd+.2))
                L=blend(gL,BODY_L,body)
                R=blend(blend(blend(blend(gR,HOOK_COCK_R,hookCock),HOOK_HIT_R,hookHit),HOOK_FOLLOW_R,hookFollow),gR,hookBack)
                -- The leg: hip -> knee -> ankle, raised high and straight, then chopped down through the target.
                local raise=easeOut(window(a,cfg.HookEnd,1.15),2.2);local chop=easeOut(window(a,1.15,b3),3.5)
                local settle=smoothstep(window(a,cfg.AxeEnd-.05,cfg.AxeEnd+.25))
                legLift=(2.65*raise-1.75*chop)*(1-settle);legBend=.35*(1-raise)+.15*raise-.1*chop
                legShown=a>=cfg.HookEnd and a<cfg.AxeEnd+.25
                local twist=-.12*hookCock*(1-hookHit)+.16*hookHit*(1-hookBack)
                look=look*CFrame.Angles(-.06*body+.12*raise*(1-chop)-.42*chop*(1-recover*.2),twist,.04*hookHit*(1-hookBack))
                look=look*CFrame.Angles(-.3*recover*(1-smoothstep(window(a,cfg.End-.15,cfg.End))),0,0)
                if cast.target and a>=cfg.DashEnd then
                    local th=headOf(cast.target)
                    if th then look=lookToward(camera,th,.35*(1-raise),.5)*look end
                end
                out.fov=out.fov+6*body+8*hookHit*(1-hookBack)-6*raise*(1-chop)+10*bump(a,b3-.02,b3+.3)
                if a>=b3 then o.flash=math.max(o.flash,.35*(1-smoothstep(window(a,b3,b3+.2)))) end
                if cast.stopped then
                    local s=smoothstep((n-cast.stopped)/.25)
                    R=blend(R,REST(1,breathe),s);L=blend(L,REST(-1,breathe),s);legShown=legShown and s<.5
                    if n-cast.stopped>.4 then cast=nil end
                end
                if cast and (a>cfg.End+.1 or (cast.ended and n-cast.ended>.15)) then cast=nil end
            end
            env.commonLook(look)
        elseif cast.kind=="Judgment" then
            ---------------------------------------------------------------- R
            local cfg=Y.OgreJudgment
            local root=VFX.rootOf(m)
            local dir=cast.direction or Vector3.new(0,0,-1)
            local side=dir:Cross(Vector3.yAxis).Unit
            -- 0-.5 serious: frozen, head down, the world loses its colour; heartbeat and a low laugh (VFX).
            local serious=smoothstep(window(a,0,cfg.Serious))
            local grey=serious*(1-smoothstep(window(a,cfg.End-.6,cfg.End)))
            o.grey=grey*(cast.failed and (1-smoothstep((n-cast.failed)/.4)) or 1)
            o.tint=.6*smoothstep(window(a,cfg.Serious,cfg.Open))*(1-smoothstep(window(a,cfg.End-.6,cfg.End)))
            o.red=.12*bump(a,cfg.Serious,cfg.Open+.3)+.06*o.tint
            o.vignette=.5*serious
            R=blend(R,LOW(1),serious);L=blend(L,LOW(-1),serious)
            local look=CFrame.Angles(-.22*serious*(1-smoothstep(window(a,cfg.Serious,cfg.Serious+.2))),0,0)
            out.fov=72-6*serious
            -- .5-1 the Demon Back opens: rear third-person shot of the back.
            if root then
                local shots={{cfg.Serious,cfg.Open,-dir*9+Vector3.yAxis*3.5+side*1.5,root.Position+Vector3.yAxis*1.4}}
                if cast.target and not cast.failed then
                    table.insert(shots,{cfg.WindFrom,cfg.WindTo,side*9-dir*4+Vector3.yAxis*2.5,root.Position+Vector3.yAxis*1.2+dir*1.5})
                end
                for _,s in shots do
                    local k=smoothstep(window(a,s[1],s[1]+.12))*(1-smoothstep(window(a,s[2]-.1,s[2])))
                    if k>cinematic then cinematic=k;shotCF=shot(camera,root,s[3],s[4]) end
                end
            end
            if cast.failed then
                -- Nobody in reach: the arms drop with a short exhale, back to normal by 1.55.
                local f=n-cast.failed
                R=blend(R,REST(1,breathe),smoothstep(f/.5));L=blend(L,REST(-1,breathe),smoothstep(f/.5))
                look=look*CFrame.Angles(-.1*bump(f,0,.5),0,0)
                if f>.6 or (cast.ended and n-cast.ended>.1) then cast=nil end
            elseif a>=cfg.Capture then
                local th=cast.target and headOf(cast.target)
                -- 1-1.5 dash in, the left hand reaches as a claw and closes on the collar.
                local reach=easeOut(window(a,cfg.Capture,cfg.DashEnd-.08),2)
                local grip=smoothstep(window(a,cfg.DashEnd-.1,cfg.DashEnd))
                local liftK=smoothstep(window(a,cfg.LiftFrom,cfg.LiftTo))
                local release=easeOut(window(a,cfg.Release-.06,cfg.Release+.06),2)
                local relax=smoothstep(window(a,cfg.Release+.1,cfg.WindTo))
                local lpose=blend(blend(L,CLAW_L,reach),GRIP_L,grip)
                -- Blows: body 1.66, slap 2.05, then four alternating rush punches 2.40 / 2.56 / 2.72 / 2.88.
                local h=cfg.Hits
                local rpose=R
                local body=easeOut(window(a,h[1].Time-.14,h[1].Time),3)*(1-smoothstep(window(a,h[1].Time+.05,cfg.Hits[2].Time-.2)))
                rpose=blend(rpose,BODY_R,body)
                local slapCock=smoothstep(window(a,h[2].Time-.3,h[2].Time-.08));local slap=easeOut(window(a,h[2].Time-.08,h[2].Time),3)
                local slapBack=smoothstep(window(a,h[2].Time+.06,h[3].Time-.12))
                rpose=blend(blend(blend(rpose,SLAP_FROM,slapCock),SLAP_TO,slap),R,slapBack)
                for i=3,6 do
                    local k=bump(a,h[i].Time-.08,h[i].Time+.08)
                    if i%2==1 then rpose=blend(rpose,JAB(1),k) else lpose=blend(lpose,JAB(-1),k) end
                end
                -- 3.0-3.5 both hands lift the body; 3.62 thrown forward; then the right fist winds far back.
                rpose=blend(rpose,LIFT(1),liftK);lpose=blend(lpose,LIFT(-1),liftK)
                rpose=blend(rpose,PUSH(1),release*(1-relax));lpose=blend(lpose,PUSH(-1),release*(1-relax))
                local wind=smoothstep(window(a,cfg.Release+.1,cfg.WindTo))
                rpose=blend(rpose,WIND_R,wind);lpose=blend(lpose,LOW(-1),relax)
                -- 4.12 the final punch, hitstop, then a slow recovery.
                local final=easeOut(window(a,cfg.WindTo,cfg.Final),3.5)
                local recover=smoothstep(window(a,cfg.Final+.4,cfg.End))
                rpose=blend(blend(rpose,FINAL_R,final),REST(1,breathe),recover);lpose=blend(lpose,REST(-1,breathe),recover)
                R,L=rpose,lpose
                look=CFrame.identity
                if th then
                    local track=(1-smoothstep(window(a,cfg.LiftFrom-.1,cfg.LiftFrom+.2)))*smoothstep(window(a,cfg.Capture,cfg.Capture+.15))
                    look=lookToward(camera,th,.6*track,.6)
                end
                look=look*CFrame.Angles(.25*liftK*(1-release)-.32*final*(1-recover),0,0)
                look=look*CFrame.new(0,0,-.5*bump(a,cfg.Final-.05,cfg.Final+.3))
                out.fov=72+14*bump(a,cfg.Capture,cfg.DashEnd)+4*body+6*slap*(1-slapBack)-4*wind+18*bump(a,cfg.Final-.04,cfg.Final+.5)
                if a>=cfg.Final then
                    o.flash=math.max(o.flash,.9*(1-smoothstep(window(a,cfg.Final+.04,cfg.Final+.35))))
                    o.contrast=.3*(1-smoothstep(window(a,cfg.Final,cfg.Final+.6)))
                    o.shout=a<cfg.Final+1 and "오거의 심판" or nil;o.shoutFade=smoothstep(window(a,cfg.Final+.6,cfg.Final+1))
                end
                if a>cfg.End+.1 or (cast.ended and n-cast.ended>.25) then cast=nil end
            elseif cast.ended and n-cast.ended>.25 then cast=nil end
            env.commonLook(look)
        end
    end
    if cinematic>.001 and shotCF then
        local blended=camera.CFrame:Lerp(shotCF,smoothstep(cinematic))
        env.commonLook(camera.CFrame:Inverse()*blended)
        revealBody(m,cinematic>.25)
        if cinematic>.25 then visible=false;legShown=false end
        out.fov=lerp(out.fov,62,cinematic)
    elseif next(revealed) then revealBody(nil,false) end
    if n<shake.untilTime then
        local k=(shake.untilTime-n)/math.max(.01,shake.duration);local p=shake.power*k
        env.commonLook(CFrame.new((math.random()-.5)*p*4,(math.random()-.5)*p*4,0)*CFrame.Angles((math.random()-.5)*p,(math.random()-.5)*p,(math.random()-.5)*p*.5))
    end
    local squeeze=math.min(1,camera.ViewportSize.X/math.max(1,camera.ViewportSize.Y))
    local function narrow(p)
        local f=p.frame
        p.frame=CFrame.new(f.Position*Vector3.new(math.max(.72,squeeze),1,1))*f.Rotation
        if p.shoulder then p.shoulder=p.shoulder*Vector3.new(math.max(.8,squeeze),1,1) end
        return p
    end
    poseArm(arms.right,narrow(R),visible and not out.victim)
    poseArm(arms.left,narrow(L),visible and not out.victim)
    poseLeg(legLift,legBend,legShown and visible and not out.victim)
    setOverlay(o)
    -- Never draw our own hair into the first-person view (the cinematic shows the whole body).
    if m and cinematic<=.25 then
        for _,v in m:GetChildren() do if v:IsA("BasePart") and string.sub(v.Name,1,6)=="Yujiro" then v.LocalTransparencyModifier=1 end end
    end
    if n<combo.untilTime then out.combo=string.format("%s   %.1f",combo.text,combo.untilTime-n);out.ready=nil end
    return out
end
-- Victim side: a held body is moved by the server; locally the humanoid stops fighting it and cannot jump.
local heldApplied=false
function YujiroClient.updateVictims(n)
    local m=player.Character;local h=m and m:FindFirstChildOfClass("Humanoid")
    if not h then return end
    local held=(m:GetAttribute("YujiroHeldUntil") or 0)>n
    if held~=heldApplied then
        heldApplied=held
        h.PlatformStand=held
        if not held then h:ChangeState(Enum.HumanoidStateType.GettingUp) end
    end
    if held or (m:GetAttribute("YujiroLockUntil") or 0)>n or (m:GetAttribute("YujiroNoJumpUntil") or 0)>n then
        h:SetStateEnabled(Enum.HumanoidStateType.Jumping,false)
    end
end
function YujiroClient.busy() return cast~=nil end
function YujiroClient.buffed() return clock()<buffUntil end
function YujiroClient.reset()
    cast=nil;victim=nil;combo={untilTime=0,text=""};shake.untilTime=0;freeze.length=0;buffUntil=0
    revealBody(nil,false)
    -- A respawned character must never stay platform-stood from an old hold.
    if heldApplied then
        heldApplied=false
        local m=player.Character;local h=m and m:FindFirstChildOfClass("Humanoid")
        if h then h.PlatformStand=false end
    end
    if overlay.root then setOverlay({}) end
    if leg then poseLeg(0,0,false) end
end
function YujiroClient.init(environment)
    env=environment
    arms.right=buildArm(1);arms.left=buildArm(-1);leg=buildLeg()
    buildOverlay()
    UIS.WindowFocusReleased:Connect(function() shake.untilTime=0 end)
end
return YujiroClient
