local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Assets = ReplicatedStorage:WaitForChild("Assets")
local GameObjects = Assets:WaitForChild("GameObjects")
local MinigameClayTemplate = GameObjects:WaitForChild("MinigameClay")

local Fusion = require(Shared.Fusion)
local Functions = require(script.Functions)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek

local LocalPlayer = Players.LocalPlayer

local COLORS = {
    background = Color3.fromRGB(248, 248, 248),
    wheelBase = Color3.fromRGB(240, 238, 235),
    wheelStroke = Color3.fromRGB(200, 200, 210),
    targetZone = Color3.fromRGB(230, 255, 235),
    targetStroke = Color3.fromRGB(52, 199, 89),
    spinLines = Color3.fromRGB(220, 215, 210),
    pulseRingBg = Color3.fromRGB(235, 235, 237),
    pulseRingFill = Color3.fromRGB(255, 149, 0),
    progressBg = Color3.fromRGB(226, 226, 226),
    progressFill = Color3.fromRGB(0, 224, 127),
    clayOutline = Color3.fromRGB(185, 144, 113),
    clayMain = Color3.fromRGB(231, 172, 126),
    statusCentered = Color3.fromRGB(0, 224, 127),
    statusOffCenter = Color3.fromRGB(255, 149, 0),
    wobbleArrow = Color3.fromRGB(255, 208, 0),
    wobbleArrowUrgent = Color3.fromRGB(255, 0, 0),
    levelActive = Color3.fromRGB(221, 221, 221),
    levelInactive = Color3.fromRGB(240, 240, 240),
    infoText = Color3.fromRGB(186, 186, 186),
}

