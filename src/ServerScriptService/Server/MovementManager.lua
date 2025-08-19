local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")  -- Added for periodic updates

local Shared = ReplicatedStorage.Shared
local Events = require(Shared.Events)

local PlayerCameraData = Events.PlayerCameraData:Server()
local CameraPosition = Events.CameraPosition:Server()

local MovementManager = {
    cameraPositions = {},
    updateRate = 0.2,
}

CameraPosition:On(function(player, cameraPosition)
    local character = player.Character
    
    if character and character.PrimaryPart then
        local characterPos = character.PrimaryPart.Position
        local distance = (cameraPosition - characterPos).Magnitude
        
        local maxDistance = 50
        
        if distance <= maxDistance then
            MovementManager.cameraPositions[player] = cameraPosition
        end
    end
end)

function MovementManager:FormatCameraData(cameraPositions)
    local formattedData = {}

    for player, cameraPosition in pairs (cameraPositions) do
        formattedData[player.Name] = cameraPosition
    end

    return formattedData
end

task.spawn(function()
    Players.PlayerRemoving:Connect(function(player)
		MovementManager.cameraPositions[player] = nil
    end)

    while true do
        for _, player in ipairs(Players:GetPlayers()) do
			PlayerCameraData:Fire(player, MovementManager:FormatCameraData(MovementManager.cameraPositions))
        end
        task.wait(MovementManager.updateRate)
    end
end)

return MovementManager