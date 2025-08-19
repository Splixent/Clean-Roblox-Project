local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client = Players.LocalPlayer.PlayerScripts.Client
local Shared = ReplicatedStorage.Shared

local BetterReplication = require(Shared.BetterReplication)

BetterReplication.startReplication()

--[[

how to fix for ragdolls --melon

local function interpolate(dt)
local stagedPlayers = {}
local stagedResults = {}

for player, isIn in inProximity do
    if not isIn or player == localPlayer or (player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid:GetState() == Enum.HumanoidStateType.Physics or player.Character:GetAttribute("Ragdolled")) then
    continue
end
]]