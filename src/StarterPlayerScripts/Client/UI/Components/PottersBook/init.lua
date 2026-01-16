local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Client = Players.LocalPlayer.PlayerScripts.Client

local Fusion = require(Shared.Fusion)
local SharedConstants = require(Shared.Constants)
local Functions = require(script.Functions)
local ExitButton = require(script.Parent.Parent.ExitButton)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek

local scope = Functions.scope
local s = scope

-- Helper function to create a style card for the grid
local function CreateStyleCard(styleKey: string, styleData: table)
    local isHovered = s:Value(false)
    
    local containerRotation = s:Spring(
        s:Computed(function(use)
            return use(isHovered) and 5 or 0
        end),
        20, 0.6
    )
    
    local containerScale = s:Spring(
        s:Computed(function(use)
            return use(isHovered) and 1.05 or 1
        end),
        20, 0.6
    )
    
    local card = s:New "Frame" {
        Name = styleKey,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(0.177536, 0.205039),

        [Children] = {
            s:New "ImageLabel" {
                Name = "Container",
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundTransparency = 1,
                Image = "rbxassetid://123413392379402",
                ImageColor3 = Color3.new(),
                ImageTransparency = 0.89,
                Position = UDim2.fromScale(0.5, 0.5),
                Rotation = containerRotation,
                Size = s:Computed(function(use)
                    local scale = use(containerScale)
                    return UDim2.fromScale(scale, scale)
                end),

                [Children] = {
                    s:New "ViewportFrame" {
                        Name = "ViewportFrame",
                        Ambient = Color3.new(),
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundTransparency = 1,
                        LightColor = Color3.new(1, 1, 1),
                        Position = UDim2.fromScale(0.5, 0.5),
                        Size = UDim2.fromScale(0.85, 0.85),
                    },
                    
                    s:New "ImageButton" {
                        Name = "SelectButton",
                        BackgroundTransparency = 1,
                        Size = UDim2.fromScale(1, 1),
                        
                        [OnEvent "Activated"] = function()
                            Functions:SelectStyle(styleKey)
                        end,
                        
                        [OnEvent "MouseEnter"] = function()
                            if UserInputService.PreferredInput == Enum.PreferredInput.KeyboardAndMouse then
                                isHovered:set(true)
                            end
                        end,
                        
                        [OnEvent "MouseLeave"] = function()
                            isHovered:set(false)
                        end,
                    },
                }
            },
        }
    }
    
    -- Setup viewport when card is added to game
    task.defer(function()
        local container = card:FindFirstChild("Container")
        if container then
            local viewport = container:FindFirstChild("ViewportFrame")
            if viewport then
                Functions:SetupViewportFrame(viewport, styleKey)
            end
        end
    end)
    
    return card
end

-- Helper function to create an empty placeholder card
local function CreatePlaceholderCard(layoutOrder: number)
    return s:New "Frame" {
        Name = "Placeholder_" .. layoutOrder,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(0.177536, 0.205039),
        LayoutOrder = layoutOrder,

        [Children] = {
            s:New "ImageLabel" {
                Name = "Container",
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundTransparency = 1,
                Image = "rbxassetid://123413392379402",
                ImageColor3 = Color3.new(),
                ImageTransparency = 0.89,
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromScale(1, 1),
            },
        }
    }
end

