local Players=game:GetService("Players")
local Debris=game:GetService("Debris")
local Tween=game:GetService("TweenService")
local C=require(game:GetService("ReplicatedStorage"):WaitForChild("GojoConfig"))
local M={};local env;local cast;local boot;local glow;local cross={};local gold=Color3.fromRGB(255,215,80)
local function now() return workspace:GetServerTimeNow() end
local function smooth(x) x=math.clamp(x,0,1);return x*x*(3-2*x) end
local function part(name,size,parent,color)
    local p=Instance.new("Part");p.Name=name;p.Size=size;p.Color=color or gold;p.Material=Enum.Material.Neon
    p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false;p.Parent=parent;return p
end
local function sound(at,charge)
    local p=part("LightSound",Vector3.one*.1,workspace);p.CFrame=CFrame.new(at);p.Transparency=1
    local s=Instance.new("Sound");s.SoundId=charge and "rbxasset://sounds/electronicpingshort.mp3" or "rbxasset://sounds/impact_generic.mp3";s.Volume=.55;s.PlaybackSpeed=charge and 1.7 or 1.2;s.RollOffMaxDistance=95;s.Parent=p;s:Play();Debris:AddItem(p,3)
end
function M.init(e)
    env=e;boot=part("KizaruRightBoot",Vector3.new(.26,.32,.62),e.viewmodel,Color3.fromRGB(40,37,29));boot.Material=Enum.Material.SmoothPlastic
    glow=part("LightCore",Vector3.one*.11,e.viewmodel,Color3.fromRGB(255,252,226));glow.Shape=Enum.PartType.Ball
    cross={part("LightCrossH",Vector3.new(.9,.018,.018),e.viewmodel),part("LightCrossV",Vector3.new(.018,.9,.018),e.viewmodel)};M.reset()
end
function M.reset() cast=nil;if boot then boot.Transparency=1;glow.Transparency=1;for _,p in cross do p.Transparency=1 end end end
function M.busy() return cast~=nil end
function M.onEvent(kind,d)
    local own=d.owner==Players.LocalPlayer.UserId
    if kind=="KizaruCast" then
        sound(d.position,true)
        if own then cast=d;env.announce(({LightLaser="손끝 레이저",LightKick="빛의 속도로 차여본 적 있나?",LightJewels="야사카니의 곡옥",LightMirror="야타의 거울"})[d.skill],({LightKick="빛을 모은다 → 광속 돌진 → 걷어차기",LightJewels="웅크렸다 → 높이 도약 → 공중 탄막 → 낙하"})[d.skill] or "빛을 모은다 → 순간 방출") end
    elseif kind=="KizaruEnd" and own then M.reset()
    elseif kind=="KizaruDash" then
        local dist=(d.to-d.from).Magnitude;if dist>.1 then
            local trail=part("KizaruDash",Vector3.new(.5,.5,dist),workspace);trail.CFrame=CFrame.lookAt((d.from+d.to)/2+Vector3.yAxis*1.3,d.to+Vector3.yAxis*1.3)
            Tween:Create(trail,TweenInfo.new(.4),{Transparency=1,Size=Vector3.new(.1,.1,dist)}):Play();Debris:AddItem(trail,.42)
        end
        sound(d.from,true)
    elseif kind=="KizaruKick" then
        local blast=part("KizaruKickBlast",Vector3.one*.5,workspace);blast.Shape=Enum.PartType.Ball;blast.Position=d.position+Vector3.yAxis*1.2
        Tween:Create(blast,TweenInfo.new(.4),{Size=Vector3.one*(d.hit and 12 or 6),Transparency=1}):Play();Debris:AddItem(blast,.45);sound(d.position,false)
    elseif kind=="KizaruRise" then
        local pillar=part("KizaruPillar",Vector3.new(.9,math.max(1,d.height),.9),workspace);pillar.CFrame=CFrame.new(d.position+Vector3.yAxis*d.height/2)
        Tween:Create(pillar,TweenInfo.new(.5),{Transparency=1,Size=Vector3.new(.1,math.max(1,d.height),.1)}):Play();Debris:AddItem(pillar,.52);sound(d.position,true)
    elseif kind=="KizaruLand" then
        local ringPart=part("KizaruLandRing",Vector3.new(1,.3,1),workspace);ringPart.Shape=Enum.PartType.Cylinder;ringPart.CFrame=CFrame.new(d.position+Vector3.yAxis*.2)*CFrame.Angles(0,0,math.pi/2)
        Tween:Create(ringPart,TweenInfo.new(.5),{Size=Vector3.new(.3,24,24),Transparency=1}):Play();Debris:AddItem(ringPart,.55);sound(d.position,false)
    elseif kind=="KizaruBeam" then
        local distance=math.max(.01,d.distance);local endPoint=d.position+d.direction*distance
        local beam=part("KizaruLight",Vector3.new(d.skill=="LightKick" and .4 or .12,.12,distance),workspace)
        beam.CFrame=CFrame.lookAt(d.position+d.direction*distance/2,endPoint)
        Tween:Create(beam,TweenInfo.new(.3),{Transparency=1}):Play();Debris:AddItem(beam,.32)
        local blast=part("LightImpact",Vector3.one*.3,workspace);blast.Shape=Enum.PartType.Ball;blast.Position=endPoint
        Tween:Create(blast,TweenInfo.new(.35),{Size=Vector3.one*(d.skill=="LightKick" and 6 or 2),Transparency=1}):Play();Debris:AddItem(blast,.4);sound(endPoint,false)
    end
