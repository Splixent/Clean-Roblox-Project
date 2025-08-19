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
local EquipmentUtils = require(Server.EquipmentManager.EquipmentUtils)

local WeaponBind = {
    weaponModelTemplate = ReplicatedStorage.Assets.Weapons.StarterKatana.WeaponModel,
    weaponAnimations = ReplicatedStorage.Assets.CharacterAnimations.WeaponAnimations.StarterKatana,
    weaponModel = nil,
    handleAttachments = {},

    playerWeaponData = {}
}

function WeaponBind:Bind(player, character)
    WeaponBind.playerWeaponData[player] = {}

    WeaponBind.playerWeaponData[player].handleAttachments = EquipmentUtils:AttachHandles(character)

    WeaponBind.playerWeaponData[player].weaponModel = WeaponBind.weaponModelTemplate:Clone()
    WeaponBind.playerWeaponData[player].weaponModel.Parent = character

    WeaponBind.playerWeaponData[player].weaponModel.Habaki.Transparency = 1
    WeaponBind.playerWeaponData[player].weaponModel.Blade.Transparency = 1

    WeaponBind.playerWeaponData[player].weaponModel.Sheath.HandleWeld.RigidConstraint.Attachment0 = character.Torso.HipHandle
    WeaponBind.playerWeaponData[player].weaponModel.MainHandle.HandleWeld.RigidConstraint.Attachment0 = WeaponBind.playerWeaponData[player].weaponModel.Sheath.UnequipWeld
end

function WeaponBind:Equip(player, character)
    print(WeaponBind.playerWeaponData)
    if WeaponBind.playerWeaponData[player].weaponModel == nil then return end

    WeaponBind.playerWeaponData[player].weaponModel.Habaki.Transparency = 0
    WeaponBind.playerWeaponData[player].weaponModel.Blade.Transparency = 0

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local animator = humanoid:FindFirstChildOfClass("Animator")

    if humanoid and animator then
        local equipMaid = Maid.new()
        local equipTrack = animator:LoadAnimation(WeaponBind.weaponAnimations.Equip)

        equipMaid:GiveTask(equipTrack.KeyframeReached:Connect(function(keyframeName)
            if keyframeName == "UpdateWeld" then
                task.delay(0.06, function()
                    if character then
                        WeaponBind.playerWeaponData[player].weaponModel.MainHandle.HandleWeld.RigidConstraint.Attachment0 = WeaponBind.playerWeaponData[player].handleAttachments.right
                    end
                end)
                equipMaid:Destroy()
            end
        end))

		equipTrack:Play()
    end
end

function WeaponBind:Unequip(player, character)
    if WeaponBind.playerWeaponData[player].weaponModel == nil then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid:FindFirstChildOfClass("Animator")

	if humanoid and animator then
		local unequipMaid = Maid.new()
		local UnequipTrack = animator:LoadAnimation(WeaponBind.weaponAnimations.Unequip)

		unequipMaid:GiveTask(UnequipTrack.KeyframeReached:Connect(function(keyframeName)
			if keyframeName == "UpdateWeld" then
                WeaponBind.playerWeaponData[player].weaponModel.Habaki.Transparency = 1
                WeaponBind.playerWeaponData[player].weaponModel.Blade.Transparency = 1
                WeaponBind.playerWeaponData[player].weaponModel.MainHandle.HandleWeld.RigidConstraint.Attachment0 = WeaponBind.playerWeaponData[player].weaponModel.Sheath.UnequipWeld
                unequipMaid:GiveTask(UnequipTrack.Ended:Connect(function()
					WeaponBind.playerWeaponData[player].weaponModel.Sheath.HandleWeld.RigidConstraint.Attachment0 = character.Torso.HipHandle
				    unequipMaid:Destroy()
                end))
			end
		end))

		UnequipTrack:Play()
        WeaponBind.playerWeaponData[player].weaponModel.Sheath.HandleWeld.RigidConstraint.Attachment0 = WeaponBind.handleAttachments.left
	end
end

function WeaponBind:Unbind(player)
    for _, attachment in pairs(WeaponBind.handleAttachments) do
        if attachment and attachment:IsA("Attachment") then
            attachment:Destroy()
        end
    end

    if WeaponBind.playerWeaponData[player].weaponModel then
        WeaponBind.playerWeaponData[player].weaponModel:Destroy()
        WeaponBind.playerWeaponData[player].weaponModel = nil
    end
end

Players.PlayerRemoving:Connect(function(player)
    if WeaponBind.playerWeaponData[player] then
        WeaponBind:Unbind(player)
        WeaponBind.playerWeaponData[player] = nil
    end
end)

return WeaponBind