--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Server = ServerScriptService.Server

local Signal = require(Shared.Signal)
local ReplicaService = require(Server.ReplicaService.ReplicaServiceListeners)

local DataObject = {}

function DataObject.new(player: Player?, extraInfo: boolean?, loadedData: any?) : any
    assert(player, "player is nil")

    if DataObject[player] == nil and loadedData ~= nil then
        DataObject[player] = {}
        DataObject[player].Replica = ReplicaService.NewReplica({
            ClassToken = ReplicaService.NewClassToken("dataKey"..player.UserId),
            Data = loadedData,
            Replication = player,
        })
        DataObject[player].Changed = Signal.new()
    end

    if DataObject[player] == nil then
        repeat
            task.wait()
        until 
        DataObject[player] ~= nil
    end

    return if extraInfo == true then DataObject[player] else DataObject[player].Replica.Data
end

Players.PlayerRemoving:Connect(function(player: Player?)
    local Replica = DataObject.new(player, true).Replica
    
    assert(player, "player is nil")
    assert(Replica, "playerData is nil")

    Replica:Destroy()
    if DataObject[player] ~= nil then
        DataObject[player] = nil
    end
end)

return DataObject