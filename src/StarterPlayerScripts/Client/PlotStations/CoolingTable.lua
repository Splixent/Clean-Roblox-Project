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

local CoolingTableUI = require(Client.UI.Components.CoolingTableUI.Functions)

local CoolPottery = Events.CoolPottery
local CollectPottery = Events.CollectPottery
local DeletePottery = Events.DeletePottery

local CoolingTable = {}
CoolingTable.__index = CoolingTable
setmetatable(CoolingTable, PlotStation)

function CoolingTable.new(player: Player, stationModel: Model)
    local self = PlotStation.new(player, stationModel)
    setmetatable(self, CoolingTable)
    
    -- Track if this client is the owner
    self.isOwner = self.ownerPlayer.UserId == self.player.UserId
    
    -- Maid for cleanup
    self.equippedItemMaid = Maid.new()
    self.replicaMaid = Maid.new()
    self.colorUpdateMaid = Maid.new() -- For color update loops
    
    -- Store slot models
    self.slotModels = {}
    self.slotDryingData = {} -- Store drying data for each slot
    
    -- Only setup interaction for the owner
    if self.isOwner then
        self:SetupInteraction()
    end
    
    return self
end

-- Get level stats for this cooling table
function CoolingTable:GetLevelStats()
    local level = tostring(self.data.level or 0)
    local stationInfo = SharedConstants.potteryStationInfo.CoolingTable
    if stationInfo and stationInfo.levelStats then
        return stationInfo.levelStats[level] or stationInfo.levelStats["0"]
    end
    return { maxSlots = 4, dryTimeMultiplier = 1.0, coolTimeMultiplier = 1.0 }
end

function CoolingTable:SetupInteraction()
    local interactPart = self.model:WaitForChild("ImportantObjects"):WaitForChild("StationRoot"):WaitForChild("Interact")
    
    -- Cool prompt - only visible when holding unfired pottery
    self.coolPrompt = ProximityPromptHandler.new(interactPart, {
        actionText = "Cool Pottery",
        objectText = "Cooling Table (Lvl " .. self.data.level .. ")",
        priority = 1,
        onTriggered = function(player)
            self:OnCoolTriggered(player)
        end,
    })
    
    -- View prompt - visible when there are items cooling
    self.viewPrompt = ProximityPromptHandler.new(interactPart, {
        actionText = "View",
        objectText = "Cooling Table",
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
        objectText = "Cooling Table (Lvl " .. self.data.level .. ")",
        simple = true,
        left = false,
        priority = 1,
        onTriggered = function(player)
            self:OnUpgradeTriggered(player)
        end,
    })
end

-- Check if the player is holding unfired pottery
function CoolingTable:IsHoldingUnfiredPottery(): boolean
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
    if itemInfo.cooled then return false end -- Only reject already cooled pottery
    
    return true
end

-- Update prompt visibility based on held item

-- Get the station key for accessing replica data
function CoolingTable:GetStationKey(): string
    return `{self.ownerPlayer.UserId}_CoolingTable`
end

-- Deep copy a table
function CoolingTable:DeepCopy(original)
    if type(original) ~= "table" then return original end
    local copy = {}
    for k, v in pairs(original) do
        copy[k] = self:DeepCopy(v)
    end
    return copy
end

-- Get current cooling slots data from station replica
function CoolingTable:GetCoolingSlotsData()
    local stationReplica = Replication.PotteryStations
    if not stationReplica then return {} end
    
    local stationKey = self:GetStationKey()
    local stationData = stationReplica.Data.activeStations[stationKey]
    
    if stationData and stationData.coolingSlots then
        return stationData.coolingSlots
    end
    
    return {}
end