-- Helper function to create section icon button
local function CreateSectionIcon(sectionName: string, iconAsset: string, layoutOrder: number)
    local isSelected = s:Computed(function(use)
        return use(Functions.CurrentSection) == sectionName
    end)
    
    -- Transparency springs faster when becoming visible (selected)
    local iconTransparency = s:Spring(
        s:Computed(function(use)
            return use(isSelected) and 0 or 0.89
        end),
        15, 1
    )
    
    -- Color: Use a Value that we manually control for instant vs slow transition
    local sectionColor = Functions.SECTION_COLORS[sectionName] or Color3.new(0, 0, 0)
    local targetColor = s:Value(Color3.new(0, 0, 0))
    local colorSpringSpeed = s:Value(30) -- Fast by default
    
    local iconColor = s:Spring(
        targetColor,
        s:Computed(function(use)
            return use(colorSpringSpeed)
        end),
        1
    )
    
    -- Observer to update color with appropriate speed
    s:Observer(isSelected):onBind(function()
        local selected = peek(isSelected)
        if selected then
            -- Instant color change when selected
            colorSpringSpeed:set(50)
            targetColor:set(sectionColor)
        else
            -- Slow fade when deselected
            colorSpringSpeed:set(6)
            targetColor:set(Color3.new(0, 0, 0))
        end
    end)
    
    return s:New "ImageButton" {
        Name = sectionName,
        BackgroundTransparency = 1,
        Image = iconAsset,
        ImageColor3 = iconColor,
        ImageTransparency = iconTransparency,
        LayoutOrder = layoutOrder,
        ScaleType = Enum.ScaleType.Fit,
        Size = UDim2.fromScale(0.109489, 1.21622),
        
        [OnEvent "Activated"] = function()
            Functions:SetSection(sectionName)
        end,
    }
end

-- Helper to create a scrolling frame for a section
local function CreateSectionScrollFrame(sectionName: string)
    local isVisible = s:Computed(function(use)
        return use(Functions.CurrentSection) == sectionName
    end)
    
    local scrollFrame = s:New "ScrollingFrame" {
        Name = sectionName,
        AnchorPoint = Vector2.new(1, 1),
        BackgroundTransparency = 1,
        ClipsDescendants = false,
        Position = UDim2.fromScale(0.633258, 1),
        ScrollBarImageColor3 = Color3.new(),
        ScrollBarImageTransparency = 0.77,
        ScrollBarThickness = 20,
        Selectable = false,
        Size = UDim2.fromScale(0.616071, 1),
        VerticalScrollBarPosition = Enum.VerticalScrollBarPosition.Left,
        Visible = isVisible,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,

        [Children] = {
            s:New "UIGridLayout" {
                Name = "UIGridLayout",
                CellPadding = UDim2.fromOffset(13, 13),
                CellSize = UDim2.fromOffset(147, 147),
                HorizontalAlignment = Enum.HorizontalAlignment.Right,
                SortOrder = Enum.SortOrder.LayoutOrder,
            },
        }
    }
    
    -- Populate with styles for this section
    task.defer(function()
        local styles = Functions:GetStylesForSection(sectionName)
        local cardCount = 0
        
        for i, styleInfo in ipairs(styles) do
            local card = CreateStyleCard(styleInfo.key, styleInfo.data)
            card.LayoutOrder = i
            card.Parent = scrollFrame
            cardCount = cardCount + 1
        end
        
        -- Fill remaining slots with placeholders (minimum 20 slots = 4 rows of 5)
        local minSlots = 20
        for i = cardCount + 1, minSlots do
            local placeholder = CreatePlaceholderCard(i)
            placeholder.Parent = scrollFrame
        end
    end)
    
    return scrollFrame
end

