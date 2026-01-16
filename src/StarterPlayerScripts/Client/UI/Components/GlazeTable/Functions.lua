local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared

local Fusion = require(Shared.Fusion)
local SharedConstants = require(Shared.Constants)
local Events = require(Shared.Events)

local peek = Fusion.peek

local GlazePottery = Events.GlazePottery

local Functions = {}

-- Create scope for reactive state
Functions.scope = Fusion.scoped(Fusion)
local scope = Functions.scope

-- Constants
Functions.CLOSED_POSITION = UDim2.fromScale(0.5, 2)
Functions.OPEN_POSITION = UDim2.fromScale(0.5, 0.55)

-- Glaze category tabs
Functions.GlazeTabs = {
    Color = "Color",
    Pattern = "Pattern",
    Finish = "Finish",
}

-- Style section tabs (Bowls, Cups, Limiteds)
Functions.StyleSections = {
    Bowls = "Bowls",
    Cups = "Cups",
    Limiteds = "Limiteds",
}

-- Tab colors for glaze categories
Functions.TAB_COLORS = {
    Color = Color3.fromRGB(255, 130, 130),    -- Red/Pink
    Pattern = Color3.fromRGB(81, 159, 255),   -- Blue
    Finish = Color3.fromRGB(130, 212, 130),   -- Green
}

-- Section name positions and sizes for each glaze tab
Functions.TAB_NAME_DATA = {
    Color = { position = UDim2.new(0.360511, 0, -0.00902886, 0), size = UDim2.new(0.0844794, 0, 0.0790026, 0) },
    Pattern = { position = UDim2.new(0.5, 0, -0.00902886, 0), size = UDim2.new(0.11, 0, 0.0790026, 0) },
    Finish = { position = UDim2.new(0.65, 0, -0.00902886, 0), size = UDim2.new(0.09, 0, 0.0790026, 0) },
}

-- Reactive state
Functions.IsOpen = scope:Value(false)
Functions.CurrentGlazeTab = scope:Value(Functions.GlazeTabs.Color) -- Default to Color tab
Functions.CurrentStyleSection = scope:Value(Functions.StyleSections.Bowls) -- Default to Bowls section

Functions.SelectedColor = scope:Value(nil) -- Selected color name
Functions.SelectedPattern = scope:Value(nil) -- Selected pattern name
Functions.SelectedFinish = scope:Value(nil) -- Selected finish name

-- Track if selected pattern is style-unique
Functions.IsStyleUniquePattern = scope:Value(false)

-- Pottery item reference
Functions.PotteryItemKey = scope:Value(nil)
Functions.PotteryModel = scope:Value(nil)
Functions.PotteryStyleKey = scope:Value(nil)
Functions.ViewportModel = nil

-- Preview rotation state
Functions.PreviewRotationX = scope:Value(0)
Functions.PreviewRotationY = scope:Value(0)
Functions.IsDragging = scope:Value(false)
Functions.DragVelocityX = scope:Value(0)
Functions.DragVelocityY = scope:Value(0)
Functions.AutoRotateSpeed = 30
Functions.DragSensitivity = 0.5
Functions.VelocityDamping = 0.92
Functions.MaxTiltAngle = 45

-- Callbacks
Functions.OnSelect = nil
Functions.OnClose = nil

-- Computed: Check if selection is complete
Functions.IsSelectionComplete = scope:Computed(function(use)
    local color = use(Functions.SelectedColor)
    local pattern = use(Functions.SelectedPattern)
    local _finish = use(Functions.SelectedFinish)
    
    if not color then return false end
    if not pattern then return false end
    
    return true
end)

-- Animation springs
Functions.AnimatedPosition = scope:Spring(
    scope:Computed(function(use)
        return use(Functions.IsOpen) and Functions.OPEN_POSITION or Functions.CLOSED_POSITION
    end), 
    18, 0.7
)

