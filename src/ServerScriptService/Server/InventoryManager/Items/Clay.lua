--[[
    Clay Item - Server-side Clay-specific behavior
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService.Server

local BaseItem = require(script.Parent.BaseItem)

local Clay = {}
Clay.__index = Clay
setmetatable(Clay, BaseItem)

function Clay.new(player: Player)
    local self = setmetatable(BaseItem.new(player, "Clay"), Clay)
    
    return self
end

function Clay:OnEquip()
end

function Clay:OnUnequip()
end

function Clay:OnActivate()
end

return Clay
