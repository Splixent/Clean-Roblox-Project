local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Fusion = require(Shared.Fusion)
local Functions = require(script.Functions)

local scope = Functions.scope
local Children = Fusion.Children

local slotChildren = {}
for i = 1, Functions.MAX_HOTBAR_SLOTS do
    table.insert(slotChildren, Functions:CreateSlot(i))
end

return scope:New "Frame" {
    Name = "Hotbar",
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundTransparency = 1,
    Position = UDim2.fromScale(0.5, 0.931),
    Size = UDim2.fromScale(0.52125, 0.0926784),

    [Children] = {
        scope:New "UIListLayout" {
            Name = "UIListLayout",
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            Padding = UDim.new(0, 30),
            SortOrder = Enum.SortOrder.LayoutOrder,
            VerticalAlignment = Enum.VerticalAlignment.Center,
        },
        
        Functions:CreateCurrentItemLabel(),

        unpack(slotChildren),
    }
}