Functions.AnimatedRotation = scope:Spring(
    scope:Computed(function(use)
        return use(Functions.IsOpen) and 0 or 15
    end), 
    20, 0.5
)

-- Animated section name color
Functions.SectionNameColor = scope:Spring(
    scope:Computed(function(use)
        local tab = use(Functions.CurrentGlazeTab)
        return Functions.TAB_COLORS[tab] or Color3.fromRGB(81, 159, 255)
    end),
    20, 0.6
)

-- Glaze tab icon animations (Color, Pattern, Finish tabs)
Functions.GlazeTabIconColors = {}
Functions.GlazeTabIconTransparencies = {}
Functions.GlazeTabIconTargetColors = {}
Functions.GlazeTabIconColorSpeeds = {}

for tabKey, tabColor in pairs(Functions.TAB_COLORS) do
    local isActive = scope:Computed(function(use)
        return use(Functions.CurrentGlazeTab) == tabKey
    end)
    
    Functions.GlazeTabIconTransparencies[tabKey] = scope:Spring(
        scope:Computed(function(use)
            return use(isActive) and 0 or 0.89
        end),
        15, 1
    )
    
    Functions.GlazeTabIconTargetColors[tabKey] = scope:Value(Color3.new(0, 0, 0))
    Functions.GlazeTabIconColorSpeeds[tabKey] = scope:Value(30)
    
    Functions.GlazeTabIconColors[tabKey] = scope:Spring(
        Functions.GlazeTabIconTargetColors[tabKey],
        scope:Computed(function(use)
            return use(Functions.GlazeTabIconColorSpeeds[tabKey])
        end),
        1
    )
    
    scope:Observer(isActive):onBind(function()
        local selected = peek(isActive)
        if selected then
            Functions.GlazeTabIconColorSpeeds[tabKey]:set(50)
            Functions.GlazeTabIconTargetColors[tabKey]:set(tabColor)
        else
            Functions.GlazeTabIconColorSpeeds[tabKey]:set(6)
            Functions.GlazeTabIconTargetColors[tabKey]:set(Color3.new(0, 0, 0))
        end
    end)
end

-- Select button state
Functions.SelectHovered = scope:Value(false)
Functions.SelectPressed = scope:Value(false)

Functions.SelectScale = scope:Spring(scope:Computed(function(use)
    if use(Functions.SelectPressed) then return 0.95 end
    if use(Functions.SelectHovered) then return 1.02 end
    return 1
end), 30, 0.7)

Functions.SelectButtonColor = scope:Spring(
    scope:Computed(function(use)
        if use(Functions.IsSelectionComplete) then
            return Color3.fromRGB(0, 227, 121) -- Green
        else
            return Color3.fromRGB(180, 180, 180) -- Grey
        end
    end),
    15, 0.7
)

-- Check if a pattern is style-unique
function Functions:IsPatternStyleUnique(patternName: string): boolean
    local styleKey = peek(Functions.PotteryStyleKey)
    if not styleKey or not patternName or patternName == "noPattern" then return false end
    
    -- First check Constants for style-unique patterns
    if SharedConstants.glazeTypes.uniquePatterns and SharedConstants.glazeTypes.uniquePatterns[styleKey] then
        local styleUniqueData = SharedConstants.glazeTypes.uniquePatterns[styleKey]
        if styleUniqueData.patterns then
            for _, patternData in ipairs(styleUniqueData.patterns) do
                if patternData.name == patternName then
                    return true
                end
            end
        end
    end
    
    -- Fallback: check Assets folder
    local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
    if not assetsFolder then return false end
    
    local glazesFolder = assetsFolder:FindFirstChild("Glazes")
    if not glazesFolder then return false end
    
    local styleUniqueFolder = glazesFolder:FindFirstChild("StyleUniquePatterns")
    if not styleUniqueFolder then return false end
    
    local styleFolder = styleUniqueFolder:FindFirstChild(styleKey)
    if not styleFolder then return false end
    
    return styleFolder:FindFirstChild(patternName) ~= nil
