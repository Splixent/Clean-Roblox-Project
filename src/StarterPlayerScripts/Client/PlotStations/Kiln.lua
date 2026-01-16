local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Client = Players.LocalPlayer.PlayerScripts.Client

local PlotStation = require(Shared.PlotStation)
local ProximityPromptHandler = require(Client.ProximityPromptHandler)
local SharedConstants = require(Shared.Constants)
local Events = require(Shared.Events)
local Maid = require(Shared.Maid)
local Replication = require(Client.Replication)
local ScriptUtils = require(Shared.ScriptUtils)

local KilnUI = require(Client.UI.Components.KilnUI.Functions)

local FirePottery = Events.FirePottery
local CollectKilnPottery = Events.CollectKilnPottery
local DeleteKilnPottery = Events.DeleteKilnPottery

local Kiln = {}
Kiln.__index = Kiln
setmetatable(Kiln, PlotStation)

function Kiln.new(player: Player, stationModel: Model)
    local self = PlotStation.new(player, stationModel)
    setmetatable(self, Kiln)
    
    -- Track if this client is the owner
    self.isOwner = self.ownerPlayer.UserId == self.player.UserId
    
    -- Maid for cleanup
    self.equippedItemMaid = Maid.new()
    self.replicaMaid = Maid.new()
    self.colorUpdateMaid = Maid.new()
    
    -- Store slot models
    self.slotModels = {}
    
    -- Only setup interaction for the owner
    if self.isOwner then
        self:SetupInteraction()
    end
    
    return self
end

-- Get level stats for this kiln
function Kiln:GetLevelStats()
    local level = tostring(self.data.level or 0)
    local stationInfo = SharedConstants.potteryStationInfo.Kiln
    if stationInfo and stationInfo.levelStats then
        return stationInfo.levelStats[level] or stationInfo.levelStats["0"]
    end
    return { maxSlots = 2, fireTimeMultiplier = 1.0 }
end

function Kiln:SetupInteraction()
    local interactPart = self.model:WaitForChild("ImportantObjects"):WaitForChild("StationRoot"):WaitForChild("Interact")
    
    -- Fire prompt - only visible when holding dried unfired pottery
    self.firePrompt = ProximityPromptHandler.new(interactPart, {
        actionText = "Fire Pottery",
        objectText = "Kiln (Lvl " .. self.data.level .. ")",
        priority = 1,
        onTriggered = function(player)
            self:OnFireTriggered(player)
        end,
    })
    
    -- View prompt - visible when there are items firing
    self.viewPrompt = ProximityPromptHandler.new(interactPart, {
        actionText = "View",
        objectText = "Kiln",
        simple = true,
        left = true,
        priority = 2,
        onTriggered = function(player)
            self:OnViewTriggered(player)
        end,
    })
    self.viewPrompt:SetEnabled(false)
    
    self.upgradePrompt = ProximityPromptHandler.new(interactPart, {
        actionText = "Upgrade",
        objectText = "Kiln (Lvl " .. self.data.level .. ")",
        simple = true,
        left = false,
        priority = 1,
        onTriggered = function(player)
            self:OnUpgradeTriggered(player)
        end,
    })
end

-- Check if the player is holding dried unfired pottery
function Kiln:IsHoldingDriedPottery(): boolean
    local states = Replication:GetInfo("States", true)
    if not states then return false end
    
    local equippedItem = states.Data.equippedItem
    if not equippedItem then return false end
    
    local itemName = equippedItem.itemName
    if not itemName then return false end
    
    local playerData = Replication:GetInfo("Data")
    if not playerData then return false end
    
    local inventory = playerData.inventory
    if not inventory or not inventory.items then return false end
    
    local itemInfo = inventory.items[itemName]
    if not itemInfo then return false end
    
    if not itemInfo.potteryStyle then return false end
    if itemInfo.fired then return false end
    if not itemInfo.dried then return false end
    
    return true
end

-- Get the station key for accessing replica data
function Kiln:GetStationKey(): string
    return `{self.ownerPlayer.UserId}_Kiln`
end

-- Deep copy a table
function Kiln:DeepCopy(original)
    if type(original) ~= "table" then return original end
    local copy = {}
    for k, v in pairs(original) do
        copy[k] = self:DeepCopy(v)
    end
    return copy
end

-- Get current kiln slots data from station replica
function Kiln:GetKilnSlotsData()
    local stationReplica = Replication.PotteryStations
    if not stationReplica then return {} end
    
    local stationKey = self:GetStationKey()
    local stationData = stationReplica.Data.activeStations[stationKey]
    
    if stationData and stationData.kilnSlots then
        return stationData.kilnSlots
    end
    
    return {}
