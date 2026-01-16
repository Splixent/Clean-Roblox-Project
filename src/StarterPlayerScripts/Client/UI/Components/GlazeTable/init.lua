local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared

local Fusion = require(Shared.Fusion)
local SharedConstants = require(Shared.Constants)
local Functions = require(script.Functions)
local ExitButton = require(script.Parent.Parent.ExitButton)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek

local scope = Functions.scope
local s = scope

-- Glaze tab icons (Color, Pattern, Finish)
local GLAZE_TAB_ICONS = {
    Color = "rbxassetid://89654639114187",
    Pattern = "rbxassetid://94606885334615",
    Finish = "rbxassetid://95126760327838",
}

-- Get finish icons from SharedConstants
local FINISH_ICONS = SharedConstants.glazeTypes.finishIcons

-- Glaze tab button (Color, Pattern, Finish) with animated colors
local function CreateGlazeTabButton(tabScope, tabKey: string, layoutOrder: number)
    local icon = GLAZE_TAB_ICONS[tabKey] or "rbxassetid://140498599498498"

    return tabScope:New "ImageButton" {
        Name = tabKey,
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        Image = icon,
        ImageColor3 = Functions.GlazeTabIconColors[tabKey],
        ImageTransparency = Functions.GlazeTabIconTransparencies[tabKey],
        LayoutOrder = layoutOrder,
        ScaleType = Enum.ScaleType.Fit,
        Size = UDim2.fromScale(0.138, 1.354),
        [OnEvent "Activated"] = function()
            Functions:SetGlazeTab(tabKey)
        end,
    }
end

-- Color button
local function CreateColorButton(colorScope, colorName: string, colorData, layoutOrder: number)
    local isSelected = colorScope:Computed(function(use)
        return use(Functions.SelectedColor) == colorName
    end)
    
    local strokeColor = colorScope:Spring(
        colorScope:Computed(function(use)
            if use(isSelected) then
                return Color3.fromRGB(81, 159, 255)
            else
                return Color3.fromRGB(199, 199, 199)
            end
        end),
        20, 0.8
    )
    
    local textColor = colorScope:Computed(function(use)
        if use(isSelected) then
            return Color3.fromRGB(81, 159, 255)
        else
            return Color3.fromRGB(177, 177, 177)
        end
    end)
    
    local displayName = colorData.displayName or colorName
    
    return colorScope:New "ImageButton" {
        Name = colorName,
        Active = true,
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Image = "rbxassetid://123413392379402",
        ImageColor3 = colorData.color,
        LayoutOrder = layoutOrder,
        ScaleType = Enum.ScaleType.Slice,
        Selectable = false,
        Size = UDim2.fromScale(0.201314, 0.898107),
        SliceCenter = Rect.new(512, 512, 512, 512),
        
        [OnEvent "Activated"] = function()
            Functions:SelectColor(colorName)
        end,
        
        [Children] = {
            colorScope:New "ImageLabel" {
                Name = "Stroke",
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundTransparency = 1,
                Image = "rbxassetid://82598953491471",
                ImageColor3 = strokeColor,
                Position = UDim2.fromScale(0.5, 0.5),
                ScaleType = Enum.ScaleType.Slice,
                Size = UDim2.fromScale(1.02, 1.02),
                SliceCenter = Rect.new(512, 512, 512, 512),
            },
            
            colorScope:New "TextLabel" {
                Name = "TextLabel",
                Active = true,
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundTransparency = 1,
                FontFace = Font.new("rbxasset://fonts/families/HighwayGothic.json"),
                Position = UDim2.fromScale(0.5, 0.0100936),
                Selectable = true,
                Size = UDim2.fromScale(1.05263, 0.168421),
                Text = displayName,
                TextColor3 = Color3.new(1, 1, 1),
                TextScaled = true,
                
                [Children] = {
                    colorScope:New "UIStroke" {
                        Name = "UIStroke",
                        Color = colorScope:Spring(textColor, 20, 0.8),
                        StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                        Thickness = 0.1,
                    },
                }
            },
        }
    }
end

