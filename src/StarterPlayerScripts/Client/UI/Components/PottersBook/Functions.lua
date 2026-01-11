local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Client = Players.LocalPlayer.PlayerScripts.Client

local Fusion = require(Shared.Fusion)
local SharedConstants = require(Shared.Constants)

local peek = Fusion.peek

local Functions = {}

-- Create scope for reactive state
Functions.scope = Fusion.scoped(Fusion)
local scope = Functions.scope

-- Constants
Functions.SECTIONS = {"Bowls", "Plates", "Cups", "Vessels", "Sculptures", "Relics", "Limiteds"}
Functions.CLOSED_POSITION = UDim2.fromScale(0.5, 2)
Functions.OPEN_POSITION = UDim2.fromScale(0.5, 0.55)

-- Section icons mapping
Functions.SECTION_ICONS = {
    Bowls = "rbxassetid://74560426975999",
    Plates = "rbxassetid://81597431202934",
    Cups = "rbxassetid://81724621143682",
    Vessels = "rbxassetid://96317488518513",
    Sculptures = "rbxassetid://127198685412609",
    Relics = "rbxassetid://134400456438061",
    Limiteds = "rbxassetid://135533654534105",
}

-- Section colors
Functions.SECTION_COLORS = {
    Bowls = Color3.fromRGB(81, 159, 255),      -- Blue
    Plates = Color3.fromRGB(255, 166, 77),     -- Orange
    Cups = Color3.fromRGB(130, 212, 130),      -- Green
    Vessels = Color3.fromRGB(199, 130, 212),   -- Purple
    Sculptures = Color3.fromRGB(255, 130, 130),-- Red/Pink
    Relics = Color3.fromRGB(255, 215, 100),    -- Gold
    Limiteds = Color3.fromRGB(130, 230, 230),  -- Cyan
}

-- Reactive state
Functions.IsOpen = scope:Value(false)
Functions.CurrentSection = scope:Value("Bowls")
Functions.SelectedStyle = scope:Value(nil) -- Currently previewed style
Functions.ConfirmedStyle = scope:Value(nil) -- Style confirmed by clicking Select button

-- Preview rotation state (XYZ)
Functions.PreviewRotationX = scope:Value(0)
Functions.PreviewRotationY = scope:Value(0)
Functions.IsDragging = scope:Value(false)
Functions.DragVelocityX = scope:Value(0)
Functions.DragVelocityY = scope:Value(0)
Functions.AutoRotateSpeed = 30 -- degrees per second (Y axis)
Functions.DragSensitivity = 0.5
Functions.VelocityDamping = 0.92 -- How quickly velocity decays
Functions.MaxTiltAngle = 45 -- Max X rotation from drag

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

-- Exit button jiggle rotation
Functions.ExitButtonRotation = scope:Spring(
    scope:Computed(function(use)
        return use(Functions.IsOpen) and -15 or 0
    end),
    15, 0.5
)

-- Section name positions and sizes for each section
Functions.SECTION_NAME_DATA = {
    Bowls = { position = UDim2.fromScale(0.114, -0.064), size = UDim2.fromScale(0.062, 0.036) },
    Plates = { position = UDim2.fromScale(0.189, -0.064), size = UDim2.fromScale(0.062, 0.036) },
    Cups = { position = UDim2.fromScale(0.261, -0.064), size = UDim2.fromScale(0.046, 0.036) },
    Vessels = { position = UDim2.fromScale(0.343, -0.064), size = UDim2.fromScale(0.069, 0.036) },
    Sculptures = { position = UDim2.fromScale(0.42, -0.064), size = UDim2.fromScale(0.081, 0.036) },
    Relics = { position = UDim2.fromScale(0.493, -0.064), size = UDim2.fromScale(0.056, 0.036) },
    Limiteds = { position = UDim2.fromScale(0.572, -0.064), size = UDim2.fromScale(0.071, 0.036) },
}

-- Animated X position for section name label (hovers over selected icon)
Functions.SectionNameXPosition = scope:Spring(
    scope:Computed(function(use)
        local section = use(Functions.CurrentSection)
        local data = Functions.SECTION_NAME_DATA[section]
        return data and data.position.X.Scale or 0.114
    end),
    25, 0.8
)

-- Animated width for section name label
Functions.SectionNameWidth = scope:Spring(
    scope:Computed(function(use)
        local section = use(Functions.CurrentSection)
        local data = Functions.SECTION_NAME_DATA[section]
        return data and data.size.X.Scale or 0.062
    end),
    25, 0.8
)

