local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Server = ServerScriptService.Server

local PlotStation = require(Shared.PlotStation)
local DataObject = require(Server.Datastore.DataObject)
local SharedConstants = require(Shared.Constants)
local InventoryManager = require(Server.InventoryManager)
local Events = require(Shared.Events)

local InsertClay = Events.InsertClay
local SetPotteryStyle = Events.SetPotteryStyle
local CancelPottery = Events.CancelPottery
local CompletePottery = Events.CompletePottery
local UpdatePotteryShaping = Events.UpdatePotteryShaping

local PottersWheel = {}
PottersWheel.__index = PottersWheel
setmetatable(PottersWheel, PlotStation)

-- Helper function to find the PottersWheel model for a player
local function FindPottersWheelModel(player: Player): Model?
    local plots = game.Workspace:FindFirstChild("Plots")
    if not plots then return nil end
    
    for _, plot in ipairs(plots:GetChildren()) do
        if plot:GetAttribute("Owner") == player.UserId then
            local mainPlot = plot:FindFirstChild("MainPlot")
            if mainPlot then
                local stations = mainPlot:FindFirstChild("PotteryStations")
                if stations then
                    for _, station in ipairs(stations:GetChildren()) do
                        if station:GetAttribute("StationType") == "PottersWheel" then
                            return station
                        end
                    end
                end
            end
        end
    end
    return nil
end

function PottersWheel.new(player: Player, stationModel: Model)
    local self = PlotStation.new(player, stationModel)
    setmetatable(self, PottersWheel)
    
    return self
end

function PottersWheel:Destroy()
    self.maid:DoCleaning()
end

-- SetPotteryStyle handler (sets/clears visual attributes for replication)
SetPotteryStyle:SetCallback(function(player: Player, stationId: string, styleKey: string?, requiredClay: number?)
    local stationModel = FindPottersWheelModel(player)
    
    if not stationModel then
        return { success = false, error = "NoStation" }
    end
    
    -- If styleKey is nil or empty, clear the attributes
    if not styleKey or styleKey == "" then
        stationModel:SetAttribute("PotteryStyle", nil)
        stationModel:SetAttribute("InsertedClay", nil)
        stationModel:SetAttribute("RequiredClay", nil)
        return { success = true, cleared = true }
    end
    
    -- Set the initial style attributes (clay starts at 0)
    stationModel:SetAttribute("PotteryStyle", styleKey)
    stationModel:SetAttribute("InsertedClay", 0)
    stationModel:SetAttribute("RequiredClay", requiredClay or 0)
    
    return { success = true }
end)

-- InsertClay handler
InsertClay:SetCallback(function(player: Player, stationId: string, styleKey: string)
    -- Validate inputs
    if not stationId or not styleKey then
        return { success = false, error = "InvalidInput" }
    end
    
    -- Get player data
    local playerData = DataObject.new(player, true).Replica
    if not playerData then
        return { success = false, error = "NoPlayerData" }
    end
    
    -- Get style data
    local styleData = SharedConstants.pottteryData and SharedConstants.pottteryData[styleKey]
    if not styleData then
        return { success = false, error = "InvalidStyle" }
    end
    
    -- Get required clay type and amount
    local requiredClayType = styleData.clayType or "normal"
    local requiredClayAmount = styleData.cost and styleData.cost.clay or 0
    
    -- Find the item name that matches the clay type
    local clayItemName = nil
    for itemName, itemInfo in pairs(SharedConstants.itemData) do
        if itemInfo.itemType == "clay" and itemInfo.clayType == requiredClayType then
            clayItemName = itemName
            break
        end
    end
    
    if not clayItemName then
        return { success = false, error = "NoClayItemForType" }
    end
    
    -- Check if player has any clay of the required type
    local inventory = playerData.Data.inventory
    local playerClayInfo = inventory and inventory.items and inventory.items[clayItemName]
    local playerClayAmount = playerClayInfo and playerClayInfo.amount or 0
    
    if playerClayAmount <= 0 then
        return { success = false, error = "NoClay", currentClay = 0, requiredClay = requiredClayAmount }
    end
    
    -- Find the PottersWheel model for this player
    local stationModel = FindPottersWheelModel(player)
    
    -- Get current insertion progress (stored on station or in player data)
    local insertionProgress = playerData.Data.potteryInsertion or {}
    local stationProgress = insertionProgress[stationId] or {
        styleKey = styleKey,
        insertedClay = 0,
        requiredClay = requiredClayAmount,
        clayType = requiredClayType,
    }
    
    -- If style changed, reset progress
    if stationProgress.styleKey ~= styleKey then
        stationProgress = {
            styleKey = styleKey,
            insertedClay = 0,
            requiredClay = requiredClayAmount,
            clayType = requiredClayType,
        }
    end
    
    -- Calculate how much clay to insert
    local clayNeeded = stationProgress.requiredClay - stationProgress.insertedClay
    local clayToInsert = math.min(playerClayAmount, clayNeeded)
    
    if clayToInsert <= 0 then
        -- Already fully inserted
        return { 
            success = true, 
            complete = true, 
            insertedClay = stationProgress.insertedClay, 
            requiredClay = stationProgress.requiredClay 
        }
    end
    
    -- Consume clay from inventory
    local consumed = InventoryManager:ConsumeItem(player, clayItemName, clayToInsert)
    if not consumed then
        return { success = false, error = "FailedToConsume" }
    end
    
    -- Update insertion progress
    stationProgress.insertedClay = stationProgress.insertedClay + clayToInsert
    insertionProgress[stationId] = stationProgress
    playerData:Set({"potteryInsertion"}, insertionProgress)
    
    -- Update station model attributes for visual replication to all clients
    if stationModel then
        stationModel:SetAttribute("PotteryStyle", styleKey)
        stationModel:SetAttribute("InsertedClay", stationProgress.insertedClay)
        stationModel:SetAttribute("RequiredClay", stationProgress.requiredClay)
    end
    
    -- Check if insertion is complete
    local isComplete = stationProgress.insertedClay >= stationProgress.requiredClay
    
    if isComplete then
        -- NOTE: Don't clear insertion progress here - keep it so player can cancel and get clay back
        -- Progress will be cleared when minigame is completed or cancelled
    end
    
    return { 
        success = true, 
        complete = isComplete,
        insertedClay = stationProgress.insertedClay,
        requiredClay = stationProgress.requiredClay,
        clayInsertedThisTime = clayToInsert,
    }
end)

