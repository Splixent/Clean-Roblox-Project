--Strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Server = ServerScriptService.Server

require(Server.Datastore)
require(Server.Datastore.DataObject)
require(Server.MarketplaceManager)
require(Server.SyncedTime)

local PlayerEntityManager = require(Server.PlayerEntityManager)
local Events = require(Shared.Events)

Events.InGame.listen(function(_data, player: Player)
	local PlayerEntity = PlayerEntityManager.new(player, true).Replica

	assert(player, "player is nil")
	assert(PlayerEntity, "PlayerEntity is nil")

	PlayerEntity:Set({ "inGame" }, true)
end)
