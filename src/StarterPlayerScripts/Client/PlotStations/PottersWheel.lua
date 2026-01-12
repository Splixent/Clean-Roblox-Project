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

-- Get PottersBook Functions module
local PottersBookFunctions = require(Client.UI.Components.PottersBook.Functions)
local ClayRequirementFunctions = require(Client.UI.Components.ClayRequirement.Functions)
local PotteryMinigameFunctions = require(Client.UI.Components.PotteryMinigame.Functions)

local InsertClay = Events.InsertClay
local peek = Fusion.peek
local camera = workspace.CurrentCamera

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
    
    self:SetupInteraction()
    self:SetupStyleSelectionListener()
    
    return self
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
        customHorizontalOffset = -0.7,
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
    
    -- Show style selection prompts
    self.cancelPrompt:SetEnabled(true)
    self.insertClayPrompt:SetEnabled(true)
    
    -- Show clay requirement UI (pass the interact part as adornee and the prompts to adjust)
    local clayCost = styleData.cost and styleData.cost.clay or 0
    self.requiredClay = clayCost
    self.currentClay = 0
    ClayRequirementFunctions:Show(clayCost, "normal", self.interactPart, {self.cancelPrompt, self.insertClayPrompt})
    ClayRequirementFunctions:UpdateCurrentClay(0)
    
    -- Place preview model on the wheel (hidden initially)
    self:PlacePreviewModel(styleKey, styleData)
    
    -- Place unformed clay on the wheel
    self:PlaceUnformedClay()
end

function PottersWheel:PlacePreviewModel(styleKey: string, styleData: table)
    -- Remove existing preview model
    self:RemovePreviewModel()
    
    -- Get model from ReplicatedStorage
    local modelName = styleData.model or styleKey
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
    
    local modelTemplate = potteryStyles:FindFirstChild(modelName)
    if not modelTemplate then
        warn("PottersWheel: Model not found:", modelName)
        return
    end
    
    -- Clone the model
    local model = modelTemplate:Clone()
    model.Parent = self.model
    self.previewModel = model
    
    -- Set all BaseParts to 0.8 transparency
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
    
    -- Parent the model to the PottersWheel
    model.Parent = self.model
end

function PottersWheel:RemovePreviewModel()
    if self.previewModel then
        self.previewModel:Destroy()
        self.previewModel = nil
    end
end

function PottersWheel:PlaceUnformedClay()
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
    self.unformedClay = clay
    
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
    if self.unformedClay then
        self.unformedClay:Destroy()
        self.unformedClay = nil
    end
    self.clayTargetSize = nil
    self.clayCurrentSize = nil
    self.clayTargetHeight = 0
    self.clayCurrentHeight = 0
end

function PottersWheel:OnCancelStyleSelection(player: Player)
    self:ExitStyleSelection()
end

function PottersWheel:ExitStyleSelection()
    self.selectedStyle = nil
    self.isInStyleSelection = false
    self.requiredClay = 0
    self.currentClay = 0
    
    self:RemovePreviewModel()
    self:RemoveUnformedClay()
    
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
				-- Transition to shape mode: hide insert clay, show shape prompt
				self.insertClayPrompt:SetEnabled(false)
				self.shapePrompt:SetEnabled(true)

				-- Hide preview model (unformed clay is now fully sized)
				if self.previewModel then
					for _, descendant in ipairs(self.previewModel:GetDescendants()) do
						if descendant:IsA("BasePart") then
							descendant.Transparency = 1
						end
					end
				end
            else
                print(string.format("Clay inserted: %d/%d", result.insertedClay, result.requiredClay))
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
    print(player.Name .. " wants to upgrade the potter's wheel")
end

