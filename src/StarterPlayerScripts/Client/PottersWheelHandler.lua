local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Client = Players.LocalPlayer.PlayerScripts.Client

local Fusion = require(Shared.Fusion)
local ScriptUtils = require(Shared.ScriptUtils)

local Value = Fusion.Value
local Computed = Fusion.Computed
local Hydrate = Fusion.Hydrate

local player = Players.LocalPlayer
local camera = game.Workspace.CurrentCamera

local PottersWheelHandler = {
    pottersWheelObject = game.Workspace:WaitForChild("PottersWheel")
}


function PottersWheelHandler:HideCharacter()
    local character = player.Character

    if character then
        for _, object in ipairs (character:GetDescendants()) do
           local success, error = pcall(function()
                return object.Transparency
           end)

           if success then
				object:SetAttribute("originalTransparency", object.Transparency)
				local transparencySpring = ScriptUtils:CreateSpring({
					Initial = object.Transparency,
					Speed = 30,
					Damper = 1,
				})

				Hydrate(object)({
					Transparency = Computed(function()
						return transparencySpring.Spring:get()
					end),
				})

                transparencySpring.Value:set(1)
           end
        end               
    end
end

task.spawn(function()
    PottersWheelHandler.pottersWheelObject.Root.Attachment.ProximityPrompt.Triggered:Connect(function(player)
        local pottersWheel = PottersWheelHandler.pottersWheelObject
        local pottersCamera = pottersWheel:WaitForChild("Camera")
        
        pottersWheel.Root.Attachment.ProximityPrompt.Enabled = false
        
		PottersWheelHandler:HideCharacter()

        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")

        if character and humanoid then
            humanoid.WalkSpeed = 0
            humanoid.JumpPower = 0               
        end

        camera.FieldOfView = 40
        camera.CameraType = Enum.CameraType.Scriptable
        camera.CFrame = pottersCamera.CFrame
    end)
end)


return PottersWheelHandler