-- Place a pottery model on a slot (client-side visual)
function CoolingTable:PlacePotteryModel(slotIndex: number, styleKey: string)
    local importantObjects = self.model:FindFirstChild("ImportantObjects")
    if not importantObjects then 
        --warn("CoolingTable Client: ImportantObjects not found")
        return 
    end
    
    local stationRoot = importantObjects:FindFirstChild("StationRoot")
    if not stationRoot then 
        --warn("CoolingTable Client: StationRoot not found")
        return 
    end
    
    local coolingLocation = stationRoot:FindFirstChild("CoolingLocation_" .. slotIndex)
    if not coolingLocation then 
        --warn("CoolingTable Client: CoolingLocation_" .. slotIndex .. " not found")
        return 
    end
    
    -- Get the pottery model template
    local potteryData = SharedConstants.pottteryData and SharedConstants.pottteryData[styleKey]
    if not potteryData then 
        --warn("CoolingTable Client: potteryData not found for", styleKey)
        return 
    end
    
    local modelName = potteryData.name or styleKey
    local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
    if not assetsFolder then 
        --warn("CoolingTable Client: Assets folder not found")
        return 
    end
    
    local potteryStyles = assetsFolder:FindFirstChild("PotteryStyles")
    if not potteryStyles then 
        --warn("CoolingTable Client: PotteryStyles folder not found")
        return 
    end
    
    local styleFolder = potteryStyles:FindFirstChild(modelName)
    if not styleFolder then 
        --warn("CoolingTable Client: Style folder '" .. modelName .. "' not found")
        return 
    end
    
    local templateModel = styleFolder:FindFirstChild("Model")
    if not templateModel then 
        --warn("CoolingTable Client: Model not found in style folder")
        return 
    end
    
    -- Remove existing model if any
    self:RemovePotteryModel(slotIndex)
    
    -- Clone and position the model
    local potteryModel = templateModel:Clone()
    potteryModel.Name = "CoolingPottery_" .. slotIndex
    potteryModel.Parent = self.model
    
    -- Position at cooling location using attachment offset (like PottersWheel)
    local targetCFrame
    if coolingLocation:IsA("BasePart") then
        targetCFrame = coolingLocation.CFrame
    elseif coolingLocation:IsA("Attachment") then
        targetCFrame = coolingLocation.WorldCFrame
    else
        warn("CoolingTable Client: CoolingLocation is not a BasePart or Attachment, type:", coolingLocation.ClassName)
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

-- Get the current color for a pottery model based on state (supports both drying and cooling)
function CoolingTable:GetPotteryColor(slotData): Color3
    local clayType = slotData.clayType
    if not clayType then
        -- Fall back to style's clay type
        local styleData = SharedConstants.pottteryData and SharedConstants.pottteryData[slotData.styleKey]
        clayType = styleData and styleData.clayType or "normal"
    end
    
    local clayTypeData = SharedConstants.clayTypes[clayType]
    if not clayTypeData then
        clayTypeData = SharedConstants.clayTypes.normal
    end
    
    -- Determine mode based on fired state
    local isCoolingMode = slotData.fired == true
    
    -- Calculate progress based on start/end time
    local progress = 0
    if slotData.startTime and slotData.endTime then
        local levelStats = self:GetLevelStats()
        local duration
        if isCoolingMode then
            local coolTimeMultiplier = levelStats.coolTimeMultiplier or 1.0
            duration = ScriptUtils:CalculateCoolingDuration(clayType, slotData.styleKey, coolTimeMultiplier)
        else
            local dryTimeMultiplier = levelStats.dryTimeMultiplier or 1.0
            duration = ScriptUtils:CalculateDryingDuration(clayType, slotData.styleKey, dryTimeMultiplier)
        end
        local elapsed = os.time() - slotData.startTime
        progress = math.clamp(elapsed / duration, 0, 1)
    end
    
    -- Return color based on mode
    if isCoolingMode then
        return ScriptUtils:GetCoolingColor(clayType, progress)
    else
        return ScriptUtils:GetDryingColor(clayType, progress)
    end
end

-- Backwards compatibility alias
function CoolingTable:GetDryingColor(slotData): Color3
    return self:GetPotteryColor(slotData)
end

-- Apply color to all mud parts in a pottery model
function CoolingTable:ApplyColorToModel(potteryModel: Model, color: Color3)
    if not potteryModel then return end
    
    for _, part in ipairs(potteryModel:GetDescendants()) do
        if part:IsA("BasePart") and part.Material == Enum.Material.Mud then
            part.Color = color
        end
    end
end

-- Tween the color of a pottery model to a target color
function CoolingTable:TweenModelColor(potteryModel: Model, targetColor: Color3, duration: number?)
    if not potteryModel then return end
    
    duration = duration or 0.5
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    
    for _, part in ipairs(potteryModel:GetDescendants()) do
        if part:IsA("BasePart") and part.Material == Enum.Material.Mud then
            local tween = TweenService:Create(part, tweenInfo, { Color = targetColor })
            tween:Play()
        end
    end
