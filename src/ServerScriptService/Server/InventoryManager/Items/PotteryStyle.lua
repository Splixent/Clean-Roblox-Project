--[[
    PotteryStyle Item - Server-side Pottery item behavior
    Works for any pottery style - gets tool model from Assets.PotteryStyles[styleName].Tool
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Server = ServerScriptService.Server

local BaseItem = require(script.Parent.BaseItem)
local SharedConstants = require(Shared.Constants)
local ScriptUtils = require(Shared.ScriptUtils)
local DataObject = require(Server.Datastore.DataObject)

local PotteryStyle = {}
PotteryStyle.__index = PotteryStyle
setmetatable(PotteryStyle, BaseItem)

-- Extract the actual style key from a unique pottery key (e.g., "bowl_1" -> "bowl")
local function getStyleKey(itemName: string): string
    local styleKey = itemName:match("^(.+)_%d+$")
    if styleKey and SharedConstants.pottteryData and SharedConstants.pottteryData[styleKey] then
        return styleKey
    end
    return itemName
end

function PotteryStyle.new(player: Player, uniqueKey: string)
    local self = setmetatable(BaseItem.new(player, uniqueKey), PotteryStyle)
    
    -- Extract the actual style key from the unique key
    self.UniqueKey = uniqueKey
    self.StyleKey = getStyleKey(uniqueKey)
    self.StyleData = SharedConstants.pottteryData and SharedConstants.pottteryData[self.StyleKey]
    
    return self
end

-- Get the item info from the player's inventory
function PotteryStyle:GetItemInfo()
    local playerData = DataObject.new(self.Player, true)
    if not playerData or not playerData.Replica or not playerData.Replica.Data then
        return nil
    end
    
    local inventory = playerData.Replica.Data.inventory
    if not inventory or not inventory.items then
        return nil
    end
    
    return inventory.items[self.UniqueKey]
end

-- Get the appropriate color based on pottery state
function PotteryStyle:GetCurrentColor()
    local itemInfo = self:GetItemInfo()
    
    -- Check for glaze color first
    if itemInfo and itemInfo.glaze and itemInfo.glaze.color then
        -- Get the glaze color from SharedConstants
        for _, colorData in ipairs(SharedConstants.glazeTypes.colors) do
            if colorData.name == itemInfo.glaze.color then
                return colorData.color
            end
        end
    end
    
    -- Get clay type from item info (preferred) or style data (fallback)
    local clayType = (itemInfo and itemInfo.clayType) or (self.StyleData and self.StyleData.clayType)
    if not clayType then
        return Color3.new(0.5, 0.4, 0.3) -- Default brown color
    end
    
    local clayTypeData = SharedConstants.clayTypes[clayType]
    if not clayTypeData then
        return Color3.new(0.5, 0.4, 0.3)
    end
    
    if not itemInfo then
        return clayTypeData.color
    end
    
    -- Return color based on pottery state progression
    if itemInfo.cooled then
        -- Fully processed: cooledColor
        return clayTypeData.cooledColor or clayTypeData.firedColor or clayTypeData.driedColor or clayTypeData.color
    elseif itemInfo.fired then
        -- Fired but not cooled: firedColor
        return clayTypeData.firedColor or clayTypeData.driedColor or clayTypeData.color
    elseif itemInfo.dried then
        -- Dried but not fired: driedColor
        return clayTypeData.driedColor or clayTypeData.color
    end
    
    -- Not dried yet - use base color (drying only happens on CoolingTable)
    return clayTypeData.color
end

-- Get SurfaceAppearance for pattern + finish from Assets/Glazes
function PotteryStyle:GetSurfaceAppearance(pattern: string?, finish: string?): SurfaceAppearance?
    local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
    if not assetsFolder then return nil end
    
    local glazesFolder = assetsFolder:FindFirstChild("Glazes")
    if not glazesFolder then return nil end
    
    -- Check style-unique patterns first
    if pattern and pattern ~= "noPattern" then
        local styleUniqueFolder = glazesFolder:FindFirstChild("StyleUniquePatterns")
        if styleUniqueFolder then
            local styleFolder = styleUniqueFolder:FindFirstChild(self.StyleKey)
            if styleFolder then
                local patternFolder = styleFolder:FindFirstChild(pattern)
                if patternFolder and finish then
                    local finishName = finish:sub(1,1):upper() .. finish:sub(2)
                    local sa = patternFolder:FindFirstChild(finishName)
                    if sa then return sa end
                end
            end
        end
    end
    
    -- No pattern - check for finish only
    if not pattern or pattern == "noPattern" then
        if not finish then return nil end
        
        local noPatternFolder = glazesFolder:FindFirstChild("noPattern")
        if not noPatternFolder then return nil end
        
        local finishName = finish:sub(1,1):upper() .. finish:sub(2)
        return noPatternFolder:FindFirstChild(finishName)
    end
    
    -- Regular pattern folder
    local patternFolder = glazesFolder:FindFirstChild(pattern)
    if not patternFolder then return nil end
    
    if not finish then return nil end
    
    local finishName = finish:sub(1,1):upper() .. finish:sub(2)
    return patternFolder:FindFirstChild(finishName)
end

-- Apply surface appearance to a part
function PotteryStyle:ApplySurfaceAppearance(basePart: BasePart, surfaceAppearance: SurfaceAppearance?)
    -- Remove existing surface appearances
    for _, child in ipairs(basePart:GetChildren()) do
        if child:IsA("SurfaceAppearance") then
            child:Destroy()
        end
    end
    
    -- Add new surface appearance if provided
    if surfaceAppearance then
        local clone = surfaceAppearance:Clone()
        clone.Parent = basePart
    end
end

function PotteryStyle:ColorizeToolModel(tool: Tool)
    local currentColor = self:GetCurrentColor()
    local itemInfo = self:GetItemInfo()
    
    -- Get pattern and finish from glaze data
    local pattern = itemInfo and itemInfo.glaze and itemInfo.glaze.pattern
    local finish = itemInfo and itemInfo.glaze and itemInfo.glaze.finish
    
    -- Get the surface appearance for this pattern/finish combo
    local surfaceAppearance = self:GetSurfaceAppearance(pattern, finish)
    
	for _, basePart in ipairs(tool:GetDescendants()) do
		if basePart:IsA("BasePart") and basePart.Material == Enum.Material.Mud then
			basePart.Color = currentColor
            self:ApplySurfaceAppearance(basePart, surfaceAppearance)
		end
	end
end

-- Override GetToolModel to get from PotteryStyles instead of HeldItems
function PotteryStyle:GetToolModel()
    local potteryStyles = ReplicatedStorage.Assets.PotteryStyles
    if not potteryStyles then 
        warn("[PotteryStyle] PotteryStyles folder not found in ReplicatedStorage")
        return nil 
    end
    
    -- Get the model name from style data, or capitalize the styleKey as fallback
    local modelName = self.StyleData and self.StyleData.model
    if not modelName then
        -- Capitalize first letter of styleKey (e.g., "bowl" -> "Bowl")
        modelName = self.StyleKey:sub(1,1):upper() .. self.StyleKey:sub(2)
    end
    
    local styleFolder = potteryStyles:FindFirstChild(modelName)
    if not styleFolder then 
        warn(`[PotteryStyle] Style folder '{modelName}' not found in PotteryStyles`)
        return nil 
    end
    
    local tool = styleFolder:FindFirstChild("Tool")
    if not tool then
        warn(`[PotteryStyle] Tool not found in PotteryStyles/{modelName}`)
    end
    
    self:ColorizeToolModel(tool)

    return tool
end

-- Update the tool's color and surface appearance based on glaze data
function PotteryStyle:UpdateToolColor()
    if not self.Tool then return end
    
    local currentColor = self:GetCurrentColor()
    local itemInfo = self:GetItemInfo()
    
    -- Get pattern and finish from glaze data
    local pattern = itemInfo and itemInfo.glaze and itemInfo.glaze.pattern
    local finish = itemInfo and itemInfo.glaze and itemInfo.glaze.finish
    
    -- Get the surface appearance for this pattern/finish combo
    local surfaceAppearance = self:GetSurfaceAppearance(pattern, finish)
    
    for _, basePart in ipairs(self.Tool:GetDescendants()) do
        if basePart:IsA("BasePart") and basePart.Material == Enum.Material.Mud then
            basePart.Color = currentColor
            self:ApplySurfaceAppearance(basePart, surfaceAppearance)
        end
    end
end

-- Check if drying is still in progress (only relevant on CoolingTable now)
function PotteryStyle:IsDrying()
    -- Drying only happens on CoolingTable, not when held
    return false
end

function PotteryStyle:OnEquip()
    local displayName = self.StyleData and self.StyleData.name or self.StyleKey
    
    -- Start color update loop if pottery is drying
    if self:IsDrying() then
        self.DryingUpdateConnection = true
        task.spawn(function()
            while self.DryingUpdateConnection and self.IsEquipped do
                self:UpdateToolColor()
                
                -- Check if drying is complete
                if not self:IsDrying() then
                    break
                end
                
                -- Update every 0.5 seconds for smooth color transition
                task.wait(0.5)
            end
        end)
    end
end

function PotteryStyle:OnUnequip()
    local displayName = self.StyleData and self.StyleData.name or self.StyleKey
    
    -- Stop the color update loop
    self.DryingUpdateConnection = nil
end

function PotteryStyle:OnActivate()
    local displayName = self.StyleData and self.StyleData.name or self.StyleKey
end

return PotteryStyle