end

-- Get available finishes for a pattern
function Functions:GetAvailableFinishes(patternName: string): {string}
    local styleKey = peek(Functions.PotteryStyleKey)
    if not styleKey then return {} end
    
    -- First check Constants for style-unique pattern finishes
    if SharedConstants.glazeTypes.uniquePatterns and SharedConstants.glazeTypes.uniquePatterns[styleKey] then
        local styleUniqueData = SharedConstants.glazeTypes.uniquePatterns[styleKey]
        if styleUniqueData.patterns then
            for _, patternData in ipairs(styleUniqueData.patterns) do
                if patternData.name == patternName and patternData.finishes then
                    local finishes = {}
                    local finishesToCheck = patternData.finishes
                    if finishesToCheck.name then
                        -- Single finish object
                        table.insert(finishes, finishesToCheck.name)
                    else
                        -- Array of finishes
                        for _, finishData in ipairs(finishesToCheck) do
                            table.insert(finishes, finishData.name)
                        end
                    end
                    if #finishes > 0 then
                        return finishes
                    end
                end
            end
        end
    end
    
    -- Fallback: check Assets folder for SurfaceAppearance objects
    local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
    if assetsFolder then
        local glazesFolder = assetsFolder:FindFirstChild("Glazes")
        if glazesFolder then
            local styleUniqueFolder = glazesFolder:FindFirstChild("StyleUniquePatterns")
            if styleUniqueFolder then
                local styleFolder = styleUniqueFolder:FindFirstChild(styleKey)
                if styleFolder then
                    local patternFolder = styleFolder:FindFirstChild(patternName)
                    if patternFolder then
                        local finishes = {}
                        for _, child in ipairs(patternFolder:GetChildren()) do
                            if child:IsA("SurfaceAppearance") then
                                table.insert(finishes, child.Name:lower())
                            end
                        end
                        if #finishes > 0 then
                            return finishes
                        end
                    end
                end
            end
        end
    end
    
    return {"matte", "glossy", "metallic", "polished", "lustrous", "radiant"}
end

-- Get SurfaceAppearance for pattern + finish
function Functions:GetSurfaceAppearance(pattern: string, finish: string?): SurfaceAppearance?
    local styleKey = peek(Functions.PotteryStyleKey)
    
    if styleKey and pattern and pattern ~= "noPattern" then
        local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
        if assetsFolder then
            local glazesFolder = assetsFolder:FindFirstChild("Glazes")
            if glazesFolder then
                local styleUniqueFolder = glazesFolder:FindFirstChild("StyleUniquePatterns")
                if styleUniqueFolder then
                    local styleFolder = styleUniqueFolder:FindFirstChild(styleKey)
                    if styleFolder then
                        local patternFolder = styleFolder:FindFirstChild(pattern)
                        if patternFolder and finish then
                            local finishName = finish:sub(1,1):upper() .. finish:sub(2)
                            local sa = patternFolder:FindFirstChild(finishName)
                            if sa then return sa end
                        end
                    end
                end
            end
        end
    end
    
    if not pattern or pattern == "noPattern" then
        if not finish then return nil end
        
        local glazesFolder = ReplicatedStorage:FindFirstChild("Assets")
        if not glazesFolder then return nil end
        glazesFolder = glazesFolder:FindFirstChild("Glazes")
        if not glazesFolder then return nil end
        
        local patternFolder = glazesFolder:FindFirstChild("noPattern")
        if not patternFolder then return nil end
        
        local finishName = finish:sub(1,1):upper() .. finish:sub(2)
        return patternFolder:FindFirstChild(finishName)
    end
    
    local glazesFolder = ReplicatedStorage:FindFirstChild("Assets")
    if not glazesFolder then return nil end
    glazesFolder = glazesFolder:FindFirstChild("Glazes")
    if not glazesFolder then return nil end
    
    local patternFolder = glazesFolder:FindFirstChild(pattern)
    if not patternFolder then return nil end
    
    if not finish then return nil end
    
    local finishName = finish:sub(1,1):upper() .. finish:sub(2)
    return patternFolder:FindFirstChild(finishName)
