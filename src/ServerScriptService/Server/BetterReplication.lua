local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Server = ServerScriptService.Server

local BetterReplication = require(Shared.BetterReplication)

task.spawn(function()
	BetterReplication.start()
	BetterReplication.bindSanityCheck(function(data)
		return true
	end)
end)

return BetterReplication