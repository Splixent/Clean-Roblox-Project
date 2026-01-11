local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared

local Fusion = require(Shared.Fusion)
local SharedConstants = require(Shared.Constants)

local peek = Fusion.peek

local LocalPlayer = Players.LocalPlayer

local Functions = {}

-- Constants
Functions.MAX_DISTANCE = 20 -- Studs before hiding
Functions.STACK_HORIZONTAL_OFFSET = 0 -- X offset (centered between prompts)
Functions.STACK_VERTICAL_OFFSET = 2 -- Y offset (studs above adornee)
Functions.PROMPT_OFFSET_ADJUSTMENT = -0.7 -- Negative = prompts move closer to center, Positive = prompts move outward

-- Store references to prompts we're adjusting
Functions.AffectedPrompts = {}

-- Create scope for reactive state
Functions.scope = Fusion.scoped(Fusion)
local scope = Functions.scope

-- Reactive state
Functions.IsVisible = scope:Value(false)
Functions.IsInRange = scope:Value(true) -- Player distance check
Functions.RequiredClay = scope:Value(0)
Functions.CurrentClay = scope:Value(0)
Functions.ClayType = scope:Value("normal")
Functions.Adornee = scope:Value(nil)
Functions.StackOffset = scope:Value(Vector3.new(0, 2, 0)) -- Y offset for positioning

-- Combined visibility (must be visible AND in range)
Functions.ShouldShow = scope:Computed(function(use)
    return use(Functions.IsVisible) and use(Functions.IsInRange)
end)

-- Animation
Functions.AnimatedTransparency = scope:Spring(
    scope:Computed(function(use)
        return use(Functions.ShouldShow) and 0 or 1
    end),
    15, 1
)

Functions.AnimatedStackOffset = scope:Spring(Functions.StackOffset, 20, 0.8)

-- Distance checking connection
local distanceConnection = nil

local function getPlayerDistance(position: Vector3): number
    local character = LocalPlayer.Character
    if not character then
        return math.huge
    end
    
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        return math.huge
    end
    
    return (rootPart.Position - position).Magnitude
end

local function getAdorneePosition(): Vector3?
    local adornee = peek(Functions.Adornee)
    if not adornee then return nil end
    
    if adornee:IsA("BasePart") then
        return adornee.Position
    elseif adornee:IsA("Model") then
        local primaryPart = adornee.PrimaryPart
        if primaryPart then
            return primaryPart.Position
        end
        local part = adornee:FindFirstChildWhichIsA("BasePart")
        if part then
            return part.Position
        end
    elseif adornee:IsA("Attachment") then
        return adornee.WorldPosition
    end
    return nil
end

local function startDistanceCheck()
    if distanceConnection then return end
    
    distanceConnection = RunService.Heartbeat:Connect(function()
        local position = getAdorneePosition()
        if not position then
            Functions.IsInRange:set(false)
            return
        end
        
        local distance = getPlayerDistance(position)
        local inRange = distance <= Functions.MAX_DISTANCE
        
        if peek(Functions.IsInRange) ~= inRange then
            Functions.IsInRange:set(inRange)
        end
    end)
end

local function stopDistanceCheck()
    if distanceConnection then
        distanceConnection:Disconnect()
        distanceConnection = nil
    end
end

function Functions:Show(requiredClay: number, clayType: string?, adornee: Instance?, prompts: {any}?)
    self.RequiredClay:set(requiredClay)
    self.ClayType:set(clayType or "normal")
    if adornee then
        self.Adornee:set(adornee)
    end
    self.IsVisible:set(true)
    self.IsInRange:set(true) -- Assume in range initially
    startDistanceCheck()
    
    -- Store and adjust the specific prompts
    if prompts then
        self.AffectedPrompts = prompts
        for _, prompt in ipairs(prompts) do
            if prompt.SetCustomHorizontalOffset then
                prompt:SetCustomHorizontalOffset(self.PROMPT_OFFSET_ADJUSTMENT)
            end
        end
    end
end

function Functions:Hide()
    self.IsVisible:set(false)
    stopDistanceCheck()
    
    -- Reset the specific prompts back to normal
    for _, prompt in ipairs(self.AffectedPrompts) do
        if prompt.SetCustomHorizontalOffset then
            prompt:SetCustomHorizontalOffset(0)
        end
    end
    self.AffectedPrompts = {}
end

function Functions:SetAdornee(adornee: Instance?)
    self.Adornee:set(adornee)
end

function Functions:SetStackOffset(offset: Vector3)
    self.StackOffset:set(offset)
end

function Functions:UpdateCurrentClay(amount: number)
    self.CurrentClay:set(amount)
end

return Functions
