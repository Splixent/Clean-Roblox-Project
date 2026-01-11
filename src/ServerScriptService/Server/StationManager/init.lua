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
        warn(`StationManager: Unknown station type '{stationType}' for station '{stationModel.Name}'`)
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

    --award clay to player (implementation depends on inventory system)

    print(`{player.Name} harvested {clayToGive} clay from their Clay Patch.`)

    InventoryManager:AddItem(player, "Clay", clayToGive)

    return "Success"
end)

-- InsertClay handler for PottersWheel
local InsertClay = Events.InsertClay

InsertClay:SetCallback(function(player: Player, stationId: string, styleKey: string)
    -- Validate inputs
    if not stationId or not styleKey then
        return "InvalidInput"
    end
    
    -- Get player data
    local playerData = DataObject.new(player, true).Replica
    if not playerData then
        return "NoPlayerData"
    end
    
    -- Get style data
    local styleData = SharedConstants.pottteryData and SharedConstants.pottteryData[styleKey]
    if not styleData then
        return "InvalidStyle"
    end
    
    -- Get clay cost
    local clayCost = styleData.cost and styleData.cost.clay or 0
    
    -- Check if player is holding clay (check equipped item)
    local equippedItem = playerData.Data.equippedItem
    if not equippedItem or equippedItem.itemType ~= "Clay" then
        return "NotHoldingClay"
    end
    
    -- Check if player has enough clay in hand
    local heldClayAmount = equippedItem.amount or 0
    if heldClayAmount < clayCost then
        return "NotEnoughClay"
    end
    
    -- Check clay type matches (if style requires specific clay type)
    local requiredClayType = styleData.clayType or "normal"
    local heldClayType = equippedItem.clayType or "normal"
    if requiredClayType ~= heldClayType then
        return "WrongClayType"
    end
    
    -- Deduct clay from player's held item
    local newAmount = heldClayAmount - clayCost
    if newAmount <= 0 then
        -- Remove equipped item entirely
        playerData:Set({"equippedItem"}, nil)
    else
        -- Update amount
        playerData:Set({"equippedItem", "amount"}, newAmount)
    end
    
    -- TODO: Start pottery creation process on the PottersWheel
    -- This would involve:
    -- 1. Setting the wheel's state to "creating"
    -- 2. Storing the selected style
    -- 3. Making the preview model solid (transparency 0)
    -- 4. Starting any minigame/animation
    
    print(`{player.Name} inserted {clayCost} clay to create {styleData.name}`)
    
    return "Success"
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