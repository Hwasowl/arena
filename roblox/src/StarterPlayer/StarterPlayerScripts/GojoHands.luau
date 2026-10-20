-- Gojo and Zenitsu: plain black sleeves and skin-colored block hands, without fingers.
-- Wrist origin, +Y toward fingertips, palm toward -Z. All geometry is display-only.
local Hands={}
local arms={}
local function smooth(x) x=math.clamp(x,0,1);return x*x*(3-2*x) end
local function handFrame(at,fingers,palm)
    local y=fingers.Unit;local z=-(palm-y*palm:Dot(y))
    if z.Magnitude<.01 then z=Vector3.zAxis end
    z=z.Unit;return CFrame.fromMatrix(at,y:Cross(z).Unit,y,z)
end
local function part(a,name,size,shape)
    local p=Instance.new("Part");p.Name=name;p.Size=size;p.Shape=shape or Enum.PartType.Block
    p.Material=Enum.Material.SmoothPlastic;p.Anchored=true;p.Massless=true
    p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
    p.CollisionGroup=a.group;p.Transparency=1;p.Parent=a.model
    table.insert(a.parts,p);return p
end
local function build(parent,side,group)
    local model=Instance.new("Model");model.Name=side==1 and "GojoRightHandRig" or "GojoLeftHandRig"
    local a={model=model,side=side,thumbSide=-side,group=group,parts={}}
    a.sleeve=part(a,"BlackSleeve",Vector3.new(.215,.70,.19))
    a.palm=part(a,"Palm",Vector3.new(.215,.205,.19))
    model.Parent=parent;return a
end
function Hands.init(parent,group)
    for _,a in arms do a.model:Destroy() end
    arms={left=build(parent,-1,group),right=build(parent,1,group)}
end
function Hands.reset()
    for _,a in arms do
        for _,p in a.parts do p.Transparency=1 end
        a.initialized=false
    end
end
local function draw(a,frame,curls,spread,cross,skin,dt)
    local alpha=1-math.exp(-dt*24)
    if not a.initialized then a.frame=frame;a.initialized=true end
    a.frame=a.frame:Lerp(frame,alpha)
    local camera=workspace.CurrentCamera
    local world=camera.CFrame*a.frame
    local function put(p,cf,color) p.CFrame=cf;p.Color=color;p.Transparency=0 end
    a.sleeve.Size=Vector3.new(.215,.70,.19)
    local sleeve=world*CFrame.new(0,-.3505,0)
    if a.shoulder then
        -- The forearm reaches toward its own shoulder, independent of the sword/wrist roll.
        local shoulder=camera.CFrame:PointToWorldSpace(a.shoulder)
        local length=(shoulder-world.Position).Magnitude
        local direction=(shoulder-world.Position).Unit
        a.sleeve.Size=Vector3.new(.215,math.max(.12,length),.19)
        local rotation=world.Rotation
        sleeve=CFrame.new((world.Position+shoulder)/2)*rotation
    end
    put(a.sleeve,sleeve,Color3.fromRGB(13,14,20))
    put(a.palm,world*CFrame.new(0,.102,0),skin)
end
local function relaxed(side)
    return handFrame(Vector3.new(side*.39,-.50,-.94),Vector3.new(-side*.18,.8,-.5),Vector3.new(-side*.8,.05,-.45))