end

-- Start color update loop for a slot
function CoolingTable:StartSlotColorUpdates(slotIndex: number, slotData)
    -- Stop any existing updates for this slot
    self:StopSlotColorUpdates(slotIndex)
    
    -- Store slot data
    self.slotDryingData[slotIndex] = slotData
    
    local potteryModel = self.slotModels[slotIndex]
    if not potteryModel then return end
    
    -- Apply initial color
    local initialColor = self:GetPotteryColor(slotData)
    self:ApplyColorToModel(potteryModel, initialColor)
    
    -- Determine mode and calculate duration
    local isCoolingMode = slotData.fired == true
    local clayType = slotData.clayType or "normal"
    local levelStats = self:GetLevelStats()
    local duration
    
    if isCoolingMode then
        local coolTimeMultiplier = levelStats.coolTimeMultiplier or 1.0
        duration = ScriptUtils:CalculateCoolingDuration(clayType, slotData.styleKey, coolTimeMultiplier)
    else
        local dryTimeMultiplier = levelStats.dryTimeMultiplier or 1.0
        duration = ScriptUtils:CalculateDryingDuration(clayType, slotData.styleKey, dryTimeMultiplier)
    end
    
    -- If no timing info, no updates needed
    if not slotData.startTime or not slotData.styleKey then return end
    
    -- Check if already complete
    local elapsed = os.time() - slotData.startTime
    if elapsed >= duration then
        local finalColor = self:GetPotteryColor(slotData)
        self:ApplyColorToModel(potteryModel, finalColor)
        return
    end
    
    -- Start update loop
    task.spawn(function()
        local lastColor = initialColor
        
        while potteryModel and potteryModel.Parent and self.slotModels[slotIndex] == potteryModel do
            -- Get current progress
            local currentElapsed = os.time() - slotData.startTime
            local currentProgress = math.clamp(currentElapsed / duration, 0, 1)
            local targetColor = self:GetPotteryColor(slotData)
            
            -- Only tween if color changed significantly
            local colorDiff = math.abs(targetColor.R - lastColor.R) + 
                              math.abs(targetColor.G - lastColor.G) + 
                              math.abs(targetColor.B - lastColor.B)
            
            if colorDiff > 0.01 then
                self:TweenModelColor(potteryModel, targetColor, 0.8)
                lastColor = targetColor
            end
            
            -- Check if complete
            if currentProgress >= 1 then
                self:TweenModelColor(potteryModel, targetColor, 0.8)
                break
            end
            
            -- Update every 2 seconds for smooth but efficient updates
            task.wait(2)
        end
    end)
end

-- Stop color updates for a slot
function CoolingTable:StopSlotColorUpdates(slotIndex: number)
    self.slotDryingData[slotIndex] = nil
end

-- Remove pottery model from slot
function CoolingTable:RemovePotteryModel(slotIndex: number)
    -- Stop color updates
    self:StopSlotColorUpdates(slotIndex)
    
    -- Remove from tracking
    local existingModel = self.slotModels[slotIndex]
    if existingModel then
        existingModel:Destroy()
        self.slotModels[slotIndex] = nil
    end
    
    -- Also check for any model in the workspace (in case of desync)
    local modelInWorkspace = self.model:FindFirstChild("CoolingPottery_" .. slotIndex)
    if modelInWorkspace then
        modelInWorkspace:Destroy()
    end
end

-- Get adornee for billboard UI (pottery model or cooling location)
function CoolingTable:GetSlotAdornee(slotIndex: number): BasePart?
    local potteryModel = self.slotModels[slotIndex]
    if potteryModel then
        local root = potteryModel:FindFirstChild("Root")
        if root and root:IsA("BasePart") then
            return root
        end
        for _, part in ipairs(potteryModel:GetDescendants()) do
            if part:IsA("BasePart") then
                return part
            end
        end
    end
    
    -- Fall back to cooling location
    local importantObjects = self.model:FindFirstChild("ImportantObjects")
    if importantObjects then
        local stationRoot = importantObjects:FindFirstChild("StationRoot")
        if stationRoot then
            return stationRoot:FindFirstChild("CoolingLocation_" .. slotIndex)
        end
    end
    
    return nil
