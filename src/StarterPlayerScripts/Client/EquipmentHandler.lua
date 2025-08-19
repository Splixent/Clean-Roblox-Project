local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Client = Players.LocalPlayer.PlayerScripts.Client

local Events = require(Shared.Events)

local EquipWeapon = Events.EquipWeapon:Client()

local player = Players.LocalPlayer

local EquipmentHandler = {}


function EquipmentHandler.equipWeapon(inputName, userInputState)
    if userInputState == Enum.UserInputState.Begin then
		EquipWeapon:Fire()
        return Enum.ContextActionResult.Sink
    end
end


return EquipmentHandler