end

-- Place a pottery model on a slot (client-side visual)
function Kiln:PlacePotteryModel(slotIndex: number, styleKey: string)
    local importantObjects = self.model:FindFirstChild("ImportantObjects")
    if not importantObjects then return end
    
    local stationRoot = importantObjects:FindFirstChild("StationRoot")
    if not stationRoot then return end
    
    local kilnLocation = stationRoot:FindFirstChild("KilnLocation_" .. slotIndex) or stationRoot:FindFirstChild("KilnLocation_0" .. slotIndex)
    if not kilnLocation then return end
    
    -- Get the pottery model template
    local potteryData = SharedConstants.pottteryData and SharedConstants.pottteryData[styleKey]
    if not potteryData then return end
    
    local modelName = potteryData.name or styleKey
    local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
    if not assetsFolder then return end
    
    local potteryStyles = assetsFolder:FindFirstChild("PotteryStyles")
    if not potteryStyles then return end
    
    local styleFolder = potteryStyles:FindFirstChild(modelName)
    if not styleFolder then return end
    
    local templateModel = styleFolder:FindFirstChild("Model")
    if not templateModel then return end
    
    -- Remove existing model if any
    self:RemovePotteryModel(slotIndex)
    
    -- Clone and position the model
    local potteryModel = templateModel:Clone()
    potteryModel.Name = "KilnPottery_" .. slotIndex
    potteryModel.Parent = self.model
    
    -- Position at kiln location
    local targetCFrame
    if kilnLocation:IsA("BasePart") then
        targetCFrame = kilnLocation.CFrame
    elseif kilnLocation:IsA("Attachment") then
        targetCFrame = kilnLocation.WorldCFrame
    else
        targetCFrame = self.model.PrimaryPart.CFrame
    end
    
    -- Check if the model has a Root with an Attachment for precise positioning
    local modelRoot = potteryModel:FindFirstChild("Root")
    if modelRoot then
        local modelAttachment = modelRoot:FindFirstChild("Attachment")
        if modelAttachment then
            local attachmentOffset = modelAttachment.CFrame
            potteryModel:PivotTo(targetCFrame * attachmentOffset:Inverse())
        else
            potteryModel:PivotTo(targetCFrame)
        end
    else
        potteryModel:PivotTo(targetCFrame)
    end
    
    self.slotModels[slotIndex] = potteryModel
end

-- Remove a pottery model from a slot
function Kiln:RemovePotteryModel(slotIndex: number)
    local existingModel = self.slotModels[slotIndex]
    if existingModel then
        existingModel:Destroy()
        self.slotModels[slotIndex] = nil
    end
    
    -- Also check for named model in parent
    local existingByName = self.model:FindFirstChild("KilnPottery_" .. slotIndex)
    if existingByName then
        existingByName:Destroy()
    end
end

-- Get the current color for a pottery model based on firing state
function Kiln:GetFiringColor(slotData): Color3
    local clayType = slotData.clayType
    if not clayType then
        local styleData = SharedConstants.pottteryData and SharedConstants.pottteryData[slotData.styleKey]
        clayType = styleData and styleData.clayType or "normal"
    end
    
    local clayTypeData = SharedConstants.clayTypes[clayType]
    if not clayTypeData then
        clayTypeData = SharedConstants.clayTypes.normal
    end
    
    -- If we have firing timing info, calculate duration and interpolate
    if slotData.startTime and slotData.styleKey then
        local levelStats = self:GetLevelStats()
        local fireTimeMultiplier = levelStats.fireTimeMultiplier or 1.0
        local firingDuration = ScriptUtils:CalculateFiringDuration(clayType, slotData.styleKey, fireTimeMultiplier)
        local firingProgress = ScriptUtils:GetFiringProgress(slotData.startTime, firingDuration)
        return ScriptUtils:GetFiringColor(clayType, firingProgress)
    end
    
    -- Default to dried color (pottery starts dried in kiln)
    return clayTypeData.driedColor or clayTypeData.color
end

-- Apply color to all mud parts in a pottery model
function Kiln:ApplyColorToModel(potteryModel: Model, color: Color3)
    if not potteryModel then return end
    
    for _, part in ipairs(potteryModel:GetDescendants()) do
        if part:IsA("BasePart") and part.Material == Enum.Material.Mud then
            part.Color = color
        end
    end
end

