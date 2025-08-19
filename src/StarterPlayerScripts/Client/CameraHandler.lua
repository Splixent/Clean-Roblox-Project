local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Client = Players.LocalPlayer.PlayerScripts.Client

local Fusion = require(Shared.Fusion)
local ScriptUtils = require(Shared.ScriptUtils)
local Maid = require(Shared.Maid)

local Value = Fusion.Value
local Computed = Fusion.Computed
local Hydrate = Fusion.Hydrate

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = game.Workspace.CurrentCamera

local CameraHandler = {
    shiftOffset = Vector3.new(1.3, 0.3, 0),
    cameraOffset = Vector3.new(0, 0, 0),
    enabled = Value(false),
    shiftSpring = ScriptUtils:CreateSpring({
        Initial = Vector3.new(),
        Speed = 30,
        Damper = 1
    }),
    defaultIcon = mouse.Icon
}

function CameraHandler.shiftLock(inputName, userInputState)
    if userInputState == Enum.UserInputState.Begin then
        CameraHandler.enabled:set(not CameraHandler.enabled:get())
    end
end

function CameraHandler.Shift()
    local humanoid = Players.LocalPlayer.Character.Humanoid
    local humanoidRootPart = Players.LocalPlayer.Character.HumanoidRootPart

    if humanoid and humanoidRootPart then
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter

        local cameraCFrame = camera.CFrame
        local lookVector = cameraCFrame.LookVector
        local flatLookVector = Vector3.new(lookVector.X, 0, lookVector.Z).Unit

        -- Roblox-style camera offset calculation
        local rightVector = cameraCFrame.RightVector
        local upVector = cameraCFrame.UpVector
        local cameraRelativeOffset = (CameraHandler.shiftSpring.Spring:get().X * rightVector) + (CameraHandler.shiftSpring.Spring:get().Y * upVector) + (CameraHandler.shiftSpring.Spring:get().Z * flatLookVector)

        if cameraRelativeOffset.Magnitude == cameraRelativeOffset.Magnitude then -- NaN check
            camera.CFrame += cameraRelativeOffset
        end

        if CameraHandler.enabled:get() == true then
            humanoidRootPart.CFrame = CFrame.new(humanoidRootPart.Position, humanoidRootPart.Position + flatLookVector)
        end
    end
end

CameraHandler.Toggled = Computed(function()
    if CameraHandler.enabled:get() == true then
        local character = Players.LocalPlayer.Character

        if character and character.Humanoid then
            local Mouse = Players.LocalPlayer:GetMouse()
            Mouse.Icon = "rbxassetid://15213957604"

            CameraHandler.shiftSpring.Value:set(CameraHandler.shiftOffset)
            CameraHandler.ShiftEnabled = true

            character.Humanoid.AutoRotate = false

            RunService:BindToRenderStep("ShiftLock", Enum.RenderPriority.Camera.Value, CameraHandler.Shift)
        end
    else
        local humanoid = Players.LocalPlayer.Character.Humanoid

        if humanoid then
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            mouse.Icon = CameraHandler.defaultIcon

            humanoid.AutoRotate = true

            CameraHandler.shiftSpring.Value:set(Vector3.new(0, 0, 0))
            RunService:UnbindFromRenderStep("ShiftLock")
        end
    end
end)


task.spawn(function()
    RunService.PreRender:Connect(function(dt)
		local character = player.Character
		local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
		local head = character and character:FindFirstChild("Head")

		if character and humanoidRootPart and head then
			CameraHandler.cameraOffset = CameraHandler.cameraOffset:Lerp(
				(humanoidRootPart.CFrame + Vector3.new(0, 1.5, 0)):ToObjectSpace(head.CFrame).Position,
				0.1 * (dt * 60)
			)
			camera.CFrame *= CFrame.new(CameraHandler.cameraOffset)
		end
    end)
end)

return CameraHandler