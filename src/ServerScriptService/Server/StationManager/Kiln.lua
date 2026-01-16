local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Server = ServerScriptService.Server

local PlotStation = require(Shared.PlotStation)
local DataObject = require(Server.Datastore.DataObject)
local SharedConstants = require(Shared.Constants)
local ScriptUtils = require(Shared.ScriptUtils)
local InventoryManager = require(Server.InventoryManager)
local Events = require(Shared.Events)

local FirePottery = Events.FirePottery
local CollectKilnPottery = Events.CollectKilnPottery
local DeleteKilnPottery = Events.DeleteKilnPottery

local Kiln = {}
Kiln.__index = Kiln
setmetatable(Kiln, PlotStation)

-- Track instances by owner player
Kiln.instances = {}

function Kiln.new(player: Player, stationModel: Model)
	local self = PlotStation.new(player, stationModel)
	setmetatable(self, Kiln)

	-- Register this instance
	Kiln.instances[self.ownerPlayer] = self

	-- Initialize kiln slots data in self.data (will be replicated via StationManager)
	self.data.kilnSlots = self:LoadKilnSlots()

	return self
end

-- Load kiln slots from saved player data
function Kiln:LoadKilnSlots()
	local playerData = DataObject.new(self.ownerPlayer, true).Replica
	local stationData = playerData.Data.potteryStations and playerData.Data.potteryStations.Kiln
	
	if stationData and stationData.firingPottery then
		-- Convert saved data to slot format
		local slots = {}
		for slotIndex, potteryInfo in pairs(stationData.firingPottery) do
			slots[slotIndex] = {
				styleKey = potteryInfo.styleKey,
				clayType = potteryInfo.clayType,
				startTime = potteryInfo.startTime,
				endTime = potteryInfo.endTime,
				itemName = potteryInfo.itemName,
			}
		end
		return slots
	end
	
	return {}
end

-- Get level stats for this kiln
function Kiln:GetLevelStats()
	local level = tostring(self.data.level or 0)
	local stationInfo = SharedConstants.potteryStationInfo.Kiln
	if stationInfo and stationInfo.levelStats then
		return stationInfo.levelStats[level] or stationInfo.levelStats["0"]
	end
	return { maxSlots = 2, fireTimeMultiplier = 1.0 }
end

-- Find next available slot
function Kiln:GetNextAvailableSlot(): number?
	local levelStats = self:GetLevelStats()
	local maxSlots = levelStats.maxSlots or 2
	local kilnSlots = self.data.kilnSlots or {}
	
	for i = 1, maxSlots do
		if not kilnSlots[tostring(i)] then
			return i
		end
	end
	return nil
end

-- Update replica data for kiln slots
function Kiln:UpdateReplicaData()
	local StationManager = require(script.Parent)
	StationManager:UpdateStationData(self.ownerPlayer, "Kiln", "kilnSlots", self.data.kilnSlots)
end

-- Save kiln data to player's persistent data
function Kiln:SaveToPlayerData()
	local playerData = DataObject.new(self.ownerPlayer, true).Replica
	
	-- Ensure potteryStations exists
	if not playerData.Data.potteryStations then
		playerData:Set({"potteryStations"}, {})
	end
	
	local stationData = playerData.Data.potteryStations.Kiln or {}
	
	-- Convert slots to firingPottery format for saving
	local firingPottery = {}
	for slotIndex, slotData in pairs(self.data.kilnSlots or {}) do
		firingPottery[slotIndex] = {
			itemName = slotData.itemName,
			styleKey = slotData.styleKey,
			clayType = slotData.clayType,
			startTime = slotData.startTime,
			endTime = slotData.endTime,
		}
	end
	
	stationData.firingPottery = firingPottery
	playerData:Set({"potteryStations", "Kiln"}, stationData)
end

-- Add pottery to kiln for firing
function Kiln:AddFiringPottery(itemName: string, styleKey: string, potteryInfo: {clayType: string?, dried: boolean?}?): (boolean, number?, number?)
	local slotIndex = self:GetNextAvailableSlot()
	if not slotIndex then
		return false, nil, nil -- No slots available
	end
	
	-- Get clay type from pottery info or from style data
	local clayType = potteryInfo and potteryInfo.clayType
	if not clayType then
		local styleData = SharedConstants.pottteryData and SharedConstants.pottteryData[styleKey]
		clayType = styleData and styleData.clayType or "normal"
	end
	
	-- Calculate firing time at runtime
	local levelStats = self:GetLevelStats()
	local stationFireMultiplier = levelStats.fireTimeMultiplier or 1.0
	local firingTime = ScriptUtils:CalculateFiringDuration(clayType, styleKey, stationFireMultiplier)
	
	-- Get current server time
	local startTime = os.time()
	local endTime = startTime + firingTime
	
	-- Update data
	if not self.data.kilnSlots then
		self.data.kilnSlots = {}
	end
	
	-- Store slot data
	local slotData = {
		itemName = itemName,
		styleKey = styleKey,
		clayType = clayType,
		startTime = startTime,
		endTime = endTime,
	}
	
	self.data.kilnSlots[tostring(slotIndex)] = slotData
	
	-- Update replica for clients
	self:UpdateReplicaData()
	
	-- Save to persistent data
	self:SaveToPlayerData()
	
	return true, slotIndex, endTime
end

