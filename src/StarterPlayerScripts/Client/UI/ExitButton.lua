--[[
    ExitButton Component
    A reusable animated exit button with hover/press effects.
    
    Usage:
        local ExitButton = require(script.Parent.ExitButton)
        local button = ExitButton.new(scope, {
            Position = UDim2.fromScale(0.97, 0.05),
            Size = UDim2.fromScale(0.099, 0.236),
            BaseRotation = -15, -- Optional, default is 0
            OnActivated = function() end,
        })
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Fusion = require(Shared.Fusion)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

local ExitButton = {}

-- Create state values for hover/press animations
function ExitButton.createState(scope)
    return {
        IsHovered = scope:Value(false),
        IsPressed = scope:Value(false),
    }
end

-- Create animation springs from state
function ExitButton.createAnimations(scope, state, baseRotation, basePosition)
    baseRotation = baseRotation or 0
    basePosition = basePosition or UDim2.fromScale(0.5, 0.5)
    
    local scale = scope:Spring(
        scope:Computed(function(use)
            if use(state.IsPressed) then return 0.9 end
            if use(state.IsHovered) then return 1.15 end
            return 1
        end),
        50, 0.6
    )

    local position = scope:Spring(
        scope:Computed(function(use)
            return basePosition
        end),
        50, 0.2
    )
    
    local rotation = scope:Spring(
        scope:Computed(function(use)
            if use(state.IsPressed) then return baseRotation - 5 end
            if use(state.IsHovered) then return baseRotation + 10 end
            return baseRotation
        end),
        15, 0.5
    )
    
    local textColor = scope:Spring(
        scope:Computed(function(use)
            if use(state.IsPressed) then return Color3.fromRGB(180, 0, 3) end
            if use(state.IsHovered) then return Color3.fromRGB(255, 50, 50) end
            return Color3.fromRGB(255, 0, 4)
        end),
        15, 0.7
    )
    
    local strokeColor = scope:Spring(
        scope:Computed(function(use)
            if use(state.IsPressed) then return Color3.fromRGB(150, 0, 3) end
            return Color3.fromRGB(214, 0, 4)
        end),
        15, 0.7
    )

    local strokeThickness = scope:Spring(
        scope:Computed(function(use)
            if use(state.IsPressed) then return 0.04 end
            return 0.08
        end),
        15, 0.7
    )
    
    return {
        Scale = scale,
        Position = position,
        Rotation = rotation,
        TextColor = textColor,
        StrokeColor = strokeColor,
        StrokeThickness = strokeThickness,
    }
end

--[[
    Create a new ExitButton instance
    
    @param scope - Fusion scope
    @param options - Table with:
        - Position: UDim2 (required)
        - Size: UDim2 - Base size before scaling (required)
        - BaseRotation: number - Default rotation angle (default: 0)
        - OnActivated: function - Called when button is clicked (required)
        - ZIndex: number (optional)
]]
function ExitButton.new(scope, options)
    local position = options.Position
    local baseSize = options.Size
    local baseRotation = options.BaseRotation or 0
    local onActivated = options.OnActivated
    local zIndex = options.ZIndex
    
    -- Create state and animations
    local state = ExitButton.createState(scope)
    local animations = ExitButton.createAnimations(scope, state, baseRotation, position)
    
    -- Computed size based on scale
    local animatedSize = scope:Computed(function(use)
        local scale = use(animations.Scale)
        return UDim2.fromScale(
            baseSize.X.Scale * scale,
            baseSize.Y.Scale * scale
        )
    end)
    
    return scope:New "TextButton" {
        Name = "Exit",
        Active = true,
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
        Position = animations.Position,
        Rotation = animations.Rotation,
        Size = animatedSize,
        Text = "X",
        TextColor3 = animations.TextColor,
        TextScaled = true,
        ZIndex = zIndex,
        
        [OnEvent "Activated"] = function()
            if onActivated then
                onActivated()
            end
        end,
        
        [OnEvent "MouseEnter"] = function()
            if UserInputService.PreferredInput == Enum.PreferredInput.KeyboardAndMouse then
                state.IsHovered:set(true)
            end
        end,
        
        [OnEvent "MouseLeave"] = function()
            state.IsHovered:set(false)
            state.IsPressed:set(false)
        end,
        
        [OnEvent "MouseButton1Down"] = function()
            state.IsPressed:set(true)
		    animations.Position:setVelocity(UDim2.fromScale(0, -0.5))
        end,
        
        [OnEvent "MouseButton1Up"] = function()
            state.IsPressed:set(false)
        end,
        
        [Children] = {
            scope:New "UIAspectRatioConstraint" {
                Name = "UIAspectRatioConstraint",
            },
            
            scope:New "UIStroke" {
                Name = "UIStroke",
                Color = animations.StrokeColor,
                StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                Thickness = animations.StrokeThickness,
            },
        }
    }
end

return ExitButton