-- Pattern button
local function CreatePatternButton(patternScope, patternName: string, patternData, layoutOrder: number, isStyleUnique: boolean?, isDisabled)
    if not patternData then
        warn("CreatePatternButton: patternData is nil for", patternName)
        -- Return a placeholder frame since CreateEmptySlot isn't available yet
        return patternScope:New "Frame" {
            Name = "EmptyPattern",
            LayoutOrder = layoutOrder,
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(190, 190),
        }
    end
    
    local isSelected = patternScope:Computed(function(use)
        return use(Functions.SelectedPattern) == patternName
    end)
    
    local strokeColor = patternScope:Spring(
        patternScope:Computed(function(use)
            if use(isSelected) then
                return Color3.fromRGB(81, 159, 255)
            else
                return Color3.fromRGB(199, 199, 199)
            end
        end),
        20, 0.8
    )

	local textColor = patternScope:Computed(function(use)
		if use(isDisabled) then
			return Color3.fromRGB(150, 150, 150)
		end
		if use(isSelected) then
			return Color3.fromRGB(81, 159, 255)
		else
			return Color3.fromRGB(177, 177, 177)
		end
	end)
    
    local displayName = patternData.displayName or patternName
    local icon = patternData.icon or "rbxassetid://123413392379402"
    
    local children = {
        patternScope:New "ImageLabel" {
            Name = "Stroke",
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            Image = "rbxassetid://82598953491471",
            ImageColor3 = strokeColor,
            Position = UDim2.fromScale(0.5, 0.5),
            ScaleType = Enum.ScaleType.Slice,
            Size = UDim2.fromScale(1, 1),
            SliceCenter = Rect.new(512, 512, 512, 512),
        },
        
        patternScope:New "TextLabel" {
            Name = "TextLabel",
            Active = true,
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            FontFace = Font.new("rbxasset://fonts/families/HighwayGothic.json"),
            Position = UDim2.fromScale(0.5, 0.0100936),
            Selectable = true,
            Size = UDim2.fromScale(1.05263, 0.168421),
            Text = displayName,
            TextColor3 = Color3.new(1, 1, 1),
            TextScaled = true,
            
            [Children] = {
                patternScope:New "UIStroke" {
                    Name = "UIStroke",
                    Color = patternScope:Spring(textColor, 20, 0.8),
                    StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                    Thickness = 0.1,
                },
            }
        },
    }
    
    if isStyleUnique then
        table.insert(children, patternScope:New "ImageLabel" {
            Name = "StyleUnique",
            BackgroundTransparency = 1,
            Image = "rbxassetid://135533654534105",
            ImageColor3 = Color3.fromRGB(255, 195, 0),
            LayoutOrder = 5,
            Position = UDim2.fromScale(0.064156, 0.654208),
            ScaleType = Enum.ScaleType.Fit,
            Size = UDim2.fromScale(0.31329, 0.343106),
        })
    end
    
    return patternScope:New "ImageButton" {
        Name = patternName,
        Active = true,
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Image = icon,
        LayoutOrder = layoutOrder,
        ScaleType = Enum.ScaleType.Tile,
        Selectable = false,
        Size = UDim2.fromScale(0.201314, 0.898107),
        SliceCenter = Rect.new(512, 512, 512, 512),
        SliceScale = 0.2,
        
        [OnEvent "Activated"] = function()
            Functions:SelectPattern(patternName)
        end,
        
        [Children] = children
    }
end

