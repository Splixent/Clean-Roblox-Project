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
    
    -- Track if this client is the owner
    self.isOwner = self.ownerPlayer.UserId == self.player.UserId
    print(self.isOwner)
    -- Only setup interaction for the owner
    if self.isOwner then
        self:SetupInteraction()
    end
    
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

function Kiln:SetupVisuals() end


function Kiln:OnUpgradeTriggered(player: Player)
end

function Kiln:OnTriggered(player: Player)
end

function Kiln:Destroy()
    if self.proximityPromptObject then
        self.proximityPromptObject:Destroy()
    end
end

return Kiln
