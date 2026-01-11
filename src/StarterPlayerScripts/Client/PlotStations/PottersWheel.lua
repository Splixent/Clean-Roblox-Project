local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Client = Players.LocalPlayer.PlayerScripts.Client

local PlotStation = require(Shared.PlotStation)
local ProximityPromptHandler = require(Client.ProximityPromptHandler)
local SharedConstants = require(Shared.Constants)
local Events = require(Shared.Events)
local Fusion = require(Shared.Fusion)

-- Get PottersBook Functions module
local PottersBookFunctions = require(Client.UI.Components.PottersBook.Functions)
local ClayRequirementFunctions = require(Client.UI.Components.ClayRequirement.Functions)

local InsertClay = Events.InsertClay
local peek = Fusion.peek

local PottersWheel = {}
PottersWheel.__index = PottersWheel
setmetatable(PottersWheel, PlotStation)

function PottersWheel.new(player: Player, stationModel: Model)
    local self = PlotStation.new(player, stationModel)
    setmetatable(self, PottersWheel)
    
    self.selectedStyle = nil
    self.previewModel = nil
    self.isInStyleSelection = false
    
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
        priority = 1,
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
    ClayRequirementFunctions:Show(clayCost, "normal", self.interactPart, {self.cancelPrompt, self.insertClayPrompt})
    -- TODO: Update current clay from player inventory
    ClayRequirementFunctions:UpdateCurrentClay(0)
    
    -- Place preview model on the wheel
    self:PlacePreviewModel(styleKey, styleData)
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
    self.previewModel = model
    
    -- Set all BaseParts to 0.8 transparency
    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("BasePart") then
            descendant.Transparency = 0.8
            descendant.CanCollide = false
        end
    end
    
    -- Get the base attachment from the PottersWheel
    local primaryPart = self.model.PrimaryPart
    if not primaryPart then
        warn("PottersWheel: No PrimaryPart found")
        model:Destroy()
        self.previewModel = nil
        return
    end
    
    local baseAttachment = primaryPart:FindFirstChild("Base")
    if not baseAttachment then
        warn("PottersWheel: Base attachment not found on PrimaryPart")
        model:Destroy()
        self.previewModel = nil
        return
    end
    
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

function PottersWheel:OnCancelStyleSelection(player: Player)
    self:ExitStyleSelection()
end

function PottersWheel:ExitStyleSelection()
    self.selectedStyle = nil
    self.isInStyleSelection = false
    
    -- Remove preview model
    self:RemovePreviewModel()
    
    -- Hide style selection prompts
    self.cancelPrompt:SetEnabled(false)
    self.insertClayPrompt:SetEnabled(false)
    
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
    local result = InsertClay:Call(stationId, self.selectedStyle)
    
    if result == "Success" then
        print("Clay inserted successfully!")
        -- The model transparency will be updated by server replication
        -- Exit style selection mode
        self:ExitStyleSelection()
    elseif result == "NotHoldingClay" then
        warn("You need to hold clay to insert it!")
    elseif result == "WrongClayType" then
        warn("Wrong type of clay!")
    elseif result == "NotEnoughClay" then
        warn("Not enough clay!")
    else
        warn("Failed to insert clay:", result)
    end
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

function PottersWheel:Destroy()
    self:RemovePreviewModel()
    
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
    
    ClayRequirementFunctions:Hide()
end

return PottersWheel
