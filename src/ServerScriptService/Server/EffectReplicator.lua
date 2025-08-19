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
local PlayerEntityManager = require(Server.PlayerEntityManager)

local SendEffect = Events.SendEffect:Server()
local RecieveEffect = Events.RecieveEffect:Server()

local EffectReplicator = {}


SendEffect:On(function(player, effectName)
    local playerEntity = PlayerEntityManager.new(player, true).Replica
    local effectData = playerEntity.Data.effectCooldowns[effectName]

    if effectData and effectData.enabled and tick() - effectData.lastUsed >= effectData.cooldownTime then
        playerEntity:SetValue({"effectCooldowns", effectName, "lastUsed"}, tick())
        RecieveEffect:FireAllExcept(player, effectName, player.Character)
    end
end)

return EffectReplicator