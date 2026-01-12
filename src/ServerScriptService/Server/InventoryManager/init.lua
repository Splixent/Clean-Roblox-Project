--[[
    InventoryManager - Server-side inventory and item management
    Handles item adding, equipping, unequipping, and activation
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Server = ServerScriptService.Server

local DataObject = require(Server.Datastore.DataObject)
local PlayerEntityManager = require(Server.PlayerEntityManager)
local ScriptUtils = require(Shared.ScriptUtils)
local Events = require(Shared.Events)
local Maid = require(Shared.Maid)
local SharedConstants = require(Shared.Constants)

local Items = require(script.Items)

local EquipItem = Events.EquipItem:Server()
local ActivateItem = Events.ActivateItem:Server()

local InventoryManager = {}

-- Item class registry
InventoryManager.ItemClasses = {
    Clay = Items.Clay,
}

-- Active item instances per player
InventoryManager.PlayerItems = {}

function InventoryManager:GetItemClass(itemName: string)
    return self.ItemClasses[itemName] or Items.BaseItem
end

function InventoryManager:AddItem(player: Player, itemName: string, quantity: number)
    local playerData = DataObject.new(player, true).Replica
    local inventory = playerData.Data.inventory

    local itemData = SharedConstants.itemData[itemName]
    if not itemData then
        warn(`InventoryManager:AddItem - Unknown item '{itemName}'`)
        return
    end

    if inventory.items[itemName] == nil then
        inventory.items[itemName] = {
            amount = quantity,
        }
    else
        inventory.items[itemName].amount = math.min(inventory.items[itemName].amount + quantity, itemData.maxStackSize)
    end

    if #inventory.hotbar < 10 then
        if table.find(inventory.hotbar, itemName) == nil then
            table.insert(inventory.hotbar, itemName)
        end     
    end

    print(inventory)
    playerData:Set({"inventory"}, inventory)
end

function InventoryManager:GetEquippedItem(player: Player): string?
    local playerStates = PlayerEntityManager.new(player, true).Replica
    return playerStates.Data.equippedItem
end

function InventoryManager:HasItem(player: Player, itemName: string): boolean
    local playerData = DataObject.new(player, true).Replica
    if not playerData or not playerData.Data then return false end
    
    local inventory = playerData.Data.inventory
    if not inventory or not inventory.items then return false end
    
    local itemInfo = inventory.items[itemName]
    return itemInfo ~= nil and itemInfo.amount > 0
end

function InventoryManager:ConsumeItem(player: Player, itemName: string, amount: number?): boolean
    amount = amount or 1
    
    local playerData = DataObject.new(player, true).Replica
    if not playerData or not playerData.Data then return false end
    
    local inventory = playerData.Data.inventory
    if not inventory or not inventory.items then return false end
    
    local itemInfo = inventory.items[itemName]
    if not itemInfo or itemInfo.amount < amount then return false end
    
    itemInfo.amount = itemInfo.amount - amount
    
    -- Remove from inventory if depleted
    if itemInfo.amount <= 0 then
        inventory.items[itemName] = nil
        
        -- Remove from hotbar
        local hotbarIndex = table.find(inventory.hotbar, itemName)
        if hotbarIndex then
            table.remove(inventory.hotbar, hotbarIndex)
        end
        
        -- Unequip if this was the equipped item
        local playerStates = PlayerEntityManager.new(player, true).Replica
        local equippedItem = playerStates.Data.equippedItem
        if equippedItem and equippedItem.itemName == itemName then
            self:UnequipItem(player)
        end
    end

    playerData:Set({"inventory"}, inventory)
    return true
end

function InventoryManager:EquipItem(player: Player, itemName: string)
    -- Unequip current item first
    self:UnequipItem(player)
    
    if not itemName or itemName == "" then
        return
    end
    
    -- Validate player has the item
    if not self:HasItem(player, itemName) then
        warn(`[InventoryManager] {player.Name} tried to equip {itemName} but doesn't have it`)
        return
    end
    
    -- Create item instance
    local ItemClass = self:GetItemClass(itemName)
    local itemInstance
    
    if ItemClass == Items.BaseItem then
        itemInstance = ItemClass.new(player, itemName)
    else
        itemInstance = ItemClass.new(player)
    end
    
    self.PlayerItems[player] = itemInstance
    itemInstance:Equip()
    
    -- Update player state - store itemName along with item data for easy lookup
    local playerStates = PlayerEntityManager.new(player, true).Replica
    local equippedData = table.clone(SharedConstants.itemData[itemName])
    equippedData.itemName = itemName -- Store the item name for comparison
    playerStates:Set({"equippedItem"}, equippedData)
end

function InventoryManager:UnequipItem(player: Player)
    local itemInstance = self.PlayerItems[player]
    if itemInstance then
        itemInstance:Unequip()
        itemInstance:Destroy()
        self.PlayerItems[player] = nil
    end
    
    -- Update player state
    local playerStates = PlayerEntityManager.new(player, true).Replica
    playerStates:Set({"equippedItem"}, nil)
end

function InventoryManager:ActivateItem(player: Player)
    local itemInstance = self.PlayerItems[player]
    if itemInstance then
        itemInstance:Activate()
    end
end

function InventoryManager:GetPlayerItem(player: Player)
    return self.PlayerItems[player]
end

-- Handle equip item event from client
EquipItem:On(function(player, slotNumber)
    local playerData = DataObject.new(player, true).Replica
    if not playerData or not playerData.Data then return end
    
    local inventory = playerData.Data.inventory
    if not inventory then return end
    
    local hotbar = inventory.hotbar or {}
    
    if slotNumber == 0 then
        -- Unequip
        InventoryManager:UnequipItem(player)
    else
        local itemName = hotbar[slotNumber]
        if itemName and inventory.items and inventory.items[itemName] then
            InventoryManager:EquipItem(player, itemName)
        end
    end
end)

-- Handle activate item event from client
ActivateItem:On(function(player)
    local equippedItem = InventoryManager:GetEquippedItem(player)
    
    if not equippedItem then
        return
    end
    
    if not InventoryManager:HasItem(player, equippedItem) then
        warn(`[InventoryManager] {player.Name} tried to activate {equippedItem} but doesn't have it`)
        return
    end
    
    InventoryManager:ActivateItem(player)
end)

-- Clean up when player leaves
Players.PlayerRemoving:Connect(function(player)
    if InventoryManager.PlayerItems[player] then
        InventoryManager.PlayerItems[player]:Destroy()
        InventoryManager.PlayerItems[player] = nil
    end
end)

return InventoryManager