-- Get pottery styles for a specific section
function Functions:GetStylesForSection(sectionName: string)
    local styles = {}
    
    -- Note: typo in constants is "pottteryData" (3 t's)
    if SharedConstants.pottteryData then
        for styleName, data in pairs(SharedConstants.pottteryData) do
            if data.sectionType == sectionName then
                table.insert(styles, {
                    key = styleName,
                    data = data,
                })
            end
        end
        
        table.sort(styles, function(a, b)
            return a.data.name < b.data.name
        end)
    end
    
    return styles
end

-- Get selected style data
function Functions:GetSelectedStyleData()
    local styleKey = peek(self.SelectedStyle)
    if not styleKey then return nil end
    if not SharedConstants.pottteryData then return nil end
    return SharedConstants.pottteryData[styleKey]
end

function Functions:Open()
    self.IsOpen:set(true)
end

function Functions:Close()
    self.IsOpen:set(false)
    self.SelectedStyle:set(nil)
end

function Functions:Toggle()
    if peek(self.IsOpen) then
        self:Close()
    else
        self:Open()
    end
end

function Functions:SetSection(sectionName: string)
    if table.find(self.SECTIONS, sectionName) then
        self.CurrentSection:set(sectionName)
    end
end

function Functions:SelectStyle(styleKey: string)
    self.SelectedStyle:set(styleKey)
end

function Functions:ConfirmStyle()
    local styleKey = peek(self.SelectedStyle)
    if styleKey then
        self.ConfirmedStyle:set(styleKey)
    end
end

-- Setup a viewport frame with a pottery model
function Functions:SetupViewportFrame(viewportFrame: ViewportFrame, modelName: string)
    if not viewportFrame or not modelName then return end
    
    -- Clear existing content
    for _, child in ipairs(viewportFrame:GetChildren()) do
        if child:IsA("Model") or child:IsA("Camera") or child:IsA("BasePart") then
            child:Destroy()
        end
    end
    
    -- Get the model name from pottery data (e.g., "Bowl" instead of "bowl")
    local styleData = SharedConstants.pottteryData and SharedConstants.pottteryData[modelName]
    local actualModelName = styleData and styleData.model or modelName
    
    local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
    if not assetsFolder then 
        self:CreatePlaceholderModel(viewportFrame, modelName)
        return 
    end
    
    local potteryStyles = assetsFolder:FindFirstChild("PotteryStyles")
    if not potteryStyles then 
        self:CreatePlaceholderModel(viewportFrame, modelName)
        return 
    end
    
    local modelTemplate = potteryStyles:FindFirstChild(actualModelName)
    if not modelTemplate then 
        self:CreatePlaceholderModel(viewportFrame, modelName)
        return 
    end
    
    local model = modelTemplate:Clone()
    model.Parent = viewportFrame
    
    local camera = Instance.new("Camera")
    camera.Parent = viewportFrame
    viewportFrame.CurrentCamera = camera
    
    -- Position camera at (0, 20, 20) looking down at -20 degrees
    local cameraPos = Vector3.new(0, 20, 20)
    -- Create camera CFrame: position at cameraPos, rotated -20 degrees on X axis
    camera.CFrame = CFrame.new(cameraPos) * CFrame.Angles(math.rad(-20), 0, 0)
end

-- Create a placeholder model when the actual model isn't found
function Functions:CreatePlaceholderModel(viewportFrame: ViewportFrame, modelName: string)
    local part = Instance.new("Part")
    part.Shape = Enum.PartType.Ball
    part.Size = Vector3.new(2, 2, 2)
    part.Position = Vector3.new(0, 0, 0)
    part.Anchored = true
    part.Color = Color3.fromRGB(180, 140, 100) -- Clay-like color
    part.Material = Enum.Material.SmoothPlastic
    part.Parent = viewportFrame
    
    local camera = Instance.new("Camera")
    camera.CFrame = CFrame.new(0, 20, 20) * CFrame.Angles(math.rad(-20), 0, 0)
    camera.Parent = viewportFrame
    viewportFrame.CurrentCamera = camera
end

-- Update section name container width based on text bounds
function Functions:UpdateSectionNameWidth(textLabel: TextLabel, containerFrame: Frame)
    if not textLabel or not containerFrame then return end
    
    local connection
    connection = textLabel:GetPropertyChangedSignal("TextBounds"):Connect(function()
        local textBounds = textLabel.TextBounds
        local padding = 20 -- Extra padding on each side
        local newWidth = textBounds.X + padding * 2
        
        -- Update container frame width
        containerFrame.Size = UDim2.new(0, newWidth, containerFrame.Size.Y.Scale, containerFrame.Size.Y.Offset)
    end)
    
    -- Initial update
    task.defer(function()
        local textBounds = textLabel.TextBounds
        local padding = 20
        local newWidth = textBounds.X + padding * 2
        containerFrame.Size = UDim2.new(0, newWidth, containerFrame.Size.Y.Scale, containerFrame.Size.Y.Offset)
    end)
    
    return connection
end

-- Update the large preview viewport when a style is selected
function Functions:StartPreviewUpdater()
    scope:Observer(self.SelectedStyle):onBind(function()
        local styleKey = peek(self.SelectedStyle)
        if not styleKey then return end
        
        task.defer(function()
            local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
            if not playerGui then return end
            
            local ui = playerGui:FindFirstChild("UI")
            if not ui then return end
            
            local pottersBook = ui:FindFirstChild("PottersBook")
            if not pottersBook then return end
            
            local container = pottersBook:FindFirstChild("Container")
            if not container then return end
            
            local stylePreview = container:FindFirstChild("StylePreview")
            if not stylePreview then return end
            
            local viewport = stylePreview:FindFirstChild("ViewportFrame")
            if viewport then
                self:SetupViewportFrame(viewport, styleKey)
            end
        end)
    end)
end

-- Initialize the preview updater
Functions:StartPreviewUpdater()

-- Preview rotation update loop
local lastMouseX = 0
local lastMouseY = 0

RunService.RenderStepped:Connect(function(deltaTime)
    local isDragging = peek(Functions.IsDragging)
    local velocityX = peek(Functions.DragVelocityX)
    local velocityY = peek(Functions.DragVelocityY)
    local rotationX = peek(Functions.PreviewRotationX)
    local rotationY = peek(Functions.PreviewRotationY)
    
    if isDragging then
        -- While dragging, apply drag velocity
        local newRotationX = rotationX + velocityX * deltaTime
        local newRotationY = rotationY + velocityY * deltaTime
        Functions.PreviewRotationX:set(newRotationX)
        Functions.PreviewRotationY:set(newRotationY)
    else
        -- Not dragging - apply velocity decay and auto-rotation
        local hasXMomentum = math.abs(velocityX) > 1
        local hasYMomentum = math.abs(velocityY) > 1
        
        if hasXMomentum or hasYMomentum then
            -- Still have momentum from drag
            local newVelocityX = velocityX * Functions.VelocityDamping
            local newVelocityY = velocityY * Functions.VelocityDamping
            Functions.DragVelocityX:set(newVelocityX)
            Functions.DragVelocityY:set(newVelocityY)
            
            local newRotationX = rotationX + newVelocityX * deltaTime
            local newRotationY = rotationY + newVelocityY * deltaTime
            Functions.PreviewRotationX:set(newRotationX)
            Functions.PreviewRotationY:set(newRotationY)
        else
            -- Smoothly return X to 0 and continue auto-rotate on Y
            Functions.DragVelocityX:set(0)
            Functions.DragVelocityY:set(0)
            
            -- Lerp X rotation back to 0
            local newRotationX = rotationX * 0.95
            if math.abs(newRotationX) < 0.1 then newRotationX = 0 end
            Functions.PreviewRotationX:set(newRotationX)
            
            -- Continue auto-rotate on Y
            local newRotationY = rotationY + Functions.AutoRotateSpeed * deltaTime
            Functions.PreviewRotationY:set(newRotationY)
        end
    end
    
    -- Update the model rotation in the viewport
    Functions:UpdatePreviewModelRotation()
end)

-- Handle mouse movement for drag rotation
UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        if peek(Functions.IsDragging) then
            local deltaX = input.Position.X - lastMouseX
            local deltaY = input.Position.Y - lastMouseY
            
            -- X mouse movement = Y rotation, Y mouse movement = X rotation (tilt)
            local velocityY = deltaX * Functions.DragSensitivity * 60
            local velocityX = -deltaY * Functions.DragSensitivity * 30 -- Less sensitive for tilt
            
            Functions.DragVelocityY:set(velocityY)
            Functions.DragVelocityX:set(velocityX)
        end
        lastMouseX = input.Position.X
        lastMouseY = input.Position.Y
    end
end)

