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
local EquipmentUtils = require(script.EquipmentUtils)
local PlayerEntityManager = require(Server.PlayerEntityManager)

local EquipWeapon = Events.EquipWeapon:Server()

local WeaponBinds = (function()
    local weaponBinds = {}

    for _, weaponBind in ipairs (script.WeaponBinds:GetChildren()) do
        weaponBinds[weaponBind.Name] = require(script.WeaponBinds[weaponBind.Name])
    end

    return weaponBinds
end)()

local EquipmentManager = {
    equipCooldown = 2,
}

function EquipmentManager:Setup(player: Player)
    local playerReplica = DataObject.new(player)
    local character = player.Character or player.CharacterAdded:Wait()

    WeaponBinds[playerReplica.equipment.weapon]:Bind(player, character)
    print("Binding weapon for player:", character, "Weapon:", playerReplica.equipment.weapon)

    player.CharacterAdded:Connect(function(newCharacter)
        WeaponBinds[playerReplica.equipment.weapon]:Bind(player, newCharacter)
        print("Rebinding weapon for player:", newCharacter, "Weapon:", playerReplica.equipment.weapon)
    end)
end

EquipWeapon:On(function(player)
    local playerReplica = DataObject.new(player)
    local playerEntity = PlayerEntityManager.new(player, true).Replica
    local character = player.Character

    if character == nil then return end

    if WeaponBinds[playerReplica.equipment.weapon] then
       if playerEntity.Data.weapon.lastEquip < tick() - EquipmentManager.equipCooldown then
           playerEntity:SetValue({"weapon", "lastEquip"}, tick())

			if playerEntity.Data.weapon.isEquipped then
				playerEntity:SetValue({"weapon", "isEquipped" }, false)
				WeaponBinds[playerReplica.equipment.weapon]:Unequip(player, character)
			else
				playerEntity:SetValue({"weapon", "isEquipped" }, true)
				WeaponBinds[playerReplica.equipment.weapon]:Equip(player, character)
			end
       end
    end
end)



task.spawn(function()
    for i, player in ipairs (Players:GetPlayers()) do
        EquipmentManager:Setup(player)
    end

    Players.PlayerAdded:Connect(function(player)
        EquipmentManager:Setup(player)
    end)

end)

return EquipmentManager