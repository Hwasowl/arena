local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
-- Apply daylight when the arena starts, including places synced from older builds.
Lighting.ClockTime = 13.5
Lighting.Brightness = 3
Lighting.Ambient = Color3.new(0.38, 0.42, 0.52)
Lighting.OutdoorAmbient = Color3.new(0.5, 0.54, 0.64)
local Config = require(game.ReplicatedStorage:WaitForChild("GojoConfig"))
local arena = Instance.new("Folder")
arena.Name = "InfinityArena"
arena.Parent = workspace
local function part(name, size, cf, color, material, parent)
    local p = Instance.new("Part")
    p.Name, p.Size, p.CFrame = name, size, cf
    p.Color, p.Material = color, material or Enum.Material.Slate
    p.Anchored, p.TopSurface, p.BottomSurface = true, Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    p.Parent = parent or arena
    return p
end
local dark = Color3.fromRGB(42, 50, 67)
local cyan = Color3.fromRGB(57, 170, 215)
part("Foundation", Vector3.new(150, 4, 150), CFrame.new(0,-3,0), dark)
for x=-7,7 do
    for z=-7,7 do
        local shade = 45 + ((x*7+z*3)%5)*2
        part("StoneTile", Vector3.new(9.88,.35,9.88), CFrame.new(x*10,-.825,z*10), Color3.fromRGB(shade,shade+7,shade+15),Enum.Material.Concrete)
    end
end
for _,radius in {22,42,66} do
    for i=1,100 do
        local a = i*math.pi*2/100
        local p=part("RuneCircle",Vector3.new(.10,.03,radius*.064),CFrame.new(math.cos(a)*radius,-.63,math.sin(a)*radius)*CFrame.Angles(0,-a,0),cyan,Enum.Material.Neon)
        p.CanCollide=false
    end
end
for i=0,11 do
    local a = i*math.pi/6
    local cf=CFrame.new(math.sin(a)*61,0,math.cos(a)*61)*CFrame.Angles(0,a,0)
    for _,side in {-1,1} do
        part("GatePillar",Vector3.new(3,16,3),cf*CFrame.new(side*4,7,0),dark)
        part("LightInset",Vector3.new(.12,11,3.04),cf*CFrame.new(side*4,7,0),cyan,Enum.Material.Neon).CanCollide=false
    end
    part("GateLintel",Vector3.new(13,2,4),cf*CFrame.new(0,15,0),dark)
end
local spawn=Instance.new("SpawnLocation")
spawn.Name="Entry";spawn.Size=Vector3.new(8,.2,8);spawn.CFrame=CFrame.new(0,-.5,23)
spawn.Anchored=true;spawn.Transparency=1;spawn.Neutral=true;spawn.Duration=0;spawn.Parent=arena
local atmosphere=Instance.new("Atmosphere")
atmosphere.Density=.18;atmosphere.Offset=.25;atmosphere.Color=Color3.fromRGB(152,174,211);atmosphere.Decay=Color3.fromRGB(78,92,128);atmosphere.Parent=Lighting
local bloom=Instance.new("BloomEffect")
bloom.Intensity=.65;bloom.Size=28;bloom.Threshold=1.2;bloom.Parent=Lighting
local grade=Instance.new("ColorCorrectionEffect")
grade.Contrast=.04;grade.Saturation=-.04;grade.TintColor=Color3.fromRGB(235,243,255);grade.Parent=Lighting

