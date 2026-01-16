local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared

local Fusion = require(Shared.Fusion)
local SharedConstants = require(Shared.Constants)
local ScriptUtils = require(Shared.ScriptUtils)
local Functions = require(script.Functions)
local ExitButton = require(script.Parent.Parent.ExitButton)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek

local scope = Functions.scope
local s = scope

-- Helper function to create an empty placeholder slot
local function CreateEmptySlot(slotScope, slotIndex: number)
    return slotScope:New "Frame" {
        Name = "EmptySlot_" .. slotIndex,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(0.334443, 0.889381),
        LayoutOrder = slotIndex,

        [Children] = {
            slotScope:New "ImageLabel" {
                Name = "Container",
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundTransparency = 1,
                Image = "rbxassetid://123413392379402",
                ImageColor3 = Color3.fromRGB(180, 180, 180),
                ImageTransparency = 0.5,
                Position = UDim2.fromScale(0.5, 0.5),
                ScaleType = Enum.ScaleType.Slice,
                Size = UDim2.fromScale(0.9, 0.9),
                SliceCenter = Rect.new(512, 512, 512, 512),
            },
        }
    }
end

-- Helper function to create a slot item for the scrolling frame
local function CreateSlotItem(slotScope, slotData, slotIndex: number, kilnLevel: number?)
    local ss = slotScope
    
    -- Get style data
    local styleKey = slotData.styleKey
    local potteryData = SharedConstants.pottteryData and SharedConstants.pottteryData[styleKey]
    local styleName = potteryData and potteryData.name or styleKey
    
    -- Get clay type for color
    local clayType = slotData.clayType or (potteryData and potteryData.clayType) or "normal"
    local clayTypeData = SharedConstants.clayTypes[clayType] or SharedConstants.clayTypes.normal
    
    -- Get level stats for multipliers
    local levelKey = tostring(kilnLevel or 0)
    local levelStats = SharedConstants.potteryStationInfo.Kiln.levelStats[levelKey] or SharedConstants.potteryStationInfo.Kiln.levelStats["0"]
    local fireTimeMultiplier = levelStats.fireTimeMultiplier or 1.0
    
    -- Calculate actual duration using the same formula as server
    local firingDuration = ScriptUtils:CalculateFiringDuration(clayType, styleKey, fireTimeMultiplier)
    
    -- Progress color: orange/red for firing
    local firingColor = Color3.fromRGB(255, 120, 55)
    local greyColor = Color3.fromRGB(140, 140, 140)
    local progressColor = firingColor
    
    local totalDuration = firingDuration
    
    -- Reactive state
    local RemainingTime = ss:Value(0)
    
    -- Calculate time offset between os.time() and tick() for sub-second precision
    local timeOffset = tick() - os.time()
    
    -- Smooth progress value that updates every frame
    local SmoothProgress = ss:Value(0)
    local lastProgress = 0
    
    -- Progress Left rotation: 0% = 0, 50% = 0, 100% = 180 (directly from smooth progress)
    local AnimatedLeftRotation = ss:Computed(function(use)
        local progress = use(SmoothProgress)
        if progress < 0.5 then
            return 0
        else
            return (progress - 0.5) * 2 * 180
        end
    end)
    
    -- Is complete
    local IsComplete = ss:Computed(function(use)
        return use(RemainingTime) <= 0
    end)
    
    -- Flash spring for green glow
    local FlashValue = ss:Value(0)
    local FlashSpring = ss:Spring(FlashValue, 25, 0.5)
    
    -- Viewport model color (reactive for smooth color changes)
    local ViewportModelColor = ss:Value(clayTypeData.driedColor or clayTypeData.color)
    
    local LeftGradientTransparency = ss:Computed(function(use)
        if use(IsComplete) then
            return NumberSequence.new(1)
        end
        return NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.5, 0),
            NumberSequenceKeypoint.new(0.501, 1),
            NumberSequenceKeypoint.new(1, 1),
        })
    end)
    
    -- Progress Right rotation: smooth lerp 0-50%, snap at 50%, stay at -180 after
    local AnimatedRightRotation = ss:Value(-180)
    
    local RightColor = ss:Computed(function(use)
        local progress = use(SmoothProgress)
        if progress < 0.5 then
            return progressColor
        else
            return greyColor
        end
    end)
    
    local RightGradientTransparency = ss:Computed(function(use)
        if use(IsComplete) then
            return NumberSequence.new(1)
        end
        return NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.5, 0),
            NumberSequenceKeypoint.new(0.501, 1),
            NumberSequenceKeypoint.new(1, 1),
        })
    end)
    
    -- Update timer, flash, and progress
    local flashTimer = 0
    local flashState = false
    local updateConnection = RunService.Heartbeat:Connect(function(dt)
        local currentTick = tick()
        
        -- Calculate remaining time with sub-second precision
        local startTick = slotData.startTime + timeOffset
        local endTick = slotData.endTime + timeOffset
        local remaining = math.max(0, endTick - currentTick)
        
        RemainingTime:set(remaining)
        
        -- Calculate smooth progress
        local currentProgress = math.clamp(1 - (remaining / totalDuration), 0, 1)
        
        -- Detect snap: progress crossed 0.5 threshold
        local crossedHalf = (lastProgress < 0.5 and currentProgress >= 0.5)
        
        -- Update smooth progress
        SmoothProgress:set(currentProgress)
        
        -- Right rotation: smooth lerp 0-50%, snap at 50%, stay at -180 after
        if currentProgress < 0.5 then
            local rightRot = -180 + (currentProgress * 2 * 180)
            AnimatedRightRotation:set(rightRot)
        elseif crossedHalf then
            AnimatedRightRotation:set(-180)
        end
        
        lastProgress = currentProgress
        
        -- Flash green when complete
        local allComplete = remaining <= 0
        if allComplete then
            flashTimer = flashTimer + dt
            if flashTimer >= 0.5 then
                flashTimer = 0
                flashState = not flashState
                FlashSpring:setPosition(flashState and 1 or 0)
                FlashValue:set(flashState and 0 or 1)
            end
        end
        
        -- Update viewport model color based on firing progress
        if slotData.startTime then
            local firingProgress = ScriptUtils:GetFiringProgress(slotData.startTime, firingDuration)
            local currentColor = ScriptUtils:GetFiringColor(clayType, firingProgress)
            ViewportModelColor:set(currentColor)
        end
    end)
    table.insert(slotScope, updateConnection)
    
    -- Get pottery model for viewport
    local modelTemplate = nil
    local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
    if assetsFolder then
        local potteryStyles = assetsFolder:FindFirstChild("PotteryStyles")
        if potteryStyles then
            local styleFolder = potteryStyles:FindFirstChild(styleName)
            if styleFolder then
                modelTemplate = styleFolder:FindFirstChild("Model")
            end
        end
    end
    
    -- Clone model for viewport
    local viewportModel = modelTemplate and modelTemplate:Clone() or nil
    local modelParts = {}
    if viewportModel then
        local currentColor = clayTypeData.driedColor or clayTypeData.color
        if slotData.startTime then
            local firingProgress = ScriptUtils:GetFiringProgress(slotData.startTime, firingDuration)
            currentColor = ScriptUtils:GetFiringColor(clayType, firingProgress)
        end
        
        for _, part in ipairs(viewportModel:GetDescendants()) do
            if part:IsA("BasePart") and part.Material == Enum.Material.Mud then
                part.Color = currentColor
                table.insert(modelParts, part)
            end
        end
    end
    
    -- Update viewport model colors reactively
    local colorUpdateConnection = RunService.Heartbeat:Connect(function()
        local newColor = peek(ViewportModelColor)
        for _, part in ipairs(modelParts) do
            if part and part.Parent then
                part.Color = newColor
            end
        end
    end)
    table.insert(slotScope, colorUpdateConnection)
    
    -- Create viewport camera
    local viewportCamera = ss:New "Camera" {
        Name = "Camera",
        CFrame = CFrame.new(0, 20, 20) * CFrame.Angles(math.rad(-20), 0, 0),
    }
    
    -- Background stroke color (flashes green when complete)
    local StrokeColor = ss:Computed(function(use)
        if use(IsComplete) then
            local flash = use(FlashSpring)
            local grey = Color3.fromRGB(133, 133, 133)
            local green = Color3.fromRGB(0, 255, 0)
            return grey:Lerp(green, flash)
        end
        return Color3.fromRGB(133, 133, 133)
    end)
    
    -- Text color (green when done)
    local TextColor = ss:Computed(function(use)
        if use(IsComplete) then
            return Color3.fromRGB(0, 255, 0)
        end
        return Color3.new(1, 1, 1)
    end)
    
    -- Remove button hover state
    local RemoveHovered = ss:Value(false)
    local RemovePressed = ss:Value(false)
    
    local RemoveScale = ss:Spring(ss:Computed(function(use)
        if use(RemovePressed) then return 0.9 end
        if use(RemoveHovered) then return 1.2 end
        return 1
    end), 30, 0.7)
    
    local RemoveRotation = ss:Spring(ss:Computed(function(use)
        if use(RemoveHovered) then return 10 end
        return 0
    end), 15, 0.5)
    
    -- Container hover state
    local isHovered = ss:Value(false)
    
    local containerRotation = ss:Spring(
        ss:Computed(function(use)
            return use(isHovered) and 5 or 0
        end),
        20, 0.6
    )
    
    local containerScale = ss:Spring(
        ss:Computed(function(use)
            return use(isHovered) and 1.05 or 1
        end),
        20, 0.6
    )
    
    -- Build children array
    local containerChildren = {
        ss:New "ViewportFrame" {
            Name = "ViewportFrame",
            Ambient = Color3.new(),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            LightColor = Color3.new(1, 1, 1),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromScale(0.85, 0.85),
            CurrentCamera = viewportCamera,

            [Children] = {
                viewportModel,
                viewportCamera,
            }
        },

        ss:New "TextLabel" {
            Name = "Progress",
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            FontFace = Font.new(
                "rbxasset://fonts/families/HighwayGothic.json",
                Enum.FontWeight.Bold,
                Enum.FontStyle.Normal
            ),
            Position = UDim2.fromScale(0.5, 0.12),
            Size = UDim2.fromScale(0.8, 0.15),
            Text = ss:Computed(function(use)
                return Functions.FormatTime(use(RemainingTime))
            end),
            TextColor3 = TextColor,
            TextScaled = true,

            [Children] = {
                ss:New "UIStroke" {
                    Name = "UIStroke",
                    Color = Color3.fromRGB(102, 102, 102),
                    StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                    Thickness = 0.05,
                },
            }
        },

        ss:New "ImageLabel" {
            Name = "ProgressLeft",
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            Image = "rbxassetid://82598953491471",
            ImageColor3 = progressColor,
            Position = UDim2.fromScale(0.5, 0.5),
            ScaleType = Enum.ScaleType.Slice,
            Size = UDim2.fromScale(1.02, 1.02),
            SliceCenter = Rect.new(512, 512, 512, 512),
            ZIndex = -1,

            [Children] = {
                ss:New "UIGradient" {
                    Name = "UIGradient",
                    Rotation = AnimatedLeftRotation,
                    Transparency = LeftGradientTransparency,
                },
            }
        },

        ss:New "ImageLabel" {
            Name = "ProgressRight",
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            Image = "rbxassetid://82598953491471",
            ImageColor3 = RightColor,
            Position = UDim2.fromScale(0.5, 0.5),
            ScaleType = Enum.ScaleType.Slice,
            Size = UDim2.fromScale(1.02, 1.02),
            SliceCenter = Rect.new(512, 512, 512, 512),
            ZIndex = 0,

            [Children] = {
                ss:New "UIGradient" {
                    Name = "UIGradient",
                    Rotation = AnimatedRightRotation,
                    Transparency = RightGradientTransparency,
                },
            }
        },

        ss:New "ImageLabel" {
            Name = "BackgroundStroke",
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            Image = "rbxassetid://82598953491471",
            ImageColor3 = StrokeColor,
            Position = UDim2.fromScale(0.5, 0.5),
            ScaleType = Enum.ScaleType.Slice,
            Size = UDim2.fromScale(1.02, 1.02),
            SliceCenter = Rect.new(512, 512, 512, 512),
            ZIndex = -2,
        },
        
        -- Invisible button for click detection
        ss:New "ImageButton" {
            Name = "SelectButton",
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            
            [OnEvent "Activated"] = function()
                if Functions.OnCollect then
                    Functions.OnCollect(slotIndex)
                end
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
    
    -- Add remove button
    table.insert(containerChildren, ss:New "TextButton" {
        Name = "Remove",
        Active = true,
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
        Position = UDim2.fromScale(0.92, 0.08),
        Rotation = RemoveRotation,
        Size = ss:Computed(function(use)
            local scale = use(RemoveScale)
            return UDim2.fromScale(0.3 * scale, 0.3 * scale)
        end),
        Text = "X",
        TextColor3 = Color3.fromRGB(255, 0, 4),
        TextScaled = true,
        ZIndex = 10,

        [OnEvent "Activated"] = function()
            if Functions.OnDelete then
                Functions.OnDelete(slotIndex)
            end
        end,
        
        [OnEvent "MouseEnter"] = function()
            if UserInputService.PreferredInput == Enum.PreferredInput.KeyboardAndMouse then
                RemoveHovered:set(true)
            end
        end,
        
        [OnEvent "MouseLeave"] = function()
            RemoveHovered:set(false)
            RemovePressed:set(false)
        end,
        
        [OnEvent "MouseButton1Down"] = function()
            RemovePressed:set(true)
        end,
        
        [OnEvent "MouseButton1Up"] = function()
            RemovePressed:set(false)
        end,

        [Children] = {
            ss:New "UIAspectRatioConstraint" {
                Name = "UIAspectRatioConstraint",
            },
            
            ss:New "UIStroke" {
                Name = "UIStroke",
                Color = Color3.fromRGB(214, 0, 4),
                StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                Thickness = 0.08,
            },
        }
    })
    
    return ss:New "Frame" {
        Name = "Slot_" .. slotIndex,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(0.334443, 0.889381),
        LayoutOrder = slotIndex,

        [Children] = {
            ss:New "ImageLabel" {
                Name = "Container",
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundTransparency = 1,
                Image = "rbxassetid://123413392379402",
                ImageColor3 = Color3.fromRGB(224, 224, 224),
                Position = UDim2.fromScale(0.5, 0.5),
                Rotation = containerRotation,
                ScaleType = Enum.ScaleType.Slice,
                Size = ss:Computed(function(use)
                    local scale = use(containerScale)
                    return UDim2.fromScale(1 * scale, 1 * scale)
                end),
                SliceCenter = Rect.new(512, 512, 512, 512),

                [Children] = containerChildren
            },
        }
    }
end

-- Generate slot items based on current data
local function GenerateSlots()
    local slotsData = peek(Functions.SlotsData)
    local maxSlots = peek(Functions.MaxSlots)
    local kilnLevel = peek(Functions.KilnLevel)
    
    -- Cleanup previous slots
    Functions:CleanupSlots()
    
    local slotItems = {}
    
    for slotIndex = 1, maxSlots do
        local slotScope = Fusion.scoped(Fusion)
        table.insert(Functions.SlotScopes, slotScope)
        
        local slotData = slotsData[tostring(slotIndex)]
        if slotData and slotData.styleKey then
            table.insert(slotItems, CreateSlotItem(slotScope, slotData, slotIndex, kilnLevel))
        else
            table.insert(slotItems, CreateEmptySlot(slotScope, slotIndex))
        end
    end
    
    return slotItems
end

-- Reactive slots that regenerate when data changes
local SlotsChildren = s:Computed(function(use)
    -- Subscribe to reactive state
    use(Functions.SlotsData)
    use(Functions.MaxSlots)
    use(Functions.KilnLevel)
    use(Functions.IsOpen)
    
    -- Only generate slots when open
    if not peek(Functions.IsOpen) then
        return {}
    end
    
    return GenerateSlots()
end)

-- Canvas size based on max slots
local CanvasWidth = s:Computed(function(use)
    local maxSlots = use(Functions.MaxSlots)
    return UDim2.fromOffset(math.max(1, maxSlots) * 217, 0)
end)

-- Build the UI
return s:New "Frame" {
    Name = "KilnUI",
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundTransparency = 1,
    Position = Functions.AnimatedPosition,
    Size = UDim2.fromScale(0.367379, 0.275),

    [Children] = {
        s:New "ImageLabel" {
            Name = "Background",
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            Image = "rbxassetid://123413392379402",
            Position = UDim2.fromScale(0.499291, 0.484848),
            ScaleType = Enum.ScaleType.Slice,
            Size = UDim2.fromScale(1, 0.973064),
            SliceCenter = Rect.new(512, 512, 512, 512),
            SliceScale = 0.2,
            ZIndex = -1,
        },

        s:New "CanvasGroup" {
            Name = "KilnCanvas",
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            Position = UDim2.fromScale(0.500709, 0.47138),
            Size = UDim2.fromScale(0.948936, 0.83165),

            [Children] = {
                s:New "ScrollingFrame" {
                    Name = "ScrollingFrame_Horizontal",
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundTransparency = 1,
                    CanvasSize = CanvasWidth,
                    ClipsDescendants = false,
                    Position = UDim2.fromScale(0.476831, 0.522267),
                    ScrollBarImageColor3 = Color3.fromRGB(183, 183, 183),
                    ScrollBarThickness = 20,
                    Selectable = false,
                    Size = UDim2.fromScale(0.898356, 0.95),
                    VerticalScrollBarPosition = Enum.VerticalScrollBarPosition.Left,
                    ScrollingDirection = Enum.ScrollingDirection.X,

                    [Children] = {
                        SlotsChildren,

                        s:New "UIGridLayout" {
                            Name = "UIGridLayout",
                            CellPadding = UDim2.fromOffset(16, 16),
                            CellSize = UDim2.fromOffset(201, 201),
                            SortOrder = Enum.SortOrder.LayoutOrder,
                            FillDirection = Enum.FillDirection.Horizontal,
                            HorizontalAlignment = Enum.HorizontalAlignment.Left,
                            VerticalAlignment = Enum.VerticalAlignment.Top,
                        },
                    }
                },

                s:New "UIGradient" {
                    Name = "UIGradient",
                    Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 1),
                        NumberSequenceKeypoint.new(0.00928074, 0),
                        NumberSequenceKeypoint.new(0.989559, 0),
                        NumberSequenceKeypoint.new(1, 1),
                    }),
                },
            }
        },

        ExitButton.new(s, {
            Position = UDim2.fromScale(0.97, 0.05),
            Size = UDim2.fromScale(0.099, 0.236),
            BaseRotation = -15,
            OnActivated = function()
                Functions:Close()
            end,
        }),
    }
}