return s:New "Frame" {
    Name = "PottersBook",
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundTransparency = 1,
    Position = Functions.AnimatedPosition,
    Rotation = Functions.AnimatedRotation,
    Size = UDim2.fromScale(1, 1),

    [Children] = {
        s:New "Frame" {
            Name = "Container",
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromScale(0.7, 0.7),

            [Children] = {
                s:New "ImageLabel" {
                    Name = "Background",
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundTransparency = 1,
                    Image = "rbxassetid://123413392379402",
                    Position = UDim2.fromScale(0.5, 0.464556),
                    ScaleType = Enum.ScaleType.Slice,
                    Size = UDim2.fromScale(1, 1.07089),
                    SliceCenter = Rect.new(512, 512, 512, 512),
                    SliceScale = 0.3,
                    ZIndex = 0,
                },

                s:New "Frame" {
                    Name = "StyleContainer",
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundTransparency = 1,
                    ClipsDescendants = true,
                    Position = UDim2.fromScale(0.5, 0.525),
                    Size = UDim2.fromScale(1, 0.949),

                    [Children] = {
                        -- Create scrolling frames for each section
                        CreateSectionScrollFrame("Bowls"),
                        CreateSectionScrollFrame("Plates"),
                        CreateSectionScrollFrame("Cups"),
                        CreateSectionScrollFrame("Vessels"),
                        CreateSectionScrollFrame("Sculptures"),
                        CreateSectionScrollFrame("Relics"),
                        CreateSectionScrollFrame("Limiteds"),
                    }
                },

                s:New "Frame" {
                    Name = "StyleSections",
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundTransparency = 1,
                    Position = UDim2.fromScale(0.342084, -0.00878779),
                    Size = UDim2.fromScale(0.611607, 0.0979743),
                    ZIndex = 2,

                    [Children] = {
                        s:New "UIListLayout" {
                            Name = "UIListLayout",
                            FillDirection = Enum.FillDirection.Horizontal,
                            HorizontalAlignment = Enum.HorizontalAlignment.Center,
                            Padding = UDim.new(0.015, 0),
                            SortOrder = Enum.SortOrder.LayoutOrder,
                            VerticalAlignment = Enum.VerticalAlignment.Center,
                        },

                        CreateSectionIcon("Bowls", Functions.SECTION_ICONS.Bowls, 1),
                        CreateSectionIcon("Plates", Functions.SECTION_ICONS.Plates, 2),
                        CreateSectionIcon("Cups", Functions.SECTION_ICONS.Cups, 3),
                        CreateSectionIcon("Vessels", Functions.SECTION_ICONS.Vessels, 4),
                        CreateSectionIcon("Sculptures", Functions.SECTION_ICONS.Sculptures, 5),
                        CreateSectionIcon("Relics", Functions.SECTION_ICONS.Relics, 6),
                        CreateSectionIcon("Limiteds", Functions.SECTION_ICONS.Limiteds, 7),
                    }
                },

                s:New "Frame" {
                    Name = "SectionNameContainer",
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundColor3 = s:Computed(function(use)
                        local section = use(Functions.CurrentSection)
                        return Functions.SECTION_COLORS[section] or Color3.fromRGB(81, 159, 255)
                    end),
                    Position = s:Computed(function(use)
                        local xPos = use(Functions.SectionNameXPosition)
                        return UDim2.fromScale(xPos, -0.064)
                    end),
                    Size = s:Computed(function(use)
                        local width = use(Functions.SectionNameWidth)
                        return UDim2.fromScale(width, 0.036)
                    end),
                    ZIndex = 3,

                    [Children] = {
                        s:New "UICorner" {
                            Name = "UICorner",
                            CornerRadius = UDim.new(1, 0),
                        },
                        
                        s:New "TextLabel" {
                            Name = "SectionName",
                            AnchorPoint = Vector2.new(0.5, 0.5),
                            BackgroundTransparency = 1,
                            FontFace = Font.new("rbxasset://fonts/families/HighwayGothic.json"),
                            Position = UDim2.fromScale(0.5, 0.5),
                            Size = UDim2.fromScale(1, 0.8),
                            Text = Functions.CurrentSection,
                            TextColor3 = Color3.new(1, 1, 1),
                            TextScaled = true,
                        },
                    }
                },

                s:New "ImageLabel" {
                    Name = "StylePreview",
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundTransparency = 1,
                    Image = "rbxassetid://123413392379402",
                    ImageColor3 = Color3.new(),
                    ImageTransparency = 0.89,
                    Position = UDim2.fromScale(0.813988, 0.263471),
                    ScaleType = Enum.ScaleType.Slice,
                    Size = UDim2.fromScale(0.317708, 0.573282),
                    SliceCenter = Rect.new(512, 512, 512, 512),
                    SliceScale = 0.3,

                    [Children] = {
                        s:New "ViewportFrame" {
                            Name = "ViewportFrame",
                            Ambient = Color3.new(),
                            AnchorPoint = Vector2.new(0.5, 0.5),
                            BackgroundTransparency = 1,
                            LightColor = Color3.new(1, 1, 1),
                            Position = UDim2.fromScale(0.5, 0.5),
                            Size = UDim2.fromScale(0.95, 0.95),
                            Visible = s:Computed(function(use)
                                return use(Functions.SelectedStyle) ~= nil
                            end),
                        },

                        s:New "ImageButton" {
                            Name = "Drag",
                            AnchorPoint = Vector2.new(0.5, 0.5),
                            BackgroundTransparency = 1,
                            Position = UDim2.fromScale(0.5, 0.5),
                            Selectable = false,
                            Size = UDim2.fromScale(1, 1),
                            
                            [OnEvent "MouseButton1Down"] = function()
                                Functions:StartDrag()
                            end,
                            
                            [OnEvent "MouseButton1Up"] = function()
                                Functions:StopDrag()
                            end,
                            
                            [OnEvent "MouseLeave"] = function()
                                Functions:StopDrag()
                            end,
                        },
                        
                        -- Rotate icons with flash animation
                        (function()
                            local flashTime = s:Value(0)
                            
                            -- Update flash time
                            task.spawn(function()
                                local connection
                                connection = RunService.RenderStepped:Connect(function(dt)
                                    flashTime:set(peek(flashTime) + dt)
                                end)
                                
                                -- Cleanup when scope is destroyed
                                table.insert(scope, function()
                                    connection:Disconnect()
                                end)
                            end)
                            
                            local flashTransparency = s:Computed(function(use)
                                local isDragging = use(Functions.IsDragging)
                                local hasStyle = use(Functions.SelectedStyle) ~= nil
                                
                                if not hasStyle or isDragging then
                                    return 1 -- Fully transparent (hidden)
                                end
                                
                                -- Pulsing effect: oscillate between 0.5 and 1
                                local t = use(flashTime)
                                local pulse = (math.sin(t * 3) + 1) / 2 -- 0 to 1
                                return 0.8 + pulse * 0.8 -- 0.5 to 1
                            end)
                            
                            return {
                                s:New "ImageLabel" {
                                    Name = "RotateRight",
                                    AnchorPoint = Vector2.new(1, 1),
                                    BackgroundTransparency = 1,
                                    Image = "rbxassetid://107510103401021",
                                    ImageColor3 = Color3.new(),
                                    ImageTransparency = flashTransparency,
                                    Position = UDim2.fromScale(0.95, 0.95),
                                    ScaleType = Enum.ScaleType.Fit,
                                    Size = UDim2.fromOffset(77, 77),
                                },
                                
                                s:New "ImageLabel" {
                                    Name = "RotateLeft",
                                    AnchorPoint = Vector2.new(0, 1),
                                    BackgroundTransparency = 1,
                                    Image = "rbxassetid://105549184796361",
                                    ImageColor3 = Color3.new(),
                                    ImageTransparency = flashTransparency,
                                    Position = UDim2.fromScale(0.05, 0.95),
                                    ScaleType = Enum.ScaleType.Fit,
                                    Size = UDim2.fromOffset(77, 77),
                                },
                            }
                        end)(),
                    }
                },

                s:New "Frame" {
                    Name = "StyleInfo",
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundTransparency = 1,
                    Position = UDim2.fromScale(0.814347, 0.787984),
                    Size = UDim2.fromScale(0.317735, 0.405861),

                    [Children] = {
                        s:New "UIListLayout" {
                            Name = "UIListLayout",
                            Padding = UDim.new(0.05, 0),
                            SortOrder = Enum.SortOrder.LayoutOrder,
                        },

                        -- Style Name
                        s:New "ImageLabel" {
                            Name = "NameRow",
                            AnchorPoint = Vector2.new(0.5, 0.5),
                            BackgroundTransparency = 1,
                            Image = "rbxassetid://123413392379402",
                            ImageColor3 = Color3.new(),
                            ImageTransparency = 0.89,
                            LayoutOrder = -1,
                            ScaleType = Enum.ScaleType.Slice,
                            Size = UDim2.fromScale(0.999915, 0.192466),
                            SliceCenter = Rect.new(512, 512, 512, 512),
                            SliceScale = 2,

                            [Children] = {
                                s:New "TextLabel" {
                                    Name = "StyleName",
                                    AnchorPoint = Vector2.new(0.5, 0.5),
                                    BackgroundTransparency = 1,
                                    FontFace = Font.new("rbxasset://fonts/families/HighwayGothic.json"),
                                    Position = UDim2.fromScale(0.5, 0.5),
                                    Size = UDim2.fromScale(0.9, 0.8),
                                    Text = s:Computed(function(use)
                                        local styleKey = use(Functions.SelectedStyle)
                                        if not styleKey then return "Select a Style" end
                                        local data = SharedConstants.pottteryData and SharedConstants.pottteryData[styleKey]
                                        return data and data.name or styleKey
                                    end),
                                    TextColor3 = Color3.new(1, 1, 1),
                                    TextScaled = true,
                                    TextXAlignment = Enum.TextXAlignment.Left,

                                    [Children] = {
                                        s:New "UIStroke" {
                                            Name = "UIStroke",
                                            Color = Color3.fromRGB(214, 214, 214),
                                            StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                                            Thickness = 0.03,
                                        },
                                    }
                                },
                            }
                        },

                        -- Rarity
                        s:New "ImageLabel" {
                            Name = "RarityRow",
                            AnchorPoint = Vector2.new(0.5, 0.5),
                            BackgroundTransparency = 1,
                            Image = "rbxassetid://123413392379402",
                            ImageColor3 = Color3.new(),
                            ImageTransparency = 0.89,
                            LayoutOrder = 1,
                            ScaleType = Enum.ScaleType.Slice,
                            Size = UDim2.fromScale(0.999915, 0.192466),
                            SliceCenter = Rect.new(512, 512, 512, 512),
                            SliceScale = 2,

                            [Children] = {
                                s:New "TextLabel" {
                                    Name = "Rarity",
                                    AnchorPoint = Vector2.new(0.5, 0.5),
                                    BackgroundTransparency = 1,
                                    FontFace = Font.new(
                                        "rbxasset://fonts/families/HighwayGothic.json",
                                        Enum.FontWeight.Bold,
                                        Enum.FontStyle.Normal
                                    ),
                                    Position = UDim2.fromScale(0.5, 0.5),
                                    Size = UDim2.fromScale(0.9, 0.8),
                                    Text = s:Computed(function(use)
                                        local styleKey = use(Functions.SelectedStyle)
                                        if not styleKey then return "" end
                                        local data = SharedConstants.pottteryData and SharedConstants.pottteryData[styleKey]
                                        return data and data.rarity or ""
                                    end),
                                    TextColor3 = Color3.new(1, 1, 1),
                                    TextScaled = true,
                                    TextXAlignment = Enum.TextXAlignment.Left,

                                    [Children] = {
                                        s:New "UIStroke" {
                                            Name = "UIStroke",
                                            Color = Color3.fromRGB(214, 214, 214),
                                            StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                                            Thickness = 0.03,
                                        },
                                    }
                                },
                            }
                        },

                        -- Cost row
                        s:New "ImageLabel" {
                            Name = "CostRow",
                            AnchorPoint = Vector2.new(0.5, 0.5),
                            BackgroundTransparency = 1,
                            Image = "rbxassetid://123413392379402",
                            ImageColor3 = Color3.new(),
                            ImageTransparency = 1,
                            LayoutOrder = 2,
                            ScaleType = Enum.ScaleType.Slice,
                            Size = UDim2.fromScale(0.999915, 0.192466),
                            SliceCenter = Rect.new(512, 512, 512, 512),
                            SliceScale = 2,
                            Visible = s:Computed(function(use)
                                return use(Functions.SelectedStyle) ~= nil
                            end),

                            [Children] = {
                                s:New "UIListLayout" {
                                    Name = "UIListLayout",
                                    FillDirection = Enum.FillDirection.Horizontal,
                                    Padding = UDim.new(0.025, 0),
                                    SortOrder = Enum.SortOrder.LayoutOrder,
                                },
                                
                                s:New "ImageLabel" {
                                    Name = "ClayIcon",
                                    AnchorPoint = Vector2.new(0.5, 0.5),
                                    BackgroundTransparency = 1,
                                    Image = "rbxassetid://123413392379402",
                                    ImageColor3 = Color3.new(),
                                    ImageTransparency = 0.89,
                                    LayoutOrder = 1,
                                    ScaleType = Enum.ScaleType.Slice,
                                    Size = UDim2.fromScale(0.154567, 1),
                                    SliceCenter = Rect.new(512, 512, 512, 512),
                                    SliceScale = 2,

                                    [Children] = {
                                        s:New "ImageLabel" {
                                            Name = "Icon",
                                            AnchorPoint = Vector2.new(0.5, 0.5),
                                            BackgroundTransparency = 1,
                                            Image = "rbxassetid://86846067959868",
                                            LayoutOrder = 2,
                                            Position = UDim2.fromScale(0.5, 0.5),
                                            ScaleType = Enum.ScaleType.Fit,
                                            Size = UDim2.fromScale(0.8, 0.8),
                                        },
                                    }
                                },

                                s:New "ImageLabel" {
                                    Name = "CostAmount",
                                    AnchorPoint = Vector2.new(0.5, 0.5),
                                    BackgroundTransparency = 1,
                                    Image = "rbxassetid://123413392379402",
                                    ImageColor3 = Color3.new(),
                                    ImageTransparency = 0.89,
                                    LayoutOrder = 2,
                                    ScaleType = Enum.ScaleType.Slice,
                                    Size = UDim2.fromScale(0.827583, 1),
                                    SliceCenter = Rect.new(512, 512, 512, 512),
                                    SliceScale = 2,

                                    [Children] = {
                                        s:New "TextLabel" {
                                            Name = "Cost",
                                            AnchorPoint = Vector2.new(0.5, 0.5),
                                            BackgroundTransparency = 1,
                                            FontFace = Font.new("rbxasset://fonts/families/HighwayGothic.json"),
                                            Position = UDim2.fromScale(0.5, 0.5),
                                            Size = UDim2.fromScale(0.9, 0.8),
                                            Text = s:Computed(function(use)
                                                local styleKey = use(Functions.SelectedStyle)
                                                if not styleKey then return "0" end
                                                local data = SharedConstants.pottteryData and SharedConstants.pottteryData[styleKey]
                                                return data and data.cost and tostring(data.cost.clay) or "0"
                                            end),
                                            TextColor3 = Color3.new(1, 1, 1),
                                            TextScaled = true,
                                            TextXAlignment = Enum.TextXAlignment.Left,

                                            [Children] = {
                                                s:New "UIStroke" {
                                                    Name = "UIStroke",
                                                    Color = Color3.fromRGB(214, 214, 214),
                                                    StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                                                    Thickness = 0.03,
                                                },
                                            }
                                        },
                                    }
                                },
                            }
                        },

                        -- Select button with hover effects
                        (function()
                            local isHovered = s:Value(false)
                            local isPressed = s:Value(false)
                            
                            local hasSelection = s:Computed(function(use)
                                return use(Functions.SelectedStyle) ~= nil
                            end)
                            
                            local buttonColor = s:Spring(
                                s:Computed(function(use)
                                    if not use(hasSelection) then
                                        return Color3.fromRGB(150, 150, 150) -- Grey when no selection
                                    end
                                    return Color3.fromRGB(0, 227, 121) -- Green when has selection
                                end),
                                15, 1
                            )
                            
                            local buttonScale = s:Spring(
                                s:Computed(function(use)
                                    if not use(hasSelection) then return 1 end
                                    if use(isPressed) then return 0.95 end
                                    if use(isHovered) then return 1.05 end
                                    return 1
                                end),
                                20, 0.6
                            )
                            
                            return s:New "ImageLabel" {
                                Name = "SelectButton",
                                AnchorPoint = Vector2.new(0.5, 0.5),
                                BackgroundTransparency = 1,
                                Image = "rbxassetid://123413392379402",
                                ImageColor3 = Color3.new(),
                                ImageTransparency = 0.89,
                                LayoutOrder = 4,
                                ScaleType = Enum.ScaleType.Slice,
                                Size = UDim2.fromScale(0.999915, 0.192466),
                                SliceCenter = Rect.new(512, 512, 512, 512),
                                SliceScale = 2,

                                [Children] = {
                                    s:New "ImageButton" {
                                        Name = "Button",
                                        AnchorPoint = Vector2.new(0.5, 0.5),
                                        BackgroundTransparency = 1,
                                        Image = "rbxassetid://123413392379402",
                                        ImageColor3 = buttonColor,
                                        Position = UDim2.fromScale(0.5, 0.5),
                                        ScaleType = Enum.ScaleType.Slice,
                                        Size = s:Computed(function(use)
                                            local scale = use(buttonScale)
                                            return UDim2.fromScale(scale, scale)
                                        end),
                                        SliceCenter = Rect.new(512, 512, 512, 512),
                                        SliceScale = 0.3,

                                        [OnEvent "Activated"] = function()
                                            local styleKey = peek(Functions.SelectedStyle)
                                            if styleKey then
                                                Functions:ConfirmStyle()
                                                Functions:Close()
                                            end
                                        end,
                                        
                                        [OnEvent "MouseEnter"] = function()
                                            if UserInputService.PreferredInput == Enum.PreferredInput.KeyboardAndMouse then
                                                isHovered:set(true)
                                            end
                                        end,
                                        
                                        [OnEvent "MouseLeave"] = function()
                                            isHovered:set(false)
                                            isPressed:set(false)
                                        end,
                                        
                                        [OnEvent "MouseButton1Down"] = function()
                                            isPressed:set(true)
                                        end,
                                        
                                        [OnEvent "MouseButton1Up"] = function()
                                            isPressed:set(false)
                                        end,

                                        [Children] = {
                                            s:New "TextLabel" {
                                                Name = "SelectText",
                                                AnchorPoint = Vector2.new(0.5, 0.5),
                                                BackgroundTransparency = 1,
                                                FontFace = Font.new("rbxasset://fonts/families/HighwayGothic.json"),
                                                Position = UDim2.fromScale(0.5, 0.5),
                                                Size = UDim2.fromScale(1, 0.8),
                                                Text = "Select",
                                                TextColor3 = Color3.new(1, 1, 1),
                                                TextScaled = true,
                                            },
                                        }
                                    },
                                }
                            }
                        end)(),
                    }
                },
                
                -- Exit button (using reusable component)
                ExitButton.new(s, {
                    Position = UDim2.fromScale(0.979167, -0.0503111),
                    Size = UDim2.fromScale(0.111607, 0.198597),
                    BaseRotation = -15,
                    OnActivated = function()
                        Functions:Close()
                    end,
                }),
            }
        },
    }
}