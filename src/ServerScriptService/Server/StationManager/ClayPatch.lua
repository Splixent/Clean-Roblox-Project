local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Server = ServerScriptService.Server

local PlotStation = require(Shared.PlotStation)
local DataObject = require(Server.Datastore.DataObject)

local ClayPatch = {}
ClayPatch.__index = ClayPatch
setmetatable(ClayPatch, PlotStation)

function ClayPatch.new(player: Player, stationModel: Model)
	local self = PlotStation.new(player, stationModel)
	setmetatable(self, ClayPatch)

    local playerData = DataObject.new(player)
    self.__attributes.Clay = playerData.potteryStations.ClayPatch.clay
    self.lastHarvest = game.Workspace:GetServerTimeNow()

    self:SetupPassiveGain()
    
	return self
end

function ClayPatch:SetupPassiveGain()
    self.maid:GiveTask(task.spawn(function()
        while true do
            task.wait(self.levelStats[tostring(self.data.level)].generateDelay)
            local levelInfo = self.levelStats[tostring(self.data.level)]
            local playerData = DataObject.new(self.ownerPlayer, true).Replica

            if self.__attributes.Clay + levelInfo.clayPerInterval > levelInfo.maxClay then
                self.__attributes.Clay = levelInfo.maxClay
                playerData:Set({"potteryStations", "ClayPatch", "clay"}, levelInfo.maxClay)
            else
                self.__attributes.Clay += levelInfo.clayPerInterval
				playerData:Set({ "potteryStations", "ClayPatch", "clay" }, self.__attributes.Clay)
            end
        end
    end))
end

function ClayPatch:OnUpgradeTriggered(player: Player)

end

function ClayPatch:OnTriggered(player: Player)

end

function ClayPatch:Destroy()
	self.maid:DoCleaning()
end



return ClayPatch
