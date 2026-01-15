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
    
    -- Counter direction arrow angle (OPPOSITE of wobble - this is what player should press)
    local counterArrowAngle = s:Computed(function(use)
        local dir = use(Functions.NextDriftDirection)
        -- Return the OPPOSITE direction
        if dir == "up" then return math.pi  -- Press down
        elseif dir == "right" then return -math.pi / 2  -- Press left
        elseif dir == "down" then return 0  -- Press up
        elseif dir == "left" then return math.pi / 2  -- Press right
        end
        return -math.pi / 2
    end)
    
    -- Spring the wobble arrow angle for smooth radial rotation
    local springWobbleArrowAngle = s:Spring(wobbleArrowAngle, 15, 0.7)
    
    -- Spring the counter arrow angle for smooth radial rotation
    local springCounterArrowAngle = s:Spring(counterArrowAngle, 15, 0.7)
    
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
    
    -- Create level indicators (simple colored circles)
    -- Colors for up to 10 levels (distinct hues)
    local stageColors = {
        [1] = {active = Color3.fromRGB(255, 100, 100), completed = Color3.fromRGB(200, 70, 70)},   -- Red
        [2] = {active = Color3.fromRGB(255, 170, 50), completed = Color3.fromRGB(200, 130, 30)},   -- Orange
        [3] = {active = Color3.fromRGB(255, 220, 50), completed = Color3.fromRGB(200, 170, 30)},   -- Yellow
        [4] = {active = Color3.fromRGB(150, 255, 80), completed = Color3.fromRGB(100, 200, 50)},   -- Lime
        [5] = {active = Color3.fromRGB(50, 230, 130), completed = Color3.fromRGB(30, 180, 100)},   -- Green
        [6] = {active = Color3.fromRGB(50, 220, 220), completed = Color3.fromRGB(30, 170, 170)},   -- Cyan
        [7] = {active = Color3.fromRGB(80, 180, 255), completed = Color3.fromRGB(50, 140, 200)},   -- Sky Blue
        [8] = {active = Color3.fromRGB(130, 130, 255), completed = Color3.fromRGB(100, 100, 200)}, -- Blue
        [9] = {active = Color3.fromRGB(200, 130, 255), completed = Color3.fromRGB(160, 100, 200)}, -- Purple
        [10] = {active = Color3.fromRGB(255, 130, 200), completed = Color3.fromRGB(200, 100, 160)}, -- Pink
    }
    
    -- Create a computed array of stage indices that updates when TotalStages changes
    local stageIndices = s:Computed(function(use)
        local total = use(Functions.TotalStages)
        local indices = {}
        for i = 1, total do
            table.insert(indices, i)
        end
        return indices
    end)
    
    -- Use ForValues to dynamically create level indicators
    local levelIndicators = s:ForValues(stageIndices, function(use, scope, i)
        local colorSet = stageColors[i] or stageColors[1] -- Fallback to red if more than 10 stages
        
        return scope:New "Frame" {
            Name = "Stage" .. i,
            BackgroundColor3 = scope:Computed(function(use)
                local stage = use(Functions.CurrentStage)
                if i < stage then
                    return colorSet.completed  -- Completed - darkened version
                elseif i == stage then
                    return colorSet.active  -- Current - bright version
                else
                    return Color3.fromRGB(200, 200, 200)  -- Future - grey
                end
            end),
            BackgroundTransparency = scope:Computed(function(use)
                local stage = use(Functions.CurrentStage)
                return i == stage and 0 or 0.3
            end),
            Size = UDim2.fromScale(0.15, 0.8),
            LayoutOrder = i,
            [Children] = {
                scope:New "UICorner" { CornerRadius = UDim.new(0.5, 0) },
                scope:New "UIAspectRatioConstraint" { AspectRatio = 1 },
                scope:New "UIStroke" {
                    Color = scope:Computed(function(use)
                        local stage = use(Functions.CurrentStage)
                        if i < stage then
                            return Color3.fromRGB(colorSet.completed.R * 0.7 * 255, colorSet.completed.G * 0.7 * 255, colorSet.completed.B * 0.7 * 255)
                        elseif i == stage then
                            return Color3.fromRGB(colorSet.active.R * 0.8 * 255, colorSet.active.G * 0.8 * 255, colorSet.active.B * 0.8 * 255)
                        else
                            return Color3.fromRGB(150, 150, 150)
                        end
                    end),
                    Thickness = 1.5,
                },
            }
        }
    end)
    
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
            -- Main container Frame that holds everything and handles position animation
            s:New "Frame" {
                Name = "RootContainer",
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundTransparency = 1,
                Position = s:Spring(
                    s:Computed(function(use)
                        local isOpen = use(Functions.IsOpen)
                        local isExiting = use(Functions.IsExiting)
                        -- Drop down when exiting, slide up when opening
                        if isExiting then
                            return UDim2.fromScale(0.5, 1.5)
                        end
                        return isOpen and UDim2.fromScale(0.5, 0.5) or UDim2.fromScale(0.5, 1.5)
                    end), 15, 0.7),
                Size = UDim2.fromScale(1, 1),
                
                [Children] = {
                    -- CanvasGroup for dimming the game UI
                    s:New "CanvasGroup" {
                        Name = "GameCanvasGroup",
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundTransparency = 1,
                        GroupColor3 = s:Spring(s:Computed(function(use)
                            local showCountdown = use(Functions.ShowCountdown)
                            local showSuccess = use(Functions.ShowSuccess)
                            if showCountdown or showSuccess then
                                return Color3.fromRGB(80, 80, 80)  -- Dimmed
                            end
                            return Color3.new(1, 1, 1)  -- Normal
                        end), 12, 0.7),
                        Position = UDim2.fromScale(0.5, 0.5),
                        Size = UDim2.fromScale(1, 1),
                        
                        [Children] = {
                            s:New "Frame" {
                                Name = "MainContainer",
                                AnchorPoint = Vector2.new(0.5, 0.5),
                                BackgroundTransparency = 1,
                                Position = UDim2.fromScale(0.5, 0.5),
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
                            
                            -- Counter Feedback Ring (red glow behind wheel for impact feedback)
                            s:New "Frame" {
                                Name = "CounterFeedbackRing",
                                AnchorPoint = Vector2.new(0.5, 0.5),
                                BackgroundColor3 = s:Computed(function(use)
                                    local counterFlash = use(Functions.AnimatedCounterSuccess)
                                    local pulseProgress = use(Functions.PulseProgress)
                                    
                                    -- Flash bright green on successful counter
                                    if counterFlash > 0.1 then
                                        return Color3.fromRGB(50, 255, 100):Lerp(Color3.fromRGB(255, 255, 255), counterFlash * 0.5)
                                    end
                                    
                                    -- Pulse red color intensity based on pulse progress (urgency)
                                    local baseRed = Color3.fromRGB(255, 80, 80)
                                    local urgentRed = Color3.fromRGB(255, 30, 30)
                                    return baseRed:Lerp(urgentRed, pulseProgress)
                                end),
                                BackgroundTransparency = s:Spring(s:Computed(function(use)
                                    local counterFlash = use(Functions.AnimatedCounterSuccess)
                                    local pulseProgress = use(Functions.PulseProgress)
                                    local inWindow = use(Functions.InCounterWindow)
                                    
                                    -- Very visible on counter success
                                    if counterFlash > 0.1 then
                                        return 0.3 - counterFlash * 0.3  -- Goes to 0 (fully visible) on success
                                    end
                                    
                                    -- More visible during counter window and as pulse approaches
                                    if inWindow then
                                        return 0.5
                                    end
                                    
                                    -- Fade in as pulse approaches, fully invisible when not urgent
                                    return 1 - (pulseProgress * 0.4)  -- Goes from 1 to 0.6 as progress increases
                                end), 15, 0.6),
                                Position = UDim2.fromScale(0.502666, 0.450581),
                                Size = s:Spring(s:Computed(function(use)
                                    local counterFlash = use(Functions.AnimatedCounterSuccess)
                                    local baseSize = 0.58
                                    
                                    -- Expand on successful counter
                                    local scale = 1 + counterFlash * 0.25
                                    local size = baseSize * scale
                                    
                                    return UDim2.fromScale(size, size * 0.919)
                                end), 20, 0.5),
                                ZIndex = 1,  -- Behind wheel base (ZIndex 2) but above pulse ring bg (ZIndex 0)
                                [Children] = { 
                                    s:New "UICorner" { CornerRadius = UDim.new(0.5, 0) },
                                    s:New "UIStroke" {
                                        Color = s:Computed(function(use)
                                            local counterFlash = use(Functions.AnimatedCounterSuccess)
                                            if counterFlash > 0.1 then
                                                return Color3.fromRGB(100, 255, 150)
                                            end
                                            return Color3.fromRGB(255, 50, 50)
                                        end),
                                        Thickness = s:Computed(function(use)
                                            local counterFlash = use(Functions.AnimatedCounterSuccess)
                                            local pulseProgress = use(Functions.PulseProgress)
                                            -- Base thickness grows with pulse progress, extra on counter
                                            return 2 + pulseProgress * 3 + counterFlash * 6
                                        end),
                                        Transparency = s:Computed(function(use)
                                            local counterFlash = use(Functions.AnimatedCounterSuccess)
                                            local pulseProgress = use(Functions.PulseProgress)
                                            if counterFlash > 0.1 then return 0 end
                                            return 0.7 - pulseProgress * 0.5
                                        end),
                                    }
                                }
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
                            
                            -- Wobble Direction Arrow (shows where next wobble will push - warning indicator)
                            s:New "ImageLabel" {
                                Name = "WobbleArrow",
                                AnchorPoint = Vector2.new(0.5, 0.5),
                                BackgroundTransparency = 1,
                                Image = "rbxassetid://104879640275901",
                                ImageColor3 = wobbleArrowColor,
                                ImageTransparency = 0.4,  -- More transparent since it's just a warning
                                Position = s:Computed(function(use)
                                    local angle = use(springWobbleArrowAngle)
                                    local centerX, centerY = 0.502666, 0.450581
                                    local radius = 0.28  -- Positioned at outer edge of wheel
                                    -- Calculate position using angle (0 = up, clockwise)
                                    local x = centerX + math.sin(angle) * radius
                                    local y = centerY - math.cos(angle) * radius * 0.919  -- Account for aspect ratio
                                    return UDim2.fromScale(x, y)
                                end),
                                Rotation = s:Computed(function(use)
                                    return math.deg(use(springWobbleArrowAngle))
                                end),
                                ScaleType = Enum.ScaleType.Fit,
                                Size = UDim2.fromScale(0.07, 0.065),  -- Smaller size
                                Visible = s:Computed(function(use)
                                    return use(Functions.HasPulses)
                                end),
                                ZIndex = 7,
                                [Children] = { s:New "UIAspectRatioConstraint" {} }
                            },
                            
                            -- Counter Direction Arrow (shows which way player should press - main indicator)
                            s:New "ImageLabel" {
                                Name = "CounterArrow",
                                AnchorPoint = Vector2.new(0.5, 0.5),
                                BackgroundTransparency = 1,
                                Image = "rbxassetid://104879640275901",
                                ImageColor3 = s:Computed(function(use)
                                    local progress = use(Functions.PulseProgress)
                                    local inWindow = use(Functions.InCounterWindow)
                                    local counterSuccess = use(Functions.CounterSuccess)
                                    
                                    -- Bright green on successful counter
                                    if counterSuccess then
                                        return Color3.fromRGB(100, 255, 150)
                                    end
                                    
                                    -- Bright green in counter window
                                    if inWindow then
                                        return Color3.fromRGB(50, 255, 100)
                                    end
                                    
                                    -- Cyan/blue color that intensifies as wobble approaches
                                    local base = Color3.fromRGB(100, 200, 255)
                                    local bright = Color3.fromRGB(50, 255, 200)
                                    return base:Lerp(bright, progress)
                                end),
                                Position = s:Computed(function(use)
                                    local angle = use(springCounterArrowAngle)
                                    local centerX, centerY = 0.502666, 0.450581
                                    local radius = 0.25  -- Positioned at outer edge of wheel
                                    -- Calculate position using angle (0 = up, clockwise)
                                    local x = centerX + math.sin(angle) * radius
                                    local y = centerY - math.cos(angle) * radius * 0.919  -- Account for aspect ratio
                                    return UDim2.fromScale(x, y)
                                end),
                                Rotation = s:Computed(function(use)
                                    return math.deg(use(springCounterArrowAngle))
                                end),
                                ScaleType = Enum.ScaleType.Fit,
                                Size = s:Spring(s:Computed(function(use)
                                    local progress = use(Functions.PulseProgress)
                                    local inWindow = use(Functions.InCounterWindow)
                                    local counterSuccess = use(Functions.CounterSuccess)
                                    
                                    -- Pulse bigger on success
                                    if counterSuccess then
                                        return UDim2.fromScale(0.14, 0.13)
                                    end
                                    
                                    -- Bigger during counter window
                                    if inWindow then
                                        return UDim2.fromScale(0.13, 0.12)
                                    end
                                    
                                    -- Grow as pulse approaches
                                    local baseSize = 0.09 + progress * 0.03
                                    return UDim2.fromScale(baseSize, baseSize * 0.92)
                                end), 20, 0.6),
                                Visible = s:Computed(function(use)
                                    return use(Functions.HasPulses)
                                end),
                                ZIndex = 9,
                                [Children] = { 
                                    s:New "UIAspectRatioConstraint" {},
                                }
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
                                                    -- Calculate progress for current stage section only
                                                    local stage = use(Functions.CurrentStage)
                                                    local totalStages = use(Functions.TotalStages)
                                                    local stability = use(Functions.AnimatedStability)
                                                    
                                                    -- Get the config for current stage
                                                    local config = Functions:GetStageConfig(stage)
                                                    local stageProgress = stability / config.stabilityRequired
                                                    
                                                    -- Calculate the section boundaries for this stage
                                                    local sectionStart = (stage - 1) / totalStages
                                                    local sectionEnd = stage / totalStages
                                                    local sectionWidth = sectionEnd - sectionStart
                                                    
                                                    -- Fill from sectionStart to current position within section
                                                    local fillEnd = sectionStart + (sectionWidth * math.clamp(stageProgress, 0, 1))
                                                    
                                                    -- Clamp fillEnd to ensure keypoints are always in proper order
                                                    -- Must have: 0 < fillEnd < fillEnd+0.001 < 1
                                                    fillEnd = math.clamp(fillEnd, 0.001, 0.997)
                                                    
                                                    -- Add completed stages (fully filled)
                                                    -- The bar shows: completed stages as solid + current stage progress
                                                    return NumberSequence.new({
                                                        NumberSequenceKeypoint.new(0, 0),  -- Start filled
                                                        NumberSequenceKeypoint.new(fillEnd, 0),  -- Filled to current progress
                                                        NumberSequenceKeypoint.new(fillEnd + 0.002, 1),  -- Sharp cutoff
                                                        NumberSequenceKeypoint.new(1, 1),  -- Rest unfilled
                                                    })
                                                end),
                                            },
                                        }
                                    },
                                }
                            },
                            
                            -- Status Text (normal status, no countdown)
                            s:New "TextLabel" {
                                Name = "Status",
                                BackgroundTransparency = 1,
                                FontFace = Font.new("rbxasset://fonts/families/HighwayGothic.json", Enum.FontWeight.Bold),
                                Position = UDim2.fromScale(0.0870661, 0.0438557),
                                Size = UDim2.fromScale(0.4, 0.0488877),
                                Text = s:Computed(function(use)
                                    -- Use priority-based status text
                                    local statusText = use(Functions.StatusText)
                                    if statusText ~= "" then
                                        return statusText
                                    end
                                    -- Fallback to centered state
                                    return use(Functions.IsCentered) and "Centered!" or "Off-center..."
                                end),
                                TextColor3 = s:Computed(function(use)
                                    local statusText = use(Functions.StatusText)
                                    if statusText == "Perfect!" then return Color3.fromRGB(50, 255, 120)
                                    elseif statusText == "Good!" then return COLORS.statusCentered
                                    elseif statusText == "Miss!" then return Color3.fromRGB(255, 100, 100)
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
                                    levelIndicators,
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
                                        Active = true, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1,
                                        Image = "rbxassetid://123413392379402", 
                                        ImageColor3 = s:Computed(function(use)
                                            local lastDir = use(Functions.LastPushedDirection)
                                            return lastDir == "left" and Color3.fromRGB(225, 103, 255) or Color3.fromRGB(229, 229, 229)
                                        end),
                                        Position = UDim2.fromScale(0.199248, 0.488737), ScaleType = Enum.ScaleType.Fit, Selectable = false,
                                        Size = UDim2.fromScale(0.257732, 0.257732),
                                        [OnEvent "Activated"] = function()
                                            Functions:OnPush("left")
                                        end,
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
                                        Active = true, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1,
                                        Image = "rbxassetid://123413392379402",
                                        ImageColor3 = s:Computed(function(use)
                                            local lastDir = use(Functions.LastPushedDirection)
                                            return lastDir == "right" and Color3.fromRGB(109, 165, 255) or Color3.fromRGB(229, 229, 229)
                                        end),
                                        Position = UDim2.fromScale(0.800752, 0.488737), ScaleType = Enum.ScaleType.Fit, Selectable = false,
                                        Size = UDim2.fromScale(0.257732, 0.257732),
                                        [OnEvent "Activated"] = function()
                                            Functions:OnPush("right")
                                        end,
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
                                        Active = true, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1,
                                        Image = "rbxassetid://123413392379402",
                                        ImageColor3 = s:Computed(function(use)
                                            local lastDir = use(Functions.LastPushedDirection)
                                            return lastDir == "down" and Color3.fromRGB(255, 108, 110) or Color3.fromRGB(229, 229, 229)
                                        end),
                                        Position = UDim2.fromScale(0.5, 0.789489), ScaleType = Enum.ScaleType.Fit, Selectable = false,
                                        Size = UDim2.fromScale(0.257732, 0.257732),
                                        [OnEvent "Activated"] = function()
                                            Functions:OnPush("down")
                                        end,
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
                                        Active = true, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1,
                                        Image = "rbxassetid://123413392379402",
                                        ImageColor3 = s:Computed(function(use)
                                            local lastDir = use(Functions.LastPushedDirection)
                                            return lastDir == "up" and Color3.fromRGB(90, 255, 139) or Color3.fromRGB(229, 229, 229)
                                        end),
                                        Position = UDim2.fromScale(0.5, 0.187986), ScaleType = Enum.ScaleType.Fit, Selectable = false,
                                        Size = UDim2.fromScale(0.257732, 0.257732),
                                        [OnEvent "Activated"] = function()
                                            Functions:OnPush("up")
                                        end,
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
                            
                            -- Exit Button with hover and click animations
                            (function()
                                local isHovered = s:Value(false)
                                local isPressed = s:Value(false)
                                
                                local buttonScale = s:Spring(
                                    s:Computed(function(use)
                                        if use(isPressed) then return 0.85 end
                                        if use(isHovered) then return 1.15 end
                                        return 1
                                    end),
                                    20, 0.6
                                )
                                
                                local buttonRotation = s:Spring(
                                    s:Computed(function(use)
                                        local baseRotation = -15
                                        if use(isPressed) then return baseRotation - 5 end
                                        if use(isHovered) then return baseRotation + 10 end
                                        return baseRotation
                                    end),
                                    15, 0.5
                                )
                                
                                return s:New "TextButton" {
                                    Name = "Exit",
                                    Active = true,
                                    AnchorPoint = Vector2.new(0.5, 0.5),
                                    BackgroundTransparency = 1,
                                    FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
                                    Position = UDim2.fromScale(0.967374, 0.0296391),
                                    Rotation = buttonRotation,
                                    Size = s:Computed(function(use)
                                        local scale = use(buttonScale)
                                        return UDim2.fromScale(0.111607 * scale, 0.102593 * scale)
                                    end),
                                    Text = "X",
                                    TextColor3 = s:Spring(s:Computed(function(use)
                                        if use(isPressed) then return Color3.fromRGB(180, 0, 3) end
                                        if use(isHovered) then return Color3.fromRGB(255, 50, 50) end
                                        return Color3.fromRGB(255, 0, 4)
                                    end), 15, 0.7),
                                    TextScaled = true,
                                    
                                    [OnEvent "Activated"] = function()
                                        Functions:Exit()
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
                                        s:New "UIAspectRatioConstraint" {},
                                        s:New "UIStroke" {
                                            Color = s:Spring(s:Computed(function(use)
                                                if use(isPressed) then return Color3.fromRGB(150, 0, 3) end
                                                if use(isHovered) then return Color3.fromRGB(255, 50, 50) end
                                                return Color3.fromRGB(214, 0, 4)
                                            end), 15, 0.7),
                                            StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                                            Thickness = 0.08,
                                        },
                                    }
                                }
                            end)(),
                        }
                    },
                }
            },  -- End of CanvasGroup
                    
                    -- Centered Countdown Text (outside CanvasGroup so it doesn't get dimmed)
                    s:New "TextLabel" {
                        Name = "CountdownText",
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundTransparency = 1,
                        FontFace = Font.new("rbxasset://fonts/families/HighwayGothic.json", Enum.FontWeight.Bold),
                        Position = UDim2.fromScale(0.5, 0.467),
                        Size = s:Spring(s:Computed(function(use)
                            local showCountdown = use(Functions.ShowCountdown)
                            if showCountdown then
                                local num = use(Functions.CountdownNumber)
                                -- Size increases as countdown progresses (3->2->1) with bigger pulse
                                local baseSize = 0.15 + (4 - num) * 0.05
                                return UDim2.fromScale(baseSize, baseSize)
                            end
                            return UDim2.fromScale(0, 0)
                        end), 30, 0.4),
                        Text = s:Computed(function(use)
                            local num = use(Functions.CountdownNumber)
                            return tostring(num)
                        end),
                        TextColor3 = s:Computed(function(use)
                            local num = use(Functions.CountdownNumber)
                            if num == 3 then return Color3.fromRGB(255, 220, 100)
                            elseif num == 2 then return Color3.fromRGB(255, 180, 50)
                            else return Color3.fromRGB(255, 100, 50)
                            end
                        end),
                        TextScaled = true,
                        TextTransparency = s:Spring(s:Computed(function(use)
                            return use(Functions.ShowCountdown) and 0 or 1
                        end), 20, 0.6),
                        Visible = s:Computed(function(use)
                            return use(Functions.ShowCountdown)
                        end),
                        ZIndex = 100,
                        [Children] = {
                            s:New "UIAspectRatioConstraint" { AspectRatio = 1 },
                            s:New "UIStroke" {
                                Color = Color3.fromRGB(180, 100, 0),
                                Thickness = 3,
                                Transparency = 0.2,
                            },
                        },
                    },
                    
                    -- Success Text (outside CanvasGroup so it doesn't get dimmed)
                    s:New "TextLabel" {
                        Name = "SuccessText",
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundTransparency = 1,
                        FontFace = Font.new("rbxasset://fonts/families/HighwayGothic.json", Enum.FontWeight.Bold),
                        Position = UDim2.fromScale(0.5, 0.467),
                        Size = s:Spring(s:Computed(function(use)
                            local showSuccess = use(Functions.ShowSuccess)
                            return showSuccess and UDim2.fromScale(0.15, 0.06) or UDim2.fromScale(0, 0)
                        end), 20, 0.5),
                        Rotation = s:Spring(s:Computed(function(use)
                            return use(Functions.ShowSuccess) and 0 or -15
                        end), 15, 0.6),
                        Text = "Complete!",
                        TextColor3 = Color3.fromRGB(50, 255, 120),
                        TextScaled = true,
                        TextTransparency = s:Spring(s:Computed(function(use)
                            return use(Functions.ShowSuccess) and 0 or 1
                        end), 15, 0.6),
                        Visible = s:Computed(function(use)
                            return use(Functions.ShowSuccess)
                        end),
                        ZIndex = 100,
                        [Children] = {
                            s:New "UIStroke" {
                                Color = Color3.fromRGB(0, 150, 70),
                                Thickness = 3,
                                Transparency = 0.2,
                            },
                        },
                    },
                }  -- End of RootContainer Children
            },  -- End of RootContainer
        }
    }
end

return Component()