function PottersWheel:OnTriggered(player: Player)
    print(player.Name .. " wants to create pottery at level " .. self.data.level .. " potter's wheel")
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
    
    -- Get camera location from the wheel
    local primaryPart = self.model.PrimaryPart
    local cameraLocation = primaryPart and primaryPart:FindFirstChild("CameraLocation")
    
    if not cameraLocation then
        warn("PottersWheel: CameraLocation attachment not found on PrimaryPart")
        self:ExitMinigame()
        return
    end
    
    -- Store original camera type
    self.originalCameraType = camera.CameraType
    self.originalFOV = camera.FieldOfView
    
    -- Make camera scriptable for our control
    camera.CameraType = Enum.CameraType.Scriptable
    
    -- Target CFrame looking at the wheel center
    local targetCFrame = cameraLocation.WorldCFrame
    
    local startTime = tick()
    
    -- Distance check for exiting (same as prompt distance)
    local maxDistance = 5 -- Studs before auto-exiting (matches prompt distance)
    
    -- Camera transition with spring-like lerp
    self.minigameMaid:GiveTask(RunService.RenderStepped:Connect(function(dt)
        if not self.isInMinigame then return end
        
        -- Check player distance
        local character = player.Character
        if character then
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            if rootPart then
                local distance = (rootPart.Position - self.model.PrimaryPart.Position).Magnitude
                if distance > maxDistance then
                    self:ExitMinigame()
                    return
                end
            end
        end
        
        -- Smooth camera transition using exponential lerp
        local elapsed = tick() - startTime
        local transitionSpeed = ScriptUtils:Map(elapsed, 0, 0.5, 5, 15)
        transitionSpeed = math.clamp(transitionSpeed, 5, 15)
        
        local alpha = 1 - math.exp(-transitionSpeed * dt)
        camera.CFrame = camera.CFrame:Lerp(targetCFrame, alpha)
        
        -- Spring FOV to 40
        local fovAlpha = 1 - math.exp(-8 * dt)
        camera.FieldOfView = camera.FieldOfView + (40 - camera.FieldOfView) * fovAlpha
    end))
    
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
                stabilityRequired = 3.0,
                
                -- How strongly the clay drifts off-center on its own (higher = harder)
                driftStrength = 0.5,
                
                -- How quickly clay returns to center when not being pushed (higher = easier)
                friction = 3.0,
                
                -- How much player input moves the clay (higher = more responsive)
                pushStrength = 0.6,
                
                -- How close to center counts as "balanced" (higher = easier)
                threshold = 0.3,
                
                -- How fast progress depletes when off-center (0 = no depletion, 0.5 = default, 1+ = punishing)
                depletionRate = 0.5,
                
                -- Counter timing: when pulse starts, player has this window to react
                counterWindowStart = 0.3,  -- seconds before pulse to start accepting counter
                counterWindowEnd = 0.15,   -- seconds after pulse to stop accepting counter
                
                -- Pulse rhythm: clay gets pushed in pulses, player must counter
                pulses = {
                    { interval = 2.5, strength = 0.6 },  -- every 2.5s, push with 0.6 strength
                },
            },
            [2] = {
                stabilityRequired = 3.0,
                driftStrength = 1.5,
                friction = 2.5,
                pushStrength = 0.6,
                threshold = 0.25,
                depletionRate = 0.5,
                counterWindowStart = 0.25,
                counterWindowEnd = 0.12,
                pulses = {
                    { interval = 2.0, strength = 0.7 },
                },
            },
            [3] = {
                stabilityRequired = 3.5,
                driftStrength = 2.5,
                friction = 2.0,
                pushStrength = 0.6,
                threshold = 0.2,
                depletionRate = 0.5,
                counterWindowStart = 0.5,
                counterWindowEnd = 0.1,
                pulses = {
                    { interval = 1.0, strength = 0.6 },
                },
            },
        },
    })
    
    -- Hide character during minigame
    self:HideCharacter(player)
    
    print("Minigame started!")
end

function PottersWheel:OnMinigameComplete()
    print("Pottery shaping complete!")
    
    -- TODO: Send completion to server, spawn finished pottery, etc.
    -- For now, just exit the minigame
    self:ExitMinigame()
    
    -- Clean up the style selection (pottery is done)
    self:ExitStyleSelection()
end

function PottersWheel:HideCharacter(player: Player)
    local character = player.Character
    if not character then return end
    
    self.originalTransparencies = {}
    
    for _, descendant in ipairs(character:GetDescendants()) do
        if descendant:IsA("BasePart") then
            self.originalTransparencies[descendant] = {
                property = "Transparency",
                value = descendant.Transparency
            }
            descendant.Transparency = 1
        elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
            self.originalTransparencies[descendant] = {
                property = "Transparency",
                value = descendant.Transparency
            }
            descendant.Transparency = 1
        elseif descendant:IsA("ParticleEmitter") or descendant:IsA("Trail") or descendant:IsA("Beam") then
            self.originalTransparencies[descendant] = {
                property = "Transparency",
                value = descendant.Transparency
            }
            descendant.Transparency = NumberSequence.new(1)
        end
    end
end

function PottersWheel:ShowCharacter()
    if not self.originalTransparencies then return end
    
    for instance, data in pairs(self.originalTransparencies) do
        if instance and instance.Parent then
            instance[data.property] = data.value
        end
    end
    
    self.originalTransparencies = nil
end

function PottersWheel:ExitMinigame()
    if not self.isInMinigame then return end
    
    self.isInMinigame = false
    
    -- Close minigame UI
    PotteryMinigameFunctions:Close()
    
    -- Clean up minigame connections
    self.minigameMaid:DoCleaning()
    
    -- Show shape prompt again and cancel prompt (stay in style selection with 5/5)
    self.shapePrompt:SetEnabled(true)
    self.cancelPrompt:SetEnabled(true)
    
    -- Show clay requirement UI again (showing 5/5)
    ClayRequirementFunctions:Show(self.requiredClay, "normal", self.interactPart, {self.cancelPrompt, self.shapePrompt})
    ClayRequirementFunctions:UpdateCurrentClay(self.currentClay)
    
    -- Restore camera
    camera.CameraType = self.originalCameraType or Enum.CameraType.Custom
    camera.FieldOfView = self.originalFOV or 70
    
    -- Restore character visibility
    self:ShowCharacter()
end

function PottersWheel:Destroy()
    -- Clean up minigame if active
    self:ExitMinigame()
    self.minigameMaid:DoCleaning()
    
    self:RemovePreviewModel()
    self:RemoveUnformedClay()
    
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