end

-- Update visuals for a single slot
function CoolingTable:UpdateSlotVisuals(slotIndex: number, slotData)
    if slotData then
        -- Place pottery model
        self:PlacePotteryModel(slotIndex, slotData.styleKey)
        
        -- Start color updates for drying effect
        self:StartSlotColorUpdates(slotIndex, slotData)
    else
        -- Slot is empty - remove model
        self:RemovePotteryModel(slotIndex)
    end
    
    -- Update view prompt visibility (deferred to allow all slots to update)
    task.defer(function()
        self:UpdateViewPromptAndUI()
    end)
end

-- Update all slot visuals from current replica data
function CoolingTable:UpdateAllSlotVisuals()
    local coolingSlots = self:GetCoolingSlotsData()
    
    for i = 1, 4 do
        local slotData = coolingSlots[tostring(i)]
        -- Don't call UpdateSlotVisuals here to avoid multiple view prompt updates
        if slotData then
            self:PlacePotteryModel(i, slotData.styleKey)
            self:StartSlotColorUpdates(i, slotData)
        else
            self:RemovePotteryModel(i)
        end
    end
    
    -- Update view prompt and UI after all slots are set
    self:UpdateViewPromptAndUI()
end

-- Check if there are any items cooling
function CoolingTable:HasCoolingItems(): boolean
    local coolingSlots = self:GetCoolingSlotsData()
    for _, slotData in pairs(coolingSlots) do
        if slotData and slotData.styleKey then
            return true
        end
    end
    return false
end

-- Update the view prompt visibility based on cooling slots
function CoolingTable:UpdateViewPromptAndUI()
    local hasItems = self:HasCoolingItems()
    
    -- Update view prompt visibility
    if self.viewPrompt then
        self.viewPrompt:SetEnabled(hasItems)
    end
    
    -- If UI is open and no items left, close it
    if not hasItems and CoolingTableUI:GetVisible() then
        CoolingTableUI:Hide()
    end
end