end

-- Get color data by name
function Functions:GetColorData(colorName: string)
    for _, colorData in ipairs(SharedConstants.glazeTypes.colors) do
        if colorData.name == colorName then
            return colorData
        end
    end
    return nil
end

-- Get pattern data by name
function Functions:GetPatternData(patternName: string)
    for _, patternData in ipairs(SharedConstants.glazeTypes.patterns) do
        if patternData.name == patternName then
            return patternData
        end
    end
    return nil
end

-- Get finish data by name
function Functions:GetFinishData(finishName: string)
    for _, finishData in ipairs(SharedConstants.glazeTypes.finishes) do
        if finishData.name == finishName then
            return finishData
        end
    end
    return nil
end

-- Apply glaze to model
function Functions:ApplyGlazeToModel(object: Model | BasePart, color: Color3?, pattern: string?, finish: string?)
    if not object then return end
    
    local surfaceAppearance = self:GetSurfaceAppearance(pattern, finish)
    
    local function applyToPart(part: BasePart)
        if color then
            part.Color = color
        end
        
        for _, child in ipairs(part:GetChildren()) do
            if child:IsA("SurfaceAppearance") then
                child:Destroy()
            end
        end
        
        if surfaceAppearance then
            local clone = surfaceAppearance:Clone()
            clone.Parent = part
        end
    end
    
    if object:IsA("Model") then
        for _, part in ipairs(object:GetDescendants()) do
            if part:IsA("BasePart") then
                applyToPart(part)
            end
        end
    elseif object:IsA("BasePart") then
        applyToPart(object)
    end
end

-- Update viewport preview
function Functions:UpdateViewportPreview()
    local model = Functions.ViewportModel
    if not model then return end
    
    local colorName = peek(Functions.SelectedColor)
    local patternName = peek(Functions.SelectedPattern)
    local finishName = peek(Functions.SelectedFinish)
    
    local color = nil
    if colorName then
        local colorData = self:GetColorData(colorName)
        if colorData then
            color = colorData.color
        end
    end
    
    self:ApplyGlazeToModel(model, color, patternName, finishName)
end

-- Set glaze tab
function Functions:SetGlazeTab(tab: string)
    Functions.CurrentGlazeTab:set(tab)
end

-- Set style section
function Functions:SetStyleSection(section: string)
    Functions.CurrentStyleSection:set(section)
end

-- Select a color
function Functions:SelectColor(colorName: string?)
    Functions.SelectedColor:set(colorName)
    self:UpdateViewportPreview()
end

-- Select a pattern
function Functions:SelectPattern(patternName: string)
    local previousPattern = peek(Functions.SelectedPattern)
    Functions.SelectedPattern:set(patternName)
    
    local isStyleUnique = self:IsPatternStyleUnique(patternName)
    Functions.IsStyleUniquePattern:set(isStyleUnique)
    
    local wasStyleUnique = self:IsPatternStyleUnique(previousPattern)
    if isStyleUnique ~= wasStyleUnique then
        Functions.SelectedFinish:set(nil)
    end
    
    self:UpdateViewportPreview()
end

-- Select a finish
function Functions:SelectFinish(finishName: string?)
    Functions.SelectedFinish:set(finishName)
    self:UpdateViewportPreview()
end

-- Rotate left
function Functions:RotateLeft()
    local current = peek(Functions.DragVelocityY)
    Functions.DragVelocityY:set(current - 200)
end

-- Rotate right
function Functions:RotateRight()
    local current = peek(Functions.DragVelocityY)
    Functions.DragVelocityY:set(current + 200)
end

-- Start dragging
function Functions:StartDrag()
    self.IsDragging:set(true)
end

