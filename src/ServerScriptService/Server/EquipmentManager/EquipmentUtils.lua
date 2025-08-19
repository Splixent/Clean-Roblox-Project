local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local MarketplaceService = game:GetService("MarketplaceService")

local Shared = ReplicatedStorage.Shared
local Server = ServerScriptService.Server

local DataObject = require(Server.Datastore.DataObject)
local ScriptUtils = require(Shared.ScriptUtils)
local Events = require(Shared.Events)
local Maid = require(Shared.Maid)


local EquipmentUtils = {}

function EquipmentUtils:AttachHandles(character)
    local handleAttachments = {}

    for count = 1, 2 do
        local armName = count == 1 and "Left Arm" or "Right Arm"
        local handleName = count == 1 and "LeftHandle" or "RightHandle"
        local side = count == 1 and "left" or "right"

        local handle = Instance.new("Part")
        handle.Size = Vector3.one * 0.5
        handle.Shape = Enum.PartType.Ball
        handle.Transparency = 0.5
        handle.CanCollide = false
        handle.Parent = character
        handle.Name = handleName

        local handleAttachment = Instance.new("Attachment")
        handleAttachment.Parent = handle
        handleAttachment.Name = count == 1 and "LeftHandle" or "RightHandle"
        handleAttachments[side] = handleAttachment

        local motor6D = Instance.new("Motor6D")
        motor6D.Parent = character[armName]
        motor6D.Part0 = character[armName]
        motor6D.Part1 = handle
        motor6D.C0 = CFrame.new(0, -1, 0)
        motor6D.Name = handleName
    end

    return handleAttachments
end

return EquipmentUtils