local function dummy(pos,index)
    local m=Instance.new("Model");m.Name="Training Target "..index
    local root=part("HumanoidRootPart",Vector3.new(2,2,1),CFrame.new(pos),dark,nil,m);root.Transparency=1;root.CanCollide=false
    local h=Instance.new("Humanoid");h.RequiresNeck=false;h.BreakJointsOnDeath=false;h.MaxHealth=250;h.Health=250;h.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.Viewer;h.Parent=m
    local pieces={
        {"Torso",Vector3.new(2,2,1),Vector3.new(0,0,0)},
        {"Head",Vector3.new(1.4,1.4,1.4),Vector3.new(0,1.7,0)},
        {"Left Arm",Vector3.new(.7,2,.8),Vector3.new(-1.5,0,0)},
        {"Right Arm",Vector3.new(.7,2,.8),Vector3.new(1.5,0,0)},
        {"Left Leg",Vector3.new(.8,2,.8),Vector3.new(-.6,-2,0)},
        {"Right Leg",Vector3.new(.8,2,.8),Vector3.new(.6,-2,0)},
    }
    for _,v in pieces do
        local p=part(v[1],v[2],CFrame.new(pos+v[3]),Color3.fromRGB(71,88,113),Enum.Material.Metal,m)
        p.Anchored=false;p.CanCollide=false;p.Massless=true
        local weld=Instance.new("WeldConstraint");weld.Part0=root;weld.Part1=p;weld.Parent=p
    end
    local core=part("Core",Vector3.new(.7,.7,.12),CFrame.new(pos+Vector3.new(0,.15,.56)),cyan,Enum.Material.Neon,m)
    core.Anchored=false;core.CanCollide=false
    local weld=Instance.new("WeldConstraint");weld.Part0=root;weld.Part1=core;weld.Parent=core
    m.PrimaryPart=root;m:SetAttribute("TrainingTarget",true);m.Parent=workspace
    h.Died:Connect(function() task.delay(3,function() m:Destroy();dummy(pos,index) end) end)
end
dummy(Vector3.new(0,3,-12),1);dummy(Vector3.new(-13,3,-20),2);dummy(Vector3.new(13,3,-26),3)

-- Arena pillars and low walls. Same layout as the browser preview (scaled up for studs).
-- Collidable pillars and low walls provide cover and elevated positions.
local stoneTrim=Color3.fromRGB(99,115,132)
local function pillar(x,z,width,height)
    local base=-.65
    part("AnchorPillar",Vector3.new(width,height,width),CFrame.new(x,base+height/2,z),dark,Enum.Material.Concrete)
    part("AnchorPillarCap",Vector3.new(width+.8,1,width+.8),CFrame.new(x,base+height-.5,z),stoneTrim,Enum.Material.Metal)
    local inset=part("AnchorPillarLight",Vector3.new(.15,height*.7,width*.35),CFrame.new(x,base+height*.45,z+width/2+.02),cyan,Enum.Material.Neon)
    inset.CanCollide=false;inset.CanQuery=false
end
local function wall(x,z,sizeX,sizeZ,height)
    part("AnchorWall",Vector3.new(sizeX,height,sizeZ),CFrame.new(x,-.65+height/2,z),dark,Enum.Material.Concrete)
    part("AnchorWallCap",Vector3.new(sizeX+.6,.8,sizeZ+.6),CFrame.new(x,-.65+height-.4,z),stoneTrim,Enum.Material.Metal)
end
for _,v in {{-26,-8,5,35},{26,-12,5,40},{-34,-34,5,30},{36,-28,5,34},{0,-46,6,45},{-20,16,4.5,26},{22,18,4.5,30}} do pillar(v[1],v[2],v[3],v[4]) end
wall(-12,2,20,2,12);wall(14,-3,2,18,12)

