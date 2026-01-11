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
    print(`[Clay] {self.Player.Name} equipped Clay`)
end

function Clay:OnUnequip()
    print(`[Clay] {self.Player.Name} unequipped Clay`)
end

function Clay:OnActivate()
    print(`[Clay] {self.Player.Name} activated Clay`)
    -- Add Clay-specific activation logic here
    -- e.g., placing clay on a potter's wheel
end

return Clay