-- Update view prompt visibility based on whether there are items in kiln
function Kiln:UpdateViewPromptVisibility()
    local kilnSlots = self:GetKilnSlotsData()
    local hasItems = false
    
    for _, slotData in pairs(kilnSlots) do
        if slotData and slotData.styleKey then
            hasItems = true
            break
        end
    end
    
    if self.viewPrompt then
        self.viewPrompt:SetEnabled(hasItems)
    end
    
    -- Hide UI if no items
    if not hasItems and KilnUI:GetVisible() then
        KilnUI:Hide()
    end
end

-- Show the kiln UI
function Kiln:ShowKilnUI()
    local kilnSlots = self:GetKilnSlotsData()
    
    -- Build slot data for UI with timing info
    local uiSlotsData = {}
    
    for slotIndexStr, slotData in pairs(kilnSlots) do
        if slotData and slotData.styleKey then
            uiSlotsData[slotIndexStr] = {
                styleKey = slotData.styleKey,
                clayType = slotData.clayType,
                startTime = slotData.startTime or os.time(),
                endTime = slotData.endTime,
            }
        end
    end
    
    -- Get max slots and level from level stats
    local levelStats = self:GetLevelStats()
    local maxSlots = levelStats.maxSlots or 2
    local kilnLevel = self.data.level or 0
    
    -- Show the UI with maxSlots and level (UI is already parented in master ScreenGui)
    KilnUI:Show(uiSlotsData, maxSlots, kilnLevel,
        function(slotIndex) -- On collect callback (clicking the slot)
            if self.isOwner then
                self:OnCollectTriggered(self.player, slotIndex)
            end
        end,
        function(slotIndex) -- On delete callback (clicking X button)
            if self.isOwner then
                self:OnDeleteTriggered(self.player, slotIndex)
            end
        end,
        function() -- On close callback
            -- Nothing extra needed, UI handles cleanup
        end
    )
end

-- Handler for view prompt
function Kiln:OnViewTriggered(player: Player)
    if KilnUI:GetVisible() then
        KilnUI:Hide()
    else
        self:ShowKilnUI()
    end
end

-- Update kiln lights based on whether items are firing
function Kiln:UpdateLights()
    local hasItems = false
    local kilnSlots = self:GetKilnSlotsData()
    
    for _, slotData in pairs(kilnSlots) do
        if slotData and slotData.styleKey then
            hasItems = true
            break
        end
    end
    
    -- Update attribute for replication
    self.model:SetAttribute("HasFiringItems", hasItems)
    
    -- Find and toggle lights
    local importantObjects = self.model:FindFirstChild("ImportantObjects")
    if importantObjects then
        for _, descendant in ipairs(importantObjects:GetDescendants()) do
            if descendant:IsA("PointLight") or descendant:IsA("SpotLight") or descendant:IsA("SurfaceLight") then
                descendant.Enabled = hasItems
            end
        end
    end
end

-- Setup visuals - called by StationHandler after construction
function Kiln:SetupVisuals()
    self.replicaMaid:DoCleaning()
    
    -- Wait for replica to be available
    local stationReplica = Replication.PotteryStations
    if not stationReplica then return end
    
    local stationKey = self:GetStationKey()
    
    -- Initialize visuals from current data
    self:UpdateAllSlotVisuals()
    self:UpdateLights()
    
    -- Listen for attribute changes (for non-owner clients)
    self.replicaMaid:GiveTask(self.model:GetAttributeChangedSignal("HasFiringItems"):Connect(function()
        local hasItems = self.model:GetAttribute("HasFiringItems")
        local importantObjects = self.model:FindFirstChild("ImportantObjects")
        if importantObjects then
            for _, descendant in ipairs(importantObjects:GetDescendants()) do
                if descendant:IsA("PointLight") or descendant:IsA("SpotLight") or descendant:IsA("SurfaceLight") then
                    descendant.Enabled = hasItems
                end
            end
        end
    end))
    
    -- Track previous slots for change detection
    local previousSlots = self:DeepCopy(self:GetKilnSlotsData())
    
    -- Listen for any changes to the replica
    self.replicaMaid:GiveTask(stationReplica:OnChange(function(action, path, newValue, oldValue)
        local pathStr = table.concat(path, ".")
        
        -- Check if this change affects our station's kiln slots
        if path[1] == "activeStations" and path[2] == stationKey then
            if path[3] == "kilnSlots" then
                local currentSlots = self:GetKilnSlotsData()
                
                -- Check each slot for changes
                local levelStats = self:GetLevelStats()
                local maxSlots = levelStats.maxSlots or 2
                
                for i = 1, maxSlots do
                    local slotKeyStr = tostring(i)
                    local newData = currentSlots[slotKeyStr]
                    local oldData = previousSlots[slotKeyStr]
                    
                    local newStyleKey = newData and newData.styleKey
                    local oldStyleKey = oldData and oldData.styleKey
                    
                    if newStyleKey ~= oldStyleKey then
                        if newStyleKey then
                            -- Item added
                            self:PlacePotteryModel(i, newStyleKey)
                            self:UpdateSlotVisual(i)
                        else
                            -- Item removed
                            self:RemovePotteryModel(i)
                            self.colorUpdateMaid:GiveTask(function() end) -- Clear color update for this slot
                        end
                    end
                end
                
                -- Update tracked previous slots
                previousSlots = self:DeepCopy(currentSlots)
                
                -- Update view prompt visibility and lights
                self:UpdateViewPromptVisibility()
                self:UpdateLights()
                
                -- Refresh UI if open
                if KilnUI:GetVisible() then
                    self:ShowKilnUI()
                end
            end
        end
    end))
    
    -- Update view prompt visibility initially
    self:UpdateViewPromptVisibility()