-- Only each character's signature piece is added; the rest of the player's own avatar is left untouched.
-- Gojo: blindfold. Zenitsu: sheathed katana. Shanks: right-hand sword and missing left arm. Reze: choker/head. Doraemon: pocket/copter.
-- Parts tagged "Outfit" are rebuilt whenever the character or transformation changes.
local function outfit(character,kind,fresh)
    local h=character:WaitForChild("Humanoid");h.MaxHealth=Config.MaxHealth
    if fresh then h.Health=Config.MaxHealth end
    local head=character:WaitForChild("Head")
    local root=character:WaitForChild("HumanoidRootPart")
    for _,v in character:GetChildren() do if v:GetAttribute("Outfit") then v:Destroy() end end
    -- Undo anything hidden by a previous Bomb Devil head.
    for _,v in character:GetDescendants() do
        local original=v:GetAttribute("OutfitHidden")
        if original~=nil then v.Transparency=original;v:SetAttribute("OutfitHidden",nil) end
    end
    local function attach(anchor,name,size,offset,color,material,shape)
        local p=part(name,size,anchor.CFrame*offset,color,material or Enum.Material.SmoothPlastic,character)
        if shape then p.Shape=shape end
        p.Anchored=false;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Massless=true;p:SetAttribute("Outfit",true)
        local weld=Instance.new("WeldConstraint");weld.Part0=anchor;weld.Part1=p;weld.Parent=p
        return p
    end
    local function hide(v)
        if v:GetAttribute("OutfitHidden")==nil then v:SetAttribute("OutfitHidden",v.Transparency) end
        v.Transparency=1
    end
    local neck=-head.Size.Y/2-.08
    if kind=="Zenitsu" then
        -- Sheathed katana at the left hip, edge up, hilt forward.
        attach(root,"ZenitsuSaya",Vector3.new(.22,.28,3.4),CFrame.new(-1.15,-.9,.6)*CFrame.Angles(.25,.12,0),Color3.fromRGB(43,34,51))
        attach(root,"ZenitsuTsuba",Vector3.new(.5,.5,.08),CFrame.new(-1.05,-.62,-1.0)*CFrame.Angles(.25,.12,0),Color3.fromRGB(42,37,34),Enum.Material.Metal)
        attach(root,"ZenitsuTsuka",Vector3.new(.18,.22,1.1),CFrame.new(-1.0,-.5,-1.55)*CFrame.Angles(.25,.12,0),Color3.fromRGB(241,234,216))
    elseif kind=="Doraemon" then
        -- A white belly patch with a horizontal, semicircular pocket sewn to the real torso.
        local torso=character:FindFirstChild("LowerTorso") or character:FindFirstChild("Torso") or root
        local front=-torso.Size.Z/2-.035
        local white=Color3.fromRGB(255,253,241);local ink=Color3.fromRGB(49,58,69);local gold=Color3.fromRGB(244,206,82)
        attach(torso,"DoraemonBelly",Vector3.new(1.65,1.65,.14),CFrame.new(0,-.08,front),white,nil,Enum.PartType.Ball)
        local radius=.64;local opening=.06
        for i=0,23 do
            local y=(i+.5)*radius/24
            local width=2*radius*math.sqrt(math.max(0,1-(y/radius)^2))
            attach(torso,"DoraemonPocketFabric",Vector3.new(width,radius/24+.005,.075),CFrame.new(0,opening-y,front-.12),white)
        end
        attach(torso,"DoraemonPocketMouth",Vector3.new(1.25,.027,.045),CFrame.new(0,opening,front-.17),ink)
        for i=0,31 do
            local a=i*math.pi/32;local b=(i+1)*math.pi/32
            local p1=Vector3.new(-radius*math.cos(a),opening-radius*math.sin(a),front-.163)
            local p2=Vector3.new(-radius*math.cos(b),opening-radius*math.sin(b),front-.163)
            attach(torso,"DoraemonPocketSeam",Vector3.new(.018,.018,(p2-p1).Magnitude+.008),CFrame.lookAt((p1+p2)/2,p2),ink)
        end
        local upper=character:FindFirstChild("UpperTorso") or torso
        attach(upper,"DoraemonCollar",Vector3.new(upper.Size.X*.9,.1,.06),CFrame.new(0,upper.Size.Y/2-.1,-upper.Size.Z/2-.03),Color3.fromRGB(217,42,54))
        attach(upper,"DoraemonBell",Vector3.new(.28,.28,.16),CFrame.new(0,upper.Size.Y/2-.28,-upper.Size.Z/2-.11),gold,Enum.Material.Metal,Enum.PartType.Ball)
        attach(upper,"DoraemonBellSlot",Vector3.new(.018,.1,.014),CFrame.new(0,upper.Size.Y/2-.32,-upper.Size.Z/2-.195),ink)
        local shaft=attach(head,"DoraemonRotorShaft",Vector3.new(.055,.45,.055),CFrame.new(0,head.Size.Y/2+.225,0),gold)
        local hub=attach(head,"DoraemonRotorHub",Vector3.new(.2,.08,.2),CFrame.new(0,head.Size.Y/2+.45,0),gold,nil,Enum.PartType.Ball)
        local blade=attach(head,"DoraemonRotorBlade",Vector3.new(1.7,.045,.2),CFrame.new(0,head.Size.Y/2+.51,0),gold)
        shaft.Transparency=1;hub.Transparency=1;blade.Transparency=1
        for _,v in blade:GetChildren() do if v:IsA("WeldConstraint") then v:Destroy() end end
        local rotor=Instance.new("Motor6D");rotor.Name="DoraemonRotorMotor";rotor.Part0=head;rotor.Part1=blade;rotor.C0=CFrame.new(0,head.Size.Y/2+.51,0);rotor.Parent=blade
    elseif kind=="Shanks" then
        local leftArm=character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm") or character:FindFirstChild("LeftLowerArm")
        if leftArm then hide(leftArm) end
        local rightArm=character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm") or character:FindFirstChild("RightHand") or root
        local sword=CFrame.new(.08,-.1,-.28)*CFrame.Angles(math.rad(-18),0,math.rad(-22))
        attach(rightArm,"ShanksBlade",Vector3.new(.11,.15,3.2),sword*CFrame.new(0,0,-1.45),Color3.fromRGB(215,221,230),Enum.Material.Metal)
        attach(rightArm,"ShanksEdge",Vector3.new(.025,.035,3.05),sword*CFrame.new(-.045,-.035,-1.45),Color3.fromRGB(174,40,51),Enum.Material.Neon)
        attach(rightArm,"ShanksGuard",Vector3.new(.62,.14,.18),sword*CFrame.new(0,0,.18),Color3.fromRGB(189,157,93),Enum.Material.Metal)
        attach(rightArm,"ShanksGrip",Vector3.new(.14,.16,.72),sword*CFrame.new(0,0,.58),Color3.fromRGB(77,35,43),Enum.Material.SmoothPlastic)
    elseif kind=="Reze" then
        local transformed=(character:GetAttribute("BombDevilUntil") or 0)>workspace:GetServerTimeNow()
        if transformed then
            -- Bomb Devil: the real head and anything worn on it disappear under a bomb-shaped head with fuse hair.
            hide(head)
            for _,v in head:GetChildren() do if v:IsA("Decal") then hide(v) end end
            for _,accessory in character:GetChildren() do
                local handle=accessory:IsA("Accessory") and accessory:FindFirstChild("Handle")
                local weld=handle and handle:FindFirstChildWhichIsA("Weld")
                if weld and (weld.Part0==head or weld.Part1==head) then hide(handle) end
            end
            local metal=Color3.fromRGB(46,44,48)
            local bomb=attach(head,"BombHead",Vector3.one*1.7,CFrame.new(0,.15,0),metal,Enum.Material.Metal,Enum.PartType.Ball)
            attach(head,"BombBand",Vector3.new(1.76,.28,1.76),CFrame.new(0,-.05,0)*CFrame.Angles(0,0,math.pi/2),Color3.fromRGB(24,22,26),Enum.Material.Metal,Enum.PartType.Cylinder)
            attach(head,"BombCap",Vector3.new(.3,.55,.55),CFrame.new(0,1.05,0)*CFrame.Angles(0,0,math.pi/2),Color3.fromRGB(120,112,104),Enum.Material.Metal,Enum.PartType.Cylinder)
            for i=-2,2 do
                attach(head,"BombTooth",Vector3.new(.16,.2,.08),CFrame.new(i*.19,-.38,-.8)*CFrame.Angles(0,i*.18,0),Color3.fromRGB(240,236,226))
            end
            for _,x in {-.34,.34} do
                attach(head,"BombEye",Vector3.new(.34,.09,.08),CFrame.new(x,.22,-.82)*CFrame.Angles(0,x*.5,x>0 and -.2 or .2),Color3.new(1,.55,.2),Enum.Material.Neon)
            end
            -- Fuse cords hang from the back and sides like hair, each with a lit tip.
            for i=0,6 do
                local a=math.pi*.15+i*math.pi*.7/6
                local offset=CFrame.new(math.cos(a)*.75,.25,math.sin(a)*.75)*CFrame.Angles(.35*math.sin(a),0,-.35*math.cos(a))
                attach(head,"Fuse",Vector3.new(.1,1.3,.1),offset*CFrame.new(0,-.55,0),Color3.fromRGB(84,62,44))
                local tip=attach(head,"FuseTip",Vector3.one*.16,offset*CFrame.new(0,-1.25,0),Config.Colors.Bomb,Enum.Material.Neon,Enum.PartType.Ball)
                if i%2==0 then local sparks=Instance.new("Sparkles");sparks.SparkleColor=Config.Colors.Bomb;sparks.Parent=tip end
            end
            local light=Instance.new("PointLight");light.Color=Config.Colors.Bomb;light.Brightness=2;light.Range=10;light.Parent=bomb
        else
            -- Choker with the grenade pin ring at the front of the throat.
            attach(head,"RezeChoker",Vector3.new(.24,.92,.92),CFrame.new(0,neck,0)*CFrame.Angles(0,0,math.pi/2),Color3.fromRGB(16,16,20),Enum.Material.SmoothPlastic,Enum.PartType.Cylinder)
            attach(head,"RezePin",Vector3.new(.06,.3,.3),CFrame.new(0,neck-.12,-.5)*CFrame.Angles(0,math.pi/2,0),Color3.fromRGB(200,204,210),Enum.Material.Metal,Enum.PartType.Cylinder)
        end
    else
        attach(head,"GojoBlindfold",Vector3.new(head.Size.X*1.04,.42,head.Size.Z*1.08),CFrame.new(0,.1,0),Color3.fromRGB(12,14,23))
    end
