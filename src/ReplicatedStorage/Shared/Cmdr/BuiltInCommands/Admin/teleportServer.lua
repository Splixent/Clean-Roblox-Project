local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Server = ServerScriptService.Server

return function (context, targets, destination)
	local cframe

	if typeof(destination) == "Instance" then
		if destination.Character and destination.Character:FindFirstChild("HumanoidRootPart") then
			cframe = destination.Character.HumanoidRootPart.CFrame
		else
			return "Target player has no character."
		end
	elseif typeof(destination) == "Vector3" then
		cframe = CFrame.new(destination)
    end

    if typeof(targets) == "table" then
		for _, player in ipairs(targets) do
			if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
				player.Character.HumanoidRootPart.CFrame = cframe
			end
		end

		return ("Teleported %d players."):format(#targets)
    end
end
