--!strict

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Server = ServerScriptService.Server

local Replica = require(Server.ReplicaServer)
local Constants = require(Server.Constants)
local ScriptUtils = require(Shared.ScriptUtils)
local Maid = require(Shared.Maid)

local PlayerEntityManager = {}

function PlayerEntityManager.new(player: Player?, extraInfo: boolean?): any
    assert(player, "Player is nil")
    if PlayerEntityManager[player] == nil then
        local PlayerEntityInfo = {}
        PlayerEntityInfo.Replica = Replica.New({
            Token = Replica.Token("states"..player.UserId),
            Data = ScriptUtils:DeepCopy(Constants.states),
        })
        PlayerEntityInfo.Replica:Subscribe(player)
        PlayerEntityManager[player] = PlayerEntityInfo
    end
    return if extraInfo then PlayerEntityManager[player] else PlayerEntityManager[player].Replica.Data
end

function PlayerEntityManager.SetupCharacter(player: Player?)
    assert(player, "Player is nil")
    player:LoadCharacterAsync()

    local character: Model = player.Character or player.CharacterAdded:Wait()
    local humanoid: Humanoid = character:WaitForChild("Humanoid"):: Humanoid

    character.Parent = game.Workspace.PlayerCharacters

    humanoid.Died:Once(function()
		PlayerEntityManager.OnDied(player)
    end)
end

function PlayerEntityManager.OnDied(player: Player?)
    PlayerEntityManager.SetupCharacter(player)
end

Players.PlayerRemoving:Connect(function(player: Player?)
    local Replica = PlayerEntityManager.new(player, true).Replica

    assert(player, "player is nil")
    assert(Replica, "PlayerEntity is nil")

    Replica:Destroy()
    if PlayerEntityManager[player] ~= nil then
        PlayerEntityManager[player] = nil
    end
end)


return PlayerEntityManager