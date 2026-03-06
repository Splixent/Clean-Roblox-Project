--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Server = ServerScriptService.Server

local Signal = require(Shared.Signal)
local ReplicaService = require(Server.ReplicaServer)

-- Type definitions
type Signal = {
    Fire: (self: Signal, ...any) -> (),
    Connect: (self: Signal, handler: (...any) -> ()) -> RBXScriptConnection,
    Wait: (self: Signal) -> ...any,
    Destroy: (self: Signal) -> ()
}

type Replica = {
    Tags: {[any]: any},
    Data: {[any]: any},
    Id: number,
    Token: string,
    Parent: Replica?,
    Children: {[Replica]: boolean?},
    BoundInstance: Instance?,
    OnServerEvent: {Connect: (self: any, listener: (Player, ...any) -> ()) -> ({Disconnect: (self: any) -> ()})},
    
    Set: (self: Replica, path: {string}, value: any) -> (),
    SetValues: (self: Replica, path: {string}, values: {[string]: any}) -> (),
    TableInsert: (self: Replica, path: {string}, value: any, index: number?) -> number,
    TableRemove: (self: Replica, path: {string}, index: number) -> any,
    Write: (self: Replica, function_name: string, ...any) -> ...any,
    FireClient: (self: Replica, player: Player, ...any) -> (),
    FireAllClients: (self: Replica, ...any) -> (),
    UFireClient: (self: Replica, player: Player, ...any) -> (),
    UFireAllClients: (self: Replica, ...any) -> (),
    SetParent: (self: Replica, new_parent: Replica) -> (),
    BindToInstance: (self: Replica, instance: Instance) -> (),
    Replicate: (self: Replica) -> (),
    DontReplicate: (self: Replica) -> (),
    Subscribe: (self: Replica, player: Player) -> (),
    Unsubscribe: (self: Replica, player: Player) -> (),
    Identify: (self: Replica) -> string,
    IsActive: (self: Replica) -> boolean,
    Destroy: (self: Replica) -> (),
}

type ReplicaToken = {
    Name: string
}

type PlayerDataObject = {
    Replica: Replica,
    Changed: Signal
}

type DataObjectModule = {
    [Player]: PlayerDataObject
}

local DataObject: DataObjectModule = {} :: any

function DataObject.new(player: Player, extraInfo: boolean?, loadedData: {[any]: any}?): PlayerDataObject | {[any]: any}
    assert(player, "player is nil")

    if DataObject[player] == nil and loadedData ~= nil then
        local classToken: ReplicaToken = (ReplicaService :: any).Token("dataKey" .. player.UserId)
        
        DataObject[player] = {
            Replica = (ReplicaService :: any).New({
                Token = classToken,
                Data = loadedData,
                Tags = {
                    Player = player
                }
            }),
            Changed = Signal.new()
        }
        
        DataObject[player].Replica:Replicate()
    end

    if DataObject[player] == nil then
        repeat
            task.wait()
        until DataObject[player] ~= nil
    end

    return if extraInfo == true then DataObject[player] else DataObject[player].Replica.Data
end

Players.PlayerRemoving:Connect(function(player: Player)
    local playerDataObject = DataObject.new(player, true) :: PlayerDataObject
    local replica: Replica = playerDataObject.Replica
    
    assert(player, "player is nil")
    assert(replica, "replica is nil")

    replica:Destroy()
    if DataObject[player] ~= nil then
        DataObject[player] = nil
    end
end)

return DataObject