-- Stop dragging
function Functions:StopDrag()
    self.IsDragging:set(false)
end

-- Get current selection
function Functions:GetSelection()
    return {
        color = peek(Functions.SelectedColor),
        pattern = peek(Functions.SelectedPattern),
        finish = peek(Functions.SelectedFinish),
    }
end

-- Confirm selection
function Functions:ConfirmSelection()
    if not peek(Functions.IsSelectionComplete) then
        return
    end
    
    local potteryItemKey = peek(Functions.PotteryItemKey)
    if not potteryItemKey then
        --warn("GlazeTable: No pottery item key set")
        return
    end
    
    local selection = self:GetSelection()
    
    GlazePottery:Call(potteryItemKey, selection):After(function(passed, result)
        if passed and result then
            if Functions.OnSelect then
                Functions.OnSelect(selection)
            end
            self:Close()
            -- Reset selections after successful submission
            Functions.SelectedColor:set(nil)
            Functions.SelectedPattern:set(nil)
            Functions.SelectedFinish:set(nil)
        else
            --warn("GlazeTable: Failed to apply glaze")
        end
    end)
end

-- Open
function Functions:Open()
    Functions.IsOpen:set(true)
end

-- Close
function Functions:Close()
    Functions.IsOpen:set(false)
    if Functions.OnClose then
        Functions.OnClose()
    end
end

-- Show the glaze table UI
function Functions:Show(potteryItemKey: string?, styleKey: string?, onSelect: ((selection: {color: string?, pattern: string?, finish: string?}) -> ())?, onClose: (() -> ())?)
    Functions.SelectedColor:set(nil)
    Functions.SelectedPattern:set(nil)
    Functions.SelectedFinish:set(nil)
    Functions.IsStyleUniquePattern:set(false)
    Functions.CurrentGlazeTab:set(Functions.GlazeTabs.Color)
    
    Functions.PreviewRotationX:set(0)
    Functions.PreviewRotationY:set(0)
    Functions.DragVelocityX:set(0)
    Functions.DragVelocityY:set(0)
    Functions.IsDragging:set(false)
    
    Functions.PotteryItemKey:set(potteryItemKey)
    Functions.PotteryStyleKey:set(styleKey)
    Functions.OnSelect = onSelect
    Functions.OnClose = onClose
    
    self:SetupViewport(styleKey)
    self:Open()
end

-- Setup viewport
function Functions:SetupViewport(styleKey: string?)
    task.defer(function()
        local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
        if not playerGui then return end
        
        local ui = playerGui:FindFirstChild("UI")
        if not ui then return end
        
        local glazeTable = ui:FindFirstChild("GlazeTable")
        if not glazeTable then return end
        
        local container = glazeTable:FindFirstChild("Container")
        if not container then return end
        
        local styleContainer = container:FindFirstChild("StyleContainer")
        if not styleContainer then return end
        
        local viewport = styleContainer:FindFirstChild("ViewportFrame")
        if not viewport then return end
        
        local camera = viewport:FindFirstChild("Camera")
        if camera then
            viewport.CurrentCamera = camera
        end
        
        for _, child in ipairs(viewport:GetChildren()) do
            if child:IsA("Model") or (child:IsA("BasePart") and child.Name ~= "Camera") then
                child:Destroy()
            end
        end
        
        if not styleKey then
            styleKey = "bowl"
        end
        
        local styleData = SharedConstants.pottteryData and SharedConstants.pottteryData[styleKey]
        if not styleData then return end
        
        local actualModelName = styleData.name or styleKey
        
        local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
        if not assetsFolder then return end
        
        local potteryStyles = assetsFolder:FindFirstChild("PotteryStyles")
        if not potteryStyles then return end
        
        local styleFolder = potteryStyles:FindFirstChild(actualModelName)
        if not styleFolder then return end
        
        local modelTemplate = styleFolder:FindFirstChild("Model")
        if not modelTemplate then return end
        
        local model = modelTemplate:Clone()
        model.Name = "PreviewModel"
        
        local cf = CFrame.new(0, 19.2, 17.728)
        if model:IsA("Model") and model.PrimaryPart then
            model:PivotTo(cf)
        elseif model:IsA("BasePart") then
            model.CFrame = cf
        end
        
        model.Parent = viewport
        
        Functions.ViewportModel = model
        self:UpdateViewportPreview()
    end)
