--[[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Client = Players.LocalPlayer.PlayerScripts.Client

local ScriptUtils = require(ReplicatedStorage.Shared.ScriptUtils)
local Fusion = require(Shared.Fusion)
local Events = require(Shared.Events)
local Replication = require(Client.Replication)

local New = Fusion.New
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local Computed = Fusion.Computed
local Value = Fusion.Value
local Hydrate = Fusion.Hydrate

local Functions = {}


task.spawn(function()
    
end)

return Functions
]]