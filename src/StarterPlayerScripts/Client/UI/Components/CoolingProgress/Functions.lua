local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared

local Fusion = require(Shared.Fusion)

local Functions = {}

-- Create scope for reactive state
Functions.scope = Fusion.scoped(Fusion)

-- Store active cooling billboards
Functions.ActiveBillboards = {}

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

-- Create a cooling billboard for a slot
function Functions:CreateCoolingBillboard(adornee: BasePart, endTime: number, _styleName: string)
    local billboardScope = Fusion.scoped(Fusion)
    local s = billboardScope
    
    -- Calculate initial remaining time (this becomes the total duration for progress)
    local totalDuration = math.max(1, endTime - os.time())
    
    -- Reactive state for this billboard
    local RemainingTime = s:Value(totalDuration)
    
    -- Animation
    local AnimatedTransparency = s:Spring(
        s:Computed(function(use)
            return use(RemainingTime) <= 0 and 1 or 0
        end),
        10, 1
    )
    
    -- Update timer
    local updateConnection = RunService.Heartbeat:Connect(function()
        local remaining = math.max(0, endTime - os.time())
        RemainingTime:set(remaining)
    end)
    
    -- Store connection for cleanup when scope is destroyed
    table.insert(billboardScope, updateConnection)
    
    -- Create billboard
    local billboard = s:New "BillboardGui" {
        Name = "CoolingProgressBillboard",
        Active = true,
        AlwaysOnTop = true,
        ClipsDescendants = true,
        LightInfluence = 0,
        Size = UDim2.fromOffset(120, 50),
        StudsOffset = Vector3.new(0, 2.5, 0),
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        MaxDistance = 50,
        Adornee = adornee,
        Parent = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("UI"):WaitForChild("ProximityPrompts"),
        
        [Fusion.Children] = {
            s:New "CanvasGroup" {
                Name = "Container",
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundTransparency = 1,
                GroupTransparency = AnimatedTransparency,
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromScale(1, 1),
                
                [Fusion.Children] = {
                    -- Background
                    s:New "Frame" {
                        Name = "Background",
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundColor3 = Color3.fromRGB(30, 30, 30),
                        BackgroundTransparency = 0.2,
                        Position = UDim2.fromScale(0.5, 0.5),
                        Size = UDim2.fromScale(1, 1),
                        
                        [Fusion.Children] = {
                            s:New "UICorner" {
                                CornerRadius = UDim.new(0, 8),
                            },
                            s:New "UIStroke" {
                                Color = Color3.fromRGB(80, 80, 80),
                                Thickness = 1.5,
                            },
                        },
                    },
                    
                    -- Time display
                    s:New "TextLabel" {
                        Name = "TimeLabel",
                        AnchorPoint = Vector2.new(0.5, 0),
                        BackgroundTransparency = 1,
                        Font = Enum.Font.GothamBold, -- Highway Gothic style
                        Position = UDim2.fromScale(0.5, 0.08),
                        Size = UDim2.fromScale(0.9, 0.45),
                        Text = s:Computed(function(use)
                            return Functions.FormatTime(use(RemainingTime))
                        end),
                        TextColor3 = Color3.fromRGB(255, 255, 255),
                        TextScaled = true,
                        TextXAlignment = Enum.TextXAlignment.Center,
                        TextYAlignment = Enum.TextYAlignment.Center,
                    },
                    
                    -- Progress bar background
                    s:New "Frame" {
                        Name = "ProgressBarBg",
                        AnchorPoint = Vector2.new(0.5, 1),
                        BackgroundColor3 = Color3.fromRGB(50, 50, 50),
                        Position = UDim2.fromScale(0.5, 0.88),
                        Size = UDim2.fromScale(0.85, 0.2),
                        
                        [Fusion.Children] = {
                            s:New "UICorner" {
                                CornerRadius = UDim.new(0.5, 0),
                            },
                            
                            -- Progress bar fill
                            s:New "Frame" {
                                Name = "ProgressBarFill",
                                AnchorPoint = Vector2.new(0, 0.5),
                                BackgroundColor3 = Color3.fromRGB(100, 180, 255),
                                Position = UDim2.fromScale(0, 0.5),
                                Size = s:Computed(function(use)
                                    -- Calculate progress based on remaining time vs total duration
                                    local remaining = use(RemainingTime)
                                    if totalDuration <= 0 then return UDim2.fromScale(1, 1) end
                                    local progress = math.clamp(1 - (remaining / totalDuration), 0, 1)
                                    return UDim2.fromScale(progress, 1)
                                end),
                                
                                [Fusion.Children] = {
                                    s:New "UICorner" {
                                        CornerRadius = UDim.new(0.5, 0),
                                    },
                                },
                            },
                        },
                    },
                },
            },
        },
    }
    
    return {
        billboard = billboard,
        scope = billboardScope,
        cleanup = function()
            billboardScope:doCleanup()
        end,
    }
end

-- Show cooling progress for a slot
function Functions:ShowCoolingProgress(slotAdornee: BasePart, endTime: number, styleName: string, slotKey: string)
    -- Remove existing billboard for this slot if any
    self:HideCoolingProgress(slotKey)
    
    local billboardData = self:CreateCoolingBillboard(slotAdornee, endTime, styleName)
    self.ActiveBillboards[slotKey] = billboardData
    
    return billboardData
end

-- Hide cooling progress for a slot
function Functions:HideCoolingProgress(slotKey: string)
    local existing = self.ActiveBillboards[slotKey]
    if existing then
        existing.cleanup()
        self.ActiveBillboards[slotKey] = nil
    end
end

-- Hide all cooling progress billboards
function Functions:HideAll()
    for slotKey, _ in pairs(self.ActiveBillboards) do
        self:HideCoolingProgress(slotKey)
    end
end

return Functions
