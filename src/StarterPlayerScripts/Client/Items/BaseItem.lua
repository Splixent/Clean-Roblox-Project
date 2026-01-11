--[[
    BaseItem - Client-side item class that all items inherit from
    Handles client-side equip/unequip/activate feedback
    Note: Tool cloning is handled server-side in InventoryManager
]]

local BaseItem = {}
BaseItem.__index = BaseItem

function BaseItem.new(itemName: string)
    local self = setmetatable({}, BaseItem)
    
    self.ItemName = itemName
    self.IsEquipped = false
    
    return self
end

function BaseItem:Equip()
    if self.IsEquipped then return end
    
    self.IsEquipped = true
    self:OnEquip()
end

function BaseItem:Unequip()
    if not self.IsEquipped then return end
    
    self.IsEquipped = false
    self:OnUnequip()
end

function BaseItem:Activate()
    if not self.IsEquipped then return end
    
    self:OnActivate()
end

-- Override these in subclasses for client-side feedback (sounds, particles, etc.)
function BaseItem:OnEquip()
    -- Override in subclass
end

function BaseItem:OnUnequip()
    -- Override in subclass
end

function BaseItem:OnActivate()
    -- Override in subclass
end

function BaseItem:Destroy()
    self:Unequip()
end

return BaseItem