-- Update the model rotation in preview viewport
function Functions:UpdatePreviewModelRotation()
    local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return end
    
    local ui = playerGui:FindFirstChild("UI")
    if not ui then return end
    
    local pottersBook = ui:FindFirstChild("PottersBook")
    if not pottersBook then return end
    
    local container = pottersBook:FindFirstChild("Container")
    if not container then return end
    
    local stylePreview = container:FindFirstChild("StylePreview")
    if not stylePreview then return end
    
    local viewport = stylePreview:FindFirstChild("ViewportFrame")
    if not viewport then return end
    
    local rotationX = peek(self.PreviewRotationX)
    local rotationY = peek(self.PreviewRotationY)
    
    -- Clamp X rotation for tilt
    rotationX = math.clamp(rotationX, -self.MaxTiltAngle, self.MaxTiltAngle)
    
    -- Find the model in the viewport and rotate it
    for _, child in ipairs(viewport:GetChildren()) do
        if child:IsA("Model") then
            local primaryPart = child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart")
            if primaryPart then
                local center = child:GetBoundingBox().Position
                child:PivotTo(CFrame.new(center) * CFrame.Angles(math.rad(rotationX), math.rad(rotationY), 0))
            end
        elseif child:IsA("BasePart") and child.Name ~= "Camera" then
            child.CFrame = CFrame.new(child.Position) * CFrame.Angles(math.rad(rotationX), math.rad(rotationY), 0)
        end
    end
end

-- Start dragging
function Functions:StartDrag()
    self.IsDragging:set(true)
end

-- Stop dragging
function Functions:StopDrag()
    self.IsDragging:set(false)
end

-- Rotate preview by amount (for button clicks)
function Functions:RotatePreview(degrees: number)
    local current = peek(self.PreviewRotation)
    self.DragVelocity:set(degrees * 3) -- Give it some momentum
end

return Functions