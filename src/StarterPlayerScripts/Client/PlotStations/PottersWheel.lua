local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Client = Players.LocalPlayer.PlayerScripts.Client

local PlotStation = require(Shared.PlotStation)
local ProximityPromptHandler = require(Client.ProximityPromptHandler)
local SharedConstants = require(Shared.Constants)
local Events = require(Shared.Events)
local Fusion = require(Shared.Fusion)
local Maid = require(Shared.Maid)
local ScriptUtils = require(Shared.ScriptUtils)
local Replication = require(Client.Replication)

-- Get PottersBook Functions module
local PottersBookFunctions = require(Client.UI.Components.PottersBook.Functions)
local ClayRequirementFunctions = require(Client.UI.Components.ClayRequirement.Functions)
local PotteryMinigameFunctions = require(Client.UI.Components.PotteryMinigame.Functions)

local InsertClay = Events.InsertClay
local SetPotteryStyle = Events.SetPotteryStyle
local CancelPottery = Events.CancelPottery
local CompletePottery = Events.CompletePottery
local UpdatePotteryShaping = Events.UpdatePotteryShaping
local peek = Fusion.peek
local Hydrate = Fusion.Hydrate
local Tween = Fusion.Tween
local Value = Fusion.Value
local scoped = Fusion.scoped

local PottersWheel = {}
PottersWheel.__index = PottersWheel
setmetatable(PottersWheel, PlotStation)

function PottersWheel.new(player: Player, stationModel: Model)
    local self = PlotStation.new(player, stationModel)
    setmetatable(self, PottersWheel)
    
    self.selectedStyle = nil
    self.previewModel = nil
    self.unformedClay = nil
    self.isInStyleSelection = false
    self.isInMinigame = false
    self.requiredClay = 0
    self.currentClay = 0
    
    -- UnformedClay final size at max clay (lerps from original to this)
    self.clayFinalSize = Vector3.new(1.324, 1.795, 1.411)
    self.clayFinalHeightOffset = 0.59
    
    -- Spring targets for smooth clay animation
    self.clayTargetSize = nil
    self.clayTargetHeight = 0
    self.clayCurrentSize = nil
    self.clayCurrentHeight = 0
    
    -- Maid for minigame cleanup
    self.minigameMaid = Maid.new()
    
    -- Maid for clay animation
    self.clayAnimationMaid = Maid.new()
    
    -- Maid for visual replication (all clients)
    self.visualMaid = Maid.new()
    
    -- Maid for replicated clay animation
    self.replicatedClayAnimationMaid = Maid.new()
    
    -- Maid for shaping/spinning animation
    self.shapingAnimationMaid = Maid.new()
    
    -- Maid for completion fade animation
    self.completionAnimationMaid = Maid.new()
    
    -- Maid for equipped item listener (during style selection)
    self.equippedItemMaid = Maid.new()
    
    -- Spin angle for shaping animation
    self.shapingSpinAngle = 0
    
    -- Spring targets for replicated clay animation
    self.replicatedClayTargetSize = nil
    self.replicatedClayTargetHeight = 0
    self.replicatedClayCurrentSize = nil
    self.replicatedClayCurrentHeight = 0
    
    -- Track if this client is the owner
    self.isOwner = self.ownerPlayer.UserId == self.player.UserId
    
    -- Only setup interaction for the owner
    if self.isOwner then
        self:SetupInteraction()
        self:SetupStyleSelectionListener()
    end
    
    return self
end

-- SetupVisuals is called from StationHandler for ALL clients (including non-owners)
-- This replicates the visual state (unformed clay, preview model) based on server attributes
-- Owner clients skip this since they manage their own visuals directly
function PottersWheel:SetupVisuals()
    -- Skip for owner - they manage their own visuals
    if self.isOwner then return end
    
    self.visualMaid:DoCleaning()
    
    local function updateVisuals()
        local styleKey = self.__attributes.PotteryStyle
        local insertedClay = self.__attributes.InsertedClay or 0
        local requiredClay = self.__attributes.RequiredClay or 0
        local isComplete = self.__attributes.PotteryComplete
        
        -- If no style selected, remove all visuals
        if not styleKey or styleKey == "" then
            self:StopShapingAnimation()
            self:RemovePreviewModelVisual()
            self:RemoveUnformedClayVisual()
            return
        end
        
        -- Get style data
        local styleData = SharedConstants.pottteryData and SharedConstants.pottteryData[styleKey]
        if not styleData then return end
        
        -- Place/update preview model
        local clayIsFull = insertedClay >= requiredClay
        self:PlacePreviewModelVisual(styleKey, styleData, clayIsFull, isComplete)
        
        -- Place/update unformed clay (hide if complete)
        if isComplete then
            self:RemoveUnformedClayVisual()
        else
            self:PlaceUnformedClayVisual(insertedClay, requiredClay, styleData)
        end
    end
    
    local function updateShapingState()
        local isShaping = self.__attributes.PotteryShaping
        local isComplete = self.__attributes.PotteryComplete
        
        if isComplete then
            -- Play completion fade animation for non-owners
            self:PlayReplicatedCompletionAnimation()
        elseif isShaping then
            -- Start spinning animation
            self:StartShapingAnimation()
        else
            -- Stop spinning
            self:StopShapingAnimation()
        end
    end
    
    -- Initial update
    updateVisuals()
    updateShapingState()
    
    -- Listen for attribute changes
    self.visualMaid:GiveTask(self.__attributeChanged.PotteryStyle:Connect(updateVisuals))
    self.visualMaid:GiveTask(self.__attributeChanged.InsertedClay:Connect(updateVisuals))
    self.visualMaid:GiveTask(self.__attributeChanged.RequiredClay:Connect(updateVisuals))
    self.visualMaid:GiveTask(self.__attributeChanged.PotteryShaping:Connect(updateShapingState))
    self.visualMaid:GiveTask(self.__attributeChanged.PotteryComplete:Connect(updateShapingState))
end

