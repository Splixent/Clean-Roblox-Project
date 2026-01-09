local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Client = Players.LocalPlayer.PlayerScripts.Client

local PlotStation = require(Shared.PlotStation)
local ProximityPromptHandler = require(Client.ProximityPromptHandler)

local CoolingTable = {}
CoolingTable.__index = CoolingTable
setmetatable(CoolingTable, PlotStation)

function CoolingTable.new(player: Player, stationModel: Model)
    local self = PlotStation.new(player, stationModel)
    setmetatable(self, CoolingTable)
    self:SetupInteraction()
    return self
end

function CoolingTable:SetupInteraction()
    -- Should only be visible when holding pottery item
    -- If holding an unfired pottery item, show drying prompt instead of cooling.
    self.coolPrompt = ProximityPromptHandler.new(self.model:WaitForChild("ImportantObjects"):WaitForChild("StationRoot"):WaitForChild("Interact"), {
		actionText = "Cool Pottery",
		objectText = "Cooling Table (Lvl " .. self.data.level .. ")",
        priority = 1,
		onTriggered = function(player)
			self:OnTriggered(player)
		end,
	})
    self.upgradePrompt = ProximityPromptHandler.new(self.model:WaitForChild("ImportantObjects"):WaitForChild("StationRoot"):WaitForChild("Interact"), {
        actionText = "Upgrade",
        objectText = "Cooling Table (Lvl " .. self.data.level .. ")",
        simple = true,
        left = true,
        priority = 1,
        onTriggered = function(player)
            self:OnUpgradeTriggered(player)
        end,
    })
end

function CoolingTable:OnUpgradeTriggered(player: Player)
    print(player.Name .. " wants to upgrade the cooling table")
end

function CoolingTable:OnTriggered(player: Player)
    print(player.Name .. " wants to cool pottery at level " .. self.data.level .. " cooling table")
end

function CoolingTable:Destroy()
    if self.proximityPromptObject then
        self.proximityPromptObject:Destroy()
    end
end

return CoolingTable