-- Finish button
local function CreateFinishButton(finishScope, finishName: string?, finishData, icon: string, layoutOrder: number, isDisabled)
    local isSelected = finishScope:Computed(function(use)
        local selected = use(Functions.SelectedFinish)
        if finishName == nil then
            return selected == nil
        end
        return selected == finishName
    end)
    
    local strokeColor = finishScope:Spring(
        finishScope:Computed(function(use)
            if use(isDisabled) then
                return Color3.fromRGB(150, 150, 150)
            end
            if use(isSelected) then
                return Color3.fromRGB(81, 159, 255)
            else
                return Color3.fromRGB(199, 199, 199)
            end
        end),
        20, 0.8
    )

    local textColor = finishScope:Computed(function(use)
        if use(isDisabled) then
            return Color3.fromRGB(150, 150, 150)
        end
        if use(isSelected) then
            return Color3.fromRGB(81, 159, 255)
        else
            return Color3.fromRGB(177, 177, 177)
        end
    end)
    
    local imageTransparency = finishScope:Computed(function(use)
        return use(isDisabled) and 0.7 or 0
    end)
    
    local displayName = finishData and finishData.displayName or "No Finish"
    
    return finishScope:New "ImageButton" {
        Name = finishName or "NoFinish",
        Active = finishScope:Computed(function(use)
            return not use(isDisabled)
        end),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Image = icon,
        ImageTransparency = imageTransparency,
        LayoutOrder = layoutOrder,
        ScaleType = Enum.ScaleType.Tile,
        Selectable = false,
        Size = UDim2.fromScale(0.201314, 0.898107),
        SliceCenter = Rect.new(512, 512, 512, 512),
        SliceScale = 0.2,
        
        [OnEvent "Activated"] = function()
            if not peek(isDisabled) then
                Functions:SelectFinish(finishName)
            end
        end,
        
        [Children] = {
            finishScope:New "ImageLabel" {
                Name = "Stroke",
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundTransparency = 1,
                Image = "rbxassetid://82598953491471",
                ImageColor3 = strokeColor,
                Position = UDim2.fromScale(0.5, 0.5),
                ScaleType = Enum.ScaleType.Slice,
                Size = UDim2.fromScale(1, 1),
                SliceCenter = Rect.new(512, 512, 512, 512),
            },
            
            finishScope:New "TextLabel" {
                Name = "TextLabel",
                Active = true,
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundTransparency = 1,
                FontFace = Font.new("rbxasset://fonts/families/HighwayGothic.json"),
                Position = UDim2.fromScale(0.5, 0.0100936),
                Selectable = true,
                Size = UDim2.fromScale(1.05263, 0.168421),
                Text = displayName,
                TextColor3 = Color3.new(1, 1, 1),
                TextScaled = true,
                
                [Children] = {
                    finishScope:New "UIStroke" {
                        Name = "UIStroke",
                        Color = finishScope:Spring(textColor, 20, 0.8),
                        StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                        Thickness = 0.1,
                    },
                }
            },
        }
    }
end

-- Empty slot
local function CreateEmptySlot(slotScope, layoutOrder: number)
    return slotScope:New "ImageButton" {
        Name = "Empty",
        Active = false,
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Image = "rbxassetid://123413392379402",
        ImageColor3 = Color3.fromRGB(235, 235, 235),
        LayoutOrder = layoutOrder,
        ScaleType = Enum.ScaleType.Slice,
        Selectable = false,
        Size = UDim2.fromScale(0.201314, 0.898107),
        SliceCenter = Rect.new(512, 512, 512, 512),
    }
end

-- Section name text
local SectionName = s:Computed(function(use)
    local tab = use(Functions.CurrentGlazeTab)
    if tab == Functions.GlazeTabs.Color then
        return "Color"
    elseif tab == Functions.GlazeTabs.Pattern then
        return "Pattern"
    elseif tab == Functions.GlazeTabs.Finish then
        return "Finish"
    end
    return "Color"
end)

-- Build color buttons
local function BuildColorChildren()
    local children = {
        s:New "UIGridLayout" {
            Name = "UIGridLayout",
            CellPadding = UDim2.fromOffset(21, 21),
            CellSize = UDim2.fromOffset(190, 190),
            SortOrder = Enum.SortOrder.LayoutOrder,
            FillDirection = Enum.FillDirection.Vertical,
        },
    }
    
    for i, colorData in ipairs(SharedConstants.glazeTypes.colors) do
        table.insert(children, CreateColorButton(s, colorData.name, colorData, i))
    end
    
    local buttonCount = #children - 1
    for i = 1, math.max(0, 5 - buttonCount) do
        table.insert(children, CreateEmptySlot(s, buttonCount + i))
    end
    
    return children
end

