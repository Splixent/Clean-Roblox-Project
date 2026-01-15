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

local CoolPottery = Events.CoolPottery
local CollectPottery = Events.CollectPottery
local DeletePottery = Events.DeletePottery

local CoolingTable = {}
CoolingTable.__index = CoolingTable
setmetatable(CoolingTable, PlotStation)

-- Track instances by owner player
CoolingTable.instances = {}

function CoolingTable.new(player: Player, stationModel: Model)
	local self = PlotStation.new(player, stationModel)
	setmetatable(self, CoolingTable)

	-- Register this instance
	CoolingTable.instances[self.ownerPlayer] = self

	-- Initialize cooling slots data in self.data (will be replicated via StationManager)
	self.data.coolingSlots = self:LoadCoolingSlots()

	return self
end

-- Load cooling slots from saved player data
function CoolingTable:LoadCoolingSlots()
	local playerData = DataObject.new(self.ownerPlayer, true).Replica
	local stationData = playerData.Data.potteryStations and playerData.Data.potteryStations.CoolingTable
	
	if stationData and stationData.coolingPottery then
		-- Convert saved data to slot format
		local slots = {}
		for slotIndex, potteryInfo in pairs(stationData.coolingPottery) do
			slots[slotIndex] = {
				styleKey = potteryInfo.styleKey,
				endTime = potteryInfo.endTime,
				itemName = potteryInfo.itemName,
			}
		end
		return slots
	end
	
	return {}
end

-- Get level stats for this cooling table
function CoolingTable:GetLevelStats()
	local level = tostring(self.data.level or 0)
	local stationInfo = SharedConstants.potteryStationInfo.CoolingTable
	if stationInfo and stationInfo.levelStats then
		return stationInfo.levelStats[level] or stationInfo.levelStats["0"]
	end
	return { maxSlots = 4, coolingTime = 60 }
end

-- Find next available slot
function CoolingTable:GetNextAvailableSlot(): number?
	local levelStats = self:GetLevelStats()
	local maxSlots = levelStats.maxSlots or 4
	local coolingSlots = self.data.coolingSlots or {}
	
	for i = 1, maxSlots do
		if not coolingSlots[tostring(i)] then
			return i
		end
	end
	return nil
end

-- Update replica data for cooling slots
function CoolingTable:UpdateReplicaData()
	local StationManager = require(script.Parent)
	print("CoolingTable: Updating replica data for", self.ownerPlayer.Name, "coolingSlots:", self.data.coolingSlots)
	StationManager:UpdateStationData(self.ownerPlayer, "CoolingTable", "coolingSlots", self.data.coolingSlots)
end

-- Save cooling data to player's persistent data
function CoolingTable:SaveToPlayerData()
	local playerData = DataObject.new(self.ownerPlayer, true).Replica
	local stationData = playerData.Data.potteryStations.CoolingTable or {}
	
	-- Convert slots to coolingPottery format for saving
	local coolingPottery = {}
	for slotIndex, slotData in pairs(self.data.coolingSlots or {}) do
		coolingPottery[slotIndex] = {
			itemName = slotData.itemName,
			styleKey = slotData.styleKey,
			startTime = slotData.startTime,
			endTime = slotData.endTime,
		}
	end
	
	stationData.coolingPottery = coolingPottery
	playerData:Set({"potteryStations", "CoolingTable"}, stationData)
end

-- Add pottery to cooling table
function CoolingTable:AddCoolingPottery(itemName: string, styleKey: string, dryingInfo: {clayType: string?, dryingStartTime: number?, dried: boolean?}?): (boolean, number?, number?)
	local slotIndex = self:GetNextAvailableSlot()
	if not slotIndex then
		return false, nil, nil -- No slots available
	end
	
	-- Get clay type from drying info or from style data
	local clayType = dryingInfo and dryingInfo.clayType
	if not clayType then
		local styleData = SharedConstants.pottteryData and SharedConstants.pottteryData[styleKey]
		clayType = styleData and styleData.clayType or "normal"
	end
	
	-- Calculate cooling time at runtime:
	-- baseCoolTime (clayType) × coolTimeMultiplier (style) × coolTimeMultiplier (station level)
	local levelStats = self:GetLevelStats()
	local stationCoolMultiplier = levelStats.coolTimeMultiplier or 1.0
	local coolingTime = ScriptUtils:CalculateCoolingDuration(clayType, styleKey, stationCoolMultiplier)
	
	-- Get current server time
	local startTime = os.time()
	local endTime = startTime + coolingTime
	
	-- Update data
	if not self.data.coolingSlots then
		self.data.coolingSlots = {}
	end
	
	-- Store slot data including drying info for visual updates
	local slotData = {
		itemName = itemName,
		styleKey = styleKey,
		startTime = startTime,
		endTime = endTime,
		clayType = clayType, -- Store for client-side duration calculations
		dryingStartTime = startTime, -- Drying starts when placed on table
		dried = dryingInfo and dryingInfo.dried or false, -- Copy dried status if already dried
	}
	
	self.data.coolingSlots[tostring(slotIndex)] = slotData
	
	-- Update replica for clients
	self:UpdateReplicaData()
	
	-- Save to persistent data
	self:SaveToPlayerData()
	
	return true, slotIndex, endTime
