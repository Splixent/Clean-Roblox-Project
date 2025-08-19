--[[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Client = Players.LocalPlayer.PlayerScripts.Client

local Fusion = require(Shared.Fusion)
local Functions = require(script.Functions)

local New = Fusion.New
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

return {}
]]