-- Build pattern children - reactive to style-unique patterns
local function BuildPatternChildren()
    -- Create a computed that builds the pattern buttons reactively
    local PatternButtons = s:Computed(function(use)
        local buttons = {}
        
        -- Add global patterns first
        for i, patternData in ipairs(SharedConstants.glazeTypes.patterns) do
            local isDisabled = s:Value(false)
            table.insert(buttons, CreatePatternButton(s, patternData.name, patternData, i, false, isDisabled))
        end
        
        -- Add style-unique patterns from Constants
        local styleKey = use(Functions.PotteryStyleKey)
        if styleKey and SharedConstants.glazeTypes.uniquePatterns then
            local styleUniqueData = SharedConstants.glazeTypes.uniquePatterns[styleKey]
            if styleUniqueData and styleUniqueData.patterns then
                -- Handle both single pattern object and array of patterns
                local patternsToAdd = styleUniqueData.patterns
                if patternsToAdd.name then
                    -- Single pattern object, wrap in array
                    patternsToAdd = {patternsToAdd}
                end
                
                local baseOrder = #SharedConstants.glazeTypes.patterns
                for i, patternData in ipairs(patternsToAdd) do
                    local isDisabled = s:Value(false)
                    table.insert(buttons, CreatePatternButton(s, patternData.name, patternData, baseOrder + i, true, isDisabled))
                end
            end
        end
        
        -- Add empty slots to fill to 5
        local patternCount = #buttons
        for i = 1, math.max(0, 5 - patternCount) do
            table.insert(buttons, CreateEmptySlot(s, patternCount + i))
        end
        
        return buttons
    end)
    
    return {
        s:New "UIGridLayout" {
            Name = "UIGridLayout",
            CellPadding = UDim2.fromOffset(21, 21),
            CellSize = UDim2.fromOffset(190, 190),
            SortOrder = Enum.SortOrder.LayoutOrder,
            FillDirection = Enum.FillDirection.Vertical,
        },
        PatternButtons,
    }
end

-- Build finish buttons - reactive to selected pattern (for style-unique pattern finishes)
local function BuildFinishChildren()
    -- Create a computed that builds finish buttons reactively
    local FinishButtons = s:Computed(function(use)
        local buttons = {}
        
        local isStyleUnique = use(Functions.IsStyleUniquePattern)
        local selectedPattern = use(Functions.SelectedPattern)
        
        if isStyleUnique and selectedPattern then
            -- Show only the finishes available for this style-unique pattern
            local availableFinishes = Functions:GetAvailableFinishes(selectedPattern)
            
            -- Add noFinish option first
            local noFinishDisabled = s:Value(false)
            table.insert(buttons, CreateFinishButton(s, nil, nil, FINISH_ICONS.noFinish, 0, noFinishDisabled))
            
            -- Add available finishes for this style-unique pattern
            for i, finishName in ipairs(availableFinishes) do
                -- Find finish data from Constants
                local finishData = nil
                for _, fd in ipairs(SharedConstants.glazeTypes.finishes) do
                    if fd.name == finishName then
                        finishData = fd
                        break
                    end
                end
                
                -- If not found in global finishes, search in style-unique pattern finishes
                if not finishData then
                    local styleKey = peek(Functions.PotteryStyleKey)
                    if styleKey and SharedConstants.glazeTypes.uniquePatterns and SharedConstants.glazeTypes.uniquePatterns[styleKey] then
                        local styleUniqueData = SharedConstants.glazeTypes.uniquePatterns[styleKey]
                        if styleUniqueData.patterns then
                            -- patterns is an array
                            for _, patternObj in ipairs(styleUniqueData.patterns) do
                                if patternObj.name == selectedPattern and patternObj.finishes then
                                    local finishesToCheck = patternObj.finishes
                                    if finishesToCheck.name then
                                        -- Single finish object
                                        if finishesToCheck.name == finishName then
                                            finishData = finishesToCheck
                                        end
                                    else
                                        -- Array of finishes
                                        for _, finishObj in ipairs(finishesToCheck) do
                                            if finishObj.name == finishName then
                                                finishData = finishObj
                                                break
                                            end
                                        end
                                    end
                                    break
                                end
                            end
                        end
                    end
                end
                
                if finishData then
                    local icon = FINISH_ICONS[finishName] or "rbxassetid://123413392379402"
                    local isDisabled = s:Value(false)
                    table.insert(buttons, CreateFinishButton(s, finishData.name, finishData, icon, i, isDisabled))
                end
            end
        else
            -- Show all global finishes
            local noFinishDisabled = s:Value(false)
            table.insert(buttons, CreateFinishButton(s, nil, nil, FINISH_ICONS.noFinish, 0, noFinishDisabled))
            
            for i, finishData in ipairs(SharedConstants.glazeTypes.finishes) do
                local icon = FINISH_ICONS[finishData.name] or "rbxassetid://123413392379402"
                local isDisabled = s:Value(false)
                table.insert(buttons, CreateFinishButton(s, finishData.name, finishData, icon, i, isDisabled))
            end
        end
        
        -- Add empty slots to fill to 6 (1 noFinish + 5 finishes max)
        local buttonCount = #buttons
        for i = 1, math.max(0, 6 - buttonCount) do
            table.insert(buttons, CreateEmptySlot(s, buttonCount + i))
        end
        
        return buttons
    end)

    return {
        s:New "UIGridLayout" {
            Name = "UIGridLayout",
            CellPadding = UDim2.fromOffset(21, 21),
            CellSize = UDim2.fromOffset(190, 190),
            SortOrder = Enum.SortOrder.LayoutOrder,
            FillDirection = Enum.FillDirection.Vertical,
        },
        FinishButtons,
    }
