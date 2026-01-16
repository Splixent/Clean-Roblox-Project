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
local GlazePottery = Events.GlazePottery

local InventoryManager = {}

-- Item class registry
InventoryManager.ItemClasses = {
    Clay = Items.Clay,
}

-- Active item instances per player
InventoryManager.PlayerItems = {}

-- Extract the style key from a unique pottery item key (e.g., "bowl_1" -> "bowl")
function InventoryManager:GetStyleKey(itemName: string): string
    local styleKey = itemName:match("^(.+)_%d+$")
    if styleKey and SharedConstants.pottteryData and SharedConstants.pottteryData[styleKey] then
        return styleKey
    end
    return itemName
end

function InventoryManager:GetItemClass(itemName: string)
    -- Check if it's a registered item class
    if self.ItemClasses[itemName] then
        return self.ItemClasses[itemName]
    end
    
    -- Check if it's a pottery style (including unique keys like "bowl_1")
    local styleKey = self:GetStyleKey(itemName)
    if SharedConstants.pottteryData and SharedConstants.pottteryData[styleKey] then
        return Items.PotteryStyle
    end
    
    return Items.BaseItem
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

    playerData:Set({"inventory"}, inventory)
end

-- Generate a unique key for pottery items
function InventoryManager:GeneratePotteryKey(inventory, styleKey: string): string
    -- Find the next available number for this style
    local counter = 1
    while inventory.items[styleKey .. "_" .. counter] ~= nil do
        counter = counter + 1
    end
    return styleKey .. "_" .. counter
end

-- Add a pottery item (uses potteryData instead of itemData, stored with potteryStyle = true)
-- Each pottery item gets a unique key like "bowl_1", "bowl_2" to allow multiple of same type
function InventoryManager:AddPotteryItem(player: Player, styleKey: string, customizeFunc: (any) -> ())
    local playerData = DataObject.new(player, true).Replica
    local inventory = playerData.Data.inventory

    local potteryData = SharedConstants.pottteryData and SharedConstants.pottteryData[styleKey]
    if not potteryData then
        warn(`InventoryManager:AddPotteryItem - Unknown pottery style '{styleKey}'`)
        return false
    end

    -- Generate a unique key for this pottery item
    local uniqueKey = self:GeneratePotteryKey(inventory, styleKey)

    -- Pottery items are stored with potteryStyle = true flag and styleKey for lookups
    inventory.items[uniqueKey] = {
        potteryStyle = true,
        styleKey = styleKey,  -- Store the original style key for looking up potteryData
        amount = 1,
    }

    if customizeFunc then
        inventory.items[uniqueKey] = customizeFunc(inventory.items[uniqueKey])
    end

    -- Add to hotbar if there's room
    if #inventory.hotbar < 10 then
        table.insert(inventory.hotbar, uniqueKey)
    end

    playerData:Set({"inventory"}, inventory)
    return true
end

function InventoryManager:GetEquippedItem(player: Player): string?
    local playerStates = PlayerEntityManager.new(player, true).Replica
    local equippedData = playerStates.Data.equippedItem
    -- equippedItem is stored as a table with itemName property, or nil
    if equippedData and equippedData.itemName then
        return equippedData.itemName
    end
    return nil
end

function InventoryManager:HasItem(player: Player, itemName: string): boolean
    local playerData = DataObject.new(player, true).Replica
    if not playerData or not playerData.Data then return false end
    
    local inventory = playerData.Data.inventory
    if not inventory or not inventory.items then return false end
    
    local itemInfo = inventory.items[itemName]
    if not itemInfo then return false end
    
    -- Pottery items have potteryStyle = true, regular items have amount
    if itemInfo.potteryStyle then
        return true
    end
    
    return itemInfo.amount and itemInfo.amount > 0
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