-- Check if a slot is ready for collection (firing complete)
function Kiln:IsSlotReady(slotIndex: number): boolean
	local kilnSlots = self.data.kilnSlots or {}
	local slotData = kilnSlots[tostring(slotIndex)]
	
	if not slotData then return false end
	
	return os.time() >= slotData.endTime
end

-- Collect pottery from a slot
function Kiln:CollectPottery(slotIndex: number): (boolean, string?, string?, table?)
	local kilnSlots = self.data.kilnSlots or {}
	local slotData = kilnSlots[tostring(slotIndex)]
	
	if not slotData then
		return false, nil, "NoItemInSlot", nil
	end
	
	-- Check if firing is complete
	if os.time() < slotData.endTime then
		return false, nil, "NotReady", nil
	end
	
	local styleKey = slotData.styleKey
	
	-- Remove from data
	self.data.kilnSlots[tostring(slotIndex)] = nil
	
	-- Update replica for clients
	self:UpdateReplicaData()
	
	-- Save to persistent data
	self:SaveToPlayerData()
	
	-- Return slot data for use in callback
	-- Pottery is now fired, needs to be cooled on CoolingTable
	return true, styleKey, nil, {
		clayType = slotData.clayType,
		dried = true, -- Was already dried before firing
		fired = true,
		cooled = false, -- Needs to be cooled on CoolingTable after firing
	}
end

function Kiln:OnUpgradeTriggered(player: Player)
end

function Kiln:OnTriggered(player: Player)
end

function Kiln:Destroy()
	-- Unregister this instance
	Kiln.instances[self.ownerPlayer] = nil
	self.maid:DoCleaning()
end


-- Handle FirePottery event
FirePottery:SetCallback(function(player, stationId)
	-- Find the kiln instance for this player
	local instance = Kiln.instances[player]
	if not instance then
		return { success = false, error = "NoKiln" }
	end
	
	-- Verify station ID matches
	local modelStationId = instance.model:GetAttribute("StationId") or instance.model.Name
	if modelStationId ~= stationId then
		return { success = false, error = "WrongStation" }
	end
	
	-- Get equipped item
	local equippedItem = InventoryManager:GetEquippedItem(player)
	if not equippedItem then
		return { success = false, error = "NoPotteryEquipped" }
	end
	
	-- Check if it's a pottery item
	local playerData = DataObject.new(player, true).Replica
	local inventory = playerData.Data.inventory
	local itemInfo = inventory and inventory.items and inventory.items[equippedItem]
	
	if not itemInfo or not itemInfo.potteryStyle then
		return { success = false, error = "NotPottery" }
	end
	
	-- Check if it's already fired
	if itemInfo.fired then
		return { success = false, error = "AlreadyFired" }
	end
	
	-- Check if it's dried (must be dried before firing)
	if not itemInfo.dried then
		return { success = false, error = "NotDried" }
	end
	
	local styleKey = itemInfo.styleKey
	
	-- Extract pottery info
	local potteryInfo = {
		clayType = itemInfo.clayType,
		dried = itemInfo.dried,
	}
	
	-- Add to kiln
	local success, slotIndex, endTime = instance:AddFiringPottery(equippedItem, styleKey, potteryInfo)
	if not success then
		return { success = false, error = "NoSlotsAvailable" }
	end
	
	-- Remove from inventory
	InventoryManager:RemovePotteryItem(player, equippedItem)
	
	return {
		success = true,
		slotIndex = slotIndex,
		endTime = endTime,
		styleKey = styleKey,
	}
end)

-- Handle CollectKilnPottery event
CollectKilnPottery:SetCallback(function(player, stationId, slotIndex)
	-- Find the kiln instance for this player
	local instance = Kiln.instances[player]
	if not instance then
		return { success = false, error = "NoKiln" }
	end
	
	-- Verify station ID matches
	local modelStationId = instance.model:GetAttribute("StationId") or instance.model.Name
	if modelStationId ~= stationId then
		return { success = false, error = "WrongStation" }
	end
	
	-- Collect the pottery
	local success, styleKey, errorMsg, collectedData = instance:CollectPottery(slotIndex)
	if not success then
		return { success = false, error = errorMsg }
	end
	
	-- Add the collected pottery to player's inventory with fired state
	InventoryManager:AddPotteryItem(player, styleKey, function(itemData)
		itemData.clayType = collectedData.clayType
		itemData.dried = collectedData.dried
		itemData.fired = collectedData.fired
		itemData.cooled = collectedData.cooled
		return itemData
	end)
	
	return {
		success = true,
		styleKey = styleKey,
	}
end)

-- Handle DeleteKilnPottery event (remove from slot without adding to inventory)
DeleteKilnPottery:SetCallback(function(player, stationId, slotIndex)
	-- Find the kiln instance for this player
	local instance = Kiln.instances[player]
	if not instance then
		return { success = false, error = "NoKiln" }
	end
	
	-- Verify station ID matches
	local modelStationId = instance.model:GetAttribute("StationId") or instance.model.Name
	if modelStationId ~= stationId then
		return { success = false, error = "WrongStation" }
	end
	
	-- Collect the pottery (removes from slot) but don't add to inventory
	local success, styleKey, errorMsg = instance:CollectPottery(slotIndex)
	if not success then
		return { success = false, error = errorMsg }
	end
	
	-- Don't add to inventory - pottery is deleted
	return {
		success = true,
		styleKey = styleKey,
		deleted = true,
	}
end)

return Kiln
