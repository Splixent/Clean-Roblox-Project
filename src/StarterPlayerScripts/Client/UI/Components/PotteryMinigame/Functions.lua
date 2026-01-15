local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared

local Fusion = require(Shared.Fusion)

local peek = Fusion.peek
local LocalPlayer = Players.LocalPlayer

local Functions = {}

-- Create scope for reactive state
Functions.scope = Fusion.scoped(Fusion)
local scope = Functions.scope

-- Reactive state
Functions.IsOpen = scope:Value(false)

--[[
    ============================================================================
    BALANCE THE CLAY - Pottery Minigame
    ============================================================================
    
    A rhythm-based balancing minigame where you keep clay centered on a 
    spinning pottery wheel. The clay drifts off-center in pulses, and you
    must push it back using directional inputs.
    
    CONTROLS:
    - Keyboard: WASD or Arrow Keys
    - Gamepad: D-Pad or Left Thumbstick
    - Mobile: Tap directional buttons
    
    GAMEPLAY:
    1. Clay pulses in a direction at regular intervals
    2. Counter the pulse by pushing OPPOSITE to the drift
    3. Keep clay centered long enough to complete each stage
    4. Each stage can have different difficulty settings
    
    ============================================================================
    CONFIG STRUCTURE - STAGE-CENTERED DESIGN
    ============================================================================
    
    Each stage defines ALL its own settings directly. No multipliers or
    abstract difficulty levels - you set exactly what you want per stage.
    
    Functions:Open({
        -- CALLBACKS
        onExit = function() end,      -- Called when player exits (X button or escape)
        onComplete = function() end,  -- Called when all stages completed successfully
        
        -- STAGES ARRAY - Each entry is one stage with ALL its settings
        stages = {
            [1] = {
                --== GOAL ==--
                -- How long the player must keep clay centered to complete this stage
                stabilityRequired = 3.0,  -- Seconds of being centered needed
                
                --== PHYSICS ==--
                -- Controls how the clay moves and responds
                driftStrength = 0.5,   -- How hard pulses push the clay (0.1 = gentle, 1.0 = strong)
                friction = 3.0,        -- How quickly clay slows down (1.0 = slippery, 5.0 = sticky)
                pushStrength = 0.6,    -- How much your input pushes clay (0.3 = weak, 1.0 = strong)
                maxOffset = 0.85,      -- Max distance clay can go from center (0.5 = small area, 1.0 = full)
                
                --== CENTER ZONE ==--
                -- Defines what counts as "centered"
                threshold = 0.3,       -- Radius of center zone (0.15 = tiny, 0.4 = forgiving)
                
                --== VISUAL ==--
                wheelSpeed = 1.5,      -- How fast the wheel spins visually (aesthetic only)
                
                --== TIMING ==--
                -- Counter window is when you can perfectly negate a pulse
                counterWindowStart = 0.3,  -- Window opens this many seconds BEFORE pulse
                counterWindowEnd = 0.15,   -- Window stays open this many seconds AFTER pulse
                
                --== PULSE RHYTHM ==--
                -- Pulses are the periodic pushes that knock clay off-center
                -- The game randomly picks from this list for variety
                pulses = {
                    { interval = 2.5, strength = 0.6 },  -- Slow pulse, medium strength
                    { interval = 2.0, strength = 0.5 },  -- Medium pulse
                },
            },
            
            [2] = {
                -- Stage 2 is harder: faster pulses, smaller center zone
                stabilityRequired = 3.5,
                driftStrength = 0.7,
                friction = 2.5,
                pushStrength = 0.6,
                maxOffset = 0.85,
                threshold = 0.25,
                wheelSpeed = 2.5,
                counterWindowStart = 0.25,
                counterWindowEnd = 0.12,
                pulses = {
                    { interval = 2.0, strength = 0.7 },
                    { interval = 1.5, strength = 0.6 },
                },
            },
            
            -- Add as many stages as you want...
        },
    })
    
    ============================================================================
    SETTING EXPLANATIONS
    ============================================================================
    
    GOAL SETTINGS:
    ├─ stabilityRequired: Seconds player must stay centered to complete stage
    │   Low (1-2s) = Quick/easy, High (5-10s) = Long/challenging
    
    PHYSICS SETTINGS:
    ├─ driftStrength: Multiplier for how hard pulses push the clay
    │   This scales the pulse strength values. 0.5 = half power, 2.0 = double
    │
    ├─ friction: How quickly the clay loses velocity (drag/resistance)
    │   Low (1.0) = Clay slides around, slippery feel
    │   High (4.0) = Clay stops quickly, responsive feel
    │
    ├─ pushStrength: How much velocity your directional input adds
    │   Low (0.3) = Gentle nudges, requires multiple taps
    │   High (1.0) = Strong pushes, can overcorrect easily
    │
    └─ maxOffset: Maximum distance clay can travel from center (0-1 scale)
        Low (0.5) = Clay stays near middle, feels cramped
        High (1.0) = Clay can go to edge, more dramatic movement
    
    CENTER ZONE:
    └─ threshold: Radius of the "centered" zone where stability builds
        Low (0.15) = Tiny target, very precise
        High (0.35) = Large target, forgiving
    
    VISUAL:
    └─ wheelSpeed: Rotation speed of the pottery wheel (radians/sec)
        Purely cosmetic, doesn't affect gameplay
    
    TIMING SETTINGS:
    ├─ counterWindowStart: Seconds BEFORE pulse when counter window opens
    │   This is when "NOW!" appears and perfect counters are possible
    │   Higher = More time to react, easier
    │
    └─ counterWindowEnd: Seconds AFTER pulse the window stays open
        Gives a small grace period if you're slightly late
    
    DEPLETION SETTINGS:
    └─ depletionRate: How fast progress depletes when not centered (default: 0.5)
        0 = No depletion, progress only pauses when off-center
        0.5 = Slow depletion (default)
        1.0+ = Fast depletion, punishing
    
    PULSE SETTINGS (per stage):
    └─ pulses: Array of possible pulse patterns for variety
        ├─ interval: Seconds between pulses (time to prepare)
        │   Low (1.0) = Rapid fire, intense
        │   High (3.0) = Slow, relaxed
        │
        └─ strength: Force of this specific pulse type (0-1)
            Combined with driftStrength for final push power
            Low (0.3) = Gentle nudge
            High (1.0) = Strong shove
    
    ============================================================================
]]