-- Remove a pottery item completely (for cooling table, etc.)
function InventoryManager:RemovePotteryItem(player: Player, itemName: string): boolean
    local playerData = DataObject.new(player, true).Replica
    if not playerData or not playerData.Data then return false end
    
    local inventory = playerData.Data.inventory
    if not inventory or not inventory.items then return false end
    
    local itemInfo = inventory.items[itemName]
    if not itemInfo then return false end
    
    -- Remove from inventory
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
    
    if ItemClass == Items.BaseItem or ItemClass == Items.PotteryStyle then
        -- BaseItem and PotteryStyle need the item name
        itemInstance = ItemClass.new(player, itemName)
    else
        -- Specific item classes like Clay don't need the name
        itemInstance = ItemClass.new(player)
    end
    
    self.PlayerItems[player] = itemInstance
    itemInstance:Equip()
    
    -- Update player state - store itemName along with item data for easy lookup
    local playerStates = PlayerEntityManager.new(player, true).Replica
    
    -- Check if it's a regular item or a pottery item (use style key for pottery lookup)
    local styleKey = self:GetStyleKey(itemName)
    local sourceData = SharedConstants.itemData[itemName]
    if not sourceData then
        -- Check if it's a pottery style (using extracted style key for unique IDs)
        sourceData = SharedConstants.pottteryData and SharedConstants.pottteryData[styleKey]
    end
    
    if sourceData then
        local equippedData = table.clone(sourceData)
        equippedData.itemName = itemName -- Store the item name (unique key) for comparison
        playerStates:Set({"equippedItem"}, equippedData)
    else
        -- Fallback - just store the item name
        playerStates:Set({"equippedItem"}, { itemName = itemName })
    end
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

-- Update dried flag for a specific pottery item when drying is complete
-- NOTE: Drying now only happens on CoolingTable, so this is deprecated
function InventoryManager:UpdateDriedStatus(player: Player, itemName: string): boolean
    local playerData = DataObject.new(player, true)
    if not playerData or not playerData.Replica or not playerData.Replica.Data then
        return false
    end
    
    local inventory = playerData.Replica.Data.inventory
    if not inventory or not inventory.items then
        return false
    end
    
    local itemInfo = inventory.items[itemName]
    if not itemInfo or not itemInfo.potteryStyle then
        return false
    end
    
    -- Already dried
    if itemInfo.dried then
        return true
    end
    
    -- Drying only happens on CoolingTable now, not in inventory
    return false
end

-- Check and update dried status for all pottery items in a player's inventory
-- NOTE: Drying now only happens on CoolingTable, so this is deprecated
function InventoryManager:CheckAllDryingStatus(player: Player)
    -- Drying only happens on CoolingTable now, no need to check inventory items
end

-- No need for periodic drying checks since drying only happens on CoolingTable

