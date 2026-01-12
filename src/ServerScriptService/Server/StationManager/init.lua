local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local MarketplaceService = game:GetService("MarketplaceService")

local Shared = ReplicatedStorage.Shared
local Server = ServerScriptService.Server

local DataObject = require(Server.Datastore.DataObject)
local ScriptUtils = require(Shared.ScriptUtils)
local Events = require(Shared.Events)
local Maid = require(Shared.Maid)
local Replica = require(Server.ReplicaServer)
local Events = require(Shared.Events)
local SharedConstants = require(Shared.Constants)
local InventoryManager = require(Server.InventoryManager)
local PlayerEntityManager = require(Server.PlayerEntityManager)

local HarvestClay = Events.HarvestClay

local StationManager = {
    stationReplica = Replica.New({
        Token = Replica.Token("PotteryStations"),
        Data = {
            activeStations = {},
        },
    }),

    stations = {
        ClayPatch = require(script.ClayPatch)
    },

    playerStations = {},
}

function StationManager:SetupStation(player, stationModel)
    local stationType = stationModel:GetAttribute("StationType")
    local stationClass = StationManager.stations[stationType]
    if stationClass then
        local stationInstance = stationClass.new(player, stationModel)
        local activeStations = StationManager.stationReplica.Data.activeStations
        activeStations[player] = stationInstance.data
        StationManager.stationReplica:Set({"activeStations"}, activeStations)

        if not StationManager.playerStations[player] then
            StationManager.playerStations[player] = {}
        end
        StationManager.playerStations[player][stationType] = stationInstance
    else
        --warn(`StationManager: Unknown station type '{stationType}' for station '{stationModel.Name}'`)
    end
end

task.spawn(function()
    StationManager.stationReplica:Replicate()
end)

HarvestClay:SetCallback(function(player: Player)
    local playerData = DataObject.new(player, true).Replica
    local clayPatchInstance = StationManager.playerStations[player] and StationManager.playerStations[player]["ClayPatch"]
    local clayPatchData = SharedConstants.potteryStationInfo.ClayPatch.levelStats[tostring(clayPatchInstance.data.level)]
    if not clayPatchInstance then
        return "NoClayPatch"  
    end

    if clayPatchInstance.ownerPlayer ~= player then
        return "NotOwner"
    end

    if game.Workspace:GetServerTimeNow() - clayPatchInstance.lastHarvest < clayPatchData.harvestCooldown then
        return "CooldownActive"
    end

    if clayPatchInstance.__attributes.Clay <= 0 then
        return "NoClay"
    end

    local clayToGive = clayPatchData.harvestAmount
    clayPatchInstance.__attributes.Clay = clayPatchInstance.__attributes.Clay - clayToGive
    clayPatchInstance.lastHarvest = game.Workspace:GetServerTimeNow()

    playerData:Set({"potteryStations", "ClayPatch", "clay"}, clayPatchInstance.__attributes.Clay)

    print(`{player.Name} harvested {clayToGive} clay from their Clay Patch.`)

    InventoryManager:AddItem(player, "Clay", clayToGive)

    return "Success"
end)

-- InsertClay handler for PottersWheel
local InsertClay = Events.InsertClay

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
    
    -- Get or create the PottersWheel station data for this player
    local pottersWheelInstance = StationManager.playerStations[player] and StationManager.playerStations[player]["PottersWheel"]
    
    -- Get current insertion progress (stored on station or in player data)
    -- We'll use playerData to track insertion progress per station
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
    
    -- Check if insertion is complete
    local isComplete = stationProgress.insertedClay >= stationProgress.requiredClay
    
    if isComplete then
        -- Clear insertion progress for this station
        insertionProgress[stationId] = nil
        playerData:Set({"potteryInsertion"}, insertionProgress)
        
        -- TODO: Start pottery creation process
        -- 1. Set wheel state to "creating"
        -- 2. Make preview model solid
        -- 3. Start minigame/animation
        
        print(`{player.Name} completed clay insertion for {styleData.name} ({stationProgress.insertedClay}/{stationProgress.requiredClay} clay)`)
    else
        print(`{player.Name} inserted {clayToInsert} clay for {styleData.name} ({stationProgress.insertedClay}/{stationProgress.requiredClay})`)
    end
    
    return { 
        success = true, 
        complete = isComplete,
        insertedClay = stationProgress.insertedClay,
        requiredClay = stationProgress.requiredClay,
        clayInsertedThisTime = clayToInsert,
    }
end)

Players.PlayerRemoving:Connect(function(player: Player)
    local activeStations = StationManager.stationReplica.Data.activeStations
    activeStations[player] = nil
    StationManager.stationReplica:Set({"activeStations"}, activeStations)

    if StationManager.playerStations[player] then
        for _, stationInstance in pairs(StationManager.playerStations[player]) do
            stationInstance:Destroy()
        end
        StationManager.playerStations[player] = nil
    end
end)





return StationManager