local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Client = Players.LocalPlayer.PlayerScripts.Client

local PlotStation = require(Shared.PlotStation)
local ProximityPromptHandler = require(Client.ProximityPromptHandler)

local GlazeTable = {}
GlazeTable.__index = GlazeTable
setmetatable(GlazeTable, PlotStation)

function GlazeTable.new(player: Player, stationModel: Model)
    local self = PlotStation.new(player, stationModel)
    setmetatable(self, GlazeTable)
    self:SetupInteraction()
    return self
end

function GlazeTable:SetupInteraction()
    self.createPrompt = ProximityPromptHandler.new(self.model:WaitForChild("ImportantObjects"):WaitForChild("StationRoot"):WaitForChild("Interact"), {
		actionText = "Glaze Pottery",
		objectText = "Glaze Table (Lvl " .. self.data.level .. ")",
        priority = 1,
		onTriggered = function(player)
			self:OnTriggered(player)
		end,
	})
    self.upgradePrompt = ProximityPromptHandler.new(self.model:WaitForChild("ImportantObjects"):WaitForChild("StationRoot"):WaitForChild("Interact"), {
        actionText = "Upgrade",
        objectText = "Glaze Table (Lvl " .. self.data.level .. ")",
        simple = true,
        left = true,
        priority = 1,
        onTriggered = function(player)
            self:OnUpgradeTriggered(player)
        end,
    })
end

function GlazeTable:OnUpgradeTriggered(player: Player)
    print(player.Name .. " wants to upgrade the Glaze Table")
end

function GlazeTable:OnTriggered(player: Player)
    print(player.Name .. " wants to glaze pottery at level " .. self.data.level .. " Glaze Table ")
end

function GlazeTable:Destroy()
    if self.proximityPromptObject then
        self.proximityPromptObject:Destroy()
    end
end

return GlazeTable
