local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Client = Players.LocalPlayer.PlayerScripts.Client

local ScriptUtils = require(ReplicatedStorage.Shared.ScriptUtils)
local Fusion = require(Shared.Fusion)
local Events = require(Shared.Events)
local Replication = require(Client.Replication)
local SharedConstants = require(Shared.Constants)

local EquipItem = Events.EquipItem:Client()

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

local Functions = {}

-- Constants
Functions.MAX_HOTBAR_SLOTS = 10
Functions.SLOT_SIZE_NORMAL = UDim2.fromScale(0.0799361, 0.8)
Functions.SLOT_SIZE_EQUIPPED = UDim2.fromScale(0.0899361, 0.9)

Functions.KEY_MAP = {
    [Enum.KeyCode.One] = 1,
    [Enum.KeyCode.Two] = 2,
    [Enum.KeyCode.Three] = 3,
    [Enum.KeyCode.Four] = 4,
    [Enum.KeyCode.Five] = 5,
    [Enum.KeyCode.Six] = 6,
    [Enum.KeyCode.Seven] = 7,
    [Enum.KeyCode.Eight] = 8,
    [Enum.KeyCode.Nine] = 9,
    [Enum.KeyCode.Zero] = 10,
}

-- Create a scope for the hotbar
Functions.scope = Fusion.scoped(Fusion)
local scope = Functions.scope

-- Currently equipped slot (0 = none)
Functions.EquippedSlot = scope:Value(0)

-- Current item name flash target for the global label
Functions.CurrentItemFlashTarget = scope:Value(1)
Functions.CurrentItemTransparency = scope:Spring(Functions.CurrentItemFlashTarget, 15, 0.6)

-- Store reactive values for each slot
Functions.Slots = {}
for i = 1, Functions.MAX_HOTBAR_SLOTS do
    Functions.Slots[i] = {
        ItemName = scope:Value(""),
        Amount = scope:Value(0),
        Visible = scope:Value(false),
        IsEquipped = scope:Computed(function(use)
            return use(Functions.EquippedSlot) == i
        end),
    }
end

-- Computed display name for currently equipped item (must be after Slots is defined)
Functions.CurrentItemDisplayName = scope:Computed(function(use)
    local equippedSlot = use(Functions.EquippedSlot)
    if equippedSlot == 0 then
        return ""
    end
    local slot = Functions.Slots[equippedSlot]
    if slot then
        local itemName = use(slot.ItemName)
        return Functions:GetDisplayName(itemName)
    end
    return ""
end)

function Functions:GetDisplayName(itemName: string): string
    local itemData = SharedConstants.itemData[itemName]
    if itemData and itemData.displayName then
        return itemData.displayName
    end
    return itemName
end

function Functions:EquipSlot(slotNumber: number)
    local currentEquipped = Fusion.peek(self.EquippedSlot)
    
    if currentEquipped == slotNumber then
        self.EquippedSlot:set(0)
        EquipItem:Fire(0)
    else
        local slot = self.Slots[slotNumber]
        if slot and Fusion.peek(slot.Visible) then
            self.EquippedSlot:set(slotNumber)
            EquipItem:Fire(slotNumber)
            
            -- Flash the current item name
            self.CurrentItemFlashTarget:set(0.25)
            task.delay(1, function()
                self.CurrentItemFlashTarget:set(1)
            end)
        end
    end
end

function Functions:UpdateHotbar(inventory)
    if not inventory then return end
    
    local hotbar = inventory.hotbar or {}
    local items = inventory.items or {}
    
    for i = 1, self.MAX_HOTBAR_SLOTS do
        local slot = self.Slots[i]
        local itemName = hotbar[i]
        
        if itemName and items[itemName] then
            local itemInfo = items[itemName]
            local amount = itemInfo.amount or 0
            
            slot.ItemName:set(itemName)
            slot.Amount:set(amount)
            slot.Visible:set(true)
        else
            slot.ItemName:set("")
            slot.Amount:set(0)
            slot.Visible:set(false)
            
            if Fusion.peek(self.EquippedSlot) == i then
                self.EquippedSlot:set(0)
            end
        end
    end
end

