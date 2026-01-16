local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Client = Players.LocalPlayer.PlayerScripts.Client

local PlotStation = require(Shared.PlotStation)
local ProximityPromptHandler = require(Client.ProximityPromptHandler)
local Replication = require(Client.Replication)

local GlazeTableUI = require(Client.UI.Components.GlazeTable.Functions)

local GlazeTable = {}
GlazeTable.__index = GlazeTable
setmetatable(GlazeTable, PlotStation)

function GlazeTable.new(player: Player, stationModel: Model)
    local self = PlotStation.new(player, stationModel)
    setmetatable(self, GlazeTable)
    
    -- Track if this client is the owner
    self.isOwner = self.ownerPlayer.UserId == self.player.UserId
    
    -- Connection for tracking unequip
    self.unequipConnection = nil
    
    -- Only setup interaction for the owner
    if self.isOwner then
        self:SetupInteraction()
    end
    
    return self
end

function GlazeTable:SetupInteraction()
    self.createPrompt = ProximityPromptHandler.new(self.model:WaitForChild("ImportantObjects"):WaitForChild("StationRoot"):WaitForChild("Interact"), {
		actionText = "Glaze Pottery",
		objectText = "Glaze Table (Lvl " .. self.data.level .. ")",
        priority = 1,
		onTriggered = function(player)
			self:OnTriggered(player)
		end,
	})
    self.upgradePrompt = ProximityPromptHandler.new(self.model:WaitForChild("ImportantObjects"):WaitForChild("StationRoot"):WaitForChild("Interact"), {
        actionText = "Upgrade",
        objectText = "Glaze Table (Lvl " .. self.data.level .. ")",
        simple = true,
        left = true,
        priority = 1,
        onTriggered = function(player)
            self:OnUpgradeTriggered(player)
        end,
    })
end

function GlazeTable:SetupVisuals() end

function GlazeTable:OnUpgradeTriggered(player: Player)
end

-- Check if the player is holding cooled pottery (fired and cooled, ready for glazing)
function GlazeTable:IsHoldingCooledPottery(): (boolean, string?, string?)
    local states = Replication:GetInfo("States", true)
    if not states then return false, nil, nil end
    
    local equippedItem = states.Data.equippedItem
    if not equippedItem then return false, nil, nil end
    
    local itemName = equippedItem.itemName
    if not itemName then return false, nil, nil end
    
    local playerData = Replication:GetInfo("Data")
    if not playerData then return false, nil, nil end
    
    local inventory = playerData.inventory
    if not inventory or not inventory.items then return false, nil, nil end
    
    local itemInfo = inventory.items[itemName]
    if not itemInfo then return false, nil, nil end
    
    -- Must be pottery
    if not itemInfo.potteryStyle then return false, nil, nil end
    -- Must be fired
    if not itemInfo.fired then return false, nil, nil end
    -- Must be cooled
    if not itemInfo.cooled then return false, nil, nil end
    -- Must not already be glazed
    if itemInfo.glazed then return false, nil, nil end
    
    return true, itemName, itemInfo.styleKey
end

function GlazeTable:OnTriggered(player: Player)
    -- Check if player is holding valid pottery
    local isValid, potteryItemKey, styleKey = self:IsHoldingCooledPottery()
    if not isValid then
        warn("GlazeTable: Must be holding cooled pottery to use the glaze table")
        return
    end
    
    -- Track the current pottery item key for unequip detection
    self.currentPotteryKey = potteryItemKey
    
    -- Listen for unequip to close the menu
    self:ListenForUnequip()
    
    -- Open the Glaze Table UI
    GlazeTableUI:Show(
        potteryItemKey,
        styleKey,
        function(selection)
            -- Called when player confirms glaze selection
            -- Disconnect unequip listener
            self:StopListeningForUnequip()
        end,
        function()
            -- Called when UI is closed
            -- Disconnect unequip listener
            self:StopListeningForUnequip()
        end
    )
end

-- Listen for pottery unequip to close the menu
function GlazeTable:ListenForUnequip()
    -- Disconnect any existing connection
    self:StopListeningForUnequip()
    
    local states = Replication:GetInfo("States", true)
    if not states then return end
    
    self.unequipConnection = states:OnSet({"equippedItem"}, function(newEquippedItem)
        -- If item changed or unequipped, close the menu
        if not newEquippedItem or newEquippedItem.itemName ~= self.currentPotteryKey then
            GlazeTableUI:Close()
            self:StopListeningForUnequip()
        end
    end)
end

-- Stop listening for unequip
function GlazeTable:StopListeningForUnequip()
    if self.unequipConnection then
        self.unequipConnection:Disconnect()
        self.unequipConnection = nil
    end
    self.currentPotteryKey = nil
end

function GlazeTable:Destroy()
    self:StopListeningForUnequip()
    if self.proximityPromptObject then
        self.proximityPromptObject:Destroy()
    end
end

return GlazeTable