-- Core physics state
Functions.ClayOffsetX = scope:Value(0)
Functions.ClayOffsetY = scope:Value(0)
Functions.VelocityX = scope:Value(0)
Functions.VelocityY = scope:Value(0)
Functions.WheelAngle = scope:Value(0)

-- Stage system
Functions.CurrentStage = scope:Value(1)
Functions.StabilityProgress = scope:Value(0)
Functions.TotalStages = scope:Value(3)  -- Reactive Value for dynamic level indicators

-- Game state
Functions.Progress = scope:Value(0)
Functions.GameState = scope:Value("waiting")
Functions.IsCentered = scope:Value(false)

-- Visual feedback
Functions.PushDirection = scope:Value("none")
Functions.PushFlash = scope:Value(0)
Functions.ShakeIntensity = scope:Value(0)
Functions.StageText = scope:Value("")

-- Pulse system state
Functions.PulseProgress = scope:Value(0)
Functions.PulseInterval = scope:Value(2.0)
Functions.NextDriftX = scope:Value(0)
Functions.NextDriftY = scope:Value(0)
Functions.NextDriftDirection = scope:Value("right")
Functions.InCounterWindow = scope:Value(false)
Functions.LastPushResult = scope:Value("")
Functions.PerfectCounter = scope:Value(0)
Functions.PulseFlash = scope:Value(0)
Functions.BeatCount = scope:Value(3)
Functions.CounterWindowFlash = scope:Value(0)
Functions.PulseNegated = scope:Value(false)
Functions.LastPushedDirection = scope:Value("none")  -- Tracks last pressed direction for UI flash
Functions.CounterSuccess = scope:Value(false)  -- True when a successful counter happens
Functions.CounterFlash = scope:Value(0)  -- 0-1 flash intensity for counter success visual
Functions.HasPulses = scope:Value(true)  -- True when current stage has pulses enabled

