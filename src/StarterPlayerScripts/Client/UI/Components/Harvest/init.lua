local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Client = Players.LocalPlayer.PlayerScripts.Client

local Fusion = require(Shared.Fusion)
local Functions = require(script.Functions)

local New = Fusion.New
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local Computed = Fusion.Computed
local Spring = Fusion.Spring

local s = Fusion.scoped(Fusion)

-- Animated progress for smooth transitions
local animatedProgress = s:Spring(Functions.progress, 25, 0.8)

-- Compute the gradient transparency based on progress
local progressGradient = s:Computed(function(use)
    local progress = use(animatedProgress)
    
    if progress <= 0.001 then
        return NumberSequence.new(1) -- Fully transparent
    end
    
    local midPoint = math.clamp(progress, 0.001, 0.999)
    
    return NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(math.max(0.001, midPoint - 0.003), 0),
        NumberSequenceKeypoint.new(math.min(0.999, midPoint + 0.003), 1),
        NumberSequenceKeypoint.new(1, 1),
    })
end)

-- Target progress gradient (darker bar showing the goal)
local targetGradient = s:Computed(function(use)
    local target = use(Functions.targetProgress)
    
    if target <= 0.001 then
        return NumberSequence.new(1)
    end
    
    local midPoint = math.clamp(target, 0.001, 0.999)
    
    return NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(math.max(0.001, midPoint - 0.003), 0),
        NumberSequenceKeypoint.new(math.min(0.999, midPoint + 0.003), 1),
        NumberSequenceKeypoint.new(1, 1),
    })
end)

return s:New "ImageLabel" {
    Name = "Harvest",
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundTransparency = 1,
    Image = "rbxassetid://123413392379402",
    ImageColor3 = Color3.fromRGB(27, 27, 27),
    Position = UDim2.fromScale(0.5, 0.718278),
    ScaleType = Enum.ScaleType.Slice,
    Size = UDim2.fromScale(0.220833, 0.0509731),
    SliceCenter = Rect.new(512, 512, 512, 512),
    Visible = Functions.visible,

    [Children] = {
        s:New "ImageLabel" {
            Name = "HarvestStroke",
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            Image = "rbxassetid://129885483315946",
            Position = UDim2.fromScale(0.5, 0.5),
            ScaleType = Enum.ScaleType.Slice,
            Size = UDim2.fromScale(1.01, 1.01),
            SliceCenter = Rect.new(512, 512, 512, 512),
            ZIndex = 3,
        },

        -- Target progress (darker green, shows the goal)
        s:New "ImageLabel" {
            Name = "Progress2",
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            Image = "rbxassetid://123413392379402",
            Position = UDim2.fromScale(0.5, 0.5),
            ScaleType = Enum.ScaleType.Slice,
            Size = UDim2.fromScale(1, 1),
            SliceCenter = Rect.new(512, 512, 512, 512),

            [Children] = {
                s:New "UIGradient" {
                    Name = "UIGradient",
                    Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 143, 60)),
                        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 143, 60)),
                    }),
                    Transparency = targetGradient,
                },
            }
        },

        -- Current progress (bright green, shows actual progress)
        s:New "ImageLabel" {
            Name = "Progress",
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            Image = "rbxassetid://123413392379402",
            Position = UDim2.fromScale(0.5, 0.5),
            ScaleType = Enum.ScaleType.Slice,
            Size = UDim2.fromScale(1, 1),
            SliceCenter = Rect.new(512, 512, 512, 512),
            ZIndex = 2,

            [Children] = {
                s:New "UIGradient" {
                    Name = "UIGradient",
                    Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 106)),
                        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 255, 106)),
                    }),
                    Transparency = progressGradient,
                },
            }
        },

        s:New "UIAspectRatioConstraint" {
            Name = "UIAspectRatioConstraint",
            AspectRatio = 5.76,
        },
    }
}