local function Component()
    local s = Functions.scope
    
    local function handleInput(input, gameProcessed)
        if gameProcessed then return end
        if not peek(Functions.IsOpen) then return end
        
        local keyMap = {
            [Enum.KeyCode.W] = "up",
            [Enum.KeyCode.Up] = "up",
            [Enum.KeyCode.S] = "down",
            [Enum.KeyCode.Down] = "down",
            [Enum.KeyCode.A] = "left",
            [Enum.KeyCode.Left] = "left",
            [Enum.KeyCode.D] = "right",
            [Enum.KeyCode.Right] = "right",
        }
        
        local direction = keyMap[input.KeyCode]
        if direction then
            Functions:OnPush(direction)
        end
        
        if input.KeyCode == Enum.KeyCode.Escape then
            Functions:Exit()
        end
    end
    
    -- Watch for IsOpen changes and connect/disconnect input
    local inputConnection = nil
    s:Observer(Functions.IsOpen):onBind(function()
        local isOpen = peek(Functions.IsOpen)
        if isOpen then
            if inputConnection then inputConnection:Disconnect() end
            inputConnection = UserInputService.InputBegan:Connect(handleInput)
        else
            if inputConnection then
                inputConnection:Disconnect()
                inputConnection = nil
            end
        end
    end)
    
    -- Drift arrow color: grey → light red → red → black based on pulse progress (force intensity)
    -- Grey/light colors = weak pull, black = strongest pull
    local driftArrowColor = s:Computed(function(use)
        local progress = use(Functions.PulseProgress)
        local grey = Color3.fromRGB(180, 180, 180)
        local lightRed = Color3.fromRGB(255, 150, 150)
        local red = Color3.fromRGB(255, 50, 50)
        local black = Color3.fromRGB(30, 30, 30)
        
        if progress < 0.33 then
            -- Grey to light red (0 to 0.33)
            return grey:Lerp(lightRed, progress * 3)
        elseif progress < 0.66 then
            -- Light red to red (0.33 to 0.66)
            return lightRed:Lerp(red, (progress - 0.33) * 3)
        else
            -- Red to black (0.66 to 1)
            return red:Lerp(black, (progress - 0.66) * 3)
        end
    end)
    
    -- Wobble direction arrow color: flashes red/yellow, faster as countdown approaches
    local wobbleArrowColor = s:Computed(function(use)
        local progress = use(Functions.PulseProgress)
        local yellow = Color3.fromRGB(255, 208, 0)
        local red = Color3.fromRGB(255, 50, 50)
        
        -- Flash frequency increases as progress approaches 1
        -- At progress 0: slow flash (~1 Hz), at progress 1: fast flash (~8 Hz)
        local frequency = 1 + progress * 7
        local time = tick() * frequency
        local flash = (math.sin(time * math.pi * 2) + 1) / 2  -- 0 to 1 oscillation
        
        return yellow:Lerp(red, flash)
    end)
    
    -- Wobble direction arrow angle based on NextDriftDirection (radians, 0 = up, clockwise)
    local wobbleArrowAngle = s:Computed(function(use)
        local dir = use(Functions.NextDriftDirection)
        if dir == "up" then return 0
        elseif dir == "right" then return math.pi / 2
        elseif dir == "down" then return math.pi
        elseif dir == "left" then return -math.pi / 2
        end
        return math.pi / 2
    end)
    
    -- Spring the wobble arrow angle for smooth radial rotation
    local springWobbleArrowAngle = s:Spring(wobbleArrowAngle, 15, 0.7)
    
    -- Arrow angle based on current drift offset (shows where clay is drifting to)
    local arrowAngle = s:Computed(function(use)
        local offsetX = use(Functions.AnimatedOffsetX)
        local offsetY = use(Functions.AnimatedOffsetY)
        -- Calculate angle from offset (atan2 gives angle from center to drift position)
        -- Returns angle in radians where 0 = right, but we want 0 = up
        local angle = math.atan2(offsetX, -offsetY)
        return angle
    end)
    
    -- Compute the drift magnitude to control arrow visibility
    local driftMagnitude = s:Computed(function(use)
        local offsetX = use(Functions.AnimatedOffsetX)
        local offsetY = use(Functions.AnimatedOffsetY)
        return math.sqrt(offsetX * offsetX + offsetY * offsetY)
    end)
    
    -- Spring the angle for smooth radial rotation
    local springArrowAngle = s:Spring(arrowAngle, 15, 0.7)
    
    -- Create cameras for clay viewports (each viewport needs its own)
    local outerCamera = Instance.new("Camera")
    outerCamera.Name = "Camera"
    outerCamera.CFrame = CFrame.new(0, 15, 0) * CFrame.Angles(math.rad(-90), 0, 0) -- Position in front, looking at origin
    outerCamera.FieldOfView = 50
    
    local innerCamera = Instance.new("Camera")
    innerCamera.Name = "Camera"
    innerCamera.CFrame = CFrame.new(0, 15.2, 0) * CFrame.Angles(math.rad(-90), 0, 0) -- Position in front, looking at origin
    innerCamera.FieldOfView = 50
    
    -- Clone clay models (already has bones from ReplicatedStorage)
    local outerClayModel = MinigameClayTemplate:Clone()
    outerClayModel:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(90), 0, 0))
    
    local innerClayModel = MinigameClayTemplate:Clone()
    innerClayModel:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(90), 0, 0))
    
    -- Create level indicators
    local function createLevelIndicators()
        local indicators = {}
        for i = 1, 3 do
            table.insert(indicators, s:New "Frame" {
                Name = "Stage" .. i,
                BackgroundColor3 = s:Computed(function(use)
                    local stage = use(Functions.CurrentStage)
                    if i < stage then
                        -- Completed stage - bright green
                        return Color3.fromRGB(0, 200, 100)
                    elseif i == stage then
                        -- Current stage - pulsing/active color
                        return Color3.fromRGB(255, 200, 50)
                    else
                        -- Future stage - grey
                        return Color3.fromRGB(200, 200, 200)
                    end
                end),
                BackgroundTransparency = s:Computed(function(use)
                    local stage = use(Functions.CurrentStage)
                    return i == stage and 0 or 0.3
                end),
                Size = UDim2.fromScale(0.22, 0.8),
                LayoutOrder = i,
                [Children] = {
                    s:New "UICorner" { CornerRadius = UDim.new(0.3, 0) },
                    s:New "UIStroke" {
                        Color = s:Computed(function(use)
                            local stage = use(Functions.CurrentStage)
                            if i < stage then
                                return Color3.fromRGB(0, 150, 70)
                            elseif i == stage then
                                return Color3.fromRGB(200, 150, 30)
                            else
                                return Color3.fromRGB(150, 150, 150)
                            end
                        end),
                        Thickness = 1.5,
                    },
                    s:New "TextLabel" {
                        Name = "StageNumber",
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundTransparency = 1,
                        Position = UDim2.fromScale(0.5, 0.5),
                        Size = UDim2.fromScale(0.8, 0.8),
                        Text = tostring(i),
                        TextColor3 = s:Computed(function(use)
                            local stage = use(Functions.CurrentStage)
                            if i < stage then
                                return Color3.fromRGB(255, 255, 255)
                            elseif i == stage then
                                return Color3.fromRGB(80, 50, 0)
                            else
                                return Color3.fromRGB(120, 120, 120)
                            end
                        end),
                        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
                        TextScaled = true,
                    },
                    -- Checkmark for completed stages
                    s:New "TextLabel" {
                        Name = "Checkmark",
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundTransparency = 1,
                        Position = UDim2.fromScale(0.5, 0.5),
                        Size = UDim2.fromScale(0.7, 0.7),
                        Text = "✓",
                        TextColor3 = Color3.new(1, 1, 1),
                        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
                        TextScaled = true,
                        Visible = s:Computed(function(use)
                            local stage = use(Functions.CurrentStage)
                            return i < stage
                        end),
                    },
                }
            })
        end
        return indicators
    end
    
    return s:New "ScreenGui" {
        Name = "PotteryMinigame",
        Parent = LocalPlayer:WaitForChild("PlayerGui"),
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 10,
        Enabled = s:Computed(function(use)
            return use(Functions.IsOpen)
        end),
        
        [Children] = {
            s:New "Frame" {
                Name = "Container",
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundTransparency = 1,
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromScale(1, 1),
                
                [Children] = {
                    s:New "Frame" {
                        Name = "Container",
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundTransparency = 1,
                        Position = s:Spring(
                            s:Computed(function(use)
                                local isOpen = use(Functions.IsOpen)
                                return isOpen and UDim2.fromScale(0.5, 0.5) or UDim2.fromScale(0.5, 1.5)
                            end),
                            12, 0.6
                        ),
                        Size = UDim2.fromScale(0.353312, 0.683929),
                        ZIndex = 0,
                        
                        [Children] = {
                            -- Background
                            s:New "ImageLabel" {
                                Name = "Background",
                                AnchorPoint = Vector2.new(0.5, 0.5),
                                BackgroundTransparency = 1,
                                Image = "rbxassetid://123413392379402",
                                Position = UDim2.fromScale(0.5, 0.53799),
                                ScaleType = Enum.ScaleType.Slice,
                                Size = UDim2.fromScale(1, 1.07598),
                                SliceCenter = Rect.new(512, 512, 512, 512),
                                SliceScale = 0.3,
                                ZIndex = -1,
                            },
                            
                            -- Secondary Background
                            s:New "ImageLabel" {
                                Name = "SecondaryBackground",
                                AnchorPoint = Vector2.new(0.5, 0.5),
                                BackgroundTransparency = 1,
                                Image = "rbxassetid://123413392379402",
                                ImageColor3 = COLORS.background,
                                Position = UDim2.fromScale(0.498262, 0.44989),
                                ScaleType = Enum.ScaleType.Slice,
                                Size = UDim2.fromScale(0.86385, 0.570492),
                                SliceCenter = Rect.new(512, 512, 512, 512),
                                SliceScale = 0.2,
                                ZIndex = -1,
                            },
                            
                            -- Target Zone
                            s:New "Frame" {
                                Name = "TargetZone",
                                AnchorPoint = Vector2.new(0.5, 0.5),
                                BackgroundColor3 = s:Computed(function(use)
                                    return use(Functions.IsCentered) and COLORS.targetZone or Color3.fromRGB(255, 240, 230)
                                end),
                                Position = UDim2.fromScale(0.502666, 0.450581),
                                Size = UDim2.fromScale(0.06044, 0.0555586),
                                ZIndex = 4,
                                [Children] = {
                                    s:New "UICorner" { CornerRadius = UDim.new(0.5, 0) },
                                    s:New "UIStroke" {
                                        Color = s:Computed(function(use)
                                            return use(Functions.IsCentered) and COLORS.targetStroke or COLORS.pulseRingFill
                                        end),
                                        Thickness = 2,
                                    },
                                }
                            },
                            
                            -- Spin Lines
                            s:New "Frame" {
                                Name = "SpinLines",
                                AnchorPoint = Vector2.new(0.5, 0.5),
                                BackgroundTransparency = 1,
                                Position = UDim2.fromScale(0.502666, 0.450581),
                                Rotation = s:Computed(function(use)
                                    return math.deg(use(Functions.WheelAngle))
                                end),
                                Size = UDim2.fromScale(0.456985, 0.420078),
                                ZIndex = 3,
                                [Children] = {
                                    s:New "Frame" { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = COLORS.spinLines, BorderSizePixel = 0, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.85, 0.008) },
                                    s:New "Frame" { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = COLORS.spinLines, BorderSizePixel = 0, Position = UDim2.fromScale(0.5, 0.5), Rotation = 60, Size = UDim2.fromScale(0.85, 0.008) },
                                    s:New "Frame" { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = COLORS.spinLines, BorderSizePixel = 0, Position = UDim2.fromScale(0.5, 0.5), Rotation = 120, Size = UDim2.fromScale(0.85, 0.008) },
                                }
                            },
                            
                            -- Pulse Ring Fill (countdown ring that shrinks towards center)
                            s:New "Frame" {
                                Name = "PulseRingFill",
                                AnchorPoint = Vector2.new(0.5, 0.5),
                                BackgroundColor3 = s:Computed(function(use)
                                    local counterSuccess = use(Functions.CounterSuccess)
                                    local inWindow = use(Functions.InCounterWindow)
                                    
                                    -- Flash bright green on successful counter
                                    if counterSuccess then
                                        return Color3.fromRGB(50, 255, 120)
                                    end
                                    
                                    -- Green when in counter window, orange otherwise
                                    return inWindow and COLORS.statusCentered or COLORS.pulseRingFill
                                end),
                                BackgroundTransparency = s:Computed(function(use)
                                    local counterSuccess = use(Functions.CounterSuccess)
                                    local progress = use(Functions.PulseProgress)
                                    local counterFlash = use(Functions.AnimatedCounterSuccess)
                                    
                                    -- Very visible on counter success
                                    if counterSuccess or counterFlash > 0.1 then 
                                        return 0.2 - counterFlash * 0.2
                                    end
                                    if progress > 0.8 then return 0.4 end
                                    return 0.5
                                end),
                                Position = UDim2.fromScale(0.502666, 0.450581),
                                Size = s:Computed(function(use)
                                    local progress = use(Functions.PulseProgress)
                                    local counterFlash = use(Functions.AnimatedCounterSuccess)
                                    
                                    -- Start at full size and shrink to target zone size
                                    local maxSize = 0.452563
                                    local minSize = 0.06044
                                    local size = maxSize - (maxSize - minSize) * progress
                                    
                                    -- Scale pulse on successful counter (expands briefly)
                                    local scalePulse = 1 + counterFlash * 0.15
                                    size = size * scalePulse
                                    
                                    return UDim2.fromScale(size, size * 0.919)
                                end),
                                ZIndex = 3,
                                [Children] = { 
                                    s:New "UICorner" { CornerRadius = UDim.new(0.5, 0) },
                                    -- Pulsing stroke that intensifies near wobble
                                    s:New "UIStroke" {
                                        Color = s:Computed(function(use)
                                            local counterSuccess = use(Functions.CounterSuccess)
                                            local counterFlash = use(Functions.AnimatedCounterSuccess)
                                            if counterSuccess or counterFlash > 0.1 then 
                                                return Color3.fromRGB(50, 255, 120)
                                            end
                                            local progress = use(Functions.PulseProgress)
                                            return COLORS.pulseRingFill:Lerp(Color3.fromRGB(255, 50, 50), progress)
                                        end),
                                        Thickness = s:Computed(function(use)
                                            local progress = use(Functions.PulseProgress)
                                            local counterFlash = use(Functions.AnimatedCounterSuccess)
                                            -- Thicker on counter success, otherwise scales with progress
                                            return 2 + progress * 4 + counterFlash * 4
                                        end),
                                        Transparency = s:Computed(function(use)
                                            local counterSuccess = use(Functions.CounterSuccess)
                                            local counterFlash = use(Functions.AnimatedCounterSuccess)
                                            if counterSuccess or counterFlash > 0.1 then return 0 end
                                            local progress = use(Functions.PulseProgress)
                                            return 0.5 - progress * 0.4
                                        end),
                                    },
                                }
                            },
                            
                            -- Pulse Ring Background
                            s:New "Frame" {
                                Name = "PulseRingBg",
                                AnchorPoint = Vector2.new(0.5, 0.5),
                                BackgroundColor3 = COLORS.pulseRingBg,
                                Position = UDim2.fromScale(0.502666, 0.450581),
                                Size = UDim2.fromScale(0.536589, 0.493252),
                                ZIndex = 0,
                                [Children] = { s:New "UICorner" { CornerRadius = UDim.new(0.5, 0) } }
                            },
                            
                            -- Outer Clay ViewportFrame (outline layer)
                            s:New "ViewportFrame" {
                                Name = "ClayOutline",
                                AnchorPoint = Vector2.new(0.5, 0.5),
                                BackgroundTransparency = 1,
                                ImageColor3 = COLORS.clayOutline,
                                Position = s:Computed(function(use)
                                    local x = 0.502666 + use(Functions.AnimatedOffsetX) * 0.15
                                    local y = 0.450581 + use(Functions.AnimatedOffsetY) * 0.15
                                    return UDim2.fromScale(x, y)
                                end),
                                ImageTransparency = 0.15,
                                Size = UDim2.fromScale(0.4, 0.368),
                                ZIndex = 5,
                                CurrentCamera = outerCamera,
                                Ambient = Color3.fromRGB(200, 200, 200),
                                LightColor = Color3.fromRGB(255, 255, 255),
                                LightDirection = Vector3.new(0, -1, 0),
                                [Children] = {
                                    outerCamera,
                                    outerClayModel,
                                }
                            },
                            
                            -- Inner Clay ViewportFrame (main color) - on top
                            s:New "ViewportFrame" {
                                Name = "ClayMain",
                                AnchorPoint = Vector2.new(0.5, 0.5),
                                BackgroundTransparency = 1,
                                ImageColor3 = s:Computed(function(use)
                                    local centered = use(Functions.IsCentered)
                                    local flash = use(Functions.AnimatedPushFlash)
                                    local base = centered and COLORS.clayMain:Lerp(Color3.new(1,1,1), 0.1) or COLORS.clayMain
                                    return base:Lerp(Color3.new(1,1,1), flash * 0.3)
                                end),
                                Position = s:Computed(function(use)
                                    local x = 0.502666 + use(Functions.AnimatedOffsetX) * 0.15
                                    local y = 0.450581 + use(Functions.AnimatedOffsetY) * 0.15
                                    return UDim2.fromScale(x, y)
                                end),
                                ImageTransparency = 0.25,
                                Size = UDim2.fromScale(0.38, 0.35),
                                ZIndex = 6,
                                CurrentCamera = innerCamera,
                                Ambient = Color3.fromRGB(200, 200, 200),
                                LightColor = Color3.fromRGB(255, 255, 255),
                                LightDirection = Vector3.new(0, -1, 0),
                                [Children] = {
                                    innerCamera,
                                    innerClayModel,
                                }
                            },
                            
                            -- Drift Arrow (overlaid on clay, points towards current drift direction)
                            s:New "ImageLabel" {
                                Name = "DriftArrow",
                                AnchorPoint = Vector2.new(0.5, 0.5),
                                BackgroundTransparency = 1,
                                Image = "rbxassetid://104879640275901",
                                ImageColor3 = driftArrowColor,
                                ImageTransparency = s:Computed(function(use)
                                    -- Fade out when centered, visible when drifting
                                    local mag = use(driftMagnitude)
                                    return math.clamp(1 - mag * 3, 0, 1)
                                end),
                                Position = s:Computed(function(use)
                                    local angle = use(springArrowAngle)
                                    local offsetX = use(Functions.AnimatedOffsetX) * 0.15
                                    local offsetY = use(Functions.AnimatedOffsetY) * 0.15
                                    local centerX, centerY = 0.502666 + offsetX, 0.450581 + offsetY
                                    local radius = 0.12
                                    -- Calculate position using angle (0 = up, clockwise)
                                    local x = centerX + math.sin(angle) * radius
                                    local y = centerY - math.cos(angle) * radius
                                    return UDim2.fromScale(x, y)
                                end),
                                Rotation = s:Computed(function(use)
                                    return math.deg(use(springArrowAngle))
                                end),
                                Size = UDim2.fromScale(0.055, 0.05),
                                ZIndex = 10,
                                [Children] = { s:New "UIAspectRatioConstraint" {} }
                            },
                            
                            -- Wobble Direction Arrow (shows where next wobble will push)
                            s:New "ImageLabel" {
                                Name = "WobbleArrow",
                                AnchorPoint = Vector2.new(0.5, 0.5),
                                BackgroundTransparency = 1,
                                Image = "rbxassetid://104879640275901",
                                ImageColor3 = wobbleArrowColor,
                                Position = s:Computed(function(use)
                                    local angle = use(springWobbleArrowAngle)
                                    local centerX, centerY = 0.502666, 0.450581
                                    local radius = 0.25  -- Positioned at outer edge of wheel
                                    -- Calculate position using angle (0 = up, clockwise)
                                    local x = centerX + math.sin(angle) * radius
                                    local y = centerY - math.cos(angle) * radius * 0.919  -- Account for aspect ratio
                                    return UDim2.fromScale(x, y)
                                end),
                                Rotation = s:Computed(function(use)
                                    return math.deg(use(springWobbleArrowAngle))
                                end),
                                ScaleType = Enum.ScaleType.Fit,
                                Size = UDim2.fromScale(0.106139, 0.0975664),
                                ZIndex = 8,
                                [Children] = { s:New "UIAspectRatioConstraint" {} }
                            },
                            
                            -- Wheel Base
                            s:New "Frame" {
                                Name = "WheelBase",
                                AnchorPoint = Vector2.new(0.5, 0.5),
                                BackgroundColor3 = COLORS.wheelBase,
                                Position = UDim2.fromScale(0.502666, 0.450581),
                                Size = UDim2.fromScale(0.496787, 0.456665),
                                ZIndex = 2,
                                [Children] = {
                                    s:New "UICorner" { CornerRadius = UDim.new(0.5, 0) },
                                    s:New "UIStroke" { Color = COLORS.wheelStroke, Thickness = 2 },
                                }
                            },
                            
                            -- Progress Bar
                            s:New "ImageLabel" {
                                Name = "ProgressBackground",
                                AnchorPoint = Vector2.new(0.5, 0.5),
                                BackgroundTransparency = 1,
                                Image = "rbxassetid://123413392379402",
                                ImageColor3 = COLORS.progressBg,
                                Position = UDim2.fromScale(0.5, 0.121208),
                                ScaleType = Enum.ScaleType.Slice,
                                Size = UDim2.fromScale(0.825868, 0.0379588),
                                SliceCenter = Rect.new(512, 512, 512, 512),
                                SliceScale = 0.3,
                                ZIndex = 0,
                                [Children] = {
                                    s:New "ImageLabel" {
                                        Name = "Progress",
                                        AnchorPoint = Vector2.new(0.5, 0.5),
                                        BackgroundTransparency = 1,
                                        Image = "rbxassetid://123413392379402",
                                        ImageColor3 = COLORS.progressFill,
                                        Position = UDim2.fromScale(0.5, 0.5),
                                        ScaleType = Enum.ScaleType.Slice,
                                        Size = UDim2.fromScale(1, 1),
                                        SliceCenter = Rect.new(512, 512, 512, 512),
                                        SliceScale = 0.3,
                                        ZIndex = 0,
                                        [Children] = {
                                            s:New "UIGradient" {
                                                Transparency = s:Computed(function(use)
                                                    local progress = math.clamp(use(Functions.AnimatedProgress), 0, 1)
                                                    return NumberSequence.new({
                                                        NumberSequenceKeypoint.new(0, 0),
                                                        NumberSequenceKeypoint.new(math.max(0.001, progress), 0),
                                                        NumberSequenceKeypoint.new(math.max(0.002, progress + 0.001), 1),
                                                        NumberSequenceKeypoint.new(1, 1),
                                                    })
                                                end),
                                            },
                                        }
                                    },
                                }
                            },
                            
                            -- Status Text
                            s:New "TextLabel" {
                                Name = "Status",
                                BackgroundTransparency = 1,
                                FontFace = Font.new("rbxasset://fonts/families/HighwayGothic.json", Enum.FontWeight.Bold),
                                Position = UDim2.fromScale(0.0870661, 0.0438557),
                                Size = UDim2.fromScale(0.4, 0.0488877),
                                Text = s:Computed(function(use)
                                    local result = use(Functions.LastPushResult)
                                    if result == "perfect" then return "Perfect!"
                                    elseif result == "good" then return "Good!"
                                    elseif result == "miss" then return "Miss!"
                                    end
                                    return use(Functions.IsCentered) and "Centered!" or "Off-center..."
                                end),
                                TextColor3 = s:Computed(function(use)
                                    local result = use(Functions.LastPushResult)
                                    if result == "perfect" or result == "good" then return COLORS.statusCentered
                                    elseif result == "miss" then return COLORS.pulseRingFill
                                    end
                                    return use(Functions.IsCentered) and COLORS.statusCentered or COLORS.statusOffCenter
                                end),
                                TextScaled = true,
                                TextXAlignment = Enum.TextXAlignment.Left,
                            },
                            
                            -- Level Container
                            s:New "Frame" {
                                Name = "LevelContainer",
                                BackgroundTransparency = 1,
                                Position = UDim2.fromScale(0.514719, 0.0438557),
                                Size = UDim2.fromScale(0.398215, 0.0488877),
                                [Children] = {
                                    s:New "UIListLayout" {
                                        FillDirection = Enum.FillDirection.Horizontal,
                                        HorizontalAlignment = Enum.HorizontalAlignment.Right,
                                        Padding = UDim.new(0.05, 0),
                                        SortOrder = Enum.SortOrder.LayoutOrder,
                                        VerticalAlignment = Enum.VerticalAlignment.Center,
                                    },
                                    unpack(createLevelIndicators()),
                                }
                            },
                            
                            -- Controls
                            s:New "Frame" {
                                Name = "Controls",
                                AnchorPoint = Vector2.new(0.5, 0.5),
                                BackgroundColor3 = Color3.new(1, 1, 1),
                                BackgroundTransparency = 0.5,
                                BorderSizePixel = 0,
                                Position = UDim2.fromScale(0.499513, 0.896865),
                                Size = UDim2.fromScale(0.285984, 0.262887),
                                [Children] = {
                                    s:New "ImageLabel" {
                                        Name = "Background",
                                        AnchorPoint = Vector2.new(0.5, 0.5),
                                        BackgroundTransparency = 1,
                                        Image = "rbxassetid://123413392379402",
                                        ImageColor3 = COLORS.background,
                                        Position = UDim2.fromScale(0.5, 0.5),
                                        ScaleType = Enum.ScaleType.Slice,
                                        Size = UDim2.fromScale(3.02062, 1),
                                        SliceCenter = Rect.new(512, 512, 512, 512),
                                        SliceScale = 0.2,
                                        ZIndex = -1,
                                    },
                                    
                                    -- Info texts
                                    s:New "TextLabel" { Active = true, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, FontFace = Font.new("rbxasset://fonts/families/HighwayGothic.json", Enum.FontWeight.Bold), Position = UDim2.fromScale(-0.427191, 0.247423), Size = UDim2.fromScale(0.846649, 0.25), Text = "Keep the Clay in the middle!", TextColor3 = COLORS.infoText, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left },
                                    s:New "TextLabel" { Active = true, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, FontFace = Font.new("rbxasset://fonts/families/HighwayGothic.json", Enum.FontWeight.Bold), Position = UDim2.fromScale(-0.427191, 0.716495), Size = UDim2.fromScale(0.846649, 0.25), Text = "Use WASD to move the Clay!", TextColor3 = COLORS.infoText, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left },
                                    s:New "TextLabel" { Active = true, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, FontFace = Font.new("rbxasset://fonts/families/HighwayGothic.json", Enum.FontWeight.Bold), Position = UDim2.fromScale(1.42332, 0.247423), Size = UDim2.fromScale(0.846649, 0.25), Text = "Watch out for wobbles!", TextColor3 = COLORS.infoText, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Right },
                                    s:New "TextLabel" { Active = true, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, FontFace = Font.new("rbxasset://fonts/families/HighwayGothic.json", Enum.FontWeight.Bold), Position = UDim2.fromScale(1.42332, 0.716495), Size = UDim2.fromScale(0.846649, 0.25), Text = "Push the right way to counter it!", TextColor3 = COLORS.infoText, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Right },
                                    
                                    -- Direction buttons (Left)
                                    s:New "ImageButton" {
                                        Active = false, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1,
                                        Image = "rbxassetid://123413392379402", 
                                        ImageColor3 = s:Computed(function(use)
                                            local lastDir = use(Functions.LastPushedDirection)
                                            return lastDir == "left" and Color3.fromRGB(225, 103, 255) or Color3.fromRGB(229, 229, 229)
                                        end),
                                        Position = UDim2.fromScale(0.199248, 0.488737), ScaleType = Enum.ScaleType.Fit, Selectable = false,
                                        Size = UDim2.fromScale(0.257732, 0.257732),
                                        [Children] = {
                                            s:New "ImageLabel" { 
                                                Name = "DirectionArrow", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, 
                                                Image = "rbxassetid://104879640275901", 
                                                ImageColor3 = s:Computed(function(use)
                                                    local lastDir = use(Functions.LastPushedDirection)
                                                    return lastDir == "left" and Color3.new(1, 1, 1) or Color3.fromRGB(225, 103, 255)
                                                end),
                                                Position = UDim2.fromScale(0.5, 0.5), Rotation = -90, 
                                                Size = s:Spring(s:Computed(function(use)
                                                    local lastDir = use(Functions.LastPushedDirection)
                                                    return lastDir == "left" and UDim2.fromScale(1, 1) or UDim2.fromScale(0.8, 0.8)
                                                end), 25, 0.6),
                                                ZIndex = 8 
                                            },
                                            s:New "ImageLabel" { Name = "Stroke", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Image = "rbxassetid://129885483315946", ImageColor3 = Color3.fromRGB(209, 209, 209), Position = UDim2.fromScale(0.5, 0.5), ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromScale(1, 1) },
                                        }
                                    },
                                    -- Direction buttons (Right)
                                    s:New "ImageButton" {
                                        Active = false, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1,
                                        Image = "rbxassetid://123413392379402",
                                        ImageColor3 = s:Computed(function(use)
                                            local lastDir = use(Functions.LastPushedDirection)
                                            return lastDir == "right" and Color3.fromRGB(109, 165, 255) or Color3.fromRGB(229, 229, 229)
                                        end),
                                        Position = UDim2.fromScale(0.800752, 0.488737), ScaleType = Enum.ScaleType.Fit, Selectable = false,
                                        Size = UDim2.fromScale(0.257732, 0.257732),
                                        [Children] = {
                                            s:New "ImageLabel" { 
                                                Name = "DirectionArrow", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, 
                                                Image = "rbxassetid://104879640275901", 
                                                ImageColor3 = s:Computed(function(use)
                                                    local lastDir = use(Functions.LastPushedDirection)
                                                    return lastDir == "right" and Color3.new(1, 1, 1) or Color3.fromRGB(109, 165, 255)
                                                end),
                                                Position = UDim2.fromScale(0.5, 0.5), Rotation = 90,
                                                Size = s:Spring(s:Computed(function(use)
                                                    local lastDir = use(Functions.LastPushedDirection)
                                                    return lastDir == "right" and UDim2.fromScale(1, 1) or UDim2.fromScale(0.8, 0.8)
                                                end), 25, 0.6),
                                                ZIndex = 8 
                                            },
                                            s:New "ImageLabel" { Name = "Stroke", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Image = "rbxassetid://129885483315946", ImageColor3 = Color3.fromRGB(209, 209, 209), Position = UDim2.fromScale(0.5, 0.5), ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromScale(1, 1) },
                                        }
                                    },
                                    -- Direction buttons (Down)
                                    s:New "ImageButton" {
                                        Active = false, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1,
                                        Image = "rbxassetid://123413392379402",
                                        ImageColor3 = s:Computed(function(use)
                                            local lastDir = use(Functions.LastPushedDirection)
                                            return lastDir == "down" and Color3.fromRGB(255, 108, 110) or Color3.fromRGB(229, 229, 229)
                                        end),
                                        Position = UDim2.fromScale(0.5, 0.789489), ScaleType = Enum.ScaleType.Fit, Selectable = false,
                                        Size = UDim2.fromScale(0.257732, 0.257732),
                                        [Children] = {
                                            s:New "ImageLabel" { 
                                                Name = "DirectionArrow", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, 
                                                Image = "rbxassetid://104879640275901", 
                                                ImageColor3 = s:Computed(function(use)
                                                    local lastDir = use(Functions.LastPushedDirection)
                                                    return lastDir == "down" and Color3.new(1, 1, 1) or Color3.fromRGB(255, 108, 110)
                                                end),
                                                Position = UDim2.fromScale(0.5, 0.5), Rotation = 180,
                                                Size = s:Spring(s:Computed(function(use)
                                                    local lastDir = use(Functions.LastPushedDirection)
                                                    return lastDir == "down" and UDim2.fromScale(1, 1) or UDim2.fromScale(0.8, 0.8)
                                                end), 25, 0.6),
                                                ZIndex = 8 
                                            },
                                            s:New "ImageLabel" { Name = "Stroke", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Image = "rbxassetid://129885483315946", ImageColor3 = Color3.fromRGB(209, 209, 209), Position = UDim2.fromScale(0.5, 0.5), ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromScale(1, 1) },
                                        }
                                    },
                                    -- Direction buttons (Up)
                                    s:New "ImageButton" {
                                        Active = false, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1,
                                        Image = "rbxassetid://123413392379402",
                                        ImageColor3 = s:Computed(function(use)
                                            local lastDir = use(Functions.LastPushedDirection)
                                            return lastDir == "up" and Color3.fromRGB(90, 255, 139) or Color3.fromRGB(229, 229, 229)
                                        end),
                                        Position = UDim2.fromScale(0.5, 0.187986), ScaleType = Enum.ScaleType.Fit, Selectable = false,
                                        Size = UDim2.fromScale(0.257732, 0.257732),
                                        [Children] = {
                                            s:New "ImageLabel" { 
                                                Name = "DirectionArrow", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, 
                                                Image = "rbxassetid://104879640275901", 
                                                ImageColor3 = s:Computed(function(use)
                                                    local lastDir = use(Functions.LastPushedDirection)
                                                    return lastDir == "up" and Color3.new(1, 1, 1) or Color3.fromRGB(90, 255, 139)
                                                end),
                                                Position = UDim2.fromScale(0.5, 0.5),
                                                Size = s:Spring(s:Computed(function(use)
                                                    local lastDir = use(Functions.LastPushedDirection)
                                                    return lastDir == "up" and UDim2.fromScale(1, 1) or UDim2.fromScale(0.8, 0.8)
                                                end), 25, 0.6),
                                                ZIndex = 8 
                                            },
                                            s:New "ImageLabel" { Name = "Stroke", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Image = "rbxassetid://129885483315946", ImageColor3 = Color3.fromRGB(209, 209, 209), Position = UDim2.fromScale(0.5, 0.5), ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromScale(1, 1) },
                                        }
                                    },
                                }
                            },
                            
                            -- Exit Button
                            s:New "TextButton" {
                                Name = "Exit",
                                Active = true,
                                AnchorPoint = Vector2.new(0.5, 0.5),
                                BackgroundTransparency = 1,
                                FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
                                Position = UDim2.fromScale(0.967374, 0.0296391),
                                Rotation = -15,
                                Size = UDim2.fromScale(0.111607, 0.102593),
                                Text = "X",
                                TextColor3 = Color3.fromRGB(255, 0, 4),
                                TextScaled = true,
                                [OnEvent "Activated"] = function()
                                    Functions:Exit()
                                end,
                                [Children] = {
                                    s:New "UIAspectRatioConstraint" {},
                                    s:New "UIStroke" {
                                        Color = Color3.fromRGB(214, 0, 4),
                                        StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                                        Thickness = 0.08,
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