-- Status text priority system (higher priority = stays visible longer)
Functions.StatusText = scope:Value("")  -- Current status text
Functions.StatusPriority = scope:Value(0)  -- Current status priority (0 = lowest)
Functions.StatusExpireTime = scope:Value(0)  -- When current status expires

-- Success/completion state
Functions.ShowSuccess = scope:Value(false)  -- True when showing success screen
Functions.IsExiting = scope:Value(false)  -- True when animating out

-- Countdown state
Functions.ShowCountdown = scope:Value(false)  -- True when showing countdown
Functions.CountdownNumber = scope:Value(3)  -- Current countdown number (3, 2, 1)

-- Animation springs
Functions.AnimatedPulseProgress = scope:Spring(Functions.PulseProgress, 8, 0.8)
Functions.AnimatedPulseFlash = scope:Spring(Functions.PulseFlash, 30, 0.4)
Functions.AnimatedCounterFlash = scope:Spring(Functions.CounterWindowFlash, 25, 0.5)
Functions.AnimatedCounterSuccess = scope:Spring(Functions.CounterFlash, 20, 0.5)

-- Helper function to set status text with priority
function Functions:SetStatus(text, priority, duration)
    priority = priority or 1
    duration = duration or 0.5
    local currentPriority = peek(self.StatusPriority)
    local currentExpire = peek(self.StatusExpireTime)
    
    -- Only override if higher/equal priority OR current status expired
    if priority >= currentPriority or tick() > currentExpire then
        self.StatusText:set(text)
        self.StatusPriority:set(priority)
        self.StatusExpireTime:set(tick() + duration)
        
        -- Schedule clear after duration
        task.delay(duration, function()
            if peek(self.StatusText) == text and peek(self.StatusExpireTime) <= tick() then
                self.StatusText:set("")
                self.StatusPriority:set(0)
            end
        end)
    end
end

Functions.AnimatedVisibility = scope:Spring(
    scope:Computed(function(use)
        return use(Functions.IsOpen) and 1 or 0
    end),
    15, 1
)
Functions.AnimatedOffsetX = scope:Spring(Functions.ClayOffsetX, 18, 0.7)
Functions.AnimatedOffsetY = scope:Spring(Functions.ClayOffsetY, 18, 0.7)
Functions.AnimatedProgress = scope:Spring(Functions.Progress, 12, 0.7)
Functions.AnimatedStability = scope:Spring(Functions.StabilityProgress, 15, 0.6)
Functions.AnimatedPushFlash = scope:Spring(Functions.PushFlash, 25, 0.5)
Functions.AnimatedShake = scope:Spring(Functions.ShakeIntensity, 20, 0.5)

-- Default stage configuration (used if no config provided)
Functions.DefaultStages = {
    [1] = {
        stabilityRequired = 3.0,
        driftStrength = 0.5,
        friction = 3.0,
        pushStrength = 0.6,
        maxOffset = 0.85,
        threshold = 0.3,
        wheelSpeed = 1.5,
        counterWindowStart = 0.3,
        counterWindowEnd = 0.15,
        depletionRate = 0.5,  -- How fast progress depletes when off-center (0 = no depletion)
        pulses = {
            { interval = 2.5, strength = 0.7 },
            { interval = 2.2, strength = 0.6 },
            { interval = 2.0, strength = 0.65 },
        },
    },
    [2] = {
        stabilityRequired = 3.5,
        driftStrength = 0.7,
        friction = 2.5,
        pushStrength = 0.6,
        maxOffset = 0.85,
        threshold = 0.25,
        wheelSpeed = 2.5,
        counterWindowStart = 0.25,
        counterWindowEnd = 0.12,
        depletionRate = 0.5,
        pulses = {
            { interval = 2.0, strength = 0.75 },
            { interval = 1.8, strength = 0.7 },
            { interval = 1.5, strength = 0.65 },
        },
    },
    [3] = {
        stabilityRequired = 4.0,
        driftStrength = 1.0,
        friction = 2.0,
        pushStrength = 0.6,
        maxOffset = 0.85,
        threshold = 0.2,
        wheelSpeed = 4.0,
        counterWindowStart = 0.2,
        counterWindowEnd = 0.1,
        depletionRate = 0.5,
        pulses = {
            { interval = 1.5, strength = 0.85 },
            { interval = 1.3, strength = 0.8 },
            { interval = 1.2, strength = 0.75 },
        },
    },
}

