-- Local presentation only. Roblox block hands, articulated limbs, two energy sources.
local RS=game:GetService("ReplicatedStorage")
local Debris=game:GetService("Debris")
local K=require(RS:WaitForChild("OkkotsuConfig"));local P=K.Colors
local VFX={};local S=1/.6
local folder=Instance.new("Folder");folder.Name="OkkotsuSpectralFX";folder.Parent=workspace
local effects,claws={},{}
local function now() return workspace:GetServerTimeNow() end
local function smooth(x) x=math.clamp(x,0,1);return x*x*(3-2*x) end
local function seg(a,b,c) return smooth((a-b)/(c-b)) end
VFX.seg=seg
local function part(parent,name,size,color,shape,material)
    local p=Instance.new("Part");p.Name=name;p.Size=size;p.Color=color;p.Material=material or Enum.Material.SmoothPlastic;p.Shape=shape or Enum.PartType.Block
    p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Parent=parent;return p
end
local function model(name) local m=Instance.new("Model");m.Name=name;m.Parent=folder;return m end
local function add(list,m,name,size,at,color,shape,material)
    local p=part(m,name,size,color,shape,material);table.insert(list,{p=p,at=at,size=size});return p
end
local function line(list,m,a,b,width,color)
    return add(list,m,"BoneRidge",Vector3.new(width,width,(b-a).Magnitude),CFrame.lookAt((a+b)/2,b),color,Enum.PartType.Block)
