local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Client = Players.LocalPlayer.PlayerScripts.Client

local Fusion = require(Shared.Fusion)
local UIPostProcess = require(script.UIPostProcess)

local New = Fusion.New
local Children = Fusion.Children

local Player = Players.LocalPlayer

local UI = {}

task.spawn(function()
    local TestUI = Player.PlayerGui:WaitForChild("TestUI")

    if TestUI then
        TestUI.Enabled = false
    end
end)


for i, Component in ipairs (script.Components:GetChildren()) do
    table.insert(UI, require(Component))
    task.wait(0.33/2)
end 

local masterUI = New "ScreenGui" {
    Name = "UI",
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    Parent = Player.PlayerGui,
    IgnoreGuiInset = true,

    [Children] = {
        UI
    }
}
UIPostProcess:ViewportChanged(masterUI)
UIPostProcess:UpdateAutoScaleScrollingFrames(masterUI)

return nil