function Functions:CreateSlot(slotIndex: number)
    local slotData = self.Slots[slotIndex]
    
    local amountText = scope:Computed(function(use)
        return tostring(use(slotData.Amount))
    end)
    
    local itemIcon = scope:Computed(function(use)
        local itemName = use(slotData.ItemName)
        local itemData = SharedConstants.itemData[itemName]
        if itemData and itemData.icon then
            return itemData.icon
        end
        return ""
    end)
    
    local slotSize = scope:Spring(scope:Computed(function(use)
        return use(slotData.IsEquipped) and self.SLOT_SIZE_EQUIPPED or self.SLOT_SIZE_NORMAL
    end), 25, 0.8)
    
    local overlayTransparency = scope:Spring(scope:Computed(function(use)
        return use(slotData.IsEquipped) and 0.5 or 1
    end), 20, 0.7)
    
    return scope:New "Frame" {
        Name = "Slot" .. slotIndex,
        BackgroundTransparency = 1,
        Size = slotSize,
        LayoutOrder = slotIndex,
        Visible = slotData.Visible,

        [Children] = {
            scope:New "TextButton" {
                Name = "ClickArea",
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundTransparency = 1,
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromScale(1, 1),
                Text = "",
                ZIndex = 10,
                
                [OnEvent "Activated"] = function()
                    self:EquipSlot(slotIndex)
                end,
            },
            
            scope:New "ImageLabel" {
                Name = "Stroke",
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundTransparency = 1,
                Image = "rbxassetid://70393233522143",
                Position = UDim2.fromScale(0.5, 0.5),
                ScaleType = Enum.ScaleType.Fit,
                Size = UDim2.fromScale(1, 1),
            },

            scope:New "ImageLabel" {
                Name = "Fill",
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundTransparency = 1,
                Image = "rbxassetid://105730174381346",
                ImageTransparency = 0.57,
                Position = UDim2.fromScale(0.5, 0.5),
                ScaleType = Enum.ScaleType.Fit,
                Size = UDim2.fromScale(1, 1),
                ZIndex = 2,
            },

            scope:New "ImageLabel" {
                Name = "ItemIcon",
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundTransparency = 1,
                Image = itemIcon,
                Position = UDim2.fromScale(0.5, 0.5),
                ScaleType = Enum.ScaleType.Fit,
                Size = UDim2.fromScale(0.7, 0.7),
                ZIndex = 3,
            },

            scope:New "TextLabel" {
                Name = "Amount",
                Active = true,
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundTransparency = 1,
                FontFace = Font.new(
                    "rbxasset://fonts/families/HighwayGothic.json",
                    Enum.FontWeight.Bold,
                    Enum.FontStyle.Normal
                ),
                Position = UDim2.fromScale(0.765727, 0.841666),
                Selectable = true,
                Size = UDim2.fromScale(0.85, 0.3),
                Text = amountText,
                TextColor3 = Color3.new(1, 1, 1),
                TextScaled = true,
                ZIndex = 6,

                [Children] = {
                    scope:New "UIStroke" {
                        Name = "UIStroke",
                        Color = Color3.fromRGB(46, 46, 46),
                        StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                        Thickness = 0.1,
                    },
                }
            },
            
            scope:New "ImageLabel" {
                Name = "EquippedOverlay",
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundTransparency = 1,
                Image = "rbxassetid://105730174381346",
                ImageColor3 = Color3.new(1, 1, 1),
                ImageTransparency = overlayTransparency,
                Position = UDim2.fromScale(0.5, 0.5),
                ScaleType = Enum.ScaleType.Fit,
                Size = UDim2.fromScale(1, 1),
                ZIndex = 5,
            },
        }
    }
end

function Functions:CreateCurrentItemLabel()
    return scope:New "Folder" {
        Name = "Nullify",

        [Children] = {
            scope:New "TextLabel" {
                Name = "CurrentItem",
                Active = true,
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundTransparency = 1,
                FontFace = Font.new(
                    "rbxasset://fonts/families/HighwayGothic.json",
                    Enum.FontWeight.Bold,
                    Enum.FontStyle.Normal
                ),
                Position = UDim2.fromScale(0.5, -0.323),
                Selectable = true,
                Size = UDim2.fromScale(0.5, 0.362334),
                Text = self.CurrentItemDisplayName,
                TextColor3 = Color3.new(1, 1, 1),
                TextTransparency = self.CurrentItemTransparency,
                TextScaled = true,
                ZIndex = 4,
            },
        }
    }
end

function Functions:Init()
    -- Keyboard input for hotbar slots
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        local slotNumber = self.KEY_MAP[input.KeyCode]
        if slotNumber then
            self:EquipSlot(slotNumber)
        end
    end)
    
    -- Listen for inventory updates
    task.spawn(function()
        Replication:GetInfo("Data", true):OnSet({"inventory"}, function(newInventory)
            self:UpdateHotbar(newInventory)
        end)
        
        local replica = Replication:GetInfo("Data", true)
        if replica and replica.Data and replica.Data.inventory then
            self:UpdateHotbar(replica.Data.inventory)
        end
    end)
end

-- Initialize on load
Functions:Init()

return Functions