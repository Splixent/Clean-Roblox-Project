local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Client = Players.LocalPlayer.PlayerScripts.Client

local PlotStation = require(Shared.PlotStation)
local ProximityPromptHandler = require(Client.ProximityPromptHandler)

local Kiln = {}
Kiln.__index = Kiln
setmetatable(Kiln, PlotStation)

function Kiln.new(player: Player, stationModel: Model)
    local self = PlotStation.new(player, stationModel)
    setmetatable(self, Kiln)
    self:SetupInteraction()
    return self
end

function Kiln:SetupInteraction()
    self.createPrompt = ProximityPromptHandler.new(self.model:WaitForChild("ImportantObjects"):WaitForChild("StationRoot"):WaitForChild("Interact"), {
		actionText = "Fire Pottery",
		objectText = "Kiln (Lvl " .. self.data.level .. ")",
        priority = 1,
		onTriggered = function(player)
			self:OnTriggered(player)
		end,
	})
    self.upgradePrompt = ProximityPromptHandler.new(self.model:WaitForChild("ImportantObjects"):WaitForChild("StationRoot"):WaitForChild("Interact"), {
        actionText = "Upgrade",
        objectText = "Kiln (Lvl " .. self.data.level .. ")",
        simple = true,
        left = true,
        priority = 1,
        onTriggered = function(player)
            self:OnUpgradeTriggered(player)
        end,
    })
end

function Kiln:OnUpgradeTriggered(player: Player)
    print(player.Name .. " wants to upgrade the kiln")
end

function Kiln:OnTriggered(player: Player)
    print(player.Name .. " wants to fire pottery at level " .. self.data.level .. " kiln ")
end

function Kiln:Destroy()
    if self.proximityPromptObject then
        self.proximityPromptObject:Destroy()
    end
end

return Kiln
