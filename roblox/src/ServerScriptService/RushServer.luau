-- Shared physical rush: the owner's physics follows a moving target instead of teleporting.
local RunService=game:GetService("RunService")
local Debris=game:GetService("Debris")
local Rush={}
local active={}
local function horizontal(v) return v*Vector3.new(1,0,1) end
local function worldParams(model)
    local list={model}
    for _,m in workspace:GetChildren() do
        if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") then table.insert(list,m) end
    end
    local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances=list;params.RespectCanCollide=true
    return params
end
local function finish(d,completed,carry)
    if active[d.root]~=d then return end
    active[d.root]=nil;d.align:Destroy();d.attachment:Destroy()
    if d.humanoid.Parent then d.humanoid.AutoRotate=d.autoRotate end
    if d.model.Parent then d.model:SetAttribute("RushingUntil",0) end
    if d.root.Parent then
        local velocity=d.root.AssemblyLinearVelocity
        local walking=completed and d.humanoid.MoveDirection*d.walkSpeed or Vector3.zero
        if carry then
            walking=horizontal(velocity)
            if walking.Magnitude>38 then walking=walking.Unit*38 end
        end
        d.root.AssemblyLinearVelocity=Vector3.new(walking.X,velocity.Y,walking.Z)
    end
    if d.options.ended then d.options.ended(completed) end
    if completed and d.options.complete then d.options.complete(d.from,d.root.Position,d) end
end
function Rush.cancel(root,carry)
    local d=active[root];if d then finish(d,false,carry) end
end
function Rush.isActive(root) return active[root]~=nil end
function Rush.start(player,model,humanoid,root,direction,distance,duration,options)
    Rush.cancel(root);options=options or {}
    local flat=horizontal(direction)
    if flat.Magnitude<.01 then flat=horizontal(root.CFrame.LookVector) end
    if flat.Magnitude<.01 then flat=Vector3.new(0,0,-1) end
    flat=flat.Unit
    local params=worldParams(model)
    local hit=distance>.01 and workspace:Blockcast(root.CFrame,Vector3.new(2.4,4,2.4),flat*distance,params)
    local travel=hit and math.max(0,hit.Distance-.65) or distance
    -- A grounded rush must not run beyond the floor or across an unsupported drop.
    if root.AssemblyLinearVelocity.Y<=2 then
        local depth=humanoid.HipHeight+root.Size.Y*.5+3
        local floor=workspace:Raycast(root.Position+Vector3.yAxis, -Vector3.yAxis*depth,params)
        if floor and root.Position.Y-floor.Position.Y<=humanoid.HipHeight+root.Size.Y*.5+.9 then
            for sample=1.5,travel+1.5,1.5 do
                local distance=math.min(sample,travel)
                local under=workspace:Raycast(root.Position+flat*distance+Vector3.yAxis,-Vector3.yAxis*depth,params)
                if not under or math.abs(under.Position.Y-floor.Position.Y)>2 then
                    travel=math.max(0,distance-2);break
                end
            end
        end
    end
    local attachment=Instance.new("Attachment");attachment.Name="RushAttachment";attachment.Parent=root
    local align=Instance.new("AlignPosition");align.Name="RushDrive"
    align.Mode=Enum.PositionAlignmentMode.OneAttachment;align.Attachment0=attachment
    align.ApplyAtCenterOfMass=true;align.RigidityEnabled=false;align.Responsiveness=100
    align.ForceLimitMode=Enum.ForceLimitMode.PerAxis
    align.MaxAxesForce=Vector3.new(1,0,1)*math.max(40000,root.AssemblyMass*12000)
    align.MaxVelocity=math.max(1,travel/duration*1.8);align.Position=root.Position;align.Parent=root
    local d={player=player,model=model,humanoid=humanoid,root=root,from=root.Position,last=root.Position,
        to=root.Position+flat*travel,direction=flat,distance=travel,duration=duration,start=workspace:GetServerTimeNow(),
        attachment=attachment,align=align,params=params,options=options,autoRotate=humanoid.AutoRotate,walkSpeed=options.walkSpeed or humanoid.WalkSpeed}
    active[root]=d;humanoid.AutoRotate=false
    model:SetAttribute("RushingUntil",d.start+duration+.25)
    Debris:AddItem(align,duration+.5);Debris:AddItem(attachment,duration+.5)
    return d
end
RunService.Heartbeat:Connect(function()
    local n=workspace:GetServerTimeNow()
    for _,d in active do
        if not d.root.Parent or not d.model.Parent or d.player.Character~=d.model or d.humanoid.Health<=0
            or (d.options.valid and not d.options.valid()) then
            finish(d,false)
        else
            local pos=d.root.Position
            if d.options.step then d.options.step(d.last,pos,d) end
            d.last=pos
            local u=math.clamp((n-d.start)/d.duration,0,1)
            -- Accelerate, cross the full path, then brake into the final stance.
            local eased=u*u*(3-2*u)
            local wanted=d.from+d.direction*d.distance*eased
            local step=horizontal(wanted-pos)
            local wall=step.Magnitude>.01 and workspace:Blockcast(d.root.CFrame,Vector3.new(2.4,4,2.4),step,d.params)
            if wall then
                d.align.Position=pos
                finish(d,true)
            else
                d.align.Position=Vector3.new(wanted.X,pos.Y,wanted.Z)
                if (u>=1 and horizontal(pos-d.to).Magnitude<.45) or n-d.start>=d.duration+.15 then finish(d,true) end
            end
        end
    end
end)
return Rush