-- Current active stages (set when Open is called)
Functions.Stages = Functions.DefaultStages

-- Internal state
Functions._gameConnection = nil
Functions._originalJumpPower = nil
Functions._originalWalkSpeed = nil
Functions._driftTimer = 0
Functions._driftTargetX = 0
Functions._driftTargetY = 0
Functions._pulseTimer = 0
Functions._currentPulseIndex = 1
Functions._pulsesUntilChange = 0
Functions._playerPushedDuringWindow = false
Functions._playerPushDirection = nil

-- Callbacks
Functions.OnExit = nil
Functions.OnComplete = nil

-- Cardinal directions for pulses
Functions.CardinalDirections = {
    {name = "up", x = 0, y = -1},
    {name = "down", x = 0, y = 1},
    {name = "left", x = -1, y = 0},
    {name = "right", x = 1, y = 0},
}

-- Get the config for a specific stage
function Functions:GetStageConfig(stageNum)
    local config = self.Stages[stageNum]
    
    -- Fallback: if stage doesn't exist, use highest available
    if not config then
        local highestStage = 1
        for k, _ in pairs(self.Stages) do
            if type(k) == "number" and k > highestStage then
                highestStage = k
            end
        end
        config = self.Stages[highestStage] or self.DefaultStages[1]
    end
    
    -- Return with defaults for any missing fields
    local pulses = config.pulses
    -- If pulses is explicitly set to empty array, keep it empty (no pulses mode)
    -- Only provide default if pulses is nil/not defined
    if pulses == nil then
        pulses = {{ interval = 2.0, strength = 0.7 }}
    end
    
    return {
        stabilityRequired = config.stabilityRequired or 3.0,
        driftStrength = config.driftStrength or 0.5,
        friction = config.friction or 2.5,
        pushStrength = config.pushStrength or 0.6,
        maxOffset = config.maxOffset or 0.85,
        threshold = config.threshold or 0.25,
        wheelSpeed = config.wheelSpeed or 2.0,
        counterWindowStart = config.counterWindowStart or 0.25,
        counterWindowEnd = config.counterWindowEnd or 0.12,
        pulses = pulses,
    }
end

-- Pick a new random drift direction
function Functions:RandomizeDrift()
    local angle = math.random() * math.pi * 2
    local strength = 0.5 + math.random() * 0.5
    self._driftTargetX = math.cos(angle) * strength
    self._driftTargetY = math.sin(angle) * strength
end

