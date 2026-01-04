--Strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage.Shared
local Client = Players.LocalPlayer.PlayerScripts.Client

local Replication = require(Client.Replication)
local Events = require(Shared.Events)
local ScriptUtils = require(Shared.ScriptUtils)

local InGame = Events.InGame:Client()

task.spawn(function()
    if game:IsLoaded() == false then
        game.Loaded:Wait()
    end

    ContentProvider:PreloadAsync(game:GetDescendants())

    repeat task.wait() until Replication:GetInfo("States")

    require(Client.UI)
    
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)

    if Replication:GetInfo("States").loaded == false then
        Replication.LoadedChanged(function(NewValue)
            if NewValue == true then
                InGame:Fire()
            end
        end)
    elseif Replication:GetInfo("States").loaded == true then
        print("ingame")
        InGame:Fire()
    end

end)