-- CancelPottery handler (returns inserted clay to player inventory)
CancelPottery:SetCallback(function(player: Player, stationId: string)
    
    -- Get player data
    local playerData = DataObject.new(player, true).Replica
    if not playerData then
        return { success = false, error = "NoPlayerData" }
    end
    
    -- Get insertion progress for this station
    local insertionProgress = playerData.Data.potteryInsertion or {}
    local stationProgress = insertionProgress[stationId]
    
    -- If no progress, nothing to return
    if not stationProgress then
        return { success = true, returnedClay = 0 }
    end
    
    local insertedClay = stationProgress.insertedClay or 0
    local clayType = stationProgress.clayType or "normal"
    
    
    -- Find the item name that matches the clay type
    local clayItemName = nil
    for itemName, itemInfo in pairs(SharedConstants.itemData) do
        if itemInfo.itemType == "clay" and itemInfo.clayType == clayType then
            clayItemName = itemName
            break
        end
    end
    
    -- Return clay to inventory if any was inserted
    if insertedClay > 0 and clayItemName then
        InventoryManager:AddItem(player, clayItemName, insertedClay)
    end
    
    -- Clear insertion progress for this station
    insertionProgress[stationId] = nil
    playerData:Set({"potteryInsertion"}, insertionProgress)
    
    -- Clear station model attributes
    local stationModel = FindPottersWheelModel(player)
    if stationModel then
        stationModel:SetAttribute("PotteryStyle", nil)
        stationModel:SetAttribute("InsertedClay", nil)
        stationModel:SetAttribute("RequiredClay", nil)
        stationModel:SetAttribute("PotteryShaping", nil)
        stationModel:SetAttribute("PotteryComplete", nil)
    end
    
    return { success = true, returnedClay = insertedClay }
end)

-- CompletePottery handler (give the finished pottery item to the player)
CompletePottery:SetCallback(function(player: Player, stationId: string, styleKey: string)
    
    -- Validate style
    local styleData = SharedConstants.pottteryData and SharedConstants.pottteryData[styleKey]
    if not styleData then
        return { success = false, error = "InvalidStyle" }
    end
    
    -- Get player data
    local playerData = DataObject.new(player, true).Replica
    if not playerData then
        return { success = false, error = "NoPlayerData" }
    end
    
    -- Clear insertion progress for this station (if any remains)
    local insertionProgress = playerData.Data.potteryInsertion or {}
    if insertionProgress[stationId] then
        insertionProgress[stationId] = nil
        playerData:Set({"potteryInsertion"}, insertionProgress)
    end
    
    -- Get clay type from style data
    local clayType = styleData.clayType or "normal"
    
    -- Add the pottery item to inventory
    -- NOTE: dryingDuration is NOT stored - it's calculated at runtime using ScriptUtils:CalculateDryingDuration
    -- This allows station upgrades to affect drying times dynamically
    local added = InventoryManager:AddPotteryItem(player, styleKey, function(itemData)
        itemData.fired = false
        itemData.dried = false
        itemData.cooled = false
        itemData.clayType = clayType -- Store for color calculations and duration calculation
        return itemData
    end)
    if not added then
        return { success = false, error = "FailedToAddItem" }
    end
    
    -- Clear station model attributes
    local stationModel = FindPottersWheelModel(player)
    if stationModel then
        stationModel:SetAttribute("PotteryStyle", nil)
        stationModel:SetAttribute("InsertedClay", nil)
        stationModel:SetAttribute("RequiredClay", nil)
        stationModel:SetAttribute("PotteryShaping", nil)
        stationModel:SetAttribute("PotteryComplete", nil)
    end
    
    return { success = true, styleKey = styleKey }
end)

-- UpdatePotteryShaping handler (sets shaping/completion attributes for visual replication)
UpdatePotteryShaping:SetCallback(function(player: Player, stationId: string, isShaping: boolean, isComplete: boolean?)
    local stationModel = FindPottersWheelModel(player)
    
    if not stationModel then
        return { success = false, error = "NoStation" }
    end
    
    -- Set shaping attribute (true = spinning animation active)
    stationModel:SetAttribute("PotteryShaping", isShaping)
    
    -- Set completion attribute if provided (true = show finished pottery)
    if isComplete ~= nil then
        stationModel:SetAttribute("PotteryComplete", isComplete)
    end
    
    return { success = true }
end)

return PottersWheel
