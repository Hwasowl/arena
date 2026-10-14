-- Optional Creator Store decoration. The game also runs when permissions prevent loading.
-- Only ParticleEmitter data is copied; imported scripts are never parented to the DataModel.
local InsertService=game:GetService("InsertService")
local RS=game:GetService("ReplicatedStorage")
local templates=Instance.new("Folder");templates.Name="StoreVFX";templates.Parent=RS
local ASSET_ID=17879749515 -- Red and Blue VFX Gojo !, @XxMurder_ProgamexX
task.spawn(function()
    local ok,model=pcall(function() return InsertService:LoadAsset(ASSET_ID) end)
    if not ok then
        templates:SetAttribute("Status","Permission unavailable; procedural fallback")
        warn("Creator Store VFX not loaded. Open this place with the account that acquired asset "..ASSET_ID)
        return
    end
    -- model remains unparented throughout inspection.
    for _,v in model:GetDescendants() do if v:IsA("LuaSourceContainer") then v:Destroy() end end
    local count=0
    for _,v in model:GetDescendants() do
        if v:IsA("ParticleEmitter") and count<8 then
            count+=1
            local copy=v:Clone()
            for _,child in copy:GetChildren() do child:Destroy() end
            copy.Name="StoreParticle"..count
            copy.Enabled=false;copy.Rate=math.min(copy.Rate,30)
            copy.Lifetime=NumberRange.new(math.min(copy.Lifetime.Min,1),math.min(copy.Lifetime.Max,1.6))
            copy.Speed=NumberRange.new(math.min(copy.Speed.Min,10),math.min(copy.Speed.Max,16))
            copy.Parent=templates
        end
    end
    model:Destroy()
    templates:SetAttribute("Status",count>0 and "Loaded" or "No particle emitters; procedural fallback")
    templates:SetAttribute("SourceAssetId",ASSET_ID)
end)
