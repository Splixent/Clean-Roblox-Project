local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService.Server

local InventoryManager = require(Server.InventoryManager)

return function(context, players, itemName, quantity)
	quantity = quantity or 1

	for _, player in pairs(players) do
		InventoryManager:AddItem(player, itemName, quantity)
	end

	return `Gave {quantity}x {itemName} to {#players} player(s)`
end
