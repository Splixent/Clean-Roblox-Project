local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Server = ServerScriptService.Server

local PlotStation = require(Shared.PlotStation)
local DataObject = require(Server.Datastore.DataObject)
local SharedConstants = require(Shared.Constants)
local InventoryManager = require(Server.InventoryManager)


local Kiln = {}
Kiln.__index = Kiln
setmetatable(Kiln, PlotStation)


function Kiln.new(player: Player, stationModel: Model)
	local self = PlotStation.new(player, stationModel)
	setmetatable(self, Kiln)

	return self
end

function Kiln:OnUpgradeTriggered(player: Player)

end

function Kiln:OnTriggered(player: Player)

end

function Kiln:Destroy()
	self.maid:DoCleaning()
end


return Kiln