-- Prepare the next pulse
function Functions:PrepareNextPulse()
    local stage = peek(self.CurrentStage)
    local config = self:GetStageConfig(stage)
    
    -- Check if this stage has pulses
    local hasPulses = config.pulses and #config.pulses > 0
    self.HasPulses:set(hasPulses)
    
    -- Skip pulse setup if no pulses
    if not hasPulses then
        self.PulseProgress:set(0)
        self.InCounterWindow:set(false)
        return
    end
    
    -- Set the forecasted drift direction
    local dir = self.CardinalDirections[math.random(1, 4)]
    self.NextDriftX:set(dir.x)
    self.NextDriftY:set(dir.y)
    self.NextDriftDirection:set(dir.name)
    
    -- Change pulse pattern every 2-3 pulses for variety
    self._pulsesUntilChange = self._pulsesUntilChange - 1
    if self._pulsesUntilChange <= 0 and #config.pulses > 0 then
        self._currentPulseIndex = math.random(1, #config.pulses)
        self._pulsesUntilChange = math.random(2, 3)
        local pulse = config.pulses[self._currentPulseIndex]
        self.PulseInterval:set(pulse.interval)
    end
    
    -- Reset pulse timer
    self._pulseTimer = 0
    self.PulseProgress:set(0)
    self._playerPushedDuringWindow = false
    self._playerPushDirection = nil
end

-- Execute the drift pulse
function Functions:ExecutePulse()
    local stage = peek(self.CurrentStage)
    local config = self:GetStageConfig(stage)
    local pulse = config.pulses[self._currentPulseIndex] or config.pulses[1]
    
    -- Get the forecasted drift
    local driftX = peek(self.NextDriftX)
    local driftY = peek(self.NextDriftY)
    local strength = pulse.strength * config.driftStrength
    
    -- Check if player made a counter-push during the window
    local negated = self:EvaluateCounterPush(driftX, driftY)
    
    -- Only apply drift if NOT negated
    if not negated then
        local velX = peek(self.VelocityX) + driftX * strength
        local velY = peek(self.VelocityY) + driftY * strength
        self.VelocityX:set(velX)
        self.VelocityY:set(velY)
        self.PulseNegated:set(false)
    else
        self.PulseNegated:set(true)
    end
    
    -- Visual flash
    self.PulseFlash:set(1)
    task.delay(0.2, function()
        self.PulseFlash:set(0)
    end)
    
    -- Prepare next pulse
    self:PrepareNextPulse()
end

-- Evaluate if player's push was a good counter
function Functions:EvaluateCounterPush(driftX, driftY)
    if not self._playerPushedDuringWindow then
        self.LastPushResult:set("")
        return false
    end
    
    local pushDir = self._playerPushDirection
    local pushX, pushY = 0, 0
    if pushDir == "up" then pushY = -1
    elseif pushDir == "down" then pushY = 1
    elseif pushDir == "left" then pushX = -1
    elseif pushDir == "right" then pushX = 1
    end
    
    local dot = pushX * driftX + pushY * driftY
    
    if dot < -0.5 then
        -- Perfect counter!
        self.LastPushResult:set("perfect")
        local combo = peek(self.PerfectCounter) + 1
        self.PerfectCounter:set(combo)
        self:SetStatus("Perfect!", 10, 1.2)  -- High priority, long duration
        return true
    elseif dot < 0 then
        self.LastPushResult:set("good")
        self:SetStatus("Good!", 7, 0.8)  -- Medium priority
    else
        self.LastPushResult:set("miss")
        self.PerfectCounter:set(0)
        self:SetStatus("Miss!", 5, 0.6)  -- Lower priority
    end
    
    return false
end

-- Open the minigame with config
function Functions:Open(config, onCompleteCallback, legacyDifficulty)
    -- Support legacy call signature: Open(onExit, onComplete, difficulty)
    if type(config) == "function" then
        config = {
            onExit = config,
            onComplete = onCompleteCallback,
        }
    end
    
    config = config or {}
    
    -- Set callbacks
    self.OnExit = config.onExit
    self.OnComplete = config.onComplete
    
    -- Apply stages config or use defaults
    if config.stages and #config.stages > 0 then
        self.Stages = config.stages
        self.TotalStages:set(#config.stages)
    else
        -- Deep copy defaults
        self.Stages = {}
        for k, v in pairs(self.DefaultStages) do
            self.Stages[k] = {}
            for key, val in pairs(v) do
                if type(val) == "table" then
                    self.Stages[k][key] = {}
                    for i, pulse in ipairs(val) do
                        self.Stages[k][key][i] = { interval = pulse.interval, strength = pulse.strength }
                    end
                else
                    self.Stages[k][key] = val
                end
            end
        end
        self.TotalStages:set(3)
    end
    
    self.IsOpen:set(true)
    
    -- Reset all state
    self.ClayOffsetX:set(0)
    self.ClayOffsetY:set(0)
    self.VelocityX:set(0)
    self.VelocityY:set(0)
    self.WheelAngle:set(0)
    self.CurrentStage:set(1)
    self.StabilityProgress:set(0)
    self.Progress:set(0)
    self.GameState:set("playing")
    self.IsCentered:set(true)
    self.PushDirection:set("none")
    self.PushFlash:set(0)
    self.ShakeIntensity:set(0)
    self.StageText:set("")
    
    -- Reset pulse system
    self.PulseProgress:set(0)
    self.PulseFlash:set(0)
    self.InCounterWindow:set(false)
    self.LastPushResult:set("")
    self.PerfectCounter:set(0)
    self._pulseTimer = 0
    
    -- Reset status text system
    self.StatusText:set("")
    self.StatusPriority:set(0)
    self.StatusExpireTime:set(0)
    
    -- Reset success/exit state
    self.ShowSuccess:set(false)
    self.IsExiting:set(false)
    
    -- Reset countdown state
    self.ShowCountdown:set(false)
    self.CountdownNumber:set(3)
    
    -- Reset counter flash
    self.CounterSuccess:set(false)
    self.CounterFlash:set(0)
    self.LastPushedDirection:set("none")
    
    local stageConfig = self:GetStageConfig(1)
    local hasPulses = stageConfig.pulses and #stageConfig.pulses > 0
    self.HasPulses:set(hasPulses)
    
    if hasPulses then
        self._currentPulseIndex = math.random(1, #stageConfig.pulses)
        self._pulsesUntilChange = math.random(2, 3)
        self.PulseInterval:set(stageConfig.pulses[self._currentPulseIndex].interval)
    else
        self._currentPulseIndex = 1
        self._pulsesUntilChange = 0
        self.PulseInterval:set(999)  -- Large interval so pulse never triggers
    end
    self.BeatCount:set(3)
    self.CounterWindowFlash:set(0)
    self.PulseNegated:set(false)
    
    self._driftTimer = 0
    self:RandomizeDrift()
    self:PrepareNextPulse()
    
    self:DisableCharacterControls()
    
    -- Show countdown before starting
    self:StartCountdown(function()
        self:StartGameLoop()
    end)
end

function Functions:StartCountdown(onComplete)
    self.GameState:set("countdown")
    self.ShowCountdown:set(true)
    self.CountdownNumber:set(3)
    
    -- 3, 2, 1 countdown (0.33s each = 1s total)
    local countdownDelay = 0.33
    
    task.delay(countdownDelay, function()
        self.CountdownNumber:set(2)
        
        task.delay(countdownDelay, function()
            self.CountdownNumber:set(1)
            
            task.delay(countdownDelay, function()
                self.ShowCountdown:set(false)
                self.GameState:set("playing")
                if onComplete then
                    onComplete()
                end
            end)
        end)
    end)
end

function Functions:Close()
    self.IsOpen:set(false)
    self:StopGameLoop()
    self:EnableCharacterControls()
end

function Functions:Exit()
    -- Trigger exit animation
    self.IsExiting:set(true)
    
    task.delay(0.1, function()  -- Wait for drop animation
        self.IsExiting:set(false)
        self.ShowSuccess:set(false)
        self:Close()
        if self.OnExit then
            task.defer(self.OnExit)
        end
    end)
end

function Functions:DisableCharacterControls()
    local character = LocalPlayer.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            self._originalJumpPower = humanoid.JumpPower
            self._originalWalkSpeed = humanoid.WalkSpeed
            humanoid.JumpPower = 0
            humanoid.WalkSpeed = 0
        end
    end
end

function Functions:EnableCharacterControls()
    local character = LocalPlayer.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            if self._originalJumpPower then
                humanoid.JumpPower = self._originalJumpPower
                self._originalJumpPower = nil
            end
            if self._originalWalkSpeed then
                humanoid.WalkSpeed = self._originalWalkSpeed
                self._originalWalkSpeed = nil
            end
        end
    end
end

function Functions:StartGameLoop()
    self:StopGameLoop()
    
    self._gameConnection = RunService.RenderStepped:Connect(function(dt)
        local state = peek(self.GameState)
        if state ~= "playing" then return end
        
        local stage = peek(self.CurrentStage)
        local config = self:GetStageConfig(stage)
        
        -- Spin the wheel (visual only)
        local wheelAngle = peek(self.WheelAngle)
        self.WheelAngle:set((wheelAngle + config.wheelSpeed * dt) % (math.pi * 2))
        
        -- PULSE RHYTHM SYSTEM
        local pulseInterval = peek(self.PulseInterval)
        self._pulseTimer = self._pulseTimer + dt
        local progress = math.clamp(self._pulseTimer / pulseInterval, 0, 1)
        self.PulseProgress:set(progress)
        
        -- Calculate beat countdown
        local beatsTotal = 3
        local beatProgress = progress * beatsTotal
        local currentBeat = math.ceil(beatsTotal - beatProgress + 0.001)
        currentBeat = math.clamp(currentBeat, 0, 3)
        self.BeatCount:set(currentBeat)
        
        -- Check if we're in the counter window
        local timeUntilPulse = pulseInterval - self._pulseTimer
        local wasInWindow = peek(self.InCounterWindow)
        local inWindow = timeUntilPulse <= config.counterWindowStart and timeUntilPulse > -config.counterWindowEnd
        self.InCounterWindow:set(inWindow)
        
        -- Reset counter used flag when entering a new window
        if inWindow and not wasInWindow then
            self._counterUsedThisWindow = false
        end
        
        -- Flash during counter window
        self.CounterWindowFlash:set(inWindow and 1 or 0)
        
        -- Execute pulse when timer reaches interval
        if self._pulseTimer >= pulseInterval then
            self:ExecutePulse()
        end
        
        -- Apply gentle continuous drift
        local velX = peek(self.VelocityX)
        local velY = peek(self.VelocityY)
        velX = velX + self._driftTargetX * config.driftStrength * 0.15 * dt
        velY = velY + self._driftTargetY * config.driftStrength * 0.15 * dt
        
        -- Apply friction
        local frictionMult = math.max(0, 1 - config.friction * dt)
        velX = velX * frictionMult
        velY = velY * frictionMult
        
        self.VelocityX:set(velX)
        self.VelocityY:set(velY)
        
        -- Update position
        local offsetX = peek(self.ClayOffsetX) + velX * dt
        local offsetY = peek(self.ClayOffsetY) + velY * dt
        
        -- Clamp to max offset (with bounce)
        local maxOff = config.maxOffset
        if math.abs(offsetX) > maxOff then
            offsetX = math.sign(offsetX) * maxOff
            self.VelocityX:set(-velX * 0.3)
        end
        if math.abs(offsetY) > maxOff then
            offsetY = math.sign(offsetY) * maxOff
            self.VelocityY:set(-velY * 0.3)
        end
        
        self.ClayOffsetX:set(offsetX)
        self.ClayOffsetY:set(offsetY)
        
        -- Check if centered
        local distance = math.sqrt(offsetX * offsetX + offsetY * offsetY)
        local isCentered = distance <= config.threshold
        self.IsCentered:set(isCentered)
        
        -- Update status text for centered/off-center (low priority, doesn't override counters)
        if peek(self.StatusPriority) <= 2 then
            if isCentered then
                self:SetStatus("Centered!", 2, 0.3)
            else
                self:SetStatus("Off-center...", 1, 0.3)
            end
        end
        
        -- Shake when very off-center
        local shakeAmount = math.clamp((distance - 0.5) / 0.5, 0, 1)
        self.ShakeIntensity:set(shakeAmount * 0.5)
        
        -- Build stability when centered
        local stability = peek(self.StabilityProgress)
        if isCentered then
            stability = stability + dt
            if stability >= config.stabilityRequired then
                self:CompleteStage()
                return
            end
        else
            -- Use depletionRate from config (default 0.5 if not specified)
            local depletionRate = config.depletionRate or 0.5
            stability = math.max(0, stability - dt * depletionRate)
        end
        self.StabilityProgress:set(stability)
        
        -- Update overall progress
        local stageProgress = stability / config.stabilityRequired
        local totalStages = peek(self.TotalStages)
        local overallProgress = ((stage - 1) + stageProgress) / totalStages
        self.Progress:set(overallProgress)
    end)
end

function Functions:StopGameLoop()
    if self._gameConnection then
        self._gameConnection:Disconnect()
        self._gameConnection = nil
    end
end

function Functions:CompleteStage()
    local currentStage = peek(self.CurrentStage)
    local totalStages = peek(self.TotalStages)
    
    if currentStage >= totalStages then
        -- Game complete!
        self.GameState:set("complete")
        self.Progress:set(1)
        self:StopGameLoop()
        
        -- Show success screen
        self.ShowSuccess:set(true)
        
        -- After showing success, animate out and call complete
        task.delay(1.5, function()
            self.IsExiting:set(true)  -- Trigger exit animation
            
            task.delay(0.5, function()  -- Wait for animation
                self.IsExiting:set(false)
                self.ShowSuccess:set(false)
                self.IsOpen:set(false)
                self:EnableCharacterControls()
                
                if self.OnComplete then
                    self.OnComplete()
                end
            end)
        end)
        return
    end
    
    -- Move to next stage
    local nextStage = currentStage + 1
    self.GameState:set("stageTransition")
    self.StageText:set("STAGE " .. nextStage .. "!")
    
    task.delay(0.8, function()
        self.StageText:set("")
        self.CurrentStage:set(nextStage)
        self.StabilityProgress:set(0)
        
        -- Reset for new stage
        self.ClayOffsetX:set(peek(self.ClayOffsetX) * 0.5)
        self.ClayOffsetY:set(peek(self.ClayOffsetY) * 0.5)
        self.VelocityX:set(0)
        self.VelocityY:set(0)
        self:RandomizeDrift()
        
        -- Reset pulse system for new stage config
        local config = self:GetStageConfig(nextStage)
        local hasPulses = config.pulses and #config.pulses > 0
        self.HasPulses:set(hasPulses)
        
        if hasPulses then
            self._currentPulseIndex = math.random(1, #config.pulses)
            self._pulsesUntilChange = math.random(2, 3)
            self.PulseInterval:set(config.pulses[self._currentPulseIndex].interval)
        else
            self._currentPulseIndex = 1
            self._pulsesUntilChange = 0
            self.PulseInterval:set(999)  -- Large interval so pulse never triggers
        end
        self:PrepareNextPulse()
        
        -- Show countdown before next stage
        self:StartCountdown(function()
            self:StartGameLoop()
        end)
    end)
end

-- Called when player pushes in a direction
function Functions:OnPush(direction)
    local state = peek(self.GameState)
    if state ~= "playing" then return end
    
    -- Set the last pushed direction for UI flash feedback
    self.LastPushedDirection:set(direction)
    task.delay(0.15, function()
        if peek(self.LastPushedDirection) == direction then
            self.LastPushedDirection:set("none")
        end
    end)
    
    -- Track if this push is during the counter window
    if peek(self.InCounterWindow) and not self._counterUsedThisWindow then
        self._playerPushedDuringWindow = true
        self._playerPushDirection = direction
        
        -- Check if it's the correct counter direction (opposite of drift)
        local driftDir = peek(self.NextDriftDirection)
        local isCorrectCounter = 
            (driftDir == "up" and direction == "down") or
            (driftDir == "down" and direction == "up") or
            (driftDir == "left" and direction == "right") or
            (driftDir == "right" and direction == "left")
        
        if isCorrectCounter then
            self._counterUsedThisWindow = true  -- Prevent multiple counters per window
            self.CounterSuccess:set(true)
            self.CounterFlash:set(1)  -- Trigger flash animation
            self.LastPushResult:set("perfect")
            self:SetStatus("Perfect!", 10, 1.2)  -- High priority, visible for 1.2s
            
            task.delay(0.4, function()
                self.CounterSuccess:set(false)
            end)
            task.delay(0.1, function()
                self.CounterFlash:set(0)  -- Reset flash for spring to animate back
            end)
        end
    end
    
    local stage = peek(self.CurrentStage)
    local config = self:GetStageConfig(stage)
    local pushStrength = config.pushStrength
    
    local velX = peek(self.VelocityX)
    local velY = peek(self.VelocityY)
    
    -- Add velocity in push direction
    if direction == "up" then
        velY = velY - pushStrength
    elseif direction == "down" then
        velY = velY + pushStrength
    elseif direction == "left" then
        velX = velX - pushStrength
    elseif direction == "right" then
        velX = velX + pushStrength
    end
    
    self.VelocityX:set(velX)
    self.VelocityY:set(velY)
    
    -- Visual feedback
    self.PushDirection:set(direction)
    self.PushFlash:set(1)
    
    task.delay(0.15, function()
        self.PushDirection:set("none")
        self.PushFlash:set(0)
    end)
end

return Functions
