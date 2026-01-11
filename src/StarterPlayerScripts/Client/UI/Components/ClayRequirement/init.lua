local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Fusion = require(Shared.Fusion)
local SharedConstants = require(Shared.Constants)
local Functions = require(script.Functions)

local Children = Fusion.Children

local scope = Functions.scope
local s = scope

local LocalPlayer = Players.LocalPlayer

-- Create as BillboardGui for 3D world positioning (between simple prompts)
return s:New "BillboardGui" {
    Name = "ClayRequirementBillboard",
    Active = true,
    AlwaysOnTop = true,
    ClipsDescendants = true,
    LightInfluence = 1,
    Size = UDim2.fromScale(3.7, 1.5),
    StudsOffset = Functions.AnimatedStackOffset,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    MaxDistance = math.huge, -- We handle distance ourselves
    Adornee = Functions.Adornee,
    Parent = s:Computed(function(use)
        local adornee = use(Functions.Adornee)
        if adornee then
            return LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("UI"):WaitForChild("ProximityPrompts")
        end
        return nil
    end),

    [Children] = {
        s:New "CanvasGroup" {
            Name = "Container",
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            GroupTransparency = Functions.AnimatedTransparency,
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromScale(1, 1),

            [Children] = {
                s:New "Frame" {
                    Name = "ClayRequirement",
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundTransparency = 1,
                    Position = UDim2.fromScale(0.5, 0.5),
                    Size = UDim2.fromScale(1, 1),

                    [Children] = {
                        s:New "ImageLabel" {
                            Name = "Background",
                            AnchorPoint = Vector2.new(0.5, 0.5),
                            BackgroundTransparency = 1,
                            Image = "rbxassetid://99448744269230",
                            ImageTransparency = 0.3,
                            Position = UDim2.fromScale(0.499239, 0.498127),
                            ScaleType = Enum.ScaleType.Slice,
                            Size = UDim2.fromScale(0.999925, 0.996254),
                            SliceCenter = Rect.new(512, 512, 512, 512),
                            SliceScale = 0.999074,
                            ZIndex = -1,
                        },

                        s:New "ImageLabel" {
                            Name = "BackgroundStroke",
                            AnchorPoint = Vector2.new(0.5, 0.5),
                            BackgroundTransparency = 1,
                            Image = "rbxassetid://138803086803744",
                            ImageColor3 = Color3.fromRGB(230, 230, 230),
                            Position = UDim2.fromScale(0.499239, 0.498127),
                            ScaleType = Enum.ScaleType.Slice,
                            Size = UDim2.fromScale(0.999925, 0.996254),
                            SliceCenter = Rect.new(512, 512, 512, 512),
                            SliceScale = 0.999074,
                            ZIndex = -2,
                        },

                        s:New "TextLabel" {
                            Name = "ActionText",
                            AnchorPoint = Vector2.new(0.5, 0.5),
                            BackgroundTransparency = 1,
                            FontFace = Font.new(
                                "rbxasset://fonts/families/HighwayGothic.json",
                                Enum.FontWeight.Bold,
                                Enum.FontStyle.Normal
                            ),
                            Position = UDim2.fromScale(0.632369, 0.498127),
                            Size = UDim2.fromScale(0.564357, 0.599687),
                            Text = s:Computed(function(use)
                                local current = use(Functions.CurrentClay)
                                local required = use(Functions.RequiredClay)
                                return string.format("%d/%d", current, required)
                            end),
                            TextColor3 = s:Computed(function(use)
                                local current = use(Functions.CurrentClay)
                                local required = use(Functions.RequiredClay)
                                if current >= required then
                                    return Color3.fromRGB(77, 180, 77) -- Green when enough
                                else
                                    return Color3.fromRGB(77, 77, 77) -- Grey otherwise
                                end
                            end),
                            TextScaled = true,
                            TextXAlignment = Enum.TextXAlignment.Right,
                        },

                        s:New "ImageLabel" {
                            Name = "ClayIcon",
                            AnchorPoint = Vector2.new(0.5, 0.5),
                            BackgroundTransparency = 1,
                            Image = s:Computed(function(use)
                                local clayType = use(Functions.ClayType)
                                local clayData = SharedConstants.clayTypes and SharedConstants.clayTypes[clayType]
                                return clayData and clayData.icon or "rbxassetid://86846067959868"
                            end),
                            Position = UDim2.fromScale(0.230532, 0.493291),
                            Size = UDim2.fromScale(0.244324, 0.594851),
                            ZIndex = 3,
                        },

                        s:New "ImageLabel" {
                            Name = "ButtonStroke",
                            AnchorPoint = Vector2.new(0.5, 0.5),
                            BackgroundTransparency = 1,
                            Image = "rbxassetid://132440398359005",
                            ImageColor3 = Color3.fromRGB(113, 113, 113),
                            ImageTransparency = 0.05,
                            Position = UDim2.fromScale(0.230532, 0.493291),
                            ScaleType = Enum.ScaleType.Slice,
                            Size = UDim2.fromScale(0.336931, 0.826987),
                            SliceCenter = Rect.new(512, 512, 512, 512),
                            SliceScale = 0.999074,
                            ZIndex = 0,
                        },

                        s:New "ImageLabel" {
                            Name = "ButtonIcon",
                            AnchorPoint = Vector2.new(0.5, 0.5),
                            BackgroundTransparency = 1,
                            Image = "rbxassetid://123413392379402",
                            Position = UDim2.fromScale(0.230532, 0.493291),
                            Size = UDim2.fromScale(0.281761, 0.686738),

                            [Children] = {
                                s:New "UIGradient" {
                                    Name = "UIGradient",
                                    Rotation = 90,
                                    Transparency = NumberSequence.new({
                                        NumberSequenceKeypoint.new(0, 0),
                                        NumberSequenceKeypoint.new(1, 0.95625),
                                    }),
                                },
                            }
                        },
                    }
                },
            }
        },
    }
}
