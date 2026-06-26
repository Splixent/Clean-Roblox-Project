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
    [Player]: PlayerDataObject,
    new: (player: Player, extraInfo: boolean?, loadedData: {[any]: any}?) -> (PlayerDataObject | {[any]: any}),
}

local DataObject: DataObjectModule = {} :: any

-- ReplicaServer.Token writes the token name into a module-level Tokens set
-- and NEVER clears it — there's no "free" path even after the corresponding
-- Replica is :Destroy()'d. When a player rejoins the same server session
-- (same UserId, new Player instance), the prior session's "dataKey<userId>"
-- entry is still in that set, so a fresh ReplicaService.Token(...) errors
-- with "duplicate". Cache the token by UserId at module scope so the rejoin
-- path reuses the one we already minted — the Token object is just a name +
-- identity table; the Replica it backed has been destroyed but the name slot
-- stays ours.
local tokenCache: { [number]: ReplicaToken } = {}

function DataObject.new(player: Player, extraInfo: boolean?, loadedData: {[any]: any}?): PlayerDataObject | {[any]: any}
    assert(player, "player is nil")

    if DataObject[player] == nil and loadedData ~= nil then
        local classToken: ReplicaToken = tokenCache[player.UserId]
        if classToken == nil then
            classToken = (ReplicaService :: any).Token("dataKey" .. player.UserId)
            tokenCache[player.UserId] = classToken
        end

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
    assert(player, "player is nil")

    -- Direct index (not DataObject.new) — calling .new here for a player whose
    -- entry was already cleared would fall into its `repeat task.wait() until
    -- DataObject[player] ~= nil` loop and hang this handler forever, leaking
    -- the replica + token. Just look it up and destroy if present.
    local playerDataObject = DataObject[player]
    if playerDataObject and playerDataObject.Replica then
        playerDataObject.Replica:Destroy()
    end
    DataObject[player] = nil
end)

return DataObject