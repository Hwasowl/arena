-- Uchiha Itachi on the client: slim first-person hands with jointed fingers and purple nails inside wide Akatsuki
-- sleeves (red clouds, red lining), the seal / face / sleeve-grip / point poses, the Mangekyo overlay, camera work for
-- each technique (including the Susanoo cinematic), the crow-clone dissolve, and the victim's side: the Tsukuyomi
-- world (only on the victim's own screen) and the view from inside the Totsuka seal.
-- Gojo.client.luau owns input and the shared HUD; it forwards Itachi* events here and asks for the arm pose every
-- frame. All judgement stays on the server.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local Lighting=game:GetService("Lighting")
local I=require(RS:WaitForChild("ItachiConfig"))
local VFX=require(RS:WaitForChild("ItachiVFX"))
local COLORS=I.Colors
local player=Players.LocalPlayer
local smoothstep,window,bump=VFX.smoothstep,VFX.window,VFX.bump
local function clock() return workspace:GetServerTimeNow() end
local function lerp(a,b,t) return a+(b-a)*t end

local ItachiClient={}
local env
local cast=nil            -- own technique in progress: {kind, start, data}
local crow=nil            -- own crow clone in progress
local victim=nil          -- something being done to us: {kind="Tsukuyomi"|"Seal", start, owner}
local combo={untilTime=0,text="",key=nil}
local shake={untilTime=0,power=0,duration=.1}
local revealed={}

---------------------------------------------------------------- arms
-- Hand frame: origin at the wrist, +Y toward the knuckles, palm facing -Z. The sleeve hangs open around the wrist.
local arms={}
local SKIN,CLOAK,LINING,NAIL=COLORS.Skin,COLORS.Cloak,Color3.fromRGB(150,10,16),COLORS.Nail
local function vmPart(model,name,size,color,shape,material)
    local p=Instance.new("Part");p.Name=name;p.Size=size;p.Color=color;p.Shape=shape or Enum.PartType.Block
    p.Material=material or Enum.Material.SmoothPlastic;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
    p.CastShadow=false;p.Transparency=1;p.Parent=model
    return p
end
local FINGERS={{x=.052,a=.072,b=.05,c=.04},{x=.018,a=.078,b=.054,c=.042},{x=-.017,a=.074,b=.05,c=.04},{x=-.05,a=.062,b=.042,c=.035}}
local function buildArm(side)
    local m=Instance.new("Model");m.Name=side>0 and "ItachiRightArm" or "ItachiLeftArm";m.Parent=env.viewmodel
    local a={side=side,thumbSide=side>0 and -1 or 1,model=m,fingers={},order={},k=1}
    a.palm=vmPart(m,"Palm",Vector3.new(.15,.17,.06),SKIN)
    for i,f in FINGERS do
        local fp={def=f,a=vmPart(m,"Finger",Vector3.new(.034,f.a,.034),SKIN),b=vmPart(m,"Finger",Vector3.new(.031,f.b,.031),SKIN),
            c=vmPart(m,"Finger",Vector3.new(.028,f.c,.028),SKIN),nail=vmPart(m,"Nail",Vector3.new(.026,.016,.012),NAIL)}
        a.fingers[i]=fp
    end
    a.thumb={a=vmPart(m,"Thumb",Vector3.new(.038,.06,.038),SKIN),b=vmPart(m,"Thumb",Vector3.new(.034,.05,.034),SKIN),nail=vmPart(m,"Nail",Vector3.new(.03,.016,.012),NAIL)}
    a.wrist=vmPart(m,"Wrist",Vector3.new(.3,.11,.11),SKIN,Enum.PartType.Cylinder)
    a.sleeve=vmPart(m,"Sleeve",Vector3.new(.95,.4,.4),CLOAK,Enum.PartType.Cylinder)
    a.lining=vmPart(m,"SleeveLining",Vector3.new(.04,.37,.37),LINING,Enum.PartType.Cylinder)
    a.clouds={}
    for i=1,3 do
        table.insert(a.clouds,{rim=vmPart(m,"CloudRim",Vector3.new(.012,.15,.15),COLORS.CloudRim,Enum.PartType.Cylinder),
            red=vmPart(m,"Cloud",Vector3.new(.014,.12,.12),COLORS.Cloud,Enum.PartType.Cylinder),at=({-.25,-.48,-.66})[i],h=({.02,.07,-.05})[i]})
    end
    a.upper=vmPart(m,"UpperSleeve",Vector3.new(1,.42,.42),CLOAK,Enum.PartType.Cylinder)
    -- Dissolve order for the crow clone: fingertips first, the sleeve last.
    for i=4,1,-1 do table.insert(a.order,a.fingers[i].nail);table.insert(a.order,a.fingers[i].c) end
    table.insert(a.order,a.thumb.nail);table.insert(a.order,a.thumb.b)
    for i=4,1,-1 do table.insert(a.order,a.fingers[i].b) end
    table.insert(a.order,a.thumb.a);for i=4,1,-1 do table.insert(a.order,a.fingers[i].a) end
    for _,p in {a.palm,a.wrist,a.lining} do table.insert(a.order,p) end
    for _,c in a.clouds do table.insert(a.order,c.red);table.insert(a.order,c.rim) end
    table.insert(a.order,a.sleeve);table.insert(a.order,a.upper)
    return a
end
local function handFrame(position,fingerDir,palmNormal)
    local y=fingerDir.Unit
    local z=-(palmNormal-y*palmNormal:Dot(y))
    if z.Magnitude<.01 then z=Vector3.zAxis end
    z=z.Unit
    return CFrame.fromMatrix(position,y:Cross(z),y,z)
end
local ALONG=CFrame.Angles(0,0,math.pi/2)
-- pose: {frame, curl (number or per finger, thumb 5th), shoulder}
local function poseArm(a,pose,visible)
    local cam=workspace.CurrentCamera.CFrame
    local world=cam*pose.frame
    local shown={}
    local count=#a.order;local keep=math.floor(a.k*count+.5)
    for i,p in a.order do shown[p]=i>count-keep end
    local function put(p,cf) p.CFrame=cf;p.Transparency=(visible and shown[p]) and 0 or 1 end
    put(a.palm,world*CFrame.new(0,.085,0))
    for i,f in a.fingers do
        local d=f.def
        local c=math.clamp(type(pose.curl)=="table" and pose.curl[i] or pose.curl or 0,0,1)
        local base=world*CFrame.new(d.x*a.thumbSide,.17,0)
        local pa=base*CFrame.Angles(-c*1.45,0,0)
        put(f.a,pa*CFrame.new(0,d.a/2,0))
        local pb=pa*CFrame.new(0,d.a,0)*CFrame.Angles(-c*1.6,0,0)
        put(f.b,pb*CFrame.new(0,d.b/2,0))
        local pc=pb*CFrame.new(0,d.b,0)*CFrame.Angles(-c*1.1,0,0)
        put(f.c,pc*CFrame.new(0,d.c/2,0))
        put(f.nail,pc*CFrame.new(0,d.c-.008,.012))
    end
    local tc=math.clamp(type(pose.curl)=="table" and pose.curl[5] or pose.curl or 0,0,1)
    local thumb=world*CFrame.new(a.thumbSide*.075,.05,-.02)*CFrame.Angles(0,0,-a.thumbSide*(.8-.6*tc))*CFrame.Angles(-.3-tc*.7,0,0)
    put(a.thumb.a,thumb*CFrame.new(0,.03,0))
    local tip=thumb*CFrame.new(0,.06,0)*CFrame.Angles(-tc*.9,0,0)
    put(a.thumb.b,tip*CFrame.new(0,.025,0))
    put(a.thumb.nail,tip*CFrame.new(0,.042,.014))
    put(a.wrist,world*CFrame.new(0,-.1,0)*ALONG)
    -- The sleeve opens around the wrist (it never hides the hand) and runs back toward the elbow.
    local sleeve=world*CFrame.new(0,-.62,0)
    put(a.sleeve,sleeve*ALONG)
    put(a.lining,world*CFrame.new(0,-.15,0)*ALONG)
    for _,c in a.clouds do
        local at=world*CFrame.new(a.side*.2,c.at,c.h)
        put(c.rim,at*CFrame.Angles(0,0,0))
        put(c.red,at*CFrame.new(a.side*.003,0,0))
    end
    local elbow=(world*CFrame.new(0,-1.08,0)).Position
    local shoulder=(cam*CFrame.new(pose.shoulder or Vector3.new(a.side*.85,-1.15,.2))).Position
    local span=shoulder-elbow
    if span.Magnitude>.05 then
        a.upper.Size=Vector3.new(span.Magnitude+.15,.42,.42)
        put(a.upper,CFrame.lookAt(elbow+span*.5,shoulder)*CFrame.Angles(0,math.pi/2,0))
    else put(a.upper,CFrame.new(0,-5000,0)) end
end
local function pose(position,fingers,palm,curl,shoulder)
    return {frame=handFrame(position,fingers,palm),curl=curl or .3,shoulder=shoulder}
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
    return {frame=p.frame:Lerp(q.frame,t),curl=curl,shoulder=(p.shoulder and q.shoulder) and sp:Lerp(sq,t) or q.shoulder or p.shoulder}
end
-- Poses (camera space). Idle: both hands low and relaxed, at the bottom edge of the screen.
local function REST(side,breathe) return pose(Vector3.new(side*.5,-.9+(breathe or 0),-.9),Vector3.new(-side*.08,.2,-1),Vector3.new(-side,-.3,0),.35) end
local function LOW(side) return pose(Vector3.new(side*.56,-1.25,-.72),Vector3.new(-side*.05,-.2,-1),Vector3.new(-side,0,0),.25) end
local function KNIFE(side) return pose(Vector3.new(side*.1,-.34,-1.42),Vector3.new(0,.08,-1),Vector3.new(-side,0,0),{0,0,0,0,.35},Vector3.new(side*.62,-.98,-.2)) end
local function SEAL(side) return pose(Vector3.new(side*.055,-.44,-.78),Vector3.new(-side*.05,1,-.18),Vector3.new(-side,0,0),{0,0,.85,.85,.3},Vector3.new(side*.8,-1.1,0)) end
local FACE=pose(Vector3.new(.16,-.14,-.62),Vector3.new(-.22,1,.08),Vector3.new(-1,0,.15),{0,0,.85,.85,.45},Vector3.new(.78,-1.0,.05))
local GRIP=pose(Vector3.new(.14,-.62,-.86),Vector3.new(1,.25,-.25),Vector3.new(0,-1,0),.8,Vector3.new(-.8,-1.1,.1))
local POINT=pose(Vector3.new(.24,-.34,-1.18),Vector3.new(-.04,.12,-1),Vector3.new(-1,0,0),{0,1,1,1,.7},Vector3.new(.74,-1,-.12))

---------------------------------------------------------------- screen
local overlay={}
local function frame(parent,name,size,position,color,z)
    local f=Instance.new("Frame");f.Name=name;f.Size=size;f.Position=position or UDim2.new();f.BackgroundColor3=color or Color3.new()
    f.BackgroundTransparency=1;f.BorderSizePixel=0;f.ZIndex=z or 4;f.Parent=parent
    return f
end
local function round(f) local c=Instance.new("UICorner");c.CornerRadius=UDim.new(.5,0);c.Parent=f;return f end
local function buildOverlay()
    local root=frame(env.gui,"ItachiOverlay",UDim2.fromScale(1,1));overlay.root=root
    overlay.edges={}
    for i,spec in {{UDim2.fromScale(1,.34),UDim2.fromScale(0,0),90},{UDim2.fromScale(1,.34),UDim2.fromScale(0,.66),-90},{UDim2.fromScale(.28,1),UDim2.fromScale(0,0),0},{UDim2.fromScale(.28,1),UDim2.fromScale(.72,0),180}} do
        local e=frame(root,"Edge",spec[1],spec[2],Color3.fromRGB(6,0,0))
        local g=Instance.new("UIGradient");g.Rotation=spec[3];g.Transparency=NumberSequence.new(0,1);g.Parent=e
        overlay.edges[i]=e
    end
    overlay.red=frame(root,"Red",UDim2.fromScale(1,1),nil,Color3.fromRGB(150,0,6),5)
    overlay.lid=frame(root,"Lid",UDim2.fromScale(.5,1),UDim2.fromScale(0,0),Color3.new(),6)   -- one eye closing
    -- Mangekyo Sharingan: red disc, black ring, three curved pinwheel blades, black pupil; spun from code.
    local eye=frame(root,"Sharingan",UDim2.fromOffset(260,260),UDim2.fromScale(.5,.5),COLORS.Red,7);eye.AnchorPoint=Vector2.new(.5,.5);round(eye)
    local ring=frame(eye,"Ring",UDim2.fromScale(.92,.92),UDim2.fromScale(.5,.5),Color3.new(),7);ring.AnchorPoint=Vector2.new(.5,.5);round(ring)
    local inner=frame(ring,"Inner",UDim2.fromScale(.9,.9),UDim2.fromScale(.5,.5),COLORS.Red,7);inner.AnchorPoint=Vector2.new(.5,.5);round(inner)
    overlay.blades={}
    for i=1,3 do
        local b=frame(inner,"Blade",UDim2.fromScale(.16,.5),UDim2.fromScale(.5,.5),Color3.new(),8);b.AnchorPoint=Vector2.new(.5,1);round(b)
        overlay.blades[i]=b
    end
    local pupil=frame(inner,"Pupil",UDim2.fromScale(.22,.22),UDim2.fromScale(.5,.5),Color3.new(),9);pupil.AnchorPoint=Vector2.new(.5,.5);round(pupil)
    overlay.eye=eye;overlay.eyeParts={eye,ring,inner,pupil}
    -- Cracks across the genjutsu world, and the vortex seen from inside the seal.
    overlay.cracks={}
    for i=1,9 do
        local c=frame(root,"Crack",UDim2.fromOffset(3,220+math.random(0,260)),UDim2.fromScale(.5,.5),Color3.fromRGB(255,235,235),8)
        c.AnchorPoint=Vector2.new(.5,0);c.Rotation=(i-1)*40+math.random(-12,12)
        overlay.cracks[i]=c
    end
    overlay.vortex={}
    for i=1,14 do
        local v=frame(root,"Vortex",UDim2.fromOffset(6,600),UDim2.fromScale(.5,.5),i%2==0 and COLORS.Gold or COLORS.Red,5)
        v.AnchorPoint=Vector2.new(.5,1);overlay.vortex[i]={f=v,angle=(i-1)/14*360}
    end
    local label=Instance.new("TextLabel");label.AnchorPoint=Vector2.new(.5,0);label.Position=UDim2.fromScale(.5,.12);label.Size=UDim2.fromOffset(520,30)
    label.BackgroundTransparency=1;label.Font=Enum.Font.GothamBold;label.TextSize=16;label.TextColor3=Color3.fromRGB(255,214,214)
    label.TextStrokeTransparency=.4;label.Text="";label.ZIndex=9;label.Parent=root
    overlay.label=label
    overlay.grade=Instance.new("ColorCorrectionEffect");overlay.grade.Name="ItachiGrade";overlay.grade.Parent=Lighting
end
local function setOverlay(o)
    for _,e in overlay.edges do e.BackgroundTransparency=1-math.clamp(o.vignette or 0,0,1) end
    overlay.red.BackgroundTransparency=1-math.clamp(o.red or 0,0,.85)
    overlay.lid.BackgroundTransparency=1-math.clamp(o.lid or 0,0,1)
    local n=clock();local eye=math.clamp(o.eye or 0,0,1)
    for _,p in overlay.eyeParts do p.BackgroundTransparency=1-eye*(p.Name=="Sharingan" and .55 or .65) end
    overlay.eye.Rotation=(n*420)%360;overlay.eye.Size=UDim2.fromOffset(260*(1.25-.25*eye),260*(1.25-.25*eye))
    for i,b in overlay.blades do b.Rotation=(i-1)*120+20;b.BackgroundTransparency=1-eye*.7 end
    for _,c in overlay.cracks do c.BackgroundTransparency=1-math.clamp(o.crack or 0,0,1) end
    local vortex=math.clamp(o.vortex or 0,0,1)
    for _,v in overlay.vortex do v.f.Rotation=(v.angle+n*140)%360;v.f.BackgroundTransparency=1-vortex*.55 end
    overlay.label.Text=o.label or "";overlay.label.TextTransparency=o.label and 0 or 1;overlay.label.TextStrokeTransparency=o.label and .4 or 1
    local world=math.clamp(o.world or 0,0,1)
    overlay.grade.Saturation=-world;overlay.grade.Contrast=.45*world;overlay.grade.Brightness=-.18*world
    overlay.grade.TintColor=Color3.new(1,1,1):Lerp(Color3.fromRGB(255,110,110),world)
end
local function kick(power,duration) if power>=shake.power or clock()>shake.untilTime then shake.power=power;shake.untilTime=clock()+duration;shake.duration=duration end end

---------------------------------------------------------------- the Tsukuyomi world (victim's screen only)
local world=nil
local function clearWorld()
    if not world then return end
    for _,p in world.parts do p:Destroy() end
    world=nil
end
local function silhouette(parent)
    local m=Instance.new("Model");m.Name="ItachiShadow";m.Parent=parent
    local function sp(name,size,cf,shape)
        local p=VFX.part(name,size,COLORS.Black,cf,shape,Enum.Material.SmoothPlastic);p.Parent=m;return p
    end
    local parts={
        {sp("Legs",Vector3.new(1.6,2.2,1),CFrame.new(0,1.1,0)),CFrame.new(0,1.1,0)},
        {sp("Cloak",Vector3.new(2.4,3.2,1.4),CFrame.new(0,3.2,0)),CFrame.new(0,3.2,0)},
        {sp("Head",Vector3.new(1.2,1.2,1.2),CFrame.new(0,5.4,0),Enum.PartType.Ball),CFrame.new(0,5.4,0)},
        {sp("Hair",Vector3.new(1.3,.5,1.3),CFrame.new(0,5.9,.1)),CFrame.new(0,5.9,.1)},
    }
    for _,x in {-.25,.25} do
        local e=VFX.part("ShadowEye",Vector3.new(.2,.1,.05),COLORS.Red,CFrame.new(),nil,Enum.Material.Neon);e.Parent=m
        table.insert(parts,{e,CFrame.new(x,5.45,-.6)})
    end
    return {model=m,parts=parts}
end
local function buildWorld(casterModel)
    world={parts={},shadows={}}
    local moon=VFX.part("TsukuyomiMoon",Vector3.one*60,COLORS.Moon,CFrame.new(0,-5000,0),Enum.PartType.Ball,Enum.Material.Neon)
    local floor=VFX.part("TsukuyomiFloor",Vector3.new(.2,140,140),Color3.fromRGB(10,4,4),CFrame.new(0,-5000,0),Enum.PartType.Cylinder,Enum.Material.SmoothPlastic)
    floor.Transparency=1;moon.Transparency=1
    world.moon=moon;world.floor=floor;table.insert(world.parts,moon);table.insert(world.parts,floor)
    for i=1,6 do
        local s=silhouette(VFX.folder);s.ang=(i-3.5)*.36;s.rad=7+(i%3)*3;s.next=0
        table.insert(world.shadows,s);table.insert(world.parts,s.model)
    end
    world.caster=casterModel
end
local function updateWorld(a,k,me)
    if not world then return end
    local cfg=I.Tsukuyomi
    local caster=VFX.rootOf(world.caster)
    local myRoot=VFX.rootOf(me)
    if not myRoot then return end
    local toCaster=caster and Vector3.new(caster.Position.X-myRoot.Position.X,0,caster.Position.Z-myRoot.Position.Z) or -myRoot.CFrame.LookVector
    if toCaster.Magnitude<.1 then toCaster=-myRoot.CFrame.LookVector end
    toCaster=toCaster.Unit
    local feet=myRoot.Position-Vector3.yAxis*3
    world.moon.CFrame=CFrame.new(feet+toCaster*260+Vector3.yAxis*110);world.moon.Size=Vector3.one*(60+30*k)
    world.moon.Transparency=1-k
    world.floor.CFrame=CFrame.new(feet+Vector3.yAxis*.06)*CFrame.Angles(0,0,math.pi/2);world.floor.Transparency=1-.85*k
    local base=math.atan2(toCaster.Z,toCaster.X)
    for _,s in world.shadows do
        if a>.9 and a<1.5 and clock()>s.next then
            s.next=clock()+.08+math.random()*.12
            if math.random()<.5 then
                VFX.feathers(s.model:GetPivot().Position+Vector3.yAxis*3,4,1.5,.8)
                s.ang=math.clamp(s.ang+(math.random()-.5)*1.4,-1.2,1.2);s.rad=6+math.random()*8
            end
        end
        local ang=base+s.ang
        local pos=feet+Vector3.new(math.cos(ang),0,math.sin(ang))*s.rad
        local cf=CFrame.lookAt(pos,Vector3.new(feet.X,pos.Y,feet.Z))
        local show=k>.3 and a<1.62
        for _,entry in s.parts do entry[1].CFrame=cf*entry[2];entry[1].Transparency=show and 0 or 1 end
    end
    if a>=1.62 and not world.scattered then
        world.scattered=true
        for _,s in world.shadows do VFX.feathers(s.model:GetPivot().Position+Vector3.yAxis*3,12,3,1.4) end
    end
end

---------------------------------------------------------------- events
local function ownerOf(data)
    local owner=Players:GetPlayerByUserId(data.owner)
    return owner and owner.Character,owner==player
end
function ItachiClient.onEvent(kind,data)
    local model,mine=ownerOf(data)
    local me=player.Character
    if kind=="ItachiCrow" then
        if model then VFX.crowClone(model,data) end
        if mine then crow={start=data.start};combo={untilTime=data.start+2.5,text="까마귀 분신 · 지금 Q 츠쿠요미로 반격",key="Q"} end
    elseif kind=="ItachiTsukuyomi" then
        if model then VFX.tsukuyomi(model,data) end
        if mine then cast={kind="Tsukuyomi",start=data.start,target=data.target}
            combo={untilTime=data.start+I.Tsukuyomi.End+1,text="츠쿠요미 · 구속 중에 E 아마테라스로 연계",key="E",from=data.start+I.Tsukuyomi.Wave} end
        if data.target==me and me then
            victim={kind="Tsukuyomi",start=data.start,caster=model}
            clearWorld();buildWorld(model)
            VFX.sound("Genjutsu",me:GetPivot().Position,.8,3)
        end
    elseif kind=="ItachiTsukuyomiFail" then
        if mine then cast={kind="TsukuyomiFail",start=clock()};env.announce("츠쿠요미","35스터드 · 12° 안에 보이는 대상이 없습니다") end
    elseif kind=="ItachiTsukuyomiEnd" then
        if data.target==me and victim and victim.kind=="Tsukuyomi" and data.reason~="done" then victim=nil;clearWorld() end
    elseif kind=="ItachiAmaterasu" then
        VFX.amaterasu(data)
        if mine then cast={kind="Amaterasu",start=data.start,center=data.center}
            combo={untilTime=data.start+I.Amaterasu.BurnEnd,text="흑염이 타는 중 · R 스사노오로 연계",key="R",from=data.start+I.Amaterasu.Spread} end
    elseif kind=="ItachiAmaterasuFail" then
        if mine then
            local why=({blocked="적이 시야를 가리고 있습니다 · 바닥을 바라보세요",wall="벽이나 가파른 면에는 붙지 않습니다",range="65스터드 안의 지면을 바라보세요"})[data.reason] or "유효한 지면이 아닙니다"
            env.announce("아마테라스",why)
        end
    elseif kind=="ItachiAmaterasuEnd" then
        VFX.endAmaterasu(data.owner,data.start)
    elseif kind=="ItachiSusanoo" then
        if model then VFX.susanoo(model,data) end
        if mine then cast={kind="Susanoo",start=data.start,direction=data.direction};combo.untilTime=0 end
    elseif kind=="ItachiSusanooThrust" then
        VFX.susanooThrust(data.owner,data.target)
        if mine and cast and cast.kind=="Susanoo" then cast.target=data.target end
    elseif kind=="ItachiSusanooHit" then
        VFX.susanooHit(data.owner,data.point)
        if mine then kick(.25,.3) end
        if data.target==me and me then victim={kind="Seal",start=data.start,caster=model} end
    elseif kind=="ItachiSusanooMiss" then
        VFX.susanooMiss(data.owner)
        if mine then env.announce("토츠카의 검","빗나감 · 봉인 없음") end
    elseif kind=="ItachiSusanooSealed" then
        VFX.sound("Seal",data.point,.8,2)
    elseif kind=="ItachiSusanooEnd" then
        VFX.susanooEnd(data.owner,data.reason~="done")
        if mine and cast and cast.kind=="Susanoo" then cast.ended=clock() end
        if victim and victim.kind=="Seal" and victim.caster==model then victim=nil end
    elseif kind=="ItachiMirrorHit" then
        VFX.mirrorHit(data.owner)
    end
end

---------------------------------------------------------------- render
local function lookToward(camera,point,k)
    local d=camera.CFrame:VectorToObjectSpace((point-camera.CFrame.Position).Unit)
    local yaw=math.atan2(-d.X,-d.Z);local pitch=math.atan2(d.Y,math.sqrt(d.X*d.X+d.Z*d.Z))
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
local function shot(camera,me,offset,look)
    local list={VFX.folder,camera}
    for _,p in Players:GetPlayers() do if p.Character then table.insert(list,p.Character) end end
    cinemaParams.FilterDescendantsInstances=list
    local from=me.Position+Vector3.yAxis*1.5
    local best,bestLen=nil,-1
    for _,ang in {0,.45,-.45,.9,-.9,1.4,-1.4} do
        local want=CFrame.Angles(0,ang,0)*offset
        local hit=workspace:Raycast(from,want,cinemaParams)
        local len=hit and math.max(1.5,hit.Distance-1) or want.Magnitude
        if len>bestLen+.01 then best=want.Unit;bestLen=len end
        if len>=want.Magnitude*.85 then break end
    end
    return CFrame.lookAt(from+best*bestLen,look)
end
-- info: {isItachi, melee, sliding, moving, alive}. Returns {fov, fovAdd, combo, ready} for Gojo.client.
function ItachiClient.render(dt,info)
    local n=clock()
    local camera=workspace.CurrentCamera
    if not arms.right then return end
    ItachiClient.updateVictims(n)
    local m=player.Character
    local o={vignette=0,red=0,eye=0,lid=0,crack=0,vortex=0,world=0,label=nil}
    local out={fov=72,fovAdd=0}
    -- Things done to us show for every kit.
    if victim then
        local a=n-victim.start
        if victim.kind=="Tsukuyomi" then
            local cfg=I.Tsukuyomi
            if a>cfg.End+.05 then victim=nil;clearWorld()
            else
                local k=a>=cfg.Eye and smoothstep(window(a,cfg.Eye,cfg.World))*(1-smoothstep(window(a,1.6,1.95))) or 0
                o.world=k;o.vignette=.7*k;o.label=k>.05 and "츠쿠요미 · 환술 세계 · 1.4초 구속" or nil
                o.crack=a>=cfg.Crack and smoothstep(window(a,cfg.Crack,1.75))*(1-smoothstep(window(a,1.75,1.95))) or 0
                if a>=cfg.Wave and not victim.hit then victim.hit=true;o.red=1;kick(.12,.25) end
                if victim.hit then o.red=math.max(o.red,.6*(1-window(a,cfg.Wave,cfg.Wave+.4))) end
                updateWorld(a,k,m)
                local caster=VFX.rootOf(victim.caster)
                if caster and k>0 then env.commonLook(lookToward(camera,caster.Position+Vector3.yAxis*1.2,.85*k)*CFrame.Angles(-.08*k,0,math.sin(n*2)*.03*k)) end
                out.fov=72-10*k;out.victim=true
            end
        elseif victim.kind=="Seal" then
            local cfg=I.Susanoo
            if a>cfg.End+.2 then victim=nil
            else
                local sealedNow=m and (m:GetAttribute("ItachiSealedUntil") or 0)>n
                local caster=VFX.rootOf(victim.caster)
                if caster then env.commonLook(lookToward(camera,caster.Position+Vector3.yAxis*11,.9)) end
                o.vortex=sealedNow and 1 or smoothstep(window(a,cfg.StrikeEnd,cfg.Seal))
                o.red=sealedNow and .75 or .25;o.vignette=.8
                o.label=sealedNow and "토츠카의 검 · 봉인 중" or "토츠카의 검에 끌려 들어가는 중"
                out.fov=82;out.victim=true
            end
        end
    end
    if not info.isItachi then
        poseArm(arms.right,REST(1),false);poseArm(arms.left,REST(-1),false)
        cast=nil;crow=nil;revealBody(nil,false)
        setOverlay(o)
        return out.victim and out or nil
    end
    local visible=info.alive
    local breathe=math.sin(n*1.4)*.01
    local swing=info.moving and math.sin(n*8) or 0
    local R,L=REST(1,breathe+.03*swing),REST(-1,breathe-.03*swing)
    -- Idle Mangekyo: always faintly on.
    VFX.eyeGlow(m,.15)
    -- Basic attack: quick knife-hand jabs, alternating hands, fingers straight, no big wind-up.
    if info.melee and not cast then
        local me=info.melee;local a=n-me.start
        local wind=smoothstep(a/me.windup);local strike=1-(1-window(a,me.windup,me.windup+me.swing))^3
        local back=smoothstep((a-me.windup-me.swing)/math.max(.05,me.duration-me.windup-me.swing))
        local side=me.combo%2==0 and -1 or 1
        local rest=side>0 and R or L
        local cock=blend(rest,KNIFE(side),.25);cock.frame=cock.frame*CFrame.new(0,-.1,.15)
        local p=blend(blend(blend(rest,cock,wind),KNIFE(side),strike),rest,back)
        if side>0 then R=p else L=p end
        out.fovAdd+=2*strike*(1-back)
    end
    if info.sliding then R.frame=R.frame*CFrame.new(0,-.1,.1);L.frame=L.frame*CFrame.new(0,-.1,.1) end
    if not info.alive then cast=nil;crow=nil end
    -- Crow clone: flinch, the hands dissolve fingertips-first into the crows, then come back.
    arms.right.k,arms.left.k=1,1
    if crow then
        local cfg=I.CrowClone;local a=n-crow.start
        if a>cfg.Total then crow=nil
        else
            local gone=smoothstep(window(a,cfg.Break,cfg.MoveFrom))*(1-smoothstep(window(a,cfg.MoveTo,cfg.Reform)))
            arms.right.k,arms.left.k=1-gone,1-gone
            out.fov=72-8*bump(a,0,.25)+6*bump(a,cfg.MoveFrom,cfg.MoveTo)
            o.vignette=math.max(o.vignette,.5*bump(a,0,cfg.Reform));o.eye=math.max(o.eye,.5*bump(a,cfg.Reform-.05,cfg.Total))
            if a<cfg.Break then env.commonLook(CFrame.Angles(.04*bump(a,0,cfg.Break),0,-.03*bump(a,0,cfg.Break))) end
        end
    end
    local cinematic,shotCF=0,nil
    if cast then
        local a=n-cast.start
        if cast.kind=="TsukuyomiFail" then
            if a>.45 then cast=nil else env.commonLook(CFrame.Angles(-.05*bump(a,0,.45),0,0));o.eye=.3*bump(a,0,.45) end
        elseif cast.kind=="Tsukuyomi" then
            ---------------------------------------------------------------- Q
            local cfg=I.Tsukuyomi
            if a>cfg.End+.05 then cast=nil
            else
                -- 0-.3 the head dips, the right hand rises to the face and the left grips the right sleeve;
                -- .3-.55 the Mangekyo spins; .9-1.5 the right hand extends toward the victim; then everything lowers.
                local up=smoothstep(window(a,0,cfg.Prep))*(1-smoothstep(window(a,1.55,1.95)))
                local reach=smoothstep(window(a,1.05,1.3))*(1-smoothstep(window(a,1.5,1.75)))
                R=blend(blend(R,FACE,up),POINT,reach);L=blend(L,GRIP,up*(1-reach))
                env.commonLook(CFrame.Angles(-.12*bump(a,0,.6),0,0))
                out.fov=72-8*smoothstep(window(a,0,cfg.Prep))*(1-smoothstep(window(a,1.5,1.95)))
                o.vignette=.55*up;o.eye=math.max(o.eye,bump(a,cfg.Prep,cfg.Eye+.25)*.9);o.red=.25*bump(a,cfg.Prep,cfg.Eye+.2)
                VFX.eyeGlow(m,.3+.7*up)
                if a>=cfg.Wave and not cast.waved then cast.waved=true;kick(.04,.15) end
            end
        elseif cast.kind=="Amaterasu" then
            ---------------------------------------------------------------- E
            local cfg=I.Amaterasu
            if a>cfg.Full+.1 then cast=nil
            else
                -- .2-.55 the head dips, one eye closes then opens on the Mangekyo; the arms barely move.
                env.commonLook(CFrame.Angles(-.07*bump(a,.1,.9),0,0))
                o.lid=bump(a,.2,.42);o.eye=math.max(o.eye,bump(a,.38,.62)*.85);o.vignette=.45*bump(a,.15,1)
                out.fov=72-6*bump(a,.2,.8)
                R=blend(R,blend(R,SEAL(1),.12),bump(a,.15,.7))
                VFX.eyeGlow(m,.3+.7*bump(a,.2,.9))
                -- Heat haze: a short shake while the flames spread, stronger when close.
                local d=cast.center and m and m:GetPivot().Position and (cast.center-m:GetPivot().Position).Magnitude or 99
                if a>=cfg.Spread and a<cfg.Full and d<40 then kick(.03*(1-d/40)+.01,.1) end
            end
        elseif cast.kind=="Susanoo" then
            ---------------------------------------------------------------- R
            local cfg=I.Susanoo
            if a>cfg.End+.1 or (cast.ended and n-cast.ended>.3) then cast=nil;revealBody(nil,false)
            else
                -- 0-.6 head down, arms lowered slowly, both eyes Mangekyo, red pressure. They stay low.
                local low=smoothstep(window(a,0,.6))*(1-smoothstep(window(a,6.0,6.4)))
                R=blend(R,LOW(1),low);L=blend(L,LOW(-1),low)
                env.commonLook(CFrame.Angles(-.16*smoothstep(window(a,0,.6))*(1-smoothstep(window(a,.6,1.1)))-.1*bump(a,6.0,6.4),0,0))
                o.vignette=.6*low;o.red=.35*bump(a,.1,1.2)+.25*bump(a,cfg.Aim,cfg.StrikeEnd);o.eye=math.max(o.eye,.45*bump(a,.3,.75))
                VFX.eyeGlow(m,1)
                out.fov=72-6*smoothstep(window(a,cfg.Aim,cfg.Thrust))*(1-window(a,cfg.Thrust,cfg.Tip))+10*bump(a,cfg.Thrust,cfg.StrikeEnd)
                -- Cinematic: rear shot while Susanoo rises, over the shoulder for the mirror, side shot of the blade,
                -- first person to aim and thrust, a side shot of the seal, then first person again.
                local root=VFX.rootOf(m)
                local dir=cast.direction or Vector3.new(0,0,-1)
                local side=dir:Cross(Vector3.yAxis).Unit
                if root then
                    local shots={
                        {cfg.Upper,cfg.Mirror,-dir*15+Vector3.yAxis*9+side*2.5,root.Position+Vector3.yAxis*8+dir*3},
                        {cfg.Mirror,cfg.Blade,-dir*5.5-side*3+Vector3.yAxis*3,root.Position+Vector3.yAxis*5+dir*14},
                        {cfg.Blade,cfg.Aim,side*17+dir*2.5+Vector3.yAxis*4,root.Position+Vector3.yAxis*7+dir*3},
                    }
                    if cast.target and a>=cfg.Tip then
                        local tr=VFX.rootOf(cast.target)
                        local mid=tr and root.Position:Lerp(tr.Position,.55) or root.Position+dir*10
                        table.insert(shots,{cfg.StrikeEnd,cfg.SealEnd+.2,side*18+Vector3.yAxis*5+(mid-root.Position)*.5,mid+Vector3.yAxis*3})
                    end
                    for _,s in shots do
                        local k=smoothstep(window(a,s[1]-.05,s[1]+.2))*(1-smoothstep(window(a,s[2]-.2,s[2]+.05)))
                        if k>cinematic then cinematic=k;shotCF=shot(camera,root,s[3],s[4]) end
                    end
                end
            end
        end
    end
    if cinematic>.001 and shotCF then
        local blended=camera.CFrame:Lerp(shotCF,smoothstep(cinematic))
        env.commonLook(camera.CFrame:Inverse()*blended)
        revealBody(m,cinematic>.25)
        if cinematic>.25 then visible=false end
        out.fov=lerp(out.fov,64,cinematic)
    elseif next(revealed) then revealBody(nil,false) end
    if n<shake.untilTime then
        local k=(shake.untilTime-n)/math.max(.01,shake.duration);local p=shake.power*k
        env.commonLook(CFrame.new((math.random()-.5)*p*4,(math.random()-.5)*p*4,0)*CFrame.Angles((math.random()-.5)*p,(math.random()-.5)*p,0))
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
    setOverlay(o)
    -- Never draw our own eyes or sleeves into the first-person view (the cinematic shows the whole body).
    if m and cinematic<=.25 then
        for _,v in m:GetChildren() do if v:IsA("BasePart") and string.sub(v.Name,1,6)=="Itachi" then v.LocalTransparencyModifier=1 end end
    end
    if n<combo.untilTime and n>=(combo.from or 0) then out.combo=combo.text;out.ready=combo.key end
    return out
end
-- Victim side: a sealed body is carried by the server and does not fight it; binds stop jumping.
local heldApplied=false
function ItachiClient.updateVictims(n)
    local m=player.Character;local h=m and m:FindFirstChildOfClass("Humanoid")
    if not h then return end
    local sealedNow=(m:GetAttribute("ItachiSealedUntil") or 0)>n or (victim and victim.kind=="Seal" and (m:GetAttribute("ItachiHeldUntil") or 0)>n)
    if sealedNow~=heldApplied then
        heldApplied=sealedNow
        h.PlatformStand=sealedNow
        if not sealedNow then h:ChangeState(Enum.HumanoidStateType.GettingUp) end
    end
    if (m:GetAttribute("ItachiHeldUntil") or 0)>n or (m:GetAttribute("ItachiLockUntil") or 0)>n then
        h:SetStateEnabled(Enum.HumanoidStateType.Jumping,false)
    end
end
function ItachiClient.busy() return cast~=nil or crow~=nil end
function ItachiClient.reset()
    cast=nil;crow=nil;victim=nil;combo={untilTime=0,text=""};shake.untilTime=0
    clearWorld();revealBody(nil,false)
    if overlay.root then setOverlay({}) end
end
function ItachiClient.init(environment)
    env=environment
    arms.right=buildArm(1);arms.left=buildArm(-1)
    buildOverlay()
    UIS.WindowFocusReleased:Connect(function() shake.untilTime=0 end)
end
return ItachiClient