end

-- Update all slot visuals
function Kiln:UpdateAllSlotVisuals()
    local kilnSlots = self:GetKilnSlotsData()
    local levelStats = self:GetLevelStats()
    local maxSlots = levelStats.maxSlots or 2
    
    for i = 1, maxSlots do
        local slotData = kilnSlots[tostring(i)]
        if slotData and slotData.styleKey then
            self:PlacePotteryModel(i, slotData.styleKey)
            self:UpdateSlotVisual(i)
        else
            self:RemovePotteryModel(i)
        end
    end
end

-- Update visual for a specific slot
function Kiln:UpdateSlotVisual(slotIndex: number)
    local slotData = self:GetKilnSlotsData()[tostring(slotIndex)]
    if not slotData then return end
    
    local potteryModel = self.slotModels[slotIndex]
    if not potteryModel then return end
    
    -- Apply initial color
    local color = self:GetFiringColor(slotData)
    self:ApplyColorToModel(potteryModel, color)
end

-- Handler for fire prompt
function Kiln:OnFireTriggered(player: Player)
    if not self:IsHoldingDriedPottery() then
        return
    end
    
    -- Get station ID
    local stationId = self.model:GetAttribute("StationId") or self.model.Name
    
    -- Call server event
    FirePottery:Call(stationId):After(function(passed, result)
        if not passed or not result then
            --warn("Kiln: FirePottery call failed")
            return
        end
        
        if result.success then
        else
            --warn("Kiln: Failed to fire pottery -", result.error)
        end
    end)
end

-- Handler for collect
function Kiln:OnCollectTriggered(player: Player, slotIndex: number)
    local stationId = self.model:GetAttribute("StationId") or self.model.Name
    
    CollectKilnPottery:Call(stationId, slotIndex):After(function(passed, result)
        if not passed or not result then
            --warn("Kiln: CollectKilnPottery call failed")
            return
        end
        
        if result.success then
            -- Refresh the UI after collection completes
            task.defer(function()
                if KilnUI:GetVisible() then
                    self:ShowKilnUI()
                end
            end)
        else
            --warn("Kiln: Failed to collect pottery -", result.error)
        end
    end)
end

-- Handler for delete
function Kiln:OnDeleteTriggered(player: Player, slotIndex: number)
    local stationId = self.model:GetAttribute("StationId") or self.model.Name
    
    DeleteKilnPottery:Call(stationId, slotIndex):After(function(passed, result)
        if not passed or not result then
            --warn("Kiln: DeleteKilnPottery call failed")
            return
        end
        
        if result.success then
            -- Refresh the UI after deletion completes
            task.defer(function()
                if KilnUI:GetVisible() then
                    self:ShowKilnUI()
                end
            end)
        else
            --warn("Kiln: Failed to delete pottery -", result.error)
        end
    end)
end

function Kiln:OnUpgradeTriggered(player: Player)
end

function Kiln:Destroy()
    if self.firePrompt then
        self.firePrompt:Destroy()
    end
    if self.viewPrompt then
        self.viewPrompt:Destroy()
    end
    if self.upgradePrompt then
        self.upgradePrompt:Destroy()
    end
    
    self.equippedItemMaid:DoCleaning()
    self.replicaMaid:DoCleaning()
    self.colorUpdateMaid:DoCleaning()
    
    -- Clean up slot models
    for slotIndex, _ in pairs(self.slotModels) do
        self:RemovePotteryModel(slotIndex)
    end
end

return Kiln