end

-- Check if a slot is ready for collection (cooling complete)
function CoolingTable:IsSlotReady(slotIndex: number): boolean
	local coolingSlots = self.data.coolingSlots or {}
	local slotData = coolingSlots[tostring(slotIndex)]
	
	if not slotData then return false end
	
	return os.time() >= slotData.endTime
end

-- Collect pottery from a slot
function CoolingTable:CollectPottery(slotIndex: number): (boolean, string?, string?, table?)
	local coolingSlots = self.data.coolingSlots or {}
	local slotData = coolingSlots[tostring(slotIndex)]
	
	if not slotData then
		return false, nil, "NoItemInSlot", nil
	end
	
	-- Check if cooling is complete
	if os.time() < slotData.endTime then
		return false, nil, "NotReady", nil
	end
	
	local styleKey = slotData.styleKey
	
	-- Check if drying is complete (calculate at runtime)
	-- Note: Pottery on the CoolingTable is drying (unfired), not cooling
	-- It needs to be fired in a Kiln before it can be "cooled"
	local levelStats = self:GetLevelStats()
	local dryTimeMultiplier = levelStats.dryTimeMultiplier or 1.0
	local dryingDuration = ScriptUtils:CalculateDryingDuration(slotData.clayType or "normal", styleKey, dryTimeMultiplier)
	local isDried = slotData.dried or ScriptUtils:IsDried(slotData.dryingStartTime, dryingDuration)
	
	-- Remove from data
	self.data.coolingSlots[tostring(slotIndex)] = nil
	
	-- Update replica for clients
	self:UpdateReplicaData()
	
	-- Save to persistent data
	self:SaveToPlayerData()
	
	-- Return slot data for use in callback
	-- Note: cooled is false because pottery must be fired first before it can cool
	return true, styleKey, nil, {
		clayType = slotData.clayType,
		dried = isDried,
		cooled = false, -- Cannot be cooled until fired in a Kiln
	}
end

function CoolingTable:OnUpgradeTriggered(player: Player)
end

function CoolingTable:OnTriggered(player: Player)
end

function CoolingTable:Destroy()
	-- Unregister this instance
	CoolingTable.instances[self.ownerPlayer] = nil
	self.maid:DoCleaning()
end


-- Handle CoolPottery event
CoolPottery:SetCallback(function(player, stationId)
	-- Find the cooling table instance for this player
	local instance = CoolingTable.instances[player]
	if not instance then
		return { success = false, error = "NoCoolingTable" }
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
	
	-- Check if it's a pottery item (unfired)
	local playerData = DataObject.new(player, true).Replica
	local inventory = playerData.Data.inventory
	local itemInfo = inventory and inventory.items and inventory.items[equippedItem]
	
	if not itemInfo or not itemInfo.potteryStyle then
		return { success = false, error = "NotPottery" }
	end
	
	-- Check if it's unfired
	if itemInfo.fired then
		return { success = false, error = "AlreadyFired" }
	end
	
	local styleKey = itemInfo.styleKey
	
	-- Extract drying info for visual updates (duration calculated at runtime by client)
	local dryingInfo = {
		clayType = itemInfo.clayType,
		dryingStartTime = itemInfo.dryingStartTime,
		dried = itemInfo.dried,
	}
	
	-- Add to cooling table with drying info
	local success, slotIndex, endTime = instance:AddCoolingPottery(equippedItem, styleKey, dryingInfo)
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

-- Handle CollectPottery event
CollectPottery:SetCallback(function(player, stationId, slotIndex)
	-- Find the cooling table instance for this player
	local instance = CoolingTable.instances[player]
	if not instance then
		return { success = false, error = "NoCoolingTable" }
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
	
	-- Add the collected pottery to player's inventory with proper state
	InventoryManager:AddPotteryItem(player, styleKey, function(itemData)
		itemData.clayType = collectedData.clayType
		itemData.dried = collectedData.dried
		itemData.cooled = collectedData.cooled
		return itemData
	end)
	
	return {
		success = true,
		styleKey = styleKey,
	}
end)

-- Handle DeletePottery event (remove from slot without adding to inventory)
DeletePottery:SetCallback(function(player, stationId, slotIndex)
	-- Find the cooling table instance for this player
	local instance = CoolingTable.instances[player]
	if not instance then
		return { success = false, error = "NoCoolingTable" }
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

return CoolingTable