end
local function swept(list,m,points,width,color)
    local control={};for i,p in points do control[i]=p end
    local total=(#control-1)*5;local prev
    local function sample(t)
        local x=math.min(#control-1,t*(#control-1));local i=math.floor(x)+1;local u=x-math.floor(x)
        if i>=#control then i=#control-1;u=1 end
        local p0=control[math.max(1,i-1)];local p1=control[i];local p2=control[i+1];local p3=control[math.min(#control,i+2)]
        return (p1*2+(-p0+p2)*u+(p0*2-p1*5+p2*4-p3)*u*u+(-p0+p1*3-p2*3+p3)*u*u*u)*.5
    end
    for i=0,total do
        local t=i/total;local here=sample(t)
        if prev then
            local d=(here-prev).Magnitude;local w=width*(.05+.95*(1-t)^.8)
            local p=part(m,"FlowingHairLock",Vector3.new(d,w,w),color,Enum.PartType.Cylinder)
            p.CFrame=CFrame.lookAt((here+prev)/2,here)*CFrame.Angles(0,math.pi/2,0)
            table.insert(list,{p=p,at=p.CFrame,size=p.Size})
        end
        prev=here
    end
end
local function place(list,cf,alpha,scale)
    scale=scale or S
    for _,v in list do v.p.Size=v.size*scale;v.p.CFrame=cf*CFrame.new(v.at.Position*scale)*v.at.Rotation;v.p.Transparency=alpha or 0 end
end
local function effect(life,update,cleanup,owner)
    local f={born=now(),life=life,update=update,cleanup=cleanup,owner=owner};table.insert(effects,f);return f
end
function VFX.sound(kind,pos)
    local id,speed,vol="rbxasset://sounds/impact_generic.mp3",.5,.65
    if kind=="sheath" then id="rbxasset://sounds/swordunsheath.wav";speed=.7;vol=.4
    elseif kind=="heal" or kind=="release" then id="rbxasset://sounds/electronicpingshort.wav";speed=kind=="heal" and .6 or 1.3;vol=.4
    elseif kind=="manifest" or kind=="charge" then id="rbxasset://sounds/action_falling.mp3";speed=kind=="manifest" and .25 or .65;vol=.7 end
    local anchor=part(folder,"Audio",Vector3.one*.02,P.Ink);anchor.Transparency=1;anchor.Position=pos
    local sound=Instance.new("Sound");sound.SoundId=id;sound.PlaybackSpeed=speed;sound.Volume=vol;sound.RollOffMaxDistance=150;sound.Parent=anchor;sound:Play();Debris:AddItem(anchor,5)
end
function VFX.ring(pos,radius,life,color)
    local m=model("CursedPressure");local list={};color=color or P.Aura
    for i=0,47 do local a=i*math.pi/24;local b=(i+1)*math.pi/24;local p=line(list,m,Vector3.new(math.cos(a),0,math.sin(a)),Vector3.new(math.cos(b),0,math.sin(b)),.015,color);p.Material=Enum.Material.Neon end
    effect(life,function(u) place(list,CFrame.new(pos),.25+.75*u,radius*(.5+.5*u)) end,function() m:Destroy() end)
end
function VFX.portal(pos,direction)
    if not pos then return end
    local cf=CFrame.lookAt(pos,pos-direction);local m=model("RikaDimensionalRift");local list={}
    local void=add(list,m,"RiftVoid",Vector3.new(1.12,1.92,.05),CFrame.new(0,0,.04),Color3.fromRGB(20,8,28));void.Material=Enum.Material.Neon
    local function oval(rx,ry,count,width,color,phase)
        local points={};for i=0,count do local a=i*math.pi*2/count+phase;points[i+1]=Vector3.new(math.cos(a)*rx,math.sin(a)*ry,0) end
        for i=1,count do local p=line(list,m,points[i],points[i+1],width,color);p.Material=Enum.Material.Neon end
    end
    oval(.64,1.04,36,.055,Color3.fromRGB(185,91,175),0)
    oval(.55,.91,28,.018,Color3.fromRGB(242,213,238),.06)
    oval(.37,.71,20,.022,Color3.fromRGB(124,65,133),.12)
    effect(1.05,function(u)
        local open=smooth(math.min(1,u/.18));local close=1-smooth((u-.66)/.34)
        place(list,cf,1-.92*open*close,.5*(.22+.78*open)*(1-.08*math.max(0,u-.75)))
    end,function() m:Destroy() end)
end
function VFX.motes(pos,color,count,inward)
    for i=1,count do
        local p=part(folder,"CurseMote",Vector3.one*(.05+math.random()*.055),color,Enum.PartType.Ball,Enum.Material.Neon)
        local offset=Vector3.new(math.random()-.5,math.random()-.5,math.random()-.5)*3
        effect(.55+math.random()*.25,function(u) p.Position=pos+offset*(inward and (1-u)^2 or u);p.Transparency=math.sin(u*math.pi)*-.75+1 end,function() p:Destroy() end)
    end
end
local function trail(a,b,color,width,life)
    if (b-a).Magnitude<.01 then return end
    local p=part(folder,"CurseTrail",Vector3.new(width,width,(b-a).Magnitude),color,nil,Enum.Material.Neon);p.CFrame=CFrame.lookAt((a+b)/2,b)
    effect(life,function(u) p.Transparency=u end,function() p:Destroy() end)
end
local function newArm(m)
    local a={fixed={},palm={}}
    a.upper=part(m,"RikaDrapedSleeve",Vector3.one,P.Bone,Enum.PartType.Cylinder)
    a.fore=part(m,"RikaForearmSleeve",Vector3.one,Color3.fromRGB(222,217,214),Enum.PartType.Cylinder)
    a.elbow=part(m,"RikaElbowFold",Vector3.one,Color3.fromRGB(202,197,195),Enum.PartType.Ball)
    a.shoulder=part(m,"RikaMantleShoulder",Vector3.one,P.Bone,Enum.PartType.Ball)
    -- A single smooth block fist; Roblox Rika has no separate fingers.
    add(a.palm,m,"RikaBlockFist",Vector3.new(.36,.38,.26),CFrame.new(0,-.12,0),P.Bone)
    return a
end
local function bone(p,a,b,width,alpha)
    p.Size=Vector3.new((b-a).Magnitude,width,width);p.CFrame=CFrame.lookAt((a+b)/2,b)*CFrame.Angles(0,math.pi/2,0);p.Transparency=alpha
end
local function poseArm(a,cf,shoulder,elbow,wrist,alpha,forward)
    local s=(cf*CFrame.new(shoulder*S)).Position;local e=(cf*CFrame.new(elbow*S)).Position;local w=(cf*CFrame.new(wrist*S)).Position
    bone(a.upper,s,e,.45*S,alpha);bone(a.fore,e,w,.32*S,alpha)
    a.elbow.Size=Vector3.one*.28*S;a.elbow.CFrame=CFrame.new(e);a.elbow.Transparency=alpha
    a.shoulder.Size=Vector3.one*.34*S;a.shoulder.CFrame=CFrame.new(s);a.shoulder.Transparency=alpha
    local f=cf:VectorToWorldSpace(forward or Vector3.new(0,-.2,-1))
    local frame=CFrame.lookAt(w,w+f)*CFrame.Angles(math.pi/2,0,0)
    place(a.palm,frame,alpha)
    return w
end
function VFX.newRig()
    local m=model("RikaBehindCaster");local body,head={},{ }
    add(body,m,"ShadowedRobe",Vector3.new(2.15,2.9,1.15),CFrame.new(0,-.65,2.08),P.Ink,Enum.PartType.Ball)
    add(body,m,"PaleShoulderMantle",Vector3.new(2.65,1.05,1.24),CFrame.new(0,.18,1.93),Color3.fromRGB(203,199,199),Enum.PartType.Ball)
    for _,side in {-1,1} do
        add(body,m,"DrapedSleeve",Vector3.new(1.18,2.05,1.08),CFrame.new(side*.84,-.66,2.08)*CFrame.Angles(0,0,side*.12),P.Bone,Enum.PartType.Ball)
        swept(body,m,{Vector3.new(side*.54,.26,1.45),Vector3.new(side*.86,-.2,1.36),Vector3.new(side*1.08,-.92,1.57),Vector3.new(side*1.18,-1.62,2.03)},.11,Color3.fromRGB(229,225,222))
        swept(body,m,{Vector3.new(side*.24,-.18,1.36),Vector3.new(side*.32,-.8,1.38),Vector3.new(side*.53,-1.48,1.7),Vector3.new(side*.7,-2.03,2.15)},.05,P.Ink)
    end
    local shell=add(head,m,"SmoothTaperedCranium",Vector3.one,CFrame.identity,P.Bone)
    local shape=Instance.new("SpecialMesh");shape.MeshType=Enum.MeshType.Sphere;shape.Scale=Vector3.new(.82,1.5,.76);shape.Parent=shell
    -- Keep Rika's face completely smooth and blank: no eyes, nose, mouth, teeth, or jaw pieces.
    for _,side in {-1,1} do
        swept(head,m,{Vector3.new(side*.04,.55,-.28),Vector3.new(side*.24,.98,-.42),Vector3.new(side*.62,1.46,-.3),Vector3.new(side*1.1,1.58,-.05),Vector3.new(side*1.58,1.23,.22),Vector3.new(side*1.88,.78,.38),Vector3.new(side*1.72,.35,.45)},.17,side<0 and P.Bone or Color3.fromRGB(190,185,184))
        swept(head,m,{Vector3.new(side*.18,.47,-.4),Vector3.new(side*.48,.83,-.52),Vector3.new(side*1,1.06,-.35),Vector3.new(side*1.55,.88,-.1),Vector3.new(side*1.9,.45,.24)},.13,Color3.fromRGB(129,124,132))
        swept(head,m,{Vector3.new(side*.1,.52,.34),Vector3.new(side*.38,.96,.58),Vector3.new(side*.8,1.44,.83),Vector3.new(side*1.35,1.32,1.07),Vector3.new(side*1.82,.81,1.28),Vector3.new(side*1.65,.34,1.34)},.16,side<0 and Color3.fromRGB(190,185,184) or P.Bone)
        swept(head,m,{Vector3.new(side*.15,.62,-.45),Vector3.new(side*.42,1.05,-.39),Vector3.new(side*.86,1.42,-.2),Vector3.new(side*1.36,1.35,.08),Vector3.new(side*1.78,.82,.36)},.025,Color3.fromRGB(242,238,233))
    end
    swept(head,m,{Vector3.new(-.22,.68,-.28),Vector3.new(-.5,1.12,-.25),Vector3.new(-.52,1.58,-.13),Vector3.new(-.18,1.85,-.02),Vector3.new(.42,1.72,.12),Vector3.new(.93,1.36,.3),Vector3.new(1.35,.93,.45)},.16,P.Bone)
    swept(head,m,{Vector3.new(.02,.64,-.38),Vector3.new(.36,1.08,-.45),Vector3.new(.78,1.42,-.25),Vector3.new(1.23,1.48,.02),Vector3.new(1.67,1.14,.3),Vector3.new(1.9,.68,.5)},.13,Color3.fromRGB(190,185,184))
    swept(head,m,{Vector3.new(0,.5,.4),Vector3.new(.18,1,.72),Vector3.new(.55,1.52,1),Vector3.new(1,1.7,1.22),Vector3.new(1.46,1.35,1.4),Vector3.new(1.8,.9,1.5)},.14,Color3.fromRGB(129,124,132))
    local arms={newArm(m),newArm(m)}
    for i=0,8 do local side=i%2==0 and -1 or 1;swept(body,m,{Vector3.new(side*.12,-.42,2.38),Vector3.new(side*(.36+i*.025),-1.12,2.63),Vector3.new(side*(.62+i*.04),-1.98,3.03),Vector3.new(side*(.86+i*.05),-2.5,3.32)},.035+(i%3)*.012,i%2==0 and P.Ink or Color3.fromRGB(94,84,99)) end
    return {m=m,body=body,head=head,arms=arms,neck={part(m,"NeckBase",Vector3.one,P.Bone,Enum.PartType.Cylinder),part(m,"NeckNape",Vector3.one,P.Bone,Enum.PartType.Cylinder)}}
end
function VFX.poseRig(v,cf,a)
    local reveal=seg(a,1.05,1.85);local fade=1-seg(a,3.85,4.6);local alpha=1-reveal*fade;local lean=seg(a,1.1,2)
    place(v.body,cf*CFrame.new(0,-.8*(1-reveal)*S,0),alpha)
    local head=cf*CFrame.new(Vector3.new(.12-.72*lean,1.95-.82*lean+.1*seg(a,2.65,3.12),1.8-5.25*lean+seg(a,2.65,3.12))*S)*CFrame.Angles(.6-.8*seg(a,2.65,3.12),math.pi*(1-seg(a,2.65,3.12))-.15,0)
    local arch=(cf*CFrame.new(0,3.2*S,-.3*S)).Position;local nape=(head*CFrame.new(0,.65*S,.48*S)).Position
    bone(v.neck[1],(cf*CFrame.new(0,.95*S,S)).Position,arch,.5*S,alpha);bone(v.neck[2],arch,nape,.4*S,alpha)
    place(v.head,head,alpha)
    for i,arm in v.arms do local s=i==1 and -1 or 1;poseArm(arm,cf,Vector3.new(s*1.05,.62,1.7),Vector3.new(s*1.72,.25,.95),Vector3.new(s*(1.22-.08*lean),-.2,.34),alpha,Vector3.new(-s*.12,-.18,-1)) end
    return (head*CFrame.new(0,-.08*S,-.48*S)).Position
end
function VFX.claw(data)
    local old=claws[data.owner];if old then old.dead=true end
    local portal=data.portal or data.position-data.direction*1.3+Vector3.yAxis*1.3;VFX.portal(portal,data.direction)
    local m=model("RikaPortalSwing");local arm=newArm(m);local cf=CFrame.lookAt(portal,portal+data.direction);local hit=cf:PointToObjectSpace(data.position)/S;local swept=hit+Vector3.new(-1.25,0,0);local start=Vector3.new(0,0,.16);local last;local lastAt=0
    local delay=math.max(.12,data.delay or .44);local finish=delay+.48
    local entry=effect(finish,function(u)
        local a=u*finish;local wrist=start:Lerp(hit,seg(a,.025,delay))
        if a>=delay then wrist=hit:Lerp(swept,seg(a,delay,delay+.18)) end
        if a>delay+.18 then wrist=swept:Lerp(start,seg(a,delay+.18,delay+.42)) end
        local shoulder=Vector3.new(0,0,.12);local elbow=shoulder:Lerp(wrist,.5)+Vector3.new(-.1,.28,0)
        local w=poseArm(arm,cf,shoulder,elbow,wrist,1-seg(a,.025,.1)*(1-seg(a,delay+.34,finish)),Vector3.new(-.55,-.08,-1))
        if a>=delay and a<delay+.22 and last and now()-lastAt>.022 then trail(last,w,Color3.fromRGB(255,232,247),.1,.27);lastAt=now() end;last=w
    end,function() m:Destroy() end,data.owner);claws[data.owner]=entry
end
local function beam(from,to,radius,color,opacity)
    local p=part(folder,"PureLoveStream",Vector3.one,color,Enum.PartType.Cylinder,Enum.Material.Neon)
    effect(.9,function(u) local width=radius*(.5+.5*math.sin(u*math.pi))*(.92+.08*math.sin(u*70));bone(p,from,to,width*2,1-opacity*(1-seg(u,.5,1))) end,function() p:Destroy() end)
end
function VFX.beam(data,faceOrigin,hand)
    local focus=data.position+data.direction*math.min(3.8*S,math.max(.8,data.distance*.6));local finish=data.position+data.direction*data.distance
    beam(hand,focus,.095*S,Color3.fromRGB(213,255,250),.9)
    beam(faceOrigin,focus,.38*S,P.Aura,.5);beam(faceOrigin,focus,.12*S,Color3.new(1,1,1),.85)
    beam(focus,finish,.85*S,P.Aura,.24);beam(focus,finish,.36*S,Color3.fromRGB(255,218,239),.65);beam(focus,finish,.11*S,Color3.new(1,1,1),.9)
    VFX.motes(focus,P.Aura,22,false);VFX.sound("beam",data.position)
end
function VFX.cancel(owner)
    for _,f in effects do if f.owner==owner then f.dead=true end end
end
function VFX.render()
    local n=now()
    for i=#effects,1,-1 do local f=effects[i];local u=(n-f.born)/f.life;if f.dead or u>=1 then f.cleanup();table.remove(effects,i) else f.update(u) end end
end
function VFX.reset() for _,f in effects do f.cleanup() end;effects={};claws={} end
return VFX
