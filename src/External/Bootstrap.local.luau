--Strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage.Shared
local Client = Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Client")

local Replication = require(Client.Replication)
local ScriptUtils = require(Shared.ScriptUtils)
local Events = require(Shared.Events)

task.spawn(function()
	if game:IsLoaded() == false then
		game.Loaded:Wait()
	end

	ContentProvider:PreloadAsync(game:GetDescendants())

	repeat
		task.wait()
	until Replication:GetInfo("States")

	require(Client.UI)

	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)

	if Replication:GetInfo("States").loaded == false then
		Replication.LoadedChanged(function(NewValue)
			if NewValue == true then
				Events.InGame.send(nil)
			end
		end)
	elseif Replication:GetInfo("States").loaded == true then
		print("ingame")
		Events.InGame.send(nil)
	end
end)