-- Visual-only methods for replication (separate from owner's interactive methods)
function PottersWheel:PlacePreviewModelVisual(styleKey: string, styleData: {name : string, clayType: string}, isClayFull: boolean, isComplete: boolean?)
    -- Remove existing if style changed
    if self.replicatedPreviewModel and self.replicatedPreviewStyleKey ~= styleKey then
        self:RemovePreviewModelVisual()
    end
    
    -- Create if doesn't exist
    if not self.replicatedPreviewModel then
        local modelName = styleData.name or styleKey
        local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
        if not assetsFolder then return end
        
        local potteryStyles = assetsFolder:FindFirstChild("PotteryStyles")
        if not potteryStyles then return end
        
        local modelTemplate = potteryStyles[modelName].Model
        if not modelTemplate then return end
        
        local model = modelTemplate:Clone()
        self.replicatedPreviewModel = model
        self.replicatedPreviewStyleKey = styleKey
        
        -- Colorize based on clay type
        self:ColorizePotteryStyle(model, styleData.clayType)
        
        -- Position on wheel
        local primaryPart = self.model.PrimaryPart
        local baseAttachment = primaryPart and primaryPart:FindFirstChild("Base")
        
        if baseAttachment then
            local modelRoot = model:FindFirstChild("Root")
            if modelRoot then
                local modelAttachment = modelRoot:FindFirstChild("Attachment")
                if modelAttachment then
                    local targetCFrame = baseAttachment.WorldCFrame
                    local attachmentOffset = modelAttachment.CFrame
                    model:PivotTo(targetCFrame * attachmentOffset:Inverse())
                else
                    model:PivotTo(baseAttachment.WorldCFrame)
                end
            else
                model:PivotTo(baseAttachment.WorldCFrame)
            end
        end
        
        model.Parent = self.model
    end
    
    -- Update transparency based on state:
    -- - Not full: 0.6 (preview)
    -- - Full but not complete: hidden (1.0) while shaping
    -- - Complete: fully visible (0)
    local targetTransparency
    if isComplete then
        targetTransparency = 0 -- Fully visible when complete
    elseif isClayFull then
        targetTransparency = 1 -- Hidden during shaping
    else
        targetTransparency = 0.6 -- Preview transparency
    end
    
    for _, descendant in ipairs(self.replicatedPreviewModel:GetDescendants()) do
        if descendant:IsA("BasePart") then
            descendant.Transparency = targetTransparency
            descendant.CanCollide = false
        end
    end
end

function PottersWheel:RemovePreviewModelVisual()
    if self.replicatedPreviewModel then
        self.replicatedPreviewModel:Destroy()
        self.replicatedPreviewModel = nil
        self.replicatedPreviewStyleKey = nil
    end
end

function PottersWheel:PlaceUnformedClayVisual(insertedClay: number, requiredClay: number, styleData: {clayType : string})
    if requiredClay <= 0 then return end
    -- Create unformed clay if doesn't exist
    if not self.replicatedUnformedClay then
        local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
        if not assetsFolder then return end
        
        local gameObjects = assetsFolder:FindFirstChild("GameObjects")
        if not gameObjects then return end
        
        local unformedClayTemplate = gameObjects:FindFirstChild("UnformedClay")
        if not unformedClayTemplate then return end
        
        local clay = unformedClayTemplate:Clone()
        self.replicatedUnformedClay = clay

        self:ColorizePotteryStyle(clay, styleData.clayType)
        
        -- Store original size
        if clay:IsA("BasePart") then
            self.replicatedClayOriginalSize = clay.Size
        elseif clay:IsA("Model") and clay.PrimaryPart then
            self.replicatedClayOriginalSize = clay.PrimaryPart.Size
        end
        
        clay.Parent = self.model
    end
    
    -- Calculate target size based on progress
    local progress = math.clamp(insertedClay / requiredClay, 0, 1)
    local originalSize = self.replicatedClayOriginalSize or Vector3.new(1, 1, 1)
    
    -- Set spring targets
    self.replicatedClayTargetSize = originalSize:Lerp(self.clayFinalSize, progress)
    self.replicatedClayTargetHeight = self.clayFinalHeightOffset * progress
    
    -- Initialize current values if not set
    if not self.replicatedClayCurrentSize then
        self.replicatedClayCurrentSize = originalSize
        self.replicatedClayCurrentHeight = 0
    end
    
    -- Start spring animation
    self:StartReplicatedClayAnimation()
end

function PottersWheel:StartReplicatedClayAnimation()
    -- Don't restart if already running
    if self.replicatedClayAnimationRunning then return end
    
    self.replicatedClayAnimationRunning = true
    self.replicatedClayAnimationMaid:DoCleaning()
    
    self.replicatedClayAnimationMaid:GiveTask(RunService.RenderStepped:Connect(function(dt)
        if not self.replicatedUnformedClay then return end
        if not self.replicatedClayTargetSize then return end
        
        -- Spring the size and height
        local springSpeed = 8
        local alpha = 1 - math.exp(-springSpeed * dt)
        
        self.replicatedClayCurrentSize = self.replicatedClayCurrentSize:Lerp(self.replicatedClayTargetSize, alpha)
        self.replicatedClayCurrentHeight = self.replicatedClayCurrentHeight + (self.replicatedClayTargetHeight - self.replicatedClayCurrentHeight) * alpha
        
        -- Get base position
        local primaryPart = self.model.PrimaryPart
        local baseAttachment = primaryPart and primaryPart:FindFirstChild("Base")
        if not baseAttachment then return end
        
        local baseCFrame = baseAttachment.WorldCFrame
        local newCFrame = baseCFrame + Vector3.new(0, self.replicatedClayCurrentHeight, 0)
        
        if self.replicatedUnformedClay:IsA("BasePart") then
            self.replicatedUnformedClay.Size = self.replicatedClayCurrentSize
            self.replicatedUnformedClay.CFrame = newCFrame
        elseif self.replicatedUnformedClay:IsA("Model") and self.replicatedUnformedClay.PrimaryPart then
            self.replicatedUnformedClay:PivotTo(newCFrame)
        end
    end))
end

function PottersWheel:RemoveUnformedClayVisual()
    self.replicatedClayAnimationMaid:DoCleaning()
    self.replicatedClayAnimationRunning = false
    
    if self.replicatedUnformedClay then
        self.replicatedUnformedClay:Destroy()
        self.replicatedUnformedClay = nil
        self.replicatedClayOriginalSize = nil
    end
    
    self.replicatedClayTargetSize = nil
    self.replicatedClayCurrentSize = nil
    self.replicatedClayTargetHeight = 0
    self.replicatedClayCurrentHeight = 0
end

-- Shaping animation (spinning the clay and preview model)
function PottersWheel:StartShapingAnimation()
    -- Stop the clay spring animation to prevent position conflicts
    self.replicatedClayAnimationMaid:DoCleaning()
    self.replicatedClayAnimationRunning = false
    
    -- Don't restart if already running
    if self.shapingAnimationRunning then return end
    self.shapingAnimationRunning = true
    
    self.shapingAnimationMaid:DoCleaning()
    self.shapingSpinAngle = 0
    
    -- Get base attachment
    local primaryPart = self.model.PrimaryPart
    local baseAttachment = primaryPart and primaryPart:FindFirstChild("Base")
    if not baseAttachment then return end
    
    self.shapingAnimationMaid:GiveTask(RunService.RenderStepped:Connect(function(dt)
        -- Spin speed (radians per second)
        local spinSpeed = 90
        self.shapingSpinAngle = self.shapingSpinAngle + spinSpeed * dt
        
        local rotationCFrame = CFrame.Angles(0, self.shapingSpinAngle, 0)
        local baseCFrame = baseAttachment.WorldCFrame
        
        -- Get clay height
        local clayHeight = self.replicatedClayCurrentHeight or self.clayFinalHeightOffset
        
        -- Spin the unformed clay
        if self.replicatedUnformedClay then
            local clayNewCFrame = baseCFrame * CFrame.new(0, clayHeight, 0) * rotationCFrame
            
            if self.replicatedUnformedClay:IsA("BasePart") then
                self.replicatedUnformedClay.CFrame = clayNewCFrame
            elseif self.replicatedUnformedClay:IsA("Model") then
                self.replicatedUnformedClay:PivotTo(clayNewCFrame)
            end
        end
        
        -- Spin the preview model (using its attachment offset)
        if self.replicatedPreviewModel then
            local previewBaseCFrame = baseCFrame * rotationCFrame
            local previewCFrame = previewBaseCFrame
            
            local modelRoot = self.replicatedPreviewModel:FindFirstChild("Root")
            if modelRoot then
                local modelAttachment = modelRoot:FindFirstChild("Attachment")
                if modelAttachment then
                    previewCFrame = previewBaseCFrame * modelAttachment.CFrame:Inverse()
                end
            end
            
            self.replicatedPreviewModel:PivotTo(previewCFrame)
        end
    end))
end

function PottersWheel:StopShapingAnimation()
    self.shapingAnimationMaid:DoCleaning()
    self.shapingAnimationRunning = false
    self.shapingSpinAngle = 0
end

-- Completion fade animation for non-owners (replicated visuals)
function PottersWheel:PlayReplicatedCompletionAnimation()
    self.completionAnimationMaid:DoCleaning()
    
    local duration = 1.0 -- 1 second fade
    local startTime = tick()
    
    -- Get starting transparencies
    local clayStartTransparency = 0
    local previewStartTransparency = 1 -- Hidden during shaping
    
    -- Get base attachment for spinning
    local primaryPart = self.model.PrimaryPart
    local baseAttachment = primaryPart and primaryPart:FindFirstChild("Base")
    local clayHeight = self.replicatedClayCurrentHeight or self.clayFinalHeightOffset
    
    self.completionAnimationMaid:GiveTask(RunService.RenderStepped:Connect(function(dt)
        local elapsed = tick() - startTime
        local progress = math.clamp(elapsed / duration, 0, 1)
        
        -- Ease out for smoother feel
        local easedProgress = 1 - math.pow(1 - progress, 2)
        
        -- Continue spinning
        local spinSpeed = 6
        self.shapingSpinAngle = self.shapingSpinAngle + spinSpeed * dt
        local rotationCFrame = CFrame.Angles(0, self.shapingSpinAngle, 0)
        
        -- Fade out unformed clay (0 -> 1 transparency)
        if self.replicatedUnformedClay then
            local clayTransparency = clayStartTransparency + (1 - clayStartTransparency) * easedProgress
            
            if baseAttachment then
                local baseCFrame = baseAttachment.WorldCFrame
                local clayNewCFrame = baseCFrame * CFrame.new(0, clayHeight, 0) * rotationCFrame
                
                if self.replicatedUnformedClay:IsA("BasePart") then
                    self.replicatedUnformedClay.Transparency = clayTransparency
                    self.replicatedUnformedClay.CFrame = clayNewCFrame
                elseif self.replicatedUnformedClay:IsA("Model") then
                    self.replicatedUnformedClay:PivotTo(clayNewCFrame)
                    for _, part in ipairs(self.replicatedUnformedClay:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.Transparency = clayTransparency
                        end
                    end
                end
            end
        end
        
        -- Fade in preview model (1 -> 0 transparency)
        if self.replicatedPreviewModel then
            local previewTransparency = previewStartTransparency - previewStartTransparency * easedProgress
            
            if baseAttachment then
                local baseCFrame = baseAttachment.WorldCFrame
                local previewBaseCFrame = baseCFrame * rotationCFrame
                local previewCFrame = previewBaseCFrame
                
                local modelRoot = self.replicatedPreviewModel:FindFirstChild("Root")
                if modelRoot then
                    local modelAttachment = modelRoot:FindFirstChild("Attachment")
                    if modelAttachment then
                        previewCFrame = previewBaseCFrame * modelAttachment.CFrame:Inverse()
                    end
                end
                
                self.replicatedPreviewModel:PivotTo(previewCFrame)
            end
            
            for _, part in ipairs(self.replicatedPreviewModel:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Transparency = previewTransparency
                end
            end
        end
        
        -- Check if animation is complete
        if progress >= 1 then
            self.completionAnimationMaid:DoCleaning()
            self:StopShapingAnimation()
            -- Clean up after animation
            self:RemoveUnformedClayVisual()
        end
    end))
end

function PottersWheel:SetupInteraction()
    local interactPart = self.model:WaitForChild("ImportantObjects"):WaitForChild("StationRoot"):WaitForChild("Interact")
    self.interactPart = interactPart -- Store for later use
    
    self.createPrompt = ProximityPromptHandler.new(interactPart, {
        actionText = "Create Pottery",
        objectText = "Potter's Wheel (Lvl " .. self.data.level .. ")",
        priority = 1,
        onTriggered = function(player)
            self:OnTriggered(player)
        end,
        onPromptHidden = function(player)
            self:OnPromptHidden(player)
        end,
    })
    
    self.upgradePrompt = ProximityPromptHandler.new(interactPart, {
        actionText = "Upgrade",
        objectText = "Potter's Wheel (Lvl " .. self.data.level .. ")",
        simple = true,
        left = true,
        priority = 1,
        onTriggered = function(player)
            self:OnUpgradeTriggered(player)
        end,
    })
    
    -- Style selection prompts (hidden by default)
    self.cancelPrompt = ProximityPromptHandler.new(interactPart, {
        actionText = "Cancel",
        objectText = "",
        simple = true,
        left = true,
        priority = 1, -- Lower priority = R key
        onTriggered = function(player)
            self:OnCancelStyleSelection(player)
        end,
    })
    self.cancelPrompt:SetEnabled(false)
    
    self.insertClayPrompt = ProximityPromptHandler.new(interactPart, {
        actionText = "Insert Clay",
        objectText = "",
        simple = true,
        left = false,
        priority = 3,
        onTriggered = function(player)
            self:OnInsertClay(player)
        end,
    })
    self.insertClayPrompt:SetEnabled(false)
    
    -- Shape prompt (shown when clay requirements are met, starts minigame)
    self.shapePrompt = ProximityPromptHandler.new(interactPart, {
        actionText = "Shape",
        objectText = "",
        simple = true,
        left = false,
        priority = 2, -- Higher priority = E key
        customHorizontalOffset = -0.75,
        onTriggered = function(player)
            self:StartMinigame(player)
        end,
        onPromptHidden = function(player)
            -- If player walks away while shape prompt is showing, exit minigame prep
            -- BUT only if clay is NOT complete (don't clean up finished clay)
            if self.isInStyleSelection and not self.isInMinigame then
                if self.currentClay < self.requiredClay then
                    self:ExitStyleSelection()
                end
            end
        end,
    })
    self.shapePrompt:SetEnabled(false)
end

function PottersWheel:SetupStyleSelectionListener()
    -- Listen for style CONFIRMATION (when user clicks Select button) not just selection
    PottersBookFunctions.scope:Observer(PottersBookFunctions.ConfirmedStyle):onBind(function()
        local styleKey = peek(PottersBookFunctions.ConfirmedStyle)
        
        if styleKey then
            -- Defer to break the reactive cycle
            task.defer(function()
                self:OnStyleSelected(styleKey)
                -- Reset confirmed style after handling
                PottersBookFunctions.ConfirmedStyle:set(nil)
            end)
        end
    end)
end

-- Check if the player is holding the correct clay type for the selected style
function PottersWheel:IsHoldingCorrectClay()
    if not self.selectedStyle then return false end
    
    -- Get style data to check required clay type
    local styleData = SharedConstants.pottteryData and SharedConstants.pottteryData[self.selectedStyle]
    if not styleData then return false end
    
    local requiredClayType = styleData.clayType or "normal"
    
    -- Get currently equipped item
    local states = Replication:GetInfo("States", true)
    if not states then return false end
    
    local equippedItem = states.Data.equippedItem
    if not equippedItem then return false end
    
    -- equippedItem is a table with itemName property
    local itemName = equippedItem.itemName
    if not itemName then return false end
    
    -- Check if it's clay and matches the required type
    local itemData = SharedConstants.itemData and SharedConstants.itemData[itemName]
    if not itemData or itemData.itemType ~= "clay" then return false end
    
    local heldClayType = itemData.clayType or "normal"
    return heldClayType == requiredClayType
end

-- Update prompt visibility based on held item
function PottersWheel:UpdatePromptsForEquippedItem()
    if not self.isInStyleSelection then return end
    
    -- Don't show prompts during minigame or completion animation
    if self.isInMinigame or self.isCompleting then return end
    
    local holdingCorrectClay = self:IsHoldingCorrectClay()
    
    -- Insert clay prompt should only show if:
    -- 1. Clay is not full yet
    -- 2. Player is holding the correct clay type
    if self.currentClay < self.requiredClay then
        self.insertClayPrompt:SetEnabled(holdingCorrectClay)
    end
    
    -- Shape prompt should always show when clay is full (no need to hold clay)
    if self.currentClay >= self.requiredClay then
        self.shapePrompt:SetEnabled(true)
    end
end

-- Start listening for equipped item changes
function PottersWheel:StartEquippedItemListener()
    self.equippedItemMaid:DoCleaning()
    
    local states = Replication:GetInfo("States", true)
    if not states then return end
    
    -- Listen for equipped item changes
    self.equippedItemMaid:GiveTask(states:OnSet({"equippedItem"}, function()
        self:UpdatePromptsForEquippedItem()
    end))
    
    -- Update prompts immediately based on current equipped item
    self:UpdatePromptsForEquippedItem()
end

-- Stop listening for equipped item changes
function PottersWheel:StopEquippedItemListener()
    self.equippedItemMaid:DoCleaning()
end

function PottersWheel:OnStyleSelected(styleKey: string)
    -- Get style data
    local styleData = SharedConstants.pottteryData and SharedConstants.pottteryData[styleKey]
    if not styleData then
        warn("PottersWheel: Style data not found for", styleKey)
        return
    end
    
    self.selectedStyle = styleKey
    self.isInStyleSelection = true
    
    -- Close the PottersBook UI
    PottersBookFunctions:Close()
    
    -- Hide default prompts
    self.createPrompt:SetEnabled(false)
    self.upgradePrompt:SetEnabled(false)
    
    -- Show cancel prompt (always available)
    self.cancelPrompt:SetEnabled(true)
    -- Insert clay prompt is controlled by equipped item listener
    self.insertClayPrompt:SetEnabled(false)
    
    -- Show clay requirement UI (pass the interact part as adornee and the prompts to adjust)
    local clayCost = styleData.cost and styleData.cost.clay or 0
    self.requiredClay = clayCost
    self.currentClay = 0
    ClayRequirementFunctions:Show(clayCost, "normal", self.interactPart, {self.cancelPrompt, self.insertClayPrompt})
    ClayRequirementFunctions:UpdateCurrentClay(0)
    
    -- Tell server to set pottery style attributes (for visual replication)
    local stationId = self.model:GetAttribute("StationId") or self.model.Name
    SetPotteryStyle:Call(stationId, styleKey, clayCost)
    
    -- Place preview model on the wheel (hidden initially)
    self:PlacePreviewModel(styleKey, styleData)
    
    -- Place unformed clay on the wheel (pass clay type for colorization)
    self:PlaceUnformedClay(styleData.clayType)
    
    -- Start listening for equipped item changes to show/hide prompts
    self:StartEquippedItemListener()
end

function PottersWheel:PlacePreviewModel(styleKey: string, styleData: {name : string, clayType : string})
    -- Remove existing preview model
    self:RemovePreviewModel()
    
    -- Get model from ReplicatedStorage
    local modelName = styleData.name or styleKey
    local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
    if not assetsFolder then
        warn("PottersWheel: Assets folder not found")
        return
    end
    
    local potteryStyles = assetsFolder:FindFirstChild("PotteryStyles")
    if not potteryStyles then
        warn("PottersWheel: PotteryStyles folder not found")
        return
    end
    
    local modelTemplate = potteryStyles[modelName].Model
    if not modelTemplate then
        warn("PottersWheel: Model not found:", modelName)
        return
    end
    
    -- Clone the model
    local model = modelTemplate:Clone()
    model.Name = "_PreviewModel"
    self.previewModel = model

    self:ColorizePotteryStyle(model, styleData.clayType)
    
    -- Set all BaseParts to 0.6 transparency (preview state)
    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("BasePart") then
            descendant.Transparency = 0.6
            descendant.CanCollide = false
        end
    end
    
    -- Get the base attachment from the PottersWheel
    local primaryPart = self.model.PrimaryPart
    local baseAttachment = primaryPart:FindFirstChild("Base")

    -- Get the model's root attachment
    local modelRoot = model:FindFirstChild("Root")
    if modelRoot then
        local modelAttachment = modelRoot:FindFirstChild("Attachment")
        if modelAttachment then
            -- Align model's attachment to wheel's base attachment
            local targetCFrame = baseAttachment.WorldCFrame
            local attachmentOffset = modelAttachment.CFrame
            model:PivotTo(targetCFrame * attachmentOffset:Inverse())
        else
            -- No attachment, just position at base
            model:PivotTo(baseAttachment.WorldCFrame)
        end
    else
        -- No Root part, just position at base
        model:PivotTo(baseAttachment.WorldCFrame)
    end
    
    -- Parent the model to the PottersWheel (only once, at the end)
    model.Parent = self.model
end

function PottersWheel:RemovePreviewModel()
    -- Clean up tracked preview model
    if self.previewModel then
        self.previewModel:Destroy()
        self.previewModel = nil
    end
    
    -- Also clean up any orphaned preview models in the station
    local existingPreview = self.model:FindFirstChild("_PreviewModel")
    if existingPreview then
        existingPreview:Destroy()
    end
end

function PottersWheel:PlaceUnformedClay(clayType: string?)
    self:RemoveUnformedClay()
    
    -- Get UnformedClay from ReplicatedStorage
    local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
    if not assetsFolder then return end
    
    local gameObjects = assetsFolder:FindFirstChild("GameObjects")
    if not gameObjects then return end
    
    local unformedClayTemplate = gameObjects:FindFirstChild("UnformedClay")
    if not unformedClayTemplate then
        warn("PottersWheel: UnformedClay not found in Assets/GameObjects")
        return
    end
    
    -- Clone the unformed clay
    local clay = unformedClayTemplate:Clone()
    clay.Name = "_UnformedClay"
    self.unformedClay = clay
    
    -- Colorize based on clay type
    if clayType then
        self:ColorizePotteryStyle(clay, clayType)
    end
    
    -- Store original size and position for scaling
    if clay:IsA("BasePart") then
        self.clayOriginalSize = clay.Size
    elseif clay:IsA("Model") and clay.PrimaryPart then
        self.clayOriginalSize = clay.PrimaryPart.Size
    end
    
    -- Get the base attachment from the PottersWheel
    local primaryPart = self.model.PrimaryPart
    local baseAttachment = primaryPart and primaryPart:FindFirstChild("Base")
    
    if baseAttachment then
        if clay:IsA("BasePart") then
            clay.CFrame = baseAttachment.WorldCFrame
        elseif clay:IsA("Model") then
            clay:PivotTo(baseAttachment.WorldCFrame)
        end
    end
    
    clay.Parent = self.model
    
    -- Update to initial state (0 clay)
    self:UpdateUnformedClay(0)
end

function PottersWheel:UpdateUnformedClay(currentClay: number)
    if not self.unformedClay then return end
    if self.requiredClay <= 0 then return end
    
    local progress = math.clamp(currentClay / self.requiredClay, 0, 1)
    
    -- Lerp from original size TO final size (not adding offset)
    local originalSize = self.clayOriginalSize or Vector3.new(1, 1, 1)
    self.clayTargetSize = originalSize:Lerp(self.clayFinalSize, progress)
    self.clayTargetHeight = self.clayFinalHeightOffset * progress
    
    -- Initialize current values if not set
    if not self.clayCurrentSize then
        self.clayCurrentSize = originalSize
        self.clayCurrentHeight = 0
    end
    
    -- Start spring animation if not already running
    self:StartClayAnimation()
end

function PottersWheel:StartClayAnimation()
    -- Clean up existing animation
    self.clayAnimationMaid:DoCleaning()
    
    self.clayAnimationMaid:GiveTask(RunService.RenderStepped:Connect(function(dt)
        if not self.unformedClay then return end
        if not self.clayTargetSize then return end
        
        -- Spring the size and height
        local springSpeed = 8
        local alpha = 1 - math.exp(-springSpeed * dt)
        
        self.clayCurrentSize = self.clayCurrentSize:Lerp(self.clayTargetSize, alpha)
        self.clayCurrentHeight = self.clayCurrentHeight + (self.clayTargetHeight - self.clayCurrentHeight) * alpha
        
        -- Get base position
        local primaryPart = self.model.PrimaryPart
        local baseAttachment = primaryPart and primaryPart:FindFirstChild("Base")
        if not baseAttachment then return end
        
        local baseCFrame = baseAttachment.WorldCFrame
        local newCFrame = baseCFrame + Vector3.new(0, self.clayCurrentHeight, 0)
        
        if self.unformedClay:IsA("BasePart") then
            self.unformedClay.Size = self.clayCurrentSize
            self.unformedClay.CFrame = newCFrame
        elseif self.unformedClay:IsA("Model") and self.unformedClay.PrimaryPart then
            self.unformedClay:PivotTo(newCFrame)
        end
    end))
end

function PottersWheel:RemoveUnformedClay()
    self.clayAnimationMaid:DoCleaning()
    
    -- Clean up tracked unformed clay
    if self.unformedClay then
        self.unformedClay:Destroy()
        self.unformedClay = nil
    end
    
    -- Also clean up any orphaned unformed clay in the station
    local existingClay = self.model:FindFirstChild("_UnformedClay")
    if existingClay then
        existingClay:Destroy()
    end
    
    self.clayTargetSize = nil
    self.clayCurrentSize = nil
    self.clayTargetHeight = 0
    self.clayCurrentHeight = 0
end

-- Owner's shaping animation (spinning during minigame)
function PottersWheel:StartOwnerShapingAnimation()
    -- Stop the clay spring animation to prevent position conflicts
    self.clayAnimationMaid:DoCleaning()
    
    -- Don't restart if already running
    if self.ownerShapingAnimationRunning then return end
    self.ownerShapingAnimationRunning = true
    
    self.shapingAnimationMaid:DoCleaning()
    self.shapingSpinAngle = 0
    
    -- Get base attachment
    local primaryPart = self.model.PrimaryPart
    local baseAttachment = primaryPart and primaryPart:FindFirstChild("Base")
    if not baseAttachment then return end
    
    -- Get the final clay height
    local clayHeight = self.clayCurrentHeight or self.clayFinalHeightOffset
    
    self.shapingAnimationMaid:GiveTask(RunService.RenderStepped:Connect(function(dt)
        -- Spin speed (radians per second)
        local spinSpeed = 6
        self.shapingSpinAngle = self.shapingSpinAngle + spinSpeed * dt
        
        local rotationCFrame = CFrame.Angles(0, self.shapingSpinAngle, 0)
        local baseCFrame = baseAttachment.WorldCFrame
        
        -- Spin the unformed clay
        if self.unformedClay then
            local clayNewCFrame = baseCFrame * CFrame.new(0, clayHeight, 0) * rotationCFrame
            
            if self.unformedClay:IsA("BasePart") then
                self.unformedClay.CFrame = clayNewCFrame
            elseif self.unformedClay:IsA("Model") then
                self.unformedClay:PivotTo(clayNewCFrame)
            end
        end
        
        -- Spin the preview model (using its attachment offset)
        if self.previewModel then
            local previewBaseCFrame = baseCFrame * rotationCFrame
            local previewCFrame = previewBaseCFrame
            
            local modelRoot = self.previewModel:FindFirstChild("Root")
            if modelRoot then
                local modelAttachment = modelRoot:FindFirstChild("Attachment")
                if modelAttachment then
                    previewCFrame = previewBaseCFrame * modelAttachment.CFrame:Inverse()
                end
            end
            
            self.previewModel:PivotTo(previewCFrame)
        end
    end))
end

function PottersWheel:StopOwnerShapingAnimation()
    self.shapingAnimationMaid:DoCleaning()
    self.ownerShapingAnimationRunning = false
    self.shapingSpinAngle = 0
end

function PottersWheel:OnCancelStyleSelection(player: Player)
    self:ExitStyleSelection(true) -- true = return clay
end

function PottersWheel:ExitStyleSelection(returnClay: boolean?)
    local stationId = self.model:GetAttribute("StationId") or self.model.Name
    -- If returnClay is true and clay was inserted, tell server to return it
    if returnClay and self.currentClay > 0 then
        CancelPottery:Call(stationId):After(function(passed, result)
        end)
    else
        -- Just clear the style attributes without returning clay
        SetPotteryStyle:Call(stationId, nil, nil)
    end
    
    self.selectedStyle = nil
    self.isInStyleSelection = false
    self.requiredClay = 0
    self.currentClay = 0
    
    self:RemovePreviewModel()
    self:RemoveUnformedClay()
    
    -- Stop listening for equipped item changes
    self:StopEquippedItemListener()
    
    -- Hide style selection prompts
    self.cancelPrompt:SetEnabled(false)
    self.insertClayPrompt:SetEnabled(false)
    self.shapePrompt:SetEnabled(false)
    
    -- Hide clay requirement UI
    ClayRequirementFunctions:Hide()
    
    -- Show default prompts
    self.createPrompt:SetEnabled(true)
    self.upgradePrompt:SetEnabled(true)
end

function PottersWheel:OnInsertClay(player: Player)
    if not self.selectedStyle then
        warn("PottersWheel: No style selected")
        return
    end
    
    -- Get style data for clay requirement
    local styleData = SharedConstants.pottteryData and SharedConstants.pottteryData[self.selectedStyle]
    if not styleData then
        warn("PottersWheel: Style data not found")
        return
    end
    
    -- Fire remote to server
    local stationId = self.model:GetAttribute("StationId") or self.model.Name
    InsertClay:Call(stationId, self.selectedStyle):After(function(passed, result)
        if not passed or not result then
            warn("PottersWheel: InsertClay call failed")
            return
        end
        
        if result.success then
            -- Update the clay requirement UI with current progress
            self.currentClay = result.insertedClay
            ClayRequirementFunctions:UpdateCurrentClay(result.insertedClay)
            
            -- Update the unformed clay visual
            self:UpdateUnformedClay(result.insertedClay)
            
            if result.complete then
				-- Transition to shape mode: hide insert clay prompt
				self.insertClayPrompt:SetEnabled(false)
				
				-- Shape prompt visibility is controlled by equipped item listener
				-- This will show it if player is still holding correct clay
				self:UpdatePromptsForEquippedItem()

				-- Hide preview model (unformed clay is now fully sized)
				if self.previewModel then
					for _, descendant in ipairs(self.previewModel:GetDescendants()) do
						if descendant:IsA("BasePart") then
							descendant.Transparency = 1
						end
					end
				end
            end
        else
            -- Handle errors
            local errorType = result.error
            if errorType == "NoClay" then
                warn("You don't have any clay!")
                -- Still update UI to show current state
                if result.currentClay then
                    ClayRequirementFunctions:UpdateCurrentClay(result.currentClay)
                end
            elseif errorType == "WrongClayType" then
                warn("Wrong type of clay!")
            elseif errorType == "InvalidStyle" then
                warn("Invalid pottery style!")
            else
                warn("Failed to insert clay:", errorType or "Unknown error")
            end
        end
    end)
end

function PottersWheel:OnUpgradeTriggered(player: Player)
end

function PottersWheel:OnTriggered(player: Player)
    PottersBookFunctions:Open()
end

function PottersWheel:OnPromptHidden(player: Player)
    -- Only close if not in style selection mode
    if not self.isInStyleSelection then
        PottersBookFunctions:Close()
    end
end

function PottersWheel:StartMinigame(player: Player)
    if self.isInMinigame then return end
    
    self.isInMinigame = true
    
    -- Hide prompts during minigame
    self.shapePrompt:SetEnabled(false)
    self.cancelPrompt:SetEnabled(false)
    
    -- Hide clay requirement UI during minigame
    ClayRequirementFunctions:Hide()
    
    -- Tell server we're shaping (for visual replication)
    local stationId = self.model:GetAttribute("StationId") or self.model.Name
    UpdatePotteryShaping:Call(stationId, true, false)
    
    -- Start local spinning animation for owner
    self:StartOwnerShapingAnimation()
    
    -- Show minigame UI with exit button
    PotteryMinigameFunctions:Open({
        onExit = function()
            self:ExitMinigame()
        end,
        onComplete = function()
            self:OnMinigameComplete()
        end,
        
        -- Stage-centered config: each stage has ALL its own settings
        stages = {
            [1] = {
                -- How long player must stay balanced to complete this stage (seconds)
                stabilityRequired = 1.0,
                
                -- How strongly the clay drifts off-center on its own (higher = harder)
                driftStrength = 10,
                
                -- How quickly clay returns to center when not being pushed (higher = easier)
                friction = 3.0,
                
                -- How much player input moves the clay (higher = more responsive)
                pushStrength = 0.6,
                
                -- How close to center counts as "balanced" (higher = easier)
                threshold = 0.2,
                
                -- How fast progress depletes when off-center (0 = no depletion, 0.5 = default, 1+ = punishing)
                depletionRate = 0.5,
                
                -- Counter timing: when pulse starts, player has this window to react
                counterWindowStart = 0.5,  -- seconds before pulse to start accepting counter
                counterWindowEnd = 0.1,   -- seconds after pulse to stop accepting counter
                
                -- Pulse rhythm: clay gets pushed in pulses, player must counter
                pulses = {
                },
            },
        },
    })
end

function PottersWheel:OnMinigameComplete()
    -- Store the selected style before cleanup
    local completedStyle = self.selectedStyle
    local stationId = self.model:GetAttribute("StationId") or self.model.Name
    
    -- Mark as completing to prevent prompts - but don't fire remote yet
    self.isCompleting = true
    
    -- Close minigame UI immediately
    PotteryMinigameFunctions:Close()
    
    -- Hide clay requirement UI
    ClayRequirementFunctions:Hide()
    
    -- Disable all prompts during completion
    self.shapePrompt:SetEnabled(false)
    self.cancelPrompt:SetEnabled(false)
    self.insertClayPrompt:SetEnabled(false)
    
    -- Stop the equipped item listener
    self:StopEquippedItemListener()
    
    -- Clean up minigame connections
    self.minigameMaid:DoCleaning()
    
    -- Play completion fade animation (clay fades out, pottery fades in while spinning)
    self:PlayCompletionAnimation(function()
        -- Animation complete - NOW set the attribute and fire remotes
        self.model:SetAttribute("PotteryComplete", true)
        
        -- Tell server minigame is complete (for visual replication to other clients)
        UpdatePotteryShaping:Call(stationId, false, true)
        
        -- After animation, clean up
        self:RemoveUnformedClay()
        
        -- Stop the spinning animation
        self:StopOwnerShapingAnimation()
        
        -- Now restore character
        self.isInMinigame = false
        self:ShowCharacter()
        
        -- Tell server to complete pottery and give the item
        if completedStyle then
            CompletePottery:Call(stationId, completedStyle):After(function(passed, result)
            end)
        end
        
        -- Clean up the style selection after a short delay to show the finished pottery
        task.delay(1.0, function()
            self.isCompleting = false
            self:ExitStyleSelection(false)
        end)
    end)
end

function PottersWheel:PlayCompletionAnimation(onComplete: () -> ()?)
    self.completionAnimationMaid:DoCleaning()
    
    local duration = 0.33 -- 1 second fade
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    
    -- Create a scope for the tweens (Fusion 0.3 scoped syntax)
    local scope = Fusion.scoped(Fusion)
    
    local hasAnimations = false
    local transparencyValues = {} -- Store values to update after hydrating
    
    -- Fade out unformed clay (0 -> 1 transparency)
    if self.unformedClay then
        if self.unformedClay:IsA("BasePart") then
            -- Start at current transparency (0), will tween to 1
            local transparencyValue = scope:Value(self.unformedClay.Transparency)
            scope:Hydrate(self.unformedClay)({
                Transparency = scope:Tween(transparencyValue, tweenInfo),
            })
            table.insert(transparencyValues, {value = transparencyValue, target = 1})
            hasAnimations = true
        elseif self.unformedClay:IsA("Model") then
            for _, part in ipairs(self.unformedClay:GetDescendants()) do
                if part:IsA("BasePart") then
                    -- Start at current transparency (0), will tween to 1
                    local transparencyValue = scope:Value(part.Transparency)
                    scope:Hydrate(part)({
                        Transparency = scope:Tween(transparencyValue, tweenInfo),
                    })
                    table.insert(transparencyValues, {value = transparencyValue, target = 1})
                    hasAnimations = true
                end
            end
        end
    end
    
    -- Fade in preview model (1 -> 0 transparency)
    if self.previewModel then
        for _, part in ipairs(self.previewModel:GetDescendants()) do
            if part:IsA("BasePart") then
                -- Start at current transparency (1 from preview state), will tween to 0
                local transparencyValue = scope:Value(part.Transparency)
                scope:Hydrate(part)({
                    Transparency = scope:Tween(transparencyValue, tweenInfo),
                })
                table.insert(transparencyValues, {value = transparencyValue, target = 0})
                hasAnimations = true
            end
        end
    end
    
    -- Now set all the target values to trigger the tweens
    for _, data in ipairs(transparencyValues) do
        data.value:set(data.target)
    end
    
    -- Wait for tween duration and call callback
    if hasAnimations then
        task.delay(duration, function()
            self.completionAnimationMaid:DoCleaning()
            Fusion.doCleanup(scope)
            self:StopOwnerShapingAnimation()
            if onComplete then
                onComplete()
            end
        end)
    else
        -- No animations created, call completion immediately
        Fusion.doCleanup(scope)
        self:StopOwnerShapingAnimation()
        if onComplete then
            onComplete()
        end
    end
end

function PottersWheel:ShowCharacter()
    if not self.originalTransparencies then return end
    
    -- Create a scope for the springs (Fusion 0.3 scoped syntax)
    local scope = Fusion.scoped(Fusion)
    
    for instance, data in pairs(self.originalTransparencies) do
        if instance and instance.Parent then
            local targetValue = scope:Value(data.value)
            scope:Hydrate(instance)({
                [data.property] = scope:Spring(targetValue, 25, 1),
            })
        end
    end
    
    self.originalTransparencies = nil
end

function PottersWheel:ExitMinigame(isCompleting: boolean?)
    if not self.isInMinigame then return end
    
    self.isInMinigame = false
    
    -- Stop owner's spinning animation
    self:StopOwnerShapingAnimation()
    
    -- Tell server we stopped shaping (only if NOT completing - completion handles its own call)
    if not isCompleting then
        local stationId = self.model:GetAttribute("StationId") or self.model.Name
        UpdatePotteryShaping:Call(stationId, false, false)
    end
    
    -- Close minigame UI
    PotteryMinigameFunctions:Close()
    
    -- Clean up minigame connections
    self.minigameMaid:DoCleaning()
    
    -- Only show prompts and clay requirement UI if NOT completing
    -- When completing, we don't want to show the 5/5 clay UI - we're done!
    if not isCompleting then
        -- Cancel prompt is always available
        self.cancelPrompt:SetEnabled(true)
        
        -- Shape prompt visibility is controlled by equipped item listener
        self:UpdatePromptsForEquippedItem()
        
        -- Show clay requirement UI again (showing 5/5)
        ClayRequirementFunctions:Show(self.requiredClay, "normal", self.interactPart, {self.cancelPrompt, self.shapePrompt})
        ClayRequirementFunctions:UpdateCurrentClay(self.currentClay)
    else
        -- Hide clay requirement UI on completion
        ClayRequirementFunctions:Hide()
        
        -- Explicitly disable prompts during completion animation
        self.shapePrompt:SetEnabled(false)
        self.cancelPrompt:SetEnabled(false)
        self.insertClayPrompt:SetEnabled(false)
        
        -- Stop the equipped item listener since we're done
        self:StopEquippedItemListener()
    end
    
    -- Restore character visibility
    self:ShowCharacter()
end

function PottersWheel:Destroy()
    -- Clean up minigame if active
    self:ExitMinigame()
    self.minigameMaid:DoCleaning()
    self.clayAnimationMaid:DoCleaning()
    self.visualMaid:DoCleaning()
    self.replicatedClayAnimationMaid:DoCleaning()
    self.shapingAnimationMaid:DoCleaning()
    self.completionAnimationMaid:DoCleaning()
    self.equippedItemMaid:DoCleaning()
    
    self:RemovePreviewModel()
    self:RemoveUnformedClay()
    self:RemovePreviewModelVisual()
    self:RemoveUnformedClayVisual()
    
    if self.createPrompt then
        self.createPrompt:Destroy()
    end
    if self.upgradePrompt then
        self.upgradePrompt:Destroy()
    end
    if self.cancelPrompt then
        self.cancelPrompt:Destroy()
    end
    if self.insertClayPrompt then
        self.insertClayPrompt:Destroy()
    end
    if self.shapePrompt then
        self.shapePrompt:Destroy()
    end
    
    ClayRequirementFunctions:Hide()
end

return PottersWheel