end

local function Component()
    local ColorVisible = s:Computed(function(use)
        return use(Functions.CurrentGlazeTab) == Functions.GlazeTabs.Color
    end)
    
    local PatternVisible = s:Computed(function(use)
        return use(Functions.CurrentGlazeTab) == Functions.GlazeTabs.Pattern
    end)
    
    local FinishVisible = s:Computed(function(use)
        return use(Functions.CurrentGlazeTab) == Functions.GlazeTabs.Finish
    end)
    
    -- Springs for section name position and size (use Computed to build UDim2 from spring values)
    local SectionNamePosition = s:Spring(
        s:Computed(function(use)
            local tab = use(Functions.CurrentGlazeTab)
            local data = Functions.TAB_NAME_DATA[tab]
            return data and data.position or UDim2.new(0.0975842, 0, 0.00614222, 0)
        end),
        25, 0.8
    )
    
    local SectionNameSize = s:Spring(
        s:Computed(function(use)
            local tab = use(Functions.CurrentGlazeTab)
            local data = Functions.TAB_NAME_DATA[tab]
            return data and data.size or UDim2.new(0.0723784, 0, 0.0429955, 0)
        end),
        25, 0.8
    )
    
    return s:New "Frame" {
        Name = "GlazeTable",
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0.499739, 0.493519),
        Size = UDim2.fromScale(1, 1),
        
        [Children] = {
            s:New "Frame" {
                Name = "Container",
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = Color3.new(1, 1, 1),
                BackgroundTransparency = 1,
                BorderColor3 = Color3.new(),
                BorderSizePixel = 0,
                Position = Functions.AnimatedPosition,
                Rotation = Functions.AnimatedRotation,
                Size = UDim2.fromScale(0.530208, 0.410587),
                ZIndex = -1,
                
                [Children] = {
                    -- Section name container (animated)
                    s:New "Frame" {
                        Name = "SectionNameContainer",
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundColor3 = Functions.SectionNameColor,
                        Position = SectionNamePosition,
                        Size = SectionNameSize,
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
                                Size = UDim2.fromScale(100, 0.8),
                                Text = SectionName,
                                TextColor3 = Color3.new(1, 1, 1),
                                TextScaled = true,
                            },
                        }
                    },
                    
                    -- Glaze tab buttons (Color, Pattern, Finish) - replaces StyleSections
                    s:New "Frame" {
                        Name = "GlazeTabs",
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundTransparency = 1,
                        Position = UDim2.fromScale(0.502947, 0.133176),
                        Size = UDim2.fromScale(0.927308, 0.216693),
                        ZIndex = 2,
                        
                        [Children] = {
                            s:New "UIListLayout" {
                            Name = "UIListLayout",
                            FillDirection = Enum.FillDirection.Horizontal,
                            Padding = UDim.new(0.0149861, 0),
                            SortOrder = Enum.SortOrder.LayoutOrder,
                            VerticalAlignment = Enum.VerticalAlignment.Center,
                            HorizontalAlignment = Enum.HorizontalAlignment.Center,
                        },
                            
                            CreateGlazeTabButton(s, "Color", 1),
                            CreateGlazeTabButton(s, "Pattern", 2),
                            CreateGlazeTabButton(s, "Finish", 3),
                        }
                    },
                    
                    -- Exit button
                    ExitButton.new(s, {
                        Position = UDim2.fromScale(0.991159, 0.0406299),
                        Size = UDim2.fromScale(0.131631, 0.239265),
                        BaseRotation = 0,
                        OnActivated = function()
                            Functions:Close()
                        end,
                    }),
                    
                    -- Background
                    s:New "ImageLabel" {
                        Name = "Background",
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundTransparency = 1,
                        Image = "rbxassetid://123413392379402",
                        Position = UDim2.fromScale(0.5, 0.498845),
                        ScaleType = Enum.ScaleType.Slice,
                        Size = UDim2.fromScale(1, 0.999953),
                        SliceCenter = Rect.new(512, 512, 512, 512),
                        SliceScale = 0.2,
                        ZIndex = -1,
                    },
                    
                    -- Select button
                    s:New "ImageLabel" {
                        Name = "SelectButton",
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundTransparency = 1,
                        Image = "rbxassetid://123413392379402",
                        ImageColor3 = Functions.SelectButtonColor,
                        Position = UDim2.fromScale(0.502947, 0.866771),
                        ScaleType = Enum.ScaleType.Slice,
                        Size = s:Computed(function(use)
                            local scale = use(Functions.SelectScale)
                            return UDim2.fromScale(0.927308 * scale, 0.124147 * scale)
                        end),
                        SliceCenter = Rect.new(512, 512, 512, 512),
                        SliceScale = 0.3,
                        ZIndex = 0,
                        
                        [Children] = {
                            s:New "TextLabel" {
                                Name = "SectionName",
                                AnchorPoint = Vector2.new(0.5, 0.5),
                                BackgroundTransparency = 1,
                                FontFace = Font.new("rbxasset://fonts/families/HighwayGothic.json"),
                                Position = UDim2.fromScale(0.5, 0.5),
                                Size = UDim2.fromScale(1, 0.8),
                                Text = "Select",
                                TextColor3 = Color3.new(1, 1, 1),
                                TextScaled = true,
                            },
                            
                            s:New "TextButton" {
                                Name = "ClickArea",
                                AnchorPoint = Vector2.new(0.5, 0.5),
                                BackgroundTransparency = 1,
                                Position = UDim2.fromScale(0.5, 0.5),
                                Size = UDim2.fromScale(1, 1),
                                Text = "",
                                
                                [OnEvent "Activated"] = function()
                                    Functions:ConfirmSelection()
                                end,
                                
                                [OnEvent "MouseEnter"] = function()
                                    if UserInputService.PreferredInput == Enum.PreferredInput.KeyboardAndMouse then
                                        Functions.SelectHovered:set(true)
                                    end
                                end,
                                
                                [OnEvent "MouseLeave"] = function()
                                    Functions.SelectHovered:set(false)
                                    Functions.SelectPressed:set(false)
                                end,
                                
                                [OnEvent "MouseButton1Down"] = function()
                                    Functions.SelectPressed:set(true)
                                end,
                                
                                [OnEvent "MouseButton1Up"] = function()
                                    Functions.SelectPressed:set(false)
                                end,
                            },
                        }
                    },
                    
                    -- Glaze types (Color, Pattern, Finish tabs)
                    s:New "CanvasGroup" {
                        Name = "GlazeTypes",
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundTransparency = 1,
                        Position = UDim2.fromScale(0.500982, 0.512388),
                        Size = UDim2.fromScale(0.946955, 0.521417),
                        
                        [Children] = {
                            -- Color tab
                            s:New "Frame" {
                                Name = "Color",
                                AnchorPoint = Vector2.new(0.5, 0.5),
                                BackgroundTransparency = 1,
                                ClipsDescendants = true,
                                Position = UDim2.fromScale(0.5, 0.5),
                                Size = UDim2.fromScale(1, 1),
                                Visible = ColorVisible,
                                
                                [Children] = {
                                    s:New "ScrollingFrame" {
                                        Name = "ScrollingFrame_Horizontal",
                                        AnchorPoint = Vector2.new(0.5, 0.5),
                                        BackgroundTransparency = 1,
                                        CanvasSize = UDim2.fromScale(10, 0),
                                        ClipsDescendants = false,
                                        Position = UDim2.fromScale(0.501323, 0.522267),
                                        ScrollBarImageColor3 = Color3.fromRGB(183, 183, 183),
                                        Selectable = false,
                                        Size = UDim2.fromScale(0.979557, 0.91498),
                                        VerticalScrollBarPosition = Enum.VerticalScrollBarPosition.Left,
                                        ScrollingDirection = Enum.ScrollingDirection.X,
                                        
                                        [Children] = BuildColorChildren()
                                    },
                                }
                            },
                            
                            -- UIGradient for edge fade
                            s:New "UIGradient" {
                                Name = "UIGradient",
                                Transparency = NumberSequence.new({
                                    NumberSequenceKeypoint.new(0, 1),
                                    NumberSequenceKeypoint.new(0.00928074, 0),
                                    NumberSequenceKeypoint.new(0.989559, 0),
                                    NumberSequenceKeypoint.new(1, 1),
                                }),
                            },
                            
                            -- Pattern tab
                            s:New "Frame" {
                                Name = "Pattern",
                                AnchorPoint = Vector2.new(0.5, 0.5),
                                BackgroundTransparency = 1,
                                ClipsDescendants = true,
                                Position = UDim2.fromScale(0.5, 0.5),
                                Size = UDim2.fromScale(1, 1),
                                Visible = PatternVisible,
                                
                                [Children] = {
                                    s:New "ScrollingFrame" {
                                        Name = "ScrollingFrame_Horizontal",
                                        AnchorPoint = Vector2.new(0.5, 0.5),
                                        BackgroundTransparency = 1,
                                        CanvasSize = UDim2.fromScale(10, 0),
                                        ClipsDescendants = false,
                                        Position = UDim2.fromScale(0.501323, 0.522267),
                                        ScrollBarImageColor3 = Color3.fromRGB(183, 183, 183),
                                        Selectable = false,
                                        Size = UDim2.fromScale(0.979557, 0.91498),
                                        VerticalScrollBarPosition = Enum.VerticalScrollBarPosition.Left,
                                        ScrollingDirection = Enum.ScrollingDirection.X,
                                        
                                        [Children] = BuildPatternChildren()
                                    },
                                }
                            },
                            
                            -- Finish tab
                            s:New "Frame" {
                                Name = "Finish",
                                AnchorPoint = Vector2.new(0.5, 0.5),
                                BackgroundTransparency = 1,
                                ClipsDescendants = true,
                                Position = UDim2.fromScale(0.5, 0.5),
                                Size = UDim2.fromScale(1, 1),
                                Visible = FinishVisible,
                                
                                [Children] = {
                                    s:New "ScrollingFrame" {
                                        Name = "ScrollingFrame_Horizontal",
                                        AnchorPoint = Vector2.new(0.5, 0.5),
                                        BackgroundTransparency = 1,
                                        CanvasSize = UDim2.fromScale(10, 0),
                                        ClipsDescendants = false,
                                        Position = UDim2.fromScale(0.501323, 0.522267),
                                        ScrollBarImageColor3 = Color3.fromRGB(183, 183, 183),
                                        Selectable = false,
                                        Size = UDim2.fromScale(0.979557, 0.91498),
                                        VerticalScrollBarPosition = Enum.VerticalScrollBarPosition.Left,
                                        ScrollingDirection = Enum.ScrollingDirection.X,
                                        
                                        [Children] = BuildFinishChildren()
                                    },
                                }
                            },
                        }
                    },
                }
            },
        }
    }
end

return Component()