end

-- Update model rotation
function Functions:UpdatePreviewModelRotation()
    local model = Functions.ViewportModel
    if not model then return end
    
    local rotationX = peek(self.PreviewRotationX)
    local rotationY = peek(self.PreviewRotationY)
    
    rotationX = math.clamp(rotationX, -self.MaxTiltAngle, self.MaxTiltAngle)
    
    local basePos = Vector3.new(0, 19.2, 17.728)
    
    if model:IsA("Model") then
        model:PivotTo(CFrame.new(basePos) * CFrame.Angles(math.rad(rotationX), math.rad(rotationY), 0))
    elseif model:IsA("BasePart") then
        model.CFrame = CFrame.new(basePos) * CFrame.Angles(math.rad(rotationX), math.rad(rotationY), 0)
    end
end

-- Hide
function Functions:Hide()
    self:Close()
end

-- IsVisible
function Functions:IsVisible(): boolean
    return peek(Functions.IsOpen)
end

-- Preview rotation update loop
local lastMouseX = 0
local lastMouseY = 0

RunService.RenderStepped:Connect(function(deltaTime)
    if not peek(Functions.IsOpen) then return end
    
    local isDragging = peek(Functions.IsDragging)
    local velocityX = peek(Functions.DragVelocityX)
    local velocityY = peek(Functions.DragVelocityY)
    local rotationX = peek(Functions.PreviewRotationX)
    local rotationY = peek(Functions.PreviewRotationY)
    
    if isDragging then
        local newRotationX = rotationX + velocityX * deltaTime
        local newRotationY = rotationY + velocityY * deltaTime
        Functions.PreviewRotationX:set(newRotationX)
        Functions.PreviewRotationY:set(newRotationY)
    else
        local hasXMomentum = math.abs(velocityX) > 1
        local hasYMomentum = math.abs(velocityY) > 1
        
        if hasXMomentum or hasYMomentum then
            local newVelocityX = velocityX * Functions.VelocityDamping
            local newVelocityY = velocityY * Functions.VelocityDamping
            Functions.DragVelocityX:set(newVelocityX)
            Functions.DragVelocityY:set(newVelocityY)
            
            local newRotationX = rotationX + newVelocityX * deltaTime
            local newRotationY = rotationY + newVelocityY * deltaTime
            Functions.PreviewRotationX:set(newRotationX)
            Functions.PreviewRotationY:set(newRotationY)
        else
            Functions.DragVelocityX:set(0)
            Functions.DragVelocityY:set(0)
            
            local newRotationX = rotationX * 0.95
            if math.abs(newRotationX) < 0.1 then newRotationX = 0 end
            Functions.PreviewRotationX:set(newRotationX)
            
            local newRotationY = rotationY + Functions.AutoRotateSpeed * deltaTime
            Functions.PreviewRotationY:set(newRotationY)
        end
    end
    
    Functions:UpdatePreviewModelRotation()
end)

-- Handle mouse movement
UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        if peek(Functions.IsDragging) and peek(Functions.IsOpen) then
            local deltaX = input.Position.X - lastMouseX
            local deltaY = input.Position.Y - lastMouseY
            
            local velocityY = deltaX * Functions.DragSensitivity * 60
            local velocityX = -deltaY * Functions.DragSensitivity * 30
            
            Functions.DragVelocityY:set(velocityY)
            Functions.DragVelocityX:set(velocityX)
        end
        lastMouseX = input.Position.X
        lastMouseY = input.Position.Y
    end
end)

return Functions
