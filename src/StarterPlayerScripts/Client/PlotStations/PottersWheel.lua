local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Client = Players.LocalPlayer.PlayerScripts.Client

local PlotStation = require(Shared.PlotStation)
local ProximityPromptHandler = require(Client.ProximityPromptHandler)

local PottersWheel = {}
PottersWheel.__index = PottersWheel
setmetatable(PottersWheel, PlotStation)

function PottersWheel.new(player: Player, stationModel: Model)
    local self = PlotStation.new(player, stationModel)
    setmetatable(self, PottersWheel)
    self:SetupInteraction()
    return self
end

function PottersWheel:SetupInteraction()
    self.createPrompt = ProximityPromptHandler.new(self.model:WaitForChild("ImportantObjects"):WaitForChild("StationRoot"):WaitForChild("Interact"), {
		actionText = "Create Pottery",
		objectText = "Potter's Wheel (Lvl " .. self.data.level .. ")",
        priority = 1,
		onTriggered = function(player)
			self:OnTriggered(player)
		end,
	})
    self.upgradePrompt = ProximityPromptHandler.new(self.model:WaitForChild("ImportantObjects"):WaitForChild("StationRoot"):WaitForChild("Interact"), {
        actionText = "Upgrade",
        objectText = "Potter's Wheel (Lvl " .. self.data.level .. ")",
        simple = true,
        left = true,
        priority = 1,
        onTriggered = function(player)
            self:OnUpgradeTriggered(player)
        end,
    })
end

function PottersWheel:OnUpgradeTriggered(player: Player)
    print(player.Name .. " wants to upgrade the potter's wheel")
end

function PottersWheel:OnTriggered(player: Player)
    print(player.Name .. " wants to create pottery at level " .. self.data.level .. " potter's wheel")
end

function PottersWheel:Destroy()
    if self.proximityPromptObject then
        self.proximityPromptObject:Destroy()
    end
end

return PottersWheel