end
local function joined(p)
    local function dress(c,fresh) outfit(c,p:GetAttribute("Character") or "Gojo",fresh) end
    local function watchDoraRotor(c)
        c:GetAttributeChangedSignal("DoraCopterUntil"):Connect(function()
            local visible=(c:GetAttribute("DoraCopterUntil") or 0)>workspace:GetServerTimeNow() and p:GetAttribute("Character")=="Doraemon"
            for _,name in {"DoraemonRotorShaft","DoraemonRotorHub","DoraemonRotorBlade"} do local rotor=c:FindFirstChild(name);if rotor then rotor.Transparency=visible and 0 or 1 end end
        end)
    end
    p.CharacterAdded:Connect(function(c)
        watchDoraRotor(c)
        c:GetAttributeChangedSignal("BombDevilUntil"):Connect(function() dress(c) end)
        dress(c,true)
    end)
    p:GetAttributeChangedSignal("Character"):Connect(function() if p.Character then task.spawn(dress,p.Character) end end)
    if p.Character then
        watchDoraRotor(p.Character)
        p.Character:GetAttributeChangedSignal("BombDevilUntil"):Connect(function() dress(p.Character) end)
        task.spawn(dress,p.Character,true)
    end
end
Players.PlayerAdded:Connect(joined);for _,p in Players:GetPlayers() do joined(p) end
