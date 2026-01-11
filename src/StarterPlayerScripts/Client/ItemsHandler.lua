--[[
    ItemsHandler - Client-side handler for managing equipped items
    Used by Hotbar Functions to handle item equipping/unequipping/activation
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local Client = Player.PlayerScripts.Client
local Shared = ReplicatedStorage.Shared

local Items = require(Client.Items)
local Events = require(Shared.Events)
local Replication = require(Client.Replication)

local ActivateItem = Events.ActivateItem:Client()

local ItemsHandler = {}

-- Item class registry
ItemsHandler.ItemClasses = {
    Clay = Items.Clay,
}

-- Currently active item instance
ItemsHandler.CurrentItem = nil
ItemsHandler.CurrentItemName = nil

function ItemsHandler:GetItemClass(itemName: string)
    return self.ItemClasses[itemName] or Items.BaseItem
end

function ItemsHandler:EquipItem(itemName: string)
    -- Unequip current item if any
    if self.CurrentItem then
        self:UnequipItem()
    end
    
    if not itemName or itemName == "" then
        return
    end
    
    -- Create and equip new item
    local ItemClass = self:GetItemClass(itemName)
    
    if ItemClass == Items.BaseItem then
        self.CurrentItem = ItemClass.new(itemName)
    else
        self.CurrentItem = ItemClass.new()
    end
    
    self.CurrentItemName = itemName
    self.CurrentItem:Equip()
end

function ItemsHandler:UnequipItem()
    if self.CurrentItem then
        self.CurrentItem:Unequip()
        self.CurrentItem:Destroy()
        self.CurrentItem = nil
        self.CurrentItemName = nil
    end
end

function ItemsHandler:ActivateItem()
    if self.CurrentItem then
        self.CurrentItem:Activate()
        ActivateItem:Fire()
    end
end

function ItemsHandler:GetCurrentItem()
    return self.CurrentItem
end

function ItemsHandler:GetCurrentItemName(): string?
    return self.CurrentItemName
end

function ItemsHandler:Init()
    -- Listen for mouse click / tap to activate item
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.UserInputType == Enum.UserInputType.MouseButton1 
            or input.UserInputType == Enum.UserInputType.Touch then
            self:ActivateItem()
        end
    end)
    
    -- Listen for equipped item changes from server states
    task.spawn(function()
        local states = Replication:GetInfo("States", true)
        if states then
            states:OnSet({"equippedItem"}, function(newItemName)
                if newItemName then
                    self:EquipItem(newItemName)
                else
                    self:UnequipItem()
                end
            end)
            
            -- Initial equip if already equipped
            if states.Data.equippedItem then
                self:EquipItem(states.Data.equippedItem)
            end
        end
    end)
end

-- Initialize
ItemsHandler:Init()

return ItemsHandler
