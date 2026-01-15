local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Server = ServerScriptService.Server

local PlotStation = require(Shared.PlotStation)
local DataObject = require(Server.Datastore.DataObject)
local SharedConstants = require(Shared.Constants)
local InventoryManager = require(Server.InventoryManager)
local Events = require(Shared.Events)

local HarvestClay = Events.HarvestClay

local ClayPatch = {}
ClayPatch.__index = ClayPatch
setmetatable(ClayPatch, PlotStation)

-- Store all clay patch instances for the HarvestClay callback
ClayPatch.instances = {}

function ClayPatch.new(player: Player, stationModel: Model)
	local self = PlotStation.new(player, stationModel)
	setmetatable(self, ClayPatch)

    local playerData = DataObject.new(player)
    self.__attributes.Clay = playerData.potteryStations.ClayPatch.clay
    self.lastHarvest = game.Workspace:GetServerTimeNow()

    self:SetupPassiveGain()
    
    -- Register this instance for the HarvestClay callback
    ClayPatch.instances[player] = self
    
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
    -- Unregister this instance
    ClayPatch.instances[self.ownerPlayer] = nil
	self.maid:DoCleaning()
end

-- HarvestClay handler
HarvestClay:SetCallback(function(player: Player)
    local clayPatchInstance = ClayPatch.instances[player]
    if not clayPatchInstance then
        return "NoClayPatch"  
    end
    
    local playerData = DataObject.new(player, true).Replica
    local clayPatchData = SharedConstants.potteryStationInfo.ClayPatch.levelStats[tostring(clayPatchInstance.data.level)]

    if clayPatchInstance.ownerPlayer ~= player then
        return "NotOwner"
    end

    if game.Workspace:GetServerTimeNow() - clayPatchInstance.lastHarvest < clayPatchData.harvestCooldown then
        return "CooldownActive"
    end

    if clayPatchInstance.__attributes.Clay <= 0 then
        return "NoClay"
    end

    local clayToGive = clayPatchData.harvestAmount
    clayPatchInstance.__attributes.Clay = clayPatchInstance.__attributes.Clay - clayToGive
    clayPatchInstance.lastHarvest = game.Workspace:GetServerTimeNow()

    playerData:Set({"potteryStations", "ClayPatch", "clay"}, clayPatchInstance.__attributes.Clay)

    InventoryManager:AddItem(player, "Clay", clayToGive)

    return "Success"
end)

return ClayPatch
