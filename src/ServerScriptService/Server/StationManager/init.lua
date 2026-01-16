local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService.Server

local Replica = require(Server.ReplicaServer)

local StationManager = {
    stationReplica = Replica.New({
        Token = Replica.Token("PotteryStations"),
        Data = {
            activeStations = {},
        },
    }),

    stations = {
        ClayPatch = require(script.ClayPatch),
        PottersWheel = require(script.PottersWheel),
        Kiln = require(script.Kiln),
        GlazeTable = require(script.GlazeTable),
        CoolingTable = require(script.CoolingTable),
    },

    playerStations = {},
}

function StationManager:SetupStation(player, stationModel)
    local stationType = stationModel:GetAttribute("StationType")
    local stationClass = StationManager.stations[stationType]
    if stationClass then
        local stationInstance = stationClass.new(player, stationModel)
        local activeStations = StationManager.stationReplica.Data.activeStations
        activeStations[`{player.UserId}_{stationType}`] = stationInstance.data
        StationManager.stationReplica:Set({"activeStations"}, activeStations)

        if not StationManager.playerStations[player.UserId] then
            StationManager.playerStations[player.UserId] = {}
        end
        StationManager.playerStations[player.UserId][stationType] = stationInstance
    else
        --warn(`StationManager: Unknown station type '{stationType}' for station '{stationModel.Name}'`)
    end
end

-- Update a specific station's data in the replica
function StationManager:UpdateStationData(player, stationType, key, value)
    local stationKey = `{player.UserId}_{stationType}`
    local activeStations = StationManager.stationReplica.Data.activeStations
    
    if activeStations[stationKey] then
        activeStations[stationKey][key] = value
        StationManager.stationReplica:Set({"activeStations", stationKey, key}, value)
    else
        --warn("StationManager: No active station found for", stationKey)
    end
end

task.spawn(function()
    StationManager.stationReplica:Replicate()
end)

Players.PlayerRemoving:Connect(function(player: Player)
    local activeStations = StationManager.stationReplica.Data.activeStations
    activeStations[player.UserId] = nil
    StationManager.stationReplica:Set({"activeStations"}, activeStations)

    if StationManager.playerStations[player.UserId] then
        for _, stationInstance in pairs(StationManager.playerStations[player.UserId]) do
            stationInstance:Destroy()
        end
        StationManager.playerStations[player.UserId] = nil
    end
end)

return StationManager