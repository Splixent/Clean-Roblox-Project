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
end

function Clay:OnUnequip()
end

function Clay:OnActivate()
end

return Clay