-- Show the cooling table UI
function CoolingTable:ShowCoolingTableUI()
    local coolingSlots = self:GetCoolingSlotsData()
    
    -- Build slot data for UI with timing info
    local uiSlotsData = {}
    
    for slotIndexStr, slotData in pairs(coolingSlots) do
        if slotData and slotData.styleKey then
            uiSlotsData[slotIndexStr] = {
                styleKey = slotData.styleKey,
                clayType = slotData.clayType,
                startTime = slotData.startTime or os.time(),
                endTime = slotData.endTime,
                dried = slotData.dried,
                fired = slotData.fired, -- Track if in cooling mode (fired pottery)
            }
        end
    end
    
    -- Get max slots and level from level stats
    local levelStats = self:GetLevelStats()
    local maxSlots = levelStats.maxSlots or 4
    local coolingTableLevel = self.data.level or 0
    
    -- Show the UI with maxSlots and level (UI is already parented in master ScreenGui)
    CoolingTableUI:Show(uiSlotsData, maxSlots, coolingTableLevel,
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
function CoolingTable:OnViewTriggered(player: Player)
    if CoolingTableUI:GetVisible() then
        CoolingTableUI:Hide()
    else
        self:ShowCoolingTableUI()
    end
end

-- Setup visuals - called by StationHandler after construction
function CoolingTable:SetupVisuals()
    self.replicaMaid:DoCleaning()
    
    -- Wait for replica to be available
    local stationReplica = Replication.PotteryStations
    if not stationReplica then 
        warn("CoolingTable: PotteryStations replica not available")
        return 
    end
    
    local stationKey = self:GetStationKey()
    
    -- Initialize visuals from current data
    self:UpdateAllSlotVisuals()
    
    -- Track previous slots for change detection
    local previousSlots = self:DeepCopy(self:GetCoolingSlotsData())
    
    -- Listen for any changes to the replica
    self.replicaMaid:GiveTask(stationReplica:OnChange(function(action, path, newValue, oldValue)
        -- Debug: show all changes
        --local pathStr = table.concat(path, ".")
        --warn("CoolingTable: OnChange fired - action:", action, "path:", pathStr, "expected stationKey:", stationKey, "path[2]:", path[2])
        
        -- Check if this change affects our station's cooling slots
        -- Path format: {"activeStations", stationKey, "coolingSlots"}
        if path[1] == "activeStations" and path[2] == stationKey then
            --warn("CoolingTable: Path matches our station!", "path[3]:", path[3])
            if path[3] == "coolingSlots" then
                local currentSlots = self:GetCoolingSlotsData()
                --warn("CoolingTable: Current slots from replica:", currentSlots)
                
                -- Check each slot for changes
                for i = 1, 4 do
                    local slotKeyStr = tostring(i)
                    local newData = currentSlots[slotKeyStr]
                local oldData = previousSlots[slotKeyStr]
                
                local newStyleKey = newData and newData.styleKey
                local oldStyleKey = oldData and oldData.styleKey
                
                if newStyleKey ~= oldStyleKey then
                    self:UpdateSlotVisuals(i, newData)
                end
            end
            
            previousSlots = self:DeepCopy(currentSlots)
            end
        end
    end))
end

function CoolingTable:OnUpgradeTriggered(player: Player)
end

function CoolingTable:OnCoolTriggered(player: Player)
    local stationId = self.model:GetAttribute("StationId") or self.model.Name
    
    CoolPottery:Call(stationId):After(function(passed, result)
        if not passed or not result then
            --warn("CoolingTable: CoolPottery call failed")
            return
        end
        
        if result.success then
        else
            local errorType = result.error
            if errorType == "NoPotteryEquipped" then
                --warn("You need to hold unfired pottery!")
            elseif errorType == "NotPottery" then
                --warn("That's not a pottery item!")
            elseif errorType == "AlreadyCooled" then
                --warn("This pottery is already cooled!")
            elseif errorType == "NoSlotsAvailable" then
                --warn("No cooling slots available!")
            else
                --warn("Failed to cool pottery:", errorType or "Unknown error")
            end
        end
    end)
end

function CoolingTable:OnCollectTriggered(player: Player, slotIndex: number)
    local stationId = self.model:GetAttribute("StationId") or self.model.Name
    
    CollectPottery:Call(stationId, slotIndex):After(function(passed, result)
        if not passed or not result then
            --warn("CoolingTable: CollectPottery call failed")
            return
        end
        
        if result.success then
            -- Refresh UI after successful collection
            task.defer(function()
                if CoolingTableUI:GetVisible() then
                    self:ShowCoolingTableUI()
                end
            end)
        else
            local errorType = result.error
            if errorType == "NotReady" then
                --warn("Pottery is still cooling!")
            elseif errorType == "NoItemInSlot" then
                --warn("No pottery in this slot!")
            else
                --warn("Failed to collect pottery:", errorType or "Unknown error")
            end
        end
    end)
end

function CoolingTable:OnDeleteTriggered(player: Player, slotIndex: number)
    local stationId = self.model:GetAttribute("StationId") or self.model.Name
    
    DeletePottery:Call(stationId, slotIndex):After(function(passed, result)
        if not passed or not result then
            --warn("CoolingTable: DeletePottery call failed")
            return
        end
        
        if result.success then
            -- Refresh UI after successful deletion
            task.defer(function()
                if CoolingTableUI:GetVisible() then
                    self:ShowCoolingTableUI()
                end
            end)
        else
            local errorType = result.error
            if errorType == "NoItemInSlot" then
                --warn("No pottery in this slot!")
            else
                --warn("Failed to delete pottery:", errorType or "Unknown error")
            end
        end
    end)
end

function CoolingTable:Destroy()
    self.equippedItemMaid:DoCleaning()
    self.replicaMaid:DoCleaning()
    self.colorUpdateMaid:DoCleaning()
    
    -- Clean up UI
    CoolingTableUI:Hide()
    
    -- Clean up slot models
    for i = 1, 4 do
        -- Stop color updates
        self:StopSlotColorUpdates(i)
        
        -- Clean up slot models
        if self.slotModels[i] then
            self.slotModels[i]:Destroy()
        end
    end
    
    if self.coolPrompt then
        self.coolPrompt:Destroy()
    end
    if self.viewPrompt then
        self.viewPrompt:Destroy()
    end
    if self.upgradePrompt then
        self.upgradePrompt:Destroy()
    end
end

return CoolingTable