-- Apply glaze to a pottery item (color, pattern, finish)
function InventoryManager:ApplyGlaze(player: Player, itemKey: string, glazeData: {color: string?, pattern: string?, finish: string?}): boolean
    local playerData = DataObject.new(player, true)
    if not playerData or not playerData.Replica or not playerData.Replica.Data then
        return false
    end
    
    local inventory = playerData.Replica.Data.inventory
    if not inventory or not inventory.items then
        return false
    end
    
    local itemInfo = inventory.items[itemKey]
    if not itemInfo or not itemInfo.potteryStyle then
        warn(`[InventoryManager] {player.Name} tried to glaze {itemKey} but it's not a pottery item`)
        return false
    end
    
    -- Validate glaze data against constants
    if glazeData.color then
        local colorFound = false
        for _, colorData in ipairs(SharedConstants.glazeTypes.colors) do
            if colorData.name == glazeData.color then
                colorFound = true
                break
            end
        end
        if not colorFound then
            warn(`[InventoryManager] Invalid glaze color: {glazeData.color}`)
            return false
        end
    end
    
    if glazeData.pattern and glazeData.pattern ~= "noPattern" then
        local patternFound = false
        
        -- Check global patterns
        for _, patternData in ipairs(SharedConstants.glazeTypes.patterns) do
            if patternData.name == glazeData.pattern then
                patternFound = true
                break
            end
        end
        
        -- Check style-unique patterns if not found in global patterns
        if not patternFound and itemInfo.styleKey then
            local styleKey = itemInfo.styleKey
            if SharedConstants.glazeTypes.uniquePatterns and SharedConstants.glazeTypes.uniquePatterns[styleKey] then
                local styleUniqueData = SharedConstants.glazeTypes.uniquePatterns[styleKey]
                if styleUniqueData.patterns then
                    -- Handle both single pattern object and array of patterns
                    local patternsToCheck = styleUniqueData.patterns
                    for _, patternInfo in ipairs(patternsToCheck) do
                        if patternInfo.name == glazeData.pattern then
                            patternFound = true
                            break
                        end
                    end
                end
            end
        end
        
        if not patternFound then
            warn(`[InventoryManager] Invalid glaze pattern: {glazeData.pattern}`)
            return false
        end
    end
    
    if glazeData.finish then
        local finishFound = false
        
        -- Check global finishes
        for _, finishData in ipairs(SharedConstants.glazeTypes.finishes) do
            if finishData.name == glazeData.finish then
                finishFound = true
                break
            end
        end
        
        -- Check style-unique pattern finishes if not found in global finishes
        if not finishFound and itemInfo.styleKey and glazeData.pattern then
            local styleKey = itemInfo.styleKey
            if SharedConstants.glazeTypes.uniquePatterns and SharedConstants.glazeTypes.uniquePatterns[styleKey] then
                local styleUniqueData = SharedConstants.glazeTypes.uniquePatterns[styleKey]
                if styleUniqueData.patterns then
                    local patternsToCheck = styleUniqueData.patterns
                    if patternsToCheck.name then
                        -- Single pattern object
                        if patternsToCheck.name == glazeData.pattern and patternsToCheck.finishes then
                            local finishesToCheck = patternsToCheck.finishes
                            if finishesToCheck.name then
                                -- Single finish object
                                if finishesToCheck.name == glazeData.finish then
                                    finishFound = true
                                end
                            else
                                -- Array of finishes
                                for _, finishData in ipairs(finishesToCheck) do
                                    if finishData.name == glazeData.finish then
                                        finishFound = true
                                        break
                                    end
                                end
                            end
                        end
                    else
                        -- Array of patterns
                        for _, patternData in ipairs(patternsToCheck) do
                            if patternData.name == glazeData.pattern and patternData.finishes then
                                local finishesToCheck = patternData.finishes
                                if finishesToCheck.name then
                                    if finishesToCheck.name == glazeData.finish then
                                        finishFound = true
                                    end
                                else
                                    for _, finishData in ipairs(finishesToCheck) do
                                        if finishData.name == glazeData.finish then
                                            finishFound = true
                                            break
                                        end
                                    end
                                end
                                break
                            end
                        end
                    end
                end
            end
        end
        
        if not finishFound then
            warn(`[InventoryManager] Invalid glaze finish: {glazeData.finish}`)
            return false
        end
    end
    
    -- Apply glaze data to the item
    itemInfo.glaze = {
        color = glazeData.color,
        pattern = glazeData.pattern or "noPattern",
        finish = glazeData.finish,
    }
    itemInfo.glazed = true
    
    -- Save the updated inventory
    playerData.Replica:Set({"inventory"}, inventory)
    
    -- Update the held item's visual if it's currently equipped
    local playerItem = self.PlayerItems[player]
    if playerItem and playerItem.UniqueKey == itemKey and playerItem.UpdateToolColor then
        playerItem:UpdateToolColor()
    end
    
    return true
end

-- Handle glaze pottery event from client
GlazePottery:SetCallback(function(player, itemKey, glazeData)
    if not itemKey or not glazeData then
        return false
    end
    
    return InventoryManager:ApplyGlaze(player, itemKey, glazeData)
end)

-- Clean up when player leaves
Players.PlayerRemoving:Connect(function(player)
    if InventoryManager.PlayerItems[player] then
        InventoryManager.PlayerItems[player]:Destroy()
        InventoryManager.PlayerItems[player] = nil
    end
end)

return InventoryManager
