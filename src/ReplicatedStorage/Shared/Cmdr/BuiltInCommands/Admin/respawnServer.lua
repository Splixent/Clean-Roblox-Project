local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Server = ServerScriptService.Server

local PlayerEntityManager = require(Server.PlayerEntityManager)

return function(_, players)
	for _, player in pairs(players) do
		if player.Character then
			PlayerEntityManager.OnDied(player, player.Character, true)
		end
	end
	return ("Respawned %d players."):format(#players)
end
