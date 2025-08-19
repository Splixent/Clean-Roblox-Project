local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Client = Players.LocalPlayer.PlayerScripts.Client

local ScriptUtils = require(Shared.ScriptUtils)

local EffectUtils = {}

function EffectUtils:HideCharacter(character, excludeInstances)
	local invisibleObjects = {}
    local exclusion = {}

    excludeInstances = excludeInstances or {}

    for _, object in ipairs (excludeInstances) do
        for i, descendant in ipairs (object:GetDescendants()) do
            table.insert(exclusion, descendant)
        end
    end

	for _, object in ipairs(character:GetDescendants()) do
		if table.find(exclusion, object) then
			continue
		end

		local success, _ = pcall(function()
			if object.Transparency then
				return true
			end
		end)
		if success == true then
			invisibleObjects[object] = object.Transparency

			if
				typeof(object.Transparency) == "NumberSequence"
				and ScriptUtils:GetAverageNumberSequenceValue(object.Transparency) < 1
			then
				object.Transparency = NumberSequence.new(1)
			elseif object.Transparency < 1 then
				object.Transparency = 1
			end
		end
	end

    return invisibleObjects
end

function EffectUtils:ShowCharacter(invisibleObjects)
    for object, transparency in pairs(invisibleObjects) do
        if object then
            object.Transparency = transparency
        end
    end
end

function EffectUtils:CreateAfterImage(character)
    local meshCharacter = ReplicatedStorage.Assets.MeshCharacter:Clone()
    meshCharacter.Parent = game.Workspace.Debris

    local editableMeshes = {}

    if character then
        for _, part in ipairs (meshCharacter:GetChildren()) do
			part.CFrame = character:FindFirstChild(part.Name) and character[part.Name].CFrame or CFrame.new()
           table.insert(editableMeshes, part)
        end
    end

    return meshCharacter
end

return EffectUtils