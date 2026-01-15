local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Fusion = require(Shared.Fusion)

local peek = Fusion.peek

local Functions = {}

-- Create scope for reactive state
Functions.scope = Fusion.scoped(Fusion)
local scope = Functions.scope

-- Constants
Functions.CLOSED_POSITION = UDim2.fromScale(0.5, 2)
Functions.OPEN_POSITION = UDim2.fromScale(0.5, 0.5)

-- Reactive state
Functions.IsOpen = scope:Value(false)
Functions.SlotsData = scope:Value({}) -- Current slots data
Functions.MaxSlots = scope:Value(4)
Functions.CoolingTableLevel = scope:Value(0)

-- Callbacks (set when Show is called)
Functions.OnCollect = nil
Functions.OnDelete = nil
Functions.OnClose = nil

-- Slot scopes for cleanup
Functions.SlotScopes = {}

-- Animation springs
Functions.AnimatedPosition = scope:Spring(
    scope:Computed(function(use)
        return use(Functions.IsOpen) and Functions.OPEN_POSITION or Functions.CLOSED_POSITION
    end), 
    18, 0.7
)

-- Exit button hover state
Functions.ExitHovered = scope:Value(false)
Functions.ExitPressed = scope:Value(false)

Functions.ExitScale = scope:Spring(scope:Computed(function(use)
    if use(Functions.ExitPressed) then return 0.9 end
    if use(Functions.ExitHovered) then return 1.2 end
    return 1
end), 30, 0.7)

Functions.ExitRotation = scope:Spring(scope:Computed(function(use)
    if use(Functions.ExitHovered) then return 10 end
    return 0
end), 15, 0.5)

-- Format time to shortform: 5m, 2m 40s, 10h 50m, etc.
function Functions.FormatTime(seconds: number): string
    if seconds <= 0 then
        return "Done!"
    end
    
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)
    
    if hours > 0 then
        if minutes > 0 then
            return string.format("%dh %dm", hours, minutes)
        else
            return string.format("%dh", hours)
        end
    elseif minutes > 0 then
        if secs > 0 then
            return string.format("%dm %ds", minutes, secs)
        else
            return string.format("%dm", minutes)
        end
    else
        return string.format("%ds", secs)
    end
end

-- Cleanup slot scopes
function Functions:CleanupSlots()
    for _, slotScope in ipairs(self.SlotScopes) do
        Fusion.doCleanup(slotScope)
    end
    self.SlotScopes = {}
end

-- Open the UI
function Functions:Open()
    Functions.IsOpen:set(true)
end

-- Close the UI
function Functions:Close()
    Functions.IsOpen:set(false)
    self:CleanupSlots()
    if Functions.OnClose then
        Functions.OnClose()
    end
end

-- Show the cooling table UI with data
function Functions:Show(slotsData: {[string]: any}, maxSlots: number, coolingTableLevel: number?, onCollect: ((number) -> ())?, onDelete: ((number) -> ())?, onClose: (() -> ())?)
    -- Cleanup previous slots
    self:CleanupSlots()
    
    -- Store callbacks
    Functions.OnCollect = onCollect
    Functions.OnDelete = onDelete
    Functions.OnClose = onClose
    
    -- Update reactive state
    Functions.SlotsData:set(slotsData)
    Functions.MaxSlots:set(maxSlots)
    Functions.CoolingTableLevel:set(coolingTableLevel or 0)
    
    -- Open UI
    self:Open()
end

-- Hide the cooling table UI
function Functions:Hide()
    self:Close()
end

-- Check if UI is currently shown
function Functions:IsVisible(): boolean
    return peek(Functions.IsOpen)
end

-- Alias for backwards compatibility
function Functions:GetVisible(): boolean
    return self:IsVisible()
end

return Functions
