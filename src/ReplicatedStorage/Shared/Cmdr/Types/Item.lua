local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local SharedConstants = require(Shared.Constants)

local items = {}

for itemName, _ in pairs(SharedConstants.itemData) do
	table.insert(items, itemName)
end

return function(registry)
	registry:RegisterType("item", registry.Cmdr.Util.MakeEnumType("Item", items))
end
