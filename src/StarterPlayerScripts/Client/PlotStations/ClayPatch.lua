local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Client = Players.LocalPlayer.PlayerScripts.Client

local PlotStation = require(Shared.PlotStation)
local ProximityPromptHandler = require(Client.ProximityPromptHandler)
local Harvest = require(Client.UI.Components.Harvest.Functions)
local Events = require(Shared.Events)
local Maid = require(Shared.Maid)
local Fusion = require(Shared.Fusion)
local ScriptUtils = require(Shared.ScriptUtils)

local HarvestClay = Events.HarvestClay

local ClayPatch = {}
ClayPatch.__index = ClayPatch
setmetatable(ClayPatch, PlotStation)

function ClayPatch.new(ownerPlayer: Player, stationModel: Model)
    local self = PlotStation.new(ownerPlayer, stationModel)
    setmetatable(self, ClayPatch)

    self.visualMaid = Maid.new()
    if self.ownerPlayer.UserId == self.player.UserId then
        self:SetupInteraction()
    end
    return self
end

function ClayPatch:SetupInteraction()
    self.collectPrompt = ProximityPromptHandler.new(self.model:WaitForChild("ImportantObjects"):WaitForChild("StationRoot"):WaitForChild("Interact"), {
		actionText = "Harvest",
		objectText = "Clay Patch (Lvl " .. self.data.level .. ")",
        priority = 1,
		onTriggered = function(player)
			self:OnTriggered(player)
		end,
        onPromptHidden = function()
            if self.harvest then
                self.harvest:Cancel()
                self.harvest = nil                
            end
        end
	})
    self.upgradePrompt = ProximityPromptHandler.new(self.model:WaitForChild("ImportantObjects"):WaitForChild("StationRoot"):WaitForChild("Interact"), {
        actionText = "Upgrade",
        objectText = "Clay Patch (Lvl " .. self.data.level .. ")",
        simple = true,
        left = true,
        priority = 1,
        onTriggered = function(player)
            self:OnUpgradeTriggered(player)
        end,
    })
end

function ClayPatch:SetupVisuals()
    self.visualMaid:DoCleaning()
    if self.data.level == 0 then
        local clayMesh = self.model:WaitForChild("Clay")
        local levelInfo = self.stationInfo.levelStats["0"]
        local originalPosition = clayMesh.Position
        local originalSize = clayMesh.Size

        local s = Fusion.scoped(Fusion)

        local sizeValue = s:Value(originalSize)
        local positionValue = s:Value(originalPosition)

        local sizeSpring = s:Spring(sizeValue, 5, 0.7)
        local positionSpring = s:Spring(positionValue, 5, 0.7)

        s:Hydrate(clayMesh) {
            Size = sizeSpring,
            Position = positionSpring,
        }

        self.visualMaid:GiveTask(self.__attributeChanged.Clay:Connect(function()
            if clayMesh then
                sizeValue:set(Vector3.new(4.075, self.__attributes.Clay / levelInfo.maxClay * 1.73, 4.343))
                positionValue:set(Vector3.new(originalPosition.X, originalPosition.Y + (self.__attributes.Clay / levelInfo.maxClay * 1.73) / 2, originalPosition.Z))
            end
        end))
    end
end

function ClayPatch:OnUpgradeTriggered(player: Player)
end

function ClayPatch:OnTriggered(player: Player)
    if self.harvest then
        if self.harvest:IsActive() == false then
            self.harvest:Cancel()
            self.harvest = nil
			self.harvest = Harvest:SetupHarvest(self.model.PrimaryPart.Position, function()
				HarvestClay:Call():After(function(success, result)
				end)
				self.harvest:Cancel()
				self.harvest = nil
			end, 2, 0.1)
			self.harvest:Attempt()
            return
        end
        
        self.harvest:Attempt()
    else
		self.harvest = Harvest:SetupHarvest(self.model.PrimaryPart.Position, function()
			HarvestClay:Call():After(function(success, result)
			end)
			self.harvest:Cancel()
            self.harvest = nil
		end, 2, 0.1)
        self.harvest:Attempt()
    end
end

function ClayPatch:Destroy()
    if self.proximityPromptObject then
        self.proximityPromptObject:Destroy()
    end
end

return ClayPatch
