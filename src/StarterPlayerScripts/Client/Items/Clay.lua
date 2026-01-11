--[[
    Clay Item - Client-side Clay feedback (sounds, particles, etc.)
    Note: Actual tool handling is done server-side
]]

local Players = game:GetService("Players")

local Player = Players.LocalPlayer

local BaseItem = require(script.Parent.BaseItem)

local Clay = {}
Clay.__index = Clay
setmetatable(Clay, BaseItem)

function Clay.new()
    local self = setmetatable(BaseItem.new("Clay"), Clay)
    
    return self
end

function Clay:OnEquip()
    print(`[Clay Client] Equipped by {Player.Name}`)
    -- Add client-side feedback here (equip sound, particles, etc.)
end

function Clay:OnUnequip()
    print(`[Clay Client] Unequipped by {Player.Name}`)
    -- Add client-side feedback here (unequip sound, etc.)
end

function Clay:OnActivate()
    print(`[Clay Client] Activated by {Player.Name}`)
    -- Add client-side feedback here (use sound, particles, etc.)
end

return Clay