end
function M.render(dt,selected,alive)
    if not selected or not alive then M.reset();return end
    if not cast then return end
    local a=now()-cast.start;local cfg=C[cast.skill];if a>=cfg.Duration then M.reset();return end
    local wind=smooth(a/cfg.Windup);local release=smooth((a-cfg.Windup)/.12);local back=smooth((a-cfg.Windup-.18)/(cfg.Duration-cfg.Windup-.18));local k=wind*(1-back)
    local cam=workspace.CurrentCamera;local l=CFrame.new(-.45,-.45,-.85);local r=CFrame.new(.28,-.3+.32*k,-.9-.22*k)*CFrame.Angles(-.35*k,0,.12)
    local core=CFrame.new(.28,.18*k,-1.15-.22*k);local fov=66
    boot.Transparency=1
    if cast.skill=="LightKick" then
        local dash=smooth((a-cfg.Windup)/.12);local sweep=smooth((a-cfg.Windup-.12)/.12);local rush=math.sin(math.pi*math.clamp((a-cfg.Windup)/.37,0,1));back=smooth((a-cfg.Windup-.42)/(cfg.Duration-cfg.Windup-.42))
        boot.Transparency=0;boot.CFrame=cam.CFrame*CFrame.new(.58-1.15*sweep,-1.1+.95*wind-.9*back,-.65-.6*wind)*CFrame.Angles(-.5*wind,.7-1.7*sweep,-.25+.65*wind-1.35*sweep)
        core=cam.CFrame:ToObjectSpace(boot.CFrame*CFrame.new(0,.05,-.32));r=CFrame.new(.65,-.28,-.65)*CFrame.Angles(.2,.2,.55)
        env.commonLook(CFrame.Angles(0,(.04*wind-.09*sweep)*(1-back),(.065*wind-.15*sweep)*(1-back)));fov=66-5*wind*(1-dash)+30*rush
    elseif cast.skill=="LightJewels" then
        l=CFrame.new(-.36,-.1+.16*k,-.86)*CFrame.Angles(.1,0,-.65);r=CFrame.new(.36,-.1+.16*k,-.86)*CFrame.Angles(.1,0,.65);core=CFrame.new(.36,.12,-.88);local up=math.clamp((a-cfg.Windup)/cfg.Rise,0,1);local dn=math.clamp((a-cfg.Hover)/cfg.Fall,0,1);k=wind*(1-dn);fov=66-7*k+12*math.sin(math.pi*up)+8*math.sin(math.pi*dn)
    elseif cast.skill=="LightMirror" then l=CFrame.new(-.24,-.22,-1);fov=66+25*release*(1-back) end
    glow.CFrame=cam.CFrame*core;glow.Transparency=1-k
    for _,p in cross do p.CFrame=cam.CFrame*core*CFrame.Angles(0,0,a*.5);p.Transparency=1-k end
    return {left=l,right=r,fov=fov}
end
return M