end
function Hands.render(dt,info)
    if not arms.right then return end
    if not info.active or not info.alive then Hands.reset();return end
    if info.kit=="Zenitsu" and info.hilt and info.saya then
        -- Block hands share the forearm axis. Their centers, not finger-era wrist
        -- offsets, are locked to the handle and the scabbard mouth.
        arms.left.shoulder=Vector3.new(-.56,-.85,.18)
        arms.right.shoulder=Vector3.new(.56,-.85,.18)
        local k=math.clamp(info.twoHand or 0,0,1)
        local function grip(center,shoulder,palm)
            local up=(center-shoulder).Unit
            return handFrame(center-up*.102,up,Vector3.new(0,0,-1))
        end
        -- Block wrists retain a stable roll throughout the transfer. The right hand
        -- makes room for the left hand on the lower portion of the handle.
        local rightCenter=(info.hilt*CFrame.new(0,0,-.24+.12*k)).Position
        local scabbardCenter=(info.saya*CFrame.new(0,0,.10)).Position
        local supportCenter=(info.hilt*CFrame.new(0,0,-.40)).Position
        local r=grip(rightCenter,arms.right.shoulder,-info.hilt.RightVector)
        local palm=info.saya.RightVector:Lerp(info.hilt.RightVector,k)
        if palm.Magnitude<.01 then palm=info.hilt.RightVector end
        local l=grip(scabbardCenter:Lerp(supportCenter,k),arms.left.shoulder,palm)
        local skin=Color3.fromRGB(235,190,162)
        -- Match the weapon exactly, including the fastest slash, instead of lagging behind it.
        draw(arms.left,l,{.95,1,1.03,1.06,.8},.05,0,skin,1)
        draw(arms.right,r,{.95,1,1.03,1.06,.8},.05,0,skin,1)
        return {left=l,right=r}
    end
    arms.left.shoulder=nil;arms.right.shoulder=nil
    local n=workspace:GetServerTimeNow()
    local l,r=relaxed(-1),relaxed(1)
    local lc,rc={.25,.32,.42,.48,.3},{.25,.32,.42,.48,.3}
    local ls,rs,cross=.45,.45,0
    local cast,hold,melee=info.cast,info.hold,info.melee
    if hold then
        local raise=smooth((n-hold.start)/.25)
        if hold.kind=="Blue" then
            r=handFrame(Vector3.new(.34,-.57,-1.05),Vector3.new(-.1,.8,-.6),Vector3.new(-.3,.1,-1))
            rc={.18,.68,.7,.78,.68};rs=.2
        else
            r=r:Lerp(handFrame(Vector3.new(.28,-.28,-.93),Vector3.new(-.1,.9,-.4),Vector3.new(-.4,.05,-1)),raise)
            rc={.03,.88,.94,.98,.52};rs=.05
        end
    end
    if cast then
        local age=n-cast.start
        if cast.kind=="Blue" then
            local snap=smooth((age-.25)/.12)
            r=handFrame(info.right.Position,Vector3.new(-.1,.8,-.6),Vector3.new(-.3,.1,-1))
            rc={.16,.8*(1-snap),.84,.9,.72-.35*snap};rs=.12
        elseif cast.kind=="Red" then
            r=handFrame(info.right.Position,Vector3.new(-.05,.13,-1),Vector3.new(-.1,-1,-.1))
            rc={.015,.92,.96,1,.55};rs=.05
            if cast.fired then r*=CFrame.Angles(-.08*math.exp(-(n-cast.fireAt)*8),0,0) end
        elseif cast.kind=="Purple" then
            local merged=smooth((age-2.5)/.5)
            l=handFrame(info.left.Position,Vector3.new(.25,.5,-.85),Vector3.new(.9,.1,-.35))
            r=handFrame(info.right.Position,Vector3.new(-.25,.5,-.85),Vector3.new(-.9,.1,-.35))
            lc={.25,.3,.45,.5,.45};rc={.28*(1-merged),.3*(1-merged),.5+.3*merged,.6+.3*merged,.5}
            ls=.6;rs=.45*(1-merged)
            if cast.fired then
                r=handFrame(info.right.Position,Vector3.new(-.1,.2,-1),Vector3.new(-.1,-1,-.1))
                rc={.015,.03,.78,.88,.4};rs=.1
            end
        elseif cast.kind=="Domain" then
            local raise=smooth(age/.7)
            l=l:Lerp(handFrame(Vector3.new(-.17,-.48-.035*smooth((age-.4)/.3),-.72),Vector3.new(.35,.94,-.08),Vector3.new(.15,.05,-1)),raise)
            r=r:Lerp(handFrame(Vector3.new(.21,-.30,-.85),Vector3.new(-.13,1,-.03),Vector3.new(0,0,-1)),raise)
            lc={.48,.65,.82,.9,.78}
            rc={.015,.045,.25+.7*smooth((age-.18)/.3),.3+.7*smooth((age-.25)/.3),.75}
            cross=smooth((age-.35)/.35);ls=.1;rs=0
        end
    end
    if melee then
        local age=n-melee.start;local close=smooth(age/math.min(.12,melee.windup))
        local sign=melee.combo%2==0 and -1 or 1
        local f=handFrame((sign==1 and info.right or info.left).Position,Vector3.new(-sign*.1,.2,-1),Vector3.new(-sign*.6,-.8,0))
        local curl=.35+.65*close
        if sign==1 then r=f;rc={curl,curl,curl,curl,.85};lc={.7,.7,.75,.8,.6}
        else l=f;lc={curl,curl,curl,curl,.85};rc={.7,.7,.75,.8,.6} end
        ls=.02;rs=.02
    elseif info.sliding then
        l=handFrame(info.left.Position,Vector3.new(.2,.4,-.8),Vector3.new(.5,-.7,-.2))
        r=handFrame(info.right.Position,Vector3.new(-.2,.4,-.8),Vector3.new(-.5,-.7,-.2))
        lc={.55,.6,.65,.7,.5};rc=table.clone(lc)
    end
    if not cast and not hold and not melee and not info.sliding then
        -- Relaxed framing leaves the center open; the right hand sits slightly higher.
        l=handFrame(Vector3.new(-.61,-.60,-1.03),Vector3.new(.08,.88,-.28),Vector3.new(.45,0,-.85))
        r=handFrame(Vector3.new(.61,-.57,-1.03),Vector3.new(-.08,.88,-.28),Vector3.new(-.45,0,-.85))
    end
    local skin=Color3.fromRGB(235,190,162)
    draw(arms.left,l,lc,ls,0,skin,dt)
    draw(arms.right,r,rc,rs,cross,skin,dt)
    local left,right=arms.left.frame,arms.right.frame
    -- The charge sphere floats above the visible block hand, with a gap.
    local focus=(right*CFrame.new(0,.205,0)).Position+Vector3.new(0,.14,0)
    return {left=left,right=right,focus=focus,seal=(right*CFrame.new(-.028,.31,-.02)).Position}
end
return Hands
