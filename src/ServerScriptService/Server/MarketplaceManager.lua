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
local Datastore = require(Server.Datastore)

local MarketplaceManager = {
	gamepasses = {},

	purchaseInfo = {},
    processes = {}
}

function MarketplaceManager._1(player) -- Test
end

function MarketplaceManager.ProcessReceipt(reciptInfo)
	local player = Players:GetPlayerByUserId(reciptInfo.PlayerId)
	local validPurchase = true

	if player then
		local playerData = DataObject.new(player, true).Replica
		local purchaseHistory = ScriptUtils:DeepCopy(playerData.Data.purchaseHistory)

		for i, purchaseInfo in ipairs(purchaseHistory) do
			if purchaseInfo.PurchaseId == reciptInfo.PurchaseId then
				validPurchase = false
			end
		end

		if validPurchase == true then
			table.insert(purchaseHistory, {
				currencySpent = reciptInfo.CurrencySpent,
				productId = reciptInfo.ProductId,
				purchaseId = reciptInfo.PurchaseId,
			})

			playerData:Set({ "purchaseHistory" }, purchaseHistory)
			MarketplaceManager["_" .. reciptInfo.ProductId](player)
		end
	end

	return if validPurchase
		then Enum.ProductPurchaseDecision.PurchaseGranted
		else Enum.ProductPurchaseDecision.NotProcessedYet
end

MarketplaceService.ProcessReceipt = MarketplaceManager.ProcessReceipt

function MarketplaceManager:CheckGamepasses(player)
	task.spawn(function()
		repeat
			task.wait()
		until DataObject[player] ~= nil

		for gamepassName, gamepassId in pairs(MarketplaceManager.gamepasses) do
			local ownsGamepass = MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepassId)
			if ownsGamepass == true then
				local playerData = DataObject.new(player, true)

				if playerData.Replica.Data[gamepassName] == nil then
					playerData.Replica:Set({ gamepassName }, true)
				end
			end
		end
	end)
end

task.spawn(function()
	for i, player in ipairs(Players:GetPlayers()) do
		MarketplaceManager:CheckGamepasses(player)
	end
end)

Players.PlayerAdded:Connect(function(player)
	MarketplaceManager:CheckGamepasses(player)
end)

return MarketplaceManager
