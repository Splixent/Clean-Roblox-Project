local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Server = ServerScriptService.Server

local PlotStation = require(Shared.PlotStation)
local DataObject = require(Server.Datastore.DataObject)
local SharedConstants = require(Shared.Constants)
local InventoryManager = require(Server.InventoryManager)


local GlazeTable = {}
GlazeTable.__index = GlazeTable
setmetatable(GlazeTable, PlotStation)


function GlazeTable.new(player: Player, stationModel: Model)
	local self = PlotStation.new(player, stationModel)
	setmetatable(self, GlazeTable)

	return self
end

function GlazeTable:OnUpgradeTriggered(player: Player)

end

function GlazeTable:OnTriggered(player: Player)

end

function GlazeTable:Destroy()
	self.maid:DoCleaning()
end


return GlazeTable
