local Players = game:GetService("Players")
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

-- Track viewport size for responsive positioning
local ViewportSize = scope:Value(workspace.CurrentCamera.ViewportSize)

-- Listen for viewport size changes
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    ViewportSize:set(workspace.CurrentCamera.ViewportSize)
end)

-- Compute position based on aspect ratio
local HotbarPosition = scope:Computed(function(use)
    local size = use(ViewportSize)
    local aspectRatio = size.X / size.Y
    
    -- 16:9 aspect ratio is approximately 1.78
    -- iPhone aspect ratios are typically wider (around 2.16 for newer models)
    if aspectRatio > 1.9 then
        -- Wider screens (iPhone, ultrawide) - position higher
        return UDim2.fromScale(0.5, 0.85)
    else
        -- Standard 16:9 and narrower - position lower
        return UDim2.fromScale(0.5, 0.904)
    end
end)

return scope:New "Frame" {
    Name = "Hotbar",
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundTransparency = 1,
    Position = HotbarPosition,
    Size = UDim2.fromScale(0.52125, 0.0926784),
    ZIndex = 0,

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