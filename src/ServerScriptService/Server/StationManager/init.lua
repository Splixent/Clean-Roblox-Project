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