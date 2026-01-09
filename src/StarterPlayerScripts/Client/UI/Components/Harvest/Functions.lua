local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared

local Fusion = require(Shared.Fusion)

local LocalPlayer = Players.LocalPlayer

local peek = Fusion.peek

-- Create a scope for Fusion state
local scope = Fusion.scoped(Fusion)

-- Configuration
local DEFAULT_TIMEOUT = 3 -- Seconds of inactivity before harvest times out
local DEFAULT_RANGE = 10 -- Studs before player is considered "out of range"
local ATTEMPT_INCREMENT = 0.08 -- How much each attempt adds to progress
local BASE_DEPLETION_RATE = 0.15 -- Base depletion per second for progress (multiplied by difficulty)
local TARGET_FOLLOW_SPEED = 0.3 -- How fast dark green catches up to light green (per second)
local INACTIVITY_DELAY = 2 -- Seconds of no attempts before timeout starts counting

local Functions = {
    visible = scope:Value(false),
    progress = scope:Value(0),
    targetProgress = scope:Value(0), -- The trailing bar (darker green, follows behind progress)
    
    -- Internal state
    _active = false,
    _location = nil,
    _onSuccess = nil,
    _difficulty = 1,
    _connection = nil,
    _timeout = DEFAULT_TIMEOUT,
    _range = DEFAULT_RANGE,
    _lastAttemptTime = 0, -- Track when last attempt was made
    _inactiveTime = 0, -- Track how long player has been inactive
}

--[=[
    Gets the player's current position
    @return Vector3?
]=]
local function getPlayerPosition(): Vector3?
    local character = LocalPlayer.Character
    if not character then return nil end
    
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return nil end
    
    return rootPart.Position
end

--[=[
    Checks if player is within range of the harvest location
    @return boolean
]=]
function Functions:_isInRange(): boolean
    if not self._location then return false end
    
    local playerPos = getPlayerPosition()
    if not playerPos then return false end
    
    return (playerPos - self._location).Magnitude <= self._range
end

--[=[
    Ends the current harvest session
    @param success boolean -- Whether the harvest was successful
]=]
function Functions:_endHarvest(success: boolean)
    if not self._active then return end
    
    self._active = false
    
    -- Disconnect the update loop
    if self._connection then
        self._connection:Disconnect()
        self._connection = nil
    end
    
    -- Hide UI
    self.visible:set(false)
    
    -- Fire success callback if completed
    if success and self._onSuccess then
        self._onSuccess()
    end
    
    -- Reset state
    self.progress:set(0)
    self.targetProgress:set(0)
    self._location = nil
    self._onSuccess = nil
end

--[=[
    Main update loop for the harvest system
    @param dt number -- Delta time
]=]
function Functions:_update(dt: number)
    if not self._active then return end
    
    -- Check if player left the area
    if not self:_isInRange() then
        self:_endHarvest(false)
        return
    end
    
    -- Track inactivity for timeout
    local timeSinceLastAttempt = tick() - self._lastAttemptTime
    if timeSinceLastAttempt > INACTIVITY_DELAY then
        -- Start counting inactive time after the delay
        self._inactiveTime = self._inactiveTime + dt
        
        -- Check timeout (only after inactivity delay)
        if self._inactiveTime >= self._timeout then
            self:_endHarvest(false)
            return
        end
    else
        -- Reset inactive time if player is actively attempting
        self._inactiveTime = 0
    end
    
    -- Deplete progress (light green) based on difficulty
    local currentProgress = peek(self.progress)
    local depletionRate = BASE_DEPLETION_RATE * self._difficulty
    local newProgress = math.max(0, currentProgress - (depletionRate * dt))
    self.progress:set(newProgress)
    
    -- Dark green follows behind light green slowly
    local currentTarget = peek(self.targetProgress)
    if currentTarget > newProgress then
        -- Target catches up to progress when progress is lower
        local followSpeed = TARGET_FOLLOW_SPEED * self._difficulty
        local newTarget = math.max(newProgress, currentTarget - (followSpeed * dt))
        self.targetProgress:set(newTarget)
    elseif currentTarget < newProgress then
        -- Target instantly matches progress when progress increases
        self.targetProgress:set(newProgress)
    end
    
    -- Check for completion (progress fills to 100%)
    if currentProgress >= 1 then
        self:_endHarvest(true)
        return
    end
end

--[=[
    Sets up a new harvest session
    @param location Vector3 -- The location to harvest at
    @param onSuccess function -- Callback when harvest is complete
    @param difficulty number? -- Difficulty multiplier (affects depletion rate), default 1
    @param timeout number? -- Seconds before timeout, default 10
    @param range number? -- Max distance from location, default 15
    @return { Attempt: function, Cancel: function }
]=]
function Functions:SetupHarvest(location: Vector3, onSuccess: () -> (), difficulty: number?, increment: number?, timeout: number?, range: number?)
    -- End any existing harvest
    if self._active then
        self:_endHarvest(false)
    end
    
    -- Setup new harvest
    self._active = true
    self._location = location
    self._onSuccess = onSuccess
    self._difficulty = difficulty or 1
    self._timeout = timeout or DEFAULT_TIMEOUT
    self._range = range or DEFAULT_RANGE
    self._lastAttemptTime = tick() -- Start fresh
    self._inactiveTime = 0
    
    -- Reset progress
    self.progress:set(0)
    self.targetProgress:set(0) -- Starts at 0, follows progress
    
    -- Show UI
    self.visible:set(true)
    
    -- Start update loop
    self._connection = RunService.Heartbeat:Connect(function(dt)
        self:_update(dt)
    end)
    
    -- Return control interface
    return {
        --[=[
            Call this to progress the harvest (e.g., on button press)
            @return boolean -- Whether the attempt was registered
        ]=]
        Attempt = function(): boolean
            if not self._active then return false end
            if not self:_isInRange() then return false end
            
            -- Update last attempt time (resets timeout)
            self._lastAttemptTime = tick()
            self._inactiveTime = 0
            
            local currentProgress = peek(self.progress)
            local newProgress = math.min(1, currentProgress + (increment or ATTEMPT_INCREMENT))
            self.progress:set(newProgress)
            
            -- Target instantly follows when progress increases
            self.targetProgress:set(newProgress)
            
            return true
        end,
        
        --[=[
            Call this to cancel the harvest early
        ]=]
        Cancel = function()
            self:_endHarvest(false)
        end,
        
        --[=[
            Check if the harvest is still active
            @return boolean
        ]=]
        IsActive = function(): boolean
            return self._active
        end,
    }
end

return Functions